#include <QCoreApplication>
#include <QTextStream>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    const QString jsonOutput = qEnvironmentVariable("RECLIP_FAKE_YTDLP_JSON");
    if (app.arguments().contains(QStringLiteral("--dump-single-json"))
        && !jsonOutput.isEmpty()) {
        QTextStream(stdout) << jsonOutput << Qt::endl;
        return 0;
    }

    const QString outputPath = qEnvironmentVariable("RECLIP_FAKE_YTDLP_OUTPUT");
    if (outputPath.isEmpty()) {
        return 2;
    }
    QTextStream(stdout) << outputPath << Qt::endl;
    return 0;
}
