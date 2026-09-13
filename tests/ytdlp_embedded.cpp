#include "ytdlp/YtDlpService.h"
#include "MediaInspector.h"
#include "DownloadManager.h"
#include "DownloadQueue.h"
#include "ffmpeg/FfmpegService.h"
#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QTimer>
#include <QSettings>
#include <QCryptographicHash>
#include <cstdio>

using namespace ReClip::YtDlp;

namespace {

Result awaitResult(YtDlpService &service, const QString &id)
{
    Result result {false, {}, QStringLiteral("test-timeout"), {}};
    QEventLoop loop;
    const auto connection = QObject::connect(&service, &YtDlpService::finished, &loop,
        [&](const QString &received, bool ok, const QByteArray &payload, const QString &code, const QString &error) {
            if (received != id) { return; }
            result = {ok, payload, code, error};
            loop.quit();
        });
    QTimer::singleShot(10000, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(connection);
    return result;
}

class FixtureServer : public QTcpServer {
public:
    QByteArray media;
    QByteArray playlist;
    QByteArray dashManifest;
    FixtureServer()
    {
        QObject::connect(this, &QTcpServer::newConnection, this, [this] {
            while (hasPendingConnections()) {
                auto *socket = nextPendingConnection();
                auto request = std::make_shared<QByteArray>();
                QObject::connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
                QObject::connect(socket, &QTcpSocket::readyRead, socket, [this, socket, request] {
                    request->append(socket->readAll());
                    if (!request->contains("\r\n\r\n")) { return; }
                    if (socket->property("responded").toBool()) { return; }
                    socket->setProperty("responded", true);
                    if (request->contains("/stall.mp4")) { return; }
                    const bool missing = request->contains("/missing");
                    const bool hls = request->contains("/video.m3u8");
                    const bool dash = request->contains("/video.mpd");
                    const QByteArray body = missing
                        ? QByteArray("Not found")
                        : (hls ? playlist : (dash ? dashManifest : media));
                    const QByteArray contentType = hls
                        ? QByteArrayLiteral("application/vnd.apple.mpegurl")
                        : (dash ? QByteArrayLiteral("application/dash+xml")
                                : QByteArrayLiteral("video/mp4"));
                    socket->write(missing ? "HTTP/1.1 404 Not Found\r\n" : "HTTP/1.1 200 OK\r\n");
                    socket->write("Content-Type: " + contentType + "\r\nConnection: close\r\nContent-Length: " + QByteArray::number(body.size()) + "\r\n\r\n");
                    if (!request->startsWith("HEAD ")) { socket->write(body); }
                    socket->disconnectFromHost();
                });
            }
        });
    }
    QString url(const QString &path = QStringLiteral("/fixture.mp4")) const
    { return QStringLiteral("http://127.0.0.1:%1%2").arg(serverPort()).arg(path); }
};

bool download(DownloadManager &manager, const QString &url, const QString &format)
{
    QEventLoop loop;
    QObject::connect(&manager, &DownloadManager::stateChanged, &loop, [&] {
        if (!manager.busy()) { loop.quit(); }
    });
    manager.startDownload(url, {}, format);
    if (manager.busy()) {
        QTimer::singleShot(10000, &loop, &QEventLoop::quit);
        loop.exec();
    }
    if (manager.state() != QStringLiteral("completed")) {
        std::fprintf(stderr, "download %s: %s / %s\n", qPrintable(format), qPrintable(manager.state()), qPrintable(manager.errorMessage()));
        return false;
    }
    ReClip::Ffmpeg::FfmpegService ffmpeg;
    return ffmpeg.probe(manager.outputPath()).ok;
}

int fail(int code, const Result &result)
{
    std::fprintf(stderr, "case %d failed: %s / %s / %s\n", code, qPrintable(result.errorCode), qPrintable(result.errorMessage), result.payload.constData());
    return code;
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("ReClipTests"));
    QCoreApplication::setApplicationName(QStringLiteral("EmbeddedYtDlpTest"));
    QTemporaryDir settingsDirectory;
    QSettings::setDefaultFormat(QSettings::IniFormat);
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, settingsDirectory.path());
    YtDlpService service;
    const Result probe = awaitResult(service, service.probe());
    if (app.arguments().contains(QStringLiteral("--expect-runtime-error"))) {
        return !probe.ok && probe.errorCode == QStringLiteral("runtime-error") ? 0 : fail(30, probe);
    }
    if (!probe.ok) { return fail(1, probe); }
    const auto runtime = QJsonDocument::fromJson(probe.payload).object();
    if (!runtime.value(QStringLiteral("isolated")).toBool()
        || runtime.value(QStringLiteral("python")).toString() != QStringLiteral("3.13.15")
        || runtime.value(QStringLiteral("ytDlp")).toString() != QStringLiteral("2026.08.19")) { return fail(2, probe); }
    std::printf("Embedded runtime: %s\n", probe.payload.constData());

    QFile fixture(QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("tiny_video_mp4.b64")));
    if (!fixture.open(QIODevice::ReadOnly)) { return 3; }
    FixtureServer server;
    server.media = QByteArray::fromBase64(fixture.readAll().trimmed());
    if (server.media.isEmpty() || !server.listen(QHostAddress::LocalHost, 0)) { return 4; }
    server.playlist = QByteArrayLiteral(
        "#EXTM3U\n"
        "#EXT-X-VERSION:7\n"
        "#EXT-X-TARGETDURATION:1\n"
        "#EXT-X-MEDIA-SEQUENCE:0\n"
        "#EXT-X-PLAYLIST-TYPE:VOD\n"
        "#EXT-X-MAP:URI=\"tiny.mp4\"\n"
        "#EXTINF:0.4,\n"
        "tiny.mp4\n"
        "#EXT-X-ENDLIST\n");
    server.dashManifest = QByteArrayLiteral(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<MPD xmlns=\"urn:mpeg:dash:schema:mpd:2011\" type=\"static\" mediaPresentationDuration=\"PT0.4S\" minBufferTime=\"PT0.4S\" profiles=\"urn:mpeg:dash:profile:isoff-on-demand:2011\">\n"
        "  <Period id=\"0\" start=\"PT0S\" duration=\"PT0.4S\">\n"
        "    <AdaptationSet id=\"0\" contentType=\"video\" mimeType=\"video/mp4\" codecs=\"mp4v.20.3,mp4a.40.2\" segmentAlignment=\"true\">\n"
        "      <Representation id=\"muxed\" bandwidth=\"100000\" width=\"16\" height=\"16\">\n"
        "        <SegmentList timescale=\"1000\" duration=\"400\">\n"
        "          <SegmentURL media=\"tiny.mp4\" />\n"
        "        </SegmentList>\n"
        "      </Representation>\n"
        "    </AdaptationSet>\n"
        "  </Period>\n"
        "</MPD>\n");

    Request request;
    request.url = server.url();
    auto resolved = awaitResult(service, service.inspect(request));
    if (!resolved.ok || QJsonDocument::fromJson(resolved.payload).object().value(QStringLiteral("url")).toString() != request.url) { return fail(5, resolved); }

    request.url = QStringLiteral("not-a-url");
    auto invalid = awaitResult(service, service.inspect(request));
    if (invalid.ok || invalid.errorCode != QStringLiteral("invalid-url")) { return fail(6, invalid); }
    request.url = server.url(QStringLiteral("/missing.mp4?secret=do-not-log"));
    const auto missing = awaitResult(service, service.inspect(request));
    if (missing.ok || missing.errorMessage.contains(QStringLiteral("do-not-log"))) { return fail(7, missing); }

    request.url = server.url();
    const QString cancelledId = service.inspect(request);
    service.cancel(cancelledId);
    const auto cancelled = awaitResult(service, cancelledId);
    if (cancelled.ok || cancelled.errorCode != QStringLiteral("cancelled")) { return fail(8, cancelled); }

    int heartbeat = 0;
    QTimer pulse;
    QObject::connect(&pulse, &QTimer::timeout, [&] { ++heartbeat; });
    pulse.start(20);
    request.url = server.url(QStringLiteral("/stall.mp4"));
    request.timeoutSeconds = 0.25;
    const auto timedOut = awaitResult(service, service.inspect(request));
    if (timedOut.ok || timedOut.errorCode != QStringLiteral("timeout") || heartbeat < 3) { return fail(9, timedOut); }

    request.timeoutSeconds = 2;
    const QString activeId = service.inspect(request);
    int terminalCount = 0;
    QObject::connect(&service, &YtDlpService::finished, &app, [&](const QString &id, bool, const QByteArray &, const QString &, const QString &) {
        if (id == activeId) { ++terminalCount; }
    });
    QTimer::singleShot(100, &service, [&] { service.cancel(activeId); });
    const auto activeCancelled = awaitResult(service, activeId);
    if (activeCancelled.ok || activeCancelled.errorCode != QStringLiteral("cancelled") || terminalCount != 1) { return fail(10, activeCancelled); }

    // A cancelled/cleared inspection must never overwrite a newer result.
    MediaInspector inspector;
    inspector.inspect(server.url(QStringLiteral("/stall.mp4")));
    inspector.clear();
    inspector.inspect(server.url());
    QEventLoop inspectionLoop;
    QObject::connect(&inspector, &MediaInspector::stateChanged, &inspectionLoop, [&] {
        if (!inspector.inspecting()) { inspectionLoop.quit(); }
    });
    QTimer::singleShot(10000, &inspectionLoop, &QEventLoop::quit);
    inspectionLoop.exec();
    if (!inspector.hasResult() || inspector.sourceUrl() != server.url()) {
        std::fprintf(stderr, "inspector: %s\n", qPrintable(inspector.errorMessage()));
        return 11;
    }
    for (int i = 0; i < 5; ++i) {
        const auto repeated = awaitResult(service, service.probe());
        if (!repeated.ok) { return fail(12, repeated); }
    }

    // The embedded downloader owns the native single-format path. Multi-format
    // selection remains with DownloadManager + the FFmpeg SDK merger.
    QTemporaryDir nativeOutput;
    const QString nativePath = QDir(nativeOutput.path()).filePath(QStringLiteral("native-direct.mp4"));
    Request nativeRequest;
    nativeRequest.url = server.url();
    nativeRequest.formatSelector = QStringLiteral("best");
    nativeRequest.outputPath = nativePath;
    const auto nativeDownload = awaitResult(service, service.download(nativeRequest));
    const auto nativePayload = QJsonDocument::fromJson(nativeDownload.payload).object();
    const QString reportedNativePath = QDir::cleanPath(QDir::fromNativeSeparators(
        nativePayload.value(QStringLiteral("path")).toString()));
    const QString expectedNativePath = QDir::cleanPath(QDir::fromNativeSeparators(
        QFileInfo(nativePath).absoluteFilePath()));
    if (!nativeDownload.ok
        || reportedNativePath.compare(expectedNativePath, Qt::CaseInsensitive) != 0
        || !QFileInfo(nativePath).isFile()
        || QFileInfo(nativePath).size() != server.media.size()) {
        return fail(25, nativeDownload);
    }
    const auto refusedNativeOverwrite = awaitResult(service, service.download(nativeRequest));
    if (refusedNativeOverwrite.ok || refusedNativeOverwrite.errorCode != QStringLiteral("output-exists")) {
        return fail(26, refusedNativeOverwrite);
    }

    QTemporaryDir output(QDir::tempPath() + QStringLiteral("/ReClip test XXXXXXX"));
    DownloadManager manager;
    manager.setDownloadDirectory(output.path());
    manager.setYtDlpPath({});
    manager.setFfmpegPath({});
    if (!download(manager, server.url(), QStringLiteral("mp4"))) { return 13; }
    const QString mp4Output = manager.outputPath();
    if (!download(manager, server.url(), QStringLiteral("mp3"))) { return 14; }
    const QString existingOutput = manager.outputPath();
    QFile existing(existingOutput);
    if (!existing.open(QIODevice::ReadOnly)) { return 19; }
    const QByteArray existingHash = QCryptographicHash::hash(existing.readAll(), QCryptographicHash::Sha256);
    existing.close();
    ReClip::Ffmpeg::OperationOptions noOverwrite;
    noOverwrite.overwriteExisting = false;
    const auto refusedOverwrite = ReClip::Ffmpeg::FfmpegService().transcodeAudio(mp4Output, existingOutput, {}, noOverwrite);
    if (refusedOverwrite.ok || !existing.open(QIODevice::ReadOnly)
        || QCryptographicHash::hash(existing.readAll(), QCryptographicHash::Sha256) != existingHash) { return 21; }
    existing.close();
    QEventLoop collisionLoop;
    QObject::connect(&manager, &DownloadManager::stateChanged, &collisionLoop, [&] { if (!manager.busy()) { collisionLoop.quit(); } });
    manager.startDownload(server.url(), {}, QStringLiteral("mp3"));
    if (manager.busy()) {
        QTimer::singleShot(10000, &collisionLoop, &QEventLoop::quit);
        collisionLoop.exec();
    }
    if (manager.state() != QStringLiteral("failed") || !existing.open(QIODevice::ReadOnly)
        || QCryptographicHash::hash(existing.readAll(), QCryptographicHash::Sha256) != existingHash) { return 20; }
    existing.close();
    if (!QDir(output.path()).entryList({QStringLiteral("*.part")}, QDir::Files).isEmpty()) { return 15; }

    DownloadManager hlsManager;
    hlsManager.setDownloadDirectory(output.path());
    hlsManager.setYtDlpPath({});
    hlsManager.setFfmpegPath({});
    if (!download(hlsManager, server.url(QStringLiteral("/video.m3u8")), QStringLiteral("mp4"))) {
        std::fprintf(stderr, "embedded HLS: %s / %s\n",
                     qPrintable(hlsManager.state()),
                     qPrintable(hlsManager.errorMessage()));
        return 22;
    }
    DownloadManager hlsAudioManager;
    hlsAudioManager.setDownloadDirectory(output.path());
    hlsAudioManager.setYtDlpPath({});
    hlsAudioManager.setFfmpegPath({});
    if (!download(hlsAudioManager, server.url(QStringLiteral("/video.m3u8")), QStringLiteral("mp3"))) {
        std::fprintf(stderr, "embedded HLS MP3: %s / %s\n",
                     qPrintable(hlsAudioManager.state()),
                     qPrintable(hlsAudioManager.errorMessage()));
        return 24;
    }
    DownloadManager dashManager;
    dashManager.setDownloadDirectory(output.path());
    dashManager.setYtDlpPath({});
    dashManager.setFfmpegPath({});
    if (!download(dashManager, server.url(QStringLiteral("/video.mpd")), QStringLiteral("mp4"))) {
        std::fprintf(stderr, "embedded DASH: %s / %s\n",
                     qPrintable(dashManager.state()),
                     qPrintable(dashManager.errorMessage()));
        return 23;
    }
    QTemporaryDir queueOutput;
    DownloadQueue queue;
    queue.setDownloadDirectory(queueOutput.path());
    queue.addTask(server.url(QStringLiteral("/queue-a.mp4")), {}, QStringLiteral("mp3"));
    queue.addTask(server.url(QStringLiteral("/queue-b.mp4")), {}, QStringLiteral("mp4"));
    QEventLoop queueLoop;
    QObject::connect(&queue, &DownloadQueue::queueChanged, &queueLoop, [&] {
        if (!queue.running()) { queueLoop.quit(); }
    });
    queue.startAll();
    if (queue.running()) {
        QTimer::singleShot(10000, &queueLoop, &QEventLoop::quit);
        queueLoop.exec();
    }
    if (queue.running() || queue.tasks().size() != 2) { return 16; }
    for (const auto &item : queue.tasks()) {
        const auto task = item.toMap();
        if (task.value(QStringLiteral("state")).toString() != QStringLiteral("completed")) {
            std::fprintf(stderr, "queue: %s\n", qPrintable(task.value(QStringLiteral("errorMessage")).toString()));
            return 17;
        }
    }
    DownloadQueue restored;
    if (restored.tasks().size() != 2 || restored.tasks().first().toMap().value(QStringLiteral("state")) != QStringLiteral("completed")) { return 18; }
    std::puts("PASS: probe, isolated imports, metadata, errors, cancellation, timeout, GUI heartbeat, stale callbacks, native yt-dlp single-format download, MP4/MP3 SDK outputs, HLS and DASH VOD");
    return 0;
}
