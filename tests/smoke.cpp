#include <QCoreApplication>
#include <QVersionNumber>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    const QVersionNumber version = QVersionNumber::fromString(QString::fromLatin1(QT_VERSION_STR));
    return version.majorVersion() >= 6 ? 0 : 1;
}
