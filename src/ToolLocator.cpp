#include "ToolLocator.h"
#include "PlatformPaths.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QSettings>
#include <QStandardPaths>

ToolLocator::ToolLocator(QObject *parent)
    : QObject(parent)
    , m_androidEngine(this)
{
#ifndef Q_OS_IOS
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
                    message = QStringLiteral("工具启动后异常退出（%1，退出码 %2）")
                                  .arg(m_process.errorString())
                                  .arg(m_process.exitCode());
                    break;
                default:
                    message = QStringLiteral("工具检测失败：%1").arg(m_process.errorString());
                    break;
                }
                finishCurrent(false, {}, message);
            });
#endif
}

bool ToolLocator::ready() const
{
#ifdef Q_OS_IOS
    return true;
#endif
#ifdef Q_OS_ANDROID
    if (m_androidEngine.available()) {
        return m_ytDlp.available && m_ffmpeg.available;
    }
#endif
    return m_ytDlp.available && m_ffmpeg.available && m_ffprobe.available;
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

bool ToolLocator::ffprobeAvailable() const
{
    return m_ffprobe.available;
}

QString ToolLocator::ffprobePath() const
{
    return m_ffprobe.path;
}

QString ToolLocator::ffprobeCustomPath() const
{
    return m_ffprobe.customPath;
}

QString ToolLocator::ffprobeVersion() const
{
    return m_ffprobe.version;
}

QString ToolLocator::ffprobeStatus() const
{
    return m_ffprobe.message;
}

void ToolLocator::refresh()
{
#ifndef Q_OS_IOS
    if (m_process.state() != QProcess::NotRunning) {
        m_currentTool.clear();
        m_process.kill();
        m_process.waitForFinished(500);
    }
#endif

    m_pendingTools = {
        QStringLiteral("yt-dlp"),
        QStringLiteral("ffmpeg"),
        QStringLiteral("ffprobe")
    };
    m_checking = true;
    prepareState(QStringLiteral("yt-dlp"));
    prepareState(QStringLiteral("ffmpeg"));
    prepareState(QStringLiteral("ffprobe"));
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
    return toolName == QStringLiteral("yt-dlp")
        || toolName == QStringLiteral("ffmpeg")
        || toolName == QStringLiteral("ffprobe");
}

ToolLocator::ToolState &ToolLocator::stateFor(const QString &toolName)
{
    const QString normalizedName = normalizeToolName(toolName);
    if (normalizedName == QStringLiteral("yt-dlp")) {
        return m_ytDlp;
    }
    if (normalizedName == QStringLiteral("ffmpeg")) {
        return m_ffmpeg;
    }
    return m_ffprobe;
}

const ToolLocator::ToolState &ToolLocator::stateFor(const QString &toolName) const
{
    const QString normalizedName = normalizeToolName(toolName);
    if (normalizedName == QStringLiteral("yt-dlp")) {
        return m_ytDlp;
    }
    if (normalizedName == QStringLiteral("ffmpeg")) {
        return m_ffmpeg;
    }
    return m_ffprobe;
}

QString ToolLocator::configuredPath(const QString &toolName) const
{
    QSettings settings;
    return settings.value(QStringLiteral("tools/%1Path").arg(normalizeToolName(toolName))).toString().trimmed();
}

namespace {

QStringList packagedExecutableNames(const QString &executableName)
{
    QStringList names;
#ifdef Q_OS_WIN
    if (!executableName.endsWith(QStringLiteral(".exe"), Qt::CaseInsensitive)) {
        names.append(executableName + QStringLiteral(".exe"));
    }
#endif
    names.append(executableName);
    return names;
}

} // namespace

void ToolLocator::prepareState(const QString &toolName)
{
    ToolState &state = stateFor(toolName);
    state.customPath = configuredPath(toolName);
    state.version.clear();
    state.available = false;

#ifdef Q_OS_IOS
    state.path.clear();
    state.version = QStringLiteral("iOS 原生下载");
    state.available = true;
    state.message = QStringLiteral("仅支持 HTTPS 直接媒体链接");
    return;
#endif

#ifdef Q_OS_ANDROID
    if (normalizeToolName(toolName) == QStringLiteral("yt-dlp")
        && m_androidEngine.available()) {
        state.path.clear();
        state.version = QStringLiteral("yt-dlp-android 2.0.2");
        state.available = true;
        state.message = QStringLiteral("Android 内置运行时已就绪");
        return;
    }

    if (normalizeToolName(toolName) == QStringLiteral("ffmpeg")
        && m_androidEngine.ffmpegKitAvailable()) {
        state.path.clear();
        state.version = QStringLiteral("FFmpegKit 8.1.7");
        state.available = true;
        state.message = QStringLiteral("Android 内置 FFmpegKit 运行时已就绪");
        return;
    }

    if (normalizeToolName(toolName) == QStringLiteral("ffprobe")
        && m_androidEngine.ffmpegKitAvailable()) {
        state.path.clear();
        state.version = QStringLiteral("FFprobeKit 8.1.7");
        state.available = true;
        state.message = QStringLiteral("Android 内置 FFprobeKit 运行时已就绪");
        return;
    }
#endif

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
    const QStringList packagedDirectories {
        PlatformPaths::runtimeDirectory(),
        QDir(PlatformPaths::cacheDirectory()).filePath(QStringLiteral("bin")),
        QDir(applicationDirectory).filePath(QStringLiteral("bin")),
        QDir(applicationDirectory).filePath(QStringLiteral("../Resources/bin")),
        applicationDirectory,
        QDir(applicationDirectory).filePath(QStringLiteral("../Resources"))
    };
    const QStringList packagedNames = packagedExecutableNames(executableName);
    for (const QString &directory : packagedDirectories) {
        for (const QString &name : packagedNames) {
            const QFileInfo packagedFile(QDir(directory).filePath(name));
            if (packagedFile.exists() && packagedFile.isFile() && packagedFile.isExecutable()) {
                state.path = packagedFile.absoluteFilePath();
                state.message = QStringLiteral("检测中…");
                return;
            }
        }
    }

#ifdef Q_OS_ANDROID
    state.path.clear();
    state.message = QStringLiteral("未找到 Android 运行时，请将工具放入 %1 或设置自定义路径")
        .arg(PlatformPaths::runtimeDirectory());
#else
#ifdef Q_OS_MACOS
    state.path = QStandardPaths::findExecutable(executableName, {
        QStringLiteral("/opt/homebrew/bin"),
        QStringLiteral("/usr/local/bin")
    });
    if (state.path.isEmpty()) {
        state.path = QStandardPaths::findExecutable(executableName);
    }
#else
    state.path = QStandardPaths::findExecutable(executableName);
#endif
    if (state.path.isEmpty()) {
        state.message = QStringLiteral("未在系统 PATH 中找到，请安装工具或指定路径");
    } else {
        state.message = QStringLiteral("检测中…");
    }
#endif
}

void ToolLocator::detectNext()
{
#ifdef Q_OS_IOS
    m_pendingTools.clear();
    m_checking = false;
    emit statusChanged();
    return;
#else
    while (!m_pendingTools.isEmpty()) {
        const QString toolName = m_pendingTools.takeFirst();
        ToolState &state = stateFor(toolName);
        if (state.path.isEmpty() || !state.message.startsWith(QStringLiteral("检测中"))) {
            emit statusChanged();
            continue;
        }

        m_currentTool = toolName;
        m_process.setProgram(state.path);
        const QString versionArgument = toolName == QStringLiteral("yt-dlp")
            ? QStringLiteral("--version")
            : QStringLiteral("-version");
        m_process.setArguments({versionArgument});
        const QFileInfo executableFile(state.path);
        if (executableFile.exists() && executableFile.isFile()) {
            const QString toolDirectory = executableFile.absolutePath();
            m_process.setWorkingDirectory(toolDirectory);

            QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
            const QString systemPath = environment.value(QStringLiteral("PATH"));
            const QString pathPrefix = toolDirectory + QDir::listSeparator();
            if (!systemPath.startsWith(pathPrefix, Qt::CaseInsensitive)) {
                environment.insert(QStringLiteral("PATH"), pathPrefix + systemPath);
            }
            m_process.setProcessEnvironment(environment);
        }
        m_process.setProcessChannelMode(QProcess::MergedChannels);
        m_process.start();
        return;
    }

    m_currentTool.clear();
    m_checking = false;
    emit statusChanged();
#endif
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
