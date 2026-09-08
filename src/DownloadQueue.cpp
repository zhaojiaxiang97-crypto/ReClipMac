#include "DownloadQueue.h"
#include "PlatformPaths.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSettings>
#include <QStorageInfo>
#include <QStandardPaths>
#include <QUuid>

#include <algorithm>

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

DownloadQueue::DownloadQueue(QObject *parent)
    : QObject(parent)
    , m_androidEngine(this)
{
    m_downloadDirectory = PlatformPaths::defaultDownloadDirectory();
    loadPersistedTasks();

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
            &DownloadQueue::handleAndroidDownloadProgress);
    connect(&m_androidEngine,
            &AndroidDownloadEngine::downloadFinished,
            this,
            &DownloadQueue::handleAndroidDownloadFinished);
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
        value.insert(QStringLiteral("exportedUri"), task.exportedUri);
        value.insert(QStringLiteral("errorMessage"), task.errorMessage);
        value.insert(QStringLiteral("progress"), task.progress);
        value.insert(QStringLiteral("canRetry"), task.state == QStringLiteral("failed")
                    || task.state == QStringLiteral("cancelled")
                    || task.state == QStringLiteral("interrupted"));
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

QString DownloadQueue::exportDirectoryUri() const
{
    return m_exportDirectoryUri;
}

void DownloadQueue::setExportDirectoryUri(const QString &uri)
{
    const QString cleaned = uri.trimmed();
    if (m_exportDirectoryUri == cleaned) {
        return;
    }
    m_exportDirectoryUri = cleaned;
    emit exportDirectoryChanged();
}

PlatformStorage *DownloadQueue::platformStorage() const
{
    return m_platformStorage;
}

void DownloadQueue::setPlatformStorage(PlatformStorage *storage)
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
                this, &DownloadQueue::handleExportFinished);
    }
    emit platformStorageChanged();
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
        if (task.state == QStringLiteral("queued")
            || task.state == QStringLiteral("interrupted")) {
            task.state = QStringLiteral("waiting");
            task.statusText = QStringLiteral("等待前一项完成");
            task.errorMessage.clear();
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
        if (!m_androidRequestId.isEmpty()) {
            m_androidEngine.cancel(m_androidRequestId);
        } else {
            m_process.terminate();
        }
    } else if (task.state == QStringLiteral("queued") || task.state == QStringLiteral("waiting")) {
        task.state = QStringLiteral("cancelled");
        task.statusText = QStringLiteral("已取消");
    }
    notifyQueueChanged();
}

void DownloadQueue::retryTask(const QString &taskId)
{
    const int index = indexForId(taskId);
    if (index < 0 || (m_tasks[index].state != QStringLiteral("failed")
                      && m_tasks[index].state != QStringLiteral("cancelled")
                      && m_tasks[index].state != QStringLiteral("interrupted"))) {
        return;
    }

    Task &task = m_tasks[index];
    task.state = QStringLiteral("queued");
    task.statusText = QStringLiteral("等待下载");
    task.progress = 0.0;
    task.speed.clear();
    task.eta.clear();
    task.outputPath.clear();
    task.exportedUri.clear();
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
        if (!m_androidRequestId.isEmpty()) {
            m_androidEngine.cancel(m_androidRequestId);
        } else {
            m_process.terminate();
        }
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
    const QString mimeType = task.format == QStringLiteral("mp3")
        ? QStringLiteral("audio/mpeg")
        : QStringLiteral("video/mp4");
    if (m_platformStorage) {
        m_platformStorage->openFile(path, task.exportedUri, mimeType);
        return;
    }
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void DownloadQueue::shareTask(const QString &taskId)
{
    const int index = indexForId(taskId);
    if (index < 0 || m_tasks[index].outputPath.isEmpty()) {
        return;
    }
    const Task &task = m_tasks[index];
    const QString mimeType = task.format == QStringLiteral("mp3")
        ? QStringLiteral("audio/mpeg")
        : QStringLiteral("video/mp4");
    if (m_platformStorage) {
        m_platformStorage->shareFile(task.outputPath, task.exportedUri, mimeType);
    }
}

QString DownloadQueue::consumeAndroidNotificationRetry()
{
    return m_androidEngine.takePendingRetryTaskId();
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
#ifdef Q_OS_ANDROID
    const bool androidEngineAvailable = m_androidEngine.available();
#else
    const bool androidEngineAvailable = false;
#endif
#ifndef Q_OS_ANDROID
    if (m_ytDlpPath.trimmed().isEmpty() || m_ffmpegPath.trimmed().isEmpty()) {
        task.state = QStringLiteral("failed");
        task.statusText = QStringLiteral("工具不可用");
        task.errorMessage = QStringLiteral("yt-dlp 或 FFmpeg 不可用，请先完成工具诊断");
        notifyQueueChanged();
        return;
    }
#else
    if (!androidEngineAvailable
        && (m_ytDlpPath.trimmed().isEmpty() || m_ffmpegPath.trimmed().isEmpty())) {
        task.state = QStringLiteral("failed");
        task.statusText = QStringLiteral("工具不可用");
        task.errorMessage = QStringLiteral("Android yt-dlp 运行时不可用，请先完成工具诊断");
        notifyQueueChanged();
        return;
    }
#endif

    QDir directory(m_downloadDirectory);
    if (!directory.exists() && !directory.mkpath(QStringLiteral("."))) {
        task.state = QStringLiteral("failed");
        task.statusText = QStringLiteral("下载目录不可用");
        task.errorMessage = QStringLiteral("无法创建下载目录：%1").arg(m_downloadDirectory);
        notifyQueueChanged();
        return;
    }
    if (!hasUsableDownloadStorage(m_downloadDirectory)) {
        task.state = QStringLiteral("failed");
        task.statusText = QStringLiteral("存储空间不足");
        task.errorMessage = QStringLiteral("存储空间不足或下载位置不可用，请清理空间后重试");
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

#ifdef Q_OS_ANDROID
    if (androidEngineAvailable) {
        m_androidRequestId = m_androidEngine.download(
            task.sourceUrl, task.formatId, task.format, m_downloadDirectory, task.id);
        if (m_androidRequestId.isEmpty()) {
            finishActive(QStringLiteral("failed"),
                         QStringLiteral("下载失败"),
                         QStringLiteral("无法启动 Android yt-dlp 运行时"));
        } else {
            notifyQueueChanged();
        }
        return;
    }
#endif

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
        if (m_platformStorage && !m_exportDirectoryUri.isEmpty() && !task.outputPath.isEmpty()) {
            const QString displayName = QFileInfo(task.outputPath).fileName();
            const QString mimeType = task.format == QStringLiteral("mp3")
                ? QStringLiteral("audio/mpeg")
                : QStringLiteral("video/mp4");
            m_pendingExportRequest = m_platformStorage->exportFile(
                task.outputPath, m_exportDirectoryUri, displayName, mimeType);
            if (!m_pendingExportRequest.isEmpty()) {
                task.state = QStringLiteral("exporting");
                task.statusText = QStringLiteral("正在导出");
                notifyQueueChanged();
                return;
            }
        }
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

void DownloadQueue::handleAndroidDownloadProgress(const QString &requestId,
                                                   double progress,
                                                   const QString &eta,
                                                   const QString &speed,
                                                   const QString &line)
{
    Q_UNUSED(line)
    if (requestId != m_androidRequestId
        || m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }

    Task &task = m_tasks[m_activeIndex];
    task.progress = qBound(0.0, progress, 1.0);
    task.eta = eta;
    task.speed = speed;
    task.statusText = QStringLiteral("下载中");
    notifyQueueChanged();
}

void DownloadQueue::handleAndroidDownloadFinished(const QString &requestId,
                                                   bool success,
                                                   const QString &outputPath,
                                                   const QString &errorMessage)
{
    if (requestId != m_androidRequestId
        || m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }

    m_androidRequestId.clear();
    Task &task = m_tasks[m_activeIndex];
    if (task.cancelRequested || !success) {
        if (task.cancelRequested || errorMessage == QStringLiteral("已取消")) {
            finishActive(QStringLiteral("cancelled"), QStringLiteral("已取消"));
        } else {
            finishActive(QStringLiteral("failed"),
                         QStringLiteral("下载失败"),
                         friendlyError(errorMessage));
        }
        return;
    }

    task.outputPath = outputPath.trimmed();
    if (task.outputPath.isEmpty()) {
        finishActive(QStringLiteral("failed"),
                     QStringLiteral("下载失败"),
                     QStringLiteral("Android 运行时未返回输出文件"));
        return;
    }

    task.progress = 1.0;
    if (m_platformStorage && !m_exportDirectoryUri.isEmpty()) {
        const QString displayName = QFileInfo(task.outputPath).fileName();
        const QString mimeType = task.format == QStringLiteral("mp3")
            ? QStringLiteral("audio/mpeg")
            : QStringLiteral("video/mp4");
        m_pendingExportRequest = m_platformStorage->exportFile(
            task.outputPath, m_exportDirectoryUri, displayName, mimeType);
        if (!m_pendingExportRequest.isEmpty()) {
            task.state = QStringLiteral("exporting");
            task.statusText = QStringLiteral("正在导出");
            notifyQueueChanged();
            return;
        }
    }

    finishActive(QStringLiteral("completed"), QStringLiteral("下载完成"));
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
    m_androidRequestId.clear();
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

void DownloadQueue::handleExportFinished(const QString &requestId,
                                         bool success,
                                         const QString &exportedUri,
                                         const QString &errorMessage)
{
    if (requestId != m_pendingExportRequest
        || m_activeIndex < 0 || m_activeIndex >= m_tasks.size()) {
        return;
    }

    m_pendingExportRequest.clear();
    Task &task = m_tasks[m_activeIndex];
    if (success) {
        task.exportedUri = exportedUri;
        finishActive(QStringLiteral("completed"), QStringLiteral("下载完成"));
        return;
    }

    task.statusText = QStringLiteral("下载完成，但导出失败");
    finishActive(QStringLiteral("completed"),
                 QStringLiteral("下载完成，但导出失败"),
                 errorMessage.isEmpty() ? QStringLiteral("文件导出失败") : errorMessage);
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

void DownloadQueue::loadPersistedTasks()
{
    QSettings settings;
    const QByteArray serialized = settings.value(QStringLiteral("downloads/queue")).toByteArray();
    if (serialized.isEmpty()) {
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(serialized, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        settings.remove(QStringLiteral("downloads/queue"));
        settings.sync();
        return;
    }

    int recoveredCount = 0;
    const QJsonArray array = document.array();
    for (const QJsonValue &value : array) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonObject object = value.toObject();
        const QString sourceUrl = object.value(QStringLiteral("sourceUrl")).toString().trimmed();
        if (!isHttpUrl(QUrl(sourceUrl))) {
            continue;
        }

        Task task;
        task.id = object.value(QStringLiteral("id")).toString().trimmed();
        task.id = task.id.isEmpty()
            ? QUuid::createUuid().toString(QUuid::WithoutBraces)
            : task.id;
        task.sourceUrl = sourceUrl;
        task.title = object.value(QStringLiteral("title")).toString().trimmed();
        if (task.title.isEmpty()) {
            const QUrl url(sourceUrl);
            task.title = url.host() + url.path();
        }
        task.formatId = object.value(QStringLiteral("formatId")).toString().trimmed();
        task.format = normalizeFormat(object.value(QStringLiteral("format")).toString());
        task.state = object.value(QStringLiteral("state")).toString().trimmed();
        task.statusText = object.value(QStringLiteral("statusText")).toString().trimmed();
        task.speed = object.value(QStringLiteral("speed")).toString();
        task.eta = object.value(QStringLiteral("eta")).toString();
        task.outputPath = object.value(QStringLiteral("outputPath")).toString();
        task.exportedUri = object.value(QStringLiteral("exportedUri")).toString();
        task.errorMessage = object.value(QStringLiteral("errorMessage")).toString();
        task.progress = qBound(0.0, object.value(QStringLiteral("progress")).toDouble(), 1.0);

        const bool wasActive = task.state == QStringLiteral("downloading")
            || task.state == QStringLiteral("exporting");
        if (wasActive) {
            task.state = QStringLiteral("interrupted");
            task.statusText = QStringLiteral("应用关闭时中断，可重试");
            task.errorMessage = QStringLiteral("应用退出时任务尚未完成");
            task.speed.clear();
            task.eta.clear();
            task.cancelRequested = false;
            task.removeAfterFinish = false;
            ++recoveredCount;
        } else if (task.state.isEmpty()) {
            task.state = QStringLiteral("queued");
            task.statusText = QStringLiteral("等待下载");
        }

        if (task.statusText.isEmpty()) {
            task.statusText = task.state == QStringLiteral("completed")
                ? QStringLiteral("下载完成")
                : QStringLiteral("等待下载");
        }

        if (task.state == QStringLiteral("completed") && !task.outputPath.isEmpty()
            && !QFileInfo::exists(task.outputPath) && task.exportedUri.isEmpty()) {
            task.state = QStringLiteral("failed");
            task.statusText = QStringLiteral("输出文件不存在，可重试");
            task.errorMessage = QStringLiteral("已记录的输出文件不在原位置");
        }

        m_tasks.append(task);
    }

    if (recoveredCount > 0) {
        m_statusText = QStringLiteral("已恢复 %1 个中断任务，可重试").arg(recoveredCount);
    } else if (!m_tasks.isEmpty()) {
        m_statusText = QStringLiteral("队列中有 %1 个任务").arg(m_tasks.size());
    }

    // Persist the normalised representation and the interrupted states so a
    // second restart cannot mistake an old active task for a live operation.
    persistTasks();
}

void DownloadQueue::persistTasks() const
{
    QJsonArray array;
    for (const Task &task : m_tasks) {
        QJsonObject object;
        object.insert(QStringLiteral("id"), task.id);
        object.insert(QStringLiteral("sourceUrl"), task.sourceUrl);
        object.insert(QStringLiteral("title"), task.title);
        object.insert(QStringLiteral("formatId"), task.formatId);
        object.insert(QStringLiteral("format"), task.format);
        object.insert(QStringLiteral("state"), task.state);
        object.insert(QStringLiteral("statusText"), task.statusText);
        object.insert(QStringLiteral("speed"), task.speed);
        object.insert(QStringLiteral("eta"), task.eta);
        object.insert(QStringLiteral("outputPath"), task.outputPath);
        object.insert(QStringLiteral("exportedUri"), task.exportedUri);
        object.insert(QStringLiteral("errorMessage"), task.errorMessage);
        object.insert(QStringLiteral("progress"), task.progress);
        array.append(object);
    }

    QSettings settings;
    settings.setValue(QStringLiteral("downloads/queue"),
                      QJsonDocument(array).toJson(QJsonDocument::Compact));
    settings.sync();
}

void DownloadQueue::notifyQueueChanged()
{
    persistTasks();
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

bool DownloadQueue::isHttpUrl(const QUrl &url)
{
    const QString scheme = url.scheme().toLower();
    return url.isValid() && !url.host().isEmpty()
        && (scheme == QStringLiteral("http") || scheme == QStringLiteral("https"));
}
