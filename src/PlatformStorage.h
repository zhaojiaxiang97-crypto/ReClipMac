#pragma once

#include <QSet>
#include <QString>
#include <QObject>
#include <QtQml/qqmlregistration.h>

class PlatformStorage : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool androidStorage READ androidStorage CONSTANT)
    Q_PROPERTY(bool canChooseExportDirectory READ canChooseExportDirectory CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY stateChanged)

public:
    explicit PlatformStorage(QObject *parent = nullptr);
    ~PlatformStorage() override;

    bool androidStorage() const;
    bool canChooseExportDirectory() const;
    bool busy() const;
    QString lastError() const;

    Q_INVOKABLE void chooseExportDirectory();
    Q_INVOKABLE QString exportFile(const QString &sourcePath,
                                   const QString &treeUri,
                                   const QString &displayName,
                                   const QString &mimeType);
    Q_INVOKABLE void openFile(const QString &sourcePath,
                              const QString &exportedUri,
                              const QString &mimeType);
    Q_INVOKABLE void shareFile(const QString &sourcePath,
                               const QString &exportedUri,
                               const QString &mimeType);
    Q_INVOKABLE bool removeFile(const QString &sourcePath,
                                const QString &exportedUri);
    Q_INVOKABLE void openDirectory(const QString &directoryUri);
    Q_INVOKABLE void clearError();

    // Called by the Android JNI callbacks on the Qt event loop.
    void reportError(const QString &message);
    void finishExport(const QString &requestId,
                      bool success,
                      const QString &result,
                      const QString &errorMessage);

signals:
    void exportDirectorySelected(const QString &uri, const QString &label);
    void exportFinished(const QString &requestId,
                        bool success,
                        const QString &exportedUri,
                        const QString &errorMessage);
    void operationError(const QString &message);
    void stateChanged();

private:
    QString createRequestId() const;
    void queueExportFinished(const QString &requestId,
                             bool success,
                             const QString &exportedUri,
                             const QString &errorMessage);

    QSet<QString> m_pendingRequests;
    QString m_lastError;
};
