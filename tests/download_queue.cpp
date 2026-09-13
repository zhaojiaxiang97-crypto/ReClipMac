#include "DownloadQueue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#if defined(RECLIP_HAS_FFMPEG_SDK)
#include <QEventLoop>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include "ffmpeg/FfmpegService.h"
#endif
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QTemporaryDir>
#include <QVariantMap>
#include <QUrl>

#include <utility>

namespace {

QVariantMap taskAt(const DownloadQueue &queue, int index)
{
    return queue.tasks().value(index).toMap();
}

#if defined(RECLIP_HAS_FFMPEG_SDK)
class StaticHttpServer final : public QTcpServer
{
public:
    explicit StaticHttpServer(QByteArray payload, QObject *parent = nullptr)
        : QTcpServer(parent)
        , m_payload(std::move(payload))
    {
        connect(this, &QTcpServer::newConnection, this, [this] {
            while (hasPendingConnections()) {
                QTcpSocket *socket = nextPendingConnection();
                connect(socket, &QTcpSocket::disconnected,
                        socket, &QTcpSocket::deleteLater);
                const QByteArray response = QByteArrayLiteral(
                    "HTTP/1.1 200 OK\r\n"
                    "Content-Type: video/mp4\r\n"
                    "Connection: close\r\n"
                    "Content-Length: ")
                    + QByteArray::number(m_payload.size())
                    + QByteArrayLiteral("\r\n\r\n")
                    + m_payload;
                socket->write(response);
                socket->flush();
                QTimer::singleShot(1000, socket, [socket] {
                    socket->disconnectFromHost();
                });
            }
        });
    }

private:
    QByteArray m_payload;
};

bool waitForQueueTerminal(DownloadQueue &queue)
{
    if (!queue.running()) {
        return true;
    }

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&queue, &DownloadQueue::queueChanged, &loop, [&] {
        if (!queue.running()) {
            loop.quit();
        }
    });
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(10000);
    loop.exec();
    return !queue.running();
}
#endif

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
#if defined(RECLIP_HAS_FFMPEG_SDK)
    QCoreApplication::setApplicationName(QStringLiteral("ReClipDownloadQueueTestSdk"));
#else
    QCoreApplication::setApplicationName(QStringLiteral("ReClipDownloadQueueTest"));
#endif
    QCoreApplication::setOrganizationName(QStringLiteral("ReClipTests"));

    QSettings settings;
    settings.remove(QStringLiteral("downloads/queue"));
    settings.sync();

    DownloadQueue queue;
#ifdef RECLIP_HAS_YTDLP_SDK
    // With an embedded resolver, an empty tool path is valid. Exercise the
    // same synchronous preflight-failure state machine using a file as a dir.
    QTemporaryDir unavailableDirectory;
    QFile directoryBlocker(unavailableDirectory.filePath(QStringLiteral("not-a-directory")));
    if (!directoryBlocker.open(QIODevice::WriteOnly)) { return 18; }
    directoryBlocker.close();
    queue.setDownloadDirectory(directoryBlocker.fileName());
#endif
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

    queue.addTask(QStringLiteral("https://example.com/titled"), {}, QStringLiteral("mp4"));
    queue.addTaskWithTitle(QStringLiteral("https://example.com/titled"), {},
                           QStringLiteral("mp4"), QStringLiteral("一个真实的视频标题"));
    if (queue.tasks().size() != 3
        || taskAt(queue, 2).value(QStringLiteral("title")) != QStringLiteral("一个真实的视频标题")) {
        return 19;
    }
    {
        DownloadQueue titledRestarted;
        if (titledRestarted.tasks().size() != 3
            || taskAt(titledRestarted, 2).value(QStringLiteral("title"))
                != QStringLiteral("一个真实的视频标题")) {
            return 20;
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

#if defined(RECLIP_HAS_FFMPEG_SDK)
    const QString fixturePath = QDir(QCoreApplication::applicationDirPath()).filePath(
        QStringLiteral("tiny_video_mp4.b64"));
    QFile fixtureFile(fixturePath);
    if (!fixtureFile.open(QIODevice::ReadOnly)) {
        return 12;
    }
    const QByteArray fixture = QByteArray::fromBase64(fixtureFile.readAll().trimmed());
    fixtureFile.close();
    if (fixture.isEmpty()) {
        return 13;
    }

    StaticHttpServer server(fixture);
    if (!server.listen(QHostAddress::LocalHost, 0)) {
        return 14;
    }

    const QString fakeYtDlpPath = QDir(QCoreApplication::applicationDirPath()).filePath(
        QStringLiteral("ReClipFakeYtDlp.exe"));
    if (!QFileInfo(fakeYtDlpPath).isFile()) {
        return 15;
    }

    QJsonObject resolveObject;
    resolveObject.insert(QStringLiteral("id"), QStringLiteral("queue-fixture"));
    resolveObject.insert(QStringLiteral("title"), QStringLiteral("SDK queue fixture"));
    resolveObject.insert(QStringLiteral("url"),
                        QStringLiteral("http://127.0.0.1:%1/queue.mp4").arg(server.serverPort()));
    resolveObject.insert(QStringLiteral("protocol"), QStringLiteral("http"));
    resolveObject.insert(QStringLiteral("vcodec"), QStringLiteral("mpeg4"));
    resolveObject.insert(QStringLiteral("acodec"), QStringLiteral("aac"));
    resolveObject.insert(QStringLiteral("filesize"), static_cast<double>(fixture.size()));
    qputenv("RECLIP_FAKE_YTDLP_JSON",
            QJsonDocument(resolveObject).toJson(QJsonDocument::Compact));

    QTemporaryDir sdkDirectory;
    if (!sdkDirectory.isValid()) {
        qunsetenv("RECLIP_FAKE_YTDLP_JSON");
        return 16;
    }
    DownloadQueue sdkQueue;
    sdkQueue.setDownloadDirectory(sdkDirectory.path());
    sdkQueue.setYtDlpPath(fakeYtDlpPath);
    sdkQueue.setFfmpegPath({});
    sdkQueue.addTask(QStringLiteral("https://example.com/queue-video"), {}, QStringLiteral("mp4"));
    const QString sdkTaskId = taskAt(sdkQueue, 0).value(QStringLiteral("id")).toString();
    sdkQueue.startAll();
    const bool sdkTerminal = waitForQueueTerminal(sdkQueue);
    const QVariantMap sdkTask = taskAt(sdkQueue, 0);
    const QString sdkOutputPath = sdkTask.value(QStringLiteral("outputPath")).toString();
    const ReClip::Ffmpeg::ProbeResult sdkProbe =
        ReClip::Ffmpeg::FfmpegService().probe(sdkOutputPath);
    qunsetenv("RECLIP_FAKE_YTDLP_JSON");
    if (!sdkTerminal || sdkTask.value(QStringLiteral("id")) != sdkTaskId
        || sdkTask.value(QStringLiteral("state")) != QStringLiteral("completed")
        || !sdkProbe.ok || !QFileInfo(sdkOutputPath).isFile()) {
        qWarning() << "SDK queue test failed" << sdkTerminal << sdkTask << sdkOutputPath
                   << sdkProbe.error.message;
        return 17;
    }
    settings.remove(QStringLiteral("downloads/queue"));
    settings.sync();
#endif

    return 0;
}
