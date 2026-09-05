#include "DownloadQueue.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUuid>

#include <algorithm>

DownloadQueue::DownloadQueue(QObject *parent)
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

QVariantList DownloadQueue::tasks() const
{
    QVariantList result;
    result.reserve(m_tasks.size());
    for (const Task &task : m_tasks) {
        QVariantMap value;
        value.insert(QStringLiteral("id"), task.id);
        value.insert(QStringLiteral("sourceUrl"), task.sourceUrl);
        value.insert(QStringLiteral("title"), task.title);
        value.insert(QStringLiteral("format"), task.format.toUpper());
        value.insert(QStringLiteral("state"), task.state);
        value.insert(QStringLiteral("statusText"), task.statusText);
        value.insert(QStringLiteral("speed"), task.speed);
        value.insert(QStringLiteral("eta"), task.eta);
        value.insert(QStringLiteral("outputPath"), task.outputPath);
        value.insert(QStringLiteral("errorMessage"), task.errorMessage);
        value.insert(QStringLiteral("progress"), task.progress);
        value.insert(QStringLiteral("canRetry"), task.state == QStringLiteral("failed")
                    || task.state == QStringLiteral("cancelled"));
        value.insert(QStringLiteral("canCancel"), task.state == QStringLiteral("queued")
                    || task.state == QStringLiteral("waiting")
                    || task.state == QStringLiteral("downloading"));
        result.append(value);
    }
    return result;
}

bool DownloadQueue::running() const
{
    return m_queueRequested || m_activeIndex >= 0;
}

QString DownloadQueue::statusText() const
{
    return m_statusText;
}

QString DownloadQueue::downloadDirectory() const
{
    return m_downloadDirectory;
}

void DownloadQueue::setDownloadDirectory(const QString &path)
{
    const QString cleaned = path.trimmed();
    if (cleaned.isEmpty() || m_downloadDirectory == cleaned) {
        return;
    }
    m_downloadDirectory = QDir::cleanPath(cleaned);
    emit downloadDirectoryChanged();
}

QString DownloadQueue::ytDlpPath() const
{
    return m_ytDlpPath;
}

void DownloadQueue::setYtDlpPath(const QString &path)
{
    if (m_ytDlpPath == path) {
        return;
    }
    m_ytDlpPath = path;
    emit toolPathChanged();
}

QString DownloadQueue::ffmpegPath() const
{
    return m_ffmpegPath;
}

void DownloadQueue::setFfmpegPath(const QString &path)
{
    if (m_ffmpegPath == path) {
        return;
    }
    m_ffmpegPath = path;
    emit toolPathChanged();
}

void DownloadQueue::addUrls(const QString &rawInput, const QString &format)
{
    const QStringList values = rawInput.split(QRegularExpression(QStringLiteral("[\\s,]+")), Qt::SkipEmptyParts);
    for (const QString &value : values) {
        addTask(value, {}, format);
    }
}

void DownloadQueue::addTask(const QString &sourceUrl, const QString &formatId, const QString &format)
{
    const QUrl url(sourceUrl.trimmed());
    if (!isHttpUrl(url)) {
        return;
    }
    const QString normalizedUrl = url.toString();
    if (std::any_of(m_tasks.cbegin(), m_tasks.cend(), [&](const Task &task) {
            return task.sourceUrl == normalizedUrl;
        })) {
        return;
    }

    Task task;
    task.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    task.sourceUrl = normalizedUrl;
    task.title = url.host() + url.path();
    task.formatId = formatId.trimmed();
    task.format = normalizeFormat(format);
    m_tasks.append(task);
    m_statusText = QStringLiteral("队列中有 %1 个任务").arg(m_tasks.size());
    notifyQueueChanged();
}

void DownloadQueue::startAll()
{
    if (m_tasks.isEmpty()) {
        m_statusText = QStringLiteral("队列为空");
        emit queueChanged();
        return;
    }

    m_queueRequested = true;
    for (Task &task : m_tasks) {
        if (task.state == QStringLiteral("queued")) {
            task.state = QStringLiteral("waiting");
            task.statusText = QStringLiteral("等待前一项完成");
        }
    }
    m_statusText = QStringLiteral("正在按顺序处理队列");
    notifyQueueChanged();
    startNext();
}

void DownloadQueue::cancelTask(const QString &taskId)
{
    const int index = indexForId(taskId);
    if (index < 0) {
        return;
    }
    Task &task = m_tasks[index];
    if (index == m_activeIndex) {
        task.cancelRequested = true;
        task.statusText = QStringLiteral("正在取消…");
        m_process.terminate();
    } else if (task.state == QStringLiteral("queued") || task.state == QStringLiteral("waiting")) {
        task.state = QStringLiteral("cancelled");
        task.statusText = QStringLiteral("已取消");
    }
    notifyQueueChanged();
}

void DownloadQueue::retryTask(const QString &taskId)
{
    const int index = indexForId(taskId);
    if (index < 0 || m_tasks[index].state != QStringLiteral("failed")
        && m_tasks[index].state != QStringLiteral("cancelled")) {
        return;
    }

    Task &task = m_tasks[index];
    task.state = QStringLiteral("queued");
    task.statusText = QStringLiteral("等待下载");
    task.progress = 0.0;
    task.speed.clear();
    task.eta.clear();
    task.outputPath.clear();
    task.errorMessage.clear();
    task.cancelRequested = false;
    task.removeAfterFinish = false;
    m_queueRequested = true;
    notifyQueueChanged();
    startNext();
}

void DownloadQueue::removeTask(const QString &taskId)
{
    const int index = indexForId(taskId);
    if (index < 0) {
        return;
    }
    if (index == m_activeIndex) {
        m_tasks[index].removeAfterFinish = true;
        m_tasks[index].cancelRequested = true;
        m_tasks[index].statusText = QStringLiteral("正在删除…");
        m_process.terminate();
        notifyQueueChanged();
        return;
    }

    moveTaskFilesToTrash(m_tasks[index]);
    m_tasks.removeAt(index);
    notifyQueueChanged();
}

void DownloadQueue::clearCompleted()
{
    for (int index = m_tasks.size() - 1; index >= 0; --index) {
        if (index != m_activeIndex && m_tasks[index].state == QStringLiteral("completed")) {
            moveTaskFilesToTrash(m_tasks[index]);
            m_tasks.removeAt(index);
        }
    }
    notifyQueueChanged();
}

void DownloadQueue::openTask(const QString &taskId)
{
    const int index = indexForId(taskId);
    if (index < 0) {
        return;
    }
    const Task &task = m_tasks[index];
    const QString path = task.outputPath.isEmpty() ? m_downloadDirectory : task.outputPath;
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

int DownloadQueue::indexForId(const QString &taskId) const
{
    for (int index = 0; index < m_tasks.size(); ++index) {
        if (m_tasks[index].id == taskId) {
            return index;
        }
    }
    return -1;
}

void DownloadQueue::startNext()
{
    if (m_activeIndex >= 0 || !m_queueRequested) {
        return;
    }

    for (int index = 0; index < m_tasks.size(); ++index) {
        if (m_tasks[index].state == QStringLiteral("waiting")
            || m_tasks[index].state == QStringLiteral("queued")) {
            startTask(index);
            if (m_activeIndex >= 0) {
                return;
            }
        }
    }

    m_queueRequested = false;
    m_statusText = QStringLiteral("队列处理完成");
    emit queueChanged();
}

void DownloadQueue::startTask(int index)
{
    Task &task = m_tasks[index];
    if (m_ytDlpPath.trimmed().isEmpty() || m_ffmpegPath.trimmed().isEmpty()) {
        task.state = QStringLiteral("failed");
        task.statusText = QStringLiteral("工具不可用");
        task.errorMessage = QStringLiteral("yt-dlp 或 FFmpeg 不可用，请先完成工具诊断");
        notifyQueueChanged();
        return;
    }

    QDir directory(m_downloadDirectory);
    if (!directory.exists() && !directory.mkpath(QStringLiteral("."))) {
        task.state = QStringLiteral("failed");
        task.statusText = QStringLiteral("下载目录不可用");
        task.errorMessage = QStringLiteral("无法创建下载目录：%1").arg(m_downloadDirectory);
        notifyQueueChanged();
        return;
    }

    m_activeIndex = index;
    m_stdoutBuffer.clear();
    m_stderrBuffer.clear();
    m_lastErrorText.clear();
    task.state = QStringLiteral("downloading");
    task.statusText = QStringLiteral("下载中");
    task.progress = 0.0;
    task.speed.clear();
    task.eta.clear();
    task.errorMessage.clear();
    task.cancelRequested = false;

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

    if (task.format == QStringLiteral("mp3")) {
        arguments += {QStringLiteral("-x"), QStringLiteral("--audio-format"), QStringLiteral("mp3")};
    } else {
        arguments += {QStringLiteral("-f"), task.formatId.isEmpty()
                         ? QStringLiteral("bestvideo+bestaudio/best")
                         : task.formatId + QStringLiteral("+bestaudio/best")};
        arguments += {QStringLiteral("--merge-output-format"), QStringLiteral("mp4")};
    }
    arguments.append(task.sourceUrl);

    m_process.setProgram(m_ytDlpPath);
    m_process.setArguments(arguments);
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_process.start();
    notifyQueueChanged();
}

void DownloadQueue::handleFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }

    const int index = m_activeIndex;
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

    Task &task = m_tasks[index];
    if (task.cancelRequested) {
        finishActive(QStringLiteral("cancelled"), QStringLiteral("已取消"));
    } else if (exitStatus == QProcess::NormalExit && exitCode == 0) {
        task.progress = 1.0;
        finishActive(QStringLiteral("completed"), QStringLiteral("下载完成"));
    } else {
        const QString message = m_lastErrorText.isEmpty()
            ? QStringLiteral("下载进程异常退出（退出码 %1）").arg(exitCode)
            : friendlyError(m_lastErrorText);
        finishActive(QStringLiteral("failed"), QStringLiteral("下载失败"), message);
    }
}

void DownloadQueue::handleProcessError(QProcess::ProcessError error)
{
    if (m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }
    if (m_tasks[m_activeIndex].cancelRequested) {
        return;
    }
    const QString message = error == QProcess::FailedToStart
        ? QStringLiteral("无法启动 yt-dlp，请检查工具路径和执行权限")
        : QStringLiteral("下载进程错误：%1").arg(m_process.errorString());
    finishActive(QStringLiteral("failed"), QStringLiteral("下载失败"), message);
}

void DownloadQueue::consumeOutput(const QByteArray &data, QByteArray &buffer)
{
    buffer += data;
    int newlineIndex = -1;
    while ((newlineIndex = buffer.indexOf('\n')) >= 0) {
        const QByteArray line = buffer.left(newlineIndex);
        buffer.remove(0, newlineIndex + 1);
        consumeLine(QString::fromLocal8Bit(line));
    }
}

void DownloadQueue::consumeLine(const QString &line)
{
    if (m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }

    const QString trimmed = line.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }
    Task &task = m_tasks[m_activeIndex];
    if (trimmed.startsWith(QStringLiteral("download:"))) {
        QString payload = trimmed.mid(QStringLiteral("download:").size());
        if (payload.startsWith(QStringLiteral("download:"))) {
            payload = payload.mid(QStringLiteral("download:").size());
        }
        const QStringList values = payload.split('|', Qt::KeepEmptyParts);
        bool ok = false;
        const double percent = values.value(0).trimmed().remove('%').toDouble(&ok);
        if (ok) {
            task.progress = qBound(0.0, percent / 100.0, 1.0);
        }
        task.speed = values.value(1).trimmed();
        task.eta = values.value(2).trimmed();
        task.statusText = QStringLiteral("下载中");
        notifyQueueChanged();
        return;
    }

    const QString destinationPrefix = QStringLiteral("[download] Destination:");
    if (trimmed.startsWith(destinationPrefix)) {
        task.outputPath = trimmed.mid(destinationPrefix.size()).trimmed();
        return;
    }
    const QString mergerPrefix = QStringLiteral("[Merger] Merging formats into:");
    if (trimmed.startsWith(mergerPrefix)) {
        task.outputPath = trimmed.mid(mergerPrefix.size()).trimmed().remove('"');
        return;
    }

    const QFileInfo possiblePath(trimmed);
    if (possiblePath.isAbsolute() && (trimmed.contains(QDir::separator())
                                      || possiblePath.suffix() == QStringLiteral("mp4")
                                      || possiblePath.suffix() == QStringLiteral("mp3"))) {
        task.outputPath = possiblePath.absoluteFilePath();
        return;
    }
    if (trimmed.contains(QStringLiteral("ERROR:"), Qt::CaseInsensitive)) {
        m_lastErrorText = trimmed;
    }
}

void DownloadQueue::finishActive(const QString &state, const QString &status, const QString &error)
{
    if (m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }

    const int index = m_activeIndex;
    Task &task = m_tasks[index];
    task.state = state;
    task.statusText = status;
    task.errorMessage = error;
    if (state == QStringLiteral("failed") || state == QStringLiteral("cancelled")) {
        cleanupTemporaryFiles(task);
    }

    const bool removeTask = task.removeAfterFinish;
    m_activeIndex = -1;
    if (removeTask) {
        moveTaskFilesToTrash(task);
        m_tasks.removeAt(index);
    }
    notifyQueueChanged();
    startNext();
}

void DownloadQueue::cleanupTemporaryFiles(const Task &task)
{
    if (task.outputPath.isEmpty()) {
        return;
    }
    QFile::remove(task.outputPath + QStringLiteral(".part"));
    QFile::remove(task.outputPath + QStringLiteral(".ytdl"));
}

void DownloadQueue::moveTaskFilesToTrash(const Task &task)
{
    cleanupTemporaryFiles(task);
    if (!task.outputPath.isEmpty() && QFileInfo::exists(task.outputPath)) {
        QFile::moveToTrash(task.outputPath);
    }
}

void DownloadQueue::notifyQueueChanged()
{
    emit tasksChanged();
    emit queueChanged();
}

QString DownloadQueue::normalizeFormat(const QString &format)
{
    return format.trimmed().toLower() == QStringLiteral("mp3") ? QStringLiteral("mp3") : QStringLiteral("mp4");
}

QString DownloadQueue::friendlyError(const QString &rawMessage)
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

bool DownloadQueue::isHttpUrl(const QUrl &url)
{
    const QString scheme = url.scheme().toLower();
    return url.isValid() && !url.host().isEmpty()
        && (scheme == QStringLiteral("http") || scheme == QStringLiteral("https"));
}
