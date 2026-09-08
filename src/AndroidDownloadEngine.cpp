#include "AndroidDownloadEngine.h"

#ifdef Q_OS_ANDROID
#include <QHash>
#include <QJniEnvironment>
#include <QJniObject>
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QUuid>
#include <jni.h>
#endif

namespace {
#ifdef Q_OS_ANDROID
constexpr const char *kBridgeClass = "com/reclip/videodownloader/AndroidYtDlpBridge";

QMutex g_requestMutex;
QHash<QString, QPointer<AndroidDownloadEngine>> g_requests;
bool g_bridgeRegistered = false;

QString fromJniString(jstring value)
{
    return value ? QJniObject(value).toString() : QString();
}

QPointer<AndroidDownloadEngine> requestOwner(const QString &requestId)
{
    QMutexLocker locker(&g_requestMutex);
    return g_requests.value(requestId);
}

void forgetRequest(const QString &requestId)
{
    QMutexLocker locker(&g_requestMutex);
    g_requests.remove(requestId);
}

void rememberRequest(const QString &requestId, AndroidDownloadEngine *engine)
{
    QMutexLocker locker(&g_requestMutex);
    g_requests.insert(requestId, engine);
}

void JNICALL handleInspectionFinished(JNIEnv *,
                                      jclass,
                                      jstring requestId,
                                      jboolean success,
                                      jstring payload,
                                      jstring errorMessage)
{
    const QString id = fromJniString(requestId);
    const QPointer<AndroidDownloadEngine> engine = requestOwner(id);
    if (!engine) {
        return;
    }

    const QByteArray json = fromJniString(payload).toUtf8();
    const QString error = fromJniString(errorMessage);
    QMetaObject::invokeMethod(
        engine,
        [engine, id, success, json, error] {
            if (engine) {
                emit engine->inspectionFinished(id, success, json, error);
            }
            forgetRequest(id);
        },
        Qt::QueuedConnection);
}

void JNICALL handleDownloadProgress(JNIEnv *,
                                    jclass,
                                    jstring requestId,
                                    jfloat progress,
                                    jlong eta,
                                    jstring speed,
                                    jstring line)
{
    const QString id = fromJniString(requestId);
    const QPointer<AndroidDownloadEngine> engine = requestOwner(id);
    if (!engine) {
        return;
    }

    const QString etaText = eta > 0 ? QString::number(eta) : QString();
    const QString speedText = fromJniString(speed);
    const QString lineText = fromJniString(line);
    QMetaObject::invokeMethod(
        engine,
        [engine, id, progress, etaText, speedText, lineText] {
            if (engine) {
                emit engine->downloadProgress(
                    id, qBound(0.0, static_cast<double>(progress) / 100.0, 1.0),
                    etaText, speedText, lineText);
            }
        },
        Qt::QueuedConnection);
}

void JNICALL handleDownloadFinished(JNIEnv *,
                                    jclass,
                                    jstring requestId,
                                    jboolean success,
                                    jstring outputPath,
                                    jstring errorMessage)
{
    const QString id = fromJniString(requestId);
    const QPointer<AndroidDownloadEngine> engine = requestOwner(id);
    if (!engine) {
        return;
    }

    const QString output = fromJniString(outputPath);
    const QString error = fromJniString(errorMessage);
    QMetaObject::invokeMethod(
        engine,
        [engine, id, success, output, error] {
            if (engine) {
                emit engine->downloadFinished(id, success, output, error);
            }
            forgetRequest(id);
        },
        Qt::QueuedConnection);
}
#endif
}

AndroidDownloadEngine::AndroidDownloadEngine(QObject *parent)
    : QObject(parent)
{
    ensureBridgeRegistered();
}

bool AndroidDownloadEngine::available() const
{
#ifdef Q_OS_ANDROID
    ensureBridgeRegistered();
    if (!QJniObject::isClassAvailable("com/reclip/videodownloader/AndroidYtDlpBridge")) {
        return false;
    }

    return QJniObject::callStaticMethod<jboolean>(
        "com/reclip/videodownloader/AndroidYtDlpBridge",
        "isAvailable",
        "()Z");
#else
    return false;
#endif
}

bool AndroidDownloadEngine::ffmpegKitAvailable() const
{
#ifdef Q_OS_ANDROID
    // FFmpegKit is an embedded Java/native AAR on Android, not a desktop
    // executable that can be discovered through PATH or QProcess.
    return QJniObject::isClassAvailable("com/arthenica/ffmpegkit/FFmpegKit");
#else
    return false;
#endif
}

QString AndroidDownloadEngine::inspect(const QString &url)
{
#ifdef Q_OS_ANDROID
    ensureBridgeRegistered();
    if (!available()) {
        return {};
    }

    const QString requestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    rememberRequest(requestId, this);
    const QJniObject jRequestId = QJniObject::fromString(requestId);
    const QJniObject jUrl = QJniObject::fromString(url);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/AndroidYtDlpBridge",
        "inspect",
        "(Ljava/lang/String;Ljava/lang/String;)V",
        jRequestId.object<jstring>(),
        jUrl.object<jstring>());
    return requestId;
#else
    Q_UNUSED(url)
    return {};
#endif
}

QString AndroidDownloadEngine::download(const QString &url,
                                        const QString &formatId,
                                        const QString &format,
                                        const QString &outputDirectory,
                                        const QString &taskId)
{
#ifdef Q_OS_ANDROID
    ensureBridgeRegistered();
    if (!available()) {
        return {};
    }

    const QString requestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    rememberRequest(requestId, this);
    const QJniObject jRequestId = QJniObject::fromString(requestId);
    const QJniObject jUrl = QJniObject::fromString(url);
    const QJniObject jFormatId = QJniObject::fromString(formatId);
    const QJniObject jFormat = QJniObject::fromString(format);
    const QJniObject jOutputDirectory = QJniObject::fromString(outputDirectory);
    const QJniObject jTaskId = QJniObject::fromString(taskId);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/AndroidYtDlpBridge",
        "download",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V",
        jRequestId.object<jstring>(),
        jUrl.object<jstring>(),
        jFormatId.object<jstring>(),
        jFormat.object<jstring>(),
        jOutputDirectory.object<jstring>(),
        jTaskId.object<jstring>());
    return requestId;
#else
    Q_UNUSED(url)
    Q_UNUSED(formatId)
    Q_UNUSED(format)
    Q_UNUSED(outputDirectory)
    Q_UNUSED(taskId)
    return {};
#endif
}

void AndroidDownloadEngine::cancel(const QString &requestId)
{
#ifdef Q_OS_ANDROID
    if (requestId.isEmpty()) {
        return;
    }
    ensureBridgeRegistered();
    const QJniObject jRequestId = QJniObject::fromString(requestId);
    QJniObject::callStaticMethod<void>(
        "com/reclip/videodownloader/AndroidYtDlpBridge",
        "cancel",
        "(Ljava/lang/String;)V",
        jRequestId.object<jstring>());
#else
    Q_UNUSED(requestId)
#endif
}

QString AndroidDownloadEngine::takePendingRetryTaskId()
{
#ifdef Q_OS_ANDROID
    const QJniObject pendingTaskId = QJniObject::callStaticObjectMethod(
        "com/reclip/videodownloader/MainActivity",
        "consumePendingRetryTaskId",
        "()Ljava/lang/String;");
    return pendingTaskId.isValid() ? pendingTaskId.toString().trimmed() : QString();
#else
    return {};
#endif
}

void AndroidDownloadEngine::ensureBridgeRegistered()
{
#ifdef Q_OS_ANDROID
    if (g_bridgeRegistered
        || !QJniObject::isClassAvailable("com/reclip/videodownloader/AndroidYtDlpBridge")) {
        return;
    }

    QJniEnvironment environment;
    g_bridgeRegistered = environment.registerNativeMethods(
        "com/reclip/videodownloader/AndroidYtDlpBridge",
        {
            {"nativeHandleInspectionFinished",
             "(Ljava/lang/String;ZLjava/lang/String;Ljava/lang/String;)V",
             reinterpret_cast<void *>(handleInspectionFinished)},
            {"nativeHandleDownloadProgress",
             "(Ljava/lang/String;FJLjava/lang/String;Ljava/lang/String;)V",
             reinterpret_cast<void *>(handleDownloadProgress)},
            {"nativeHandleDownloadFinished",
             "(Ljava/lang/String;ZLjava/lang/String;Ljava/lang/String;)V",
             reinterpret_cast<void *>(handleDownloadFinished)},
        });
#endif
}
