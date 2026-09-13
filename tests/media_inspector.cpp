#include "MediaInspector.h"

#include <QCoreApplication>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    MediaInspector inspector;
    inspector.inspect(QStringLiteral("not-a-url"));
    if (inspector.state() != QStringLiteral("error")
        || inspector.errorCode() != QStringLiteral("invalid-url")) {
        return 1;
    }

#ifndef RECLIP_HAS_YTDLP_SDK
    inspector.setYtDlpPath({});
    inspector.inspect(QStringLiteral("https://example.com/media"));
    if (inspector.state() != QStringLiteral("error")
        || inspector.errorCode() != QStringLiteral("tool-missing")) {
        return 2;
    }
#endif

    return 0;
}
