#include "FfmpegService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStringList>
#include <QUrl>
#include <QUuid>

#include <algorithm>
#include <limits>
#include <vector>

extern "C" {
#include <libavutil/audio_fifo.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/mathematics.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
}

namespace {

using namespace ReClip::Ffmpeg;

QString ffmpegErrorText(int errorCode)
{
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {};
    av_strerror(errorCode, buffer, sizeof(buffer));
    return QString::fromUtf8(buffer);
}

FfmpegError makeError(const QString &code,
                      const QString &message,
                      int nativeCode = 0)
{
    QString fullMessage = message;
    if (nativeCode < 0) {
        const QString detail = ffmpegErrorText(nativeCode);
        if (!detail.isEmpty()) {
            fullMessage += QStringLiteral(" (") + detail + QLatin1Char(')');
        }
    }
    return {code, fullMessage, nativeCode};
}

OperationResult failed(const QString &code,
                       const QString &message,
                       int nativeCode = 0)
{
    return {false, makeError(code, message, nativeCode)};
}

OperationResult succeeded()
{
    return {true, {}};
}

bool operationCancelled(const OperationOptions *options)
{
    return options && options->isCancelled && options->isCancelled();
}

OperationResult cancelledOperation()
{
    return failed(QStringLiteral("cancelled"), QStringLiteral("Operation cancelled"));
}

class ProgressReporter final
{
public:
    explicit ProgressReporter(const OperationOptions *options)
        : m_options(options)
    {
    }

    void report(double fraction)
    {
        if (!m_options || !m_options->progress) {
            return;
        }

        const double bounded = std::clamp(fraction, 0.0, 1.0);
        if (m_last >= 0.0 && bounded < 1.0 && bounded - m_last < 0.01) {
            return;
        }
        m_last = bounded;
        m_options->progress(bounded);
    }

private:
    const OperationOptions *m_options = nullptr;
    double m_last = -1.0;
};

int ffmpegInterruptCallback(void *opaque)
{
    const auto *options = static_cast<const OperationOptions *>(opaque);
    return operationCancelled(options) ? 1 : 0;
}

ProbeResult probeFailed(const QString &code,
                        const QString &message,
                        int nativeCode = 0)
{
    return {false, {}, makeError(code, message, nativeCode)};
}

bool isFilePath(const QString &path)
{
    return !path.trimmed().isEmpty() && QFileInfo(path).isFile();
}

bool isHttpInput(const QString &location)
{
    const QUrl url(location);
    return url.isValid() && !url.host().isEmpty()
        && (url.scheme().compare(QStringLiteral("http"), Qt::CaseInsensitive) == 0
            || url.scheme().compare(QStringLiteral("https"), Qt::CaseInsensitive) == 0);
}

bool hasOutputDirectory(const QString &path)
{
    const QFileInfo info(path);
    return !info.fileName().isEmpty() && QDir(info.absolutePath()).exists();
}

QString temporaryOutputPath(const QString &outputPath)
{
    const QFileInfo info(outputPath);
    const QString suffix = QUuid::createUuid().toString(QUuid::WithoutBraces);
    return QDir(info.absolutePath()).filePath(
        QStringLiteral(".%1.reclip-%2.part").arg(info.fileName(), suffix));
}

OperationResult commitOutput(const QString &temporaryPath,
                              const QString &outputPath,
                              bool overwriteExisting)
{
    if (QFile::exists(outputPath) && (!overwriteExisting || !QFile::remove(outputPath))) {
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("output-not-replaceable"),
                      QStringLiteral("Unable to replace the existing output file"));
    }
    if (!QFile::rename(temporaryPath, outputPath)) {
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("output-rename-failed"),
                      QStringLiteral("Unable to move the completed media file into place"));
    }
    return succeeded();
}

bool openInput(const InputSource &source,
               AVFormatContext **context,
               FfmpegError *error,
               const OperationOptions *options = nullptr)
{
    if (operationCancelled(options)) {
        if (error) {
            *error = cancelledOperation().error;
        }
        return false;
    }
    const bool remote = isHttpInput(source.location);
    if (!remote && !isFilePath(source.location)) {
        if (error) {
            *error = makeError(QStringLiteral("input-not-found"),
                               QStringLiteral("Input media file or HTTP(S) resource is unavailable"));
        }
        return false;
    }

    const QByteArray encodedPath = remote
        ? QUrl(source.location).toEncoded(QUrl::FullyEncoded)
        : QFile::encodeName(source.location);
    AVFormatContext *allocatedContext = avformat_alloc_context();
    if (!allocatedContext) {
        if (error) {
            *error = makeError(QStringLiteral("memory-allocation-failed"),
                               QStringLiteral("Unable to allocate the input format context"));
        }
        return false;
    }
    if (options) {
        allocatedContext->interrupt_callback.callback = ffmpegInterruptCallback;
        allocatedContext->interrupt_callback.opaque = const_cast<OperationOptions *>(options);
    }
    *context = allocatedContext;
    AVDictionary *formatOptions = nullptr;
    if (remote) {
        QByteArray headerBlock;
        for (const auto &header : source.headers) {
            if (header.first.isEmpty() || header.second.isEmpty()
                || header.first.contains('\r') || header.first.contains('\n')
                || header.second.contains('\r') || header.second.contains('\n')) {
                continue;
            }
            headerBlock += header.first;
            headerBlock += ": ";
            headerBlock += header.second;
            headerBlock += "\r\n";
        }
        if (!headerBlock.isEmpty()) {
            av_dict_set(&formatOptions, "headers", headerBlock.constData(), 0);
        }
        const int timeoutMs = std::clamp(source.timeoutMs, 1000, 600000);
        const int64_t timeoutUs = static_cast<int64_t>(timeoutMs) * 1000;
        av_dict_set_int(&formatOptions, "rw_timeout", timeoutUs, 0);
        av_dict_set_int(&formatOptions, "timeout", timeoutUs, 0);
    }
    int result = avformat_open_input(context,
                                     encodedPath.constData(),
                                     nullptr,
                                     &formatOptions);
    av_dict_free(&formatOptions);
    if (result < 0) {
        avformat_close_input(context);
        if (error) {
            *error = operationCancelled(options)
                ? cancelledOperation().error
                : makeError(QStringLiteral("input-open-failed"),
                            QStringLiteral("Unable to open the input media source"),
                            result);
        }
        return false;
    }

    result = avformat_find_stream_info(*context, nullptr);
    if (result < 0) {
        avformat_close_input(context);
        if (error) {
            *error = operationCancelled(options)
                ? cancelledOperation().error
                : makeError(QStringLiteral("input-probe-failed"),
                            QStringLiteral("Unable to read input media stream information"),
                            result);
        }
        return false;
    }
    return true;
}

void closeInput(AVFormatContext **context)
{
    if (context && *context) {
        avformat_close_input(context);
    }
}

void closeOutput(AVFormatContext **context, bool writeTrailer)
{
    if (!context || !*context) {
        return;
    }
    if (writeTrailer) {
        av_write_trailer(*context);
    }
    if (!((*context)->oformat->flags & AVFMT_NOFILE) && (*context)->pb) {
        avio_closep(&(*context)->pb);
    }
    avformat_free_context(*context);
    *context = nullptr;
}

bool openOutput(AVFormatContext **context,
                const QString &formatHintPath,
                const QString &temporaryPath,
                FfmpegError *error,
                const OperationOptions *options = nullptr)
{
    if (operationCancelled(options)) {
        if (error) {
            *error = cancelledOperation().error;
        }
        return false;
    }
    const QByteArray formatHint = QFile::encodeName(formatHintPath);
    int result = avformat_alloc_output_context2(
        context, nullptr, nullptr, formatHint.constData());
    if (result < 0 || !*context) {
        if (error) {
            *error = makeError(QStringLiteral("output-format-unsupported"),
                               QStringLiteral("Unable to select an output container"),
                               result < 0 ? result : AVERROR_UNKNOWN);
        }
        return false;
    }
    if (options) {
        (*context)->interrupt_callback.callback = ffmpegInterruptCallback;
        (*context)->interrupt_callback.opaque = const_cast<OperationOptions *>(options);
    }

    if (!((*context)->oformat->flags & AVFMT_NOFILE)) {
        const QByteArray outputPath = QFile::encodeName(temporaryPath);
        result = avio_open(&(*context)->pb, outputPath.constData(), AVIO_FLAG_WRITE);
        if (result < 0) {
            avformat_free_context(*context);
            *context = nullptr;
            if (error) {
                *error = operationCancelled(options)
                    ? cancelledOperation().error
                    : makeError(QStringLiteral("output-open-failed"),
                                QStringLiteral("Unable to open the temporary output file"),
                                result);
            }
            return false;
        }
    }
    return true;
}

int streamType(const AVStream *stream)
{
    return stream && stream->codecpar ? stream->codecpar->codec_type : AVMEDIA_TYPE_UNKNOWN;
}

bool shouldCopyStream(const AVStream *stream, int inputIndex, bool hasSeparateAudio)
{
    if (!hasSeparateAudio) {
        return true;
    }
    if (inputIndex == 0) {
        return streamType(stream) == AVMEDIA_TYPE_VIDEO;
    }
    return streamType(stream) == AVMEDIA_TYPE_AUDIO;
}

struct StreamMapping {
    int inputStreamIndex = -1;
    int outputStreamIndex = -1;
};

int64_t packetTimestamp(const AVPacket *packet)
{
    if (!packet) {
        return AV_NOPTS_VALUE;
    }
    if (packet->dts != AV_NOPTS_VALUE) {
        return packet->dts;
    }
    return packet->pts;
}

OperationResult writeRemuxPacket(AVFormatContext *output,
                                 AVFormatContext *input,
                                 const StreamMapping &mapping,
                                 AVPacket *packet,
                                 const OperationOptions *options)
{
    if (operationCancelled(options)) {
        return cancelledOperation();
    }
    AVStream *inputStream = input->streams[mapping.inputStreamIndex];
    AVStream *outputStream = output->streams[mapping.outputStreamIndex];
    av_packet_rescale_ts(packet, inputStream->time_base, outputStream->time_base);
    packet->stream_index = mapping.outputStreamIndex;
    packet->pos = -1;

    const int result = av_interleaved_write_frame(output, packet);
    if (result < 0) {
        if (operationCancelled(options) || result == AVERROR_EXIT) {
            return cancelledOperation();
        }
        return failed(QStringLiteral("remux-write-failed"),
                      QStringLiteral("Unable to write a media packet"),
                      result);
    }
    return succeeded();
}

int chooseSampleRate(const AVCodec *codec, int requested)
{
    const int fallback = requested > 0 ? requested : 44100;
    if (!codec) {
        return fallback;
    }

    const void *supportedRates = nullptr;
    int supportedRateCount = 0;
    if (avcodec_get_supported_config(nullptr,
                                     codec,
                                     AV_CODEC_CONFIG_SAMPLE_RATE,
                                     0,
                                     &supportedRates,
                                     &supportedRateCount) < 0
        || !supportedRates
        || supportedRateCount <= 0) {
        return fallback;
    }

    const auto *rates = static_cast<const int *>(supportedRates);
    int best = rates[0];
    int bestDistance = std::abs(best - fallback);
    for (int i = 0; i < supportedRateCount; ++i) {
        const int distance = std::abs(rates[i] - fallback);
        if (distance < bestDistance) {
            best = rates[i];
            bestDistance = distance;
        }
    }
    return best;
}

AVSampleFormat chooseSampleFormat(const AVCodec *codec)
{
    if (codec) {
        const void *supportedFormats = nullptr;
        int supportedFormatCount = 0;
        if (avcodec_get_supported_config(nullptr,
                                         codec,
                                         AV_CODEC_CONFIG_SAMPLE_FORMAT,
                                         0,
                                         &supportedFormats,
                                         &supportedFormatCount) >= 0
            && supportedFormats
            && supportedFormatCount > 0) {
            return static_cast<const AVSampleFormat *>(supportedFormats)[0];
        }
    }
    return AV_SAMPLE_FMT_FLTP;
}

} // namespace

namespace ReClip::Ffmpeg {

ProbeResult FfmpegService::probe(const QString &inputPath) const
{
    return probe(InputSource{inputPath, {}, 30000});
}

ProbeResult FfmpegService::probe(const InputSource &inputSource) const
{
    AVFormatContext *input = nullptr;
    FfmpegError error;
    if (!openInput(inputSource, &input, &error)) {
        return {false, {}, error};
    }

    MediaInfo media;
    if (input->iformat) {
        media.format = QString::fromUtf8(input->iformat->name);
        media.formatLongName = QString::fromUtf8(input->iformat->long_name);
    }
    if (input->duration != AV_NOPTS_VALUE) {
        media.durationMs = av_rescale_q(input->duration, AVRational{1, 1000000},
                                        AVRational{1, 1000});
    }
    const qint64 fileSize = isFilePath(inputSource.location)
        ? QFileInfo(inputSource.location).size()
        : -1;
    if (fileSize >= 0) {
        media.sizeBytes = fileSize;
    }

    media.streams.reserve(static_cast<int>(input->nb_streams));
    for (unsigned int i = 0; i < input->nb_streams; ++i) {
        const AVStream *stream = input->streams[i];
        const AVCodecParameters *parameters = stream->codecpar;
        StreamInfo info;
        info.index = static_cast<int>(i);
        if (parameters) {
            const char *type = av_get_media_type_string(parameters->codec_type);
            info.type = type ? QString::fromUtf8(type) : QStringLiteral("unknown");
            info.codec = QString::fromUtf8(avcodec_get_name(parameters->codec_id));
            info.sampleRate = parameters->sample_rate;
            info.channels = parameters->ch_layout.nb_channels;
        }
        if (stream->duration != AV_NOPTS_VALUE) {
            info.durationMs = av_rescale_q(stream->duration,
                                           stream->time_base,
                                           AVRational{1, 1000});
        }
        media.streams.push_back(info);
    }

    closeInput(&input);
    return {true, media, {}};
}

OperationResult FfmpegService::remux(const QString &inputPath,
                                     const QString &outputPath,
                                     const OperationOptions &options) const
{
    return remux(InputSource{inputPath, {}, 30000}, outputPath, options);
}

OperationResult FfmpegService::remux(const QString &videoInputPath,
                                     const QString &audioInputPath,
                                     const QString &outputPath,
                                     const OperationOptions &options) const
{
    return remux(InputSource{videoInputPath, {}, 30000},
                 InputSource{audioInputPath, {}, 30000},
                 outputPath,
                 options);
}

OperationResult FfmpegService::remux(const InputSource &input,
                                     const QString &outputPath,
                                     const OperationOptions &options) const
{
    return remux(input, InputSource{}, outputPath, options);
}

OperationResult FfmpegService::remux(const InputSource &videoInput,
                                     const InputSource &audioInput,
                                     const QString &outputPath,
                                     const OperationOptions &options) const
{
    if (operationCancelled(&options)) {
        return cancelledOperation();
    }
    ProgressReporter progress(&options);
    progress.report(0.0);
    if (!hasOutputDirectory(outputPath)) {
        return failed(QStringLiteral("output-directory-missing"),
                      QStringLiteral("The output directory does not exist"));
    }
    if (!audioInput.location.isEmpty()
        && !isHttpInput(audioInput.location)
        && !isFilePath(audioInput.location)) {
        return failed(QStringLiteral("input-not-found"),
                      QStringLiteral("The audio input media source is unavailable"));
    }

    const bool hasSeparateAudio = !audioInput.location.isEmpty();
    const QList<InputSource> inputSources = hasSeparateAudio
        ? QList<InputSource>{videoInput, audioInput}
        : QList<InputSource>{videoInput};

    std::vector<AVFormatContext *> inputs(inputSources.size(), nullptr);
    FfmpegError error;
    for (int i = 0; i < inputSources.size(); ++i) {
        if (!openInput(inputSources.at(i), &inputs[static_cast<size_t>(i)], &error, &options)) {
            for (AVFormatContext *&input : inputs) {
                closeInput(&input);
            }
            return {false, error};
        }
    }

    const QString temporaryPath = temporaryOutputPath(outputPath);
    AVFormatContext *output = nullptr;
    if (!openOutput(&output, outputPath, temporaryPath, &error, &options)) {
        for (AVFormatContext *&input : inputs) {
            closeInput(&input);
        }
        return {false, error};
    }

    std::vector<std::vector<StreamMapping>> mappings(inputs.size());
    for (size_t inputIndex = 0; inputIndex < inputs.size(); ++inputIndex) {
        AVFormatContext *input = inputs[inputIndex];
        mappings[inputIndex].resize(input->nb_streams);
        for (unsigned int streamIndex = 0; streamIndex < input->nb_streams; ++streamIndex) {
            mappings[inputIndex][streamIndex].inputStreamIndex = static_cast<int>(streamIndex);
            if (!shouldCopyStream(input->streams[streamIndex],
                                  static_cast<int>(inputIndex),
                                  hasSeparateAudio)) {
                continue;
            }

            AVStream *outputStream = avformat_new_stream(output, nullptr);
            if (!outputStream) {
                closeOutput(&output, false);
                for (AVFormatContext *&context : inputs) {
                    closeInput(&context);
                }
                QFile::remove(temporaryPath);
                return failed(QStringLiteral("remux-stream-allocation-failed"),
                              QStringLiteral("Unable to create an output stream"));
            }

            const int result = avcodec_parameters_copy(
                outputStream->codecpar, input->streams[streamIndex]->codecpar);
            if (result < 0) {
                closeOutput(&output, false);
                for (AVFormatContext *&context : inputs) {
                    closeInput(&context);
                }
                QFile::remove(temporaryPath);
                return failed(QStringLiteral("remux-stream-copy-failed"),
                              QStringLiteral("Unable to copy input stream parameters"),
                              result);
            }
            outputStream->codecpar->codec_tag = 0;
            outputStream->time_base = input->streams[streamIndex]->time_base;
            mappings[inputIndex][streamIndex].outputStreamIndex = outputStream->index;
        }
    }

    if (output->nb_streams == 0) {
        closeOutput(&output, false);
        for (AVFormatContext *&context : inputs) {
            closeInput(&context);
        }
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("remux-no-supported-stream"),
                      QStringLiteral("No supported media stream was found"));
    }

    int result = avformat_write_header(output, nullptr);
    if (result < 0) {
        closeOutput(&output, false);
        for (AVFormatContext *&context : inputs) {
            closeInput(&context);
        }
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("remux-header-failed"),
                      QStringLiteral("Unable to write the output header"),
                      result);
    }

    AVPacket *packet = av_packet_alloc();
    if (!packet) {
        closeOutput(&output, true);
        for (AVFormatContext *&context : inputs) {
            closeInput(&context);
        }
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("memory-allocation-failed"),
                      QStringLiteral("Unable to allocate a media packet"));
    }

    OperationResult writeResult = succeeded();
    const auto reportPacketProgress = [&](int inputIndex, const AVPacket *packet) {
        if (!packet || inputIndex < 0 || inputIndex >= static_cast<int>(inputs.size())) {
            return;
        }
        const AVFormatContext *input = inputs[static_cast<size_t>(inputIndex)];
        const int streamIndex = packet->stream_index;
        if (!input || streamIndex < 0 || streamIndex >= static_cast<int>(input->nb_streams)
            || input->duration <= 0) {
            return;
        }
        const int64_t timestamp = packetTimestamp(packet);
        if (timestamp == AV_NOPTS_VALUE) {
            return;
        }
        const int64_t timestampUs = av_rescale_q(
            timestamp, input->streams[streamIndex]->time_base, AVRational{1, AV_TIME_BASE});
        if (!hasSeparateAudio) {
            progress.report(static_cast<double>(timestampUs)
                            / static_cast<double>(input->duration));
            return;
        }

        const int64_t firstDuration = qMax<int64_t>(0, inputs[0]->duration);
        const int64_t secondDuration = qMax<int64_t>(0, inputs[1]->duration);
        const int64_t totalDuration = firstDuration + secondDuration;
        if (totalDuration > 0) {
            const int64_t base = inputIndex == 0 ? 0 : firstDuration;
            progress.report(static_cast<double>(base + qMax<int64_t>(0, timestampUs))
                            / static_cast<double>(totalDuration));
        }
    };

    if (!hasSeparateAudio) {
        while (!operationCancelled(&options)
               && (result = av_read_frame(inputs[0], packet)) >= 0) {
            const int streamIndex = packet->stream_index;
            const StreamMapping &mapping = mappings[0][static_cast<size_t>(streamIndex)];
            if (mapping.outputStreamIndex >= 0) {
                reportPacketProgress(0, packet);
                writeResult = writeRemuxPacket(output, inputs[0], mapping, packet, &options);
                if (!writeResult.ok) {
                    av_packet_unref(packet);
                    break;
                }
            }
            av_packet_unref(packet);
        }
        if (operationCancelled(&options)) {
            writeResult = cancelledOperation();
        } else if (writeResult.ok && result < 0 && result != AVERROR_EOF) {
            writeResult = failed(QStringLiteral("remux-read-failed"),
                                 QStringLiteral("Unable to read an input media packet"),
                                 result == AVERROR_EXIT ? AVERROR_EXIT : result);
        }
    } else {
        std::vector<AVPacket *> current(inputs.size(), nullptr);
        std::vector<bool> endOfInput(inputs.size(), false);

        auto fillPacket = [&](size_t inputIndex) -> bool {
            if (endOfInput[inputIndex] || current[inputIndex]) {
                return true;
            }
            if (operationCancelled(&options)) {
                writeResult = cancelledOperation();
                return false;
            }
            for (;;) {
                AVPacket *candidate = av_packet_alloc();
                if (!candidate) {
                    writeResult = failed(QStringLiteral("memory-allocation-failed"),
                                         QStringLiteral("Unable to allocate a media packet"));
                    return false;
                }
                const int readResult = av_read_frame(inputs[inputIndex], candidate);
                if (readResult == AVERROR_EOF) {
                    av_packet_free(&candidate);
                    endOfInput[inputIndex] = true;
                    return true;
                }
                if (readResult < 0) {
                    av_packet_free(&candidate);
                    writeResult = operationCancelled(&options) || readResult == AVERROR_EXIT
                        ? cancelledOperation()
                        : failed(QStringLiteral("remux-read-failed"),
                                 QStringLiteral("Unable to read an input media packet"),
                                 readResult);
                    return false;
                }
                const int streamIndex = candidate->stream_index;
                const StreamMapping &mapping =
                    mappings[inputIndex][static_cast<size_t>(streamIndex)];
                if (mapping.outputStreamIndex < 0) {
                    av_packet_free(&candidate);
                    continue;
                }
                current[inputIndex] = candidate;
                return true;
            }
        };

        fillPacket(0);
        fillPacket(1);
        while (writeResult.ok && !operationCancelled(&options)
               && (current[0] || current[1])) {
            size_t selected = 0;
            if (!current[0]) {
                selected = 1;
            } else if (current[1]) {
                const AVPacket *first = current[0];
                const AVPacket *second = current[1];
                const int firstStream = first->stream_index;
                const int secondStream = second->stream_index;
                const int comparison = av_compare_ts(
                    packetTimestamp(first),
                    inputs[0]->streams[firstStream]->time_base,
                    packetTimestamp(second),
                    inputs[1]->streams[secondStream]->time_base);
                selected = comparison <= 0 ? 0 : 1;
            }

            AVPacket *selectedPacket = current[selected];
            const int streamIndex = selectedPacket->stream_index;
            const StreamMapping &mapping =
                mappings[selected][static_cast<size_t>(streamIndex)];
            reportPacketProgress(static_cast<int>(selected), selectedPacket);
            writeResult = writeRemuxPacket(output,
                                           inputs[selected],
                                           mapping,
                                           selectedPacket,
                                           &options);
            av_packet_free(&current[selected]);
            if (!writeResult.ok) {
                break;
            }
            fillPacket(selected);
        }

        if (operationCancelled(&options)) {
            writeResult = cancelledOperation();
        }

        for (AVPacket *&pending : current) {
            av_packet_free(&pending);
        }
    }

    av_packet_free(&packet);
    closeOutput(&output, writeResult.ok);
    for (AVFormatContext *&input : inputs) {
        closeInput(&input);
    }
    if (writeResult.ok) {
        progress.report(1.0);
    }
    if (!writeResult.ok) {
        QFile::remove(temporaryPath);
        return writeResult;
    }
    return commitOutput(temporaryPath, outputPath, options.overwriteExisting);
}

OperationResult FfmpegService::transcodeAudio(const QString &inputPath,
                                              const QString &outputPath,
                                              const AudioOptions &audioOptions,
                                              const OperationOptions &options) const
{
    return transcodeAudio(InputSource{inputPath, {}, 30000}, outputPath, audioOptions, options);
}

OperationResult FfmpegService::transcodeAudio(const InputSource &inputSource,
                                              const QString &outputPath,
                                              const AudioOptions &audioOptions,
                                              const OperationOptions &options) const
{
    if (operationCancelled(&options)) {
        return cancelledOperation();
    }
    ProgressReporter progress(&options);
    progress.report(0.0);
    if (!hasOutputDirectory(outputPath)) {
        return failed(QStringLiteral("output-directory-missing"),
                      QStringLiteral("The output directory does not exist"));
    }

    AVFormatContext *input = nullptr;
    FfmpegError error;
    if (!openInput(inputSource, &input, &error, &options)) {
        return {false, error};
    }

    int audioStreamIndex = -1;
    for (unsigned int i = 0; i < input->nb_streams; ++i) {
        if (streamType(input->streams[i]) == AVMEDIA_TYPE_AUDIO) {
            audioStreamIndex = static_cast<int>(i);
            break;
        }
    }
    if (audioStreamIndex < 0) {
        closeInput(&input);
        return failed(QStringLiteral("audio-stream-missing"),
                      QStringLiteral("The input does not contain an audio stream"));
    }

    const AVCodecParameters *inputParameters = input->streams[audioStreamIndex]->codecpar;
    const AVCodec *decoderCodec = avcodec_find_decoder(inputParameters->codec_id);
    const AVCodec *encoderCodec = avcodec_find_encoder(AV_CODEC_ID_MP3);
    if (!decoderCodec || !encoderCodec) {
        closeInput(&input);
        return failed(QStringLiteral("codec-not-available"),
                      QStringLiteral("The required audio codec is not available"));
    }

    AVCodecContext *decoder = avcodec_alloc_context3(decoderCodec);
    AVCodecContext *encoder = avcodec_alloc_context3(encoderCodec);
    if (!decoder || !encoder) {
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        return failed(QStringLiteral("memory-allocation-failed"),
                      QStringLiteral("Unable to allocate an audio codec context"));
    }

    int result = avcodec_parameters_to_context(decoder, inputParameters);
    if (result >= 0 && decoder->ch_layout.nb_channels <= 0) {
        av_channel_layout_default(&decoder->ch_layout, 2);
    }
    if (result < 0) {
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        return failed(QStringLiteral("decoder-configuration-failed"),
                      QStringLiteral("Unable to configure the audio decoder"),
                      result);
    }
    result = avcodec_open2(decoder, decoderCodec, nullptr);
    if (result < 0) {
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        return failed(QStringLiteral("decoder-open-failed"),
                      QStringLiteral("Unable to open the audio decoder"),
                      result);
    }

    encoder->bit_rate = std::clamp(audioOptions.bitrateKbps, 32, 320) * 1000;
    encoder->sample_rate = chooseSampleRate(encoderCodec, decoder->sample_rate);
    encoder->sample_fmt = chooseSampleFormat(encoderCodec);
    const int inputChannels = decoder->ch_layout.nb_channels;
    const int outputChannels = inputChannels == 1 || inputChannels == 2
        ? inputChannels
        : 2;
    av_channel_layout_default(&encoder->ch_layout, outputChannels);
    encoder->time_base = AVRational{1, encoder->sample_rate};

    const QString temporaryPath = temporaryOutputPath(outputPath);
    AVFormatContext *output = nullptr;
    if (!openOutput(&output, outputPath, temporaryPath, &error, &options)) {
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        return {false, error};
    }
    if (output->oformat->flags & AVFMT_GLOBALHEADER) {
        encoder->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    result = avcodec_open2(encoder, encoderCodec, nullptr);
    if (result < 0) {
        closeOutput(&output, false);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("encoder-open-failed"),
                      QStringLiteral("Unable to open the MP3 encoder"),
                      result);
    }

    AVStream *outputStream = avformat_new_stream(output, nullptr);
    if (!outputStream) {
        closeOutput(&output, false);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("output-stream-allocation-failed"),
                      QStringLiteral("Unable to create the output audio stream"));
    }
    result = avcodec_parameters_from_context(outputStream->codecpar, encoder);
    if (result < 0) {
        closeOutput(&output, false);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("encoder-configuration-failed"),
                      QStringLiteral("Unable to copy the encoder parameters"),
                      result);
    }
    outputStream->time_base = encoder->time_base;

    result = avformat_write_header(output, nullptr);
    if (result < 0) {
        closeOutput(&output, false);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("transcode-header-failed"),
                      QStringLiteral("Unable to write the MP3 output header"),
                      result);
    }

    SwrContext *resampler = nullptr;
    result = swr_alloc_set_opts2(&resampler,
                                 &encoder->ch_layout,
                                 encoder->sample_fmt,
                                 encoder->sample_rate,
                                 &decoder->ch_layout,
                                 decoder->sample_fmt,
                                 decoder->sample_rate,
                                 0,
                                 nullptr);
    if (result < 0 || !resampler) {
        closeOutput(&output, true);
        swr_free(&resampler);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("resampler-allocation-failed"),
                      QStringLiteral("Unable to allocate the audio resampler"),
                      result);
    }
    result = swr_init(resampler);
    if (result < 0) {
        closeOutput(&output, true);
        swr_free(&resampler);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("resampler-init-failed"),
                      QStringLiteral("Unable to initialize the audio resampler"),
                      result);
    }

    const int encoderChannels = encoder->ch_layout.nb_channels;
    AVAudioFifo *audioFifo = av_audio_fifo_alloc(encoder->sample_fmt,
                                                 encoderChannels,
                                                 1);
    if (!audioFifo) {
        closeOutput(&output, true);
        swr_free(&resampler);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("audio-fifo-allocation-failed"),
                      QStringLiteral("Unable to allocate the audio sample queue"));
    }

    AVFrame *decodedFrame = av_frame_alloc();
    AVPacket *inputPacket = av_packet_alloc();
    AVPacket *outputPacket = av_packet_alloc();
    if (!decodedFrame || !inputPacket || !outputPacket) {
        av_frame_free(&decodedFrame);
        av_packet_free(&inputPacket);
        av_packet_free(&outputPacket);
        av_audio_fifo_free(audioFifo);
        closeOutput(&output, true);
        swr_free(&resampler);
        avcodec_free_context(&decoder);
        avcodec_free_context(&encoder);
        closeInput(&input);
        QFile::remove(temporaryPath);
        return failed(QStringLiteral("memory-allocation-failed"),
                      QStringLiteral("Unable to allocate audio processing buffers"));
    }

    int64_t nextPts = 0;
    OperationResult writeResult = succeeded();

    auto drainEncoder = [&]() -> bool {
        for (;;) {
            if (operationCancelled(&options)) {
                writeResult = cancelledOperation();
                return false;
            }
            const int receiveResult = avcodec_receive_packet(encoder, outputPacket);
            if (receiveResult == AVERROR(EAGAIN) || receiveResult == AVERROR_EOF) {
                return true;
            }
            if (receiveResult < 0) {
                writeResult = failed(QStringLiteral("encoder-output-failed"),
                                     QStringLiteral("Unable to receive an encoded audio packet"),
                                     receiveResult);
                return false;
            }
            av_packet_rescale_ts(outputPacket, encoder->time_base, outputStream->time_base);
            outputPacket->stream_index = outputStream->index;
            outputPacket->pos = -1;
            const int writeResultCode = av_interleaved_write_frame(output, outputPacket);
            av_packet_unref(outputPacket);
            if (writeResultCode < 0) {
                writeResult = operationCancelled(&options) || writeResultCode == AVERROR_EXIT
                    ? cancelledOperation()
                    : failed(QStringLiteral("transcode-write-failed"),
                             QStringLiteral("Unable to write an encoded audio packet"),
                             writeResultCode);
                return false;
            }
        }
    };

    const int encoderFrameSize = encoder->frame_size > 0
        ? encoder->frame_size
        : 1024;

    auto encodeAvailableFrames = [&](bool flush) -> bool {
        while (writeResult.ok) {
            if (operationCancelled(&options)) {
                writeResult = cancelledOperation();
                return false;
            }
            const int availableSamples = av_audio_fifo_size(audioFifo);
            if (availableSamples <= 0
                || (!flush && availableSamples < encoderFrameSize)) {
                return true;
            }

            const int frameSamples = flush
                ? std::min(encoderFrameSize, availableSamples)
                : encoderFrameSize;
            AVFrame *frame = av_frame_alloc();
            if (!frame) {
                writeResult = failed(QStringLiteral("memory-allocation-failed"),
                                     QStringLiteral("Unable to allocate an encoder frame"));
                return false;
            }
            frame->nb_samples = frameSamples;
            frame->format = encoder->sample_fmt;
            frame->sample_rate = encoder->sample_rate;
            if (av_channel_layout_copy(&frame->ch_layout,
                                       &encoder->ch_layout) < 0
                || av_frame_get_buffer(frame, 0) < 0) {
                av_frame_free(&frame);
                writeResult = failed(QStringLiteral("frame-allocation-failed"),
                                     QStringLiteral("Unable to allocate encoder samples"));
                return false;
            }

            const int readSamples = av_audio_fifo_read(
                audioFifo,
                reinterpret_cast<void **>(frame->extended_data),
                frameSamples);
            if (readSamples != frameSamples) {
                av_frame_free(&frame);
                writeResult = failed(QStringLiteral("audio-fifo-read-failed"),
                                     QStringLiteral("Unable to read converted audio samples"));
                return false;
            }
            frame->pts = nextPts;
            nextPts += frameSamples;

            result = avcodec_send_frame(encoder, frame);
            av_frame_free(&frame);
            if (result < 0) {
                writeResult = failed(QStringLiteral("encoder-input-failed"),
                                     QStringLiteral("Unable to send audio samples to the encoder"),
                                     result);
                return false;
            }
            if (!drainEncoder()) {
                return false;
            }
        }
        return writeResult.ok;
    };

    auto encodeConvertedFrame = [&](const uint8_t *const *inputData,
                                    int inputSamples) -> bool {
        if (operationCancelled(&options)) {
            writeResult = cancelledOperation();
            return false;
        }
        const int64_t delay = swr_get_delay(resampler, decoder->sample_rate);
        const int outputSamples = static_cast<int>(av_rescale_rnd(
            delay + inputSamples,
            encoder->sample_rate,
            decoder->sample_rate,
            AV_ROUND_UP));
        if (outputSamples <= 0) {
            return true;
        }

        AVFrame *encodedFrame = av_frame_alloc();
        if (!encodedFrame) {
            writeResult = failed(QStringLiteral("memory-allocation-failed"),
                                 QStringLiteral("Unable to allocate an encoded audio frame"));
            return false;
        }
        encodedFrame->nb_samples = outputSamples;
        encodedFrame->format = encoder->sample_fmt;
        encodedFrame->sample_rate = encoder->sample_rate;
        if (av_channel_layout_copy(&encodedFrame->ch_layout,
                                   &encoder->ch_layout) < 0
            || av_frame_get_buffer(encodedFrame, 0) < 0) {
            av_frame_free(&encodedFrame);
            writeResult = failed(QStringLiteral("frame-allocation-failed"),
                                 QStringLiteral("Unable to allocate converted audio samples"));
            return false;
        }

        const int convertedSamples = swr_convert(resampler,
                                                 encodedFrame->extended_data,
                                                 outputSamples,
                                                 inputData,
                                                 inputSamples);
        if (convertedSamples < 0) {
            av_frame_free(&encodedFrame);
            writeResult = failed(QStringLiteral("audio-conversion-failed"),
                                 QStringLiteral("Unable to resample audio samples"),
                                 convertedSamples);
            return false;
        }
        encodedFrame->nb_samples = convertedSamples;

        if (convertedSamples > 0) {
            const int writtenSamples = av_audio_fifo_write(
                audioFifo,
                reinterpret_cast<void **>(encodedFrame->extended_data),
                convertedSamples);
            if (writtenSamples != convertedSamples) {
                av_frame_free(&encodedFrame);
                writeResult = failed(QStringLiteral("audio-fifo-write-failed"),
                                     QStringLiteral("Unable to queue converted audio samples"));
                return false;
            }
        }

        av_frame_free(&encodedFrame);
        return encodeAvailableFrames(false);
    };

    auto receiveDecoderFrames = [&]() -> bool {
        for (;;) {
            if (operationCancelled(&options)) {
                writeResult = cancelledOperation();
                return false;
            }
            result = avcodec_receive_frame(decoder, decodedFrame);
            if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
                return true;
            }
            if (result < 0) {
                writeResult = failed(QStringLiteral("decoder-output-failed"),
                                     QStringLiteral("Unable to receive decoded audio samples"),
                                     result);
                return false;
            }
            if (!encodeConvertedFrame(decodedFrame->extended_data, decodedFrame->nb_samples)) {
                av_frame_unref(decodedFrame);
                return false;
            }
            av_frame_unref(decodedFrame);
        }
    };

    while (writeResult.ok && !operationCancelled(&options)
           && (result = av_read_frame(input, inputPacket)) >= 0) {
        if (inputPacket->stream_index == audioStreamIndex) {
            const int64_t timestamp = packetTimestamp(inputPacket);
            if (timestamp != AV_NOPTS_VALUE && input->duration > 0) {
                const int64_t timestampUs = av_rescale_q(
                    timestamp,
                    input->streams[audioStreamIndex]->time_base,
                    AVRational{1, AV_TIME_BASE});
                progress.report(static_cast<double>(timestampUs)
                                / static_cast<double>(input->duration));
            }
            result = avcodec_send_packet(decoder, inputPacket);
            av_packet_unref(inputPacket);
            if (result < 0) {
                writeResult = failed(QStringLiteral("decoder-input-failed"),
                                     QStringLiteral("Unable to send an audio packet to the decoder"),
                                     result);
                break;
            }
            if (!receiveDecoderFrames()) {
                break;
            }
        } else {
            av_packet_unref(inputPacket);
        }
    }

    if (operationCancelled(&options)) {
        writeResult = cancelledOperation();
    } else if (writeResult.ok && result < 0 && result != AVERROR_EOF) {
        writeResult = result == AVERROR_EXIT
            ? cancelledOperation()
            : failed(QStringLiteral("transcode-read-failed"),
                     QStringLiteral("Unable to read an input audio packet"),
                     result);
    }

    if (writeResult.ok && !operationCancelled(&options)) {
        result = avcodec_send_packet(decoder, nullptr);
        if (result >= 0) {
            receiveDecoderFrames();
        } else {
            writeResult = failed(QStringLiteral("decoder-flush-failed"),
                                 QStringLiteral("Unable to flush the audio decoder"),
                                 result);
        }
    }

    if (writeResult.ok && !operationCancelled(&options)) {
        for (;;) {
            const int64_t delay = swr_get_delay(resampler, decoder->sample_rate);
            if (delay <= 0) {
                break;
            }
            if (!encodeConvertedFrame(nullptr, 0)) {
                break;
            }
        }
    }

    if (writeResult.ok && !operationCancelled(&options)) {
        encodeAvailableFrames(true);
    }

    if (writeResult.ok && !operationCancelled(&options)) {
        result = avcodec_send_frame(encoder, nullptr);
        if (result >= 0) {
            drainEncoder();
        } else {
            writeResult = failed(QStringLiteral("encoder-flush-failed"),
                                 QStringLiteral("Unable to flush the audio encoder"),
                                 result);
        }
    }

    av_frame_free(&decodedFrame);
    av_packet_free(&inputPacket);
    av_packet_free(&outputPacket);
    av_audio_fifo_free(audioFifo);
    closeOutput(&output, writeResult.ok);
    swr_free(&resampler);
    avcodec_free_context(&decoder);
    avcodec_free_context(&encoder);
    closeInput(&input);

    if (operationCancelled(&options) && writeResult.ok) {
        writeResult = cancelledOperation();
    }
    if (writeResult.ok) {
        progress.report(1.0);
    }
    if (!writeResult.ok) {
        QFile::remove(temporaryPath);
        return writeResult;
    }
    return commitOutput(temporaryPath, outputPath, options.overwriteExisting);
}

} // namespace ReClip::Ffmpeg
