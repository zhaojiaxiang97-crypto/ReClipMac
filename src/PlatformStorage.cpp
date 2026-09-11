#include "PlatformStorage.h"

#include <QDir>
#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QMetaObject>
#include <QStandardPaths>
#include <QUrl>
#include <QUuid>

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QJniObject>
#include <QMetaObject>
#endif

namespace {
bool removeLocalFile(const QString &path)
{
    const QString cleaned = path.trimmed();
    if (cleaned.isEmpty() || !QFileInfo::exists(cleaned)) {
        return true;
    }

    return QFile::moveToTrash(cleaned) || QFile::remove(cleaned);
}

#ifdef Q_OS_ANDROID
PlatformStorage *g_platformStorage = nullptr;

void JNICALL handleExportDirectory(JNIEnv *, jclass, jstring uri, jstring label)
{
    if (!g_platformStorage || !uri) {
        return;
    }

    const QString directoryUri = QJniObject(uri).toString().trimmed();
    const QString directoryLabel = label
        ? QJniObject(label).toString().trimmed()
        : QString();
    if (directoryUri.isEmpty()) {
        return;
    }

    QMetaObject::invokeMethod(
        g_platformStorage,
        [directoryUri, directoryLabel] {
            if (g_platformStorage) {
                emit g_platformStorage->exportDirectorySelected(
                    directoryUri,
                    directoryLabel.isEmpty() ? QStringLiteral("已选择的目录") : directoryLabel);
            }
        },
        Qt::QueuedConnection);
}

void JNICALL handleExportFinished(JNIEnv *,
                                  jclass,
                                  jstring requestId,
                                  jboolean success,
                                  jstring result)
{
    if (!g_platformStorage || !requestId) {
        return;
    }

    const QString id = QJniObject(requestId).toString();
    const QString value = result ? QJniObject(result).toString() : QString();
    QMetaObject::invokeMethod(
        g_platformStorage,
        [id, success, value] {
            if (!g_platformStorage) {
                return;
            }
            if (success) {
                g_platformStorage->finishExport(id, true, value, {});
            } else {
                g_platformStorage->finishExport(id, false, {}, value);
            }
        },
        Qt::QueuedConnection);
}

void JNICALL handleStorageError(JNIEnv *, jclass, jstring message)
{
    if (!g_platformStorage || !message) {
        return;
    }

    const QString errorMessage = QJniObject(message).toString().trimmed();
    QMetaObject::invokeMethod(
        g_platformStorage,
        [errorMessage] {
            if (g_platformStorage) {
                g_platformStorage->reportError(errorMessage);
            }
        },
        Qt::QueuedConnection);
}
#endif
}

PlatformStorage::PlatformStorage(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_ANDROID
    g_platformStorage = this;

    QJniEnvironment environment;
    environment.registerNativeMethods(
        "com/reclip/videodownloader/MainActivity",
        {
            {"nativeHandleExportDirectory", "(Ljava/lang/String;Ljava/lang/String;)V",
             reinterpret_cast<void *>(handleExportDirectory)},
            {"nativeHandleExportFinished", "(Ljava/lang/String;ZLjava/lang/String;)V",
             reinterpret_cast<void *>(handleExportFinished)},
            {"nativeHandleStorageError", "(Ljava/lang/String;)V",
             reinterpret_cast<void *>(handleStorageError)}
        });
#endif
}

PlatformStorage::~PlatformStorage()
{
#ifdef Q_OS_ANDROID
    if (g_platformStorage == this) {
        g_platformStorage = nullptr;
    }
#endif
}

bool PlatformStorage::androidStorage() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

bool PlatformStorage::canChooseExportDirectory() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

bool PlatformStorage::busy() const
{
    return !m_pendingRequests.isEmpty();
}

QString PlatformStorage::lastError() const
{
    return m_lastError;
}

void PlatformStorage::chooseExportDirectory()
{
    clearError();
#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/MainActivity",
        "chooseExportDirectory");
#else
    reportError(QStringLiteral("当前平台不需要 Android 导出目录选择器"));
#endif
}

QString PlatformStorage::exportFile(const QString &sourcePath,
                                    const QString &treeUri,
                                    const QString &displayName,
                                    const QString &mimeType)
{
    const QString requestId = createRequestId();
    const QFileInfo sourceInfo(sourcePath);
    const QString cleanName = displayName.trimmed().isEmpty()
        ? sourceInfo.fileName()
        : QFileInfo(displayName.trimmed()).fileName();

    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        const QString message = QStringLiteral("待导出的文件不存在：%1").arg(sourcePath);
        reportError(message);
        queueExportFinished(requestId, false, {}, message);
        return requestId;
    }
    if (cleanName.isEmpty()) {
        const QString message = QStringLiteral("无法确定导出文件名");
        reportError(message);
        queueExportFinished(requestId, false, {}, message);
        return requestId;
    }

#ifdef Q_OS_ANDROID
    if (!treeUri.startsWith(QStringLiteral("content://"))) {
        const QString message = QStringLiteral("尚未选择有效的 Android 导出目录");
        reportError(message);
        queueExportFinished(requestId, false, {}, message);
        return requestId;
    }

    m_pendingRequests.insert(requestId);
    clearError();
    emit stateChanged();

    const QJniObject requestObject = QJniObject::fromString(requestId);
    const QJniObject sourceObject = QJniObject::fromString(sourceInfo.absoluteFilePath());
    const QJniObject treeObject = QJniObject::fromString(treeUri);
    const QJniObject nameObject = QJniObject::fromString(cleanName);
    const QJniObject mimeObject = QJniObject::fromString(mimeType);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/MainActivity",
        "exportFile",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V",
        requestObject.object<jstring>(),
        sourceObject.object<jstring>(),
        treeObject.object<jstring>(),
        nameObject.object<jstring>(),
        mimeObject.object<jstring>());
    return requestId;
#else
    QDir destinationDirectory(treeUri);
    if (!destinationDirectory.exists() && !destinationDirectory.mkpath(QStringLiteral("."))) {
        const QString message = QStringLiteral("无法创建导出目录：%1").arg(treeUri);
        reportError(message);
        queueExportFinished(requestId, false, {}, message);
        return requestId;
    }

    const QString destinationPath = destinationDirectory.filePath(cleanName);
    if (sourceInfo.absoluteFilePath() != QFileInfo(destinationPath).absoluteFilePath()) {
        QFile::remove(destinationPath);
        if (!QFile::copy(sourceInfo.absoluteFilePath(), destinationPath)) {
            const QString message = QStringLiteral("无法导出文件到：%1").arg(destinationPath);
            reportError(message);
            queueExportFinished(requestId, false, {}, message);
            return requestId;
        }
    }
    queueExportFinished(requestId,
                        true,
                        QUrl::fromLocalFile(destinationPath).toString(),
                        {});
    return requestId;
#endif
}

void PlatformStorage::openFile(const QString &sourcePath,
                               const QString &exportedUri,
                               const QString &mimeType)
{
#ifdef Q_OS_ANDROID
    const QJniObject sourceObject = QJniObject::fromString(sourcePath);
    const QJniObject exportedObject = QJniObject::fromString(exportedUri);
    const QJniObject mimeObject = QJniObject::fromString(mimeType);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/MainActivity",
        "openFile",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V",
        sourceObject.object<jstring>(),
        exportedObject.object<jstring>(),
        mimeObject.object<jstring>());
#else
    const QUrl url = exportedUri.startsWith(QStringLiteral("file:"))
        ? QUrl(exportedUri)
        : QUrl::fromLocalFile(sourcePath);
    if (!QDesktopServices::openUrl(url)) {
        reportError(QStringLiteral("无法打开文件：%1").arg(sourcePath));
    }
    Q_UNUSED(mimeType)
#endif
}

void PlatformStorage::shareFile(const QString &sourcePath,
                                const QString &exportedUri,
                                const QString &mimeType)
{
#ifdef Q_OS_ANDROID
    const QJniObject sourceObject = QJniObject::fromString(sourcePath);
    const QJniObject exportedObject = QJniObject::fromString(exportedUri);
    const QJniObject mimeObject = QJniObject::fromString(mimeType);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/MainActivity",
        "shareFile",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V",
        sourceObject.object<jstring>(),
        exportedObject.object<jstring>(),
        mimeObject.object<jstring>());
#else
    Q_UNUSED(sourcePath)
    Q_UNUSED(exportedUri)
    Q_UNUSED(mimeType)
    reportError(QStringLiteral("桌面端暂未接入系统分享面板"));
#endif
}

bool PlatformStorage::removeFile(const QString &sourcePath, const QString &exportedUri)
{
    bool removed = true;
    const QString localPath = sourcePath.trimmed();
    if (!localPath.isEmpty()) {
        removed = removeLocalFile(localPath + QStringLiteral(".part")) && removed;
        removed = removeLocalFile(localPath + QStringLiteral(".ytdl")) && removed;
        removed = removeLocalFile(localPath) && removed;
    }

    const QString exported = exportedUri.trimmed();
    if (!exported.isEmpty()) {
#ifdef Q_OS_ANDROID
        if (exported.startsWith(QStringLiteral("content://"))) {
            const QJniObject uriObject = QJniObject::fromString(exported);
            const jboolean deleted = QJniObject::callStaticMethod<jboolean>(
                "com/reclip/videodownloader/MainActivity",
                "deleteExportedFile",
                "(Ljava/lang/String;)Z",
                uriObject.object<jstring>());
            removed = static_cast<bool>(deleted) && removed;
        } else
#endif
        {
            const QUrl url(exported);
            const QString exportedPath = url.isLocalFile()
                ? url.toLocalFile()
                : (url.scheme().isEmpty() ? exported : QString());
            if (exportedPath.isEmpty()) {
                removed = false;
            } else {
                removed = removeLocalFile(exportedPath) && removed;
            }
        }
    }

    if (!removed) {
        reportError(QStringLiteral("无法完全删除下载文件，请检查文件权限"));
    }
    return removed;
}

void PlatformStorage::openDirectory(const QString &directoryUri)
{
#ifdef Q_OS_ANDROID
    const QJniObject directoryObject = QJniObject::fromString(directoryUri);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/MainActivity",
        "openDirectory",
        "(Ljava/lang/String;)V",
        directoryObject.object<jstring>());
#else
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(directoryUri))) {
        reportError(QStringLiteral("无法打开目录：%1").arg(directoryUri));
    }
#endif
}

void PlatformStorage::clearError()
{
    if (m_lastError.isEmpty()) {
        return;
    }
    m_lastError.clear();
    emit stateChanged();
}

QString PlatformStorage::createRequestId() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void PlatformStorage::queueExportFinished(const QString &requestId,
                                          bool success,
                                          const QString &exportedUri,
                                          const QString &errorMessage)
{
    QMetaObject::invokeMethod(
        this,
        [this, requestId, success, exportedUri, errorMessage] {
            emit exportFinished(requestId, success, exportedUri, errorMessage);
        },
        Qt::QueuedConnection);
}

void PlatformStorage::reportError(const QString &message)
{
    m_lastError = message.trimmed();
    emit stateChanged();
    if (!m_lastError.isEmpty()) {
        emit operationError(m_lastError);
    }
}

void PlatformStorage::finishExport(const QString &requestId,
                                   bool success,
                                   const QString &result,
                                   const QString &errorMessage)
{
    m_pendingRequests.remove(requestId);
    if (!success) {
        reportError(errorMessage.isEmpty() ? QStringLiteral("文件导出失败") : errorMessage);
    } else {
        clearError();
    }
    emit stateChanged();
    emit exportFinished(requestId, success, result, errorMessage);
}
