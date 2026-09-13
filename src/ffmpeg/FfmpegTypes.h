#pragma once

#include <QList>
#include <QPair>
#include <QString>
#include <QVector>

#include <functional>
#include <limits>

namespace ReClip::Ffmpeg {

struct FfmpegError {
    QString code;
    QString message;
    int nativeCode = 0;
};

struct OperationResult {
    bool ok = false;
    FfmpegError error;
};

struct OperationOptions {
    std::function<bool()> isCancelled;
    std::function<void(double)> progress;
    bool overwriteExisting = true;
};

// An input can be a local file or an HTTP(S) resource.  The latter is used
// for segmented media (HLS/DASH) so libavformat can fetch the manifest and
// segments in-process instead of delegating to a command-line downloader.
struct InputSource {
    QString location;
    QList<QPair<QByteArray, QByteArray>> headers;
    int timeoutMs = 30000;
};

struct StreamInfo {
    int index = -1;
    QString type;
    QString codec;
    qint64 durationMs = -1;
    int sampleRate = 0;
    int channels = 0;
};

struct MediaInfo {
    QString format;
    QString formatLongName;
    qint64 durationMs = -1;
    qint64 sizeBytes = -1;
    QVector<StreamInfo> streams;
};

struct ProbeResult {
    bool ok = false;
    MediaInfo media;
    FfmpegError error;
};

struct AudioOptions {
    int bitrateKbps = 192;
};

} // namespace ReClip::Ffmpeg
