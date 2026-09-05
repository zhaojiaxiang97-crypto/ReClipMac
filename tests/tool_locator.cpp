#include "ToolLocator.h"

#include <QCoreApplication>
#include <QEventLoop>
#include <QTimer>

namespace {

bool waitForRefresh(ToolLocator &locator)
{
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);

    QObject::connect(&locator, &ToolLocator::statusChanged, &loop, [&] {
        if (!locator.checking()) {
            loop.quit();
        }
    });
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);

    locator.refresh();
    if (locator.checking()) {
        timeout.start(5000);
        loop.exec();
    }
    return !locator.checking();
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("ReClipToolLocatorTest"));
    QCoreApplication::setOrganizationName(QStringLiteral("ReClipTests"));

    ToolLocator locator;
    if (!waitForRefresh(locator)) {
        return 1;
    }

    if (locator.ytDlpStatus().isEmpty() || locator.ffmpegStatus().isEmpty()) {
        return 2;
    }

    locator.setCustomPath(QStringLiteral("ffmpeg"), QStringLiteral("Z:/reclip-invalid/ffmpeg.exe"));
    if (!waitForRefresh(locator) || locator.ffmpegAvailable()
        || !locator.ffmpegStatus().contains(QStringLiteral("配置路径不可执行"))) {
        return 3;
    }

    locator.clearCustomPath(QStringLiteral("ffmpeg"));
    return waitForRefresh(locator) ? 0 : 4;
}
