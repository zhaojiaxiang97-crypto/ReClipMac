#include "FfmpegSdk.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
}

namespace ReClip::Ffmpeg {

QString runtimeVersion()
{
    return QString::fromUtf8(av_version_info());
}

unsigned int avformatVersion()
{
    return avformat_version();
}

} // namespace ReClip::Ffmpeg
