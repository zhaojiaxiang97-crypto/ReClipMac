#include <QCoreApplication>
#include <QGuiApplication>
#include <QQuickStyle>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    // The application uses custom Qt Quick Controls content/background items.
    // Basic keeps that styling consistent in both the fallback and Kirigami shells.
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("ReClip"));
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
