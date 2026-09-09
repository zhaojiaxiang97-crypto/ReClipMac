#include "DownloadManager.h"
#include "PlatformPaths.h"

#include <QDesktopServices>
#include <QDir>

DownloadManager::DownloadManager(QObject *parent)
    : QObject(parent)
    , m_androidEngine(this)
{
    m_downloadDirectory = PlatformPaths::defaultDownloadDirectory();
}

bool DownloadManager::busy() const { return false; }
QString DownloadManager::state() const { return m_state; }
QString DownloadManager::statusText() const { return m_statusText; }
double DownloadManager::progress() const { return m_progress; }
QString DownloadManager::speed() const { return m_speed; }
QString DownloadManager::eta() const { return m_eta; }
QString DownloadManager::outputPath() const { return m_outputPath; }
QString DownloadManager::errorMessage() const { return m_errorMessage; }
bool DownloadManager::canRetry() const { return false; }
QString DownloadManager::outputFormat() const { return m_outputFormat; }
QString DownloadManager::downloadDirectory() const { return m_downloadDirectory; }
QString DownloadManager::exportDirectoryUri() const { return m_exportDirectoryUri; }
QString DownloadManager::exportedUri() const { return m_exportedUri; }
PlatformStorage *DownloadManager::platformStorage() const { return m_platformStorage; }
QString DownloadManager::ytDlpPath() const { return m_ytDlpPath; }
QString DownloadManager::ffmpegPath() const { return m_ffmpegPath; }

void DownloadManager::setOutputFormat(const QString &format)
{
    const QString next = format.trimmed().toLower() == QStringLiteral("mp3")
        ? QStringLiteral("mp3") : QStringLiteral("mp4");
    if (m_outputFormat != next) {
        m_outputFormat = next;
        emit outputFormatChanged();
    }
}

void DownloadManager::setDownloadDirectory(const QString &path)
{
    const QString next = path.trimmed().isEmpty() ? PlatformPaths::defaultDownloadDirectory()
                                                   : QDir::cleanPath(path.trimmed());
    if (m_downloadDirectory != next) {
        m_downloadDirectory = next;
        emit downloadDirectoryChanged();
    }
}

void DownloadManager::setExportDirectoryUri(const QString &uri)
{
    if (m_exportDirectoryUri != uri.trimmed()) {
        m_exportDirectoryUri = uri.trimmed();
        emit exportDirectoryChanged();
    }
}

void DownloadManager::setPlatformStorage(PlatformStorage *storage)
{
    if (m_platformStorage != storage) {
        m_platformStorage = storage;
        emit platformStorageChanged();
    }
}

void DownloadManager::setYtDlpPath(const QString &path)
{
    if (m_ytDlpPath != path) {
        m_ytDlpPath = path;
        emit toolPathChanged();
    }
}

void DownloadManager::setFfmpegPath(const QString &path)
{
    if (m_ffmpegPath != path) {
        m_ffmpegPath = path;
        emit toolPathChanged();
    }
}

void DownloadManager::startVideoDownload(const QString &sourceUrl, const QString &formatId)
{
    startDownload(sourceUrl, formatId, QStringLiteral("mp4"));
}

void DownloadManager::startDownload(const QString &sourceUrl, const QString &formatId, const QString &format)
{
    m_sourceUrl = sourceUrl.trimmed();
    m_formatId = formatId.trimmed();
    setOutputFormat(format);
    m_state = QStringLiteral("idle");
    m_statusText = QStringLiteral("iOS 下载由传输队列处理");
    m_errorMessage.clear();
    emit stateChanged();
}

void DownloadManager::cancel() {}
void DownloadManager::retry() {}

void DownloadManager::openOutput()
{
    const QString path = m_outputPath.isEmpty() ? m_downloadDirectory : m_outputPath;
    if (m_platformStorage) {
        m_platformStorage->openFile(path, m_exportedUri, QStringLiteral("video/mp4"));
    } else {
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
}

void DownloadManager::shareOutput()
{
    if (m_platformStorage && !m_outputPath.isEmpty()) {
        m_platformStorage->shareFile(m_outputPath, m_exportedUri, QStringLiteral("video/mp4"));
    }
}

void DownloadManager::openDownloadDirectory()
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_downloadDirectory));
}
