#include "DownloadQueue.h"

#include <QCoreApplication>
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

    return 0;
}
