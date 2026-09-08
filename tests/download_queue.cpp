#include "DownloadQueue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QSettings>
#include <QVariantMap>

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

    settings.remove(QStringLiteral("downloads/queue"));
    settings.sync();

    return 0;
}
