#include "storage/libraryschemamanager.h"
#include "storage/importmatching.h"
#include "storage/sqliteconnectionutils.h"
#include "common/scopedsqlconnectionremoval.h"

#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QRegularExpression>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QVector>
#include <QUuid>

namespace {

constexpr int kCurrentLibrarySchemaVersion = 8;

struct ComicsColumnSpec {
    const char *name;
    const char *addSql;
};

const ComicsColumnSpec kComicsSchemaV1Columns[] = {
    { "file_path", "TEXT DEFAULT ''" },
    { "filename", "TEXT DEFAULT ''" },
    { "series", "TEXT DEFAULT ''" },
    { "series_key", "TEXT DEFAULT ''" },
    { "volume", "TEXT DEFAULT ''" },
    { "title", "TEXT DEFAULT ''" },
    { "issue_number", "TEXT DEFAULT ''" },
    { "issue", "TEXT DEFAULT ''" },
    { "publisher", "TEXT DEFAULT ''" },
    { "year", "INTEGER" },
    { "month", "INTEGER" },
    { "writer", "TEXT DEFAULT ''" },
    { "penciller", "TEXT DEFAULT ''" },
    { "inker", "TEXT DEFAULT ''" },
    { "colorist", "TEXT DEFAULT ''" },
    { "letterer", "TEXT DEFAULT ''" },
    { "cover_artist", "TEXT DEFAULT ''" },
    { "editor", "TEXT DEFAULT ''" },
    { "story_arc", "TEXT DEFAULT ''" },
    { "summary", "TEXT DEFAULT ''" },
    { "characters", "TEXT DEFAULT ''" },
    { "genres", "TEXT DEFAULT ''" },
    { "age_rating", "TEXT DEFAULT ''" },
    { "read_status", "TEXT DEFAULT 'unread'" },
    { "current_page", "INTEGER DEFAULT 0" },
    { "bookmark_page", "INTEGER DEFAULT 0" },
    { "bookmark_added_at", "TEXT DEFAULT ''" },
    { "favorite_active", "INTEGER DEFAULT 0" },
    { "favorite_added_at", "TEXT DEFAULT ''" },
    { "added_date", "TEXT DEFAULT ''" },
};

const ComicsColumnSpec kComicsSchemaV3Columns[] = {
    { "import_original_filename", "TEXT DEFAULT ''" },
    { "import_strict_filename_signature", "TEXT DEFAULT ''" },
    { "import_loose_filename_signature", "TEXT DEFAULT ''" },
    { "import_source_type", "TEXT DEFAULT ''" },
};

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString normalizeSeriesKeyForSchema(const QString &value)
{
    return ComicImportMatching::normalizeSeriesKey(value);
}

QString normalizeImportSourceTypeForSchema(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("archive") || normalized == QStringLiteral("image_folder")) {
        return normalized;
    }
    return {};
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
        normalizeImportSourceTypeForSchema(row.importSourceType)
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

    return QStringLiteral("%1|%2|%3|%4|%5")
        .arg(seriesKey, volumeKey, issueKey, normalizeImportSourceTypeForSchema(row.importSourceType), identityKey);
}

QString comicsCreateTableV1Sql()
{
    return QStringLiteral(
        "CREATE TABLE IF NOT EXISTS comics ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "file_path TEXT DEFAULT '',"
        "filename TEXT DEFAULT '',"
        "series TEXT DEFAULT '',"
        "series_key TEXT DEFAULT '',"
        "volume TEXT DEFAULT '',"
        "title TEXT DEFAULT '',"
        "issue_number TEXT DEFAULT '',"
        "issue TEXT DEFAULT '',"
        "publisher TEXT DEFAULT '',"
        "year INTEGER,"
        "month INTEGER,"
        "writer TEXT DEFAULT '',"
        "penciller TEXT DEFAULT '',"
        "inker TEXT DEFAULT '',"
        "colorist TEXT DEFAULT '',"
        "letterer TEXT DEFAULT '',"
        "cover_artist TEXT DEFAULT '',"
        "editor TEXT DEFAULT '',"
        "story_arc TEXT DEFAULT '',"
        "summary TEXT DEFAULT '',"
        "characters TEXT DEFAULT '',"
        "genres TEXT DEFAULT '',"
        "age_rating TEXT DEFAULT '',"
        "read_status TEXT DEFAULT 'unread',"
        "current_page INTEGER DEFAULT 0,"
        "bookmark_page INTEGER DEFAULT 0,"
        "bookmark_added_at TEXT DEFAULT '',"
        "favorite_active INTEGER DEFAULT 0,"
        "favorite_added_at TEXT DEFAULT '',"
        "added_date TEXT DEFAULT (datetime('now'))"
        ")"
    );
}

bool execSqlStatement(
    QSqlDatabase &db,
    const QString &sql,
    const QString &context,
    QString &errorText
)
{
    QSqlQuery query(db);
    if (query.exec(sql)) return true;

    errorText = QStringLiteral("%1: %2").arg(context, query.lastError().text());
    return false;
}

bool readUserVersion(QSqlDatabase &db, int &versionOut, QString &errorText)
{
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("PRAGMA user_version"))) {
        errorText = QStringLiteral("Failed to read schema version: %1").arg(query.lastError().text());
        return false;
    }
    if (!query.next()) {
        errorText = QStringLiteral("Failed to read schema version row.");
        return false;
    }

    versionOut = query.value(0).toInt();
    return true;
}

bool writeUserVersion(QSqlDatabase &db, int version, QString &errorText)
{
    return execSqlStatement(
        db,
        QStringLiteral("PRAGMA user_version = %1").arg(version),
        QStringLiteral("Failed to write schema version"),
        errorText
    );
}

bool tableHasColumn(
    QSqlDatabase &db,
    const QString &tableName,
    const QString &columnName,
    bool &existsOut,
    QString &errorText
)
{
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("PRAGMA table_info(%1)").arg(tableName))) {
        errorText = QStringLiteral("Failed to inspect columns for '%1': %2")
            .arg(tableName, query.lastError().text());
        return false;
    }

    while (query.next()) {
        if (QString::compare(query.value(1).toString(), columnName, Qt::CaseInsensitive) == 0) {
            existsOut = true;
            return true;
        }
    }

    existsOut = false;
    return true;
}

} // namespace

LibrarySchemaManager::LibrarySchemaManager(QString dbPath)
    : m_dbPath(dbPath)
{
}

QString LibrarySchemaManager::ensureSchemaUpToDate() const
{
    const QFileInfo dbInfo(m_dbPath);
    if (!dbInfo.exists() || !dbInfo.isFile()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_schema_migrate_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    {
        QSqlDatabase db;
        if (!ComicStorageSqlite::openDatabaseConnection(db, m_dbPath, connectionName, openError)) {
            return openError;
        }

        int userVersion = 0;
        QString schemaError;
        if (!readUserVersion(db, userVersion, schemaError)) {
            db.close();
            return schemaError;
        }

        if (userVersion > kCurrentLibrarySchemaVersion) {
            db.close();
            return QStringLiteral(
                "Database schema version %1 is newer than this build supports (%2)."
            ).arg(userVersion).arg(kCurrentLibrarySchemaVersion);
        }

        if (userVersion < kCurrentLibrarySchemaVersion) {
            if (!db.transaction()) {
                const QString error = QStringLiteral("Failed to start schema migration transaction: %1")
                    .arg(db.lastError().text());
                db.close();
                return error;
            }

            for (int nextVersion = userVersion + 1; nextVersion <= kCurrentLibrarySchemaVersion; nextVersion += 1) {
                bool migrated = false;
                switch (nextVersion) {
                case 1:
                    migrated = migrateSchemaToVersion1(db, schemaError);
                    break;
                case 2:
                    migrated = migrateSchemaToVersion2(db, schemaError);
                    break;
                case 3:
                    migrated = migrateSchemaToVersion3(db, schemaError);
                    break;
                case 4:
                    migrated = migrateSchemaToVersion4(db, schemaError);
                    break;
                case 5:
                    migrated = migrateSchemaToVersion5(db, schemaError);
                    break;
                case 6:
                    migrated = migrateSchemaToVersion6(db, schemaError);
                    break;
                case 7:
                    migrated = migrateSchemaToVersion7(db, schemaError);
                    break;
                case 8:
                    migrated = migrateSchemaToVersion8(db, schemaError);
                    break;
                default:
                    schemaError = QStringLiteral("Unsupported schema migration target: %1").arg(nextVersion);
                    migrated = false;
                    break;
                }

                if (!migrated || !writeUserVersion(db, nextVersion, schemaError)) {
                    db.rollback();
                    db.close();
                    return schemaError;
                }
            }

            if (!db.commit()) {
                const QString error = QStringLiteral("Failed to commit schema migration: %1")
                    .arg(db.lastError().text());
                db.rollback();
                db.close();
                return error;
            }
        }

        if (!ensureSeriesMetadataTable(db, schemaError)
            || !ensureIssueMetadataKnowledgeTable(db, schemaError)
            || !execSqlStatement(
                db,
                QStringLiteral("DROP TABLE IF EXISTS file_fingerprint_history"),
                QStringLiteral("Failed to remove obsolete fingerprint history table"),
                schemaError)) {
            db.close();
            return schemaError;
        }

        db.close();
    }

    return {};
}

bool LibrarySchemaManager::ensureSeriesMetadataTable(QSqlDatabase &db, QString &errorText)
{
    QSqlQuery query(db);
    if (!query.exec(
            "CREATE TABLE IF NOT EXISTS series_metadata ("
            "series_group_key TEXT PRIMARY KEY, "
            "series_title TEXT NOT NULL DEFAULT '', "
            "series_summary TEXT NOT NULL DEFAULT '', "
            "series_year INTEGER, "
            "series_month INTEGER, "
            "series_genres TEXT NOT NULL DEFAULT '', "
            "series_volume TEXT NOT NULL DEFAULT '', "
            "series_publisher TEXT NOT NULL DEFAULT '', "
            "series_age_rating TEXT NOT NULL DEFAULT '', "
            "series_header_cover_path TEXT NOT NULL DEFAULT '', "
            "series_header_background_path TEXT NOT NULL DEFAULT '', "
            "updated_at TEXT NOT NULL DEFAULT (datetime('now'))"
            ")")) {
        errorText = QStringLiteral("Failed to ensure series metadata table: %1").arg(query.lastError().text());
        return false;
    }

    bool titleColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_title"), titleColumnExists, errorText)) {
        return false;
    }
    if (!titleColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_title TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_title"),
                errorText)) {
            return false;
        }
    }

    bool yearColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_year"), yearColumnExists, errorText)) {
        return false;
    }
    if (!yearColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_year INTEGER"),
                QStringLiteral("Failed to add series_metadata.series_year"),
                errorText)) {
            return false;
        }
    }

    bool monthColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_month"), monthColumnExists, errorText)) {
        return false;
    }
    if (!monthColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_month INTEGER"),
                QStringLiteral("Failed to add series_metadata.series_month"),
                errorText)) {
            return false;
        }
    }

    bool genresColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_genres"), genresColumnExists, errorText)) {
        return false;
    }
    if (!genresColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_genres TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_genres"),
                errorText)) {
            return false;
        }
    }

    bool volumeColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_volume"), volumeColumnExists, errorText)) {
        return false;
    }
    if (!volumeColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_volume TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_volume"),
                errorText)) {
            return false;
        }
    }

    bool publisherColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_publisher"), publisherColumnExists, errorText)) {
        return false;
    }
    if (!publisherColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_publisher TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_publisher"),
                errorText)) {
            return false;
        }
    }

    bool ageRatingColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_age_rating"), ageRatingColumnExists, errorText)) {
        return false;
    }
    if (!ageRatingColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_age_rating TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_age_rating"),
                errorText)) {
            return false;
        }
    }

    bool headerCoverPathColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_header_cover_path"), headerCoverPathColumnExists, errorText)) {
        return false;
    }
    if (!headerCoverPathColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_header_cover_path TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_header_cover_path"),
                errorText)) {
            return false;
        }
    }

    bool headerBackgroundPathColumnExists = false;
    if (!tableHasColumn(db, QStringLiteral("series_metadata"), QStringLiteral("series_header_background_path"), headerBackgroundPathColumnExists, errorText)) {
        return false;
    }
    if (!headerBackgroundPathColumnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE series_metadata ADD COLUMN series_header_background_path TEXT NOT NULL DEFAULT ''"),
                QStringLiteral("Failed to add series_metadata.series_header_background_path"),
                errorText)) {
            return false;
        }
    }
    return true;
}

bool LibrarySchemaManager::ensureIssueMetadataKnowledgeTable(QSqlDatabase &db, QString &errorText)
{
    if (!execSqlStatement(
            db,
            QStringLiteral(
                "CREATE TABLE IF NOT EXISTS issue_metadata_knowledge ("
                "series_name_key TEXT NOT NULL DEFAULT '', "
                "series_group_key TEXT NOT NULL DEFAULT '', "
                "series_title TEXT NOT NULL DEFAULT '', "
                "series_volume TEXT NOT NULL DEFAULT '', "
                "issue_key TEXT NOT NULL DEFAULT '', "
                "issue_number TEXT NOT NULL DEFAULT '', "
                "issue_title TEXT NOT NULL DEFAULT '', "
                "issue_publisher TEXT NOT NULL DEFAULT '', "
                "issue_year INTEGER, "
                "issue_month INTEGER, "
                "issue_age_rating TEXT NOT NULL DEFAULT '', "
                "issue_writer TEXT NOT NULL DEFAULT '', "
                "issue_penciller TEXT NOT NULL DEFAULT '', "
                "issue_inker TEXT NOT NULL DEFAULT '', "
                "issue_colorist TEXT NOT NULL DEFAULT '', "
                "issue_letterer TEXT NOT NULL DEFAULT '', "
                "issue_cover_artist TEXT NOT NULL DEFAULT '', "
                "issue_editor TEXT NOT NULL DEFAULT '', "
                "issue_story_arc TEXT NOT NULL DEFAULT '', "
                "issue_characters TEXT NOT NULL DEFAULT '', "
                "updated_at TEXT NOT NULL DEFAULT (datetime('now')), "
                "PRIMARY KEY (series_group_key, issue_key)"
                ")"
            ),
            QStringLiteral("Failed to ensure issue metadata knowledge table"),
            errorText)) {
        return false;
    }

    const QStringList indexSql = {
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_issue_metadata_knowledge_series_issue "
            "ON issue_metadata_knowledge (series_name_key, issue_key, updated_at)"
        ),
        QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_issue_metadata_knowledge_group "
            "ON issue_metadata_knowledge (series_group_key, updated_at)"
        )
    };
    for (const QString &sql : indexSql) {
        if (!execSqlStatement(
                db,
                sql,
                QStringLiteral("Failed to ensure issue metadata knowledge index"),
                errorText)) {
            return false;
        }
    }

    return true;
}

bool LibrarySchemaManager::migrateSchemaToVersion1(QSqlDatabase &db, QString &errorText) const
{
    if (!execSqlStatement(
            db,
            comicsCreateTableV1Sql(),
            QStringLiteral("Failed to ensure comics table"),
            errorText)) {
        return false;
    }

    for (const ComicsColumnSpec &column : kComicsSchemaV1Columns) {
        bool columnExists = false;
        if (!tableHasColumn(db, QStringLiteral("comics"), QString::fromUtf8(column.name), columnExists, errorText)) {
            return false;
        }
        if (columnExists) continue;

        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE comics ADD COLUMN %1 %2")
                    .arg(QString::fromUtf8(column.name), QString::fromUtf8(column.addSql)),
                QStringLiteral("Failed to add comics.%1").arg(QString::fromUtf8(column.name)),
                errorText)) {
            return false;
        }
    }

    if (!ensureSeriesMetadataTable(db, errorText)) {
        return false;
    }

    const QStringList normalizationSql = {
        QStringLiteral(
            "UPDATE comics "
            "SET issue_number = COALESCE(NULLIF(TRIM(issue_number), ''), COALESCE(issue, '')) "
            "WHERE issue_number IS NULL OR TRIM(issue_number) = ''"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET issue = COALESCE(NULLIF(TRIM(issue), ''), COALESCE(issue_number, '')) "
            "WHERE issue IS NULL OR TRIM(issue) = ''"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET read_status = 'unread' "
            "WHERE read_status IS NULL OR TRIM(read_status) = ''"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET current_page = 0 "
            "WHERE current_page IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET bookmark_page = 0 "
            "WHERE bookmark_page IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET bookmark_added_at = '' "
            "WHERE bookmark_added_at IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET favorite_active = 0 "
            "WHERE favorite_active IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET favorite_added_at = '' "
            "WHERE favorite_added_at IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET added_date = datetime('now') "
            "WHERE added_date IS NULL OR TRIM(added_date) = ''"
        ),
    };

    for (const QString &sql : normalizationSql) {
        if (!execSqlStatement(
                db,
                sql,
                QStringLiteral("Failed to normalize comics schema defaults"),
                errorText)) {
            return false;
        }
    }

    if (!backfillNormalizedSeriesKeys(db, errorText)) {
        return false;
    }

    return true;
}

bool LibrarySchemaManager::migrateSchemaToVersion2(QSqlDatabase &db, QString &errorText) const
{
    return ensureSeriesMetadataTable(db, errorText);
}

bool LibrarySchemaManager::migrateSchemaToVersion3(QSqlDatabase &db, QString &errorText) const
{
    for (const ComicsColumnSpec &column : kComicsSchemaV3Columns) {
        bool columnExists = false;
        if (!tableHasColumn(db, QStringLiteral("comics"), QString::fromUtf8(column.name), columnExists, errorText)) {
            return false;
        }
        if (columnExists) continue;

        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE comics ADD COLUMN %1 %2")
                    .arg(QString::fromUtf8(column.name), QString::fromUtf8(column.addSql)),
                QStringLiteral("Failed to add comics.%1").arg(QString::fromUtf8(column.name)),
                errorText)) {
            return false;
        }
    }

    return backfillImportSignals(db, errorText);
}

bool LibrarySchemaManager::migrateSchemaToVersion4(QSqlDatabase &db, QString &errorText) const
{
    Q_UNUSED(db);
    Q_UNUSED(errorText);
    return true;
}

bool LibrarySchemaManager::migrateSchemaToVersion5(QSqlDatabase &db, QString &errorText) const
{
    return pruneObviousDetachedRestoreDuplicates(db, errorText);
}

bool LibrarySchemaManager::migrateSchemaToVersion6(QSqlDatabase &db, QString &errorText) const
{
    bool columnExists = false;
    if (!tableHasColumn(db, QStringLiteral("comics"), QStringLiteral("bookmark_page"), columnExists, errorText)) {
        return false;
    }
    if (!columnExists) {
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE comics ADD COLUMN bookmark_page INTEGER DEFAULT 0"),
                QStringLiteral("Failed to add comics.bookmark_page"),
                errorText)) {
            return false;
        }
    }

    return execSqlStatement(
        db,
        QStringLiteral("UPDATE comics SET bookmark_page = 0 WHERE bookmark_page IS NULL"),
        QStringLiteral("Failed to normalize comics.bookmark_page"),
        errorText
    );
}

bool LibrarySchemaManager::migrateSchemaToVersion7(QSqlDatabase &db, QString &errorText) const
{
    struct ColumnSpec {
        const char *name;
        const char *sql;
    };

    const ColumnSpec columns[] = {
        { "bookmark_added_at", "TEXT DEFAULT ''" },
        { "favorite_active", "INTEGER DEFAULT 0" },
        { "favorite_added_at", "TEXT DEFAULT ''" },
    };

    for (const ColumnSpec &column : columns) {
        bool columnExists = false;
        if (!tableHasColumn(db, QStringLiteral("comics"), QString::fromUtf8(column.name), columnExists, errorText)) {
            return false;
        }
        if (columnExists) continue;
        if (!execSqlStatement(
                db,
                QStringLiteral("ALTER TABLE comics ADD COLUMN %1 %2")
                    .arg(QString::fromUtf8(column.name), QString::fromUtf8(column.sql)),
                QStringLiteral("Failed to add comics.%1").arg(QString::fromUtf8(column.name)),
                errorText)) {
            return false;
        }
    }

    const QStringList normalizationSql = {
        QStringLiteral(
            "UPDATE comics "
            "SET bookmark_added_at = '' "
            "WHERE bookmark_added_at IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET favorite_active = 0 "
            "WHERE favorite_active IS NULL"
        ),
        QStringLiteral(
            "UPDATE comics "
            "SET favorite_added_at = '' "
            "WHERE favorite_added_at IS NULL"
        )
    };

    for (const QString &sql : normalizationSql) {
        if (!execSqlStatement(
                db,
                sql,
                QStringLiteral("Failed to normalize comics filter state"),
                errorText)) {
            return false;
        }
    }

    return true;
}

bool LibrarySchemaManager::migrateSchemaToVersion8(QSqlDatabase &db, QString &errorText) const
{
    if (!ensureSeriesMetadataTable(db, errorText)) {
        return false;
    }
    return ensureIssueMetadataKnowledgeTable(db, errorText);
}

bool LibrarySchemaManager::backfillNormalizedSeriesKeys(QSqlDatabase &db, QString &errorText) const
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

        const QString normalizedSeries = normalizeSeriesKeyForSchema(series);
        updateQuery.bindValue(0, normalizedSeries);
        updateQuery.bindValue(1, comicId);
        if (!updateQuery.exec()) {
            errorText = QStringLiteral("Failed to backfill series_key for comic %1: %2")
                .arg(comicId)
                .arg(updateQuery.lastError().text());
            return false;
        }
    }

    return true;
}

bool LibrarySchemaManager::backfillImportSignals(QSqlDatabase &db, QString &errorText) const
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
        QString sourceType = normalizeImportSourceTypeForSchema(trimOrEmpty(selectQuery.value(6)));

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

bool LibrarySchemaManager::pruneObviousDetachedRestoreDuplicates(QSqlDatabase &db, QString &errorText) const
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
