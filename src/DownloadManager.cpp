#include "DownloadManager.h"

#include <QDir>
#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

DownloadManager::DownloadManager(QObject *parent)
    : QObject(parent)
{
    const QString downloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    m_downloadDirectory = QDir(downloads).filePath(QStringLiteral("ReClip"));

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
}

bool DownloadManager::busy() const
{
    return m_process.state() != QProcess::NotRunning;
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
    if (m_ytDlpPath.trimmed().isEmpty() || m_ffmpegPath.trimmed().isEmpty()) {
        finishFailed(QStringLiteral("yt-dlp 或 FFmpeg 不可用，请先完成工具诊断"));
        return;
    }

    QDir directory(m_downloadDirectory);
    if (!directory.exists() && !directory.mkpath(QStringLiteral("."))) {
        finishFailed(QStringLiteral("无法创建下载目录：%1").arg(m_downloadDirectory));
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
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void DownloadManager::openDownloadDirectory()
{
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
        m_state = QStringLiteral("completed");
        m_statusText = QStringLiteral("下载完成");
        m_errorMessage.clear();
        emit progressChanged();
        emit stateChanged();
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

void DownloadManager::resetForStart(const QString &sourceUrl, const QString &formatId)
{
    m_sourceUrl = sourceUrl;
    m_formatId = formatId;
    m_stdoutBuffer.clear();
    m_stderrBuffer.clear();
    m_speed.clear();
    m_eta.clear();
    m_outputPath.clear();
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
