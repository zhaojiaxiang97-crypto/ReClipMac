#include "DownloadManager.h"

#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QTemporaryDir>
#include <QTimer>

namespace {

bool waitForFailure(DownloadManager &manager)
{
    if (manager.state() == QStringLiteral("failed") && !manager.busy()) {
        return true;
    }

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&manager, &DownloadManager::stateChanged, &loop, [&] {
        if (manager.state() == QStringLiteral("failed") && !manager.busy()) {
            loop.quit();
        }
    });
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(2000);
    loop.exec();
    return manager.state() == QStringLiteral("failed") && !manager.busy();
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    DownloadManager manager;
    manager.setOutputFormat(QStringLiteral("mp3"));
    if (manager.outputFormat() != QStringLiteral("mp3")) {
        return 1;
    }

    manager.startVideoDownload(QStringLiteral("not-a-url"), {});
    if (manager.state() != QStringLiteral("failed")
        || !manager.errorMessage().contains(QStringLiteral("HTTP"))) {
        return 2;
    }
    if (manager.canRetry()) {
        return 3;
    }

    manager.startVideoDownload(QStringLiteral("https://example.com/media"), {});
    if (manager.state() != QStringLiteral("failed")
        || !manager.errorMessage().contains(QStringLiteral("不可用"))) {
        return 4;
    }

    QTemporaryDir temporaryDirectory;
    manager.setDownloadDirectory(temporaryDirectory.path());
    const QString missingTool = QDir(temporaryDirectory.path()).filePath(QStringLiteral("missing-yt-dlp"));
    manager.setYtDlpPath(missingTool);
    manager.setFfmpegPath(missingTool);
    manager.startDownload(QStringLiteral("https://example.com/media"), {}, QStringLiteral("mp3"));
    if (!waitForFailure(manager) || !manager.canRetry()) {
        return 5;
    }
    manager.retry();
    if (!waitForFailure(manager) || manager.outputFormat() != QStringLiteral("mp3")) {
        return 6;
    }

    return 0;
}
