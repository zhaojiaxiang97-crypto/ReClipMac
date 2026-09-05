#pragma once

#include <QProcess>
#include <QString>
#include <QStringList>
#include <QObject>
#include <QtQml/qqmlregistration.h>

class ToolLocator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool ready READ ready NOTIFY statusChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY statusChanged)
    Q_PROPERTY(bool ytDlpAvailable READ ytDlpAvailable NOTIFY statusChanged)
    Q_PROPERTY(QString ytDlpPath READ ytDlpPath NOTIFY statusChanged)
    Q_PROPERTY(QString ytDlpCustomPath READ ytDlpCustomPath NOTIFY statusChanged)
    Q_PROPERTY(QString ytDlpVersion READ ytDlpVersion NOTIFY statusChanged)
    Q_PROPERTY(QString ytDlpStatus READ ytDlpStatus NOTIFY statusChanged)
    Q_PROPERTY(bool ffmpegAvailable READ ffmpegAvailable NOTIFY statusChanged)
    Q_PROPERTY(QString ffmpegPath READ ffmpegPath NOTIFY statusChanged)
    Q_PROPERTY(QString ffmpegCustomPath READ ffmpegCustomPath NOTIFY statusChanged)
    Q_PROPERTY(QString ffmpegVersion READ ffmpegVersion NOTIFY statusChanged)
    Q_PROPERTY(QString ffmpegStatus READ ffmpegStatus NOTIFY statusChanged)

public:
    explicit ToolLocator(QObject *parent = nullptr);

    bool ready() const;
    bool checking() const;

    bool ytDlpAvailable() const;
    QString ytDlpPath() const;
    QString ytDlpCustomPath() const;
    QString ytDlpVersion() const;
    QString ytDlpStatus() const;

    bool ffmpegAvailable() const;
    QString ffmpegPath() const;
    QString ffmpegCustomPath() const;
    QString ffmpegVersion() const;
    QString ffmpegStatus() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setCustomPath(const QString &toolName, const QString &path);
    Q_INVOKABLE void clearCustomPath(const QString &toolName);

signals:
    void statusChanged();

private:
    struct ToolState {
        QString path;
        QString customPath;
        QString version;
        QString message;
        bool available = false;
    };

    static QString normalizeToolName(const QString &toolName);
    static bool isKnownTool(const QString &toolName);

    ToolState &stateFor(const QString &toolName);
    const ToolState &stateFor(const QString &toolName) const;
    QString configuredPath(const QString &toolName) const;
    void prepareState(const QString &toolName);
    void detectNext();
    void finishCurrent(bool available, const QString &version, const QString &message);

    QProcess m_process;
    QStringList m_pendingTools;
    QString m_currentTool;
    bool m_checking = false;
    ToolState m_ytDlp;
    ToolState m_ffmpeg;
};
