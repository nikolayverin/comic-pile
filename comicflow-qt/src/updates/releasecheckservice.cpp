#include "updates/releasecheckservice.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QStringList>
#include <QUrl>

namespace {

constexpr auto kLatestReleaseApiUrl = "https://api.github.com/repos/nikolayverin/comic-pile/releases/latest";
constexpr auto kRepositoryUrl = "https://github.com/nikolayverin/comic-pile";
constexpr qint64 kAutoCheckIntervalMs = 24ll * 60ll * 60ll * 1000ll;
constexpr int kAutoCheckIntervalHours = 24;
constexpr auto kSettingsGroup = "UpdateFlow";
constexpr auto kLastCheckAttemptAtMsKey = "last_check_attempt_at_ms";
constexpr auto kLastSuccessfulCheckAtMsKey = "last_successful_check_at_ms";
constexpr auto kDismissedUpdateVersionKey = "dismissed_update_version";

QString normalizeReleaseVersionTag(const QString &tag)
{
    QString normalized = tag.trimmed();
    normalized.remove(QRegularExpression(QStringLiteral("^[vV]+")));
    return normalized.trimmed();
}

QVector<int> parseVersionParts(const QString &version)
{
    QVector<int> parts;
    const QString normalized = normalizeReleaseVersionTag(version);
    const QStringList tokens = normalized.split(QLatin1Char('.'), Qt::SkipEmptyParts);
    parts.reserve(tokens.size());
    for (const QString &token : tokens) {
        bool ok = false;
        const int value = token.toInt(&ok);
        parts.push_back(ok ? value : 0);
    }
    return parts;
}

bool isVersionNewer(const QString &candidateVersion, const QString &currentVersion)
{
    const QVector<int> candidateParts = parseVersionParts(candidateVersion);
    const QVector<int> currentParts = parseVersionParts(currentVersion);
    const int count = qMax(candidateParts.size(), currentParts.size());
    for (int index = 0; index < count; index += 1) {
        const int candidateValue = index < candidateParts.size() ? candidateParts.at(index) : 0;
        const int currentValue = index < currentParts.size() ? currentParts.at(index) : 0;
        if (candidateValue == currentValue) {
            continue;
        }
        return candidateValue > currentValue;
    }
    return false;
}

QString firstZipAssetName(const QJsonArray &assets, QString &downloadUrlOut)
{
    downloadUrlOut.clear();
    for (const QJsonValue &assetValue : assets) {
        const QJsonObject assetObject = assetValue.toObject();
        const QString name = assetObject.value(QStringLiteral("name")).toString().trimmed();
        const QString downloadUrl = assetObject.value(QStringLiteral("browser_download_url")).toString().trimmed();
        if (name.isEmpty() || downloadUrl.isEmpty()) {
            continue;
        }
        if (!name.endsWith(QStringLiteral(".zip"), Qt::CaseInsensitive)) {
            continue;
        }
        downloadUrlOut = downloadUrl;
        return name;
    }
    return {};
}

}

ReleaseCheckService::ReleaseCheckService(QObject *parent)
    : QObject(parent)
    , m_networkAccessManager(new QNetworkAccessManager(this))
{
    loadPersistedState();
}

ReleaseCheckService::~ReleaseCheckService()
{
    if (m_activeReply) {
        m_activeReply->abort();
    }
}

QString ReleaseCheckService::currentVersion() const
{
    return QCoreApplication::applicationVersion().trimmed();
}

bool ReleaseCheckService::checking() const
{
    return m_checking;
}

qint64 ReleaseCheckService::lastCheckAttemptAtMs() const
{
    return m_lastCheckAttemptAtMs;
}

qint64 ReleaseCheckService::lastSuccessfulCheckAtMs() const
{
    return m_lastSuccessfulCheckAtMs;
}

QString ReleaseCheckService::dismissedUpdateVersion() const
{
    return m_dismissedUpdateVersion;
}

bool ReleaseCheckService::autoCheckDue() const
{
    return shouldAutoCheckNow();
}

qint64 ReleaseCheckService::nextAutoCheckAtMs() const
{
    if (m_lastCheckAttemptAtMs < 1) {
        return 0;
    }
    return m_lastCheckAttemptAtMs + kAutoCheckIntervalMs;
}

int ReleaseCheckService::autoCheckIntervalHours() const
{
    return kAutoCheckIntervalHours;
}

bool ReleaseCheckService::hasReleaseInfo() const
{
    return m_hasReleaseInfo;
}

QString ReleaseCheckService::latestVersion() const
{
    return m_latestVersion;
}

QString ReleaseCheckService::latestTag() const
{
    return m_latestTag;
}

QString ReleaseCheckService::latestReleaseUrl() const
{
    return m_latestReleaseUrl;
}

QString ReleaseCheckService::latestReleaseName() const
{
    return m_latestReleaseName;
}

QString ReleaseCheckService::latestReleaseNotes() const
{
    return m_latestReleaseNotes;
}

QString ReleaseCheckService::latestPublishedAt() const
{
    return m_latestPublishedAt;
}

QString ReleaseCheckService::latestAssetName() const
{
    return m_latestAssetName;
}

QString ReleaseCheckService::latestAssetDownloadUrl() const
{
    return m_latestAssetDownloadUrl;
}

bool ReleaseCheckService::latestVersionIsNewer() const
{
    if (!m_hasReleaseInfo || m_latestVersion.isEmpty()) {
        return false;
    }
    return isVersionNewer(m_latestVersion, currentVersion());
}

QString ReleaseCheckService::lastError() const
{
    return m_lastError;
}

void ReleaseCheckService::checkLatestRelease()
{
    if (m_activeReply) {
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply = nullptr;
    }

    setLastError({});
    setChecking(true);
    storeLastCheckAttemptAtMs(QDateTime::currentMSecsSinceEpoch());

    QNetworkRequest request(QUrl(QString::fromLatin1(kLatestReleaseApiUrl)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    request.setHeader(
        QNetworkRequest::UserAgentHeader,
        QStringLiteral("Comic Pile/%1 (+%2)").arg(currentVersion(), QString::fromLatin1(kRepositoryUrl))
    );

    m_activeReply = m_networkAccessManager->get(request);
    connect(m_activeReply, &QNetworkReply::finished, this, [this]() {
        handleReplyFinished(m_activeReply);
    });
}

void ReleaseCheckService::checkLatestReleaseIfDue()
{
    if (!shouldAutoCheckNow()) {
        return;
    }
    checkLatestRelease();
}

bool ReleaseCheckService::shouldAutoCheckNow() const
{
    if (m_checking) {
        return false;
    }
    if (m_lastCheckAttemptAtMs < 1) {
        return true;
    }
    return QDateTime::currentMSecsSinceEpoch() >= (m_lastCheckAttemptAtMs + kAutoCheckIntervalMs);
}

void ReleaseCheckService::markUpdateDismissed(const QString &version)
{
    storeDismissedUpdateVersion(normalizeReleaseVersionTag(version));
}

void ReleaseCheckService::clearDismissedUpdateVersion()
{
    storeDismissedUpdateVersion({});
}

bool ReleaseCheckService::isVersionDismissed(const QString &version) const
{
    const QString normalizedVersion = normalizeReleaseVersionTag(version);
    return !normalizedVersion.isEmpty()
        && normalizedVersion.compare(m_dismissedUpdateVersion, Qt::CaseInsensitive) == 0;
}

void ReleaseCheckService::loadPersistedState()
{
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kSettingsGroup));
    m_lastCheckAttemptAtMs = settings.value(QString::fromLatin1(kLastCheckAttemptAtMsKey), 0).toLongLong();
    m_lastSuccessfulCheckAtMs = settings.value(QString::fromLatin1(kLastSuccessfulCheckAtMsKey), 0).toLongLong();
    m_dismissedUpdateVersion = normalizeReleaseVersionTag(
        settings.value(QString::fromLatin1(kDismissedUpdateVersionKey)).toString()
    );
    settings.endGroup();
}

void ReleaseCheckService::storeLastCheckAttemptAtMs(qint64 timestampMs)
{
    if (m_lastCheckAttemptAtMs == timestampMs) {
        return;
    }
    m_lastCheckAttemptAtMs = timestampMs;
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kSettingsGroup));
    settings.setValue(QString::fromLatin1(kLastCheckAttemptAtMsKey), m_lastCheckAttemptAtMs);
    settings.endGroup();
    emit updateStateChanged();
}

void ReleaseCheckService::storeLastSuccessfulCheckAtMs(qint64 timestampMs)
{
    if (m_lastSuccessfulCheckAtMs == timestampMs) {
        return;
    }
    m_lastSuccessfulCheckAtMs = timestampMs;
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kSettingsGroup));
    settings.setValue(QString::fromLatin1(kLastSuccessfulCheckAtMsKey), m_lastSuccessfulCheckAtMs);
    settings.endGroup();
    emit updateStateChanged();
}

void ReleaseCheckService::storeDismissedUpdateVersion(const QString &version)
{
    const QString normalizedVersion = normalizeReleaseVersionTag(version);
    if (m_dismissedUpdateVersion.compare(normalizedVersion, Qt::CaseInsensitive) == 0) {
        return;
    }
    m_dismissedUpdateVersion = normalizedVersion;
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kSettingsGroup));
    settings.setValue(QString::fromLatin1(kDismissedUpdateVersionKey), m_dismissedUpdateVersion);
    settings.endGroup();
    emit updateStateChanged();
}

void ReleaseCheckService::setChecking(bool checkingValue)
{
    if (m_checking == checkingValue) {
        return;
    }
    m_checking = checkingValue;
    emit checkingChanged();
}

void ReleaseCheckService::setLastError(const QString &errorText)
{
    if (m_lastError == errorText) {
        return;
    }
    m_lastError = errorText;
    emit lastErrorChanged();
}

void ReleaseCheckService::clearReleaseInfo()
{
    const bool changed = m_hasReleaseInfo
        || !m_latestVersion.isEmpty()
        || !m_latestTag.isEmpty()
        || !m_latestReleaseUrl.isEmpty()
        || !m_latestReleaseName.isEmpty()
        || !m_latestReleaseNotes.isEmpty()
        || !m_latestPublishedAt.isEmpty()
        || !m_latestAssetName.isEmpty()
        || !m_latestAssetDownloadUrl.isEmpty();

    m_hasReleaseInfo = false;
    m_latestVersion.clear();
    m_latestTag.clear();
    m_latestReleaseUrl.clear();
    m_latestReleaseName.clear();
    m_latestReleaseNotes.clear();
    m_latestPublishedAt.clear();
    m_latestAssetName.clear();
    m_latestAssetDownloadUrl.clear();

    if (changed) {
        emit releaseInfoChanged();
    }
}

void ReleaseCheckService::finishWithError(const QString &errorText)
{
    clearReleaseInfo();
    setLastError(errorText);
    setChecking(false);
    emit latestReleaseCheckFinished(false);
}

void ReleaseCheckService::applyParsedReleaseInfo(
    const QString &tag,
    const QString &version,
    const QString &releaseUrl,
    const QString &releaseName,
    const QString &releaseNotes,
    const QString &publishedAt,
    const QString &assetName,
    const QString &assetDownloadUrl
)
{
    m_hasReleaseInfo = true;
    m_latestTag = tag;
    m_latestVersion = version;
    m_latestReleaseUrl = releaseUrl;
    m_latestReleaseName = releaseName;
    m_latestReleaseNotes = releaseNotes;
    m_latestPublishedAt = publishedAt;
    m_latestAssetName = assetName;
    m_latestAssetDownloadUrl = assetDownloadUrl;
    emit releaseInfoChanged();
}

void ReleaseCheckService::handleReplyFinished(QNetworkReply *reply)
{
    if (!reply || reply != m_activeReply) {
        return;
    }

    m_activeReply = nullptr;

    const QByteArray payload = reply->readAll();
    const QNetworkReply::NetworkError networkError = reply->error();
    const QString networkErrorText = reply->errorString().trimmed();
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (networkError != QNetworkReply::NoError) {
        finishWithError(
            QStringLiteral("Failed to check the latest release: %1").arg(
                networkErrorText.isEmpty() ? QStringLiteral("Network request failed.") : networkErrorText
            )
        );
        return;
    }

    if (statusCode < 200 || statusCode >= 300) {
        finishWithError(
            QStringLiteral("Failed to check the latest release: GitHub returned HTTP %1.").arg(statusCode)
        );
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        finishWithError(QStringLiteral("Failed to parse the latest release response."));
        return;
    }

    const QJsonObject root = document.object();
    const QString tag = root.value(QStringLiteral("tag_name")).toString().trimmed();
    const QString version = normalizeReleaseVersionTag(tag);
    const QString releaseUrl = root.value(QStringLiteral("html_url")).toString().trimmed();
    const QString releaseName = root.value(QStringLiteral("name")).toString().trimmed();
    const QString releaseNotes = root.value(QStringLiteral("body")).toString();
    const QString publishedAt = root.value(QStringLiteral("published_at")).toString().trimmed();

    if (tag.isEmpty() || version.isEmpty() || releaseUrl.isEmpty()) {
        finishWithError(QStringLiteral("Latest release response is missing required fields."));
        return;
    }

    QString assetDownloadUrl;
    const QString assetName = firstZipAssetName(root.value(QStringLiteral("assets")).toArray(), assetDownloadUrl);

    setLastError({});
    applyParsedReleaseInfo(
        tag,
        version,
        releaseUrl,
        releaseName,
        releaseNotes,
        publishedAt,
        assetName,
        assetDownloadUrl
    );
    storeLastSuccessfulCheckAtMs(QDateTime::currentMSecsSinceEpoch());
    setChecking(false);
    emit latestReleaseCheckFinished(true);
}
