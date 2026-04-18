#pragma once

#include <QObject>
#include <QString>

class QFile;
class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

class ReleaseDownloadService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool downloadActive READ downloadActive NOTIFY downloadStateChanged)
    Q_PROPERTY(bool downloadProgressKnown READ downloadProgressKnown NOTIFY downloadStateChanged)
    Q_PROPERTY(qreal downloadProgressFraction READ downloadProgressFraction NOTIFY downloadStateChanged)
    Q_PROPERTY(qint64 downloadedBytes READ downloadedBytes NOTIFY downloadStateChanged)
    Q_PROPERTY(qint64 downloadTotalBytes READ downloadTotalBytes NOTIFY downloadStateChanged)
    Q_PROPERTY(QString currentAssetName READ currentAssetName NOTIFY downloadStateChanged)
    Q_PROPERTY(QString downloadedFilePath READ downloadedFilePath NOTIFY downloadStateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY downloadStateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY downloadStateChanged)

public:
    explicit ReleaseDownloadService(QObject *parent = nullptr);
    ~ReleaseDownloadService() override;

    bool downloadActive() const;
    bool downloadProgressKnown() const;
    qreal downloadProgressFraction() const;
    qint64 downloadedBytes() const;
    qint64 downloadTotalBytes() const;
    QString currentAssetName() const;
    QString downloadedFilePath() const;
    QString statusText() const;
    QString lastError() const;

    Q_INVOKABLE void downloadReleaseAsset(const QString &downloadUrl, const QString &assetName);
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE void clearCompletedDownload();

signals:
    void downloadStateChanged();
    void downloadFinished(bool ok);

private:
    void resetDownloadState();
    void setStatusText(const QString &text);
    void setLastError(const QString &text);
    void setDownloadedFilePath(const QString &path);
    QString ensureDownloadDirectory(QString &errorText) const;
    QString targetFilePathForAsset(const QString &assetName, const QString &downloadDirectory) const;
    void cleanupPartialFile();
    void finishWithError(const QString &errorText);
    void finalizeDownload();
    void updateProgress(qint64 bytesReceived, qint64 bytesTotal);
    bool startDebugDownloadSimulation(const QUrl &url, const QString &assetName);
    void stopDebugDownloadSimulation();
    void advanceDebugDownloadSimulation();

    QNetworkAccessManager *m_networkAccessManager = nullptr;
    QNetworkReply *m_activeReply = nullptr;
    QFile *m_outputFile = nullptr;
    QTimer *m_debugDownloadTimer = nullptr;
    bool m_downloadActive = false;
    bool m_downloadProgressKnown = false;
    bool m_debugDownloadShouldFail = false;
    qreal m_downloadProgressFraction = 0.0;
    qint64 m_downloadedBytes = 0;
    qint64 m_downloadTotalBytes = 0;
    QString m_currentAssetName;
    QString m_downloadedFilePath;
    QString m_statusText;
    QString m_lastError;
    QString m_partialFilePath;
    QString m_finalFilePath;
};
