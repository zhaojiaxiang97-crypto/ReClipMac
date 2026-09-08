#pragma once

#include <QProcess>
#include <QUrl>
#include <QVariantList>
#include <QStringList>
#include <QTimer>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include "AndroidDownloadEngine.h"

class MediaInspector : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool inspecting READ inspecting NOTIFY stateChanged)
    Q_PROPERTY(bool hasResult READ hasResult NOTIFY resultChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QString sourceUrl READ sourceUrl NOTIFY resultChanged)
    Q_PROPERTY(QString title READ title NOTIFY resultChanged)
    Q_PROPERTY(QString uploader READ uploader NOTIFY resultChanged)
    Q_PROPERTY(QString durationText READ durationText NOTIFY resultChanged)
    Q_PROPERTY(QUrl thumbnailUrl READ thumbnailUrl NOTIFY resultChanged)
    Q_PROPERTY(QVariantList formats READ formats NOTIFY resultChanged)
    Q_PROPERTY(QStringList formatLabels READ formatLabels NOTIFY resultChanged)
    Q_PROPERTY(QString selectedFormatId READ selectedFormatId WRITE setSelectedFormatId NOTIFY selectedFormatChanged)
    Q_PROPERTY(QString ytDlpPath READ ytDlpPath WRITE setYtDlpPath NOTIFY ytDlpPathChanged)

public:
    explicit MediaInspector(QObject *parent = nullptr);

    bool inspecting() const;
    bool hasResult() const;
    QString state() const;
    QString errorCode() const;
    QString errorMessage() const;
    QString sourceUrl() const;
    QString title() const;
    QString uploader() const;
    QString durationText() const;
    QUrl thumbnailUrl() const;
    QVariantList formats() const;
    QStringList formatLabels() const;
    QString selectedFormatId() const;
    void setSelectedFormatId(const QString &formatId);
    QString ytDlpPath() const;
    void setYtDlpPath(const QString &path);

    Q_INVOKABLE void inspect(const QString &url);
    Q_INVOKABLE void clear();

signals:
    void stateChanged();
    void resultChanged();
    void selectedFormatChanged();
    void ytDlpPathChanged();

private:
    struct FormatCandidate {
        QString id;
        int height = 0;
        double bitrate = 0.0;
    };

    void handleFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleProcessError(QProcess::ProcessError error);
    void handleAndroidInspectionFinished(const QString &requestId,
                                         bool success,
                                         const QByteArray &payload,
                                         const QString &errorMessage);
    void finishWithError(const QString &code, const QString &message);
    void resetResult();
    void parseMetadata(const QByteArray &output);
    QStringList classifyError(const QString &rawMessage) const;
    static QString formatDuration(double seconds);

    QProcess m_process;
    AndroidDownloadEngine m_androidEngine;
    QTimer m_timeout;
    QByteArray m_standardOutput;
    QByteArray m_standardError;
    QString m_ytDlpPath;
    QString m_state = QStringLiteral("idle");
    QString m_errorCode;
    QString m_errorMessage;
    QString m_sourceUrl;
    QString m_title;
    QString m_uploader;
    QString m_duration;
    QUrl m_thumbnailUrl;
    QVariantList m_formats;
    QStringList m_formatLabels;
    QString m_selectedFormatId;
    QString m_androidRequestId;
    bool m_inspecting = false;
    bool m_hasResult = false;
};
