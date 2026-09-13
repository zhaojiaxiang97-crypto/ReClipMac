#include "DownloadManager.h"
#include "PlatformPaths.h"

#include <QDir>
#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QNetworkRequest>
#include <QStorageInfo>
#include <QStandardPaths>
#include <QTimer>
#include <QTemporaryFile>

#if defined(RECLIP_HAS_FFMPEG_SDK)
#include <QtConcurrent/QtConcurrentRun>

#include "ffmpeg/FfprobeService.h"
#include "ffmpeg/FfmpegService.h"
#endif

namespace {

constexpr qint64 kMinimumDownloadFreeBytes = 16 * 1024 * 1024;

bool hasUsableDownloadStorage(const QString &path)
{
    QStorageInfo storage(path);
    storage.refresh();
    return storage.isValid()
        && storage.isReady()
        && storage.bytesAvailable() >= kMinimumDownloadFreeBytes;
}

#if defined(RECLIP_HAS_FFMPEG_SDK)
ReClip::Ffmpeg::OperationResult validateSdkOutput(
    const ReClip::Ffmpeg::OperationResult &operation,
    const QString &outputPath)
{
    if (!operation.ok) {
        return operation;
    }

    const ReClip::Ffmpeg::ProbeResult probe =
        ReClip::Ffmpeg::FfprobeService().probe(outputPath);
    if (!probe.ok) {
        return {false, probe.error};
    }
    if (probe.media.streams.isEmpty()) {
        return {false, {
            QStringLiteral("probe-no-streams"),
            QStringLiteral("FFprobe SDK 没有在输出文件中找到媒体流"),
            0
        }};
    }
    return operation;
}

struct SdkStreamSpec
{
    QUrl url;
    QList<QPair<QByteArray, QByteArray>> headers;
    qint64 expectedBytes = -1;
    QString protocol;
    bool segmented = false;
};

struct SdkResolvedMedia
{
    SdkStreamSpec combined;
    SdkStreamSpec video;
    SdkStreamSpec audio;
    bool separateStreams = false;
    QString outputStem;
    QString error;
};

bool isSegmentedSdkProtocol(const QString &urlString, const QString &protocol)
{
    const QString value = (urlString + QLatin1Char(' ') + protocol).toLower();
    return value.contains(QStringLiteral("m3u8"))
        || value.contains(QStringLiteral("dash"))
        || value.contains(QStringLiteral("fragmented"));
}

bool parseSdkStreamSpec(const QJsonObject &object,
                        SdkStreamSpec *spec,
                        QString *error)
{
    if (!spec) {
        return false;
    }

    const QString urlString = object.value(QStringLiteral("url")).toString().trimmed();
    const QUrl url(urlString);
    const QString protocol = object.value(QStringLiteral("protocol")).toString().trimmed();
    if (!url.isValid() || url.host().isEmpty()
        || (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https"))) {
        if (error) {
            *error = QStringLiteral("yt-dlp 未返回可直接下载的 HTTP(S) 地址");
        }
        return false;
    }
    spec->url = url;
    spec->protocol = protocol;
    spec->segmented = isSegmentedSdkProtocol(urlString, protocol);
    spec->headers.clear();
    const QJsonValue headerValue = object.value(QStringLiteral("http_headers"));
    if (headerValue.isObject()) {
        const QJsonObject headers = headerValue.toObject();
        for (auto it = headers.constBegin(); it != headers.constEnd(); ++it) {
            const QByteArray name = it.key().toUtf8();
            const QByteArray value = it.value().toString().toUtf8();
            if (!name.isEmpty() && !value.isEmpty()
                && name.compare("Host", Qt::CaseInsensitive) != 0) {
                spec->headers.append(qMakePair(name, value));
            }
        }
    }

    const QJsonValue fileSize = object.value(QStringLiteral("filesize"));
    const QJsonValue approximateFileSize = object.value(QStringLiteral("filesize_approx"));
    const double size = fileSize.isDouble() ? fileSize.toDouble() : approximateFileSize.toDouble();
    spec->expectedBytes = size > 0.0 ? static_cast<qint64>(size) : -1;
    return true;
}

QString safeSdkOutputStem(const QJsonObject &root)
{
    QString title = root.value(QStringLiteral("title")).toString().trimmed();
    QString id = root.value(QStringLiteral("id")).toString().trimmed();
    if (title.isEmpty()) {
        title = id.isEmpty() ? QStringLiteral("download") : id;
    }

    static const QString invalidCharacters = QStringLiteral("<>:\"/\\|?*");
    for (QChar &character : title) {
        if (character.unicode() < 0x20 || invalidCharacters.contains(character)) {
            character = QLatin1Char('_');
        }
    }
    for (QChar &character : id) {
        if (character.unicode() < 0x20 || invalidCharacters.contains(character)) {
            character = QLatin1Char('_');
        }
    }
    id = id.left(64);
    while (!title.isEmpty() && (title.endsWith(QLatin1Char('.')) || title.endsWith(QLatin1Char(' ')))) {
        title.chop(1);
    }
    if (title.isEmpty()) {
        title = QStringLiteral("download");
    }
    title = title.left(180);
    const QString idSuffix = QStringLiteral("[") + id + QLatin1Char(']');
    if (!id.isEmpty() && !title.endsWith(idSuffix)) {
        title += QStringLiteral(" [") + id + QLatin1Char(']');
    }
    return title;
}

bool parseSdkResolvedMedia(const QByteArray &json,
                           SdkResolvedMedia *media)
{
    if (!media) {
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        media->error = QStringLiteral("yt-dlp 返回的媒体解析结果不是有效 JSON");
        return false;
    }

    const QJsonObject root = document.object();
    media->outputStem = safeSdkOutputStem(root);

    const QJsonValue requestedFormatsValue = root.value(QStringLiteral("requested_formats"));
    if (requestedFormatsValue.isArray() && !requestedFormatsValue.toArray().isEmpty()) {
        for (const QJsonValue &value : requestedFormatsValue.toArray()) {
            if (!value.isObject()) {
                continue;
            }
            const QJsonObject format = value.toObject();
            const QString videoCodec = format.value(QStringLiteral("vcodec"))
                                           .toString(QStringLiteral("none"));
            const QString audioCodec = format.value(QStringLiteral("acodec"))
                                           .toString(QStringLiteral("none"));
            SdkStreamSpec spec;
            QString specError;
            if (!parseSdkStreamSpec(format, &spec, &specError)) {
                media->error = specError;
                return false;
            }
            if (videoCodec != QStringLiteral("none") && audioCodec == QStringLiteral("none")) {
                media->video = spec;
            } else if (videoCodec == QStringLiteral("none") && audioCodec != QStringLiteral("none")) {
                media->audio = spec;
            } else if (videoCodec != QStringLiteral("none") && audioCodec != QStringLiteral("none")) {
                media->combined = spec;
            }
        }

        if (!media->video.url.isEmpty() && !media->audio.url.isEmpty()) {
            media->separateStreams = true;
            return true;
        }
        if (!media->combined.url.isEmpty()) {
            return true;
        }
    }

    QString specError;
    if (parseSdkStreamSpec(root, &media->combined, &specError)) {
        media->separateStreams = false;
        return true;
    }
    media->error = specError;
    return false;
}

#endif

} // namespace

DownloadManager::DownloadManager(QObject *parent)
    : QObject(parent)
    , m_androidEngine(this)
{
    m_downloadDirectory = PlatformPaths::defaultDownloadDirectory();

    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] {
        consumeOutput(m_process.readAllStandardOutput(), m_stdoutBuffer);
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        consumeOutput(m_process.readAllStandardError(), m_stderrBuffer);
    });
    connect(&m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
                handleFinished(exitCode, exitStatus);
            });
    connect(&m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
                handleProcessError(error);
            });
#if defined(RECLIP_HAS_FFMPEG_SDK)
    connect(&m_sdkResolver, &ReClip::YtDlp::YtDlpService::finished, this,
        [this](const QString &id, bool ok, const QByteArray &payload,
               const QString &errorCode, const QString &error) {
            if (id == m_sdkYtDlpDownloadRequestId) {
                m_sdkYtDlpDownloadRequestId.clear();
                handleSdkYtDlpDownloadFinished(ok, payload, errorCode, error);
                return;
            }
            if (id != m_sdkResolveRequestId) { return; }
            m_sdkResolveRequestId.clear();
            m_sdkResolveOutput = payload;
            m_sdkResolveError = error.toUtf8();
            handleSdkVideoResolveFinished(ok ? 0 : 1, QProcess::NormalExit);
        });
    connect(&m_ffmpegWatcher,
            &QFutureWatcher<ReClip::Ffmpeg::OperationResult>::finished,
            this,
            &DownloadManager::handleSdkAudioTranscodeFinished);
#endif
    connect(&m_androidEngine,
            &AndroidDownloadEngine::downloadProgress,
            this,
            &DownloadManager::handleAndroidDownloadProgress);
    connect(&m_androidEngine,
            &AndroidDownloadEngine::downloadFinished,
            this,
            &DownloadManager::handleAndroidDownloadFinished);
}

bool DownloadManager::busy() const
{
    return m_process.state() != QProcess::NotRunning
#if defined(RECLIP_HAS_FFMPEG_SDK)
        || m_ffmpegWatcher.isRunning()
        || m_sdkResolving
        || m_sdkYtDlpDownloadActive
        || m_sdkDownloadActive
        || m_sdkFallbackPending
        || m_sdkStarting
#endif
        || !m_androidRequestId.isEmpty()
        || m_exportBusy;
}

QString DownloadManager::state() const
{
    return m_state;
}

QString DownloadManager::statusText() const
{
    return m_statusText;
}

double DownloadManager::progress() const
{
    return m_progress;
}

QString DownloadManager::speed() const
{
    return m_speed;
}

QString DownloadManager::eta() const
{
    return m_eta;
}

QString DownloadManager::outputPath() const
{
    return m_outputPath;
}

QString DownloadManager::errorMessage() const
{
    return m_errorMessage;
}

bool DownloadManager::canRetry() const
{
    return !busy() && !m_sourceUrl.isEmpty()
        && (m_state == QStringLiteral("failed") || m_state == QStringLiteral("cancelled"));
}

QString DownloadManager::outputFormat() const
{
    return m_outputFormat;
}

void DownloadManager::setOutputFormat(const QString &format)
{
    const QString normalized = format.trimmed().toLower();
    const QString next = normalized == QStringLiteral("mp3") ? QStringLiteral("mp3") : QStringLiteral("mp4");
    if (m_outputFormat == next) {
        return;
    }
    m_outputFormat = next;
    emit outputFormatChanged();
}

QString DownloadManager::downloadDirectory() const
{
    return m_downloadDirectory;
}

void DownloadManager::setDownloadDirectory(const QString &path)
{
    const QString cleaned = path.trimmed();
    if (cleaned.isEmpty() || m_downloadDirectory == cleaned) {
        return;
    }
    m_downloadDirectory = QDir::cleanPath(cleaned);
    emit downloadDirectoryChanged();
}

QString DownloadManager::exportDirectoryUri() const
{
    return m_exportDirectoryUri;
}

void DownloadManager::setExportDirectoryUri(const QString &uri)
{
    const QString cleaned = uri.trimmed();
    if (m_exportDirectoryUri == cleaned) {
        return;
    }
    m_exportDirectoryUri = cleaned;
    m_exportedUri.clear();
    emit exportDirectoryChanged();
}

QString DownloadManager::exportedUri() const
{
    return m_exportedUri;
}

PlatformStorage *DownloadManager::platformStorage() const
{
    return m_platformStorage;
}

void DownloadManager::setPlatformStorage(PlatformStorage *storage)
{
    if (m_platformStorage == storage) {
        return;
    }
    if (m_platformStorage) {
        disconnect(m_platformStorage, nullptr, this, nullptr);
    }
    m_platformStorage = storage;
    if (m_platformStorage) {
        connect(m_platformStorage, &PlatformStorage::exportFinished,
                this, &DownloadManager::handleExportFinished);
    }
    emit platformStorageChanged();
}

QString DownloadManager::ytDlpPath() const
{
    return m_ytDlpPath;
}

void DownloadManager::setYtDlpPath(const QString &path)
{
    if (m_ytDlpPath == path) {
        return;
    }
    m_ytDlpPath = path;
    emit toolPathChanged();
}

QString DownloadManager::ffmpegPath() const
{
    return m_ffmpegPath;
}

void DownloadManager::setFfmpegPath(const QString &path)
{
    if (m_ffmpegPath == path) {
        return;
    }
    m_ffmpegPath = path;
    emit toolPathChanged();
}

void DownloadManager::startVideoDownload(const QString &sourceUrl, const QString &formatId)
{
    startDownload(sourceUrl, formatId, QStringLiteral("mp4"));
}

void DownloadManager::startDownload(const QString &sourceUrl, const QString &formatId, const QString &format)
{
    if (busy()) {
        return;
    }

    setOutputFormat(format);

    const QUrl url(sourceUrl.trimmed());
    if (!isHttpUrl(url)) {
        finishFailed(QStringLiteral("请输入有效的 HTTP 或 HTTPS 媒体链接"));
        return;
    }
#ifdef Q_OS_ANDROID
    if (m_androidEngine.available()) {
        QDir directory(m_downloadDirectory);
        if (!directory.exists() && !directory.mkpath(QStringLiteral("."))) {
            finishFailed(QStringLiteral("无法创建下载目录：%1").arg(m_downloadDirectory));
            return;
        }
        if (!hasUsableDownloadStorage(m_downloadDirectory)) {
            finishFailed(QStringLiteral("存储空间不足或下载位置不可用，请清理空间后重试"));
            return;
        }

        resetForStart(url.toString(), formatId.trimmed());
        m_androidRequestId = m_androidEngine.download(
            m_sourceUrl, m_formatId, m_outputFormat, m_downloadDirectory);
        if (m_androidRequestId.isEmpty()) {
            finishFailed(QStringLiteral("无法启动 Android yt-dlp 运行时"));
        }
        return;
    }
#endif

#if defined(RECLIP_HAS_FFMPEG_SDK)
    const bool embeddedResolver = ReClip::YtDlp::YtDlpService::embeddedEnabled()
        && m_ytDlpPath.trimmed().isEmpty();
    const bool sdkVideoEnabled = (m_outputFormat == QStringLiteral("mp4") || embeddedResolver)
        && !m_forceProcessBackend;
    const bool needsProcessFfmpeg = m_outputFormat == QStringLiteral("mp4")
        && !sdkVideoEnabled;
    if ((!embeddedResolver && m_ytDlpPath.trimmed().isEmpty())
        || (needsProcessFfmpeg && m_ffmpegPath.trimmed().isEmpty())) {
#else
    if (m_ytDlpPath.trimmed().isEmpty() || m_ffmpegPath.trimmed().isEmpty()) {
#endif
        finishFailed(QStringLiteral("yt-dlp 或 FFmpeg 不可用，请先完成工具诊断"));
        return;
    }

    QDir directory(m_downloadDirectory);
    if (!directory.exists() && !directory.mkpath(QStringLiteral("."))) {
        finishFailed(QStringLiteral("无法创建下载目录：%1").arg(m_downloadDirectory));
        return;
    }
    if (!hasUsableDownloadStorage(m_downloadDirectory)) {
        finishFailed(QStringLiteral("存储空间不足或下载位置不可用，请清理空间后重试"));
        return;
    }

#if defined(RECLIP_HAS_FFMPEG_SDK)
    m_sdkStarting = true;
#endif
    resetForStart(url.toString(), formatId.trimmed());
#if defined(RECLIP_HAS_FFMPEG_SDK)
    if (sdkVideoEnabled) {
        startSdkVideoResolve();
        if (m_cancelRequested) {
            m_sdkResolver.cancel(m_sdkResolveRequestId);
            m_sdkStarting = false;
            return;
        }
        m_sdkStarting = false;
        return;
    }
#endif

    if (m_cancelRequested) {
#if defined(RECLIP_HAS_FFMPEG_SDK)
        m_sdkStarting = false;
#endif
        finishCancelled();
        return;
    }
    const QString outputTemplate = directory.filePath(QStringLiteral("%(title).200B [%(id)s].%(ext)s"));
    QStringList arguments {
        QStringLiteral("--no-playlist"),
        QStringLiteral("--no-warnings"),
        QStringLiteral("--newline"),
        QStringLiteral("--no-quiet"),
        QStringLiteral("--progress-template"),
        QStringLiteral("download:download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s"),
        QStringLiteral("--print"),
        QStringLiteral("after_move:filepath"),
        QStringLiteral("-o"),
        outputTemplate
    };

    if (m_outputFormat == QStringLiteral("mp3")) {
#if defined(RECLIP_HAS_FFMPEG_SDK)
        arguments += {
            QStringLiteral("-f"),
            QStringLiteral("bestaudio/best")
        };
#else
        arguments += {
            QStringLiteral("--ffmpeg-location"),
            m_ffmpegPath,
            QStringLiteral("-x"),
            QStringLiteral("--audio-format"),
            QStringLiteral("mp3")
        };
#endif
    } else {
        arguments += {
            QStringLiteral("--ffmpeg-location"),
            m_ffmpegPath
        };
        if (m_formatId.isEmpty()) {
            arguments += {QStringLiteral("-f"), QStringLiteral("bestvideo+bestaudio/best")};
        } else {
            arguments += {QStringLiteral("-f"), m_formatId + QStringLiteral("+bestaudio/best")};
        }
        arguments += {
            QStringLiteral("--merge-output-format"),
            QStringLiteral("mp4")
        };
    }
    arguments.append(m_sourceUrl);

    m_process.setProgram(m_ytDlpPath);
    m_process.setArguments(arguments);
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
#if defined(RECLIP_HAS_FFMPEG_SDK)
    m_forceProcessBackend = false;
    m_sdkStarting = false;
#endif
    m_process.start();
    emit stateChanged();
}

void DownloadManager::cancel()
{
    if (!busy()) {
        return;
    }
    m_cancelRequested = true;
    if (!m_androidRequestId.isEmpty()) {
        m_androidEngine.cancel(m_androidRequestId);
        m_statusText = QStringLiteral("正在取消…");
        emit stateChanged();
        return;
    }
#if defined(RECLIP_HAS_FFMPEG_SDK)
    if (m_sdkResolving) {
        m_sdkResolver.cancel(m_sdkResolveRequestId);
        m_statusText = QStringLiteral("正在取消…");
        emit stateChanged();
        return;
    }
    if (m_sdkYtDlpDownloadActive) {
        m_sdkResolver.cancel(m_sdkYtDlpDownloadRequestId);
        m_statusText = QStringLiteral("cancelling");
        emit stateChanged();
        return;
    }
    if (m_sdkFallbackPending) {
        m_sdkFallbackPending = false;
        m_forceProcessBackend = false;
        finishCancelled();
        return;
    }
    if (m_sdkStarting) {
        m_statusText = QStringLiteral("正在取消");
        emit stateChanged();
        return;
    }
    if (m_sdkDownloadActive) {
        m_sdkDownloadActive = false;
        abortSdkVideoDownloads();
        finishCancelled();
        return;
    }
    if (m_ffmpegWatcher.isRunning()) {
        if (m_sdkCancelToken) {
            m_sdkCancelToken->store(true);
        }
        m_statusText = QStringLiteral("正在取消…");
        emit stateChanged();
        return;
    }
#endif
    m_process.terminate();
    m_statusText = QStringLiteral("正在取消…");
    emit stateChanged();
}

void DownloadManager::retry()
{
    if (!canRetry() || m_sourceUrl.isEmpty()) {
        return;
    }
    startDownload(m_sourceUrl, m_formatId, m_outputFormat);
}

void DownloadManager::openOutput()
{
    const QString path = m_outputPath.isEmpty() ? m_downloadDirectory : m_outputPath;
    const QString mimeType = m_outputFormat == QStringLiteral("mp3")
        ? QStringLiteral("audio/mpeg")
        : QStringLiteral("video/mp4");
    if (m_platformStorage) {
        m_platformStorage->openFile(path, m_exportedUri, mimeType);
        return;
    }
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void DownloadManager::shareOutput()
{
    if (m_outputPath.isEmpty()) {
        return;
    }
    const QString mimeType = m_outputFormat == QStringLiteral("mp3")
        ? QStringLiteral("audio/mpeg")
        : QStringLiteral("video/mp4");
    if (m_platformStorage) {
        m_platformStorage->shareFile(m_outputPath, m_exportedUri, mimeType);
        return;
    }
}

void DownloadManager::openDownloadDirectory()
{
    if (m_platformStorage && m_platformStorage->androidStorage()) {
        if (m_exportDirectoryUri.isEmpty()) {
            m_platformStorage->reportError(QStringLiteral("请先在设置中选择导出目录"));
        } else {
            m_platformStorage->openDirectory(m_exportDirectoryUri);
        }
        return;
    }
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_downloadDirectory));
}

void DownloadManager::handleFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    consumeOutput(m_process.readAllStandardOutput(), m_stdoutBuffer);
    consumeOutput(m_process.readAllStandardError(), m_stderrBuffer);

    if (!m_stdoutBuffer.isEmpty()) {
        consumeLine(QString::fromLocal8Bit(m_stdoutBuffer));
        m_stdoutBuffer.clear();
    }
    if (!m_stderrBuffer.isEmpty()) {
        consumeLine(QString::fromLocal8Bit(m_stderrBuffer));
        m_stderrBuffer.clear();
    }

    if (m_cancelRequested) {
        finishCancelled();
        return;
    }
    if (exitStatus == QProcess::NormalExit && exitCode == 0) {
#if defined(RECLIP_HAS_FFMPEG_SDK)
        if (m_outputFormat == QStringLiteral("mp3")) {
            startSdkAudioTranscode();
            return;
        }
#endif
        m_progress = 1.0;
        emit progressChanged();
        if (m_platformStorage && !m_exportDirectoryUri.isEmpty() && !m_outputPath.isEmpty()) {
            const QString displayName = QFileInfo(m_outputPath).fileName();
            const QString mimeType = m_outputFormat == QStringLiteral("mp3")
                ? QStringLiteral("audio/mpeg")
                : QStringLiteral("video/mp4");
            m_pendingExportRequest = m_platformStorage->exportFile(
                m_outputPath, m_exportDirectoryUri, displayName, mimeType);
            if (!m_pendingExportRequest.isEmpty()) {
                m_exportBusy = true;
                m_state = QStringLiteral("exporting");
                m_statusText = QStringLiteral("正在导出");
                emit stateChanged();
                return;
            }
        }
        finishCompleted();
        return;
    }

    const QString rawError = m_errorMessage.isEmpty()
        ? QString::fromLocal8Bit(m_stderrBuffer).trimmed()
        : m_errorMessage;
    finishFailed(rawError.isEmpty() ? QStringLiteral("下载进程异常退出（退出码 %1）").arg(exitCode)
                                    : friendlyError(rawError));
}

void DownloadManager::handleProcessError(QProcess::ProcessError error)
{
    if (error == QProcess::FailedToStart) {
        finishFailed(QStringLiteral("无法启动 yt-dlp，请检查工具路径和执行权限"));
    } else if (m_state != QStringLiteral("completed") && !m_cancelRequested) {
        finishFailed(QStringLiteral("下载进程错误：%1").arg(m_process.errorString()));
    }
}

void DownloadManager::consumeOutput(const QByteArray &data, QByteArray &buffer)
{
    buffer += data;
    int newlineIndex = -1;
    while ((newlineIndex = buffer.indexOf('\n')) >= 0) {
        const QByteArray line = buffer.left(newlineIndex);
        buffer.remove(0, newlineIndex + 1);
        consumeLine(QString::fromLocal8Bit(line));
    }
}

void DownloadManager::consumeLine(const QString &line)
{
    const QString trimmed = line.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    if (trimmed.startsWith(QStringLiteral("download:"))) {
        QString payload = trimmed.mid(QStringLiteral("download:").size());
        if (payload.startsWith(QStringLiteral("download:"))) {
            payload = payload.mid(QStringLiteral("download:").size());
        }
        const QStringList values = payload.split('|', Qt::KeepEmptyParts);
        bool ok = false;
        const double percent = values.value(0).trimmed().remove('%').toDouble(&ok);
        if (ok) {
            m_progress = qBound(0.0, percent / 100.0, 1.0);
        }
        m_speed = values.value(1).trimmed();
        m_eta = values.value(2).trimmed();
        m_state = QStringLiteral("downloading");
        m_statusText = QStringLiteral("下载中");
        emit progressChanged();
        emit stateChanged();
        return;
    }

    const QString destinationPrefix = QStringLiteral("[download] Destination:");
    if (trimmed.startsWith(destinationPrefix)) {
        m_outputPath = trimmed.mid(destinationPrefix.size()).trimmed();
        return;
    }

    const QString mergerPrefix = QStringLiteral("[Merger] Merging formats into:");
    if (trimmed.startsWith(mergerPrefix)) {
        m_outputPath = trimmed.mid(mergerPrefix.size()).trimmed().remove('"');
        return;
    }

    const QFileInfo possiblePath(trimmed);
    if (possiblePath.isAbsolute() && (trimmed.contains(QDir::separator()) || possiblePath.suffix() == QStringLiteral("mp4"))) {
        m_outputPath = possiblePath.absoluteFilePath();
        return;
    }

    if (trimmed.contains(QStringLiteral("ERROR:"), Qt::CaseInsensitive)) {
        m_errorMessage = friendlyError(trimmed);
    }
}

void DownloadManager::finishFailed(const QString &message)
{
#if defined(RECLIP_HAS_FFMPEG_SDK)
    if (m_sdkYtDlpDownloadActive && !m_sdkYtDlpDownloadRequestId.isEmpty()) {
        m_sdkResolver.cancel(m_sdkYtDlpDownloadRequestId);
    }
    m_sdkYtDlpDownloadActive = false;
    m_sdkYtDlpDownloadRequestId.clear();
    if (m_sdkYtDlpProgressTimer) {
        m_sdkYtDlpProgressTimer->stop();
        m_sdkYtDlpProgressTimer->deleteLater();
        m_sdkYtDlpProgressTimer = nullptr;
    }
    m_sdkResolving = false;
    m_sdkDownloadActive = false;
    m_sdkFallbackPending = false;
    m_sdkStarting = false;
#endif
    if (m_state == QStringLiteral("downloading")
        || m_state == QStringLiteral("processing")) {
        cleanupTemporaryFiles();
    }
#if defined(RECLIP_HAS_FFMPEG_SDK)
    // Failed strict jobs must not claim ownership of an existing destination.
    if (m_sdkResolver.usesEmbedded()) { m_outputPath.clear(); }
#endif
    m_state = QStringLiteral("failed");
    m_statusText = QStringLiteral("下载失败");
    m_errorMessage = message;
    m_cancelRequested = false;
    emit stateChanged();
}

void DownloadManager::finishCancelled()
{
#if defined(RECLIP_HAS_FFMPEG_SDK)
    if (m_sdkYtDlpDownloadActive && !m_sdkYtDlpDownloadRequestId.isEmpty()) {
        m_sdkResolver.cancel(m_sdkYtDlpDownloadRequestId);
    }
    m_sdkYtDlpDownloadActive = false;
    m_sdkYtDlpDownloadRequestId.clear();
    if (m_sdkYtDlpProgressTimer) {
        m_sdkYtDlpProgressTimer->stop();
        m_sdkYtDlpProgressTimer->deleteLater();
        m_sdkYtDlpProgressTimer = nullptr;
    }
    m_sdkResolving = false;
    m_sdkDownloadActive = false;
    m_sdkFallbackPending = false;
    m_sdkStarting = false;
#endif
    cleanupTemporaryFiles();
    m_state = QStringLiteral("cancelled");
    m_statusText = QStringLiteral("已取消");
    m_cancelRequested = false;
    emit stateChanged();
}

#if defined(RECLIP_HAS_FFMPEG_SDK)
void DownloadManager::startSdkVideoResolve()
{
    m_sdkResolving = true;
    m_sdkResolveOutput.clear();
    m_sdkResolveError.clear();
    m_state = QStringLiteral("downloading");
    m_statusText = QStringLiteral("正在解析媒体信息");
    m_progress = 0.01;
    m_speed.clear();
    m_eta.clear();
    emit progressChanged();
    emit stateChanged();

    ReClip::YtDlp::Request request;
    request.url = m_sourceUrl;
    request.formatSelector = m_outputFormat == QStringLiteral("mp3")
        ? QStringLiteral("bestaudio/best")
        : (m_formatId.isEmpty() ? QStringLiteral("bestvideo+bestaudio/best")
                               : m_formatId + QStringLiteral("+bestaudio/best"));
    m_sdkResolver.setProgram(m_ytDlpPath);
    m_sdkResolveRequestId = m_sdkResolver.inspect(request);
}

void DownloadManager::handleSdkVideoResolveFinished(int exitCode,
                                                     QProcess::ExitStatus exitStatus)
{
    if (!m_sdkResolving) {
        return;
    }

    m_sdkResolving = false;

    if (m_cancelRequested) {
        finishCancelled();
        return;
    }
    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        const QString rawError = QString::fromLocal8Bit(m_sdkResolveError).trimmed();
        finishFailed(rawError.isEmpty()
                         ? QStringLiteral("yt-dlp 媒体解析失败（退出码 %1）").arg(exitCode)
                         : friendlyError(rawError));
        return;
    }

    SdkResolvedMedia media;
    if (!parseSdkResolvedMedia(m_sdkResolveOutput, &media)) {
        fallbackSdkVideoToProcess(media.error.isEmpty()
                                       ? QStringLiteral("yt-dlp 未返回可供内嵌后端使用的媒体地址")
                                       : media.error);
        return;
    }

    m_outputPath = QDir(m_downloadDirectory).filePath(media.outputStem + QLatin1Char('.') + m_outputFormat);
    if (m_sdkResolver.usesEmbedded() && QFileInfo::exists(m_outputPath)) {
        const QString existingPath = m_outputPath;
        m_outputPath.clear();
        finishFailed(QStringLiteral("目标文件已存在，内嵌模式不会覆盖：%1").arg(existingPath));
        return;
    }
    m_sdkSeparateStreams = media.separateStreams;
    m_sdkCombinedUrl = media.combined.url;
    m_sdkVideoUrl = media.video.url;
    m_sdkAudioUrl = media.audio.url;
    m_sdkCombinedHeaders = media.combined.headers;
    m_sdkVideoHeaders = media.video.headers;
    m_sdkAudioHeaders = media.audio.headers;
    m_sdkCombinedExpectedBytes = media.combined.expectedBytes;
    m_sdkVideoExpectedBytes = media.video.expectedBytes;
    m_sdkAudioExpectedBytes = media.audio.expectedBytes;
    m_sdkCombinedReceivedBytes = 0;
    m_sdkVideoReceivedBytes = 0;
    m_sdkAudioReceivedBytes = 0;
    const bool segmentedInput = media.combined.segmented
        || media.video.segmented
        || media.audio.segmented;
    if (segmentedInput) {
        startSdkSegmentedProcessing();
        return;
    }
    if (!m_sdkSeparateStreams && m_sdkResolver.usesEmbedded()) {
        startSdkYtDlpDownload();
        return;
    }
    m_sdkDownloadActive = true;
    m_state = QStringLiteral("downloading");
    m_statusText = QStringLiteral("正在下载媒体数据");
    m_progress = 0.05;
    emit progressChanged();
    emit stateChanged();

    if (m_sdkSeparateStreams) {
        startSdkVideoDownload(static_cast<int>(SdkStreamKind::Video));
        if (m_sdkDownloadActive) {
            startSdkVideoDownload(static_cast<int>(SdkStreamKind::Audio));
        }
    } else {
        startSdkVideoDownload(static_cast<int>(SdkStreamKind::Combined));
    }
}

void DownloadManager::startSdkYtDlpDownload()
{
    if (!m_sdkResolver.usesEmbedded() || m_sdkSeparateStreams || !m_sdkCombinedUrl.isValid()) {
        m_sdkDownloadActive = true;
        startSdkVideoDownload(static_cast<int>(SdkStreamKind::Combined));
        return;
    }

    const QString inputPath = QFileInfo(m_outputPath).absoluteFilePath()
        + QStringLiteral(".reclip-ytdlp-input");
    QFile::remove(inputPath);
    QFile::remove(inputPath + QStringLiteral(".part"));
    m_sdkYtDlpDownloadPath = inputPath;
    m_sdkYtDlpDownloadActive = true;
    m_state = QStringLiteral("downloading");
    m_statusText = QStringLiteral("正在使用内嵌 yt-dlp 下载媒体");
    m_progress = 0.05;
    m_speed.clear();
    m_eta.clear();

    if (m_sdkYtDlpProgressTimer) {
        m_sdkYtDlpProgressTimer->stop();
        m_sdkYtDlpProgressTimer->deleteLater();
        m_sdkYtDlpProgressTimer = nullptr;
    }
    m_sdkYtDlpProgressTimer = new QTimer(this);
    m_sdkYtDlpProgressTimer->setInterval(200);
    connect(m_sdkYtDlpProgressTimer, &QTimer::timeout, this, [this] {
        if (!m_sdkYtDlpDownloadActive) {
            return;
        }
        const QString partialPath = m_sdkYtDlpDownloadPath + QStringLiteral(".part");
        const QFileInfo partialInfo(partialPath);
        const QFileInfo finalInfo(m_sdkYtDlpDownloadPath);
        const qint64 bytes = partialInfo.isFile() ? partialInfo.size() : finalInfo.size();
        if (bytes >= 0) {
            m_sdkCombinedReceivedBytes = bytes;
        }
        if (m_sdkCombinedExpectedBytes > 0 && bytes >= 0) {
            m_progress = 0.05 + 0.75 * qBound(
                0.0,
                static_cast<double>(bytes) / static_cast<double>(m_sdkCombinedExpectedBytes),
                1.0);
            emit progressChanged();
            emit stateChanged();
        }
    });
    m_sdkYtDlpProgressTimer->start();

    ReClip::YtDlp::Request request;
    request.url = m_sdkCombinedUrl.toString(QUrl::FullyEncoded);
    request.formatSelector = QStringLiteral("best");
    request.outputPath = inputPath;
    request.timeoutSeconds = 30;
    request.headers = m_sdkCombinedHeaders;
    m_sdkResolver.setProgram(m_ytDlpPath);
    m_sdkYtDlpDownloadRequestId = m_sdkResolver.download(request);
    if (m_sdkYtDlpDownloadRequestId.isEmpty()) {
        m_sdkYtDlpDownloadActive = false;
        m_sdkYtDlpDownloadPath.clear();
        m_sdkYtDlpProgressTimer->stop();
        m_sdkYtDlpProgressTimer->deleteLater();
        m_sdkYtDlpProgressTimer = nullptr;
        m_sdkDownloadActive = true;
        startSdkVideoDownload(static_cast<int>(SdkStreamKind::Combined));
    }
    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::handleSdkYtDlpDownloadFinished(bool ok,
                                                      const QByteArray &payload,
                                                      const QString &errorCode,
                                                      const QString &errorMessage)
{
    Q_UNUSED(payload);
    Q_UNUSED(errorCode);
    Q_UNUSED(errorMessage);
    if (!m_sdkYtDlpDownloadActive) {
        return;
    }

    m_sdkYtDlpDownloadActive = false;
    if (m_sdkYtDlpProgressTimer) {
        m_sdkYtDlpProgressTimer->stop();
        m_sdkYtDlpProgressTimer->deleteLater();
        m_sdkYtDlpProgressTimer = nullptr;
    }
    const QString inputPath = m_sdkYtDlpDownloadPath;
    m_sdkYtDlpDownloadPath.clear();

    if (m_cancelRequested) {
        QFile::remove(inputPath);
        QFile::remove(inputPath + QStringLiteral(".part"));
        finishCancelled();
        return;
    }

    if (!ok || !QFileInfo(inputPath).isFile()) {
        // The SDK resolver has already given us a direct URL. If yt-dlp's
        // native downloader cannot handle that particular HTTP response,
        // retain the existing Qt network path as a strict in-process fallback.
        QFile::remove(inputPath);
        QFile::remove(inputPath + QStringLiteral(".part"));
        m_sdkDownloadActive = true;
        m_state = QStringLiteral("downloading");
        m_statusText = QStringLiteral("正在使用 Qt 网络下载媒体");
        m_progress = 0.05;
        emit progressChanged();
        emit stateChanged();
        startSdkVideoDownload(static_cast<int>(SdkStreamKind::Combined));
        return;
    }

    m_sdkCombinedPath = inputPath;
    m_sdkCombinedReceivedBytes = QFileInfo(inputPath).size();
    if (m_sdkCombinedExpectedBytes <= 0) {
        m_sdkCombinedExpectedBytes = m_sdkCombinedReceivedBytes;
    }
    m_sdkDownloadActive = false;
    startSdkVideoProcessing();
}

void DownloadManager::startSdkVideoDownload(int streamKind)
{
    QPointer<QNetworkReply> *replySlot = nullptr;
    QFile *file = nullptr;
    QUrl url;
    QList<QPair<QByteArray, QByteArray>> headers;
    QString path;

    switch (static_cast<SdkStreamKind>(streamKind)) {
    case SdkStreamKind::Combined:
        replySlot = &m_sdkCombinedReply;
        file = &m_sdkCombinedFile;
        url = m_sdkCombinedUrl;
        headers = m_sdkCombinedHeaders;
        m_sdkCombinedPath = m_outputPath + QStringLiteral(".reclip-input.part");
        path = m_sdkCombinedPath;
        break;
    case SdkStreamKind::Video:
        replySlot = &m_sdkVideoReply;
        file = &m_sdkVideoFile;
        url = m_sdkVideoUrl;
        headers = m_sdkVideoHeaders;
        m_sdkVideoPath = m_outputPath + QStringLiteral(".video.part");
        path = m_sdkVideoPath;
        break;
    case SdkStreamKind::Audio:
        replySlot = &m_sdkAudioReply;
        file = &m_sdkAudioFile;
        url = m_sdkAudioUrl;
        headers = m_sdkAudioHeaders;
        m_sdkAudioPath = m_outputPath + QStringLiteral(".audio.part");
        path = m_sdkAudioPath;
        break;
    }

    if (!m_sdkDownloadActive || !replySlot || !file || !url.isValid()) {
        m_sdkDownloadActive = false;
        abortSdkVideoDownloads();
        finishFailed(QStringLiteral("内嵌 FFmpeg 下载阶段没有可用的媒体地址"));
        return;
    }

    if (m_sdkResolver.usesEmbedded()) {
        // Provisional legacy names are not owned by this request.
        switch (static_cast<SdkStreamKind>(streamKind)) {
        case SdkStreamKind::Combined: m_sdkCombinedPath.clear(); break;
        case SdkStreamKind::Video: m_sdkVideoPath.clear(); break;
        case SdkStreamKind::Audio: m_sdkAudioPath.clear(); break;
        }
        QTemporaryFile temporary(path + QStringLiteral("-XXXXXX.part"));
        if (!temporary.open()) {
            m_sdkDownloadActive = false;
            abortSdkVideoDownloads();
            finishFailed(QStringLiteral("无法创建任务专属临时文件"));
            return;
        }
        temporary.setAutoRemove(false);
        path = temporary.fileName();
        switch (static_cast<SdkStreamKind>(streamKind)) {
        case SdkStreamKind::Combined: m_sdkCombinedPath = path; break;
        case SdkStreamKind::Video: m_sdkVideoPath = path; break;
        case SdkStreamKind::Audio: m_sdkAudioPath = path; break;
        }
    } else {
        QFile::remove(path);
    }
    file->setFileName(path);
    if (!file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        m_sdkDownloadActive = false;
        abortSdkVideoDownloads();
        finishFailed(QStringLiteral("无法创建媒体临时文件：%1").arg(path));
        return;
    }

    QNetworkRequest request(url);
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    for (const auto &header : headers) {
        request.setRawHeader(header.first, header.second);
    }

    QNetworkReply *reply = m_sdkNetwork.get(request);
    *replySlot = reply;
    connect(reply, &QNetworkReply::readyRead, this, [reply, file] {
        const QByteArray data = reply->readAll();
        if (!data.isEmpty() && file->write(data) != data.size()) {
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::downloadProgress, this,
            [this, streamKind](qint64 bytesReceived, qint64 bytesTotal) {
                handleSdkVideoDownloadProgress(streamKind, bytesReceived, bytesTotal);
            });
    connect(reply, &QNetworkReply::finished, this,
            [this, streamKind] {
                handleSdkVideoStreamFinished(streamKind);
            });
}

void DownloadManager::handleSdkVideoDownloadProgress(int streamKind,
                                                      qint64 bytesReceived,
                                                      qint64 bytesTotal)
{
    if (!m_sdkDownloadActive) {
        return;
    }

    qint64 *expectedBytes = nullptr;
    qint64 *receivedBytes = nullptr;
    switch (static_cast<SdkStreamKind>(streamKind)) {
    case SdkStreamKind::Combined:
        expectedBytes = &m_sdkCombinedExpectedBytes;
        receivedBytes = &m_sdkCombinedReceivedBytes;
        break;
    case SdkStreamKind::Video:
        expectedBytes = &m_sdkVideoExpectedBytes;
        receivedBytes = &m_sdkVideoReceivedBytes;
        break;
    case SdkStreamKind::Audio:
        expectedBytes = &m_sdkAudioExpectedBytes;
        receivedBytes = &m_sdkAudioReceivedBytes;
        break;
    }
    if (!expectedBytes || !receivedBytes) {
        return;
    }

    *receivedBytes = qMax<qint64>(0, bytesReceived);
    if (bytesTotal > 0) {
        *expectedBytes = bytesTotal;
    }

    qint64 totalExpected = 0;
    qint64 totalReceived = 0;
    if (m_sdkSeparateStreams) {
        totalExpected = m_sdkVideoExpectedBytes + m_sdkAudioExpectedBytes;
        totalReceived = m_sdkVideoReceivedBytes + m_sdkAudioReceivedBytes;
    } else {
        totalExpected = m_sdkCombinedExpectedBytes;
        totalReceived = m_sdkCombinedReceivedBytes;
    }
    const double fraction = totalExpected > 0
        ? qBound(0.0, static_cast<double>(totalReceived) / static_cast<double>(totalExpected), 1.0)
        : 0.0;
    m_progress = 0.05 + 0.75 * fraction;
    m_state = QStringLiteral("downloading");
    m_statusText = QStringLiteral("正在下载媒体数据");
    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::handleSdkVideoStreamFinished(int streamKind)
{
    QPointer<QNetworkReply> *replySlot = nullptr;
    QFile *file = nullptr;
    qint64 *receivedBytes = nullptr;

    switch (static_cast<SdkStreamKind>(streamKind)) {
    case SdkStreamKind::Combined:
        replySlot = &m_sdkCombinedReply;
        file = &m_sdkCombinedFile;
        receivedBytes = &m_sdkCombinedReceivedBytes;
        break;
    case SdkStreamKind::Video:
        replySlot = &m_sdkVideoReply;
        file = &m_sdkVideoFile;
        receivedBytes = &m_sdkVideoReceivedBytes;
        break;
    case SdkStreamKind::Audio:
        replySlot = &m_sdkAudioReply;
        file = &m_sdkAudioFile;
        receivedBytes = &m_sdkAudioReceivedBytes;
        break;
    }

    if (!replySlot || !file || !receivedBytes || !*replySlot) {
        return;
    }

    QNetworkReply *reply = replySlot->data();
    const QByteArray tail = reply->readAll();
    bool writeOk = true;
    if (!tail.isEmpty()) {
        writeOk = file->write(tail) == tail.size();
    }
    file->flush();
    *receivedBytes = file->size();
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool statusOk = statusCode == 0 || (statusCode >= 200 && statusCode < 300);
    const bool success = writeOk && reply->error() == QNetworkReply::NoError && statusOk;
    const QString replyError = reply->errorString();
    const QString fileError = file->errorString();
    file->close();
    *replySlot = nullptr;
    reply->deleteLater();

    if (!success) {
        m_sdkDownloadActive = false;
        abortSdkVideoDownloads();
        const QString detail = !fileError.isEmpty() && !writeOk
            ? fileError
            : (statusCode > 0 ? QStringLiteral("HTTP %1").arg(statusCode) : replyError);
        finishFailed(friendlyError(detail.isEmpty() ? QStringLiteral("媒体网络下载失败") : detail));
        return;
    }

    handleSdkVideoDownloadProgress(streamKind, *receivedBytes,
                                   static_cast<SdkStreamKind>(streamKind) == SdkStreamKind::Combined
                                       ? m_sdkCombinedExpectedBytes
                                       : (static_cast<SdkStreamKind>(streamKind) == SdkStreamKind::Video
                                              ? m_sdkVideoExpectedBytes
                                              : m_sdkAudioExpectedBytes));

    const bool allFinished = m_sdkSeparateStreams
        ? (!m_sdkVideoReply && !m_sdkAudioReply)
        : !m_sdkCombinedReply;
    if (allFinished) {
        m_sdkDownloadActive = false;
        startSdkVideoProcessing();
    }
}

void DownloadManager::startSdkVideoProcessing()
{
    const QString combinedPath = m_sdkCombinedPath;
    const QString videoPath = m_sdkVideoPath;
    const QString audioPath = m_sdkAudioPath;
    const QString outputPath = m_outputPath;
    const bool separateStreams = m_sdkSeparateStreams;
    const bool audioOutput = m_outputFormat == QStringLiteral("mp3");
    if ((separateStreams && (!QFileInfo::exists(videoPath) || !QFileInfo::exists(audioPath)))
        || (!separateStreams && !QFileInfo::exists(combinedPath))) {
        finishFailed(QStringLiteral("媒体下载完成但临时文件不完整"));
        return;
    }

    m_sdkVideoProcessing = true;
    m_state = QStringLiteral("processing");
    m_statusText = audioOutput ? QStringLiteral("正在使用内嵌 FFmpeg 转码")
                              : QStringLiteral("正在使用内嵌 FFmpeg 封装");
    m_progress = 0.85;
    m_speed.clear();
    m_eta.clear();

    const auto cancelToken = std::make_shared<std::atomic_bool>(false);
    m_sdkCancelToken = cancelToken;
    QPointer<DownloadManager> self(this);
    ReClip::Ffmpeg::OperationOptions options;
    options.overwriteExisting = !m_sdkResolver.usesEmbedded();
    options.isCancelled = [cancelToken] {
        return cancelToken->load();
    };
    options.progress = [self](double fraction) {
        if (!self) {
            return;
        }
        QMetaObject::invokeMethod(self.data(), [self, fraction] {
            if (!self || self->m_state != QStringLiteral("processing")) {
                return;
            }
            self->m_progress = 0.85 + 0.14 * qBound(0.0, fraction, 1.0);
            emit self->progressChanged();
        }, Qt::QueuedConnection);
    };

    m_ffmpegWatcher.setFuture(QtConcurrent::run(
        [combinedPath, videoPath, audioPath, outputPath, separateStreams, audioOutput, options] {
            ReClip::Ffmpeg::FfmpegService service;
            const ReClip::Ffmpeg::OperationResult operation = audioOutput
                ? service.transcodeAudio(separateStreams ? audioPath : combinedPath,
                                         outputPath,
                                         {},
                                         options)
                : (separateStreams
                ? service.remux(videoPath, audioPath, outputPath, options)
                : service.remux(combinedPath, outputPath, options));
            return validateSdkOutput(operation, outputPath);
        }));

    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::startSdkSegmentedProcessing()
{
    const auto makeInput = [](const QUrl &url,
                              const QList<QPair<QByteArray, QByteArray>> &headers) {
        ReClip::Ffmpeg::InputSource input;
        input.location = url.toString(QUrl::FullyEncoded);
        input.headers = headers;
        input.timeoutMs = 30000;
        return input;
    };

    const ReClip::Ffmpeg::InputSource combined =
        makeInput(m_sdkCombinedUrl, m_sdkCombinedHeaders);
    const ReClip::Ffmpeg::InputSource video =
        makeInput(m_sdkVideoUrl, m_sdkVideoHeaders);
    const ReClip::Ffmpeg::InputSource audio =
        makeInput(m_sdkAudioUrl, m_sdkAudioHeaders);
    const QString outputPath = m_outputPath;
    const bool separateStreams = m_sdkSeparateStreams;
    const bool audioOutput = m_outputFormat == QStringLiteral("mp3");
    if ((separateStreams && (video.location.isEmpty() || audio.location.isEmpty()))
        || (!separateStreams && combined.location.isEmpty())) {
        finishFailed(QStringLiteral("分段媒体缺少可用的 HTTP(S) 播放列表地址"));
        return;
    }

    m_sdkVideoProcessing = true;
    m_sdkSegmentedProcessing = true;
    m_state = QStringLiteral("processing");
    m_statusText = audioOutput ? QStringLiteral("正在使用内嵌 FFmpeg 下载并转码")
                              : QStringLiteral("正在使用内嵌 FFmpeg 下载并封装");
    m_progress = 0.10;
    m_speed.clear();
    m_eta.clear();

    const auto cancelToken = std::make_shared<std::atomic_bool>(false);
    m_sdkCancelToken = cancelToken;
    QPointer<DownloadManager> self(this);
    ReClip::Ffmpeg::OperationOptions options;
    options.overwriteExisting = !m_sdkResolver.usesEmbedded();
    options.isCancelled = [cancelToken] {
        return cancelToken->load();
    };
    options.progress = [self](double fraction) {
        if (!self) {
            return;
        }
        QMetaObject::invokeMethod(self.data(), [self, fraction] {
            if (!self || self->m_state != QStringLiteral("processing")) {
                return;
            }
            self->m_progress = 0.10 + 0.84 * qBound(0.0, fraction, 1.0);
            emit self->progressChanged();
        }, Qt::QueuedConnection);
    };

    m_ffmpegWatcher.setFuture(QtConcurrent::run(
        [combined, video, audio, outputPath, separateStreams, audioOutput, options] {
            ReClip::Ffmpeg::FfmpegService service;
            const ReClip::Ffmpeg::OperationResult operation = audioOutput
                ? service.transcodeAudio(separateStreams ? audio : combined,
                                         outputPath,
                                         {},
                                         options)
                : (separateStreams
                ? service.remux(video, audio, outputPath, options)
                : service.remux(combined, outputPath, options));
            return validateSdkOutput(operation, outputPath);
        }));

    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::abortSdkVideoDownloads()
{
    const auto abortReply = [this](QPointer<QNetworkReply> &replySlot) {
        QNetworkReply *reply = replySlot.data();
        replySlot = nullptr;
        if (!reply) {
            return;
        }
        disconnect(reply, nullptr, this, nullptr);
        reply->abort();
        reply->deleteLater();
    };

    abortReply(m_sdkCombinedReply);
    abortReply(m_sdkVideoReply);
    abortReply(m_sdkAudioReply);
    m_sdkCombinedFile.close();
    m_sdkVideoFile.close();
    m_sdkAudioFile.close();
}

void DownloadManager::fallbackSdkVideoToProcess(const QString &reason)
{
    m_sdkResolving = false;
    if (m_sdkDownloadActive) {
        m_sdkDownloadActive = false;
        abortSdkVideoDownloads();
    }
    if (m_cancelRequested) {
        finishCancelled();
        return;
    }
    if (m_sdkResolver.usesEmbedded()) {
        finishFailed(QStringLiteral("严格内嵌模式暂不支持该媒体：%1；不会自动启动外部程序").arg(reason));
        return;
    }
    if (m_ffmpegPath.trimmed().isEmpty()) {
        finishFailed(QStringLiteral("内嵌 FFmpeg 暂不支持该媒体格式（%1），且未配置命令行 FFmpeg")
                         .arg(reason));
        return;
    }

    cleanupTemporaryFiles();
    m_forceProcessBackend = true;
    m_sdkFallbackPending = true;
    m_statusText = QStringLiteral("正在切换兼容下载模式");
    emit stateChanged();
    QTimer::singleShot(100, this, [this] {
        if (!m_sdkFallbackPending) {
            return;
        }
        m_sdkFallbackPending = false;
        if (m_cancelRequested) {
            m_forceProcessBackend = false;
            finishCancelled();
            return;
        }
        startDownload(m_sourceUrl, m_formatId, m_outputFormat);
    });
}

void DownloadManager::startSdkAudioTranscode()
{
    const QString inputPath = m_outputPath;
    const QFileInfo inputInfo(inputPath);
    if (!inputInfo.isFile()) {
        finishFailed(QStringLiteral("下载完成但没有找到待处理的音频文件"));
        return;
    }

    if (inputInfo.suffix().compare(QStringLiteral("mp3"), Qt::CaseInsensitive) == 0) {
        m_progress = 1.0;
        emit progressChanged();
        finishCompleted();
        return;
    }

    const QString outputPath = QDir(inputInfo.absolutePath()).filePath(
        inputInfo.completeBaseName() + QStringLiteral(".mp3"));
    m_sdkInputPath = inputPath;
    m_outputPath = outputPath;
    m_state = QStringLiteral("processing");
    m_statusText = QStringLiteral("正在使用内嵌 FFmpeg 转码");
    m_progress = 0.85;
    m_speed.clear();
    m_eta.clear();

    const auto cancelToken = std::make_shared<std::atomic_bool>(false);
    m_sdkCancelToken = cancelToken;
    QPointer<DownloadManager> self(this);
    ReClip::Ffmpeg::OperationOptions options;
    options.isCancelled = [cancelToken] {
        return cancelToken->load();
    };
    options.progress = [self](double fraction) {
        if (!self) {
            return;
        }
        QMetaObject::invokeMethod(self.data(), [self, fraction] {
            if (!self || self->m_state != QStringLiteral("processing")) {
                return;
            }
            self->m_progress = 0.85 + 0.14 * qBound(0.0, fraction, 1.0);
            emit self->progressChanged();
        }, Qt::QueuedConnection);
    };

    m_ffmpegWatcher.setFuture(QtConcurrent::run([inputPath, outputPath, options] {
        ReClip::Ffmpeg::FfmpegService service;
        return validateSdkOutput(
            service.transcodeAudio(inputPath, outputPath, {}, options),
            outputPath);
    }));

    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::handleSdkAudioTranscodeFinished()
{
    const ReClip::Ffmpeg::OperationResult result = m_ffmpegWatcher.result();
    const bool videoProcessing = m_sdkVideoProcessing;
    const bool segmentedProcessing = m_sdkSegmentedProcessing;
    const QString inputPath = m_sdkInputPath;
    const QString combinedPath = m_sdkCombinedPath;
    const QString videoPath = m_sdkVideoPath;
    const QString audioPath = m_sdkAudioPath;
    m_sdkInputPath.clear();
    m_sdkCombinedPath.clear();
    m_sdkVideoPath.clear();
    m_sdkAudioPath.clear();
    m_sdkVideoProcessing = false;
    m_sdkSegmentedProcessing = false;
    m_sdkSeparateStreams = false;
    m_sdkCancelToken.reset();
    if (videoProcessing) {
        if (!combinedPath.isEmpty()) { QFile::remove(combinedPath); }
        if (!videoPath.isEmpty()) { QFile::remove(videoPath); }
        if (!audioPath.isEmpty()) { QFile::remove(audioPath); }
    } else {
        if (!inputPath.isEmpty()) { QFile::remove(inputPath); }
    }

    if (m_cancelRequested) {
        finishCancelled();
        return;
    }
    if (!result.ok) {
        if (segmentedProcessing && !m_sdkResolver.usesEmbedded() && !m_cancelRequested) {
            fallbackSdkVideoToProcess(result.error.message.isEmpty()
                                          ? QStringLiteral("内嵌 FFmpeg 无法处理该分段媒体")
                                          : result.error.message);
            return;
        }
        const QString message = result.error.message.isEmpty()
            ? QStringLiteral("内嵌 FFmpeg 音频转码失败")
            : result.error.message;
        finishFailed(friendlyError(message));
        return;
    }

    m_progress = 1.0;
    emit progressChanged();
    if (m_platformStorage && !m_exportDirectoryUri.isEmpty() && !m_outputPath.isEmpty()) {
        const QString displayName = QFileInfo(m_outputPath).fileName();
        m_pendingExportRequest = m_platformStorage->exportFile(
            m_outputPath,
            m_exportDirectoryUri,
            displayName,
            m_outputFormat == QStringLiteral("mp3") ? QStringLiteral("audio/mpeg") : QStringLiteral("video/mp4"));
        if (!m_pendingExportRequest.isEmpty()) {
            m_exportBusy = true;
            m_state = QStringLiteral("exporting");
            m_statusText = QStringLiteral("正在导出");
            emit stateChanged();
            return;
        }
    }
    finishCompleted();
}
#endif

void DownloadManager::handleAndroidDownloadProgress(const QString &requestId,
                                                     double progress,
                                                     const QString &eta,
                                                     const QString &speed,
                                                     const QString &line)
{
    if (requestId != m_androidRequestId) {
        return;
    }

    m_progress = progress;
    m_speed = speed;
    m_eta = eta;
    if (!line.isEmpty() && m_speed.isEmpty()) {
        m_speed = line;
    }
    m_state = QStringLiteral("downloading");
    m_statusText = QStringLiteral("下载中");
    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::handleAndroidDownloadFinished(const QString &requestId,
                                                     bool success,
                                                     const QByteArray &payload,
                                                     const QString &errorCode,
                                                     const QString &errorMessage)
{
    if (requestId != m_androidRequestId) {
        return;
    }

    m_androidRequestId.clear();
    if (m_cancelRequested || errorCode == QStringLiteral("cancelled") || !success) {
        if (m_cancelRequested || errorCode == QStringLiteral("cancelled")) {
            finishCancelled();
        } else {
            finishFailed(friendlyError(errorMessage));
        }
        return;
    }

    const QJsonDocument document = QJsonDocument::fromJson(payload);
    if (document.isObject()) {
        m_outputPath = document.object().value(QStringLiteral("path")).toString().trimmed();
    }
    if (m_outputPath.isEmpty() || !QFileInfo(m_outputPath).isFile()) {
        finishFailed(QStringLiteral("下载完成但没有找到输出文件"));
        return;
    }

    m_progress = 1.0;
    emit progressChanged();
    if (m_platformStorage && !m_exportDirectoryUri.isEmpty()) {
        const QString displayName = QFileInfo(m_outputPath).fileName();
        const QString mimeType = m_outputFormat == QStringLiteral("mp3")
            ? QStringLiteral("audio/mpeg")
            : QStringLiteral("video/mp4");
        m_pendingExportRequest = m_platformStorage->exportFile(
            m_outputPath, m_exportDirectoryUri, displayName, mimeType);
        if (!m_pendingExportRequest.isEmpty()) {
            m_exportBusy = true;
            m_state = QStringLiteral("exporting");
            m_statusText = QStringLiteral("正在导出");
            emit stateChanged();
            return;
        }
    }
    finishCompleted();
}

void DownloadManager::finishCompleted()
{
    m_exportBusy = false;
    m_pendingExportRequest.clear();
    m_state = QStringLiteral("completed");
    m_statusText = QStringLiteral("下载完成");
    m_errorMessage.clear();
    m_cancelRequested = false;
    emit stateChanged();
}

void DownloadManager::handleExportFinished(const QString &requestId,
                                           bool success,
                                           const QString &exportedUri,
                                           const QString &errorMessage)
{
    if (requestId != m_pendingExportRequest) {
        return;
    }

    m_exportBusy = false;
    m_pendingExportRequest.clear();
    if (success) {
        m_exportedUri = exportedUri;
        finishCompleted();
        return;
    }

    // Keep the private copy usable even when the user revoked the export
    // permission or the selected provider ran out of space.
    m_state = QStringLiteral("completed");
    m_statusText = QStringLiteral("下载完成，但导出失败");
    m_errorMessage = errorMessage.isEmpty() ? QStringLiteral("文件导出失败") : errorMessage;
    m_cancelRequested = false;
    emit stateChanged();
}

void DownloadManager::resetForStart(const QString &sourceUrl, const QString &formatId)
{
    m_sourceUrl = sourceUrl;
    m_formatId = formatId;
    m_stdoutBuffer.clear();
    m_stderrBuffer.clear();
    m_speed.clear();
    m_eta.clear();
    m_outputPath.clear();
#if defined(RECLIP_HAS_FFMPEG_SDK)
    abortSdkVideoDownloads();
    if (m_sdkYtDlpProgressTimer) {
        m_sdkYtDlpProgressTimer->stop();
        m_sdkYtDlpProgressTimer->deleteLater();
        m_sdkYtDlpProgressTimer = nullptr;
    }
    if (!m_sdkYtDlpDownloadPath.isEmpty()) {
        QFile::remove(m_sdkYtDlpDownloadPath);
        QFile::remove(m_sdkYtDlpDownloadPath + QStringLiteral(".part"));
    }
    m_sdkYtDlpDownloadRequestId.clear();
    m_sdkYtDlpDownloadPath.clear();
    m_sdkInputPath.clear();
    m_sdkCombinedPath.clear();
    m_sdkVideoPath.clear();
    m_sdkAudioPath.clear();
    m_sdkCombinedUrl = {};
    m_sdkVideoUrl = {};
    m_sdkAudioUrl = {};
    m_sdkCombinedHeaders.clear();
    m_sdkVideoHeaders.clear();
    m_sdkAudioHeaders.clear();
    m_sdkCombinedExpectedBytes = -1;
    m_sdkVideoExpectedBytes = -1;
    m_sdkAudioExpectedBytes = -1;
    m_sdkCombinedReceivedBytes = 0;
    m_sdkVideoReceivedBytes = 0;
    m_sdkAudioReceivedBytes = 0;
    m_sdkResolving = false;
    m_sdkYtDlpDownloadActive = false;
    m_sdkDownloadActive = false;
    m_sdkFallbackPending = false;
    m_sdkVideoProcessing = false;
    m_sdkSegmentedProcessing = false;
    m_sdkSeparateStreams = false;
    m_sdkResolveOutput.clear();
    m_sdkResolveError.clear();
#endif
    m_exportedUri.clear();
    m_pendingExportRequest.clear();
    m_exportBusy = false;
    m_errorMessage.clear();
    m_progress = 0.0;
    m_state = QStringLiteral("downloading");
    m_statusText = QStringLiteral("准备下载");
    m_cancelRequested = false;
    emit progressChanged();
    emit stateChanged();
}

void DownloadManager::cleanupTemporaryFiles()
{
#if defined(RECLIP_HAS_FFMPEG_SDK)
    if (!m_sdkInputPath.isEmpty()) {
        m_sdkInputPath = QDir::cleanPath(m_sdkInputPath);
        QFile::remove(m_sdkInputPath);
    }
    m_sdkCombinedFile.close();
    m_sdkVideoFile.close();
    m_sdkAudioFile.close();
    if (!m_sdkCombinedPath.isEmpty()) {
        QFile::remove(m_sdkCombinedPath);
    }
    if (!m_sdkVideoPath.isEmpty()) {
        QFile::remove(m_sdkVideoPath);
    }
    if (!m_sdkAudioPath.isEmpty()) {
        QFile::remove(m_sdkAudioPath);
    }
    if (!m_sdkYtDlpDownloadPath.isEmpty()) {
        QFile::remove(m_sdkYtDlpDownloadPath);
        QFile::remove(m_sdkYtDlpDownloadPath + QStringLiteral(".part"));
    }
    if (m_sdkResolver.usesEmbedded()) { return; }
#endif
    if (m_outputPath.isEmpty()) {
        return;
    }

    QFile::remove(m_outputPath + QStringLiteral(".part"));
    QFile::remove(m_outputPath + QStringLiteral(".ytdl"));
}

QString DownloadManager::friendlyError(const QString &rawMessage)
{
    const QString message = rawMessage.trimmed();
    const QString lower = message.toLower();
    if (lower.contains(QStringLiteral("no space left on device"))
        || lower.contains(QStringLiteral("not enough space"))
        || lower.contains(QStringLiteral("disk full"))
        || lower.contains(QStringLiteral("insufficient storage"))
        || lower.contains(QStringLiteral("errno 28"))) {
        return QStringLiteral("存储空间不足，请清理空间后重试");
    }
    if (lower.contains(QStringLiteral("connection refused"))
        || lower.contains(QStringLiteral("connection reset"))
        || lower.contains(QStringLiteral("connection aborted"))
        || lower.contains(QStringLiteral("software caused connection abort"))
        || lower.contains(QStringLiteral("errno 103"))
        || lower.contains(QStringLiteral("remote end closed"))
        || lower.contains(QStringLiteral("network is unreachable"))
        || lower.contains(QStringLiteral("could not resolve host"))
        || lower.contains(QStringLiteral("name or service not known"))
        || lower.contains(QStringLiteral("temporary failure in name resolution"))) {
        return QStringLiteral("网络连接中断，请检查网络后重试");
    }
    if (lower.contains(QStringLiteral("unsupported url"))) {
        return QStringLiteral("该链接格式不受支持");
    }
    if (lower.contains(QStringLiteral("private video")) || lower.contains(QStringLiteral("video unavailable"))) {
        return QStringLiteral("媒体不可公开访问或需要登录");
    }
    if (lower.contains(QStringLiteral("http error 404"))) {
        return QStringLiteral("找不到该媒体，链接可能已失效");
    }
    if (lower.contains(QStringLiteral("timed out")) || lower.contains(QStringLiteral("timeout"))) {
        return QStringLiteral("网络请求超时，请重试");
    }
    return message.isEmpty() ? QStringLiteral("下载失败，请检查网络和工具状态") : message;
}

bool DownloadManager::isHttpUrl(const QUrl &url)
{
    const QString scheme = url.scheme().toLower();
    return url.isValid() && !url.host().isEmpty() && (scheme == QStringLiteral("http") || scheme == QStringLiteral("https"));
}
