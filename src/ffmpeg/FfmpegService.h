#pragma once

#include "FfmpegTypes.h"

#include <QString>

namespace ReClip::Ffmpeg {

class FfmpegService final
{
public:
    ProbeResult probe(const QString &inputPath) const;
    ProbeResult probe(const InputSource &input) const;

    OperationResult remux(const QString &inputPath,
                          const QString &outputPath,
                          const OperationOptions &options = {}) const;
    OperationResult remux(const QString &videoInputPath,
                          const QString &audioInputPath,
                          const QString &outputPath,
                          const OperationOptions &options = {}) const;
    OperationResult remux(const InputSource &input,
                          const QString &outputPath,
                          const OperationOptions &options = {}) const;
    OperationResult remux(const InputSource &videoInput,
                          const InputSource &audioInput,
                          const QString &outputPath,
                          const OperationOptions &options = {}) const;

    OperationResult transcodeAudio(const QString &inputPath,
                                   const QString &outputPath,
                                   const AudioOptions &audioOptions = {},
                                   const OperationOptions &options = {}) const;
    OperationResult transcodeAudio(const InputSource &input,
                                   const QString &outputPath,
                                   const AudioOptions &audioOptions = {},
                                   const OperationOptions &options = {}) const;
};

} // namespace ReClip::Ffmpeg
