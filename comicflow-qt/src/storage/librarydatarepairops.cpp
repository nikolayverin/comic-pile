#include "storage/librarydatarepairops.h"

#include "storage/importmatching.h"

#include <QFileInfo>
#include <QHash>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QVariant>
#include <QVector>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

struct DetachedRestoreCleanupRow {
    int id = 0;
    QString filename;
    QString importOriginalFilename;
    QString importStrictFilenameSignature;
    QString importLooseFilenameSignature;
    QString series;
    QString seriesKey;
    QString volume;
    QString title;
    QString issue;
    QString publisher;
    QString year;
    QString month;
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
    QString currentPage;
    QString importSourceType;
};

QString detachedRestoreEffectiveLabel(const DetachedRestoreCleanupRow &row)
{
    const QString original = row.importOriginalFilename.trimmed();
    if (!original.isEmpty()) {
        return original;
    }
    return row.filename.trimmed();
}

QString detachedRestoreEffectiveStrictSignature(const DetachedRestoreCleanupRow &row)
{
    const QString stored = row.importStrictFilenameSignature.trimmed().toLower();
    if (!stored.isEmpty()) {
        return stored;
    }
    const QString label = detachedRestoreEffectiveLabel(row);
    if (label.isEmpty()) {
        return {};
    }
    return ComicImportMatching::normalizeFilenameSignatureStrict(label);
}

QString detachedRestoreEffectiveLooseSignature(const DetachedRestoreCleanupRow &row)
{
    const QString stored = row.importLooseFilenameSignature.trimmed().toLower();
    if (!stored.isEmpty()) {
        return stored;
    }
    const QString label = detachedRestoreEffectiveLabel(row);
    if (label.isEmpty()) {
        return {};
    }
    return ComicImportMatching::normalizeFilenameSignatureLoose(label);
}

QString detachedRestoreSnapshotKey(const DetachedRestoreCleanupRow &row)
{
    const QStringList parts = {
        row.filename.trimmed(),
        row.importOriginalFilename.trimmed(),
        row.importStrictFilenameSignature.trimmed().toLower(),
        row.importLooseFilenameSignature.trimmed().toLower(),
        row.series.trimmed(),
        row.seriesKey.trimmed().toLower(),
        row.volume.trimmed(),
        row.title.trimmed(),
        row.issue.trimmed(),
        row.publisher.trimmed(),
        row.year.trimmed(),
        row.month.trimmed(),
        row.writer.trimmed(),
        row.penciller.trimmed(),
        row.inker.trimmed(),
        row.colorist.trimmed(),
        row.letterer.trimmed(),
        row.coverArtist.trimmed(),
        row.editor.trimmed(),
        row.storyArc.trimmed(),
        row.summary.trimmed(),
        row.characters.trimmed(),
        row.genres.trimmed(),
        row.ageRating.trimmed(),
        row.readStatus.trimmed().toLower(),
        row.currentPage.trimmed(),
        ComicImportMatching::normalizeImportSourceType(row.importSourceType)
    };
    return parts.join(QStringLiteral("\x1f"));
}

QString detachedRestoreCleanupGroupKey(const DetachedRestoreCleanupRow &row)
{
    const QString seriesKey = row.seriesKey.trimmed().toLower();
    const QString issueKey = ComicImportMatching::normalizeIssueKey(row.issue);
    if (seriesKey.isEmpty() || issueKey.isEmpty()) {
        return {};
    }

    const QString volumeKey = ComicImportMatching::normalizeVolumeKey(row.volume);
    const QString strictSignature = detachedRestoreEffectiveStrictSignature(row);
    const QString looseSignature = detachedRestoreEffectiveLooseSignature(row);

    QString identityKey;
    if (!strictSignature.isEmpty() && !looseSignature.isEmpty()) {
        identityKey = QStringLiteral("sig:%1|%2").arg(strictSignature, looseSignature);
    } else {
        const QString label = detachedRestoreEffectiveLabel(row).trimmed().toLower();
        if (label.isEmpty()) {
            return {};
        }
        identityKey = QStringLiteral("name:%1").arg(label);
    }

    return QStringLiteral("%1|%2|%3|%4|%5").arg(
        seriesKey,
        volumeKey,
        issueKey,
        ComicImportMatching::normalizeImportSourceType(row.importSourceType),
        identityKey
    );
}

QString canonicalSeriesGroupKey(const QString &currentGroupKey, const QString &volume)
{
    const QString trimmedKey = currentGroupKey.trimmed();
    if (trimmedKey.isEmpty()) {
        return {};
    }

    if (!ComicImportMatching::semanticVolumeValue(volume).isEmpty()) {
        return trimmedKey;
    }

    const QString marker = QStringLiteral("::vol::");
    const int markerIndex = trimmedKey.indexOf(marker);
    if (markerIndex < 0) {
        return trimmedKey;
    }

    return trimmedKey.left(markerIndex).trimmed();
}

} // namespace

namespace ComicLibraryDataRepair {

bool backfillNormalizedSeriesKeys(QSqlDatabase &db, QString &errorText)
{
    QSqlQuery selectQuery(db);
    selectQuery.prepare(
        QStringLiteral(
            "SELECT id, COALESCE(series, ''), COALESCE(series_key, '') "
            "FROM comics "
            "ORDER BY id"
        )
    );
    if (!selectQuery.exec()) {
        errorText = QStringLiteral("Failed to scan series keys for migration: %1")
            .arg(selectQuery.lastError().text());
        return false;
    }

    QSqlQuery updateQuery(db);
    updateQuery.prepare(
        QStringLiteral(
            "UPDATE comics "
            "SET series_key = ? "
            "WHERE id = ?"
        )
    );

    while (selectQuery.next()) {
        const int comicId = selectQuery.value(0).toInt();
        const QString series = trimOrEmpty(selectQuery.value(1));
        const QString existingSeriesKey = trimOrEmpty(selectQuery.value(2));
        if (!existingSeriesKey.isEmpty()) continue;

        updateQuery.bindValue(0, ComicImportMatching::normalizeSeriesKey(series));
        updateQuery.bindValue(1, comicId);
        if (!updateQuery.exec()) {
            errorText = QStringLiteral("Failed to backfill series_key for comic %1: %2")
                .arg(comicId)
                .arg(updateQuery.lastError().text());
            return false;
        }
        updateQuery.finish();
    }

    return true;
}

bool backfillImportSignals(QSqlDatabase &db, QString &errorText)
{
    QSqlQuery selectQuery(db);
    selectQuery.prepare(
        QStringLiteral(
            "SELECT id, "
            "COALESCE(import_original_filename, ''), COALESCE(filename, ''), COALESCE(file_path, ''), "
            "COALESCE(import_strict_filename_signature, ''), COALESCE(import_loose_filename_signature, ''), "
            "COALESCE(import_source_type, '') "
            "FROM comics "
            "ORDER BY id"
        )
    );
    if (!selectQuery.exec()) {
        errorText = QStringLiteral("Failed to scan import signals for migration: %1")
            .arg(selectQuery.lastError().text());
        return false;
    }

    QSqlQuery updateQuery(db);
    updateQuery.prepare(
        QStringLiteral(
            "UPDATE comics "
            "SET import_original_filename = ?, "
            "import_strict_filename_signature = ?, "
            "import_loose_filename_signature = ?, "
            "import_source_type = ? "
            "WHERE id = ?"
        )
    );

    while (selectQuery.next()) {
        const int comicId = selectQuery.value(0).toInt();
        QString importOriginalFilename = trimOrEmpty(selectQuery.value(1));
        const QString filename = trimOrEmpty(selectQuery.value(2));
        const QString filePath = trimOrEmpty(selectQuery.value(3));
        QString strictSignature = trimOrEmpty(selectQuery.value(4));
        QString looseSignature = trimOrEmpty(selectQuery.value(5));
        QString sourceType = ComicImportMatching::normalizeImportSourceType(trimOrEmpty(selectQuery.value(6)));

        if (importOriginalFilename.isEmpty()) {
            importOriginalFilename = filename;
        }
        if (importOriginalFilename.isEmpty() && !filePath.isEmpty()) {
            importOriginalFilename = QFileInfo(filePath).fileName().trimmed();
        }
        if (strictSignature.isEmpty()) {
            strictSignature = ComicImportMatching::normalizeFilenameSignatureStrict(importOriginalFilename);
        }
        if (looseSignature.isEmpty()) {
            looseSignature = ComicImportMatching::normalizeFilenameSignatureLoose(importOriginalFilename);
        }
        if (sourceType.isEmpty()
            && (!importOriginalFilename.isEmpty() || !filename.isEmpty() || !filePath.isEmpty())) {
            sourceType = QStringLiteral("archive");
        }

        updateQuery.bindValue(0, importOriginalFilename);
        updateQuery.bindValue(1, strictSignature);
        updateQuery.bindValue(2, looseSignature);
        updateQuery.bindValue(3, sourceType);
        updateQuery.bindValue(4, comicId);
        if (!updateQuery.exec()) {
            errorText = QStringLiteral("Failed to backfill import signals for comic %1: %2")
                .arg(comicId)
                .arg(updateQuery.lastError().text());
            return false;
        }
        updateQuery.finish();
    }

    return true;
}

bool pruneObviousDetachedRestoreDuplicates(QSqlDatabase &db, QString &errorText)
{
    QSqlQuery selectQuery(db);
    selectQuery.prepare(
        QStringLiteral(
            "SELECT "
            "id, "
            "COALESCE(filename, ''), "
            "COALESCE(import_original_filename, ''), "
            "COALESCE(import_strict_filename_signature, ''), "
            "COALESCE(import_loose_filename_signature, ''), "
            "COALESCE(series, ''), "
            "COALESCE(series_key, ''), "
            "COALESCE(volume, ''), "
            "COALESCE(title, ''), "
            "COALESCE(issue_number, issue, ''), "
            "COALESCE(publisher, ''), "
            "CASE WHEN year IS NULL THEN '' ELSE CAST(year AS TEXT) END, "
            "CASE WHEN month IS NULL THEN '' ELSE CAST(month AS TEXT) END, "
            "COALESCE(writer, ''), "
            "COALESCE(penciller, ''), "
            "COALESCE(inker, ''), "
            "COALESCE(colorist, ''), "
            "COALESCE(letterer, ''), "
            "COALESCE(cover_artist, ''), "
            "COALESCE(editor, ''), "
            "COALESCE(story_arc, ''), "
            "COALESCE(summary, ''), "
            "COALESCE(characters, ''), "
            "COALESCE(genres, ''), "
            "COALESCE(age_rating, ''), "
            "COALESCE(read_status, ''), "
            "CASE WHEN current_page IS NULL THEN '' ELSE CAST(current_page AS TEXT) END, "
            "COALESCE(import_source_type, '') "
            "FROM comics "
            "WHERE COALESCE(file_path, '') = '' "
            "ORDER BY id"
        )
    );
    if (!selectQuery.exec()) {
        errorText = QStringLiteral("Failed to scan detached restore rows for cleanup: %1")
            .arg(selectQuery.lastError().text());
        return false;
    }

    QHash<QString, int> canonicalIdByGroupAndSnapshot;
    QVector<int> duplicateIds;
    while (selectQuery.next()) {
        DetachedRestoreCleanupRow row;
        row.id = selectQuery.value(0).toInt();
        row.filename = trimOrEmpty(selectQuery.value(1));
        row.importOriginalFilename = trimOrEmpty(selectQuery.value(2));
        row.importStrictFilenameSignature = trimOrEmpty(selectQuery.value(3));
        row.importLooseFilenameSignature = trimOrEmpty(selectQuery.value(4));
        row.series = trimOrEmpty(selectQuery.value(5));
        row.seriesKey = trimOrEmpty(selectQuery.value(6));
        row.volume = trimOrEmpty(selectQuery.value(7));
        row.title = trimOrEmpty(selectQuery.value(8));
        row.issue = trimOrEmpty(selectQuery.value(9));
        row.publisher = trimOrEmpty(selectQuery.value(10));
        row.year = trimOrEmpty(selectQuery.value(11));
        row.month = trimOrEmpty(selectQuery.value(12));
        row.writer = trimOrEmpty(selectQuery.value(13));
        row.penciller = trimOrEmpty(selectQuery.value(14));
        row.inker = trimOrEmpty(selectQuery.value(15));
        row.colorist = trimOrEmpty(selectQuery.value(16));
        row.letterer = trimOrEmpty(selectQuery.value(17));
        row.coverArtist = trimOrEmpty(selectQuery.value(18));
        row.editor = trimOrEmpty(selectQuery.value(19));
        row.storyArc = trimOrEmpty(selectQuery.value(20));
        row.summary = trimOrEmpty(selectQuery.value(21));
        row.characters = trimOrEmpty(selectQuery.value(22));
        row.genres = trimOrEmpty(selectQuery.value(23));
        row.ageRating = trimOrEmpty(selectQuery.value(24));
        row.readStatus = trimOrEmpty(selectQuery.value(25));
        row.currentPage = trimOrEmpty(selectQuery.value(26));
        row.importSourceType = trimOrEmpty(selectQuery.value(27));

        const QString groupKey = detachedRestoreCleanupGroupKey(row);
        if (groupKey.isEmpty()) {
            continue;
        }

        const QString snapshotKey = detachedRestoreSnapshotKey(row);
        const QString dedupeKey = QStringLiteral("%1|%2").arg(groupKey, snapshotKey);
        if (canonicalIdByGroupAndSnapshot.contains(dedupeKey)) {
            duplicateIds.push_back(row.id);
            continue;
        }

        canonicalIdByGroupAndSnapshot.insert(dedupeKey, row.id);
    }

    if (duplicateIds.isEmpty()) {
        return true;
    }

    QStringList placeholders;
    placeholders.reserve(duplicateIds.size());
    for (int i = 0; i < duplicateIds.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery deleteComicsQuery(db);
    deleteComicsQuery.prepare(
        QStringLiteral("DELETE FROM comics WHERE id IN (%1)")
            .arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int duplicateId : duplicateIds) {
        deleteComicsQuery.addBindValue(duplicateId);
    }
    if (!deleteComicsQuery.exec()) {
        errorText = QStringLiteral("Failed to remove stale restore duplicates during migration: %1")
            .arg(deleteComicsQuery.lastError().text());
        return false;
    }

    return true;
}

bool canonicalizeDefaultVolumeOneMetadata(QSqlDatabase &db, QString &errorText)
{
    {
        QSqlQuery query(db);
        if (!query.exec(QStringLiteral(
                "SELECT series_group_key, COALESCE(series_title, ''), COALESCE(series_summary, ''), "
                "series_year, series_month, COALESCE(series_genres, ''), COALESCE(series_volume, ''), "
                "COALESCE(series_publisher, ''), COALESCE(series_age_rating, ''), "
                "COALESCE(series_header_cover_path, ''), COALESCE(series_header_background_path, ''), "
                "COALESCE(updated_at, datetime('now')) "
                "FROM series_metadata"))) {
            errorText = QStringLiteral("Failed to scan series metadata for default-volume repair: %1")
                .arg(query.lastError().text());
            return false;
        }

        struct SeriesRow {
            QString key;
            QString title;
            QString summary;
            QVariant year;
            QVariant month;
            QString genres;
            QString volume;
            QString publisher;
            QString ageRating;
            QString coverPath;
            QString backgroundPath;
            QString updatedAt;
        };
        QVector<SeriesRow> rows;
        while (query.next()) {
            SeriesRow row;
            row.key = trimOrEmpty(query.value(0));
            row.title = trimOrEmpty(query.value(1));
            row.summary = trimOrEmpty(query.value(2));
            row.year = query.value(3);
            row.month = query.value(4);
            row.genres = trimOrEmpty(query.value(5));
            row.volume = trimOrEmpty(query.value(6));
            row.publisher = trimOrEmpty(query.value(7));
            row.ageRating = trimOrEmpty(query.value(8));
            row.coverPath = trimOrEmpty(query.value(9));
            row.backgroundPath = trimOrEmpty(query.value(10));
            row.updatedAt = trimOrEmpty(query.value(11));
            rows.push_back(row);
        }
        query.finish();

        QSqlQuery upsert(db);
        upsert.prepare(QStringLiteral(
            "INSERT OR REPLACE INTO series_metadata ("
            "series_group_key, series_title, series_summary, series_year, series_month, series_genres, "
            "series_volume, series_publisher, series_age_rating, series_header_cover_path, "
            "series_header_background_path, updated_at"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        ));
        QSqlQuery remove(db);
        remove.prepare(QStringLiteral("DELETE FROM series_metadata WHERE series_group_key = ?"));

        for (const SeriesRow &row : rows) {
            const QString targetKey = canonicalSeriesGroupKey(row.key, row.volume);
            const QString targetVolume = ComicImportMatching::semanticVolumeValue(row.volume);
            if (targetKey == row.key && targetVolume == row.volume.trimmed()) {
                continue;
            }

            upsert.bindValue(0, targetKey);
            upsert.bindValue(1, row.title);
            upsert.bindValue(2, row.summary);
            upsert.bindValue(3, row.year);
            upsert.bindValue(4, row.month);
            upsert.bindValue(5, row.genres);
            upsert.bindValue(6, targetVolume);
            upsert.bindValue(7, row.publisher);
            upsert.bindValue(8, row.ageRating);
            upsert.bindValue(9, row.coverPath);
            upsert.bindValue(10, row.backgroundPath);
            upsert.bindValue(11, row.updatedAt);
            if (!upsert.exec()) {
                errorText = QStringLiteral("Failed to rewrite series metadata for default-volume repair: %1")
                    .arg(upsert.lastError().text());
                return false;
            }
            upsert.finish();

            if (row.key != targetKey) {
                remove.bindValue(0, row.key);
                if (!remove.exec()) {
                    errorText = QStringLiteral("Failed to remove legacy series metadata row during default-volume repair: %1")
                        .arg(remove.lastError().text());
                    return false;
                }
                remove.finish();
            }
        }
    }

    {
        QSqlQuery query(db);
        if (!query.exec(QStringLiteral(
                "SELECT series_name_key, series_group_key, COALESCE(series_title, ''), COALESCE(series_volume, ''), "
                "issue_key, COALESCE(issue_number, ''), COALESCE(issue_title, ''), COALESCE(issue_publisher, ''), "
                "issue_year, issue_month, COALESCE(issue_age_rating, ''), COALESCE(issue_writer, ''), "
                "COALESCE(issue_penciller, ''), COALESCE(issue_inker, ''), COALESCE(issue_colorist, ''), "
                "COALESCE(issue_letterer, ''), COALESCE(issue_cover_artist, ''), COALESCE(issue_editor, ''), "
                "COALESCE(issue_story_arc, ''), COALESCE(issue_characters, ''), COALESCE(updated_at, datetime('now')) "
                "FROM issue_metadata_knowledge"))) {
            errorText = QStringLiteral("Failed to scan issue knowledge for default-volume repair: %1")
                .arg(query.lastError().text());
            return false;
        }

        struct KnowledgeRow {
            QString seriesNameKey;
            QString groupKey;
            QString seriesTitle;
            QString volume;
            QString issueKey;
            QString issueNumber;
            QString issueTitle;
            QString issuePublisher;
            QVariant issueYear;
            QVariant issueMonth;
            QString ageRating;
            QString writer;
            QString penciller;
            QString inker;
            QString colorist;
            QString letterer;
            QString coverArtist;
            QString editor;
            QString storyArc;
            QString characters;
            QString updatedAt;
        };
        QVector<KnowledgeRow> rows;
        while (query.next()) {
            KnowledgeRow row;
            row.seriesNameKey = trimOrEmpty(query.value(0));
            row.groupKey = trimOrEmpty(query.value(1));
            row.seriesTitle = trimOrEmpty(query.value(2));
            row.volume = trimOrEmpty(query.value(3));
            row.issueKey = trimOrEmpty(query.value(4));
            row.issueNumber = trimOrEmpty(query.value(5));
            row.issueTitle = trimOrEmpty(query.value(6));
            row.issuePublisher = trimOrEmpty(query.value(7));
            row.issueYear = query.value(8);
            row.issueMonth = query.value(9);
            row.ageRating = trimOrEmpty(query.value(10));
            row.writer = trimOrEmpty(query.value(11));
            row.penciller = trimOrEmpty(query.value(12));
            row.inker = trimOrEmpty(query.value(13));
            row.colorist = trimOrEmpty(query.value(14));
            row.letterer = trimOrEmpty(query.value(15));
            row.coverArtist = trimOrEmpty(query.value(16));
            row.editor = trimOrEmpty(query.value(17));
            row.storyArc = trimOrEmpty(query.value(18));
            row.characters = trimOrEmpty(query.value(19));
            row.updatedAt = trimOrEmpty(query.value(20));
            rows.push_back(row);
        }
        query.finish();

        QSqlQuery upsert(db);
        upsert.prepare(QStringLiteral(
            "INSERT OR REPLACE INTO issue_metadata_knowledge ("
            "series_name_key, series_group_key, series_title, series_volume, issue_key, issue_number, "
            "issue_title, issue_publisher, issue_year, issue_month, issue_age_rating, issue_writer, "
            "issue_penciller, issue_inker, issue_colorist, issue_letterer, issue_cover_artist, "
            "issue_editor, issue_story_arc, issue_characters, updated_at"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        ));
        QSqlQuery remove(db);
        remove.prepare(QStringLiteral("DELETE FROM issue_metadata_knowledge WHERE series_group_key = ? AND issue_key = ?"));

        for (const KnowledgeRow &row : rows) {
            const QString targetKey = canonicalSeriesGroupKey(row.groupKey, row.volume);
            const QString targetVolume = ComicImportMatching::semanticVolumeValue(row.volume);
            if (targetKey == row.groupKey && targetVolume == row.volume.trimmed()) {
                continue;
            }

            upsert.bindValue(0, row.seriesNameKey);
            upsert.bindValue(1, targetKey);
            upsert.bindValue(2, row.seriesTitle);
            upsert.bindValue(3, targetVolume);
            upsert.bindValue(4, row.issueKey);
            upsert.bindValue(5, row.issueNumber);
            upsert.bindValue(6, row.issueTitle);
            upsert.bindValue(7, row.issuePublisher);
            upsert.bindValue(8, row.issueYear);
            upsert.bindValue(9, row.issueMonth);
            upsert.bindValue(10, row.ageRating);
            upsert.bindValue(11, row.writer);
            upsert.bindValue(12, row.penciller);
            upsert.bindValue(13, row.inker);
            upsert.bindValue(14, row.colorist);
            upsert.bindValue(15, row.letterer);
            upsert.bindValue(16, row.coverArtist);
            upsert.bindValue(17, row.editor);
            upsert.bindValue(18, row.storyArc);
            upsert.bindValue(19, row.characters);
            upsert.bindValue(20, row.updatedAt);
            if (!upsert.exec()) {
                errorText = QStringLiteral("Failed to rewrite issue knowledge for default-volume repair: %1")
                    .arg(upsert.lastError().text());
                return false;
            }
            upsert.finish();

            if (row.groupKey != targetKey) {
                remove.bindValue(0, row.groupKey);
                remove.bindValue(1, row.issueKey);
                if (!remove.exec()) {
                    errorText = QStringLiteral("Failed to remove legacy issue knowledge row during default-volume repair: %1")
                        .arg(remove.lastError().text());
                    return false;
                }
                remove.finish();
            }
        }
    }

    return true;
}

} // namespace ComicLibraryDataRepair
