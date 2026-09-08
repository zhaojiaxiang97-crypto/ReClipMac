#include <QCoreApplication>
#include <QGuiApplication>
#include <QQuickStyle>
#include <QQmlApplicationEngine>

#if defined(Q_OS_ANDROID)
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#endif

#if defined(Q_OS_ANDROID)
namespace {
bool androidSupportsVulkan()
{
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return false;
    }

    const QJniObject packageManager = context.callObjectMethod(
        "getPackageManager", "()Landroid/content/pm/PackageManager;");
    if (!packageManager.isValid()) {
        return false;
    }

    const auto hasFeature = [&packageManager](const char *feature) {
        const QJniObject featureName = QJniObject::fromString(QString::fromLatin1(feature));
        return packageManager.callMethod<jboolean>(
                   "hasSystemFeature", "(Ljava/lang/String;)Z", featureName.object<jstring>())
            == JNI_TRUE;
    };

    return hasFeature("android.hardware.vulkan.level")
        || hasFeature("android.hardware.vulkan.version");
}
}
#endif

int main(int argc, char *argv[])
{
    // The application uses custom Qt Quick Controls content/background items.
    // Basic keeps that styling consistent in both the fallback and Kirigami shells.
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QGuiApplication app(argc, argv);
#if defined(Q_OS_ANDROID)
    // Some Android MediaTek/PowerVR stacks present corrupted Qt Quick OpenGL
    // buffers. Prefer Vulkan when the device advertises it, while allowing a
    // launch-time QSG_RHI_BACKEND override for diagnostics and compatibility
    // testing. The setting is applied before QQmlApplicationEngine creates a
    // QQuickWindow.
    if (qEnvironmentVariableIsEmpty("QSG_RHI_BACKEND") && androidSupportsVulkan()) {
        qputenv("QSG_RHI_BACKEND", "vulkan");
    }
#endif
    QGuiApplication::setApplicationName(QStringLiteral("Video Downloader"));
    QGuiApplication::setOrganizationName(QStringLiteral("ReClip"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("reclip.app"));
    QGuiApplication::setApplicationVersion(QStringLiteral("0.1.0"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] {
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

#ifdef RECLIP_HAS_KIRIGAMI
    // The Kirigami plugins are copied beside the executable under qml/ so the
    // same binary can be launched from a build tree or an installed bundle.
    engine.addImportPath(QCoreApplication::applicationDirPath() + QStringLiteral("/qml"));
    engine.loadFromModule(QStringLiteral("ReClip"), QStringLiteral("MainKirigami"));
#else
    engine.loadFromModule(QStringLiteral("ReClip"), QStringLiteral("Main"));
#endif
    return app.exec();
}
