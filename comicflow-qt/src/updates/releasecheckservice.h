#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;

class ReleaseCheckService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)
    Q_PROPERTY(qint64 lastCheckAttemptAtMs READ lastCheckAttemptAtMs NOTIFY updateStateChanged)
    Q_PROPERTY(qint64 lastSuccessfulCheckAtMs READ lastSuccessfulCheckAtMs NOTIFY updateStateChanged)
    Q_PROPERTY(QString dismissedUpdateVersion READ dismissedUpdateVersion NOTIFY updateStateChanged)
    Q_PROPERTY(QString pendingUpdatePromptVersion READ pendingUpdatePromptVersion NOTIFY updateStateChanged)
    Q_PROPERTY(bool autoCheckDue READ autoCheckDue NOTIFY updateStateChanged)
    Q_PROPERTY(qint64 nextAutoCheckAtMs READ nextAutoCheckAtMs NOTIFY updateStateChanged)
    Q_PROPERTY(int autoCheckIntervalHours READ autoCheckIntervalHours CONSTANT)
    Q_PROPERTY(bool hasReleaseInfo READ hasReleaseInfo NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestTag READ latestTag NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestReleaseUrl READ latestReleaseUrl NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestReleaseName READ latestReleaseName NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestReleaseNotes READ latestReleaseNotes NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestPublishedAt READ latestPublishedAt NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestAssetName READ latestAssetName NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString latestAssetDownloadUrl READ latestAssetDownloadUrl NOTIFY releaseInfoChanged)
    Q_PROPERTY(bool latestVersionIsNewer READ latestVersionIsNewer NOTIFY releaseInfoChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit ReleaseCheckService(QObject *parent = nullptr);
    ~ReleaseCheckService() override;

    QString currentVersion() const;
    bool checking() const;
    qint64 lastCheckAttemptAtMs() const;
    qint64 lastSuccessfulCheckAtMs() const;
    QString dismissedUpdateVersion() const;
    QString pendingUpdatePromptVersion() const;
    bool autoCheckDue() const;
    qint64 nextAutoCheckAtMs() const;
    int autoCheckIntervalHours() const;
    bool hasReleaseInfo() const;
    QString latestVersion() const;
    QString latestTag() const;
    QString latestReleaseUrl() const;
    QString latestReleaseName() const;
    QString latestReleaseNotes() const;
    QString latestPublishedAt() const;
    QString latestAssetName() const;
    QString latestAssetDownloadUrl() const;
    bool latestVersionIsNewer() const;
    QString lastError() const;

    Q_INVOKABLE void checkLatestRelease();
    Q_INVOKABLE void checkLatestReleaseIfDue();
    Q_INVOKABLE bool shouldAutoCheckNow() const;
    Q_INVOKABLE bool shouldShowPendingUpdatePrompt() const;
    Q_INVOKABLE void markUpdateDismissed(const QString &version);
    Q_INVOKABLE void clearDismissedUpdateVersion();
    Q_INVOKABLE void clearPendingUpdatePrompt();
    Q_INVOKABLE bool isVersionDismissed(const QString &version) const;
    Q_INVOKABLE void debugLoadMockAvailableUpdate();
    Q_INVOKABLE void debugLoadMockFailedDownloadUpdate();

signals:
    void checkingChanged();
    void updateStateChanged();
    void releaseInfoChanged();
    void lastErrorChanged();
    void latestReleaseCheckFinished(bool ok);

private:
    void loadPersistedState();
    void startLatestReleaseCheck(bool autoDueCheck);
    void storeLastCheckAttemptAtMs(qint64 timestampMs);
    void storeLastSuccessfulCheckAtMs(qint64 timestampMs);
    void storeDismissedUpdateVersion(const QString &version);
    void storePendingUpdatePromptVersion(const QString &version);
    void storePersistedReleaseInfo();
    void clearPersistedReleaseInfo();
    void setChecking(bool checking);
    void setLastError(const QString &errorText);
    void clearReleaseInfo();
    void finishWithError(const QString &errorText);
    void applyParsedReleaseInfo(
        const QString &tag,
        const QString &version,
        const QString &releaseUrl,
        const QString &releaseName,
        const QString &releaseNotes,
        const QString &publishedAt,
        const QString &assetName,
        const QString &assetDownloadUrl
    );
    void handleReplyFinished(QNetworkReply *reply);

    QNetworkAccessManager *m_networkAccessManager = nullptr;
    QNetworkReply *m_activeReply = nullptr;
    bool m_checking = false;
    bool m_activeCheckIsAutoDue = false;
    qint64 m_lastCheckAttemptAtMs = 0;
    qint64 m_lastSuccessfulCheckAtMs = 0;
    QString m_dismissedUpdateVersion;
    QString m_pendingUpdatePromptVersion;
    bool m_hasReleaseInfo = false;
    QString m_latestVersion;
    QString m_latestTag;
    QString m_latestReleaseUrl;
    QString m_latestReleaseName;
    QString m_latestReleaseNotes;
    QString m_latestPublishedAt;
    QString m_latestAssetName;
    QString m_latestAssetDownloadUrl;
    QString m_lastError;
};
