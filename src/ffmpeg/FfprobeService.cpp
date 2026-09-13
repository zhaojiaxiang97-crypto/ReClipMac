#include "FfprobeService.h"

#include "FfmpegSdk.h"
#include "FfmpegService.h"

namespace ReClip::Ffmpeg {

ProbeResult FfprobeService::probe(const QString &inputPath) const
{
    return probe(InputSource{inputPath, {}, 30000});
}

ProbeResult FfprobeService::probe(const InputSource &input) const
{
    // FfmpegService owns the shared libavformat input lifecycle and packet
    // helpers. Keep one implementation so remux/transcode and ffprobe expose
    // exactly the same stream metadata and error handling.
    return FfmpegService().probe(input);
}

QString FfprobeService::runtimeVersion()
{
    return ReClip::Ffmpeg::runtimeVersion();
}

unsigned int FfprobeService::avformatVersion()
{
    return ReClip::Ffmpeg::avformatVersion();
}

} // namespace ReClip::Ffmpeg
