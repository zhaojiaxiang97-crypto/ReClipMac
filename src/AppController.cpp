#include "AppController.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QMetaObject>

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QJniObject>
#endif

namespace {
#ifdef Q_OS_ANDROID
AppController *g_appController = nullptr;

void JNICALL handleIncomingUrl(JNIEnv *, jclass, jstring value)
{
    if (!g_appController || !value) {
        return;
    }

    const QString url = QJniObject(value).toString().trimmed();
    if (url.isEmpty()) {
        return;
    }

    QMetaObject::invokeMethod(
        g_appController,
        [url] {
            if (g_appController) {
                g_appController->setIncomingUrl(url);
            }
        },
        Qt::QueuedConnection);
}
#endif
}

AppController::AppController(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_ANDROID
    g_appController = this;

    QJniEnvironment environment;
    environment.registerNativeMethods(
        "com/reclip/videodownloader/MainActivity",
        {{"nativeHandleUrl", "(Ljava/lang/String;)V", reinterpret_cast<void *>(handleIncomingUrl)}});

    const QJniObject pendingUrl = QJniObject::callStaticObjectMethod(
        "com/reclip/videodownloader/MainActivity",
        "consumePendingUrl",
        "()Ljava/lang/String;");
    if (pendingUrl.isValid()) {
        setIncomingUrl(pendingUrl.toString());
    }
#endif
}

QString AppController::productName() const
{
    return QStringLiteral("Video Downloader");
}

QString AppController::status() const
{
    return QStringLiteral("C++ backend connected");
}

QString AppController::qtVersion() const
{
    return QString::fromLatin1(QT_VERSION_STR);
}

QString AppController::incomingUrl() const
{
    return m_incomingUrl;
}

void AppController::setIncomingUrl(const QString &url)
{
    const QString cleaned = url.trimmed();
    if (cleaned.isEmpty() || m_incomingUrl == cleaned) {
        return;
    }

    m_incomingUrl = cleaned;
    emit incomingUrlChanged();
}

void AppController::clearIncomingUrl()
{
    if (m_incomingUrl.isEmpty()) {
        return;
    }

    m_incomingUrl.clear();
    emit incomingUrlChanged();
}

QString AppController::clipboardText() const
{
    const QClipboard *clipboard = QGuiApplication::clipboard();
    return clipboard ? clipboard->text(QClipboard::Clipboard) : QString();
}
