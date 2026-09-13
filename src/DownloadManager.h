#pragma once

#ifndef Q_OS_IOS
#include <QProcess>
#endif
#include <QString>
#include <QUrl>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include "AndroidDownloadEngine.h"
#include "PlatformStorage.h"

#if defined(RECLIP_HAS_FFMPEG_SDK)
#include <QByteArray>
#include <QFile>
#include <QFutureWatcher>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPair>
#include <QPointer>

#include <atomic>
#include <memory>

#include "ffmpeg/FfmpegTypes.h"
#include "ytdlp/YtDlpService.h"
#endif

class QTimer;

class DownloadManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString speed READ speed NOTIFY progressChanged)
    Q_PROPERTY(QString eta READ eta NOTIFY progressChanged)
    Q_PROPERTY(QString outputPath READ outputPath NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(bool canRetry READ canRetry NOTIFY stateChanged)
    Q_PROPERTY(QString outputFormat READ outputFormat WRITE setOutputFormat NOTIFY outputFormatChanged)
    Q_PROPERTY(QString downloadDirectory READ downloadDirectory WRITE setDownloadDirectory NOTIFY downloadDirectoryChanged)
    Q_PROPERTY(QString exportDirectoryUri READ exportDirectoryUri WRITE setExportDirectoryUri NOTIFY exportDirectoryChanged)
    Q_PROPERTY(QString exportedUri READ exportedUri NOTIFY stateChanged)
    Q_PROPERTY(QString ytDlpPath READ ytDlpPath WRITE setYtDlpPath NOTIFY toolPathChanged)
    Q_PROPERTY(QString ffmpegPath READ ffmpegPath WRITE setFfmpegPath NOTIFY toolPathChanged)
    Q_PROPERTY(PlatformStorage *platformStorage READ platformStorage WRITE setPlatformStorage NOTIFY platformStorageChanged)

public:
    explicit DownloadManager(QObject *parent = nullptr);

    bool busy() const;
    QString state() const;
    QString statusText() const;
    double progress() const;
    QString speed() const;
    QString eta() const;
    QString outputPath() const;
    QString errorMessage() const;
    bool canRetry() const;
    QString outputFormat() const;
    void setOutputFormat(const QString &format);
    QString downloadDirectory() const;
    void setDownloadDirectory(const QString &path);
    QString exportDirectoryUri() const;
    void setExportDirectoryUri(const QString &uri);
    QString exportedUri() const;
    PlatformStorage *platformStorage() const;
    void setPlatformStorage(PlatformStorage *storage);
    QString ytDlpPath() const;
    void setYtDlpPath(const QString &path);
    QString ffmpegPath() const;
    void setFfmpegPath(const QString &path);

    Q_INVOKABLE void startDownload(const QString &sourceUrl, const QString &formatId, const QString &format);
    Q_INVOKABLE void startVideoDownload(const QString &sourceUrl, const QString &formatId);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void retry();
    Q_INVOKABLE void openOutput();
    Q_INVOKABLE void shareOutput();
    Q_INVOKABLE void openDownloadDirectory();

signals:
    void stateChanged();
    void progressChanged();
    void outputFormatChanged();
    void downloadDirectoryChanged();
    void exportDirectoryChanged();
    void toolPathChanged();
    void platformStorageChanged();

private:
#ifndef Q_OS_IOS
    void handleFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleProcessError(QProcess::ProcessError error);
#endif
    void handleAndroidDownloadProgress(const QString &requestId,
                                       double progress,
                                       const QString &eta,
                                       const QString &speed,
                                       const QString &line);
    void handleAndroidDownloadFinished(const QString &requestId,
                                       bool success,
                                       const QByteArray &payload,
                                       const QString &errorCode,
                                       const QString &errorMessage);
    void consumeOutput(const QByteArray &data, QByteArray &buffer);
    void consumeLine(const QString &line);
    void finishFailed(const QString &message);
    void finishCancelled();
    void finishCompleted();
    void handleExportFinished(const QString &requestId,
                              bool success,
                              const QString &exportedUri,
                              const QString &errorMessage);
#if defined(RECLIP_HAS_FFMPEG_SDK)
    void startSdkAudioTranscode();
    void handleSdkAudioTranscodeFinished();
    void startSdkVideoResolve();
    void handleSdkVideoResolveFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void startSdkYtDlpDownload();
    void handleSdkYtDlpDownloadFinished(bool ok,
                                        const QByteArray &payload,
                                        const QString &errorCode,
                                        const QString &errorMessage);
    void startSdkVideoDownload(int streamKind);
    void handleSdkVideoDownloadProgress(int streamKind,
                                        qint64 bytesReceived,
                                        qint64 bytesTotal);
    void handleSdkVideoStreamFinished(int streamKind);
    void startSdkVideoProcessing();
    void startSdkSegmentedProcessing();
    void abortSdkVideoDownloads();
    void fallbackSdkVideoToProcess(const QString &reason);
#endif
    void resetForStart(const QString &sourceUrl, const QString &formatId);
    void cleanupTemporaryFiles();
    static QString friendlyError(const QString &rawMessage);
    static bool isHttpUrl(const QUrl &url);

#ifndef Q_OS_IOS
    QProcess m_process;
#endif
    AndroidDownloadEngine m_androidEngine;
#if defined(RECLIP_HAS_FFMPEG_SDK)
    enum class SdkStreamKind {
        Combined = 0,
        Video = 1,
        Audio = 2,
    };

    QFutureWatcher<ReClip::Ffmpeg::OperationResult> m_ffmpegWatcher;
    ReClip::YtDlp::YtDlpService m_sdkResolver;
    QString m_sdkResolveRequestId;
    QNetworkAccessManager m_sdkNetwork;
    QPointer<QNetworkReply> m_sdkCombinedReply;
    QPointer<QNetworkReply> m_sdkVideoReply;
    QPointer<QNetworkReply> m_sdkAudioReply;
    QFile m_sdkCombinedFile;
    QFile m_sdkVideoFile;
    QFile m_sdkAudioFile;
    QUrl m_sdkCombinedUrl;
    QUrl m_sdkVideoUrl;
    QUrl m_sdkAudioUrl;
    QList<QPair<QByteArray, QByteArray>> m_sdkCombinedHeaders;
    QList<QPair<QByteArray, QByteArray>> m_sdkVideoHeaders;
    QList<QPair<QByteArray, QByteArray>> m_sdkAudioHeaders;
    QString m_sdkCombinedPath;
    QString m_sdkVideoPath;
    QString m_sdkAudioPath;
    qint64 m_sdkCombinedExpectedBytes = -1;
    qint64 m_sdkVideoExpectedBytes = -1;
    qint64 m_sdkAudioExpectedBytes = -1;
    qint64 m_sdkCombinedReceivedBytes = 0;
    qint64 m_sdkVideoReceivedBytes = 0;
    qint64 m_sdkAudioReceivedBytes = 0;
    bool m_sdkResolving = false;
    bool m_sdkYtDlpDownloadActive = false;
    bool m_sdkDownloadActive = false;
    bool m_sdkFallbackPending = false;
    bool m_sdkStarting = false;
    QByteArray m_sdkResolveOutput;
    QByteArray m_sdkResolveError;
    bool m_sdkVideoProcessing = false;
    bool m_sdkSegmentedProcessing = false;
    bool m_sdkSeparateStreams = false;
    bool m_forceProcessBackend = false;
    QPointer<QTimer> m_sdkYtDlpProgressTimer;
    QString m_sdkYtDlpDownloadRequestId;
    QString m_sdkYtDlpDownloadPath;
    QString m_sdkInputPath;
    std::shared_ptr<std::atomic_bool> m_sdkCancelToken;
#endif
    QByteArray m_stdoutBuffer;
    QByteArray m_stderrBuffer;
    QString m_ytDlpPath;
    QString m_ffmpegPath;
    QString m_downloadDirectory;
    QString m_exportDirectoryUri;
    QString m_exportedUri;
    QString m_pendingExportRequest;
    QString m_sourceUrl;
    QString m_formatId;
    QString m_state = QStringLiteral("idle");
    QString m_statusText;
    QString m_speed;
    QString m_eta;
    QString m_outputPath;
    QString m_errorMessage;
    QString m_outputFormat = QStringLiteral("mp4");
    QString m_androidRequestId;
    double m_progress = 0.0;
    bool m_cancelRequested = false;
    bool m_exportBusy = false;
    PlatformStorage *m_platformStorage = nullptr;
};
