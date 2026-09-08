#pragma once

#include <QProcess>
#include <QVariantList>
#include <QUrl>
#include <QVector>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include "AndroidDownloadEngine.h"
#include "PlatformStorage.h"

class DownloadQueue : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList tasks READ tasks NOTIFY tasksChanged)
    Q_PROPERTY(bool running READ running NOTIFY queueChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY queueChanged)
    Q_PROPERTY(QString downloadDirectory READ downloadDirectory WRITE setDownloadDirectory NOTIFY downloadDirectoryChanged)
    Q_PROPERTY(QString exportDirectoryUri READ exportDirectoryUri WRITE setExportDirectoryUri NOTIFY exportDirectoryChanged)
    Q_PROPERTY(QString ytDlpPath READ ytDlpPath WRITE setYtDlpPath NOTIFY toolPathChanged)
    Q_PROPERTY(QString ffmpegPath READ ffmpegPath WRITE setFfmpegPath NOTIFY toolPathChanged)
    Q_PROPERTY(PlatformStorage *platformStorage READ platformStorage WRITE setPlatformStorage NOTIFY platformStorageChanged)

public:
    explicit DownloadQueue(QObject *parent = nullptr);

    QVariantList tasks() const;
    bool running() const;
    QString statusText() const;
    QString downloadDirectory() const;
    void setDownloadDirectory(const QString &path);
    QString exportDirectoryUri() const;
    void setExportDirectoryUri(const QString &uri);
    PlatformStorage *platformStorage() const;
    void setPlatformStorage(PlatformStorage *storage);
    QString ytDlpPath() const;
    void setYtDlpPath(const QString &path);
    QString ffmpegPath() const;
    void setFfmpegPath(const QString &path);

    Q_INVOKABLE void addUrls(const QString &rawInput, const QString &format);
    Q_INVOKABLE void addTask(const QString &sourceUrl, const QString &formatId, const QString &format);
    Q_INVOKABLE void startAll();
    Q_INVOKABLE void cancelTask(const QString &taskId);
    Q_INVOKABLE void retryTask(const QString &taskId);
    Q_INVOKABLE void removeTask(const QString &taskId);
    Q_INVOKABLE void clearCompleted();
    Q_INVOKABLE void openTask(const QString &taskId);
    Q_INVOKABLE void shareTask(const QString &taskId);
    Q_INVOKABLE QString consumeAndroidNotificationRetry();

signals:
    void tasksChanged();
    void queueChanged();
    void downloadDirectoryChanged();
    void exportDirectoryChanged();
    void toolPathChanged();
    void platformStorageChanged();

private:
    struct Task {
        QString id;
        QString sourceUrl;
        QString title;
        QString formatId;
        QString format = QStringLiteral("mp4");
        QString state = QStringLiteral("queued");
        QString statusText = QStringLiteral("等待下载");
        QString speed;
        QString eta;
        QString outputPath;
        QString exportedUri;
        QString errorMessage;
        double progress = 0.0;
        bool cancelRequested = false;
        bool removeAfterFinish = false;
    };

    int indexForId(const QString &taskId) const;
    void startNext();
    void startTask(int index);
    void handleFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleProcessError(QProcess::ProcessError error);
    void handleAndroidDownloadProgress(const QString &requestId,
                                       double progress,
                                       const QString &eta,
                                       const QString &speed,
                                       const QString &line);
    void handleAndroidDownloadFinished(const QString &requestId,
                                       bool success,
                                       const QString &outputPath,
                                       const QString &errorMessage);
    void consumeOutput(const QByteArray &data, QByteArray &buffer);
    void consumeLine(const QString &line);
    void finishActive(const QString &state, const QString &status, const QString &error = {});
    void handleExportFinished(const QString &requestId,
                              bool success,
                              const QString &exportedUri,
                              const QString &errorMessage);
    void cleanupTemporaryFiles(const Task &task);
    void moveTaskFilesToTrash(const Task &task);
    void loadPersistedTasks();
    void persistTasks() const;
    void notifyQueueChanged();
    static QString normalizeFormat(const QString &format);
    static QString friendlyError(const QString &rawMessage);
    static bool isHttpUrl(const QUrl &url);

    QProcess m_process;
    AndroidDownloadEngine m_androidEngine;
    QByteArray m_stdoutBuffer;
    QByteArray m_stderrBuffer;
    QString m_lastErrorText;
    QVector<Task> m_tasks;
    int m_activeIndex = -1;
    bool m_queueRequested = false;
    QString m_statusText = QStringLiteral("队列为空");
    QString m_downloadDirectory;
    QString m_exportDirectoryUri;
    QString m_ytDlpPath;
    QString m_ffmpegPath;
    QString m_androidRequestId;
    QString m_pendingExportRequest;
    PlatformStorage *m_platformStorage = nullptr;
};
