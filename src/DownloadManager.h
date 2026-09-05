#pragma once

#include <QProcess>
#include <QString>
#include <QUrl>
#include <QObject>
#include <QtQml/qqmlregistration.h>

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
    Q_PROPERTY(QString ytDlpPath READ ytDlpPath WRITE setYtDlpPath NOTIFY toolPathChanged)
    Q_PROPERTY(QString ffmpegPath READ ffmpegPath WRITE setFfmpegPath NOTIFY toolPathChanged)

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
    QString ytDlpPath() const;
    void setYtDlpPath(const QString &path);
    QString ffmpegPath() const;
    void setFfmpegPath(const QString &path);

    Q_INVOKABLE void startDownload(const QString &sourceUrl, const QString &formatId, const QString &format);
    Q_INVOKABLE void startVideoDownload(const QString &sourceUrl, const QString &formatId);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void retry();
    Q_INVOKABLE void openOutput();
    Q_INVOKABLE void openDownloadDirectory();

signals:
    void stateChanged();
    void progressChanged();
    void outputFormatChanged();
    void downloadDirectoryChanged();
    void toolPathChanged();

private:
    void handleFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleProcessError(QProcess::ProcessError error);
    void consumeOutput(const QByteArray &data, QByteArray &buffer);
    void consumeLine(const QString &line);
    void finishFailed(const QString &message);
    void finishCancelled();
    void resetForStart(const QString &sourceUrl, const QString &formatId);
    void cleanupTemporaryFiles();
    static QString friendlyError(const QString &rawMessage);
    static bool isHttpUrl(const QUrl &url);

    QProcess m_process;
    QByteArray m_stdoutBuffer;
    QByteArray m_stderrBuffer;
    QString m_ytDlpPath;
    QString m_ffmpegPath;
    QString m_downloadDirectory;
    QString m_sourceUrl;
    QString m_formatId;
    QString m_state = QStringLiteral("idle");
    QString m_statusText;
    QString m_speed;
    QString m_eta;
    QString m_outputPath;
    QString m_errorMessage;
    QString m_outputFormat = QStringLiteral("mp4");
    double m_progress = 0.0;
    bool m_cancelRequested = false;
};
