#include "ToolLocator.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>

ToolLocator::ToolLocator(QObject *parent)
    : QObject(parent)
{
    connect(&m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
                if (m_currentTool.isEmpty()) {
                    return;
                }

                const QString output = QString::fromLocal8Bit(m_process.readAllStandardOutput()).trimmed();
                if (exitStatus != QProcess::NormalExit || exitCode != 0) {
                    finishCurrent(false, {}, QStringLiteral("版本读取失败（退出码 %1）").arg(exitCode));
                    return;
                }

                const QString version = output.section('\n', 0, 0).trimmed();
                if (version.isEmpty()) {
                    finishCurrent(false, {}, QStringLiteral("版本读取失败：工具没有返回版本信息"));
                    return;
                }

                finishCurrent(true, version, QStringLiteral("已就绪"));
            });

    connect(&m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
                if (m_currentTool.isEmpty()) {
                    return;
                }

                QString message;
                switch (error) {
                case QProcess::FailedToStart:
                    message = QStringLiteral("无法启动工具，请检查路径和执行权限");
                    break;
                case QProcess::Timedout:
                    message = QStringLiteral("工具响应超时");
                    break;
                case QProcess::Crashed:
                    message = QStringLiteral("工具启动后异常退出");
                    break;
                default:
                    message = QStringLiteral("工具检测失败：%1").arg(m_process.errorString());
                    break;
                }
                finishCurrent(false, {}, message);
            });
}

bool ToolLocator::ready() const
{
    return m_ytDlp.available && m_ffmpeg.available;
}

bool ToolLocator::checking() const
{
    return m_checking;
}

bool ToolLocator::ytDlpAvailable() const
{
    return m_ytDlp.available;
}

QString ToolLocator::ytDlpPath() const
{
    return m_ytDlp.path;
}

QString ToolLocator::ytDlpCustomPath() const
{
    return m_ytDlp.customPath;
}

QString ToolLocator::ytDlpVersion() const
{
    return m_ytDlp.version;
}

QString ToolLocator::ytDlpStatus() const
{
    return m_ytDlp.message;
}

bool ToolLocator::ffmpegAvailable() const
{
    return m_ffmpeg.available;
}

QString ToolLocator::ffmpegPath() const
{
    return m_ffmpeg.path;
}

QString ToolLocator::ffmpegCustomPath() const
{
    return m_ffmpeg.customPath;
}

QString ToolLocator::ffmpegVersion() const
{
    return m_ffmpeg.version;
}

QString ToolLocator::ffmpegStatus() const
{
    return m_ffmpeg.message;
}

void ToolLocator::refresh()
{
    if (m_process.state() != QProcess::NotRunning) {
        m_currentTool.clear();
        m_process.kill();
        m_process.waitForFinished(500);
    }

    m_pendingTools = {QStringLiteral("yt-dlp"), QStringLiteral("ffmpeg")};
    m_checking = true;
    prepareState(QStringLiteral("yt-dlp"));
    prepareState(QStringLiteral("ffmpeg"));
    emit statusChanged();
    detectNext();
}

void ToolLocator::setCustomPath(const QString &toolName, const QString &path)
{
    const QString normalizedName = normalizeToolName(toolName);
    if (!isKnownTool(normalizedName)) {
        return;
    }

    QSettings settings;
    const QString key = QStringLiteral("tools/%1Path").arg(normalizedName);
    const QString cleanedPath = path.trimmed();
    if (cleanedPath.isEmpty()) {
        settings.remove(key);
    } else {
        settings.setValue(key, cleanedPath);
    }
    settings.sync();
    refresh();
}

void ToolLocator::clearCustomPath(const QString &toolName)
{
    setCustomPath(toolName, {});
}

QString ToolLocator::normalizeToolName(const QString &toolName)
{
    const QString normalized = toolName.trimmed().toLower();
    if (normalized == QStringLiteral("ytdlp")) {
        return QStringLiteral("yt-dlp");
    }
    return normalized;
}

bool ToolLocator::isKnownTool(const QString &toolName)
{
    return toolName == QStringLiteral("yt-dlp") || toolName == QStringLiteral("ffmpeg");
}

ToolLocator::ToolState &ToolLocator::stateFor(const QString &toolName)
{
    return normalizeToolName(toolName) == QStringLiteral("yt-dlp") ? m_ytDlp : m_ffmpeg;
}

const ToolLocator::ToolState &ToolLocator::stateFor(const QString &toolName) const
{
    return normalizeToolName(toolName) == QStringLiteral("yt-dlp") ? m_ytDlp : m_ffmpeg;
}

QString ToolLocator::configuredPath(const QString &toolName) const
{
    QSettings settings;
    return settings.value(QStringLiteral("tools/%1Path").arg(normalizeToolName(toolName))).toString().trimmed();
}

void ToolLocator::prepareState(const QString &toolName)
{
    ToolState &state = stateFor(toolName);
    state.customPath = configuredPath(toolName);
    state.version.clear();
    state.available = false;

    if (!state.customPath.isEmpty()) {
        const QFileInfo configuredFile(state.customPath);
        if (configuredFile.exists() && configuredFile.isFile() && configuredFile.isExecutable()) {
            state.path = configuredFile.absoluteFilePath();
            state.message = QStringLiteral("检测中…");
            return;
        }

        state.path = state.customPath;
        state.message = QStringLiteral("配置路径不可执行，请修改路径或清除自定义路径");
        return;
    }

    const QString executableName = normalizeToolName(toolName);
    const QString applicationDirectory = QCoreApplication::applicationDirPath();
    const QStringList packagedCandidates {
        QDir(applicationDirectory).filePath(QStringLiteral("bin/%1").arg(executableName)),
        QDir(applicationDirectory).filePath(QStringLiteral("../Resources/bin/%1").arg(executableName)),
        QDir(applicationDirectory).filePath(executableName),
        QDir(applicationDirectory).filePath(QStringLiteral("../Resources/%1").arg(executableName))
    };
    for (const QString &candidate : packagedCandidates) {
        const QFileInfo packagedFile(candidate);
        if (packagedFile.exists() && packagedFile.isFile() && packagedFile.isExecutable()) {
            state.path = packagedFile.absoluteFilePath();
            state.message = QStringLiteral("检测中…");
            return;
        }
    }

    state.path = QStandardPaths::findExecutable(executableName);
    if (state.path.isEmpty()) {
        state.message = QStringLiteral("未在系统 PATH 中找到，请安装工具或指定路径");
    } else {
        state.message = QStringLiteral("检测中…");
    }
}

void ToolLocator::detectNext()
{
    while (!m_pendingTools.isEmpty()) {
        const QString toolName = m_pendingTools.takeFirst();
        ToolState &state = stateFor(toolName);
        if (state.path.isEmpty() || !state.message.startsWith(QStringLiteral("检测中"))) {
            emit statusChanged();
            continue;
        }

        m_currentTool = toolName;
        m_process.setProgram(state.path);
        m_process.setArguments({QStringLiteral("--version")});
        m_process.setProcessChannelMode(QProcess::MergedChannels);
        m_process.start();
        return;
    }

    m_currentTool.clear();
    m_checking = false;
    emit statusChanged();
}

void ToolLocator::finishCurrent(bool available, const QString &version, const QString &message)
{
    if (m_currentTool.isEmpty()) {
        return;
    }

    ToolState &state = stateFor(m_currentTool);
    state.available = available;
    state.version = version;
    state.message = message;
    m_currentTool.clear();
    emit statusChanged();
    detectNext();
}
