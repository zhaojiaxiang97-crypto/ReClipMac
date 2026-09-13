#include "YtDlpService.h"
#include <QFutureWatcher>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>
#include <QUuid>
#include <cmath>

#ifdef RECLIP_HAS_YTDLP_SDK
#include "PythonRuntime.h"
#endif

namespace ReClip::YtDlp {

YtDlpService::YtDlpService(QObject *parent) : QObject(parent) {}

YtDlpService::~YtDlpService()
{
    for (const auto &operation : std::as_const(m_operations)) {
        operation->cancel->store(true);
        if (operation->process) {
            operation->process->disconnect(this);
            operation->process->kill();
            operation->process->waitForFinished(500);
        }
    }
}

bool YtDlpService::embeddedEnabled()
{
#ifdef RECLIP_HAS_YTDLP_SDK
    return true;
#else
    return false;
#endif
}

bool YtDlpService::usesEmbedded() const { return embeddedEnabled() && m_program.isEmpty(); }
void YtDlpService::setProgram(const QString &program) { m_program = program.trimmed(); }

QString YtDlpService::probe()
{
    Request request;
    request.probe = true;
    return inspect(request);
}

QString YtDlpService::inspect(const Request &request)
{
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_operations.insert(id, std::make_shared<Operation>());
    const QString program = m_program;
    QTimer::singleShot(0, this, [this, id, request, program] { start(id, request, program); });
    return id;
}

QString YtDlpService::download(const Request &request)
{
    Request downloadRequest = request;
    downloadRequest.probe = false;
    downloadRequest.download = true;
    return inspect(downloadRequest);
}

void YtDlpService::start(const QString &id, const Request &request, const QString &program)
{
    const auto operation = m_operations.value(id);
    if (!operation) { return; }
    if (operation->cancel->load()) { finish(id, {}); return; }
    const QUrl url(request.url);
    if (!request.probe && (!url.isValid() || url.host().isEmpty()
        || (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https")))) {
        finish(id, {false, {}, QStringLiteral("invalid-url"), QStringLiteral("请输入有效的 HTTP 或 HTTPS 媒体链接")});
        return;
    }
    if (request.probe && request.download) {
        finish(id, {false, {}, QStringLiteral("invalid-request"), QStringLiteral("probe and download cannot be requested together")});
        return;
    }
    if (request.download) {
        const QFileInfo outputInfo(request.outputPath);
        if (request.outputPath.trimmed().isEmpty() || !outputInfo.isAbsolute()
            || outputInfo.fileName().isEmpty() || outputInfo.isDir()
            || !outputInfo.absoluteDir().exists()) {
            finish(id, {false, {}, QStringLiteral("invalid-output"), QStringLiteral("embedded download requires an absolute output path")});
            return;
        }
        if (outputInfo.exists()) {
            finish(id, {false, {}, QStringLiteral("output-exists"), QStringLiteral("embedded download never overwrites an existing output file")});
            return;
        }
    }
    if (!std::isfinite(request.timeoutSeconds) || request.timeoutSeconds <= 0 || request.timeoutSeconds > 60) {
        finish(id, {false, {}, QStringLiteral("invalid-request"), QStringLiteral("解析超时必须在 0 到 60 秒之间")});
        return;
    }
    operation->timer = new QTimer(this);
    operation->timer->setSingleShot(true);
    connect(operation->timer, &QTimer::timeout, this, [this, id, operation] {
        operation->timedOut = true;
        cancel(id);
    });
    operation->timer->start(qMax(1, qRound(request.timeoutSeconds * 1000)));
#ifdef RECLIP_HAS_YTDLP_SDK
    if (program.isEmpty()) {
        auto *watcher = new QFutureWatcher<Result>(this);
        connect(watcher, &QFutureWatcher<Result>::finished, this, [this, id, watcher] {
            const Result result = watcher->result();
            watcher->deleteLater();
            finish(id, result);
        });
        watcher->setFuture(submitPython(request, operation->cancel));
        return;
    }
#endif
    if (program.isEmpty()) {
        finish(id, {false, {}, QStringLiteral("tool-missing"), QStringLiteral("yt-dlp 未配置且内嵌后端未启用")});
        return;
    }
    auto *process = new QProcess(this);
    operation->process = process;
    connect(process, &QProcess::readyReadStandardOutput, this, [operation, process] {
        operation->output += process->readAllStandardOutput();
        if (operation->output.size() > 32 * 1024 * 1024) { process->kill(); }
    });
    connect(process, &QProcess::readyReadStandardError, this, [operation, process] {
        operation->error = (operation->error + process->readAllStandardError()).right(16384);
    });
    connect(process, &QProcess::errorOccurred, this, [this, id, process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            finish(id, {false, {}, QStringLiteral("tool-error"), QStringLiteral("无法启动 yt-dlp：%1").arg(process->errorString())});
        }
    });
    connect(process, &QProcess::finished, this, [this, id, operation, process, request](int code, QProcess::ExitStatus status) {
        operation->output += process->readAllStandardOutput();
        operation->error += process->readAllStandardError();
        if (code != 0 || status != QProcess::NormalExit) {
            finish(id, {false, {}, QStringLiteral("tool-error"), QString::fromUtf8(operation->error).trimmed()});
        } else if (request.probe) {
            QJsonObject payload {{QStringLiteral("ytDlp"), QString::fromUtf8(operation->output).trimmed()}, {QStringLiteral("backend"), QStringLiteral("process")}};
            finish(id, {true, QJsonDocument(payload).toJson(QJsonDocument::Compact), {}, {}});
        } else if (request.download) {
            if (!QFileInfo(request.outputPath).isFile()) {
                finish(id, {false, {}, QStringLiteral("tool-error"), QStringLiteral("yt-dlp exited without producing the requested output file")});
                return;
            }
            const QJsonObject payload {{QStringLiteral("path"), QFileInfo(request.outputPath).absoluteFilePath()},
                                       {QStringLiteral("backend"), QStringLiteral("process")}};
            finish(id, {true, QJsonDocument(payload).toJson(QJsonDocument::Compact), {}, {}});
        } else {
            finish(id, {true, operation->output, {}, {}});
        }
    });
    QStringList arguments;
    if (request.probe) {
        arguments = {QStringLiteral("--version")};
    } else if (request.download) {
        arguments = {QStringLiteral("--ignore-config"), QStringLiteral("--no-playlist"),
            QStringLiteral("--no-warnings"), QStringLiteral("--newline"),
            QStringLiteral("--no-quiet"), QStringLiteral("--no-overwrites"),
            QStringLiteral("--downloader"), QStringLiteral("native"),
            QStringLiteral("--socket-timeout"), QString::number(request.timeoutSeconds),
            QStringLiteral("-o"), request.outputPath};
        if (!request.formatSelector.isEmpty()) {
            arguments += {QStringLiteral("-f"), request.formatSelector};
        }
        arguments += {QStringLiteral("--"), request.url};
    } else {
        arguments = {QStringLiteral("--ignore-config"), QStringLiteral("--no-playlist"),
            QStringLiteral("--no-warnings"), QStringLiteral("--no-progress"),
            QStringLiteral("--socket-timeout"), QString::number(request.timeoutSeconds),
            QStringLiteral("--skip-download"), QStringLiteral("--dump-single-json")};
        if (!request.formatSelector.isEmpty()) { arguments += {QStringLiteral("-f"), request.formatSelector}; }
        arguments += {QStringLiteral("--"), request.url};
    }
    process->start(program, arguments);
}

void YtDlpService::cancel(const QString &id)
{
    const auto operation = m_operations.value(id);
    if (!operation) { return; }
    operation->cancel->store(true);
    // A later deadline must not relabel an earlier user cancellation.
    if (operation->timer) { operation->timer->stop(); }
    if (operation->process) { operation->process->kill(); }
}

void YtDlpService::finish(const QString &id, Result result)
{
    const auto operation = m_operations.take(id);
    if (!operation) { return; }
    if (operation->timer) { operation->timer->stop(); operation->timer->deleteLater(); }
    if (operation->process) { operation->process->deleteLater(); }
    if (operation->timedOut) {
        result = {false, {}, QStringLiteral("timeout"), QStringLiteral("解析超时，请检查网络后重试")};
    } else if (operation->cancel->load()) {
        result = {false, {}, QStringLiteral("cancelled"), QStringLiteral("已取消")};
    }
    if (!result.ok) {
        result.errorMessage.replace(QRegularExpression(QStringLiteral("https?://[^\\s\\\"'<>]+")), QStringLiteral("<URL>"));
        if (result.errorMessage.isEmpty()) { result.errorMessage = QStringLiteral("yt-dlp 解析失败"); }
    }
    emit finished(id, result.ok, result.payload, result.errorCode, result.errorMessage);
}

} // namespace ReClip::YtDlp
