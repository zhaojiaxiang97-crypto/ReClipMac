#pragma once

#include "FfmpegTypes.h"

#include <QString>

namespace ReClip::Ffmpeg {

// In-process replacement for the ffprobe command-line frontend.  ffprobe is
// not a separate codec library: its media inspection is provided by the same
// libavformat/libavcodec/libavutil SDK used by FfmpegService.
class FfprobeService final
{
public:
    ProbeResult probe(const QString &inputPath) const;
    ProbeResult probe(const InputSource &input) const;

    static QString runtimeVersion();
    static unsigned int avformatVersion();
};

} // namespace ReClip::Ffmpeg
