#include "AppSettings.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_downloadDirectory = settings.value(QStringLiteral("downloadDirectory"), defaultDownloadDirectory()).toString();
    m_ytDlpPath = settings.value(QStringLiteral("tools/yt-dlpPath")).toString();
    m_ffmpegPath = settings.value(QStringLiteral("tools/ffmpegPath")).toString();
    m_defaultOutputFormat = settings.value(QStringLiteral("defaultOutputFormat"), QStringLiteral("mp4")).toString();
    m_defaultFormatStrategy = settings.value(QStringLiteral("defaultFormatStrategy"), QStringLiteral("best")).toString();
    m_language = settings.value(QStringLiteral("language"), QStringLiteral("system")).toString();
    m_theme = settings.value(QStringLiteral("theme"), QStringLiteral("light")).toString();
}

QString AppSettings::downloadDirectory() const
{
    return m_downloadDirectory;
}

void AppSettings::setDownloadDirectory(const QString &path)
{
    const QString cleaned = QDir::cleanPath(path.trimmed().isEmpty() ? defaultDownloadDirectory() : path.trimmed());
    if (m_downloadDirectory == cleaned) {
        return;
    }
    m_downloadDirectory = cleaned;
    save(QStringLiteral("downloadDirectory"), m_downloadDirectory);
    emit downloadDirectoryChanged();
}

bool AppSettings::downloadDirectoryValid() const
{
    const QFileInfo info(m_downloadDirectory);
    if (info.exists()) {
        return info.isDir() && info.isWritable();
    }
    return false;
}

QString AppSettings::downloadDirectoryStatus() const
{
    const QFileInfo info(m_downloadDirectory);
    if (!info.exists()) {
        return QStringLiteral("目录尚不存在，开始下载时会尝试创建");
    }
    if (!info.isDir()) {
        return QStringLiteral("配置路径不是目录，请重新选择");
    }
    if (!info.isWritable()) {
        return QStringLiteral("目录不可写，请选择有权限的位置");
    }
    return QStringLiteral("目录可用");
}

QString AppSettings::ytDlpPath() const
{
    return m_ytDlpPath;
}

void AppSettings::setYtDlpPath(const QString &path)
{
    const QString cleaned = path.trimmed();
    if (m_ytDlpPath == cleaned) {
        return;
    }
    m_ytDlpPath = cleaned;
    save(QStringLiteral("tools/yt-dlpPath"), m_ytDlpPath);
    emit ytDlpPathChanged();
}

QString AppSettings::ffmpegPath() const
{
    return m_ffmpegPath;
}

void AppSettings::setFfmpegPath(const QString &path)
{
    const QString cleaned = path.trimmed();
    if (m_ffmpegPath == cleaned) {
        return;
    }
    m_ffmpegPath = cleaned;
    save(QStringLiteral("tools/ffmpegPath"), m_ffmpegPath);
    emit ffmpegPathChanged();
}

QString AppSettings::defaultOutputFormat() const
{
    return m_defaultOutputFormat;
}

void AppSettings::setDefaultOutputFormat(const QString &format)
{
    const QString next = format.trimmed().toLower() == QStringLiteral("mp3")
        ? QStringLiteral("mp3") : QStringLiteral("mp4");
    if (m_defaultOutputFormat == next) {
        return;
    }
    m_defaultOutputFormat = next;
    save(QStringLiteral("defaultOutputFormat"), m_defaultOutputFormat);
    emit defaultOutputFormatChanged();
}

QString AppSettings::defaultFormatStrategy() const
{
    return m_defaultFormatStrategy;
}

void AppSettings::setDefaultFormatStrategy(const QString &strategy)
{
    const QString next = strategy.trimmed().toLower() == QStringLiteral("compatible")
        ? QStringLiteral("compatible") : QStringLiteral("best");
    if (m_defaultFormatStrategy == next) {
        return;
    }
    m_defaultFormatStrategy = next;
    save(QStringLiteral("defaultFormatStrategy"), m_defaultFormatStrategy);
    emit defaultFormatStrategyChanged();
}

QString AppSettings::language() const
{
    return m_language;
}

void AppSettings::setLanguage(const QString &language)
{
    const QString normalized = language.trimmed().toLower();
    const QString next = normalized == QStringLiteral("en") || normalized == QStringLiteral("zh-cn")
        ? normalized : QStringLiteral("system");
    if (m_language == next) {
        return;
    }
    m_language = next;
    save(QStringLiteral("language"), m_language);
    emit languageChanged();
}

QString AppSettings::theme() const
{
    return m_theme;
}

void AppSettings::setTheme(const QString &theme)
{
    const QString normalized = theme.trimmed().toLower();
    const QString next = normalized == QStringLiteral("dark") || normalized == QStringLiteral("system")
        ? normalized : QStringLiteral("light");
    if (m_theme == next) {
        return;
    }
    m_theme = next;
    save(QStringLiteral("theme"), m_theme);
    emit themeChanged();
}

void AppSettings::reset()
{
    QSettings settings;
    settings.remove(QStringLiteral("downloadDirectory"));
    settings.remove(QStringLiteral("tools"));
    settings.remove(QStringLiteral("defaultOutputFormat"));
    settings.remove(QStringLiteral("defaultFormatStrategy"));
    settings.remove(QStringLiteral("language"));
    settings.remove(QStringLiteral("theme"));
    settings.sync();

    m_downloadDirectory = defaultDownloadDirectory();
    m_ytDlpPath.clear();
    m_ffmpegPath.clear();
    m_defaultOutputFormat = QStringLiteral("mp4");
    m_defaultFormatStrategy = QStringLiteral("best");
    m_language = QStringLiteral("system");
    m_theme = QStringLiteral("light");
    emit downloadDirectoryChanged();
    emit ytDlpPathChanged();
    emit ffmpegPathChanged();
    emit defaultOutputFormatChanged();
    emit defaultFormatStrategyChanged();
    emit languageChanged();
    emit themeChanged();
}

QString AppSettings::defaultDownloadDirectory()
{
    const QString downloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    return QDir(downloads).filePath(QStringLiteral("ReClip"));
}

void AppSettings::save(const QString &key, const QString &value)
{
    QSettings settings;
    settings.setValue(key, value);
    settings.sync();
}
