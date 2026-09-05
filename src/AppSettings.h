#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString downloadDirectory READ downloadDirectory WRITE setDownloadDirectory NOTIFY downloadDirectoryChanged)
    Q_PROPERTY(bool downloadDirectoryValid READ downloadDirectoryValid NOTIFY downloadDirectoryChanged)
    Q_PROPERTY(QString downloadDirectoryStatus READ downloadDirectoryStatus NOTIFY downloadDirectoryChanged)
    Q_PROPERTY(QString ytDlpPath READ ytDlpPath WRITE setYtDlpPath NOTIFY ytDlpPathChanged)
    Q_PROPERTY(QString ffmpegPath READ ffmpegPath WRITE setFfmpegPath NOTIFY ffmpegPathChanged)
    Q_PROPERTY(QString defaultOutputFormat READ defaultOutputFormat WRITE setDefaultOutputFormat NOTIFY defaultOutputFormatChanged)
    Q_PROPERTY(QString defaultFormatStrategy READ defaultFormatStrategy WRITE setDefaultFormatStrategy NOTIFY defaultFormatStrategyChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString downloadDirectory() const;
    void setDownloadDirectory(const QString &path);
    bool downloadDirectoryValid() const;
    QString downloadDirectoryStatus() const;
    QString ytDlpPath() const;
    void setYtDlpPath(const QString &path);
    QString ffmpegPath() const;
    void setFfmpegPath(const QString &path);
    QString defaultOutputFormat() const;
    void setDefaultOutputFormat(const QString &format);
    QString defaultFormatStrategy() const;
    void setDefaultFormatStrategy(const QString &strategy);
    QString language() const;
    void setLanguage(const QString &language);
    QString theme() const;
    void setTheme(const QString &theme);

    Q_INVOKABLE void reset();

signals:
    void downloadDirectoryChanged();
    void ytDlpPathChanged();
    void ffmpegPathChanged();
    void defaultOutputFormatChanged();
    void defaultFormatStrategyChanged();
    void languageChanged();
    void themeChanged();

private:
    static QString defaultDownloadDirectory();
    void save(const QString &key, const QString &value);

    QString m_downloadDirectory;
    QString m_ytDlpPath;
    QString m_ffmpegPath;
    QString m_defaultOutputFormat = QStringLiteral("mp4");
    QString m_defaultFormatStrategy = QStringLiteral("best");
    QString m_language = QStringLiteral("system");
    QString m_theme = QStringLiteral("light");
};
