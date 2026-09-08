#include "DownloadManager.h"
#include "PlatformPaths.h"

#include <QDir>
#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QStorageInfo>
#include <QStandardPaths>

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

    if (m_ytDlpPath.trimmed().isEmpty() || m_ffmpegPath.trimmed().isEmpty()) {
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

    resetForStart(url.toString(), formatId.trimmed());
    const QString outputTemplate = directory.filePath(QStringLiteral("%(title).200B [%(id)s].%(ext)s"));
    QStringList arguments {
        QStringLiteral("--no-playlist"),
        QStringLiteral("--no-warnings"),
        QStringLiteral("--newline"),
        QStringLiteral("--no-quiet"),
        QStringLiteral("--ffmpeg-location"),
        m_ffmpegPath,
        QStringLiteral("--progress-template"),
        QStringLiteral("download:download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s"),
        QStringLiteral("--print"),
        QStringLiteral("after_move:filepath"),
        QStringLiteral("-o"),
        outputTemplate
    };

    if (m_outputFormat == QStringLiteral("mp3")) {
        arguments += {
            QStringLiteral("-x"),
            QStringLiteral("--audio-format"),
            QStringLiteral("mp3")
        };
    } else {
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
    if (m_state == QStringLiteral("downloading")) {
        cleanupTemporaryFiles();
    }
    m_state = QStringLiteral("failed");
    m_statusText = QStringLiteral("下载失败");
    m_errorMessage = message;
    m_cancelRequested = false;
    emit stateChanged();
}

void DownloadManager::finishCancelled()
{
    cleanupTemporaryFiles();
    m_state = QStringLiteral("cancelled");
    m_statusText = QStringLiteral("已取消");
    m_cancelRequested = false;
    emit stateChanged();
}

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
                                                     const QString &outputPath,
                                                     const QString &errorMessage)
{
    if (requestId != m_androidRequestId) {
        return;
    }

    m_androidRequestId.clear();
    if (m_cancelRequested || !success) {
        if (m_cancelRequested) {
            finishCancelled();
        } else {
            finishFailed(friendlyError(errorMessage));
        }
        return;
    }

    m_outputPath = outputPath;
    if (m_outputPath.isEmpty()) {
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
