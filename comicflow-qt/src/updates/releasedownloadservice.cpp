#include "updates/releasedownloadservice.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

namespace {

constexpr auto kRepositoryUrl = "https://github.com/nikolayverin/comic-pile";
constexpr auto kDownloadFolderName = "ComicPile/updates";
constexpr auto kDebugDownloadScheme = "comicpile-debug-download";

QString normalizedAssetFileName(const QString &assetName)
{
    QString normalized = QFileInfo(assetName.trimmed()).fileName();
    if (normalized.isEmpty()) {
        normalized = QStringLiteral("Comic-Pile-update.zip");
    }
    return normalized;
}

QString noDownloadLinkErrorText()
{
    return QStringLiteral("This release doesn't provide a downloadable update package.");
}

QString invalidDownloadLinkErrorText()
{
    return QStringLiteral("The update download link is invalid.");
}

QString noTemporaryFolderErrorText()
{
    return QStringLiteral("Comic Pile couldn't access a temporary folder for downloading the update.");
}

QString createTemporaryFolderErrorText()
{
    return QStringLiteral("Comic Pile couldn't create a temporary folder for the update download.");
}

QString createTemporaryFileErrorText()
{
    return QStringLiteral("Comic Pile couldn't create a temporary file for the downloaded update package.");
}

QString writeDownloadedFileErrorText()
{
    return QStringLiteral("Comic Pile couldn't save the downloaded update file to the temporary folder.");
}

QString finalizeDownloadedFileErrorText()
{
    return QStringLiteral("Comic Pile couldn't finalize the downloaded update package in the temporary folder.");
}

QString canceledDownloadErrorText()
{
    return QStringLiteral("The update download was canceled.");
}

QString httpStatusDownloadErrorText(int statusCode)
{
    if (statusCode == 404) {
        return QStringLiteral("The update package couldn't be found on the update server.");
    }
    if (statusCode >= 500 && statusCode < 600) {
        return QStringLiteral("The update server returned an error while downloading the package.");
    }
    return QStringLiteral("The update server couldn't provide the download package right now.");
}

QString networkDownloadErrorText(QNetworkReply::NetworkError errorCode)
{
    switch (errorCode) {
    case QNetworkReply::ConnectionRefusedError:
        return QStringLiteral("The update server refused the connection.");
    case QNetworkReply::RemoteHostClosedError:
        return QStringLiteral("The update server closed the connection before the download finished.");
    case QNetworkReply::HostNotFoundError:
        return QStringLiteral("Comic Pile couldn't reach the update server.");
    case QNetworkReply::TimeoutError:
        return QStringLiteral("The update download timed out before it could finish.");
    case QNetworkReply::SslHandshakeFailedError:
        return QStringLiteral("A secure connection to the update server couldn't be established.");
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::NetworkSessionFailedError:
        return QStringLiteral("The update download failed because the network connection became unavailable.");
    case QNetworkReply::ContentNotFoundError:
        return QStringLiteral("The update package couldn't be found on the update server.");
    case QNetworkReply::ContentAccessDenied:
        return QStringLiteral("The update server denied access to the download package.");
    default:
        return QStringLiteral("The update download failed because the network request didn't complete. Please try again.");
    }
}

}

ReleaseDownloadService::ReleaseDownloadService(QObject *parent)
    : QObject(parent)
    , m_networkAccessManager(new QNetworkAccessManager(this))
    , m_debugDownloadTimer(new QTimer(this))
{
    m_debugDownloadTimer->setInterval(160);
    m_debugDownloadTimer->setSingleShot(false);
    connect(m_debugDownloadTimer, &QTimer::timeout, this, [this]() {
        advanceDebugDownloadSimulation();
    });
}

ReleaseDownloadService::~ReleaseDownloadService()
{
    cancelDownload();
    delete m_outputFile;
    m_outputFile = nullptr;
}

bool ReleaseDownloadService::downloadActive() const
{
    return m_downloadActive;
}

bool ReleaseDownloadService::downloadProgressKnown() const
{
    return m_downloadProgressKnown;
}

qreal ReleaseDownloadService::downloadProgressFraction() const
{
    return m_downloadProgressFraction;
}

qint64 ReleaseDownloadService::downloadedBytes() const
{
    return m_downloadedBytes;
}

qint64 ReleaseDownloadService::downloadTotalBytes() const
{
    return m_downloadTotalBytes;
}

QString ReleaseDownloadService::currentAssetName() const
{
    return m_currentAssetName;
}

QString ReleaseDownloadService::downloadedFilePath() const
{
    return m_downloadedFilePath;
}

QString ReleaseDownloadService::statusText() const
{
    return m_statusText;
}

QString ReleaseDownloadService::lastError() const
{
    return m_lastError;
}

void ReleaseDownloadService::downloadReleaseAsset(const QString &downloadUrl, const QString &assetName)
{
    const QString normalizedUrl = QString(downloadUrl).trimmed();
    const QString normalizedAssetName = normalizedAssetFileName(assetName);
    if (normalizedUrl.isEmpty()) {
        finishWithError(noDownloadLinkErrorText());
        emit downloadFinished(false);
        return;
    }

    const QUrl url(normalizedUrl);
    if (!url.isValid() || url.scheme().isEmpty()) {
        finishWithError(invalidDownloadLinkErrorText());
        emit downloadFinished(false);
        return;
    }

    cancelDownload();
    clearCompletedDownload();
    resetDownloadState();

    if (startDebugDownloadSimulation(url, normalizedAssetName)) {
        return;
    }

    QString directoryError;
    const QString downloadDirectory = ensureDownloadDirectory(directoryError);
    if (downloadDirectory.isEmpty()) {
        finishWithError(directoryError);
        emit downloadFinished(false);
        return;
    }

    m_currentAssetName = normalizedAssetName;
    m_finalFilePath = targetFilePathForAsset(normalizedAssetName, downloadDirectory);
    m_partialFilePath = m_finalFilePath + QStringLiteral(".part");
    QFile::remove(m_partialFilePath);

    delete m_outputFile;
    m_outputFile = new QFile(m_partialFilePath, this);
    if (!m_outputFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        finishWithError(createTemporaryFileErrorText());
        emit downloadFinished(false);
        return;
    }

    m_downloadActive = true;
    m_statusText = QStringLiteral("Downloading update package...");
    emit downloadStateChanged();

    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/octet-stream");
    request.setHeader(
        QNetworkRequest::UserAgentHeader,
        QStringLiteral("Comic Pile update download (+%1)").arg(QString::fromLatin1(kRepositoryUrl))
    );

    m_activeReply = m_networkAccessManager->get(request);
    connect(m_activeReply, &QNetworkReply::readyRead, this, [this]() {
        if (!m_activeReply || !m_outputFile) {
            return;
        }
        const QByteArray chunk = m_activeReply->readAll();
        if (chunk.isEmpty()) {
            return;
        }
        if (m_outputFile->write(chunk) != chunk.size()) {
            finishWithError(writeDownloadedFileErrorText());
            emit downloadFinished(false);
        }
    });
    connect(m_activeReply, &QNetworkReply::downloadProgress, this, [this](qint64 bytesReceived, qint64 bytesTotal) {
        updateProgress(bytesReceived, bytesTotal);
    });
    connect(m_activeReply, &QNetworkReply::finished, this, [this]() {
        if (!m_activeReply) {
            return;
        }

        QNetworkReply *reply = m_activeReply;
        m_activeReply = nullptr;
        const QNetworkReply::NetworkError errorCode = reply->error();
        const QString errorText = reply->errorString().trimmed();
        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();

        if (!m_downloadActive) {
            return;
        }

        if (errorCode == QNetworkReply::OperationCanceledError) {
            finishWithError(canceledDownloadErrorText());
            emit downloadFinished(false);
            return;
        }

        if (errorCode != QNetworkReply::NoError) {
            Q_UNUSED(errorText)
            finishWithError(networkDownloadErrorText(errorCode));
            emit downloadFinished(false);
            return;
        }

        if (statusCode < 200 || statusCode >= 300) {
            finishWithError(httpStatusDownloadErrorText(statusCode));
            emit downloadFinished(false);
            return;
        }

        finalizeDownload();
    });
}

void ReleaseDownloadService::cancelDownload()
{
    stopDebugDownloadSimulation();

    if (m_activeReply) {
        QNetworkReply *reply = m_activeReply;
        m_activeReply = nullptr;
        reply->abort();
        reply->deleteLater();
    }

    if (m_outputFile) {
        if (m_outputFile->isOpen()) {
            m_outputFile->close();
        }
        delete m_outputFile;
        m_outputFile = nullptr;
    }

    cleanupPartialFile();
    if (m_downloadActive) {
        m_downloadActive = false;
        if (m_statusText != QStringLiteral("Update download was canceled.")) {
            m_statusText = QStringLiteral("Update download was canceled.");
        }
        emit downloadStateChanged();
    }
}

void ReleaseDownloadService::clearCompletedDownload()
{
    setDownloadedFilePath({});
    if (!m_statusText.startsWith(QStringLiteral("Update package downloaded"))) {
        return;
    }
    setStatusText({});
}

void ReleaseDownloadService::resetDownloadState()
{
    m_downloadActive = false;
    m_downloadProgressKnown = false;
    m_downloadProgressFraction = 0.0;
    m_downloadedBytes = 0;
    m_downloadTotalBytes = 0;
    m_currentAssetName.clear();
    m_lastError.clear();
    m_statusText.clear();
    m_partialFilePath.clear();
    m_finalFilePath.clear();
    m_debugDownloadShouldFail = false;
}

void ReleaseDownloadService::setStatusText(const QString &text)
{
    if (m_statusText == text) {
        return;
    }
    m_statusText = text;
    emit downloadStateChanged();
}

void ReleaseDownloadService::setLastError(const QString &text)
{
    if (m_lastError == text) {
        return;
    }
    m_lastError = text;
    emit downloadStateChanged();
}

void ReleaseDownloadService::setDownloadedFilePath(const QString &path)
{
    if (m_downloadedFilePath == path) {
        return;
    }
    m_downloadedFilePath = path;
    emit downloadStateChanged();
}

QString ReleaseDownloadService::ensureDownloadDirectory(QString &errorText) const
{
    const QString tempRoot = QDir::tempPath();
    if (tempRoot.isEmpty()) {
        errorText = noTemporaryFolderErrorText();
        return {};
    }

    const QString downloadDirectory = QDir(tempRoot).filePath(QString::fromLatin1(kDownloadFolderName));
    if (!QDir().mkpath(downloadDirectory)) {
        errorText = createTemporaryFolderErrorText();
        return {};
    }
    return downloadDirectory;
}

QString ReleaseDownloadService::targetFilePathForAsset(const QString &assetName, const QString &downloadDirectory) const
{
    return QDir(downloadDirectory).filePath(normalizedAssetFileName(assetName));
}

void ReleaseDownloadService::cleanupPartialFile()
{
    if (!m_partialFilePath.isEmpty()) {
        QFile::remove(m_partialFilePath);
    }
}

void ReleaseDownloadService::finishWithError(const QString &errorText)
{
    if (m_outputFile) {
        if (m_outputFile->isOpen()) {
            m_outputFile->close();
        }
        delete m_outputFile;
        m_outputFile = nullptr;
    }

    cleanupPartialFile();
    m_downloadActive = false;
    m_downloadProgressKnown = false;
    m_downloadProgressFraction = 0.0;
    m_downloadedBytes = 0;
    m_downloadTotalBytes = 0;
    setDownloadedFilePath({});
    setStatusText({});
    setLastError(errorText);
}

void ReleaseDownloadService::finalizeDownload()
{
    if (!m_outputFile) {
        finishWithError(finalizeDownloadedFileErrorText());
        emit downloadFinished(false);
        return;
    }

    if (m_outputFile->isOpen()) {
        m_outputFile->flush();
        m_outputFile->close();
    }
    delete m_outputFile;
    m_outputFile = nullptr;

    QFile::remove(m_finalFilePath);
    if (!QFile::rename(m_partialFilePath, m_finalFilePath)) {
        finishWithError(finalizeDownloadedFileErrorText());
        emit downloadFinished(false);
        return;
    }

    m_downloadActive = false;
    m_downloadProgressKnown = m_downloadTotalBytes > 0;
    m_downloadProgressFraction = 1.0;
    setLastError({});
    setDownloadedFilePath(m_finalFilePath);
    setStatusText(QStringLiteral("Update package downloaded to a temporary folder."));
    emit downloadStateChanged();
    emit downloadFinished(true);
}

void ReleaseDownloadService::updateProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    const bool progressKnown = bytesTotal > 0;
    const qreal progressFraction = progressKnown
        ? qBound<qreal>(0.0, qreal(bytesReceived) / qreal(bytesTotal), 1.0)
        : 0.0;

    bool changed = false;
    if (m_downloadProgressKnown != progressKnown) {
        m_downloadProgressKnown = progressKnown;
        changed = true;
    }
    if (m_downloadProgressFraction != progressFraction) {
        m_downloadProgressFraction = progressFraction;
        changed = true;
    }
    if (m_downloadedBytes != bytesReceived) {
        m_downloadedBytes = bytesReceived;
        changed = true;
    }
    if (m_downloadTotalBytes != bytesTotal) {
        m_downloadTotalBytes = bytesTotal;
        changed = true;
    }
    if (changed) {
        emit downloadStateChanged();
    }
}

bool ReleaseDownloadService::startDebugDownloadSimulation(const QUrl &url, const QString &assetName)
{
#if COMICPILE_FAST_DEV_BUILD_ENABLED
    if (url.scheme().compare(QString::fromLatin1(kDebugDownloadScheme), Qt::CaseInsensitive) != 0) {
        return false;
    }

    const QString mode = url.host().trimmed().toLower();
    if (mode != QStringLiteral("success") && mode != QStringLiteral("failure")) {
        finishWithError(invalidDownloadLinkErrorText());
        emit downloadFinished(false);
        return true;
    }

    m_currentAssetName = assetName;
    m_downloadActive = true;
    m_downloadProgressKnown = true;
    m_downloadProgressFraction = 0.0;
    m_downloadedBytes = 0;
    m_downloadTotalBytes = 10;
    m_debugDownloadShouldFail = mode == QStringLiteral("failure");
    m_statusText = QStringLiteral("Downloading update package...");
    emit downloadStateChanged();
    m_debugDownloadTimer->start();
    return true;
#else
    Q_UNUSED(url)
    Q_UNUSED(assetName)
    return false;
#endif
}

void ReleaseDownloadService::stopDebugDownloadSimulation()
{
    if (m_debugDownloadTimer && m_debugDownloadTimer->isActive()) {
        m_debugDownloadTimer->stop();
    }
    m_debugDownloadShouldFail = false;
}

void ReleaseDownloadService::advanceDebugDownloadSimulation()
{
    if (!m_downloadActive || !m_debugDownloadTimer || !m_debugDownloadTimer->isActive()) {
        return;
    }

    const qint64 nextBytes = qMin(m_downloadTotalBytes, m_downloadedBytes + 2);
    if (m_debugDownloadShouldFail && nextBytes >= m_downloadTotalBytes) {
        m_debugDownloadTimer->stop();
        finishWithError(networkDownloadErrorText(QNetworkReply::TimeoutError));
        emit downloadFinished(false);
        return;
    }

    updateProgress(nextBytes, m_downloadTotalBytes);
    if (nextBytes < m_downloadTotalBytes) {
        return;
    }

    m_debugDownloadTimer->stop();
    m_downloadActive = false;
    m_downloadProgressKnown = true;
    m_downloadProgressFraction = 1.0;
    setLastError({});
    setDownloadedFilePath(QStringLiteral("debug://downloaded/Comic-Pile-update.zip"));
    setStatusText(QStringLiteral("Debug update package download finished successfully."));
    emit downloadStateChanged();
    emit downloadFinished(true);
}
