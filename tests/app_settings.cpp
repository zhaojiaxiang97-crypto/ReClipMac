#include "AppSettings.h"

#include <QCoreApplication>
#include <QSettings>
#include <QTemporaryDir>
#include <QDir>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("ReClipSettingsTest"));
    QCoreApplication::setOrganizationName(QStringLiteral("ReClipTests"));

    QSettings cleanup;
    cleanup.clear();
    cleanup.sync();

    QTemporaryDir temporaryDirectory;
    const QString configuredDirectory = QDir(temporaryDirectory.path()).filePath(QStringLiteral("downloads"));

    AppSettings settings;
    settings.setDownloadDirectory(configuredDirectory);
    settings.setYtDlpPath(QStringLiteral("C:/tools/yt-dlp.exe"));
    settings.setFfmpegPath(QStringLiteral("C:/tools/ffmpeg.exe"));
    settings.setDefaultOutputFormat(QStringLiteral("mp3"));
    settings.setDefaultFormatStrategy(QStringLiteral("compatible"));
    settings.setLanguage(QStringLiteral("en"));
    settings.setTheme(QStringLiteral("dark"));

    if (settings.downloadDirectory() != QDir::cleanPath(configuredDirectory)
        || settings.downloadDirectoryValid()
        || settings.defaultOutputFormat() != QStringLiteral("mp3")
        || settings.defaultFormatStrategy() != QStringLiteral("compatible")
        || settings.language() != QStringLiteral("en")
        || settings.theme() != QStringLiteral("dark")) {
        cleanup.clear();
        return 1;
    }

    AppSettings restored;
    if (restored.downloadDirectory() != QDir::cleanPath(configuredDirectory)
        || restored.ytDlpPath().isEmpty() || restored.ffmpegPath().isEmpty()
        || restored.defaultOutputFormat() != QStringLiteral("mp3")
        || restored.language() != QStringLiteral("en")
        || restored.theme() != QStringLiteral("dark")) {
        cleanup.clear();
        return 2;
    }

    restored.reset();
    const bool resetOk = restored.defaultOutputFormat() == QStringLiteral("mp4")
        && restored.defaultFormatStrategy() == QStringLiteral("best")
        && restored.language() == QStringLiteral("system")
        && restored.theme() == QStringLiteral("light")
        && restored.ytDlpPath().isEmpty() && restored.ffmpegPath().isEmpty();
    cleanup.clear();
    return resetOk ? 0 : 3;
}
