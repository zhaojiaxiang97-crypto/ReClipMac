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

    inspector.setYtDlpPath({});
    inspector.inspect(QStringLiteral("https://example.com/media"));
    if (inspector.state() != QStringLiteral("error")
        || inspector.errorCode() != QStringLiteral("tool-missing")) {
        return 2;
    }

    return 0;
}
