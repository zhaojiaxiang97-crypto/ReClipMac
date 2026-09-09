#include "MediaInspector.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QRegularExpression>

#ifdef Q_OS_IOS
#include <QFileInfo>
#include <QNetworkRequest>
#endif

#include <algorithm>

MediaInspector::MediaInspector(QObject *parent)
    : QObject(parent)
    , m_androidEngine(this)
#ifdef Q_OS_IOS
    , m_iosNetwork(this)
#endif
{
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(35000);

#ifndef Q_OS_IOS
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] {
        m_standardOutput += m_process.readAllStandardOutput();
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_standardError += m_process.readAllStandardError();
    });
    connect(&m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
                handleFinished(exitCode, exitStatus);
            });
    connect(&m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
                handleProcessError(error);
            });
#endif
    connect(&m_androidEngine,
            &AndroidDownloadEngine::inspectionFinished,
            this,
            &MediaInspector::handleAndroidInspectionFinished);
    connect(&m_timeout, &QTimer::timeout, this, [this] {
        if (!m_inspecting) {
            return;
        }

        m_inspecting = false;
#ifndef Q_OS_IOS
        if (m_process.state() != QProcess::NotRunning) {
            m_process.kill();
        }
#endif
        if (!m_androidRequestId.isEmpty()) {
            m_androidEngine.cancel(m_androidRequestId);
        }
#ifdef Q_OS_IOS
        if (m_iosReply) {
            m_iosReply->abort();
            m_iosReply = nullptr;
        }
#endif
        finishWithError(QStringLiteral("timeout"), QStringLiteral("解析超时，请检查网络后重试"));
    });
}

bool MediaInspector::inspecting() const
{
    return m_inspecting;
}

bool MediaInspector::hasResult() const
{
    return m_hasResult;
}

QString MediaInspector::state() const
{
    return m_state;
}

QString MediaInspector::errorCode() const
{
    return m_errorCode;
}

QString MediaInspector::errorMessage() const
{
    return m_errorMessage;
}

QString MediaInspector::sourceUrl() const
{
    return m_sourceUrl;
}

QString MediaInspector::title() const
{
    return m_title;
}

QString MediaInspector::uploader() const
{
    return m_uploader;
}

QString MediaInspector::durationText() const
{
    return m_duration;
}

QUrl MediaInspector::thumbnailUrl() const
{
    return m_thumbnailUrl;
}

QVariantList MediaInspector::formats() const
{
    return m_formats;
}

QStringList MediaInspector::formatLabels() const
{
    return m_formatLabels;
}

QString MediaInspector::selectedFormatId() const
{
    return m_selectedFormatId;
}

void MediaInspector::setSelectedFormatId(const QString &formatId)
{
    if (m_selectedFormatId == formatId) {
        return;
    }
    m_selectedFormatId = formatId;
    emit selectedFormatChanged();
}

QString MediaInspector::ytDlpPath() const
{
    return m_ytDlpPath;
}

void MediaInspector::setYtDlpPath(const QString &path)
{
    if (m_ytDlpPath == path) {
        return;
    }
    m_ytDlpPath = path;
    emit ytDlpPathChanged();
}

void MediaInspector::inspect(const QString &url)
{
#ifndef Q_OS_IOS
    if (m_process.state() != QProcess::NotRunning) {
        m_inspecting = false;
        m_process.kill();
        m_process.waitForFinished(500);
    }
#endif
    if (!m_androidRequestId.isEmpty()) {
        m_androidEngine.cancel(m_androidRequestId);
        m_androidRequestId.clear();
    }
#ifdef Q_OS_IOS
    if (m_iosReply) {
        m_iosReply->disconnect(this);
        m_iosReply->abort();
        m_iosReply->deleteLater();
        m_iosReply = nullptr;
    }
#endif

    m_timeout.stop();
    m_standardOutput.clear();
    m_standardError.clear();
    resetResult();
    m_sourceUrl = url.trimmed();
    m_errorCode.clear();
    m_errorMessage.clear();

    const QUrl parsedUrl(m_sourceUrl);
    if (!parsedUrl.isValid() || parsedUrl.host().isEmpty()
        || (parsedUrl.scheme().compare(QStringLiteral("http"), Qt::CaseInsensitive) != 0
            && parsedUrl.scheme().compare(QStringLiteral("https"), Qt::CaseInsensitive) != 0)) {
        finishWithError(QStringLiteral("invalid-url"), QStringLiteral("请输入有效的 HTTP 或 HTTPS 媒体链接"));
        return;
    }

#ifdef Q_OS_ANDROID
    if (m_androidEngine.available()) {
        m_state = QStringLiteral("inspecting");
        m_inspecting = true;
        emit stateChanged();

        m_androidRequestId = m_androidEngine.inspect(m_sourceUrl);
        if (m_androidRequestId.isEmpty()) {
            finishWithError(QStringLiteral("tool-error"),
                            QStringLiteral("无法启动 Android yt-dlp 运行时"));
            return;
        }
        m_timeout.start();
        return;
    }
#endif

#ifdef Q_OS_IOS
    if (parsedUrl.scheme().compare(QStringLiteral("https"), Qt::CaseInsensitive) != 0) {
        finishWithError(QStringLiteral("https-required"),
                        QStringLiteral("iOS 版仅支持 HTTPS 直接媒体链接"));
        return;
    }
    inspectIosDirectMedia(parsedUrl);
    return;
#endif

#ifndef Q_OS_IOS
    if (m_ytDlpPath.trimmed().isEmpty()) {
        finishWithError(QStringLiteral("tool-missing"), QStringLiteral("yt-dlp 不可用，请先在工具诊断中完成配置"));
        return;
    }

    m_state = QStringLiteral("inspecting");
    m_inspecting = true;
    emit stateChanged();

    m_process.setProgram(m_ytDlpPath);
    m_process.setArguments({
        QStringLiteral("--no-playlist"),
        QStringLiteral("--no-warnings"),
        QStringLiteral("--no-progress"),
        QStringLiteral("--socket-timeout"),
        QStringLiteral("30"),
        QStringLiteral("-J"),
        m_sourceUrl
    });
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_process.start();
    m_timeout.start();
#endif
}

void MediaInspector::clear()
{
#ifndef Q_OS_IOS
    if (m_process.state() != QProcess::NotRunning) {
        m_inspecting = false;
        m_process.kill();
        m_process.waitForFinished(500);
    }
#endif
    if (!m_androidRequestId.isEmpty()) {
        m_androidEngine.cancel(m_androidRequestId);
        m_androidRequestId.clear();
    }
#ifdef Q_OS_IOS
    if (m_iosReply) {
        m_iosReply->disconnect(this);
        m_iosReply->abort();
        m_iosReply->deleteLater();
        m_iosReply = nullptr;
    }
#endif
    m_timeout.stop();
    m_sourceUrl.clear();
    m_errorCode.clear();
    m_errorMessage.clear();
    m_state = QStringLiteral("idle");
    resetResult();
    emit stateChanged();
}

#ifndef Q_OS_IOS
void MediaInspector::handleFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (!m_inspecting) {
        return;
    }

    m_timeout.stop();
    m_standardOutput += m_process.readAllStandardOutput();
    m_standardError += m_process.readAllStandardError();

    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        const QString rawMessage = QString::fromLocal8Bit(m_standardError).trimmed();
        const QStringList classification = classifyError(rawMessage);
        finishWithError(classification.value(0), classification.value(1));
        return;
    }

    parseMetadata(m_standardOutput);
}

void MediaInspector::handleProcessError(QProcess::ProcessError error)
{
    if (!m_inspecting) {
        return;
    }

    m_timeout.stop();
    if (error == QProcess::FailedToStart) {
        finishWithError(QStringLiteral("tool-error"), QStringLiteral("无法启动 yt-dlp，请检查工具路径和执行权限"));
    } else {
        finishWithError(QStringLiteral("tool-error"), QStringLiteral("yt-dlp 进程错误：%1").arg(m_process.errorString()));
    }
}
#endif

void MediaInspector::handleAndroidInspectionFinished(const QString &requestId,
                                                      bool success,
                                                      const QByteArray &payload,
                                                      const QString &errorMessage)
{
    if (!m_inspecting || requestId != m_androidRequestId) {
        return;
    }

    m_androidRequestId.clear();
    m_timeout.stop();
    if (!success) {
        const QStringList classification = classifyError(errorMessage);
        finishWithError(classification.value(0), classification.value(1));
        return;
    }

    parseMetadata(payload);
}

#ifdef Q_OS_IOS
void MediaInspector::inspectIosDirectMedia(const QUrl &url)
{
    m_state = QStringLiteral("inspecting");
    m_inspecting = true;
    emit stateChanged();

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("Range", "bytes=0-0");
    QNetworkReply *reply = m_iosNetwork.get(request);
    m_iosReply = reply;

    const auto finish = [this, reply] {
        finishIosDirectInspection(reply);
    };
    connect(reply, &QNetworkReply::metaDataChanged, this, finish);
    connect(reply, &QNetworkReply::finished, this, finish);
    m_timeout.start();
}

void MediaInspector::finishIosDirectInspection(QNetworkReply *reply)
{
    if (!m_inspecting || reply != m_iosReply) {
        return;
    }

    const auto closeReply = [this, reply] {
        m_iosReply = nullptr;
        reply->abort();
        reply->deleteLater();
    };
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (statusCode >= 400 || reply->error() != QNetworkReply::NoError) {
        const QString message = statusCode >= 400
            ? QStringLiteral("服务器返回 HTTP %1").arg(statusCode)
            : reply->errorString();
        closeReply();
        finishWithError(QStringLiteral("direct-link-unavailable"),
                        QStringLiteral("无法访问该媒体链接：%1").arg(message));
        return;
    }

    const QString contentType = reply->header(QNetworkRequest::ContentTypeHeader)
        .toString().toLower();
    const QString suffix = QFileInfo(reply->url().path()).suffix().toLower();
    const QStringList mediaSuffixes {
        QStringLiteral("mp4"), QStringLiteral("mov"), QStringLiteral("m4v"),
        QStringLiteral("webm"), QStringLiteral("mp3"), QStringLiteral("m4a"),
        QStringLiteral("aac"), QStringLiteral("wav")
    };
    if (!contentType.startsWith(QStringLiteral("video/"))
        && !contentType.startsWith(QStringLiteral("audio/"))
        && !mediaSuffixes.contains(suffix)) {
        closeReply();
        finishWithError(QStringLiteral("direct-link-required"),
                        QStringLiteral("iOS 版仅支持可直接访问的音视频文件链接"));
        return;
    }

    const QString fileName = QFileInfo(reply->url().path()).completeBaseName();
    m_title = fileName.isEmpty() ? reply->url().host() : fileName;
    m_uploader = reply->url().host();
    m_duration.clear();
    m_thumbnailUrl = QUrl();
    m_formats.clear();
    m_formatLabels = {QStringLiteral("原始文件")};
    m_formats.append(QVariantMap {
        {QStringLiteral("id"), QStringLiteral("direct")},
        {QStringLiteral("label"), QStringLiteral("原始文件")}
    });
    m_selectedFormatId = QStringLiteral("direct");
    m_inspecting = false;
    m_hasResult = true;
    m_state = QStringLiteral("ready");
    m_errorCode.clear();
    m_errorMessage.clear();
    m_timeout.stop();
    closeReply();
    emit stateChanged();
    emit resultChanged();
    emit selectedFormatChanged();
}
#endif

void MediaInspector::finishWithError(const QString &code, const QString &message)
{
    m_inspecting = false;
    m_hasResult = false;
    m_state = QStringLiteral("error");
    m_errorCode = code;
    m_errorMessage = message;
    emit stateChanged();
    emit resultChanged();
}

void MediaInspector::resetResult()
{
    m_hasResult = false;
    m_title.clear();
    m_uploader.clear();
    m_duration.clear();
    m_thumbnailUrl = QUrl();
    m_formats.clear();
    m_formatLabels.clear();
    m_selectedFormatId.clear();
}

void MediaInspector::parseMetadata(const QByteArray &output)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        const QString rawMessage = QString::fromLocal8Bit(m_standardError).trimmed();
        const QStringList classification = classifyError(
            rawMessage.isEmpty() ? QStringLiteral("yt-dlp 返回了无法解析的 JSON") : rawMessage);
        finishWithError(classification.value(0), classification.value(1));
        return;
    }

    const QJsonObject object = document.object();
    m_title = object.value(QStringLiteral("title")).toString().trimmed();
    if (m_title.isEmpty()) {
        m_title = QStringLiteral("未命名媒体");
    }
    m_uploader = object.value(QStringLiteral("uploader")).toString();
    if (m_uploader.isEmpty()) {
        m_uploader = object.value(QStringLiteral("channel")).toString();
    }

    const QJsonValue durationValue = object.value(QStringLiteral("duration"));
    m_duration = durationValue.isDouble() ? formatDuration(durationValue.toDouble()) : QString();
    const QString thumbnail = object.value(QStringLiteral("thumbnail")).toString();
    m_thumbnailUrl = QUrl(thumbnail);

    QHash<int, FormatCandidate> bestByHeight;
    const QJsonArray sourceFormats = object.value(QStringLiteral("formats")).toArray();
    for (const QJsonValue &value : sourceFormats) {
        const QJsonObject format = value.toObject();
        const QString id = format.value(QStringLiteral("format_id")).toString();
        const int height = format.value(QStringLiteral("height")).toInt();
        const QString videoCodec = format.value(QStringLiteral("vcodec")).toString();
        if (id.isEmpty() || height <= 0 || videoCodec == QStringLiteral("none")) {
            continue;
        }

        const double bitrate = format.value(QStringLiteral("tbr")).toDouble();
        const auto current = bestByHeight.constFind(height);
        if (current != bestByHeight.constEnd() && current->bitrate >= bitrate) {
            continue;
        }
        bestByHeight.insert(height, FormatCandidate{id, height, bitrate});
    }

    QList<FormatCandidate> candidates = bestByHeight.values();
    std::sort(candidates.begin(), candidates.end(), [](const FormatCandidate &left, const FormatCandidate &right) {
        return left.height > right.height;
    });
    for (const FormatCandidate &candidate : candidates) {
        QVariantMap format;
        format.insert(QStringLiteral("id"), candidate.id);
        format.insert(QStringLiteral("height"), candidate.height);
        format.insert(QStringLiteral("label"), QStringLiteral("%1p").arg(candidate.height));
        m_formats.append(format);
        m_formatLabels.append(format.value(QStringLiteral("label")).toString());
    }
    if (!candidates.isEmpty()) {
        m_selectedFormatId = candidates.first().id;
    }

    m_inspecting = false;
    m_hasResult = true;
    m_state = QStringLiteral("ready");
    m_errorCode.clear();
    m_errorMessage.clear();
    emit stateChanged();
    emit resultChanged();
    emit selectedFormatChanged();
}

QStringList MediaInspector::classifyError(const QString &rawMessage) const
{
    const QString message = rawMessage.trimmed();
    const QString lower = message.toLower();

    if (lower.contains(QStringLiteral("unsupported url"))
        || lower.contains(QStringLiteral("no suitable extractor"))) {
        return {QStringLiteral("unsupported-url"), QStringLiteral("该链接格式不受支持，请检查链接或更换来源")};
    }
    if (lower.contains(QStringLiteral("private video"))
        || lower.contains(QStringLiteral("video unavailable"))
        || lower.contains(QStringLiteral("login required"))
        || lower.contains(QStringLiteral("sign in"))) {
        return {QStringLiteral("private-media"), QStringLiteral("媒体不可公开访问，可能是私密内容或需要登录")};
    }
    if (lower.contains(QStringLiteral("http error 404")) || lower.contains(QStringLiteral("not found"))) {
        return {QStringLiteral("not-found"), QStringLiteral("找不到该媒体，链接可能已失效")};
    }
    if (lower.contains(QStringLiteral("timed out")) || lower.contains(QStringLiteral("timeout"))) {
        return {QStringLiteral("timeout"), QStringLiteral("网络请求超时，请检查网络后重试")};
    }
    if (lower.contains(QStringLiteral("drm"))) {
        return {QStringLiteral("drm"), QStringLiteral("该媒体受 DRM 保护，应用不会尝试绕过限制")};
    }

    return {QStringLiteral("tool-error"), message.isEmpty()
                ? QStringLiteral("媒体解析失败，请检查链接和 yt-dlp 输出")
                : QStringLiteral("媒体解析失败：%1").arg(message)};
}

QString MediaInspector::formatDuration(double seconds)
{
    if (seconds < 0.0) {
        return {};
    }

    const qint64 totalSeconds = qRound64(seconds);
    const qint64 hours = totalSeconds / 3600;
    const qint64 minutes = (totalSeconds % 3600) / 60;
    const qint64 remainingSeconds = totalSeconds % 60;
    if (hours > 0) {
        return QStringLiteral("%1:%2:%3")
            .arg(hours)
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(remainingSeconds, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2")
        .arg(minutes)
        .arg(remainingSeconds, 2, 10, QLatin1Char('0'));
}
