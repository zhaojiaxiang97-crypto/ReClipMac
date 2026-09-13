#include "ffmpeg/FfmpegSdk.h"
#include "ffmpeg/FfprobeService.h"

#include <QCoreApplication>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    if (ReClip::Ffmpeg::runtimeVersion().isEmpty()) {
        return 1;
    }
    if (ReClip::Ffmpeg::avformatVersion() == 0) {
        return 2;
    }
    if (ReClip::Ffmpeg::FfprobeService::runtimeVersion().isEmpty()
        || ReClip::Ffmpeg::FfprobeService::avformatVersion() == 0) {
        return 3;
    }

    return 0;
}
