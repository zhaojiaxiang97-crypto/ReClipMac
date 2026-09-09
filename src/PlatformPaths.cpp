#include "PlatformPaths.h"

#include <QDir>
#include <QStandardPaths>

namespace PlatformPaths
{
QString appDataDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

QString cacheDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
}

QString runtimeDirectory()
{
    return QDir(appDataDirectory()).filePath(QStringLiteral("bin"));
}

QString defaultDownloadDirectory()
{
#ifdef Q_OS_ANDROID
    // Android's public Downloads directory is governed by scoped storage and
    // should only be used after the user grants an export location. Keep the
    // initial working output inside the app sandbox instead.
    return QDir(appDataDirectory()).filePath(QStringLiteral("downloads"));
#elif defined(Q_OS_IOS)
    return QDir(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation))
        .filePath(QStringLiteral("ReClip"));
#else
    const QString downloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    return QDir(downloads).filePath(QStringLiteral("ReClip"));
#endif
}
}
