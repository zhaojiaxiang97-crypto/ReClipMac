#include "DownloadQueue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QTemporaryDir>
#include <QVariantMap>
#include <QUrl>

namespace {

QVariantMap taskAt(const DownloadQueue &queue, int index)
{
    return queue.tasks().value(index).toMap();
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("ReClipDownloadQueueTest"));
    QCoreApplication::setOrganizationName(QStringLiteral("ReClipTests"));

    QSettings settings;
    settings.remove(QStringLiteral("downloads/queue"));
    settings.sync();

    DownloadQueue queue;
    queue.addUrls(QStringLiteral("https://example.com/a https://example.com/b https://example.com/a"),
                  QStringLiteral("mp3"));
    if (queue.tasks().size() != 2 || taskAt(queue, 0).value(QStringLiteral("format")) != QStringLiteral("MP3")) {
        return 1;
    }

    queue.startAll();
    if (queue.running() || taskAt(queue, 0).value(QStringLiteral("state")) != QStringLiteral("failed")
        || taskAt(queue, 1).value(QStringLiteral("state")) != QStringLiteral("failed")) {
        return 2;
    }

    const QString firstId = taskAt(queue, 0).value(QStringLiteral("id")).toString();
    queue.retryTask(firstId);
    if (taskAt(queue, 0).value(QStringLiteral("state")) != QStringLiteral("failed")) {
        return 3;
    }

    const QString secondId = taskAt(queue, 1).value(QStringLiteral("id")).toString();
    queue.removeTask(secondId);
    if (queue.tasks().size() != 1) {
        return 4;
    }

    queue.addTask(QStringLiteral("https://example.com/recovered"), {}, QStringLiteral("mp4"));
    const QString recoveredId = taskAt(queue, 1).value(QStringLiteral("id")).toString();
    {
        DownloadQueue restarted;
        if (restarted.tasks().size() != 2
            || taskAt(restarted, 1).value(QStringLiteral("id")) != recoveredId
            || taskAt(restarted, 1).value(QStringLiteral("state")) != QStringLiteral("queued")) {
            return 5;
        }
    }

    settings.setValue(
        QStringLiteral("downloads/queue"),
        QByteArray("[{\"id\":\"active-task\",\"sourceUrl\":\"https://example.com/active\","
                   "\"title\":\"active\",\"format\":\"mp4\",\"state\":\"downloading\","
                   "\"statusText\":\"下载中\",\"progress\":0.4}]"));
    settings.sync();
    {
        DownloadQueue recovered;
        const QVariantMap task = taskAt(recovered, 0);
        if (recovered.tasks().size() != 1
            || task.value(QStringLiteral("state")) != QStringLiteral("interrupted")
            || task.value(QStringLiteral("canRetry")) != true
            || task.value(QStringLiteral("statusText")) != QStringLiteral("应用关闭时中断，可重试")) {
            return 6;
        }
    }

    settings.setValue(
        QStringLiteral("downloads/queue"),
        QByteArray("[{\"id\":\"legacy-task\",\"sourceUrl\":\"https://example.com/legacy\","
                   "\"title\":\"legacy\",\"format\":\"mp4\",\"state\":\"failed\","
                   "\"statusText\":\"????\",\"errorMessage\":\"???????????????\"}]"));
    settings.sync();
    {
        DownloadQueue migrated;
        const QVariantMap task = taskAt(migrated, 0);
        if (migrated.tasks().size() != 1
            || task.value(QStringLiteral("statusText")) != QStringLiteral("下载失败")
            || task.value(QStringLiteral("errorMessage"))
                != QStringLiteral("上次下载失败，请检查媒体链接和网络连接后重试")) {
            return 7;
        }

        DownloadQueue migratedAgain;
        const QVariantMap persistedTask = taskAt(migratedAgain, 0);
        if (persistedTask.value(QStringLiteral("statusText")) != QStringLiteral("下载失败")
            || persistedTask.value(QStringLiteral("errorMessage"))
                != QStringLiteral("上次下载失败，请检查媒体链接和网络连接后重试")) {
            return 8;
        }
    }

    QTemporaryDir taskFiles;
    if (!taskFiles.isValid()) {
        return 9;
    }
    const QString outputPath = taskFiles.filePath(QStringLiteral("download.mp4"));
    const QString exportedPath = taskFiles.filePath(QStringLiteral("exported.mp4"));
    QFile outputFile(outputPath);
    QFile exportedFile(exportedPath);
    if (!outputFile.open(QIODevice::WriteOnly)
        || outputFile.write("video") != 5
        || !exportedFile.open(QIODevice::WriteOnly)
        || exportedFile.write("copy") != 4) {
        return 10;
    }
    outputFile.close();
    exportedFile.close();

    QJsonObject fileTask;
    fileTask.insert(QStringLiteral("id"), QStringLiteral("file-task"));
    fileTask.insert(QStringLiteral("sourceUrl"), QStringLiteral("https://example.com/file"));
    fileTask.insert(QStringLiteral("title"), QStringLiteral("file-task"));
    fileTask.insert(QStringLiteral("format"), QStringLiteral("mp4"));
    fileTask.insert(QStringLiteral("state"), QStringLiteral("completed"));
    fileTask.insert(QStringLiteral("statusText"), QStringLiteral("下载完成"));
    fileTask.insert(QStringLiteral("outputPath"), outputPath);
    fileTask.insert(QStringLiteral("exportedUri"), QUrl::fromLocalFile(exportedPath).toString());
    QJsonArray fileTasks;
    fileTasks.append(fileTask);
    settings.setValue(QStringLiteral("downloads/queue"),
                      QJsonDocument(fileTasks).toJson(QJsonDocument::Compact));
    settings.sync();
    {
        DownloadQueue fileQueue;
        fileQueue.removeTask(QStringLiteral("file-task"));
        if (!fileQueue.tasks().isEmpty()
            || QFileInfo::exists(outputPath)
            || QFileInfo::exists(exportedPath)) {
            return 11;
        }
    }

    settings.remove(QStringLiteral("downloads/queue"));
    settings.sync();

    return 0;
}
