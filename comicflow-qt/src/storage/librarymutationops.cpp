#include "storage/librarymutationops.h"

#include <algorithm>

#include "common/scopedsqlconnectionremoval.h"
#include "storage/deletestagingops.h"
#include "storage/importmatching.h"
#include "storage/librarylayoututils.h"
#include "storage/libraryschemamanager.h"
#include "storage/sqliteconnectionutils.h"
#include "storage/storedpathutils.h"

#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
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
            "COALESCE(series_genres, ''), COALESCE(series_volume, ''), COALESCE(series_publisher, ''), "
            "COALESCE(series_age_rating, ''), COALESCE(series_header_cover_path, ''), "
            "COALESCE(series_header_background_path, '') "
            "FROM series_metadata WHERE series_group_key = ? LIMIT 1"
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
            "series_volume, series_publisher, series_age_rating, series_header_cover_path, "
            "series_header_background_path, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))"
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

struct BulkUpdateSnapshot {
    int id = 0;
    QString filePath;
    QString filename;
    QString series;
    QString volume;
    QString title;
    QString issueNumber;
    QString publisher;
    int year = 0;
    int month = 0;
    QString writer;
    QString penciller;
    QString inker;
    QString colorist;
    QString letterer;
    QString coverArtist;
    QString editor;
    QString storyArc;
    QString summary;
    QString characters;
    QString genres;
    QString ageRating;
    QString readStatus;
    int currentPage = 0;
};

QString joinIssueIds(const QVector<int> &ids)
{
    QStringList parts;
    parts.reserve(ids.size());
    for (int id : ids) {
        parts.push_back(QString::number(id));
    }
    return parts.join(QStringLiteral(", "));
}

bool loadBulkUpdateSnapshots(
    QSqlDatabase &db,
    const QVector<int> &ids,
    QHash<int, BulkUpdateSnapshot> &snapshotsOut,
    QString &errorText
)
{
    snapshotsOut.clear();
    if (ids.isEmpty()) return true;

    QStringList placeholders;
    placeholders.reserve(ids.size());
    for (int i = 0; i < ids.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "SELECT "
            "id, "
            "COALESCE(file_path, ''), COALESCE(filename, ''), "
            "COALESCE(series, ''), COALESCE(volume, ''), COALESCE(title, ''), "
            "COALESCE(issue_number, issue, ''), COALESCE(publisher, ''), "
            "COALESCE(year, 0), COALESCE(month, 0), "
            "COALESCE(writer, ''), COALESCE(penciller, ''), COALESCE(inker, ''), "
            "COALESCE(colorist, ''), COALESCE(letterer, ''), COALESCE(cover_artist, ''), "
            "COALESCE(editor, ''), COALESCE(story_arc, ''), COALESCE(summary, ''), "
            "COALESCE(characters, ''), COALESCE(genres, ''), COALESCE(age_rating, ''), "
            "COALESCE(read_status, 'unread'), COALESCE(current_page, 0) "
            "FROM comics "
            "WHERE id IN (%1)"
        ).arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : ids) {
        query.addBindValue(id);
    }
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to load bulk update targets: %1").arg(query.lastError().text());
        return false;
    }

    while (query.next()) {
        BulkUpdateSnapshot row;
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
        snapshotsOut.insert(row.id, row);
    }

    return true;
}

QString normalizedPathForCompare(const QString &path)
{
    return ComicLibraryLayout::normalizedPathForCompare(path);
}

bool filePathExists(const QString &filePath)
{
    const QString normalized = QDir::toNativeSeparators(filePath.trimmed());
    if (normalized.isEmpty()) return false;
    const QFileInfo info(normalized);
    return info.exists() && info.isFile();
}

QString buildSeriesGroupKey(const QString &series, const QString &volume)
{
    const QString normalizedSeriesKey = ComicImportMatching::normalizeSeriesKey(series);
    const QString volumeGroupKey = ComicImportMatching::normalizeVolumeKey(volume);
    if (volumeGroupKey == QStringLiteral("__no_volume__")) {
        return normalizedSeriesKey;
    }
    return QStringLiteral("%1::vol::%2").arg(normalizedSeriesKey, volumeGroupKey);
}

QString resolveStoredArchivePathForDataRoot(
    const QString &dataRoot,
    const QString &storedFilePath,
    const QString &storedFilename
)
{
    return ComicStoragePaths::resolveStoredArchivePath(dataRoot, storedFilePath, storedFilename);
}

QString relativeDirUnderRoot(const QString &rootPath, const QString &filePath)
{
    return ComicLibraryLayout::relativeDirUnderRoot(rootPath, filePath);
}

QString makeUniqueFilename(const QDir &dir, const QString &filename)
{
    return ComicLibraryLayout::makeUniqueFilename(dir, filename);
}

bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText)
{
    return ComicLibraryLayout::moveFileWithFallback(sourcePath, targetPath, errorText);
}

void cleanupEmptyLibraryDirs(const QString &libraryRootPath, const QStringList &candidateDirs)
{
    ComicDeleteOps::cleanupEmptyLibraryDirs(libraryRootPath, candidateDirs);
}

using SeriesFolderState = ComicLibraryLayout::SeriesFolderState;

} // namespace

namespace ComicLibraryMutationOps {

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
    if (!hasSeriesTitle && !hasSummary && !hasYear && !hasMonth && !hasGenres
        && !hasVolume && !hasPublisher && !hasAgeRating
        && !hasHeaderCoverPath && !hasHeaderBackgroundPath) {
        return {};
    }

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

    if (hasSeriesTitle) record.seriesTitle = valueFromMap(values, QStringLiteral("seriesTitle"));
    if (hasSummary) record.summary = valueFromMap(values, QStringLiteral("summary"));
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
    if (hasGenres) record.genres = valueFromMap(values, QStringLiteral("genres"));
    if (hasVolume) record.volume = ComicImportMatching::semanticVolumeValue(valueFromMap(values, QStringLiteral("volume")));
    if (hasPublisher) record.publisher = valueFromMap(values, QStringLiteral("publisher"));
    if (hasAgeRating) record.ageRating = valueFromMap(values, QStringLiteral("ageRating"));
    if (hasHeaderCoverPath) record.headerCoverPath = valueFromMap(values, QStringLiteral("headerCoverPath"));
    if (hasHeaderBackgroundPath) record.headerBackgroundPath = valueFromMap(values, QStringLiteral("headerBackgroundPath"));

    QString writeError;
    if (!writeSeriesMetadataRecord(db, key, record, writeError)) {
        db.close();
        return writeError;
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

QString setIssueMetadataKnowledge(const QString &dbPath, const QVariantMap &values)
{
    const QString seriesName = valueFromMap(values, QStringLiteral("series"));
    const QString volume = ComicImportMatching::semanticVolumeValue(valueFromMap(values, QStringLiteral("volume")));
    const QString issueNumber = ComicImportMatching::normalizeStoredIssueNumber(
        valueFromMap(values, QStringLiteral("issueNumber"))
    );
    const QString seriesNameKey = ComicImportMatching::normalizeSeriesKey(seriesName);
    const QString normalizedVolumeKey = ComicImportMatching::normalizeVolumeKey(volume);
    const QString seriesGroupKey = seriesNameKey.isEmpty()
        ? QString()
        : (normalizedVolumeKey == QStringLiteral("__no_volume__")
            ? seriesNameKey
            : QStringLiteral("%1::vol::%2").arg(seriesNameKey, normalizedVolumeKey));
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
            "issue_title, issue_publisher, issue_year, issue_month, issue_age_rating, issue_writer, "
            "issue_penciller, issue_inker, issue_colorist, issue_letterer, issue_cover_artist, "
            "issue_editor, issue_story_arc, issue_characters, updated_at"
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

BulkMetadataUpdateOutcome applyBulkMetadataUpdate(
    const QString &dbPath,
    const QString &dataRoot,
    const QVector<BulkMetadataRuntimeRow> &runtimeRows,
    const BulkMetadataUpdatePlan &plan
)
{
    BulkMetadataUpdateOutcome outcome;
    if (plan.ids.isEmpty()) {
        outcome.error = QStringLiteral("No issues selected.");
        return outcome;
    }

    QStringList sets;
    if (plan.applySeries) sets << QStringLiteral("series = ?") << QStringLiteral("series_key = ?");
    if (plan.applyVolume) sets << QStringLiteral("volume = ?");
    if (plan.applyTitle) sets << QStringLiteral("title = ?");
    if (plan.applyIssueNumber) sets << QStringLiteral("issue_number = ?") << QStringLiteral("issue = ?");
    if (plan.applyPublisher) sets << QStringLiteral("publisher = ?");
    if (plan.applyYear) sets << QStringLiteral("year = ?");
    if (plan.applyMonth) sets << QStringLiteral("month = ?");
    if (plan.applyWriter) sets << QStringLiteral("writer = ?");
    if (plan.applyPenciller) sets << QStringLiteral("penciller = ?");
    if (plan.applyInker) sets << QStringLiteral("inker = ?");
    if (plan.applyColorist) sets << QStringLiteral("colorist = ?");
    if (plan.applyLetterer) sets << QStringLiteral("letterer = ?");
    if (plan.applyCoverArtist) sets << QStringLiteral("cover_artist = ?");
    if (plan.applyEditor) sets << QStringLiteral("editor = ?");
    if (plan.applyStoryArc) sets << QStringLiteral("story_arc = ?");
    if (plan.applySummary) sets << QStringLiteral("summary = ?");
    if (plan.applyCharacters) sets << QStringLiteral("characters = ?");
    if (plan.applyGenres) sets << QStringLiteral("genres = ?");
    if (plan.applyAgeRating) sets << QStringLiteral("age_rating = ?");
    if (plan.applyReadStatus) sets << QStringLiteral("read_status = ?");
    if (plan.applyCurrentPage) sets << QStringLiteral("current_page = ?");

    if (sets.isEmpty()) {
        outcome.error = QStringLiteral("Select at least one field to apply.");
        return outcome;
    }

    struct SeriesMoveOp {
        int id = 0;
        QString sourcePath;
        QString targetPath;
    };

    QVector<SeriesMoveOp> appliedSeriesMoves;
    QHash<int, QString> movedPathById;
    QHash<int, QString> movedFilenameById;
    QStringList moveCleanupDirs;
    QSet<QString> seriesHeroKeysToPurge;
    const QString libraryRootPath = QDir(dataRoot).filePath(QStringLiteral("Library"));

    auto rollbackSeriesMoves = [&]() -> QString {
        QStringList rollbackErrors;
        QStringList rollbackCleanupDirs = moveCleanupDirs;
        for (int i = appliedSeriesMoves.size() - 1; i >= 0; i -= 1) {
            const SeriesMoveOp &op = appliedSeriesMoves.at(i);
            QString rollbackError;
            if (!moveFileWithFallback(op.targetPath, op.sourcePath, rollbackError)) {
                rollbackErrors.push_back(
                    QStringLiteral("Issue %1: %2").arg(op.id).arg(rollbackError)
                );
            }
            rollbackCleanupDirs.push_back(QFileInfo(op.sourcePath).absolutePath());
            rollbackCleanupDirs.push_back(QFileInfo(op.targetPath).absolutePath());
        }
        if (!rollbackCleanupDirs.isEmpty()) {
            cleanupEmptyLibraryDirs(libraryRootPath, rollbackCleanupDirs);
        }
        return rollbackErrors.join(QLatin1Char('\n'));
    };

    auto failWithRollback = [&](const QString &baseError) -> BulkMetadataUpdateOutcome {
        BulkMetadataUpdateOutcome failedOutcome;
        failedOutcome.error = baseError;
        const QString rollbackError = rollbackSeriesMoves();
        if (!rollbackError.isEmpty()) {
            failedOutcome.error += QStringLiteral("\nRollback warning:\n%1").arg(rollbackError);
        }
        return failedOutcome;
    };

    const QString sql = QStringLiteral("UPDATE comics SET %1 WHERE id = ?").arg(sets.join(QStringLiteral(", ")));
    const QString normalizedSeriesValue = plan.applySeries
        ? ComicImportMatching::normalizeSeriesKey(plan.series)
        : QString();
    const QString connectionName = QStringLiteral("comic_pile_bulk_update_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        outcome.error = openError;
        return outcome;
    }

    QHash<int, BulkUpdateSnapshot> preflightRows;
    QString preflightError;
    if (!loadBulkUpdateSnapshots(db, plan.ids, preflightRows, preflightError)) {
        db.close();
        return failWithRollback(preflightError);
    }

    QVector<int> missingIds;
    for (int id : plan.ids) {
        if (!preflightRows.contains(id)) {
            missingIds.push_back(id);
        }
    }
    if (!missingIds.isEmpty()) {
        db.close();
        outcome.error = QStringLiteral(
            "Bulk edit stopped because %1 selected issue(s) no longer exist.\n"
            "Refresh the library and try again.\n"
            "Affected ids: %2"
        ).arg(missingIds.size()).arg(joinIssueIds(missingIds));
        return outcome;
    }

    QVector<int> staleIds;
    for (int id : plan.ids) {
        const BulkUpdateSnapshot row = preflightRows.value(id);
        const QString preflightPath = resolveStoredArchivePathForDataRoot(
            dataRoot,
            row.filePath,
            row.filename
        );
        if (preflightPath.isEmpty()) {
            staleIds.push_back(id);
        }
    }
    if (!staleIds.isEmpty()) {
        db.close();
        outcome.error = QStringLiteral(
            "Bulk edit stopped because some selected archive files are no longer available on disk.\n"
            "Refresh the library and try again.\n"
            "Affected ids: %1"
        ).arg(joinIssueIds(staleIds));
        return outcome;
    }

    if (plan.applySeries || plan.applyVolume) {
        for (int id : plan.ids) {
            const BulkUpdateSnapshot row = preflightRows.value(id);
            const QString oldSeriesKey = buildSeriesGroupKey(row.series, row.volume);
            const QString nextSeriesKey = buildSeriesGroupKey(
                plan.applySeries ? plan.series : row.series,
                plan.applyVolume ? plan.volume : row.volume
            );
            if (!oldSeriesKey.isEmpty() && oldSeriesKey != nextSeriesKey) {
                seriesHeroKeysToPurge.insert(oldSeriesKey);
            }
        }
    }

    if (plan.applySeries) {
        if (!QDir().mkpath(libraryRootPath)) {
            db.close();
            outcome.error = QStringLiteral("Bulk edit could not prepare the library folder for a series move.");
            return outcome;
        }

        QSet<int> selectedIdSet;
        selectedIdSet.reserve(plan.ids.size());
        for (int id : plan.ids) {
            selectedIdSet.insert(id);
        }

        SeriesFolderState folderState;
        for (const BulkMetadataRuntimeRow &row : runtimeRows) {
            const QString rowSeriesKey = ComicImportMatching::normalizeSeriesKey(row.series);
            const bool rowWillLeaveCurrentSeries =
                selectedIdSet.contains(row.id) && rowSeriesKey != normalizedSeriesValue;
            if (rowWillLeaveCurrentSeries) continue;

            if (row.filePath.trimmed().isEmpty()) continue;
            const QString relativeDir = relativeDirUnderRoot(libraryRootPath, row.filePath);
            if (relativeDir.isEmpty()) continue;
            ComicLibraryLayout::registerSeriesFolderAssignment(folderState, rowSeriesKey, relativeDir);
        }

        const QString targetFolderName = ComicLibraryLayout::assignSeriesFolderName(
            folderState,
            normalizedSeriesValue,
            plan.series
        );
        const QString targetDirPath = QDir(libraryRootPath).filePath(targetFolderName);
        const QDir targetDir(targetDirPath);

        for (int id : plan.ids) {
            const BulkUpdateSnapshot row = preflightRows.value(id);
            const QString sourcePath = resolveStoredArchivePathForDataRoot(
                dataRoot,
                row.filePath,
                row.filename
            );
            if (sourcePath.isEmpty()) continue;

            const QFileInfo sourceInfo(sourcePath);
            if (!sourceInfo.exists() || !sourceInfo.isFile()) {
                db.close();
                return failWithRollback(
                    QStringLiteral(
                        "Bulk edit stopped because issue %1 is missing its archive file on disk."
                    ).arg(id)
                );
            }

            QString filenameValue = row.filename.trimmed();
            if (filenameValue.isEmpty()) {
                filenameValue = sourceInfo.fileName();
            }
            if (filenameValue.isEmpty()) continue;

            QString targetPath = targetDir.filePath(filenameValue);
            const QString sourceKey = normalizedPathForCompare(sourcePath);
            QString targetKey = normalizedPathForCompare(targetPath);
            if (sourceKey != targetKey && QFileInfo::exists(targetPath)) {
                filenameValue = makeUniqueFilename(targetDir, filenameValue);
                targetPath = targetDir.filePath(filenameValue);
                targetKey = normalizedPathForCompare(targetPath);
            }

            if (sourceKey == targetKey) continue;

            QString moveError;
            if (!moveFileWithFallback(sourcePath, targetPath, moveError)) {
                db.close();
                return failWithRollback(
                    QStringLiteral("Bulk edit could not move issue %1 into the target series folder: %2")
                        .arg(id)
                        .arg(moveError)
                );
            }

            SeriesMoveOp op;
            op.id = id;
            op.sourcePath = QDir::toNativeSeparators(QFileInfo(sourcePath).absoluteFilePath());
            op.targetPath = QDir::toNativeSeparators(QFileInfo(targetPath).absoluteFilePath());
            appliedSeriesMoves.push_back(op);
            movedPathById.insert(id, op.targetPath);
            movedFilenameById.insert(id, filenameValue);
            moveCleanupDirs.push_back(sourceInfo.absolutePath());
        }
    }

    if (!db.transaction()) {
        const QString error = QStringLiteral("Bulk edit could not start saving changes: %1").arg(db.lastError().text());
        db.close();
        return failWithRollback(error);
    }

    QSqlQuery query(db);
    for (int id : plan.ids) {
        query.prepare(sql);
        if (plan.applySeries) {
            query.addBindValue(plan.series);
            query.addBindValue(normalizedSeriesValue);
        }
        if (plan.applyVolume) query.addBindValue(plan.volume);
        if (plan.applyTitle) query.addBindValue(plan.title);
        if (plan.applyIssueNumber) {
            query.addBindValue(plan.issueNumber);
            query.addBindValue(plan.issueNumber);
        }
        if (plan.applyPublisher) query.addBindValue(plan.publisher);
        if (plan.applyYear) {
            query.addBindValue(plan.yearIsNull ? QVariant() : QVariant(plan.parsedYear));
        }
        if (plan.applyMonth) {
            query.addBindValue(plan.monthIsNull ? QVariant() : QVariant(plan.parsedMonth));
        }
        if (plan.applyWriter) query.addBindValue(plan.writer);
        if (plan.applyPenciller) query.addBindValue(plan.penciller);
        if (plan.applyInker) query.addBindValue(plan.inker);
        if (plan.applyColorist) query.addBindValue(plan.colorist);
        if (plan.applyLetterer) query.addBindValue(plan.letterer);
        if (plan.applyCoverArtist) query.addBindValue(plan.coverArtist);
        if (plan.applyEditor) query.addBindValue(plan.editor);
        if (plan.applyStoryArc) query.addBindValue(plan.storyArc);
        if (plan.applySummary) query.addBindValue(plan.summary);
        if (plan.applyCharacters) query.addBindValue(plan.characters);
        if (plan.applyGenres) query.addBindValue(plan.genres);
        if (plan.applyAgeRating) query.addBindValue(plan.ageRating);
        if (plan.applyReadStatus) query.addBindValue(plan.readStatus.isEmpty() ? QStringLiteral("unread") : plan.readStatus);
        if (plan.applyCurrentPage) query.addBindValue(plan.currentPageIsNull ? 0 : plan.parsedCurrentPage);
        query.addBindValue(id);

        if (!query.exec()) {
            const QString error = QStringLiteral("Bulk edit failed while saving issue %1: %2")
                .arg(id)
                .arg(query.lastError().text());
            db.rollback();
            db.close();
            return failWithRollback(error);
        }
        query.finish();
    }

    if (!movedPathById.isEmpty()) {
        QSqlQuery moveQuery(db);
        moveQuery.prepare(QStringLiteral("UPDATE comics SET file_path = ?, filename = ? WHERE id = ?"));
        for (auto it = movedPathById.constBegin(); it != movedPathById.constEnd(); ++it) {
            const int id = it.key();
            moveQuery.bindValue(0, ComicStoragePaths::persistPathForDataRoot(dataRoot, it.value()));
            moveQuery.bindValue(1, movedFilenameById.value(id));
            moveQuery.bindValue(2, id);
            if (!moveQuery.exec()) {
                const QString error = QStringLiteral(
                    "Bulk edit moved an archive but could not save the new path for issue %1: %2"
                ).arg(id).arg(moveQuery.lastError().text());
                db.rollback();
                db.close();
                return failWithRollback(error);
            }
            moveQuery.finish();
        }
    }

    QHash<int, BulkUpdateSnapshot> verifyRows;
    QString verifyLoadError;
    if (!loadBulkUpdateSnapshots(db, plan.ids, verifyRows, verifyLoadError)) {
        db.rollback();
        db.close();
        return failWithRollback(verifyLoadError);
    }

    QStringList verifyFailures;
    auto appendTextMismatch = [&](int id, const QString &fieldName, const QString &expected, const QString &actual) {
        if (expected == actual) return;
        verifyFailures.push_back(
            QStringLiteral("Issue %1 %2 mismatch (expected \"%3\", got \"%4\").")
                .arg(id)
                .arg(fieldName, expected, actual)
        );
    };
    auto appendNumberMismatch = [&](int id, const QString &fieldName, int expected, int actual) {
        if (expected == actual) return;
        verifyFailures.push_back(
            QStringLiteral("Issue %1 %2 mismatch (expected %3, got %4).")
                .arg(id)
                .arg(fieldName)
                .arg(expected)
                .arg(actual)
        );
    };

    for (int id : plan.ids) {
        if (!verifyRows.contains(id)) {
            verifyFailures.push_back(QStringLiteral("Issue %1 disappeared during verification.").arg(id));
            continue;
        }

        const BulkUpdateSnapshot actual = verifyRows.value(id);
        if (plan.applySeries) appendTextMismatch(id, QStringLiteral("series"), plan.series, actual.series);
        if (plan.applyVolume) appendTextMismatch(id, QStringLiteral("volume"), plan.volume, actual.volume);
        if (plan.applyTitle) appendTextMismatch(id, QStringLiteral("title"), plan.title, actual.title);
        if (plan.applyIssueNumber) appendTextMismatch(id, QStringLiteral("issue number"), plan.issueNumber, actual.issueNumber);
        if (plan.applyPublisher) appendTextMismatch(id, QStringLiteral("publisher"), plan.publisher, actual.publisher);
        if (plan.applyYear) appendNumberMismatch(id, QStringLiteral("year"), plan.yearIsNull ? 0 : plan.parsedYear, actual.year);
        if (plan.applyMonth) appendNumberMismatch(id, QStringLiteral("month"), plan.monthIsNull ? 0 : plan.parsedMonth, actual.month);
        if (plan.applyWriter) appendTextMismatch(id, QStringLiteral("writer"), plan.writer, actual.writer);
        if (plan.applyPenciller) appendTextMismatch(id, QStringLiteral("penciller"), plan.penciller, actual.penciller);
        if (plan.applyInker) appendTextMismatch(id, QStringLiteral("inker"), plan.inker, actual.inker);
        if (plan.applyColorist) appendTextMismatch(id, QStringLiteral("colorist"), plan.colorist, actual.colorist);
        if (plan.applyLetterer) appendTextMismatch(id, QStringLiteral("letterer"), plan.letterer, actual.letterer);
        if (plan.applyCoverArtist) appendTextMismatch(id, QStringLiteral("cover artist"), plan.coverArtist, actual.coverArtist);
        if (plan.applyEditor) appendTextMismatch(id, QStringLiteral("editor"), plan.editor, actual.editor);
        if (plan.applyStoryArc) appendTextMismatch(id, QStringLiteral("story arc"), plan.storyArc, actual.storyArc);
        if (plan.applySummary) appendTextMismatch(id, QStringLiteral("summary"), plan.summary, actual.summary);
        if (plan.applyCharacters) appendTextMismatch(id, QStringLiteral("characters"), plan.characters, actual.characters);
        if (plan.applyGenres) appendTextMismatch(id, QStringLiteral("genres"), plan.genres, actual.genres);
        if (plan.applyAgeRating) appendTextMismatch(id, QStringLiteral("age rating"), plan.ageRating, actual.ageRating);
        if (plan.applyReadStatus) {
            appendTextMismatch(
                id,
                QStringLiteral("read status"),
                plan.readStatus.isEmpty() ? QStringLiteral("unread") : plan.readStatus,
                actual.readStatus
            );
        }
        if (plan.applyCurrentPage) {
            appendNumberMismatch(
                id,
                QStringLiteral("current page"),
                plan.currentPageIsNull ? 0 : plan.parsedCurrentPage,
                actual.currentPage
            );
        }

        if (movedPathById.contains(id)) {
            const QString expectedFilePath = movedPathById.value(id);
            const QString actualResolvedFilePath = resolveStoredArchivePathForDataRoot(
                dataRoot,
                actual.filePath,
                actual.filename
            );
            if (normalizedPathForCompare(expectedFilePath) != normalizedPathForCompare(actualResolvedFilePath)) {
                verifyFailures.push_back(
                    QStringLiteral("Issue %1 file path mismatch after move.").arg(id)
                );
            }
            if (!filePathExists(expectedFilePath)) {
                verifyFailures.push_back(
                    QStringLiteral("Issue %1 moved archive is missing after save.").arg(id)
                );
            }
            appendTextMismatch(id, QStringLiteral("filename"), movedFilenameById.value(id), actual.filename);
        } else if (
            (!actual.filePath.trimmed().isEmpty() || !actual.filename.trimmed().isEmpty())
            && resolveStoredArchivePathForDataRoot(dataRoot, actual.filePath, actual.filename).isEmpty()
        ) {
            verifyFailures.push_back(
                QStringLiteral("Issue %1 archive file is missing after save.").arg(id)
            );
        }
    }

    if (!verifyFailures.isEmpty()) {
        const int maxErrors = std::min(8, static_cast<int>(verifyFailures.size()));
        const QStringList head = verifyFailures.mid(0, maxErrors);
        const QString suffix = verifyFailures.size() > maxErrors
            ? QStringLiteral("\n... and %1 more").arg(verifyFailures.size() - maxErrors)
            : QString();
        const QString verifyError = QStringLiteral(
            "Bulk edit could not verify the saved result, so nothing was committed.\n%1%2"
        ).arg(head.join(QLatin1Char('\n'))).arg(suffix);
        db.rollback();
        db.close();
        return failWithRollback(verifyError);
    }

    if (!db.commit()) {
        const QString error = QStringLiteral("Bulk edit could not finalize the save: %1").arg(db.lastError().text());
        db.close();
        return failWithRollback(error);
    }

    db.close();

    if (!moveCleanupDirs.isEmpty()) {
        cleanupEmptyLibraryDirs(libraryRootPath, moveCleanupDirs);
    }

    outcome.movedPathById = movedPathById;
    outcome.movedFilenameById = movedFilenameById;
    outcome.seriesHeroKeysToPurge = seriesHeroKeysToPurge;
    return outcome;
}

} // namespace ComicLibraryMutationOps
