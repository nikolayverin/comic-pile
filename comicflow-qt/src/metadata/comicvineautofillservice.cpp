#include "metadata/comicvineautofillservice.h"

#include <cmath>
#include <limits>
#include <QCoreApplication>
#include <QDate>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QProcess>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

namespace {

struct ComicVineAutofillCacheState {
    QString dataRoot;
    bool loaded = false;
    bool dirty = false;
    QHash<QString, QVariantMap> patchCache;
    QSet<QString> missCache;
};

struct ComicVineAutofillResult {
    bool attempted = false;
    bool fromCache = false;
    QVariantMap values;
    QString error;
};

QString readTrimmedTextFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    const QString raw = QString::fromUtf8(file.readAll()).trimmed();
    if (raw.isEmpty()) return {};
    const QStringList lines = raw.split(QRegularExpression("[\\r\\n]+"), Qt::SkipEmptyParts);
    if (lines.isEmpty()) return {};
    return lines.first().trimmed();
}

QString normalizeMatchKey(const QString &value)
{
    QString text = value.toLower().trimmed();
    if (text.isEmpty()) return {};
    text.replace(QRegularExpression("[^a-z0-9]+"), QString(" "));
    return text.simplified();
}

QString stripHtmlToPlainText(const QString &htmlText)
{
    QString text = htmlText;
    text.remove(QRegularExpression("(?is)<script\\b[^>]*>.*?</script>"));
    text.remove(QRegularExpression("(?is)<style\\b[^>]*>.*?</style>"));
    text.remove(QRegularExpression("(?is)<[^>]+>"));
    text.replace(QStringLiteral("&nbsp;"), QStringLiteral(" "));
    text.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    text.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
    text.replace(QStringLiteral("&#39;"), QStringLiteral("'"));
    text.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
    text.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    return text.simplified();
}

QString quotePowerShellSingleQuoted(const QString &value)
{
    QString escaped = value;
    escaped.replace(QStringLiteral("'"), QStringLiteral("''"));
    return QStringLiteral("'%1'").arg(escaped);
}

QString comicVineRuntimeDirPath()
{
    return QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral(".runtime"));
}

bool moveFileToAppRuntimeIfNeeded(const QString &sourcePath, const QString &targetPath)
{
    const QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        return false;
    }

    const QFileInfo targetInfo(targetPath);
    QDir().mkpath(targetInfo.absolutePath());

    if (QFileInfo::exists(targetPath)) {
        QFile::remove(sourceInfo.absoluteFilePath());
        return true;
    }

    if (QFile::rename(sourceInfo.absoluteFilePath(), targetPath)) {
        return true;
    }

    if (QFile::copy(sourceInfo.absoluteFilePath(), targetPath)) {
        QFile::remove(sourceInfo.absoluteFilePath());
        return true;
    }

    return false;
}

void migrateLegacyComicVineApiKeyFile(const QString &dataRoot)
{
    const QString targetPath = QDir(comicVineRuntimeDirPath()).filePath(QStringLiteral("comicvine_api_key.txt"));
    if (QFileInfo::exists(targetPath)) {
        return;
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList legacyPaths = {
        QDir(dataRoot).filePath(QStringLiteral(".runtime/comicvine_api_key.txt")),
        QDir(dataRoot).filePath(QStringLiteral(".runtime/comicvine.key")),
        QDir(dataRoot).filePath(QStringLiteral("comicvine_api_key.txt")),
        QDir(appDir).filePath(QStringLiteral("comicvine_api_key.txt")),
        QDir(appDir).filePath(QStringLiteral("comicvine.key"))
    };

    for (const QString &legacyPath : legacyPaths) {
        if (moveFileToAppRuntimeIfNeeded(legacyPath, targetPath)) {
            return;
        }
    }
}

void migrateLegacyComicVineCacheFile(const QString &dataRoot)
{
    const QString targetPath = QDir(comicVineRuntimeDirPath()).filePath(QStringLiteral("comicvine_autofill_cache.json"));
    if (QFileInfo::exists(targetPath)) {
        return;
    }

    const QString legacyPath = QDir(dataRoot).filePath(QStringLiteral(".runtime/comicvine_autofill_cache.json"));
    moveFileToAppRuntimeIfNeeded(legacyPath, targetPath);
}

QString resolveComicVineApiKey(const QString &dataRoot)
{
    migrateLegacyComicVineApiKeyFile(dataRoot);
    return readTrimmedTextFile(
        QDir(comicVineRuntimeDirPath()).filePath(QStringLiteral("comicvine_api_key.txt"))
    );
}

QString preferredComicVineApiKeyFilePath(const QString &dataRoot)
{
    Q_UNUSED(dataRoot)
    return QDir(comicVineRuntimeDirPath()).filePath(QStringLiteral("comicvine_api_key.txt"));
}

QString comicVineAutofillCachePath(const QString &dataRoot)
{
    migrateLegacyComicVineCacheFile(dataRoot);
    return QDir(comicVineRuntimeDirPath()).filePath(QStringLiteral("comicvine_autofill_cache.json"));
}

ComicVineAutofillCacheState &comicVineAutofillCacheState()
{
    static ComicVineAutofillCacheState state;
    return state;
}

void ensureComicVineAutofillCacheLoaded(const QString &dataRoot)
{
    ComicVineAutofillCacheState &state = comicVineAutofillCacheState();
    const QString normalizedRoot = QDir::cleanPath(dataRoot);
    if (state.loaded && state.dataRoot == normalizedRoot) return;

    state.dataRoot = normalizedRoot;
    state.loaded = true;
    state.dirty = false;
    state.patchCache.clear();
    state.missCache.clear();

    const QString cachePath = comicVineAutofillCachePath(normalizedRoot);
    QFile file(cachePath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) return;

    const QJsonObject root = document.object();
    const QJsonObject patchesObject = root.value(QStringLiteral("patches")).toObject();
    for (auto it = patchesObject.constBegin(); it != patchesObject.constEnd(); ++it) {
        if (!it.value().isObject()) continue;
        state.patchCache.insert(it.key(), it.value().toObject().toVariantMap());
    }

    const QJsonArray missesArray = root.value(QStringLiteral("misses")).toArray();
    for (const QJsonValue &value : missesArray) {
        const QString missKey = value.toString().trimmed();
        if (missKey.isEmpty()) continue;
        state.missCache.insert(missKey);
    }
}

void saveComicVineAutofillCacheIfDirty()
{
    ComicVineAutofillCacheState &state = comicVineAutofillCacheState();
    if (!state.loaded || !state.dirty || state.dataRoot.isEmpty()) return;

    const QString cachePath = comicVineAutofillCachePath(state.dataRoot);
    const QFileInfo cacheInfo(cachePath);
    QDir().mkpath(cacheInfo.absolutePath());

    QJsonObject patchesObject;
    for (auto it = state.patchCache.constBegin(); it != state.patchCache.constEnd(); ++it) {
        patchesObject.insert(it.key(), QJsonObject::fromVariantMap(it.value()));
    }

    QJsonArray missesArray;
    for (const QString &missKey : state.missCache) {
        missesArray.push_back(missKey);
    }

    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("patches"), patchesObject);
    root.insert(QStringLiteral("misses"), missesArray);

    QSaveFile file(cachePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return;
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!file.commit()) return;

    state.dirty = false;
}

QDate parseComicVineDate(const QString &raw)
{
    const QString trimmed = raw.trimmed();
    if (trimmed.isEmpty()) return {};

    const QString token = trimmed.left(10);
    const QDate date = QDate::fromString(token, QStringLiteral("yyyy-MM-dd"));
    if (date.isValid()) return date;
    return QDate::fromString(trimmed, Qt::ISODate);
}

QJsonArray ensureArrayResults(const QJsonValue &value)
{
    if (value.isArray()) return value.toArray();
    if (value.isObject()) {
        QJsonArray out;
        out.push_back(value.toObject());
        return out;
    }
    return {};
}

int scoreComicVineIssueCandidate(
    const QJsonObject &issue,
    const QString &targetSeriesKey,
    const QString &targetIssueNumber,
    int targetYear
)
{
    const QString issueNumber = issue.value(QStringLiteral("issue_number")).toString().trimmed();
    const QString seriesName = issue.value(QStringLiteral("volume")).toObject().value(QStringLiteral("name")).toString().trimmed();
    const QString issueNumberKey = normalizeMatchKey(issueNumber);
    const QString targetIssueKey = normalizeMatchKey(targetIssueNumber);
    const QString seriesKey = normalizeMatchKey(seriesName);

    int score = 0;
    if (!targetIssueKey.isEmpty() && issueNumberKey == targetIssueKey) {
        score += 120;
    } else if (!targetIssueKey.isEmpty() && issueNumber.contains(targetIssueNumber, Qt::CaseInsensitive)) {
        score += 40;
    }

    if (!targetSeriesKey.isEmpty() && seriesKey == targetSeriesKey) {
        score += 120;
    } else if (!targetSeriesKey.isEmpty()
               && (seriesKey.contains(targetSeriesKey) || targetSeriesKey.contains(seriesKey))) {
        score += 50;
    }

    if (targetYear > 0) {
        const QDate coverDate = parseComicVineDate(issue.value(QStringLiteral("cover_date")).toString());
        if (coverDate.isValid()) {
            const int delta = std::abs(coverDate.year() - targetYear);
            if (delta == 0) score += 15;
            else if (delta == 1) score += 8;
        }
    }

    return score;
}

bool isComicVineIssueCandidateAcceptable(
    const QJsonObject &issue,
    const QString &targetSeriesKey,
    const QString &targetIssueNumber,
    int targetYear
)
{
    const QString issueNumber = issue.value(QStringLiteral("issue_number")).toString().trimmed();
    const QString issueNumberKey = normalizeMatchKey(issueNumber);
    const QString targetIssueKey = normalizeMatchKey(targetIssueNumber);
    if (targetIssueKey.isEmpty() || issueNumberKey != targetIssueKey) return false;

    const QString seriesName = issue.value(QStringLiteral("volume")).toObject().value(QStringLiteral("name")).toString().trimmed();
    const QString seriesKey = normalizeMatchKey(seriesName);
    const bool seriesMatches = !targetSeriesKey.isEmpty()
        && (seriesKey == targetSeriesKey
            || seriesKey.contains(targetSeriesKey)
            || targetSeriesKey.contains(seriesKey));
    if (!seriesMatches) return false;

    if (targetYear > 0) {
        const QDate coverDate = parseComicVineDate(issue.value(QStringLiteral("cover_date")).toString());
        if (!coverDate.isValid()) return false;
        if (std::abs(coverDate.year() - targetYear) > 1) return false;
    }

    return true;
}

bool isFetchedComicVineDetailAcceptable(
    const QVariantMap &values,
    const QString &targetSeriesKey,
    const QString &targetIssueNumber,
    int targetYear
)
{
    const QString fetchedIssueKey = normalizeMatchKey(values.value(QStringLiteral("issueNumber")).toString());
    const QString targetIssueKey = normalizeMatchKey(targetIssueNumber);
    if (targetIssueKey.isEmpty() || fetchedIssueKey != targetIssueKey) return false;

    const QString fetchedSeriesKey = normalizeMatchKey(values.value(QStringLiteral("series")).toString());
    const bool seriesMatches = !targetSeriesKey.isEmpty()
        && (fetchedSeriesKey == targetSeriesKey
            || fetchedSeriesKey.contains(targetSeriesKey)
            || targetSeriesKey.contains(fetchedSeriesKey));
    if (!seriesMatches) return false;

    if (targetYear > 0) {
        const int fetchedYear = values.value(QStringLiteral("year")).toInt();
        if (fetchedYear < 1 || std::abs(fetchedYear - targetYear) > 1) return false;
    }

    return true;
}

QStringList splitRoleTokens(const QString &roleText)
{
    const QString normalized = roleText.toLower().trimmed();
    if (normalized.isEmpty()) return {};
    return normalized.split(QRegularExpression("[,;/|]+"), Qt::SkipEmptyParts);
}

void appendUniqueName(QHash<QString, QStringList> &roleNames, const QString &roleKey, const QString &name)
{
    const QString normalizedName = name.trimmed();
    if (normalizedName.isEmpty()) return;
    QStringList &list = roleNames[roleKey];
    for (const QString &existing : list) {
        if (existing.compare(normalizedName, Qt::CaseInsensitive) == 0) return;
    }
    list.push_back(normalizedName);
}

void mapComicVinePersonCredits(const QJsonArray &credits, QVariantMap &values)
{
    QHash<QString, QStringList> roleNames;

    for (const QJsonValue &item : credits) {
        if (!item.isObject()) continue;
        const QJsonObject person = item.toObject();
        const QString personName = person.value(QStringLiteral("name")).toString().trimmed();
        if (personName.isEmpty()) continue;

        QString roleText = person.value(QStringLiteral("role")).toString().trimmed();
        if (roleText.isEmpty()) {
            roleText = person.value(QStringLiteral("roles")).toString().trimmed();
        }
        const QStringList roles = splitRoleTokens(roleText);
        if (roles.isEmpty()) continue;

        for (const QString &tokenRaw : roles) {
            const QString token = tokenRaw.trimmed();
            if (token.isEmpty()) continue;

            if (token.contains(QStringLiteral("writer"))) appendUniqueName(roleNames, QStringLiteral("writer"), personName);
            if (token.contains(QStringLiteral("pencil")) || token.contains(QStringLiteral("artist"))) appendUniqueName(roleNames, QStringLiteral("penciller"), personName);
            if (token.contains(QStringLiteral("inker"))) appendUniqueName(roleNames, QStringLiteral("inker"), personName);
            if (token.contains(QStringLiteral("color"))) appendUniqueName(roleNames, QStringLiteral("colorist"), personName);
            if (token.contains(QStringLiteral("letter"))) appendUniqueName(roleNames, QStringLiteral("letterer"), personName);
            if (token.contains(QStringLiteral("editor"))) appendUniqueName(roleNames, QStringLiteral("editor"), personName);
            if (token.contains(QStringLiteral("cover"))) appendUniqueName(roleNames, QStringLiteral("coverArtist"), personName);
        }
    }

    auto joinRole = [&](const QString &roleKey, const QString &targetKey) {
        const QStringList names = roleNames.value(roleKey);
        if (names.isEmpty()) return;
        values.insert(targetKey, names.join(QStringLiteral(", ")));
    };

    joinRole(QStringLiteral("writer"), QStringLiteral("writer"));
    joinRole(QStringLiteral("penciller"), QStringLiteral("penciller"));
    joinRole(QStringLiteral("inker"), QStringLiteral("inker"));
    joinRole(QStringLiteral("colorist"), QStringLiteral("colorist"));
    joinRole(QStringLiteral("letterer"), QStringLiteral("letterer"));
    joinRole(QStringLiteral("editor"), QStringLiteral("editor"));
    joinRole(QStringLiteral("coverArtist"), QStringLiteral("coverArtist"));
}

QVariantMap extractComicVineMetadataValues(const QJsonObject &detail)
{
    QVariantMap values;

    const QString seriesName = detail.value(QStringLiteral("volume")).toObject().value(QStringLiteral("name")).toString().trimmed();
    const QString issueNumber = detail.value(QStringLiteral("issue_number")).toString().trimmed();
    const QString title = detail.value(QStringLiteral("name")).toString().trimmed();
    const QString publisher = detail.value(QStringLiteral("publisher")).toObject().value(QStringLiteral("name")).toString().trimmed();
    const QString deck = detail.value(QStringLiteral("deck")).toString().trimmed();
    const QString description = stripHtmlToPlainText(detail.value(QStringLiteral("description")).toString());

    if (!seriesName.isEmpty()) values.insert(QStringLiteral("series"), seriesName);
    if (!issueNumber.isEmpty()) values.insert(QStringLiteral("issueNumber"), issueNumber);
    if (!title.isEmpty()) values.insert(QStringLiteral("title"), title);
    if (!publisher.isEmpty()) values.insert(QStringLiteral("publisher"), publisher);

    const QString summary = !deck.isEmpty() ? deck : description;
    if (!summary.isEmpty()) values.insert(QStringLiteral("summary"), summary);

    QDate coverDate = parseComicVineDate(detail.value(QStringLiteral("cover_date")).toString());
    if (!coverDate.isValid()) {
        coverDate = parseComicVineDate(detail.value(QStringLiteral("store_date")).toString());
    }
    if (coverDate.isValid()) {
        values.insert(QStringLiteral("year"), coverDate.year());
        values.insert(QStringLiteral("month"), coverDate.month());
    }

    mapComicVinePersonCredits(detail.value(QStringLiteral("person_credits")).toArray(), values);

    const QJsonArray characterCredits = detail.value(QStringLiteral("character_credits")).toArray();
    if (!characterCredits.isEmpty()) {
        QStringList names;
        for (const QJsonValue &value : characterCredits) {
            const QString name = value.toObject().value(QStringLiteral("name")).toString().trimmed();
            if (name.isEmpty()) continue;

            bool exists = false;
            for (const QString &existing : names) {
                if (existing.compare(name, Qt::CaseInsensitive) == 0) {
                    exists = true;
                    break;
                }
            }
            if (!exists) names.push_back(name);
        }

        if (!names.isEmpty()) {
            values.insert(QStringLiteral("characters"), names.join(QStringLiteral(", ")));
        }
    }

    return values;
}

QVariantMap buildMissingOnlyMetadataPatch(const QVariantMap &current, const QVariantMap &fetched)
{
    QVariantMap patch;

    auto maybeText = [&](const QString &key) {
        const QString currentValue = current.value(key).toString().trimmed();
        const QString fetchedValue = fetched.value(key).toString().trimmed();
        if (!currentValue.isEmpty() || fetchedValue.isEmpty()) return;
        patch.insert(key, fetchedValue);
    };

    auto maybeNumber = [&](const QString &key) {
        const int currentValue = current.value(key).toInt();
        const int fetchedValue = fetched.value(key).toInt();
        if (currentValue > 0 || fetchedValue <= 0) return;
        patch.insert(key, fetchedValue);
    };

    maybeText(QStringLiteral("series"));
    maybeText(QStringLiteral("title"));
    maybeText(QStringLiteral("issueNumber"));
    maybeText(QStringLiteral("publisher"));
    maybeText(QStringLiteral("writer"));
    maybeText(QStringLiteral("penciller"));
    maybeText(QStringLiteral("inker"));
    maybeText(QStringLiteral("colorist"));
    maybeText(QStringLiteral("letterer"));
    maybeText(QStringLiteral("coverArtist"));
    maybeText(QStringLiteral("editor"));
    maybeText(QStringLiteral("summary"));
    maybeText(QStringLiteral("characters"));
    maybeNumber(QStringLiteral("year"));
    maybeNumber(QStringLiteral("month"));

    return patch;
}

QVariantMap normalizeSeedValues(const QVariantMap &seedValues)
{
    QVariantMap normalized = seedValues;
    if (!normalized.contains(QStringLiteral("issueNumber")) && normalized.contains(QStringLiteral("issue"))) {
        normalized.insert(QStringLiteral("issueNumber"), normalized.value(QStringLiteral("issue")));
    }
    return normalized;
}

ComicVineAutofillResult queryComicVineAutofillCache(const QString &dataRoot, const QVariantMap &currentMetadata)
{
    ComicVineAutofillResult result;

    const QString series = currentMetadata.value(QStringLiteral("series")).toString().trimmed();
    const QString issueNumber = currentMetadata.value(QStringLiteral("issueNumber")).toString().trimmed();
    const int year = currentMetadata.value(QStringLiteral("year")).toInt();
    if (series.isEmpty() || issueNumber.isEmpty() || year < 1) return result;

    result.attempted = true;
    const QString cacheKey = normalizeMatchKey(series)
        + QStringLiteral("#")
        + normalizeMatchKey(issueNumber)
        + QStringLiteral("#")
        + QString::number(year);
    ensureComicVineAutofillCacheLoaded(dataRoot);
    ComicVineAutofillCacheState &cacheState = comicVineAutofillCacheState();

    if (cacheState.patchCache.contains(cacheKey)) {
        result.fromCache = true;
        result.values = cacheState.patchCache.value(cacheKey);
        return result;
    }
    if (cacheState.missCache.contains(cacheKey)) {
        result.fromCache = true;
    }
    return result;
}

QVariantMap buildComicVineAutofillResponse(const ComicVineAutofillResult &result)
{
    QVariantMap out;
    out.insert(QStringLiteral("attempted"), result.attempted);
    out.insert(QStringLiteral("fromCache"), result.fromCache);
    out.insert(QStringLiteral("values"), result.values);
    out.insert(QStringLiteral("hasValues"), !result.values.isEmpty());

    if (!result.error.trimmed().isEmpty()) {
        out.insert(QStringLiteral("ok"), false);
        out.insert(QStringLiteral("code"), QStringLiteral("request_failed"));
        out.insert(QStringLiteral("error"), result.error.trimmed());
        return out;
    }

    if (result.values.isEmpty()) {
        out.insert(QStringLiteral("ok"), true);
        out.insert(QStringLiteral("code"), QStringLiteral("no_match"));
        return out;
    }

    out.insert(QStringLiteral("ok"), true);
    out.insert(QStringLiteral("code"), QStringLiteral("filled"));
    return out;
}

QVariantMap buildSeedMissingResponse()
{
    return {
        { QStringLiteral("ok"), false },
        { QStringLiteral("code"), QStringLiteral("seed_missing") },
        { QStringLiteral("error"), QStringLiteral("To use auto-fill, add the minimum metadata: series, issue, year.") }
    };
}

void configureComicVineNetworkRequest(QNetworkRequest &request)
{
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ComicPile/0.1 (Qt metadata fetcher)"));
    request.setRawHeader("Accept", "application/json");
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
}

void armComicVineReplyTimeout(QNetworkReply *reply, int timeoutMs)
{
    if (!reply) return;

    auto *timer = new QTimer(reply);
    timer->setSingleShot(true);
    QObject::connect(timer, &QTimer::timeout, reply, [reply]() {
        reply->setProperty("comicVineTimedOut", true);
        reply->abort();
    });
    QObject::connect(reply, &QNetworkReply::finished, timer, &QObject::deleteLater);
    timer->start(timeoutMs);
}

bool parseComicVineJsonReply(QNetworkReply *reply, QJsonObject &rootOut, QString &errorOut)
{
    rootOut = {};
    errorOut.clear();
    if (!reply) {
        errorOut = QStringLiteral("ComicVine request failed: missing reply.");
        return false;
    }

    const QByteArray payload = reply->readAll();
    const QString replyError = reply->errorString().trimmed();
    const QNetworkReply::NetworkError networkError = reply->error();
    const bool timedOut = reply->property("comicVineTimedOut").toBool();
    reply->deleteLater();

    if (timedOut) {
        errorOut = QStringLiteral("ComicVine request timed out.");
        return false;
    }
    if (networkError != QNetworkReply::NoError) {
        errorOut = QStringLiteral("ComicVine request failed: %1")
            .arg(replyError.isEmpty() ? QStringLiteral("network error") : replyError);
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        errorOut = QStringLiteral("ComicVine response parse failed: %1").arg(parseError.errorString());
        return false;
    }

    const QJsonObject root = document.object();
    const int statusCode = root.value(QStringLiteral("status_code")).toInt(0);
    if (statusCode != 1) {
        const QString apiError = root.value(QStringLiteral("error")).toString().trimmed();
        errorOut = apiError.isEmpty()
            ? QStringLiteral("ComicVine returned status code %1.").arg(statusCode)
            : QStringLiteral("ComicVine returned error: %1").arg(apiError);
        return false;
    }

    rootOut = root;
    return true;
}

QUrl buildComicVineIssuesSearchUrl(const QString &apiKey, const QString &issueNumber)
{
    QUrl searchUrl(QStringLiteral("https://comicvine.gamespot.com/api/issues/"));
    QUrlQuery searchQuery;
    searchQuery.addQueryItem(QStringLiteral("api_key"), apiKey);
    searchQuery.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    searchQuery.addQueryItem(QStringLiteral("field_list"), QStringLiteral("id,name,issue_number,cover_date,volume,publisher"));
    searchQuery.addQueryItem(QStringLiteral("filter"), QStringLiteral("issue_number:%1").arg(issueNumber));
    searchQuery.addQueryItem(QStringLiteral("sort"), QStringLiteral("cover_date:desc"));
    searchQuery.addQueryItem(QStringLiteral("limit"), QStringLiteral("50"));
    searchUrl.setQuery(searchQuery);
    return searchUrl;
}

QUrl buildComicVineIssueDetailUrl(const QString &apiKey, int issueId)
{
    QUrl detailUrl(QStringLiteral("https://comicvine.gamespot.com/api/issue/4000-%1/").arg(issueId));
    QUrlQuery detailQuery;
    detailQuery.addQueryItem(QStringLiteral("api_key"), apiKey);
    detailQuery.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    detailQuery.addQueryItem(
        QStringLiteral("field_list"),
        QStringLiteral("id,name,issue_number,cover_date,store_date,deck,description,volume,publisher,person_credits,character_credits")
    );
    detailUrl.setQuery(detailQuery);
    return detailUrl;
}

QUrl buildComicVineVerifyUrl(const QString &apiKey)
{
    QUrl verifyUrl(QStringLiteral("https://comicvine.gamespot.com/api/issues/"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("api_key"), apiKey);
    query.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    query.addQueryItem(QStringLiteral("field_list"), QStringLiteral("id"));
    query.addQueryItem(QStringLiteral("sort"), QStringLiteral("id:asc"));
    query.addQueryItem(QStringLiteral("limit"), QStringLiteral("1"));
    verifyUrl.setQuery(query);
    return verifyUrl;
}

} // namespace

ComicVineAutofillService::ComicVineAutofillService(const QString &dataRoot, QObject *parent)
    : QObject(parent)
    , m_dataRoot(dataRoot)
    , m_networkAccessManager(new QNetworkAccessManager(this))
{
}

QVariantMap ComicVineAutofillService::requestAutofillFromCache(const QVariantMap &seedValues)
{
    const QVariantMap normalized = normalizeSeedValues(seedValues);
    const QString series = normalized.value(QStringLiteral("series")).toString().trimmed();
    const QString issueNumber = normalized.value(QStringLiteral("issueNumber")).toString().trimmed();
    if (series.isEmpty() || issueNumber.isEmpty()) {
        return buildSeedMissingResponse();
    }

    return buildComicVineAutofillResponse(queryComicVineAutofillCache(m_dataRoot, normalized));
}

void ComicVineAutofillService::emitAutofillFinishedLater(int requestId, const QVariantMap &result)
{
    QMetaObject::invokeMethod(
        this,
        [this, requestId, result]() {
            emit autofillFinished(requestId, result);
        },
        Qt::QueuedConnection
    );
}

void ComicVineAutofillService::emitApiKeyValidationFinishedLater(int requestId, const QVariantMap &result)
{
    QMetaObject::invokeMethod(
        this,
        [this, requestId, result]() {
            emit apiKeyValidationFinished(requestId, result);
        },
        Qt::QueuedConnection
    );
}

QString ComicVineAutofillService::configuredApiKey() const
{
    return resolveComicVineApiKey(m_dataRoot);
}

QString ComicVineAutofillService::saveApiKey(const QString &apiKey) const
{
    const QString normalized = apiKey.trimmed();
    const QString filePath = preferredComicVineApiKeyFilePath(m_dataRoot);
    const QFileInfo fileInfo(filePath);
    QDir().mkpath(fileInfo.absolutePath());

    if (normalized.isEmpty()) {
        QFile::remove(filePath);
        return {};
    }

    QSaveFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return QStringLiteral("Failed to open ComicVine API key file for writing.");
    }
    file.write(normalized.toUtf8());
    file.write("\n");
    if (!file.commit()) {
        return QStringLiteral("Failed to save ComicVine API key.");
    }
    return {};
}

void ComicVineAutofillService::requestApiKeyValidationAsync(int requestId, const QString &apiKey)
{
    const QString normalized = apiKey.trimmed();
    if (normalized.isEmpty()) {
        emitApiKeyValidationFinishedLater(requestId, {
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("missing_key") },
            { QStringLiteral("error"), QStringLiteral("Enter a ComicVine API key.") }
        });
        return;
    }

    auto *process = new QProcess(this);
    process->setProgram(QStringLiteral("powershell.exe"));

    const QString script = QStringLiteral(
        "$ProgressPreference='SilentlyContinue';"
        "$uri='https://comicvine.gamespot.com/api/issues/?api_key=' + %1 + '&format=json&limit=1';"
        "try {"
        "  $response = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'ComicPile/0.1 (local api check)' } -TimeoutSec 20;"
        "  $statusCode = if ($null -ne $response.status_code) { [int]$response.status_code } else { 0 };"
        "  $errorText = if ($null -ne $response.error) { [string]$response.error } else { '' };"
        "  if ($statusCode -eq 1) {"
        "    [PSCustomObject]@{ ok = $true; code = 'verified'; message = 'ComicVine API key verified.' } | ConvertTo-Json -Compress | Write-Output;"
        "  } else {"
        "    [PSCustomObject]@{ ok = $false; code = 'invalid_key'; error = ('ComicVine returned: ' + $errorText) } | ConvertTo-Json -Compress | Write-Output;"
        "  }"
        "} catch {"
        "  $msg = $_.Exception.Message;"
        "  if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }"
        "  [PSCustomObject]@{ ok = $false; code = 'request_failed'; error = $msg } | ConvertTo-Json -Compress | Write-Output;"
        "}"
    ).arg(quotePowerShellSingleQuoted(normalized));

    process->setArguments({
        QStringLiteral("-NoProfile"),
        QStringLiteral("-NonInteractive"),
        QStringLiteral("-ExecutionPolicy"), QStringLiteral("Bypass"),
        QStringLiteral("-Command"), script
    });

    auto *timeoutTimer = new QTimer(process);
    timeoutTimer->setSingleShot(true);
    auto *completionGuard = new bool(false);
    QObject::connect(timeoutTimer, &QTimer::timeout, process, [this, process, requestId]() {
        if (process->state() != QProcess::NotRunning) {
            process->kill();
        }
        emitApiKeyValidationFinishedLater(requestId, {
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("request_timeout") },
            { QStringLiteral("error"), QStringLiteral("ComicVine API key validation timed out.") }
        });
    });

    connect(process, &QProcess::errorOccurred, this, [this, process, timeoutTimer, requestId, completionGuard](QProcess::ProcessError error) {
        if (*completionGuard) return;
        *completionGuard = true;
        if (timeoutTimer->isActive()) {
            timeoutTimer->stop();
        }
        const QString stdErr = QString::fromUtf8(process->readAllStandardError()).trimmed();
        const QString stdOut = QString::fromUtf8(process->readAllStandardOutput()).trimmed();
        QString message = process->errorString().trimmed();
        if (!stdErr.isEmpty()) {
            message = stdErr;
        } else if (!stdOut.isEmpty()) {
            message = stdOut;
        }
        if (message.isEmpty()) {
            message = QStringLiteral("Failed to run PowerShell validation process.");
        }
        emitApiKeyValidationFinishedLater(requestId, {
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("process_error_%1").arg(static_cast<int>(error)) },
            { QStringLiteral("error"), message }
        });
        process->deleteLater();
        delete completionGuard;
    });

    connect(process, &QProcess::finished, this, [this, process, timeoutTimer, requestId, completionGuard](int exitCode, QProcess::ExitStatus exitStatus) {
        if (*completionGuard) return;
        *completionGuard = true;
        if (!timeoutTimer->isActive()) {
            process->deleteLater();
            delete completionGuard;
            return;
        }
        timeoutTimer->stop();

        const QString stdOut = QString::fromUtf8(process->readAllStandardOutput()).trimmed();
        const QString stdErr = QString::fromUtf8(process->readAllStandardError()).trimmed();
        process->deleteLater();

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            emitApiKeyValidationFinishedLater(requestId, {
                { QStringLiteral("ok"), false },
                { QStringLiteral("code"), QStringLiteral("process_exit_%1").arg(exitCode) },
                { QStringLiteral("error"), stdErr.isEmpty() ? QStringLiteral("PowerShell validation process failed.") : stdErr }
            });
            delete completionGuard;
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(stdOut.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            emitApiKeyValidationFinishedLater(requestId, {
                { QStringLiteral("ok"), false },
                { QStringLiteral("code"), QStringLiteral("request_failed") },
                { QStringLiteral("error"), stdErr.isEmpty() ? QStringLiteral("Failed to validate ComicVine API key.") : stdErr }
            });
            delete completionGuard;
            return;
        }

        emitApiKeyValidationFinishedLater(requestId, document.object().toVariantMap());
        delete completionGuard;
    });

    process->start();
    timeoutTimer->start(22000);
}

void ComicVineAutofillService::requestAutofillAsync(int requestId, const QVariantMap &seedValues)
{
    const QVariantMap normalized = normalizeSeedValues(seedValues);
    const QString series = normalized.value(QStringLiteral("series")).toString().trimmed();
    const QString issueNumber = normalized.value(QStringLiteral("issueNumber")).toString().trimmed();
    const int targetYear = normalized.value(QStringLiteral("year")).toInt();
    if (series.isEmpty() || issueNumber.isEmpty() || targetYear < 1) {
        emitAutofillFinishedLater(requestId, buildSeedMissingResponse());
        return;
    }

    const ComicVineAutofillResult cacheResult = queryComicVineAutofillCache(m_dataRoot, normalized);
    if (cacheResult.fromCache || !cacheResult.values.isEmpty()) {
        emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(cacheResult));
        return;
    }

    const QString apiKey = resolveComicVineApiKey(m_dataRoot);
    if (apiKey.isEmpty()) {
        emitAutofillFinishedLater(requestId, {
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("request_failed") },
            { QStringLiteral("error"), QStringLiteral("ComicVine API key is not configured.") }
        });
        return;
    }

    ensureComicVineAutofillCacheLoaded(m_dataRoot);
    const QString cacheKey = normalizeMatchKey(series)
        + QStringLiteral("#")
        + normalizeMatchKey(issueNumber)
        + QStringLiteral("#")
        + QString::number(targetYear);
    const QString targetSeriesKey = normalizeMatchKey(series);

    QNetworkRequest searchRequest(buildComicVineIssuesSearchUrl(apiKey, issueNumber));
    configureComicVineNetworkRequest(searchRequest);
    QNetworkReply *searchReply = m_networkAccessManager->get(searchRequest);
    armComicVineReplyTimeout(searchReply, 15000);

    connect(searchReply, &QNetworkReply::finished, this, [this, searchReply, normalized, requestId, cacheKey, targetSeriesKey, issueNumber, targetYear]() {
        QJsonObject searchRoot;
        QString searchError;
        if (!parseComicVineJsonReply(searchReply, searchRoot, searchError)) {
            ComicVineAutofillResult result;
            result.attempted = true;
            result.error = searchError;
            emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
            return;
        }

        ensureComicVineAutofillCacheLoaded(m_dataRoot);
        ComicVineAutofillCacheState &cacheState = comicVineAutofillCacheState();
        const QJsonArray issues = ensureArrayResults(searchRoot.value(QStringLiteral("results")));
        if (issues.isEmpty()) {
            cacheState.missCache.insert(cacheKey);
            cacheState.dirty = true;
            saveComicVineAutofillCacheIfDirty();

            ComicVineAutofillResult result;
            result.attempted = true;
            emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
            return;
        }

        int bestIssueId = 0;
        int bestScore = std::numeric_limits<int>::min();
        for (const QJsonValue &entry : issues) {
            if (!entry.isObject()) continue;
            const QJsonObject candidate = entry.toObject();
            if (!isComicVineIssueCandidateAcceptable(candidate, targetSeriesKey, issueNumber, targetYear)) {
                continue;
            }
            const int score = scoreComicVineIssueCandidate(candidate, targetSeriesKey, issueNumber, targetYear);
            const int issueId = candidate.value(QStringLiteral("id")).toInt(0);
            if (issueId < 1) continue;
            if (score > bestScore) {
                bestScore = score;
                bestIssueId = issueId;
            }
        }

        if (bestIssueId < 1 || bestScore < 240) {
            cacheState.missCache.insert(cacheKey);
            cacheState.dirty = true;
            saveComicVineAutofillCacheIfDirty();

            ComicVineAutofillResult result;
            result.attempted = true;
            emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
            return;
        }

        const QString apiKey = resolveComicVineApiKey(m_dataRoot);
        if (apiKey.isEmpty()) {
            ComicVineAutofillResult result;
            result.attempted = true;
            result.error = QStringLiteral("ComicVine API key is not configured.");
            emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
            return;
        }

        QNetworkRequest detailRequest(buildComicVineIssueDetailUrl(apiKey, bestIssueId));
        configureComicVineNetworkRequest(detailRequest);
        QNetworkReply *detailReply = m_networkAccessManager->get(detailRequest);
        armComicVineReplyTimeout(detailReply, 15000);

        connect(detailReply, &QNetworkReply::finished, this, [this, detailReply, normalized, requestId, cacheKey, targetSeriesKey, issueNumber, targetYear]() {
            QJsonObject detailRoot;
            QString detailError;
            if (!parseComicVineJsonReply(detailReply, detailRoot, detailError)) {
                ComicVineAutofillResult result;
                result.attempted = true;
                result.error = detailError;
                emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
                return;
            }

            ensureComicVineAutofillCacheLoaded(m_dataRoot);
            ComicVineAutofillCacheState &cacheState = comicVineAutofillCacheState();
            const QJsonObject detail = detailRoot.value(QStringLiteral("results")).toObject();
            if (detail.isEmpty()) {
                cacheState.missCache.insert(cacheKey);
                cacheState.dirty = true;
                saveComicVineAutofillCacheIfDirty();

                ComicVineAutofillResult result;
                result.attempted = true;
                emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
                return;
            }

            const QVariantMap fetchedValues = extractComicVineMetadataValues(detail);
            if (!isFetchedComicVineDetailAcceptable(fetchedValues, targetSeriesKey, issueNumber, targetYear)) {
                cacheState.missCache.insert(cacheKey);
                cacheState.dirty = true;
                saveComicVineAutofillCacheIfDirty();

                ComicVineAutofillResult result;
                result.attempted = true;
                emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
                return;
            }
            const QVariantMap patch = buildMissingOnlyMetadataPatch(normalized, fetchedValues);
            if (!patch.isEmpty()) {
                cacheState.patchCache.insert(cacheKey, patch);
            } else {
                cacheState.missCache.insert(cacheKey);
            }
            cacheState.dirty = true;
            saveComicVineAutofillCacheIfDirty();

            ComicVineAutofillResult result;
            result.attempted = true;
            result.values = patch;
            emitAutofillFinishedLater(requestId, buildComicVineAutofillResponse(result));
        });
    });
}
