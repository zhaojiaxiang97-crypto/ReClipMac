#pragma once

#include <QByteArray>
#include <QObject>
#include <QString>

class AndroidDownloadEngine : public QObject
{
    Q_OBJECT

public:
    explicit AndroidDownloadEngine(QObject *parent = nullptr);

    bool available() const;
    bool ffmpegKitAvailable() const;
    QString inspect(const QString &url);
    QString download(const QString &url,
                     const QString &formatId,
                     const QString &format,
                     const QString &outputDirectory,
                     const QString &taskId = {});
    void cancel(const QString &requestId);
    QString takePendingRetryTaskId();

signals:
    void inspectionFinished(const QString &requestId,
                             bool success,
                             const QByteArray &payload,
                             const QString &errorMessage);
    void downloadProgress(const QString &requestId,
                          double progress,
                          const QString &eta,
                          const QString &speed,
                          const QString &line);
    void downloadFinished(const QString &requestId,
                          bool success,
                          const QString &outputPath,
                          const QString &errorMessage);

private:
    static void ensureBridgeRegistered();
};
