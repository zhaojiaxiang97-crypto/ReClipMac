#include "DownloadManager.h"
#include "ffmpeg/FfprobeService.h"

#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QTimer>

#include <cmath>
#include <cstdio>
#include <utility>

namespace {

void writeLittleEndian16(QFile &file, quint16 value)
{
    const char bytes[] = {
        static_cast<char>(value & 0xff),
        static_cast<char>((value >> 8) & 0xff),
    };
    file.write(bytes, sizeof(bytes));
}

void writeLittleEndian32(QFile &file, quint32 value)
{
    const char bytes[] = {
        static_cast<char>(value & 0xff),
        static_cast<char>((value >> 8) & 0xff),
        static_cast<char>((value >> 16) & 0xff),
        static_cast<char>((value >> 24) & 0xff),
    };
    file.write(bytes, sizeof(bytes));
}

bool writeWav(const QString &path)
{
    constexpr quint32 sampleRate = 44100;
    constexpr quint16 channels = 1;
    constexpr quint16 bitsPerSample = 16;
    constexpr quint32 sampleCount = sampleRate;
    constexpr quint32 dataSize = sampleCount * channels * bitsPerSample / 8;
    constexpr double pi = 3.14159265358979323846;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    file.write("RIFF", 4);
    writeLittleEndian32(file, 36 + dataSize);
    file.write("WAVEfmt ", 8);
    writeLittleEndian32(file, 16);
    writeLittleEndian16(file, 1);
    writeLittleEndian16(file, channels);
    writeLittleEndian32(file, sampleRate);
    writeLittleEndian32(file, sampleRate * channels * bitsPerSample / 8);
    writeLittleEndian16(file, channels * bitsPerSample / 8);
    writeLittleEndian16(file, bitsPerSample);
    file.write("data", 4);
    writeLittleEndian32(file, dataSize);
    for (quint32 i = 0; i < sampleCount; ++i) {
        const double phase = (static_cast<double>(i) * 440.0 * 2.0 * pi)
            / static_cast<double>(sampleRate);
        const auto sample = static_cast<qint16>(std::sin(phase) * 12000.0);
        writeLittleEndian16(file, static_cast<quint16>(sample));
    }
    file.close();
    return true;
}

bool waitForTerminal(DownloadManager &manager)
{
    if (!manager.busy()) {
        return true;
    }

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&manager, &DownloadManager::stateChanged, &loop, [&] {
        if (!manager.busy()) {
            loop.quit();
        }
    });
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(10000);
    loop.exec();
    return !manager.busy();
}

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
                connect(socket, &QTcpSocket::readyRead, this, [this, socket] {
                    if (socket->property("responded").toBool()) {
                        return;
                    }
                    const QByteArray request = socket->readAll();
                    if (!request.contains("\r\n\r\n")) {
                        return;
                    }
                    socket->setProperty("responded", true);
                    const bool playlist = request.startsWith("GET /video.m3u8 ");
                    const bool dash = request.startsWith("GET /video.mpd ");
                    const QByteArray body = playlist ? m_playlist : (dash ? m_dashManifest : m_payload);
                    const QByteArray contentType = playlist
                        ? QByteArrayLiteral("application/vnd.apple.mpegurl")
                        : (dash ? QByteArrayLiteral("application/dash+xml")
                                : QByteArrayLiteral("video/mp4"));
                    const QByteArray response = QByteArrayLiteral(
                        "HTTP/1.1 200 OK\r\nContent-Type: ")
                        + contentType
                        + QByteArrayLiteral("\r\nConnection: close\r\nContent-Length: ")
                        + QByteArray::number(body.size())
                        + QByteArrayLiteral("\r\n\r\n")
                        + body;
                    socket->write(response);
                    socket->flush();
                    QTimer::singleShot(1000, socket, [socket] {
                        socket->disconnectFromHost();
                    });
                });
            }
        });
    }

    QByteArray m_playlist;
    QByteArray m_dashManifest;

private:
    QByteArray m_payload;
};

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QTemporaryDir temporaryDirectory;
    if (!temporaryDirectory.isValid()) {
        return 1;
    }

    const QString inputPath = QDir(temporaryDirectory.path()).filePath(QStringLiteral("source.wav"));
    const QString fakeYtDlpPath = QDir(QCoreApplication::applicationDirPath()).filePath(
        QStringLiteral("ReClipFakeYtDlp.exe"));
    if (!writeWav(inputPath) || !QFileInfo(fakeYtDlpPath).isFile()) {
        return 2;
    }

    DownloadManager manager;
    manager.setDownloadDirectory(temporaryDirectory.path());
    manager.setYtDlpPath(fakeYtDlpPath);
    manager.setFfmpegPath({});
    qputenv("RECLIP_FAKE_YTDLP_OUTPUT",
            QDir::toNativeSeparators(inputPath).toLocal8Bit());
    manager.startDownload(QStringLiteral("https://example.com/media"), {}, QStringLiteral("mp3"));

    const bool terminal = waitForTerminal(manager);
    const bool completed = manager.state() == QStringLiteral("completed");
    const bool hasOutput = !manager.outputPath().isEmpty()
        && QFileInfo(manager.outputPath()).isFile()
        && QFileInfo(manager.outputPath()).suffix().compare(QStringLiteral("mp3"), Qt::CaseInsensitive) == 0;
    if (!terminal || !completed || !hasOutput) {
        std::fprintf(stderr,
                     "SDK download test failed: terminal=%d busy=%d state=%s error=%s output=%s\n",
                     terminal,
                     manager.busy(),
                     qPrintable(manager.state()),
                     qPrintable(manager.errorMessage()),
                     qPrintable(manager.outputPath()));
        qunsetenv("RECLIP_FAKE_YTDLP_OUTPUT");
        return 3;
    }
    if (QFile::exists(inputPath)) {
        qunsetenv("RECLIP_FAKE_YTDLP_OUTPUT");
        return 4;
    }

    qunsetenv("RECLIP_FAKE_YTDLP_OUTPUT");

    const QString fixturePath = QDir(QCoreApplication::applicationDirPath()).filePath(
        QStringLiteral("tiny_video_mp4.b64"));
    QFile fixtureFile(fixturePath);
    if (!fixtureFile.open(QIODevice::ReadOnly)) {
        return 5;
    }
    const QByteArray fixture = QByteArray::fromBase64(fixtureFile.readAll().trimmed());
    fixtureFile.close();
    if (fixture.isEmpty()) {
        return 6;
    }

    StaticHttpServer server(fixture);
    if (!server.listen(QHostAddress::LocalHost, 0)) {
        return 7;
    }
    server.m_playlist = QByteArrayLiteral(
        "#EXTM3U\n"
        "#EXT-X-VERSION:7\n"
        "#EXT-X-TARGETDURATION:1\n"
        "#EXT-X-MEDIA-SEQUENCE:0\n"
        "#EXT-X-PLAYLIST-TYPE:VOD\n"
        "#EXT-X-MAP:URI=\"tiny.mp4\"\n"
        "#EXTINF:0.4,\n"
        "tiny.mp4\n"
        "#EXT-X-ENDLIST\n");
    server.m_dashManifest = QByteArrayLiteral(
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

    QJsonObject resolveObject;
    resolveObject.insert(QStringLiteral("id"), QStringLiteral("fixture-video"));
    resolveObject.insert(QStringLiteral("title"), QStringLiteral("SDK network fixture"));
    resolveObject.insert(QStringLiteral("url"),
                        QStringLiteral("http://127.0.0.1:%1/fixture.mp4").arg(server.serverPort()));
    resolveObject.insert(QStringLiteral("protocol"), QStringLiteral("http"));
    resolveObject.insert(QStringLiteral("vcodec"), QStringLiteral("mpeg4"));
    resolveObject.insert(QStringLiteral("acodec"), QStringLiteral("aac"));
    resolveObject.insert(QStringLiteral("filesize"), static_cast<double>(fixture.size()));
    qputenv("RECLIP_FAKE_YTDLP_JSON",
            QJsonDocument(resolveObject).toJson(QJsonDocument::Compact));

    DownloadManager videoManager;
    videoManager.setDownloadDirectory(temporaryDirectory.path());
    videoManager.setYtDlpPath(fakeYtDlpPath);
    videoManager.setFfmpegPath({});
    videoManager.startDownload(QStringLiteral("https://example.com/video"), {}, QStringLiteral("mp4"));

    const bool videoTerminal = waitForTerminal(videoManager);
    const bool videoCompleted = videoManager.state() == QStringLiteral("completed");
    const bool videoOutput = !videoManager.outputPath().isEmpty()
        && QFileInfo(videoManager.outputPath()).isFile()
        && QFileInfo(videoManager.outputPath()).suffix().compare(QStringLiteral("mp4"), Qt::CaseInsensitive) == 0;
    if (!videoTerminal || !videoCompleted || !videoOutput) {
        std::fprintf(stderr,
                     "SDK video download test failed: terminal=%d busy=%d state=%s error=%s output=%s\n",
                     videoTerminal,
                     videoManager.busy(),
                     qPrintable(videoManager.state()),
                     qPrintable(videoManager.errorMessage()),
                     qPrintable(videoManager.outputPath()));
        qunsetenv("RECLIP_FAKE_YTDLP_JSON");
        return 8;
    }

    ReClip::Ffmpeg::FfprobeService ffprobe;
    const ReClip::Ffmpeg::ProbeResult probe = ffprobe.probe(videoManager.outputPath());
    bool hasVideo = false;
    bool hasAudio = false;
    for (const ReClip::Ffmpeg::StreamInfo &stream : probe.media.streams) {
        hasVideo = hasVideo || stream.type == QStringLiteral("video");
        hasAudio = hasAudio || stream.type == QStringLiteral("audio");
    }
    qunsetenv("RECLIP_FAKE_YTDLP_JSON");
    if (!probe.ok || !hasVideo || !hasAudio) {
        return 9;
    }

    QJsonObject separateVideo = resolveObject;
    separateVideo.insert(QStringLiteral("vcodec"), QStringLiteral("mpeg4"));
    separateVideo.insert(QStringLiteral("acodec"), QStringLiteral("none"));
    QJsonObject separateAudio = resolveObject;
    separateAudio.insert(QStringLiteral("vcodec"), QStringLiteral("none"));
    separateAudio.insert(QStringLiteral("acodec"), QStringLiteral("aac"));
    QJsonObject separateResolveObject;
    separateResolveObject.insert(QStringLiteral("id"), QStringLiteral("separate-fixture"));
    separateResolveObject.insert(QStringLiteral("title"), QStringLiteral("SDK separate fixture"));
    QJsonArray requestedFormats;
    requestedFormats.append(separateVideo);
    requestedFormats.append(separateAudio);
    separateResolveObject.insert(QStringLiteral("requested_formats"), requestedFormats);
    qputenv("RECLIP_FAKE_YTDLP_JSON",
            QJsonDocument(separateResolveObject).toJson(QJsonDocument::Compact));

    DownloadManager separateManager;
    separateManager.setDownloadDirectory(temporaryDirectory.path());
    separateManager.setYtDlpPath(fakeYtDlpPath);
    separateManager.setFfmpegPath({});
    separateManager.startDownload(QStringLiteral("https://example.com/separate-video"),
                                  {},
                                  QStringLiteral("mp4"));
    const bool separateTerminal = waitForTerminal(separateManager);
    const bool separateCompleted = separateTerminal
        && separateManager.state() == QStringLiteral("completed")
        && QFileInfo(separateManager.outputPath()).isFile();
    const ReClip::Ffmpeg::ProbeResult separateProbe =
        ffprobe.probe(separateManager.outputPath());
    bool separateHasVideo = false;
    bool separateHasAudio = false;
    for (const ReClip::Ffmpeg::StreamInfo &stream : separateProbe.media.streams) {
        separateHasVideo = separateHasVideo || stream.type == QStringLiteral("video");
        separateHasAudio = separateHasAudio || stream.type == QStringLiteral("audio");
    }
    qunsetenv("RECLIP_FAKE_YTDLP_JSON");
    if (!separateCompleted || !separateProbe.ok || !separateHasVideo || !separateHasAudio) {
        return 10;
    }

    QJsonObject hlsResolveObject;
    hlsResolveObject.insert(QStringLiteral("id"), QStringLiteral("hls-fixture"));
    hlsResolveObject.insert(QStringLiteral("title"), QStringLiteral("SDK HLS fixture"));
    hlsResolveObject.insert(QStringLiteral("url"),
                            QStringLiteral("http://127.0.0.1:%1/video.m3u8")
                                .arg(server.serverPort()));
    hlsResolveObject.insert(QStringLiteral("protocol"), QStringLiteral("m3u8"));
    hlsResolveObject.insert(QStringLiteral("vcodec"), QStringLiteral("mpeg4"));
    hlsResolveObject.insert(QStringLiteral("acodec"), QStringLiteral("aac"));
    qputenv("RECLIP_FAKE_YTDLP_JSON",
            QJsonDocument(hlsResolveObject).toJson(QJsonDocument::Compact));
    DownloadManager hlsManager;
    hlsManager.setDownloadDirectory(temporaryDirectory.path());
    hlsManager.setYtDlpPath(fakeYtDlpPath);
    hlsManager.setFfmpegPath({});
    hlsManager.startDownload(QStringLiteral("https://example.com/hls"), {}, QStringLiteral("mp4"));
    const bool hlsTerminal = waitForTerminal(hlsManager);
    const auto hlsProbe = ffprobe.probe(hlsManager.outputPath());
    bool hlsHasVideo = false;
    bool hlsHasAudio = false;
    for (const auto &stream : hlsProbe.media.streams) {
        hlsHasVideo = hlsHasVideo || stream.type == QStringLiteral("video");
        hlsHasAudio = hlsHasAudio || stream.type == QStringLiteral("audio");
    }
    qunsetenv("RECLIP_FAKE_YTDLP_JSON");
    if (!hlsTerminal || hlsManager.state() != QStringLiteral("completed")
        || !hlsProbe.ok || !hlsHasVideo || !hlsHasAudio) {
        std::fprintf(stderr,
                     "SDK HLS download test failed: terminal=%d busy=%d state=%s error=%s output=%s\n",
                     hlsTerminal,
                     hlsManager.busy(),
                     qPrintable(hlsManager.state()),
                     qPrintable(hlsManager.errorMessage()),
                     qPrintable(hlsManager.outputPath()));
        return 11;
    }

    QJsonObject dashResolveObject = hlsResolveObject;
    dashResolveObject.insert(QStringLiteral("id"), QStringLiteral("dash-fixture"));
    dashResolveObject.insert(QStringLiteral("title"), QStringLiteral("SDK DASH fixture"));
    dashResolveObject.insert(QStringLiteral("url"),
                             QStringLiteral("http://127.0.0.1:%1/video.mpd")
                                 .arg(server.serverPort()));
    dashResolveObject.insert(QStringLiteral("protocol"), QStringLiteral("http_dash_segments"));
    qputenv("RECLIP_FAKE_YTDLP_JSON",
            QJsonDocument(dashResolveObject).toJson(QJsonDocument::Compact));
    DownloadManager dashManager;
    dashManager.setDownloadDirectory(temporaryDirectory.path());
    dashManager.setYtDlpPath(fakeYtDlpPath);
    dashManager.setFfmpegPath({});
    dashManager.startDownload(QStringLiteral("https://example.com/dash"), {}, QStringLiteral("mp4"));
    const bool dashTerminal = waitForTerminal(dashManager);
    const auto dashProbe = ffprobe.probe(dashManager.outputPath());
    bool dashHasVideo = false;
    bool dashHasAudio = false;
    for (const auto &stream : dashProbe.media.streams) {
        dashHasVideo = dashHasVideo || stream.type == QStringLiteral("video");
        dashHasAudio = dashHasAudio || stream.type == QStringLiteral("audio");
    }
    qunsetenv("RECLIP_FAKE_YTDLP_JSON");
    if (!dashTerminal || dashManager.state() != QStringLiteral("completed")
        || !dashProbe.ok || !dashHasVideo || !dashHasAudio) {
        std::fprintf(stderr,
                     "SDK DASH download test failed: terminal=%d busy=%d state=%s error=%s output=%s\n",
                     dashTerminal,
                     dashManager.busy(),
                     qPrintable(dashManager.state()),
                     qPrintable(dashManager.errorMessage()),
                     qPrintable(dashManager.outputPath()));
        return 14;
    }

    const QString fallbackOutputPath = QDir(temporaryDirectory.path()).filePath(
        QStringLiteral("fallback-output.mp4"));
    if (!QFile::copy(videoManager.outputPath(), fallbackOutputPath)) {
        qunsetenv("RECLIP_FAKE_YTDLP_JSON");
        return 12;
    }
    QJsonObject unsupportedResolveObject;
    unsupportedResolveObject.insert(QStringLiteral("id"), QStringLiteral("hls-video"));
    unsupportedResolveObject.insert(QStringLiteral("title"), QStringLiteral("Unsupported fallback"));
    unsupportedResolveObject.insert(QStringLiteral("url"),
                                    QStringLiteral("file:///unsupported-media"));
    unsupportedResolveObject.insert(QStringLiteral("protocol"), QStringLiteral("websocket"));
    qputenv("RECLIP_FAKE_YTDLP_JSON",
            QJsonDocument(unsupportedResolveObject).toJson(QJsonDocument::Compact));
    qputenv("RECLIP_FAKE_YTDLP_OUTPUT", fallbackOutputPath.toLocal8Bit());

    DownloadManager fallbackManager;
    fallbackManager.setDownloadDirectory(temporaryDirectory.path());
    fallbackManager.setYtDlpPath(fakeYtDlpPath);
    fallbackManager.setFfmpegPath(fakeYtDlpPath);
    fallbackManager.startDownload(QStringLiteral("https://example.com/hls-video"), {}, QStringLiteral("mp4"));
    const bool fallbackTerminal = waitForTerminal(fallbackManager);
    const bool fallbackCompleted = fallbackManager.state() == QStringLiteral("completed")
        && fallbackManager.outputPath() == fallbackOutputPath;
    qunsetenv("RECLIP_FAKE_YTDLP_JSON");
    qunsetenv("RECLIP_FAKE_YTDLP_OUTPUT");
    if (!fallbackTerminal || !fallbackCompleted) {
        return 13;
    }

    return 0;
}
