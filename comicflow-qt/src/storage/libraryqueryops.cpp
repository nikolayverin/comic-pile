#include "storage/libraryqueryops.h"

#include "storage/importmatching.h"
#include "storage/libraryschemamanager.h"
#include "storage/sqliteconnectionutils.h"
#include "common/scopedsqlconnectionremoval.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString valueFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toString().trimmed();
}

struct SeriesMetadataRecord {
    QString seriesTitle;
    QString summary;
    QString seriesYear;
    QString seriesMonth;
    QString genres;
    QString volume;
    QString publisher;
    QString ageRating;
    QString headerCoverPath;
    QString headerBackgroundPath;
};

struct IssueMetadataKnowledgeRecord {
    QString seriesNameKey;
    QString seriesGroupKey;
    QString seriesTitle;
    QString seriesVolume;
    QString issueKey;
    QString issueNumber;
    QString issueTitle;
    QString issuePublisher;
    QString issueYear;
    QString issueMonth;
    QString issueAgeRating;
    QString issueWriter;
    QString issuePenciller;
    QString issueInker;
    QString issueColorist;
    QString issueLetterer;
    QString issueCoverArtist;
    QString issueEditor;
    QString issueStoryArc;
    QString issueCharacters;
};

bool normalizeSeriesMetadataYear(const QString &input, QString &normalizedYear, QString &errorText)
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty()) {
        normalizedYear.clear();
        return true;
    }

    bool ok = false;
    const int parsedYear = trimmed.toInt(&ok);
    if (!ok || parsedYear < 0 || parsedYear > 9999) {
        errorText = QStringLiteral("Series year must be between 0 and 9999.");
        return false;
    }

    normalizedYear = QString::number(parsedYear);
    return true;
}

bool normalizeOptionalMonth(
    const QString &input,
    const QString &label,
    QString &normalizedMonth,
    QString &errorText
)
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty()) {
        normalizedMonth.clear();
        return true;
    }

    bool ok = false;
    const int parsedMonth = trimmed.toInt(&ok);
    if (!ok || parsedMonth < 1 || parsedMonth > 12) {
        errorText = QStringLiteral("%1 must be between 1 and 12.").arg(label);
        return false;
    }

    normalizedMonth = QString::number(parsedMonth);
    return true;
}

bool loadSeriesMetadataRecord(
    QSqlDatabase &db,
    const QString &seriesKey,
    SeriesMetadataRecord &recordOut,
    QString &errorText
)
{
    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "SELECT COALESCE(series_title, ''), COALESCE(series_summary, ''), "
            "CASE WHEN COALESCE(series_year, 0) = 0 THEN '' ELSE CAST(series_year AS TEXT) END, "
            "CASE WHEN COALESCE(series_month, 0) = 0 THEN '' ELSE CAST(series_month AS TEXT) END, "
            "COALESCE(series_genres, ''), "
            "COALESCE(series_volume, ''), "
            "COALESCE(series_publisher, ''), "
            "COALESCE(series_age_rating, ''), "
            "COALESCE(series_header_cover_path, ''), "
            "COALESCE(series_header_background_path, '') "
            "FROM series_metadata "
            "WHERE series_group_key = ? "
            "LIMIT 1"
        )
    );
    query.addBindValue(seriesKey);
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to read series metadata: %1").arg(query.lastError().text());
        return false;
    }

    recordOut = {};
    if (query.next()) {
        recordOut.seriesTitle = trimOrEmpty(query.value(0));
        recordOut.summary = trimOrEmpty(query.value(1));
        recordOut.seriesYear = trimOrEmpty(query.value(2));
        recordOut.seriesMonth = trimOrEmpty(query.value(3));
        recordOut.genres = trimOrEmpty(query.value(4));
        recordOut.volume = trimOrEmpty(query.value(5));
        recordOut.publisher = trimOrEmpty(query.value(6));
        recordOut.ageRating = trimOrEmpty(query.value(7));
        recordOut.headerCoverPath = trimOrEmpty(query.value(8));
        recordOut.headerBackgroundPath = trimOrEmpty(query.value(9));
    }
    return true;
}

bool writeSeriesMetadataRecord(
    QSqlDatabase &db,
    const QString &seriesKey,
    const SeriesMetadataRecord &record,
    QString &errorText
)
{
    QSqlQuery query(db);
    if (record.seriesTitle.isEmpty()
        && record.summary.isEmpty()
        && record.seriesYear.isEmpty()
        && record.seriesMonth.isEmpty()
        && record.genres.isEmpty()
        && record.volume.isEmpty()
        && record.publisher.isEmpty()
        && record.ageRating.isEmpty()
        && record.headerCoverPath.isEmpty()
        && record.headerBackgroundPath.isEmpty()) {
        query.prepare(QStringLiteral("DELETE FROM series_metadata WHERE series_group_key = ?"));
        query.addBindValue(seriesKey);
        if (!query.exec()) {
            errorText = QStringLiteral("Failed to remove series metadata: %1").arg(query.lastError().text());
            return false;
        }
        return true;
    }

    query.prepare(
        QStringLiteral(
            "INSERT OR REPLACE INTO series_metadata "
            "(series_group_key, series_title, series_summary, series_year, series_month, series_genres, "
            "series_volume, series_publisher, series_age_rating, "
            "series_header_cover_path, series_header_background_path, updated_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))"
        )
    );
    query.addBindValue(seriesKey);
    query.addBindValue(record.seriesTitle);
    query.addBindValue(record.summary);
    query.addBindValue(record.seriesYear.isEmpty() ? QVariant() : QVariant(record.seriesYear.toInt()));
    query.addBindValue(record.seriesMonth.isEmpty() ? QVariant() : QVariant(record.seriesMonth.toInt()));
    query.addBindValue(record.genres);
    query.addBindValue(record.volume);
    query.addBindValue(record.publisher);
    query.addBindValue(record.ageRating);
    query.addBindValue(record.headerCoverPath);
    query.addBindValue(record.headerBackgroundPath);
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to save series metadata: %1").arg(query.lastError().text());
        return false;
    }
    return true;
}

QVariantMap issueKnowledgeRecordToMap(const IssueMetadataKnowledgeRecord &record)
{
    return {
        { QStringLiteral("seriesKey"), record.seriesGroupKey },
        { QStringLiteral("seriesTitle"), record.seriesTitle },
        { QStringLiteral("volume"), record.seriesVolume },
        { QStringLiteral("issueNumber"), record.issueNumber },
        { QStringLiteral("title"), record.issueTitle },
        { QStringLiteral("publisher"), record.issuePublisher },
        { QStringLiteral("year"), record.issueYear },
        { QStringLiteral("month"), record.issueMonth },
        { QStringLiteral("ageRating"), record.issueAgeRating },
        { QStringLiteral("writer"), record.issueWriter },
        { QStringLiteral("penciller"), record.issuePenciller },
        { QStringLiteral("inker"), record.issueInker },
        { QStringLiteral("colorist"), record.issueColorist },
        { QStringLiteral("letterer"), record.issueLetterer },
        { QStringLiteral("coverArtist"), record.issueCoverArtist },
        { QStringLiteral("editor"), record.issueEditor },
        { QStringLiteral("storyArc"), record.issueStoryArc },
        { QStringLiteral("characters"), record.issueCharacters }
    };
}

} // namespace

namespace ComicLibraryQueries {

bool loadComicRecords(const QString &dbPath, QVector<ComicRecord> &rowsOut, QString &errorText)
{
    rowsOut.clear();

    const QString connectionName = QStringLiteral("comic_pile_library_rows_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, errorText)) {
        return false;
    }

    QSqlQuery query(db);
    const char *sql =
        "SELECT id, COALESCE(file_path, ''), filename, COALESCE(series, ''), COALESCE(volume, ''), "
        "COALESCE(title, ''), "
        "COALESCE(issue_number, issue, ''), COALESCE(publisher, ''), "
        "COALESCE(year, 0), COALESCE(month, 0), "
        "COALESCE(writer, ''), COALESCE(penciller, ''), COALESCE(inker, ''), "
        "COALESCE(colorist, ''), COALESCE(letterer, ''), COALESCE(cover_artist, ''), "
        "COALESCE(editor, ''), COALESCE(story_arc, ''), COALESCE(summary, ''), "
        "COALESCE(characters, ''), COALESCE(genres, ''), COALESCE(age_rating, ''), "
        "COALESCE(read_status, 'unread'), COALESCE(current_page, 0), COALESCE(bookmark_page, 0), "
        "COALESCE(bookmark_added_at, ''), "
        "COALESCE(favorite_active, 0), COALESCE(favorite_added_at, ''), "
        "COALESCE(added_date, '') "
        "FROM comics "
        "ORDER BY id";
    if (!query.exec(QString::fromUtf8(sql))) {
        errorText = QStringLiteral("Failed to read comics: %1").arg(query.lastError().text());
        db.close();
        return false;
    }

    while (query.next()) {
        ComicRecord row;
        row.id = query.value(0).toInt();
        row.filePath = trimOrEmpty(query.value(1));
        row.filename = trimOrEmpty(query.value(2));
        row.series = trimOrEmpty(query.value(3));
        row.volume = trimOrEmpty(query.value(4));
        row.title = trimOrEmpty(query.value(5));
        row.issueNumber = trimOrEmpty(query.value(6));
        row.publisher = trimOrEmpty(query.value(7));
        row.year = query.value(8).toInt();
        row.month = query.value(9).toInt();
        row.writer = trimOrEmpty(query.value(10));
        row.penciller = trimOrEmpty(query.value(11));
        row.inker = trimOrEmpty(query.value(12));
        row.colorist = trimOrEmpty(query.value(13));
        row.letterer = trimOrEmpty(query.value(14));
        row.coverArtist = trimOrEmpty(query.value(15));
        row.editor = trimOrEmpty(query.value(16));
        row.storyArc = trimOrEmpty(query.value(17));
        row.summary = trimOrEmpty(query.value(18));
        row.characters = trimOrEmpty(query.value(19));
        row.genres = trimOrEmpty(query.value(20));
        row.ageRating = trimOrEmpty(query.value(21));
        row.readStatus = trimOrEmpty(query.value(22));
        row.currentPage = query.value(23).toInt();
        row.bookmarkPage = query.value(24).toInt();
        row.bookmarkAddedAt = trimOrEmpty(query.value(25));
        row.favoriteActive = query.value(26).toInt() > 0;
        row.favoriteAddedAt = trimOrEmpty(query.value(27));
        row.addedDate = trimOrEmpty(query.value(28));
        rowsOut.push_back(row);
    }

    db.close();
    return true;
}

QVariantMap loadComicMetadata(const QString &dbPath, int comicId)
{
    if (comicId < 1) {
        return {
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        };
    }

    const QString connectionName = QStringLiteral("comic_pile_load_metadata_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return {
            { QStringLiteral("error"), openError }
        };
    }

    QSqlQuery query(db);
    query.prepare(
        "SELECT "
        "COALESCE(series, ''), COALESCE(volume, ''), COALESCE(title, ''), "
        "COALESCE(issue_number, issue, ''), COALESCE(publisher, ''), "
        "COALESCE(year, 0), COALESCE(month, 0), "
        "COALESCE(writer, ''), COALESCE(penciller, ''), COALESCE(inker, ''), "
        "COALESCE(colorist, ''), COALESCE(letterer, ''), COALESCE(cover_artist, ''), "
        "COALESCE(editor, ''), COALESCE(story_arc, ''), COALESCE(summary, ''), "
        "COALESCE(characters, ''), COALESCE(genres, ''), COALESCE(age_rating, ''), "
        "COALESCE(read_status, 'unread'), COALESCE(current_page, 0), COALESCE(bookmark_page, 0), "
        "COALESCE(bookmark_added_at, ''), "
        "COALESCE(favorite_active, 0), COALESCE(favorite_added_at, ''), "
        "COALESCE(filename, ''), COALESCE(file_path, ''), "
        "COALESCE(import_original_filename, ''), "
        "COALESCE(import_strict_filename_signature, ''), "
        "COALESCE(import_loose_filename_signature, ''), "
        "COALESCE(import_source_type, '') "
        "FROM comics WHERE id = ? LIMIT 1"
    );
    query.addBindValue(comicId);
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to load metadata: %1").arg(query.lastError().text());
        db.close();
        return {
            { QStringLiteral("error"), error }
        };
    }

    if (!query.next()) {
        db.close();
        return {
            { QStringLiteral("error"), QStringLiteral("Issue id %1 not found.").arg(comicId) }
        };
    }

    QVariantMap values;
    values.insert(QStringLiteral("id"), comicId);
    values.insert(QStringLiteral("series"), trimOrEmpty(query.value(0)));
    values.insert(QStringLiteral("volume"), trimOrEmpty(query.value(1)));
    values.insert(QStringLiteral("title"), trimOrEmpty(query.value(2)));
    values.insert(QStringLiteral("issueNumber"), trimOrEmpty(query.value(3)));
    values.insert(QStringLiteral("publisher"), trimOrEmpty(query.value(4)));
    values.insert(QStringLiteral("year"), query.value(5).toInt());
    const int monthNumber = query.value(6).toInt();
    values.insert(QStringLiteral("month"), monthNumber);
    values.insert(QStringLiteral("writer"), trimOrEmpty(query.value(7)));
    values.insert(QStringLiteral("penciller"), trimOrEmpty(query.value(8)));
    values.insert(QStringLiteral("inker"), trimOrEmpty(query.value(9)));
    values.insert(QStringLiteral("colorist"), trimOrEmpty(query.value(10)));
    values.insert(QStringLiteral("letterer"), trimOrEmpty(query.value(11)));
    values.insert(QStringLiteral("coverArtist"), trimOrEmpty(query.value(12)));
    values.insert(QStringLiteral("editor"), trimOrEmpty(query.value(13)));
    values.insert(QStringLiteral("storyArc"), trimOrEmpty(query.value(14)));
    values.insert(QStringLiteral("summary"), trimOrEmpty(query.value(15)));
    values.insert(QStringLiteral("characters"), trimOrEmpty(query.value(16)));
    values.insert(QStringLiteral("genres"), trimOrEmpty(query.value(17)));
    values.insert(QStringLiteral("ageRating"), trimOrEmpty(query.value(18)));
    values.insert(QStringLiteral("readStatus"), trimOrEmpty(query.value(19)));
    values.insert(QStringLiteral("currentPage"), query.value(20).toInt());
    values.insert(QStringLiteral("bookmarkPage"), query.value(21).toInt());
    values.insert(QStringLiteral("bookmarkAddedAt"), trimOrEmpty(query.value(22)));
    values.insert(QStringLiteral("favoriteActive"), query.value(23).toInt() > 0);
    values.insert(QStringLiteral("favoriteAddedAt"), trimOrEmpty(query.value(24)));
    values.insert(QStringLiteral("filename"), trimOrEmpty(query.value(25)));
    values.insert(QStringLiteral("filePath"), trimOrEmpty(query.value(26)));
    values.insert(QStringLiteral("importOriginalFilename"), trimOrEmpty(query.value(27)));
    values.insert(QStringLiteral("importStrictFilenameSignature"), trimOrEmpty(query.value(28)));
    values.insert(QStringLiteral("importLooseFilenameSignature"), trimOrEmpty(query.value(29)));
    values.insert(QStringLiteral("importSourceType"), trimOrEmpty(query.value(30)));

    db.close();
    return values;
}

QVariantMap seriesMetadataForKey(const QString &dbPath, const QString &seriesKey)
{
    const QString key = seriesKey.trimmed();
    if (key.isEmpty()) {
        return {
            { QStringLiteral("seriesTitle"), QString() },
            { QStringLiteral("summary"), QString() },
            { QStringLiteral("year"), QString() },
            { QStringLiteral("month"), QString() },
            { QStringLiteral("genres"), QString() },
            { QStringLiteral("volume"), QString() },
            { QStringLiteral("publisher"), QString() },
            { QStringLiteral("ageRating"), QString() },
            { QStringLiteral("headerCoverPath"), QString() },
            { QStringLiteral("headerBackgroundPath"), QString() }
        };
    }

    const QString connectionName = QStringLiteral("comic_pile_series_metadata_read_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return {
            { QStringLiteral("seriesTitle"), QString() },
            { QStringLiteral("summary"), QString() },
            { QStringLiteral("year"), QString() },
            { QStringLiteral("month"), QString() },
            { QStringLiteral("genres"), QString() },
            { QStringLiteral("volume"), QString() },
            { QStringLiteral("publisher"), QString() },
            { QStringLiteral("ageRating"), QString() },
            { QStringLiteral("headerCoverPath"), QString() },
            { QStringLiteral("headerBackgroundPath"), QString() }
        };
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureSeriesMetadataTable(db, schemaError)) {
        db.close();
        return {
            { QStringLiteral("seriesTitle"), QString() },
            { QStringLiteral("summary"), QString() },
            { QStringLiteral("year"), QString() },
            { QStringLiteral("month"), QString() },
            { QStringLiteral("genres"), QString() },
            { QStringLiteral("volume"), QString() },
            { QStringLiteral("publisher"), QString() },
            { QStringLiteral("ageRating"), QString() }
        };
    }

    SeriesMetadataRecord record;
    QString readError;
    if (!loadSeriesMetadataRecord(db, key, record, readError)) {
        db.close();
        return {
            { QStringLiteral("seriesTitle"), QString() },
            { QStringLiteral("summary"), QString() },
            { QStringLiteral("year"), QString() },
            { QStringLiteral("month"), QString() },
            { QStringLiteral("genres"), QString() },
            { QStringLiteral("volume"), QString() },
            { QStringLiteral("publisher"), QString() },
            { QStringLiteral("ageRating"), QString() },
            { QStringLiteral("headerCoverPath"), QString() },
            { QStringLiteral("headerBackgroundPath"), QString() }
        };
    }

    db.close();
    return {
        { QStringLiteral("seriesTitle"), record.seriesTitle },
        { QStringLiteral("summary"), record.summary },
        { QStringLiteral("year"), record.seriesYear },
        { QStringLiteral("month"), record.seriesMonth },
        { QStringLiteral("genres"), record.genres },
        { QStringLiteral("volume"), record.volume },
        { QStringLiteral("publisher"), record.publisher },
        { QStringLiteral("ageRating"), record.ageRating },
        { QStringLiteral("headerCoverPath"), record.headerCoverPath },
        { QStringLiteral("headerBackgroundPath"), record.headerBackgroundPath }
    };
}

QVariantList seriesMetadataCandidates(const QString &dbPath, const QString &seriesName)
{
    QVariantList rows;

    const QString normalizedSeriesKey = ComicImportMatching::normalizeSeriesKey(seriesName);
    if (normalizedSeriesKey.isEmpty() || normalizedSeriesKey == QStringLiteral("unknown-series")) {
        return rows;
    }

    const QString connectionName = QStringLiteral("comic_pile_series_metadata_candidates_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return rows;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureSeriesMetadataTable(db, schemaError)) {
        db.close();
        return rows;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "SELECT series_group_key, "
            "COALESCE(series_title, ''), "
            "COALESCE(series_summary, ''), "
            "CASE WHEN COALESCE(series_year, 0) = 0 THEN '' ELSE CAST(series_year AS TEXT) END, "
            "CASE WHEN COALESCE(series_month, 0) = 0 THEN '' ELSE CAST(series_month AS TEXT) END, "
            "COALESCE(series_genres, ''), "
            "COALESCE(series_volume, ''), "
            "COALESCE(series_publisher, ''), "
            "COALESCE(series_age_rating, ''), "
            "COALESCE(series_header_cover_path, ''), "
            "COALESCE(series_header_background_path, '') "
            "FROM series_metadata "
            "WHERE series_group_key = ? OR series_group_key LIKE ? "
            "ORDER BY updated_at DESC"
        )
    );
    query.addBindValue(normalizedSeriesKey);
    query.addBindValue(QStringLiteral("%1::vol::%2").arg(normalizedSeriesKey, QStringLiteral("%")));
    if (!query.exec()) {
        db.close();
        return rows;
    }

    while (query.next()) {
        QVariantMap row;
        row.insert(QStringLiteral("seriesKey"), trimOrEmpty(query.value(0)));
        row.insert(QStringLiteral("seriesTitle"), trimOrEmpty(query.value(1)));
        row.insert(QStringLiteral("summary"), trimOrEmpty(query.value(2)));
        row.insert(QStringLiteral("year"), trimOrEmpty(query.value(3)));
        row.insert(QStringLiteral("month"), trimOrEmpty(query.value(4)));
        row.insert(QStringLiteral("genres"), trimOrEmpty(query.value(5)));
        row.insert(QStringLiteral("volume"), trimOrEmpty(query.value(6)));
        row.insert(QStringLiteral("publisher"), trimOrEmpty(query.value(7)));
        row.insert(QStringLiteral("ageRating"), trimOrEmpty(query.value(8)));
        row.insert(QStringLiteral("headerCoverPath"), trimOrEmpty(query.value(9)));
        row.insert(QStringLiteral("headerBackgroundPath"), trimOrEmpty(query.value(10)));
        rows.push_back(row);
    }

    db.close();
    return rows;
}

QString setSeriesMetadataForKey(const QString &dbPath, const QString &seriesKey, const QVariantMap &values)
{
    const QString key = seriesKey.trimmed();
    if (key.isEmpty()) return QStringLiteral("Series key is required.");

    const bool hasSeriesTitle = values.contains(QStringLiteral("seriesTitle"));
    const bool hasSummary = values.contains(QStringLiteral("summary"));
    const bool hasYear = values.contains(QStringLiteral("year"));
    const bool hasMonth = values.contains(QStringLiteral("month"));
    const bool hasGenres = values.contains(QStringLiteral("genres"));
    const bool hasVolume = values.contains(QStringLiteral("volume"));
    const bool hasPublisher = values.contains(QStringLiteral("publisher"));
    const bool hasAgeRating = values.contains(QStringLiteral("ageRating"));
    const bool hasHeaderCoverPath = values.contains(QStringLiteral("headerCoverPath"));
    const bool hasHeaderBackgroundPath = values.contains(QStringLiteral("headerBackgroundPath"));
    if (!hasSeriesTitle
        && !hasSummary
        && !hasYear
        && !hasMonth
        && !hasGenres
        && !hasVolume
        && !hasPublisher
        && !hasAgeRating
        && !hasHeaderCoverPath
        && !hasHeaderBackgroundPath) return {};

    const QString connectionName = QStringLiteral("comic_pile_series_metadata_write_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureSeriesMetadataTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    SeriesMetadataRecord record;
    QString readError;
    if (!loadSeriesMetadataRecord(db, key, record, readError)) {
        db.close();
        return readError;
    }

    if (hasSeriesTitle) {
        record.seriesTitle = valueFromMap(values, QStringLiteral("seriesTitle"));
    }
    if (hasSummary) {
        record.summary = valueFromMap(values, QStringLiteral("summary"));
    }
    if (hasYear) {
        QString normalizedYear;
        QString yearError;
        if (!normalizeSeriesMetadataYear(valueFromMap(values, QStringLiteral("year")), normalizedYear, yearError)) {
            db.close();
            return yearError;
        }
        record.seriesYear = normalizedYear;
    }
    if (hasMonth) {
        QString normalizedMonth;
        QString monthError;
        if (!normalizeOptionalMonth(valueFromMap(values, QStringLiteral("month")), QStringLiteral("Series month"), normalizedMonth, monthError)) {
            db.close();
            return monthError;
        }
        record.seriesMonth = normalizedMonth;
    }
    if (hasGenres) {
        record.genres = valueFromMap(values, QStringLiteral("genres"));
    }
    if (hasVolume) {
        record.volume = valueFromMap(values, QStringLiteral("volume"));
    }
    if (hasPublisher) {
        record.publisher = valueFromMap(values, QStringLiteral("publisher"));
    }
    if (hasAgeRating) {
        record.ageRating = valueFromMap(values, QStringLiteral("ageRating"));
    }
    if (hasHeaderCoverPath) {
        record.headerCoverPath = valueFromMap(values, QStringLiteral("headerCoverPath"));
    }
    if (hasHeaderBackgroundPath) {
        record.headerBackgroundPath = valueFromMap(values, QStringLiteral("headerBackgroundPath"));
    }

    QString writeError;
    if (!writeSeriesMetadataRecord(db, key, record, writeError)) {
        db.close();
        return writeError;
    }

    db.close();
    return {};
}

QVariantList issueMetadataKnowledgeCandidates(
    const QString &dbPath,
    const QString &seriesName,
    const QString &issueNumber
)
{
    QVariantList rows;

    const QString normalizedSeriesKey = ComicImportMatching::normalizeSeriesKey(seriesName);
    const QString normalizedIssueKey = ComicImportMatching::normalizeIssueKey(issueNumber);
    if (normalizedSeriesKey.isEmpty()
        || normalizedSeriesKey == QStringLiteral("unknown-series")
        || normalizedIssueKey.isEmpty()) {
        return rows;
    }

    const QString connectionName = QStringLiteral("comic_pile_issue_metadata_knowledge_candidates_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return rows;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureIssueMetadataKnowledgeTable(db, schemaError)) {
        db.close();
        return rows;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "SELECT series_name_key, series_group_key, "
            "COALESCE(series_title, ''), COALESCE(series_volume, ''), "
            "issue_key, COALESCE(issue_number, ''), COALESCE(issue_title, ''), "
            "COALESCE(issue_publisher, ''), "
            "CASE WHEN COALESCE(issue_year, 0) = 0 THEN '' ELSE CAST(issue_year AS TEXT) END, "
            "CASE WHEN COALESCE(issue_month, 0) = 0 THEN '' ELSE CAST(issue_month AS TEXT) END, "
            "COALESCE(issue_age_rating, ''), "
            "COALESCE(issue_writer, ''), COALESCE(issue_penciller, ''), COALESCE(issue_inker, ''), "
            "COALESCE(issue_colorist, ''), COALESCE(issue_letterer, ''), COALESCE(issue_cover_artist, ''), "
            "COALESCE(issue_editor, ''), COALESCE(issue_story_arc, ''), COALESCE(issue_characters, '') "
            "FROM issue_metadata_knowledge "
            "WHERE series_name_key = ? AND issue_key = ? "
            "ORDER BY updated_at DESC"
        )
    );
    query.addBindValue(normalizedSeriesKey);
    query.addBindValue(normalizedIssueKey);
    if (!query.exec()) {
        db.close();
        return rows;
    }

    while (query.next()) {
        IssueMetadataKnowledgeRecord record;
        record.seriesNameKey = trimOrEmpty(query.value(0));
        record.seriesGroupKey = trimOrEmpty(query.value(1));
        record.seriesTitle = trimOrEmpty(query.value(2));
        record.seriesVolume = trimOrEmpty(query.value(3));
        record.issueKey = trimOrEmpty(query.value(4));
        record.issueNumber = trimOrEmpty(query.value(5));
        record.issueTitle = trimOrEmpty(query.value(6));
        record.issuePublisher = trimOrEmpty(query.value(7));
        record.issueYear = trimOrEmpty(query.value(8));
        record.issueMonth = trimOrEmpty(query.value(9));
        record.issueAgeRating = trimOrEmpty(query.value(10));
        record.issueWriter = trimOrEmpty(query.value(11));
        record.issuePenciller = trimOrEmpty(query.value(12));
        record.issueInker = trimOrEmpty(query.value(13));
        record.issueColorist = trimOrEmpty(query.value(14));
        record.issueLetterer = trimOrEmpty(query.value(15));
        record.issueCoverArtist = trimOrEmpty(query.value(16));
        record.issueEditor = trimOrEmpty(query.value(17));
        record.issueStoryArc = trimOrEmpty(query.value(18));
        record.issueCharacters = trimOrEmpty(query.value(19));
        rows.push_back(issueKnowledgeRecordToMap(record));
    }

    db.close();
    return rows;
}

QString setIssueMetadataKnowledge(const QString &dbPath, const QVariantMap &values)
{
    const QString seriesName = valueFromMap(values, QStringLiteral("series"));
    const QString volume = valueFromMap(values, QStringLiteral("volume"));
    const QString issueNumber = valueFromMap(values, QStringLiteral("issueNumber"));
    const QString seriesNameKey = ComicImportMatching::normalizeSeriesKey(seriesName);
    const QString seriesGroupKey = seriesNameKey.isEmpty()
        ? QString()
        : (ComicImportMatching::normalizeVolumeKey(volume) == QStringLiteral("__no_volume__")
            ? seriesNameKey
            : QStringLiteral("%1::vol::%2").arg(seriesNameKey, ComicImportMatching::normalizeVolumeKey(volume)));
    const QString issueKey = ComicImportMatching::normalizeIssueKey(issueNumber);
    if (seriesGroupKey.isEmpty() || issueKey.isEmpty()) {
        return {};
    }

    const QString title = valueFromMap(values, QStringLiteral("title"));
    const QString publisher = valueFromMap(values, QStringLiteral("publisher"));
    const QString ageRating = valueFromMap(values, QStringLiteral("ageRating"));
    const QString writer = valueFromMap(values, QStringLiteral("writer"));
    const QString penciller = valueFromMap(values, QStringLiteral("penciller"));
    const QString inker = valueFromMap(values, QStringLiteral("inker"));
    const QString colorist = valueFromMap(values, QStringLiteral("colorist"));
    const QString letterer = valueFromMap(values, QStringLiteral("letterer"));
    const QString coverArtist = valueFromMap(values, QStringLiteral("coverArtist"));
    const QString editor = valueFromMap(values, QStringLiteral("editor"));
    const QString storyArc = valueFromMap(values, QStringLiteral("storyArc"));
    const QString characters = valueFromMap(values, QStringLiteral("characters"));
    const bool hasSupportingData = !title.isEmpty()
        || !publisher.isEmpty()
        || !valueFromMap(values, QStringLiteral("year")).isEmpty()
        || !valueFromMap(values, QStringLiteral("month")).isEmpty()
        || !ageRating.isEmpty()
        || !writer.isEmpty()
        || !penciller.isEmpty()
        || !inker.isEmpty()
        || !colorist.isEmpty()
        || !letterer.isEmpty()
        || !coverArtist.isEmpty()
        || !editor.isEmpty()
        || !storyArc.isEmpty()
        || !characters.isEmpty();
    if (!hasSupportingData) {
        return {};
    }

    QString normalizedYear;
    QString yearError;
    if (!normalizeSeriesMetadataYear(valueFromMap(values, QStringLiteral("year")), normalizedYear, yearError)) {
        return yearError;
    }

    QString normalizedMonth;
    QString monthError;
    if (!normalizeOptionalMonth(valueFromMap(values, QStringLiteral("month")), QStringLiteral("Issue month"), normalizedMonth, monthError)) {
        return monthError;
    }

    const QString connectionName = QStringLiteral("comic_pile_issue_metadata_knowledge_write_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureIssueMetadataKnowledgeTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "INSERT OR REPLACE INTO issue_metadata_knowledge ("
            "series_name_key, series_group_key, series_title, series_volume, issue_key, issue_number, "
            "issue_title, issue_publisher, issue_year, issue_month, issue_age_rating, "
            "issue_writer, issue_penciller, issue_inker, issue_colorist, issue_letterer, "
            "issue_cover_artist, issue_editor, issue_story_arc, issue_characters, updated_at"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))"
        )
    );
    query.addBindValue(seriesNameKey);
    query.addBindValue(seriesGroupKey);
    query.addBindValue(seriesName);
    query.addBindValue(volume);
    query.addBindValue(issueKey);
    query.addBindValue(issueNumber);
    query.addBindValue(title);
    query.addBindValue(publisher);
    query.addBindValue(normalizedYear.isEmpty() ? QVariant() : QVariant(normalizedYear.toInt()));
    query.addBindValue(normalizedMonth.isEmpty() ? QVariant() : QVariant(normalizedMonth.toInt()));
    query.addBindValue(ageRating);
    query.addBindValue(writer);
    query.addBindValue(penciller);
    query.addBindValue(inker);
    query.addBindValue(colorist);
    query.addBindValue(letterer);
    query.addBindValue(coverArtist);
    query.addBindValue(editor);
    query.addBindValue(storyArc);
    query.addBindValue(characters);
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to save issue knowledge: %1").arg(query.lastError().text());
        db.close();
        return error;
    }

    db.close();
    return {};
}

QString removeSeriesMetadataForKey(const QString &dbPath, const QString &seriesKey)
{
    const QString key = seriesKey.trimmed();
    if (key.isEmpty()) return QStringLiteral("Series key is required.");

    const QString connectionName = QStringLiteral("comic_pile_series_metadata_remove_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureSeriesMetadataTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    SeriesMetadataRecord emptyRecord;
    QString writeError;
    if (!writeSeriesMetadataRecord(db, key, emptyRecord, writeError)) {
        db.close();
        return writeError;
    }

    db.close();
    return {};
}

} // namespace ComicLibraryQueries
