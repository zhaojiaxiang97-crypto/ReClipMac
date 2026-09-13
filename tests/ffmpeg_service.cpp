#include "ffmpeg/FfmpegService.h"
#include "ffmpeg/FfprobeService.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>

#include <cmath>
#include <cstdint>

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

    constexpr double pi = 3.14159265358979323846;
    for (quint32 i = 0; i < sampleCount; ++i) {
        const double phase = (static_cast<double>(i) * 440.0 * 2.0 * pi)
            / static_cast<double>(sampleRate);
        const auto sample = static_cast<qint16>(std::sin(phase) * 12000.0);
        writeLittleEndian16(file, static_cast<quint16>(sample));
    }
    return file.close(), true;
}

bool hasAudioStream(const ReClip::Ffmpeg::MediaInfo &media)
{
    for (const auto &stream : media.streams) {
        if (stream.type == QStringLiteral("audio")) {
            return true;
        }
    }
    return false;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QTemporaryDir temporaryDirectory;
    if (!temporaryDirectory.isValid()) {
        return 1;
    }

    const QString inputPath = QDir(temporaryDirectory.path()).filePath(QStringLiteral("input.wav"));
    const QString remuxPath = QDir(temporaryDirectory.path()).filePath(QStringLiteral("output.mka"));
    const QString mp3Path = QDir(temporaryDirectory.path()).filePath(QStringLiteral("output.mp3"));
    if (!writeWav(inputPath)) {
        return 2;
    }

    ReClip::Ffmpeg::FfmpegService service;
    ReClip::Ffmpeg::FfprobeService ffprobe;
    const auto inputProbe = ffprobe.probe(inputPath);
    if (!inputProbe.ok || inputProbe.media.format.isEmpty() || !hasAudioStream(inputProbe.media)) {
        return 3;
    }

    const auto remuxResult = service.remux(inputPath, remuxPath);
    if (!remuxResult.ok) {
        return 4;
    }
    const auto remuxProbe = ffprobe.probe(remuxPath);
    if (!remuxProbe.ok || !hasAudioStream(remuxProbe.media)) {
        return 5;
    }

    const QString progressRemuxPath = QDir(temporaryDirectory.path()).filePath(
        QStringLiteral("progress-output.mka"));
    QVector<double> progressValues;
    ReClip::Ffmpeg::OperationOptions progressOptions;
    progressOptions.progress = [&progressValues](double value) {
        progressValues.append(value);
    };
    const auto progressResult = service.remux(inputPath, progressRemuxPath, progressOptions);
    if (!progressResult.ok || progressValues.isEmpty() || progressValues.last() < 0.99) {
        return 6;
    }

    const QString cancelledPath = QDir(temporaryDirectory.path()).filePath(
        QStringLiteral("cancelled-output.mka"));
    ReClip::Ffmpeg::OperationOptions cancelledOptions;
    cancelledOptions.isCancelled = [] {
        return true;
    };
    const auto cancelledResult = service.remux(inputPath, cancelledPath, cancelledOptions);
    if (cancelledResult.ok || cancelledResult.error.code != QStringLiteral("cancelled")
        || QFile::exists(cancelledPath)) {
        return 7;
    }

    const auto transcodeResult = service.transcodeAudio(inputPath, mp3Path);
    if (!transcodeResult.ok) {
        return 8;
    }
    const auto mp3Probe = ffprobe.probe(mp3Path);
    if (!mp3Probe.ok || !hasAudioStream(mp3Probe.media)) {
        return 9;
    }

    return 0;
}
