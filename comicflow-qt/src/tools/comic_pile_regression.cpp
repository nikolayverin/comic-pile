#include "storage/comicslistmodel.h"
#include "storage/duplicaterestoreresolver.h"
#include "storage/importmatching.h"
#include "storage/libraryschemamanager.h"
#include "common/scopedsqlconnectionremoval.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QModelIndex>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTextStream>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QUuid>

namespace {

void printStepResult(const QString &name, bool ok, const QString &details = {})
{
    QTextStream out(stdout);
    QTextStream err(stderr);
    if (ok) {
        if (details.isEmpty()) {
            out << QString("[OK] %1\n").arg(name);
        } else {
            out << QString("[OK] %1: %2\n").arg(name, details);
        }
        out.flush();
        return;
    }

    err << QString("[FAIL] %1%2\n")
               .arg(name, details.isEmpty() ? QString() : QString(": %1").arg(details));
    err.flush();
}

QString findWorkspaceRoot()
{
    QDir dir(QDir::currentPath());
    for (int depth = 0; depth < 12; depth += 1) {
        const bool hasProject = QFileInfo::exists(dir.filePath("PROJECT_BIBLE.md"));
        const bool hasQtDir = QFileInfo::exists(dir.filePath("comicflow-qt/CMakeLists.txt"));
        if (hasProject && hasQtDir) {
            return dir.absolutePath();
        }
        if (!dir.cdUp()) break;
    }
    return {};
}

QString findSeedArchive(const QString &workspaceRoot)
{
    const QStringList candidateDirs = {
        QDir(workspaceRoot).filePath("Database/Library"),
        QDir(workspaceRoot).filePath("Database/SeedScrollTest"),
    };

    const QStringList preferredOrder = {
        "*.cbz",
        "*.zip",
        "*.cbr",
    };

    for (const QString &dirPath : candidateDirs) {
        QDir dir(dirPath);
        if (!dir.exists()) continue;
        for (const QString &pattern : preferredOrder) {
            const QStringList entries = dir.entryList({ pattern }, QDir::Files | QDir::NoSymLinks, QDir::Name);
            if (!entries.isEmpty()) {
                return dir.filePath(entries.first());
            }
        }
    }

    const QStringList recursiveRoots = {
        QDir(workspaceRoot).filePath("_tmp"),
        QDir(workspaceRoot).filePath("Library"),
        workspaceRoot,
    };
    for (const QString &rootPath : recursiveRoots) {
        if (!QFileInfo::exists(rootPath)) continue;

        QDirIterator it(
            rootPath,
            preferredOrder,
            QDir::Files | QDir::NoSymLinks,
            QDirIterator::Subdirectories
        );
        while (it.hasNext()) {
            const QString archivePath = it.next();
            const QString normalizedPath = QDir::fromNativeSeparators(archivePath);
            if (normalizedPath.contains(QStringLiteral("/_build/"), Qt::CaseInsensitive)
                || normalizedPath.contains(QStringLiteral("/tools/"), Qt::CaseInsensitive)
                || normalizedPath.contains(QStringLiteral("/.git/"), Qt::CaseInsensitive)) {
                continue;
            }
            return archivePath;
        }
    }

    return {};
}

bool copyFileStrict(const QString &sourcePath, const QString &targetPath, QString &error)
{
    QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        error = QString("Source file not found: %1").arg(sourcePath);
        return false;
    }

    QFileInfo targetInfo(targetPath);
    QDir targetDir = targetInfo.dir();
    if (!targetDir.exists() && !targetDir.mkpath(".")) {
        error = QString("Failed to create target directory: %1").arg(targetDir.absolutePath());
        return false;
    }

    QFile::remove(targetPath);
    if (!QFile::copy(sourcePath, targetPath)) {
        error = QString("Failed to copy %1 -> %2").arg(sourcePath, targetPath);
        return false;
    }
    return true;
}

bool initIsolatedDatabase(const QString &dbPath, const QString &legacyArchivePath, QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_smoke_init_db");
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open isolated DB: %1").arg(db.lastError().text());
            return false;
        }

        auto execSql = [&](const QString &sql) -> bool {
            QSqlQuery query(db);
            if (!query.exec(sql)) {
                error = QString("SQL failed: %1").arg(query.lastError().text());
                return false;
            }
            return true;
        };

        if (!execSql(
                "CREATE TABLE IF NOT EXISTS comics ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                "file_path TEXT DEFAULT '',"
                "filename TEXT DEFAULT '',"
                "series TEXT DEFAULT '',"
                "volume TEXT DEFAULT '',"
                "title TEXT DEFAULT '',"
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
                "age_rating TEXT DEFAULT ''"
                ")")) {
            db.close();
            return false;
        }

        auto insertLegacyComic = [&](const QVariant &filePath,
                                     const QString &filename,
                                     const QString &series,
                                     const QString &volume,
                                     const QString &title,
                                     const QString &issue,
                                     const QString &publisher,
                                     int year,
                                     int month) -> bool {
            QSqlQuery insertQuery(db);
            insertQuery.prepare(
                "INSERT INTO comics ("
                "file_path, filename, series, volume, title, issue, publisher, year, month, "
                "writer, penciller, inker, colorist, letterer, cover_artist, editor, story_arc, summary, characters, genres, age_rating"
                ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            );
            insertQuery.addBindValue(filePath);
            insertQuery.addBindValue(filename);
            insertQuery.addBindValue(series);
            insertQuery.addBindValue(volume);
            insertQuery.addBindValue(title);
            insertQuery.addBindValue(issue);
            insertQuery.addBindValue(publisher);
            insertQuery.addBindValue(year);
            insertQuery.addBindValue(month);
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            insertQuery.addBindValue(QString());
            if (!insertQuery.exec()) {
                error = QString("Failed to seed legacy DB row: %1").arg(insertQuery.lastError().text());
                return false;
            }
            return true;
        };

        if (!insertLegacyComic(
                QDir::toNativeSeparators(QFileInfo(legacyArchivePath).absoluteFilePath()),
                QFileInfo(legacyArchivePath).fileName(),
                QStringLiteral("Legacy Seed"),
                QStringLiteral("1"),
                QStringLiteral("Legacy Seed Issue"),
                QStringLiteral("7"),
                QStringLiteral("Legacy House"),
                1994,
                6)
            || !insertLegacyComic(
                QString(),
                QStringLiteral("legacy-duplicate-004.cbz"),
                QStringLiteral("Legacy Duplicate"),
                QStringLiteral("1"),
                QStringLiteral("Legacy Duplicate #004"),
                QStringLiteral("4"),
                QStringLiteral("Legacy House"),
                1999,
                1)
            || !insertLegacyComic(
                QString(),
                QStringLiteral("legacy-duplicate-004.cbz"),
                QStringLiteral("Legacy Duplicate"),
                QStringLiteral("1"),
                QStringLiteral("Legacy Duplicate #004"),
                QStringLiteral("4"),
                QStringLiteral("Legacy House"),
                1999,
                1)
            || !insertLegacyComic(
                QString(),
                QStringLiteral("legacy-duplicate-004.cbz"),
                QStringLiteral("Legacy Duplicate"),
                QStringLiteral("1"),
                QStringLiteral("Legacy Duplicate Variant"),
                QStringLiteral("4"),
                QStringLiteral("Legacy House"),
                1999,
                1)) {
            db.close();
            return false;
        }

        if (!execSql(QStringLiteral("PRAGMA user_version = 0"))) {
            db.close();
            return false;
        }

        db.close();
    }
    return true;
}

bool readUserVersionForDb(const QString &dbPath, int &versionOut, QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_regression_schema_version");
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open DB for schema version: %1").arg(db.lastError().text());
            return false;
        }

        QSqlQuery query(db);
        if (!query.exec(QStringLiteral("PRAGMA user_version")) || !query.next()) {
            error = QString("Failed to read PRAGMA user_version: %1").arg(query.lastError().text());
            db.close();
            return false;
        }

        versionOut = query.value(0).toInt();
        db.close();
    }
    return true;
}

bool tableExistsForDb(const QString &dbPath, const QString &tableName, bool &existsOut, QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_regression_table_exists_%1").arg(tableName);
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open DB for table inspect: %1").arg(db.lastError().text());
            return false;
        }

        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT 1 "
                "FROM sqlite_master "
                "WHERE type = 'table' AND name = ? "
                "LIMIT 1"
            )
        );
        query.addBindValue(tableName);
        if (!query.exec()) {
            error = QString("Failed to inspect table %1: %2").arg(tableName, query.lastError().text());
            db.close();
            return false;
        }

        existsOut = query.next();
        db.close();
    }
    return true;
}

bool tableHasColumnForDb(
    const QString &dbPath,
    const QString &tableName,
    const QString &columnName,
    bool &existsOut,
    QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_regression_table_column_%1_%2").arg(tableName, columnName);
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open DB for column inspect: %1").arg(db.lastError().text());
            return false;
        }

        QSqlQuery query(db);
        if (!query.exec(QStringLiteral("PRAGMA table_info(%1)").arg(tableName))) {
            error = QString("Failed to inspect columns for %1: %2").arg(tableName, query.lastError().text());
            db.close();
            return false;
        }

        existsOut = false;
        while (query.next()) {
            if (QString::compare(query.value(1).toString(), columnName, Qt::CaseInsensitive) == 0) {
                existsOut = true;
                break;
            }
        }

        db.close();
    }
    return true;
}

int countDetachedRestoreRowsWithTitle(
    const QString &dbPath,
    const QString &title,
    QString &error)
{
    error.clear();
    const QString connectionName = QStringLiteral("comic_pile_regression_detached_title_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open DB for detached title inspect: %1").arg(db.lastError().text());
            return -1;
        }

        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT COUNT(*) "
                "FROM comics "
                "WHERE COALESCE(file_path, '') = '' "
                "AND COALESCE(title, '') = ?"
            )
        );
        query.addBindValue(title);
        if (!query.exec() || !query.next()) {
            error = QString("Failed to inspect detached restore title rows: %1").arg(query.lastError().text());
            db.close();
            return -1;
        }

        const int count = query.value(0).toInt();
        db.close();
        return count;
    }
}

struct DirtyRestoreSeed {
    QVariant filePathValue;
    QString filename;
    QString series;
    QString seriesKey;
    QString volume;
    QString issue;
    QString title;
    QString importOriginalFilename;
    QString importStrictFilenameSignature;
    QString importLooseFilenameSignature;
    QString importSourceType;
};

bool insertDirtyRestoreRowEx(
    const QString &dbPath,
    const DirtyRestoreSeed &seed,
    int &idOut,
    QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_regression_insert_dirty_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open DB for dirty restore seed: %1").arg(db.lastError().text());
            return false;
        }

        QSqlQuery query(db);
        query.prepare(
            "INSERT INTO comics ("
            "file_path, filename, series, series_key, volume, title, issue_number, issue, "
            "publisher, year, month, read_status, current_page, added_date, "
            "import_original_filename, import_strict_filename_signature, import_loose_filename_signature, import_source_type"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), ?, ?, ?, ?)"
        );
        query.addBindValue(seed.filePathValue);
        query.addBindValue(seed.filename);
        query.addBindValue(seed.series);
        query.addBindValue(seed.seriesKey);
        query.addBindValue(seed.volume);
        query.addBindValue(seed.title.isEmpty() ? QStringLiteral("Dirty Restore Row") : seed.title);
        query.addBindValue(seed.issue);
        query.addBindValue(seed.issue);
        query.addBindValue(QStringLiteral("Regression Publisher"));
        query.addBindValue(2025);
        query.addBindValue(1);
        query.addBindValue(QStringLiteral("unread"));
        query.addBindValue(0);
        query.addBindValue(seed.importOriginalFilename);
        query.addBindValue(seed.importStrictFilenameSignature);
        query.addBindValue(seed.importLooseFilenameSignature);
        query.addBindValue(seed.importSourceType);
        if (!query.exec()) {
            error = QString("Failed to insert dirty restore row: %1").arg(query.lastError().text());
            db.close();
            return false;
        }

        idOut = query.lastInsertId().toInt();
        db.close();
    }
    return true;
}

bool insertDirtyRestoreRow(
    const QString &dbPath,
    const QString &filename,
    const QString &series,
    const QString &seriesKey,
    const QString &volume,
    const QString &issue,
    int &idOut,
    QString &error)
{
    const DirtyRestoreSeed seed = {
        QVariant(),
        filename,
        series,
        seriesKey,
        volume,
        issue,
        QStringLiteral("Dirty Restore Row"),
        QString(),
        QString(),
        QString(),
        QString()
    };
    return insertDirtyRestoreRowEx(dbPath, seed, idOut, error);
}

bool loadDetachedRestoreIdsForKey(
    const QString &dbPath,
    const QString &seriesKey,
    const QString &volume,
    const QString &issue,
    const QString &filename,
    QVector<int> &idsOut,
    QString &error)
{
    idsOut.clear();

    const QString connectionName = QStringLiteral("comic_pile_regression_load_detached_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open DB for detached restore inspect: %1").arg(db.lastError().text());
            return false;
        }

        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT id "
                "FROM comics "
                "WHERE series_key = ? "
                "AND COALESCE(volume, '') = ? "
                "AND COALESCE(issue_number, issue, '') = ? "
                "AND filename = ? COLLATE NOCASE "
                "AND COALESCE(file_path, '') = '' "
                "ORDER BY id ASC"
            )
        );
        query.addBindValue(seriesKey);
        query.addBindValue(volume);
        query.addBindValue(issue);
        query.addBindValue(filename);
        if (!query.exec()) {
            error = QString("Failed to inspect detached restore rows: %1").arg(query.lastError().text());
            db.close();
            return false;
        }

        while (query.next()) {
            idsOut.push_back(query.value(0).toInt());
        }

        db.close();
    }

    return true;
}

int roleIndex(const ComicsListModel &model, const QByteArray &roleName)
{
    const QHash<int, QByteArray> roles = model.roleNames();
    for (auto it = roles.constBegin(); it != roles.constEnd(); ++it) {
        if (it.value() == roleName) return it.key();
    }
    return -1;
}

QModelIndex findRowByComicId(const ComicsListModel &model, int idRole, int comicId)
{
    for (int row = 0; row < model.rowCount(); row += 1) {
        const QModelIndex idx = model.index(row, 0);
        if (model.data(idx, idRole).toInt() == comicId) {
            return idx;
        }
    }
    return {};
}

bool ensureImportSuccess(
    const QVariantMap &result,
    const QString &expectedCode,
    QString &errorOut
)
{
    const bool ok = result.value(QStringLiteral("ok")).toBool();
    const QString code = result.value(QStringLiteral("code")).toString();
    const QString error = result.value(QStringLiteral("error")).toString();
    if (!ok) {
        errorOut = QString("Import failed. code=%1, error=%2").arg(code, error);
        return false;
    }
    if (!expectedCode.isEmpty() && code != expectedCode) {
        errorOut = QString("Unexpected import code. expected=%1 actual=%2").arg(expectedCode, code);
        return false;
    }
    return true;
}

bool ensureImportFailureCode(
    const QVariantMap &result,
    const QString &expectedCode,
    QString &errorOut
)
{
    const bool ok = result.value(QStringLiteral("ok")).toBool();
    const QString code = result.value(QStringLiteral("code")).toString();
    if (ok) {
        errorOut = QString("Expected failure, got success code=%1").arg(code);
        return false;
    }
    if (!expectedCode.isEmpty() && code != expectedCode) {
        errorOut = QString("Unexpected failure code. expected=%1 actual=%2").arg(expectedCode, code);
        return false;
    }
    return true;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    const QString workspaceRoot = findWorkspaceRoot();
    if (workspaceRoot.isEmpty()) {
        printStepResult(QStringLiteral("Smoke setup: workspace root"), false, QStringLiteral("Could not locate project root."));
        return 1;
    }

    const QString seedArchivePath = findSeedArchive(workspaceRoot);
    if (seedArchivePath.isEmpty()) {
        printStepResult(QStringLiteral("Smoke setup: seed archive"), false, QStringLiteral("No .cbz/.zip/.cbr found in Database fixtures."));
        return 1;
    }

    QTemporaryDir sandbox;
    if (!sandbox.isValid()) {
        printStepResult(QStringLiteral("Smoke setup: temporary dir"), false, QStringLiteral("Failed to allocate temporary directory."));
        return 1;
    }
    const QString dataRoot = sandbox.path();
    const QString libraryDirPath = QDir(dataRoot).filePath(QStringLiteral("Library"));
    const QString incomingDirPath = QDir(dataRoot).filePath(QStringLiteral("Incoming"));
    if (!QDir().mkpath(libraryDirPath) || !QDir().mkpath(incomingDirPath)) {
        printStepResult(QStringLiteral("Smoke setup: directories"), false, QStringLiteral("Failed to create Library/Incoming directories."));
        return 1;
    }

    const QString dbPath = QDir(dataRoot).filePath(QStringLiteral("library.db"));
    const QString seedExt = QFileInfo(seedArchivePath).suffix().toLower();
    const QString legacyDirPath = QDir(libraryDirPath).filePath(QStringLiteral("Legacy Seed"));
    if (!QDir().mkpath(legacyDirPath)) {
        printStepResult(QStringLiteral("Smoke setup: directories"), false, QStringLiteral("Failed to create legacy library subdir."));
        return 1;
    }
    const QString legacyArchivePath = QDir(legacyDirPath).filePath(QStringLiteral("legacy-seed.%1").arg(seedExt));
    const QString incomingA = QDir(incomingDirPath).filePath(QStringLiteral("incoming_a.%1").arg(seedExt));
    const QString incomingB = QDir(incomingDirPath).filePath(QStringLiteral("incoming_b.%1").arg(seedExt));
    const QString incomingC = QDir(incomingDirPath).filePath(QStringLiteral("incoming_c.%1").arg(seedExt));
    const QString incomingSeries0015 = QDir(incomingDirPath).filePath(QStringLiteral("Regression.NumberClash_0015.%1").arg(seedExt));
    const QString incomingOtherSeries0015 = QDir(incomingDirPath).filePath(QStringLiteral("Other.NumberClash_0015.%1").arg(seedExt));
    const QString numericSeriesDirPath = QDir(incomingDirPath).filePath(QStringLiteral("Regression Numeric Series"));
    const QString incomingBare002 = QDir(numericSeriesDirPath).filePath(QStringLiteral("002.%1").arg(seedExt));
    const QString incomingBare2 = QDir(numericSeriesDirPath).filePath(QStringLiteral("2.%1").arg(seedExt));
    const QString incomingLegacyNormalized0015 = QDir(incomingDirPath).filePath(QStringLiteral("Legacy.Normalized_0015.%1").arg(seedExt));
    const QString incomingFilenamePriority0015 = QDir(incomingDirPath).filePath(QStringLiteral("Filename.Priority_0015.%1").arg(seedExt));
    const QString incomingMultiDot = QDir(incomingDirPath).filePath(QStringLiteral("Absolute.Batman_002_2025.%1").arg(seedExt));
    const QString incomingMultiDot003 = QDir(incomingDirPath).filePath(QStringLiteral("Absolute.Batman_003_2025.%1").arg(seedExt));
    QString setupError;
    if (!QDir().mkpath(numericSeriesDirPath)
        || !copyFileStrict(seedArchivePath, legacyArchivePath, setupError)
        || !copyFileStrict(seedArchivePath, incomingA, setupError)
        || !copyFileStrict(seedArchivePath, incomingB, setupError)
        || !copyFileStrict(seedArchivePath, incomingC, setupError)
        || !copyFileStrict(seedArchivePath, incomingSeries0015, setupError)
        || !copyFileStrict(seedArchivePath, incomingOtherSeries0015, setupError)
        || !copyFileStrict(seedArchivePath, incomingBare002, setupError)
        || !copyFileStrict(seedArchivePath, incomingBare2, setupError)
        || !copyFileStrict(seedArchivePath, incomingLegacyNormalized0015, setupError)
        || !copyFileStrict(seedArchivePath, incomingFilenamePriority0015, setupError)
        || !copyFileStrict(seedArchivePath, incomingMultiDot, setupError)
        || !copyFileStrict(seedArchivePath, incomingMultiDot003, setupError)) {
        printStepResult(QStringLiteral("Smoke setup: copy fixtures"), false, setupError);
        return 1;
    }

    if (!initIsolatedDatabase(dbPath, legacyArchivePath, setupError)) {
        printStepResult(QStringLiteral("Smoke setup: isolated DB"), false, setupError);
        return 1;
    }

    qputenv("COMIC_PILE_DATA_DIR", dataRoot.toUtf8());
    ComicsListModel model;
    if (!model.lastError().trimmed().isEmpty()) {
        printStepResult(QStringLiteral("Model load"), false, model.lastError());
        return 1;
    }

    const int expectedSchemaVersion = LibrarySchemaManager::currentSchemaVersion();
    int schemaVersion = 0;
    if (!readUserVersionForDb(dbPath, schemaVersion, setupError) || schemaVersion != expectedSchemaVersion) {
        printStepResult(
            QStringLiteral("Schema migration"),
            false,
            !setupError.isEmpty()
                ? setupError
                : QStringLiteral("Unexpected user_version=%1").arg(schemaVersion)
        );
        return 1;
    }

    bool tableExists = false;
    if (!tableExistsForDb(dbPath, QStringLiteral("series_metadata"), tableExists, setupError) || !tableExists) {
        printStepResult(
            QStringLiteral("Schema migration"),
            false,
            !setupError.isEmpty()
                ? setupError
                : QStringLiteral("series_metadata table missing after migration.")
        );
        return 1;
    }
    bool seriesTitleColumnExists = false;
    if (!tableHasColumnForDb(dbPath, QStringLiteral("series_metadata"), QStringLiteral("series_title"), seriesTitleColumnExists, setupError) || !seriesTitleColumnExists) {
        printStepResult(
            QStringLiteral("Schema migration"),
            false,
            !setupError.isEmpty()
                ? setupError
                : QStringLiteral("Missing series_metadata.series_title after migration.")
        );
        return 1;
    }
    const QStringList requiredSeriesMetadataColumns = {
        QStringLiteral("series_year"),
        QStringLiteral("series_month"),
        QStringLiteral("series_genres"),
        QStringLiteral("series_volume"),
        QStringLiteral("series_publisher"),
        QStringLiteral("series_age_rating"),
        QStringLiteral("series_header_cover_path"),
        QStringLiteral("series_header_background_path"),
    };
    for (const QString &columnName : requiredSeriesMetadataColumns) {
        bool columnExists = false;
        if (!tableHasColumnForDb(dbPath, QStringLiteral("series_metadata"), columnName, columnExists, setupError) || !columnExists) {
            printStepResult(
                QStringLiteral("Schema migration"),
                false,
                !setupError.isEmpty()
                    ? setupError
                    : QStringLiteral("Missing series_metadata.%1 after migration.").arg(columnName)
            );
            return 1;
        }
    }
    bool issueMetadataKnowledgeExists = false;
    if (!tableExistsForDb(dbPath, QStringLiteral("issue_metadata_knowledge"), issueMetadataKnowledgeExists, setupError) || !issueMetadataKnowledgeExists) {
        printStepResult(
            QStringLiteral("Schema migration"),
            false,
            !setupError.isEmpty()
                ? setupError
                : QStringLiteral("issue_metadata_knowledge table missing after migration.")
        );
        return 1;
    }

    const QStringList requiredColumns = {
        QStringLiteral("series_key"),
        QStringLiteral("issue_number"),
        QStringLiteral("read_status"),
        QStringLiteral("current_page"),
        QStringLiteral("bookmark_page"),
        QStringLiteral("bookmark_added_at"),
        QStringLiteral("favorite_active"),
        QStringLiteral("favorite_added_at"),
        QStringLiteral("added_date"),
        QStringLiteral("import_original_filename"),
        QStringLiteral("import_strict_filename_signature"),
        QStringLiteral("import_loose_filename_signature"),
        QStringLiteral("import_source_type"),
    };
    for (const QString &columnName : requiredColumns) {
        bool columnExists = false;
    if (!tableHasColumnForDb(dbPath, QStringLiteral("comics"), columnName, columnExists, setupError) || !columnExists) {
        printStepResult(
            QStringLiteral("Schema migration"),
            false,
                !setupError.isEmpty()
                    ? setupError
                    : QStringLiteral("Missing comics.%1 after migration.").arg(columnName)
            );
            return 1;
        }
    }

    const QVariantMap legacyMeta = model.loadComicMetadata(1);
    if (!legacyMeta.value(QStringLiteral("error")).toString().isEmpty()
        || legacyMeta.value(QStringLiteral("issueNumber")).toString() != QStringLiteral("7")
        || legacyMeta.value(QStringLiteral("readStatus")).toString() != QStringLiteral("unread")
        || legacyMeta.value(QStringLiteral("currentPage")).toInt() != 0
        || legacyMeta.value(QStringLiteral("bookmarkPage")).toInt() != 0
        || legacyMeta.value(QStringLiteral("favoriteActive")).toBool()
        || legacyMeta.value(QStringLiteral("importOriginalFilename")).toString().isEmpty()
        || legacyMeta.value(QStringLiteral("importStrictFilenameSignature")).toString().isEmpty()
        || legacyMeta.value(QStringLiteral("importLooseFilenameSignature")).toString().isEmpty()
        || legacyMeta.value(QStringLiteral("importSourceType")).toString() != QStringLiteral("archive")
        || !QFileInfo::exists(legacyMeta.value(QStringLiteral("filePath")).toString())) {
        printStepResult(QStringLiteral("Schema migration"), false, QStringLiteral("Legacy row was not upgraded correctly."));
        return 1;
    }
    printStepResult(QStringLiteral("Schema migration"), true);

    QVector<int> legacyDetachedDuplicateIds;
    if (!loadDetachedRestoreIdsForKey(
            dbPath,
            QStringLiteral("legacy duplicate"),
            QStringLiteral("1"),
            QStringLiteral("4"),
            QStringLiteral("legacy-duplicate-004.cbz"),
            legacyDetachedDuplicateIds,
            setupError
        )) {
        printStepResult(QStringLiteral("Schema cleanup"), false, setupError);
        return 1;
    }
    if (legacyDetachedDuplicateIds.size() != 2) {
        printStepResult(
            QStringLiteral("Schema cleanup"),
            false,
            QStringLiteral("Expected migration cleanup to collapse only one obvious detached duplicate, leaving 2 rows.")
        );
        return 1;
    }
    if (countDetachedRestoreRowsWithTitle(dbPath, QStringLiteral("Legacy Duplicate Variant"), setupError) != 1) {
        printStepResult(
            QStringLiteral("Schema cleanup"),
            false,
            !setupError.isEmpty()
                ? setupError
                : QStringLiteral("Ambiguous detached variant row should survive migration cleanup.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Schema cleanup"), true);

    {
        const DuplicateRestoreResolver::RestoreMatchInput input = {
            QStringLiteral("absolute batman"),
            QStringLiteral("2"),
            QStringLiteral("1"),
            QStringLiteral("2"),
            QStringLiteral("1")
        };
        const QVector<DuplicateRestoreResolver::RestoreCandidate> candidates = {
            { 101, QString(), QString(), QStringLiteral("Absolute Batman"), QStringLiteral("absolute batman"), QStringLiteral("1"), QStringLiteral("2") },
            { 102, QString(), QString(), QStringLiteral("Absolute Batman"), QStringLiteral("absolute batman"), QStringLiteral("1"), QStringLiteral("002") }
        };
        const auto resolution = DuplicateRestoreResolver::resolveMetadataCandidates(candidates, input);
        if (!resolution.isUnique() || resolution.candidates.first().id != 101) {
            printStepResult(QStringLiteral("Restore resolver exact-match narrow"), false, QStringLiteral("Expected canonical issue text 2 to win over stale padded 002."));
            return 1;
        }
        printStepResult(QStringLiteral("Restore resolver exact-match narrow"), true);
    }

    {
        const DuplicateRestoreResolver::RestoreMatchInput input = {
            QStringLiteral("absolute batman"),
            QStringLiteral("15"),
            QStringLiteral("1"),
            QStringLiteral("0015"),
            QStringLiteral("1")
        };
        const QVector<DuplicateRestoreResolver::RestoreCandidate> candidates = {
            { 201, QStringLiteral("Absolute.Batman_0015_2025.cbz"), QString(), QStringLiteral("Other Series"), QStringLiteral("other series"), QStringLiteral("1"), QStringLiteral("0015") }
        };
        const auto resolution = DuplicateRestoreResolver::resolveFilenameCandidates(candidates, input);
        if (resolution.isUnique()) {
            printStepResult(QStringLiteral("Restore resolver mismatch guard"), false, QStringLiteral("Filename match must not auto-restore into another series."));
            return 1;
        }
        printStepResult(QStringLiteral("Restore resolver mismatch guard"), true);
    }

    {
        const QVariantMap importValues = {
            { QStringLiteral("importContextSeries"), QStringLiteral("Selected Shelf") }
        };
        const QVariantMap comicInfoValues = {
            { QStringLiteral("series"), QStringLiteral("ComicInfo Series") },
            { QStringLiteral("volume"), QStringLiteral("7") },
            { QStringLiteral("issueNumber"), QStringLiteral("002") },
            { QStringLiteral("title"), QStringLiteral("ComicInfo Title") }
        };
        const ComicImportMatching::ImportIdentityPassport passport =
            ComicImportMatching::buildImportIdentityPassport(
                QStringLiteral("archive"),
                QStringLiteral("E:/Downloads/Absolute.Batman_002_2025.cbr"),
                QStringLiteral("Absolute.Batman_002_2025.cbr"),
                QStringLiteral("Absolute Batman"),
                QString(),
                importValues,
                comicInfoValues
            );
        if (passport.effectiveSeries != QStringLiteral("Selected Shelf")
            || passport.seriesSource != QStringLiteral("context")
            || passport.effectiveIssue != QStringLiteral("2")
            || passport.issueSource != QStringLiteral("comicinfo")
            || passport.strictFilenameSignature != QStringLiteral("absolute batman 002 2025")) {
            printStepResult(
                QStringLiteral("Import identity passport"),
                false,
                QStringLiteral("Passport did not preserve expected context/comicinfo/signature signals.")
            );
            return 1;
        }

        const QVariantMap appliedValues = ComicImportMatching::applyPassportDefaults({}, passport);
        if (appliedValues.value(QStringLiteral("series")).toString() != QStringLiteral("Selected Shelf")
            || appliedValues.value(QStringLiteral("issueNumber")).toString() != QStringLiteral("2")
            || appliedValues.value(QStringLiteral("volume")).toString() != QStringLiteral("7")
            || appliedValues.value(QStringLiteral("title")).toString() != QStringLiteral("ComicInfo Title")
            || appliedValues.value(QStringLiteral("importOriginalFilename")).toString() != QStringLiteral("Absolute.Batman_002_2025.cbr")
            || appliedValues.value(QStringLiteral("importSourceType")).toString() != QStringLiteral("archive")
            || appliedValues.value(QStringLiteral("importStrictFilenameSignature")).toString() != QStringLiteral("absolute batman 002 2025")) {
            printStepResult(
                QStringLiteral("Import identity passport"),
                false,
                QStringLiteral("Passport defaults did not hydrate series/volume/issue/title as expected.")
            );
            return 1;
        }

        printStepResult(QStringLiteral("Import identity passport"), true);
    }

    const int idRole = roleIndex(model, QByteArrayLiteral("id"));
    const int seriesGroupKeyRole = roleIndex(model, QByteArrayLiteral("seriesGroupKey"));
    if (idRole < 0 || seriesGroupKeyRole < 0) {
        printStepResult(QStringLiteral("Role lookup"), false, QStringLiteral("id/seriesGroupKey roles not found."));
        return 1;
    }

    QString error;
    int hiddenGhostId = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("ghost-hidden-only-in-db.cbz"),
            QStringLiteral("Ghost Hidden"),
            QStringLiteral("ghost hidden"),
            QStringLiteral("1"),
            QStringLiteral("1"),
            hiddenGhostId,
            error
        )) {
        printStepResult(QStringLiteral("Hidden stale rows setup"), false, error);
        return 1;
    }
    model.reload();
    if (findRowByComicId(model, idRole, hiddenGhostId).isValid()) {
        printStepResult(
            QStringLiteral("Hidden stale rows"),
            false,
            QStringLiteral("Row without a live file still leaked into the visible library.")
        );
        return 1;
    }
    const QVariantMap hiddenGhostMeta = model.loadComicMetadata(hiddenGhostId);
    if (!hiddenGhostMeta.value(QStringLiteral("error")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Hidden stale rows"),
            false,
            QStringLiteral("Hidden DB row should stay available for restore metadata.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Hidden stale rows"), true);

    int hiddenMissingPathId = 0;
    const DirtyRestoreSeed hiddenMissingSeed = {
        QDir(libraryDirPath).filePath(QStringLiteral("Ghost Missing/ghost-missing.cbz")),
        QStringLiteral("ghost-missing.cbz"),
        QStringLiteral("Ghost Missing"),
        QStringLiteral("ghost missing"),
        QStringLiteral("1"),
        QStringLiteral("1"),
        QStringLiteral("Hidden Missing Path"),
        QString(),
        QString(),
        QString(),
        QString()
    };
    if (!insertDirtyRestoreRowEx(dbPath, hiddenMissingSeed, hiddenMissingPathId, error)) {
        printStepResult(QStringLiteral("Hidden stale missing-path setup"), false, error);
        return 1;
    }
    model.reload();
    if (findRowByComicId(model, idRole, hiddenMissingPathId).isValid()) {
        printStepResult(
            QStringLiteral("Hidden stale missing-path"),
            false,
            QStringLiteral("Row with a stale missing file path leaked into the visible library.")
        );
        return 1;
    }
    const QVariantMap hiddenMissingMeta = model.loadComicMetadata(hiddenMissingPathId);
    if (!hiddenMissingMeta.value(QStringLiteral("error")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Hidden stale missing-path"),
            false,
            QStringLiteral("Stale missing-path row should stay available for restore metadata.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Hidden stale missing-path"), true);

    const QVariantMap baseValues = {
        { QStringLiteral("series"), QStringLiteral("Regression Series") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("1") },
        { QStringLiteral("title"), QStringLiteral("Regression Issue #1") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };

    // 1) importArchiveAndCreateIssueEx: created.
    const QString createdFilenameHint = QStringLiteral("regression-created.cbz");
    const QVariantMap createdResult = model.importArchiveAndCreateIssueEx(incomingA, createdFilenameHint, baseValues);
    if (!ensureImportSuccess(createdResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("ImportEx code=created"), false, error);
        return 1;
    }
    const int createdComicId = createdResult.value(QStringLiteral("comicId")).toInt();
    const QString createdFilePath = createdResult.value(QStringLiteral("filePath")).toString();
    const QString createdFilename = createdResult.value(QStringLiteral("filename")).toString();
    if (createdComicId < 1 || createdFilePath.isEmpty() || !QFileInfo::exists(createdFilePath)) {
        printStepResult(QStringLiteral("ImportEx code=created"), false, QStringLiteral("Created result missing comicId/filePath."));
        return 1;
    }
    if (QFileInfo(createdFilePath).absoluteDir().dirName() != QStringLiteral("Regression Series")) {
        printStepResult(QStringLiteral("ImportEx code=created"), false, QStringLiteral("Created archive was not placed in series folder."));
        return 1;
    }
    const QVariantMap createdMeta = model.loadComicMetadata(createdComicId);
    if (createdMeta.value(QStringLiteral("importOriginalFilename")).toString() != createdFilename
        || createdMeta.value(QStringLiteral("importSourceType")).toString() != QStringLiteral("archive")
        || createdMeta.value(QStringLiteral("importStrictFilenameSignature")).toString()
            != ComicImportMatching::normalizeFilenameSignatureStrict(createdFilename)
        || createdMeta.value(QStringLiteral("importLooseFilenameSignature")).toString()
            != ComicImportMatching::normalizeFilenameSignatureLoose(createdFilename)) {
        printStepResult(
            QStringLiteral("ImportEx code=created"),
            false,
            QStringLiteral("Created issue did not persist import source signals.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx code=created"), true);

    // 2) importArchiveAndCreateIssueEx: duplicate.
    const QVariantMap duplicateResult = model.importArchiveAndCreateIssueEx(createdFilePath, createdFilename, baseValues);
    if (!ensureImportFailureCode(duplicateResult, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("ImportEx code=duplicate"), false, error);
        return 1;
    }
    if (duplicateResult.value(QStringLiteral("existingId")).toInt() != createdComicId) {
        printStepResult(QStringLiteral("ImportEx code=duplicate"), false, QStringLiteral("existingId does not match initial comic."));
        return 1;
    }
    if (duplicateResult.value(QStringLiteral("duplicateTier")).toString() != QStringLiteral("exact")) {
        printStepResult(QStringLiteral("ImportEx code=duplicate"), false, QStringLiteral("Exact duplicate must report tier=exact."));
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx code=duplicate"), true);

    // 2b) importArchiveAndCreateIssueEx: duplicate before unique rename for external re-import.
    const QVariantMap duplicateIncomingResult = model.importArchiveAndCreateIssueEx(incomingA, createdFilenameHint, baseValues);
    if (!ensureImportFailureCode(duplicateIncomingResult, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("ImportEx duplicate before unique rename"), false, error);
        return 1;
    }
    if (duplicateIncomingResult.value(QStringLiteral("existingId")).toInt() != createdComicId) {
        printStepResult(QStringLiteral("ImportEx duplicate before unique rename"), false, QStringLiteral("existingId does not match initial comic."));
        return 1;
    }
    if (duplicateIncomingResult.value(QStringLiteral("duplicateTier")).toString() != QStringLiteral("exact")) {
        printStepResult(QStringLiteral("ImportEx duplicate before unique rename"), false, QStringLiteral("External exact re-import must report tier=exact."));
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx duplicate before unique rename"), true);

    // 2c) importArchiveAndCreateIssueEx: very likely duplicate should warn before import-as-new.
    const QVariantMap likelyDuplicateResult = model.importArchiveAndCreateIssueEx(
        incomingB,
        QStringLiteral("regression-likely.cbz"),
        baseValues
    );
    if (!ensureImportFailureCode(likelyDuplicateResult, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("ImportEx very likely duplicate"), false, error);
        return 1;
    }
    if (likelyDuplicateResult.value(QStringLiteral("existingId")).toInt() != createdComicId
        || likelyDuplicateResult.value(QStringLiteral("duplicateTier")).toString() != QStringLiteral("very_likely")) {
        printStepResult(
            QStringLiteral("ImportEx very likely duplicate"),
            false,
            QStringLiteral("Expected tier=very_likely against the existing live issue.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx very likely duplicate"), true);

    // 2d) importArchiveAndCreateIssueEx: weak duplicate should surface as suspicious only.
    QVariantMap weakDuplicateValues = baseValues;
    weakDuplicateValues.insert(QStringLiteral("volume"), QStringLiteral("2"));
    const QVariantMap weakDuplicateResult = model.importArchiveAndCreateIssueEx(
        incomingC,
        QStringLiteral("regression-weak.cbz"),
        weakDuplicateValues
    );
    if (!ensureImportFailureCode(weakDuplicateResult, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("ImportEx weak duplicate"), false, error);
        return 1;
    }
    if (weakDuplicateResult.value(QStringLiteral("existingId")).toInt() != createdComicId
        || weakDuplicateResult.value(QStringLiteral("duplicateTier")).toString() != QStringLiteral("weak")) {
        printStepResult(
            QStringLiteral("ImportEx weak duplicate"),
            false,
            QStringLiteral("Expected tier=weak for same issue with volume drift.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx weak duplicate"), true);

    // 2e) importArchiveAndCreateIssueEx: weak duplicate should relax inside explicit series-menu context.
    QVariantMap weakContextValues = weakDuplicateValues;
    weakContextValues.insert(QStringLiteral("importContextSeries"), QStringLiteral("Regression Series"));
    const QVariantMap weakContextResult = model.importArchiveAndCreateIssueEx(
        incomingC,
        QStringLiteral("regression-weak-context.cbz"),
        weakContextValues
    );
    if (!ensureImportSuccess(weakContextResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("ImportEx weak duplicate series-context"), false, error);
        return 1;
    }
    const int weakContextComicId = weakContextResult.value(QStringLiteral("comicId")).toInt();
    if (weakContextComicId < 1
        || weakContextComicId == createdComicId) {
        printStepResult(
            QStringLiteral("ImportEx weak duplicate series-context"),
            false,
            QStringLiteral("Series-context import should create a new row instead of blocking on weak duplicate heuristics.")
        );
        return 1;
    }
    const QString weakContextCleanupError = model.deleteComicHard(weakContextComicId);
    if (!weakContextCleanupError.isEmpty()) {
        printStepResult(QStringLiteral("ImportEx weak duplicate series-context"), false, weakContextCleanupError);
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx weak duplicate series-context"), true);

    // 2f) importArchiveAndCreateIssueEx: global add must not use metadata-only restore, but series add may.
    int intentSplitGlobalSeedId = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("intent-split-global-old.cbz"),
            QStringLiteral("Intent Split Restore"),
            QStringLiteral("intent split restore"),
            QStringLiteral("1"),
            QStringLiteral("4"),
            intentSplitGlobalSeedId,
            error
        )) {
        printStepResult(QStringLiteral("Import intent split setup"), false, error);
        return 1;
    }

    const QVariantMap globalIntentRestoreValues = {
        { QStringLiteral("series"), QStringLiteral("Intent Split Restore") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("4") },
        { QStringLiteral("title"), QStringLiteral("Intent Split Restore #4") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("importIntent"), QStringLiteral("global_add") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap globalIntentRestoreResult = model.importArchiveAndCreateIssueEx(
        incomingA,
        QStringLiteral("intent-split-global-new.cbz"),
        globalIntentRestoreValues
    );
    if (!ensureImportSuccess(globalIntentRestoreResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("Import intent split global add"), false, error);
        return 1;
    }
    if (globalIntentRestoreResult.value(QStringLiteral("comicId")).toInt() == intentSplitGlobalSeedId) {
        printStepResult(
            QStringLiteral("Import intent split global add"),
            false,
            QStringLiteral("Global add must not auto-restore from weak series/issue metadata alone.")
        );
        return 1;
    }
    const QVariantMap globalIntentSeedMeta = model.loadComicMetadata(intentSplitGlobalSeedId);
    if (!globalIntentSeedMeta.value(QStringLiteral("filePath")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Import intent split global add"),
            false,
            QStringLiteral("Global add unexpectedly reattached the old detached restore row.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Import intent split global add"), true);

    int intentSplitSeriesSeedId = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("intent-split-series-old.cbz"),
            QStringLiteral("Intent Split Restore"),
            QStringLiteral("intent split restore"),
            QStringLiteral("1"),
            QStringLiteral("5"),
            intentSplitSeriesSeedId,
            error
        )) {
        printStepResult(QStringLiteral("Import intent split series setup"), false, error);
        return 1;
    }

    const QVariantMap seriesIntentRestoreValues = {
        { QStringLiteral("series"), QStringLiteral("Intent Split Restore") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("5") },
        { QStringLiteral("title"), QStringLiteral("Intent Split Restore #5") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("importIntent"), QStringLiteral("series_add") },
        { QStringLiteral("importContextSeries"), QStringLiteral("Intent Split Restore") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap seriesIntentRestoreResult = model.importArchiveAndCreateIssueEx(
        incomingB,
        QStringLiteral("intent-split-series-new.cbz"),
        seriesIntentRestoreValues
    );
    if (!ensureImportSuccess(seriesIntentRestoreResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Import intent split series add"), false, error);
        return 1;
    }
    if (seriesIntentRestoreResult.value(QStringLiteral("comicId")).toInt() != intentSplitSeriesSeedId) {
        printStepResult(
            QStringLiteral("Import intent split series add"),
            false,
            QStringLiteral("Series add must keep using the detached issue in that selected series.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Import intent split series add"), true);

    // 2g) importArchiveAndCreateIssueEx: bare numeric filenames in selected-series context must still detect same issue.
    const QVariantMap numericSeriesBaselineValues = {
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap numericSeriesBaselineResult = model.importArchiveAndCreateIssueEx(
        incomingBare002,
        QString(),
        numericSeriesBaselineValues
    );
    if (!ensureImportSuccess(numericSeriesBaselineResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("ImportEx numeric filename baseline"), false, error);
        return 1;
    }
    const int numericSeriesBaselineId = numericSeriesBaselineResult.value(QStringLiteral("comicId")).toInt();
    const QVariantMap numericSeriesBaselineMeta = model.loadComicMetadata(numericSeriesBaselineId);
    if (numericSeriesBaselineId < 1
        || numericSeriesBaselineMeta.value(QStringLiteral("issueNumber")).toString() != QStringLiteral("2")) {
        printStepResult(
            QStringLiteral("ImportEx numeric filename baseline"),
            false,
            QStringLiteral("Bare numeric filename did not normalize to the expected issue text 2.")
        );
        return 1;
    }

    const QVariantMap numericSeriesDuplicateValues = {
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap numericSeriesDuplicateResult = model.importArchiveAndCreateIssueEx(
        incomingBare2,
        QString(),
        numericSeriesDuplicateValues
    );
    if (!ensureImportFailureCode(numericSeriesDuplicateResult, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("ImportEx numeric filename renamed duplicate"), false, error);
        return 1;
    }
    if (numericSeriesDuplicateResult.value(QStringLiteral("existingId")).toInt() != numericSeriesBaselineId
        || numericSeriesDuplicateResult.value(QStringLiteral("duplicateTier")).toString() != QStringLiteral("very_likely")) {
        printStepResult(
            QStringLiteral("ImportEx numeric filename renamed duplicate"),
            false,
            QStringLiteral("Renamed bare numeric import in the same series must warn as a replaceable duplicate.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx numeric filename renamed duplicate"), true);

    // 2h) importArchiveAndCreateIssueEx: renamed issue number in another series must still import as new.
    const QVariantMap numberClashBaselineValues = {
        { QStringLiteral("series"), QStringLiteral("Regression Number Clash") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("0015") },
        { QStringLiteral("title"), QStringLiteral("Regression Number Clash #0015") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap numberClashBaselineResult = model.importArchiveAndCreateIssueEx(
        incomingSeries0015,
        QString(),
        numberClashBaselineValues
    );
    if (!ensureImportSuccess(numberClashBaselineResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("ImportEx other-series number clash setup"), false, error);
        return 1;
    }
    const int numberClashBaselineId = numberClashBaselineResult.value(QStringLiteral("comicId")).toInt();
    if (numberClashBaselineId < 1) {
        printStepResult(
            QStringLiteral("ImportEx other-series number clash setup"),
            false,
            QStringLiteral("Failed to create live baseline issue for the cross-series check.")
        );
        return 1;
    }

    const QVariantMap otherSeries0015Values = {
        { QStringLiteral("series"), QStringLiteral("Other Number Clash") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("0015") },
        { QStringLiteral("title"), QStringLiteral("Other Number Clash #0015") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap otherSeries0015Result = model.importArchiveAndCreateIssueEx(
        incomingOtherSeries0015,
        QString(),
        otherSeries0015Values
    );
    if (!ensureImportSuccess(otherSeries0015Result, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("ImportEx renamed other-series issue"), false, error);
        return 1;
    }
    const int otherSeries0015Id = otherSeries0015Result.value(QStringLiteral("comicId")).toInt();
    if (otherSeries0015Id < 1 || otherSeries0015Id == numberClashBaselineId) {
        printStepResult(
            QStringLiteral("ImportEx renamed other-series issue"),
            false,
            QStringLiteral("Different series with the same issue number should create a separate live row.")
        );
        return 1;
    }
    const QVariantMap otherSeries0015Meta = model.loadComicMetadata(otherSeries0015Id);
    if (otherSeries0015Meta.value(QStringLiteral("series")).toString() != QStringLiteral("Other Number Clash")) {
        printStepResult(
            QStringLiteral("ImportEx renamed other-series issue"),
            false,
            QStringLiteral("Cross-series import did not stay attached to its own series.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx renamed other-series issue"), true);

    // 2i) importArchiveAndCreateIssueEx: preserve full base name for multi-dot archives.
    const QVariantMap multiDotValues = {
        { QStringLiteral("series"), QStringLiteral("Regression Series") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("2") },
        { QStringLiteral("title"), QStringLiteral("Regression Issue #2") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap multiDotResult = model.importArchiveAndCreateIssueEx(incomingMultiDot, QString(), multiDotValues);
    if (!ensureImportSuccess(multiDotResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("ImportEx preserve multi-dot filename"), false, error);
        return 1;
    }
    if (multiDotResult.value(QStringLiteral("filename")).toString() != QStringLiteral("Absolute.Batman_002_2025.cbz")) {
        printStepResult(
            QStringLiteral("ImportEx preserve multi-dot filename"),
            false,
            QStringLiteral("Filename base collapsed for multi-dot archive input.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx preserve multi-dot filename"), true);

    // 2i) dirty restore state: restored rows with old normalized import signals should heal on reimport.
    int healedLegacyImportId = 0;
    const QString legacyBadOriginalFilename = QStringLiteral("Legacy.cbz");
    const DirtyRestoreSeed healedLegacySeed = {
        QVariant(),
        QStringLiteral("Legacy.cbz"),
        QStringLiteral("Legacy Normalized"),
        QStringLiteral("legacy normalized"),
        QStringLiteral("1"),
        QStringLiteral("0015"),
        QStringLiteral("Legacy Normalized #0015"),
        legacyBadOriginalFilename,
        ComicImportMatching::normalizeFilenameSignatureStrict(legacyBadOriginalFilename),
        ComicImportMatching::normalizeFilenameSignatureLoose(legacyBadOriginalFilename),
        QStringLiteral("archive")
    };
    if (!insertDirtyRestoreRowEx(dbPath, healedLegacySeed, healedLegacyImportId, error)) {
        printStepResult(QStringLiteral("Dirty restore healed import signals setup"), false, error);
        return 1;
    }

    const QVariantMap healedLegacyValues = {
        { QStringLiteral("series"), QStringLiteral("Legacy Normalized") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("0015") },
        { QStringLiteral("title"), QStringLiteral("Legacy Normalized #0015") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap healedLegacyResult = model.importArchiveAndCreateIssueEx(
        incomingLegacyNormalized0015,
        QString(),
        healedLegacyValues
    );
    if (!ensureImportSuccess(healedLegacyResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Dirty restore healed import signals"), false, error);
        return 1;
    }
    if (healedLegacyResult.value(QStringLiteral("comicId")).toInt() != healedLegacyImportId) {
        printStepResult(
            QStringLiteral("Dirty restore healed import signals"),
            false,
            QStringLiteral("Reimport did not reconnect the original stale row with bad import memory.")
        );
        return 1;
    }
    const QVariantMap healedLegacyMeta = model.loadComicMetadata(healedLegacyImportId);
    const QString healedLegacyOriginal = healedLegacyMeta.value(QStringLiteral("importOriginalFilename")).toString();
    if (healedLegacyOriginal != QFileInfo(incomingLegacyNormalized0015).fileName()
        || healedLegacyMeta.value(QStringLiteral("importStrictFilenameSignature")).toString()
            != ComicImportMatching::normalizeFilenameSignatureStrict(healedLegacyOriginal)
        || healedLegacyMeta.value(QStringLiteral("importLooseFilenameSignature")).toString()
            != ComicImportMatching::normalizeFilenameSignatureLoose(healedLegacyOriginal)) {
        printStepResult(
            QStringLiteral("Dirty restore healed import signals"),
            false,
            QStringLiteral("Restore did not replace the old normalized filename memory with the new import signals.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore healed import signals"), true);

    // 2i) dirty restore state: exact filename should beat old wrong normalized filenames.
    int filenamePriorityBadId = 0;
    int filenamePriorityExactId = 0;
    const DirtyRestoreSeed filenamePriorityBadSeed = {
        QVariant(),
        QStringLiteral("Filename.cbz"),
        QStringLiteral("Filename Priority"),
        QStringLiteral("filename priority"),
        QStringLiteral("1"),
        QStringLiteral("0015"),
        QStringLiteral("Filename Priority #0015"),
        QStringLiteral("Filename.cbz"),
        ComicImportMatching::normalizeFilenameSignatureStrict(QStringLiteral("Filename.cbz")),
        ComicImportMatching::normalizeFilenameSignatureLoose(QStringLiteral("Filename.cbz")),
        QStringLiteral("archive")
    };
    const DirtyRestoreSeed filenamePriorityExactSeed = {
        QVariant(),
        QStringLiteral("Filename.Priority_0015.cbz"),
        QStringLiteral("Filename Priority"),
        QStringLiteral("filename priority"),
        QStringLiteral("1"),
        QStringLiteral("0015"),
        QStringLiteral("Filename Priority #0015"),
        QStringLiteral("Filename.Priority_0015.cbz"),
        ComicImportMatching::normalizeFilenameSignatureStrict(QStringLiteral("Filename.Priority_0015.cbz")),
        ComicImportMatching::normalizeFilenameSignatureLoose(QStringLiteral("Filename.Priority_0015.cbz")),
        QStringLiteral("archive")
    };
    if (!insertDirtyRestoreRowEx(dbPath, filenamePriorityBadSeed, filenamePriorityBadId, error)
        || !insertDirtyRestoreRowEx(dbPath, filenamePriorityExactSeed, filenamePriorityExactId, error)) {
        printStepResult(QStringLiteral("Dirty restore filename priority setup"), false, error);
        return 1;
    }

    const QVariantMap filenamePriorityValues = {
        { QStringLiteral("series"), QStringLiteral("Filename Priority") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("0015") },
        { QStringLiteral("title"), QStringLiteral("Filename Priority #0015") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap filenamePriorityResult = model.importArchiveAndCreateIssueEx(
        incomingFilenamePriority0015,
        QString(),
        filenamePriorityValues
    );
    if (!ensureImportSuccess(filenamePriorityResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Dirty restore filename priority"), false, error);
        return 1;
    }
    if (filenamePriorityResult.value(QStringLiteral("comicId")).toInt() != filenamePriorityExactId) {
        printStepResult(
            QStringLiteral("Dirty restore filename priority"),
            false,
            QStringLiteral("Old normalized filename row won over the stale row with the exact legacy filename.")
        );
        return 1;
    }
    const QVariantMap filenamePriorityBadMeta = model.loadComicMetadata(filenamePriorityBadId);
    if (!filenamePriorityBadMeta.value(QStringLiteral("filePath")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Dirty restore filename priority"),
            false,
            QStringLiteral("Wrong legacy filename row should remain detached after restore picked the exact stale row.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore filename priority"), true);

    // 2j) dirty restore state: same-path stale rows currently stay under the exact-duplicate guard
    // until they become truly detached/missing-file restore candidates.
    int staleSamePathId = 0;
    const QString staleSamePathSeries = QStringLiteral("Stale Path Restore");
    const QString staleSamePathFilename = QStringLiteral("exact-path-restore.cbz");
    const DirtyRestoreSeed staleSamePathSeed = {
        QDir(libraryDirPath).filePath(staleSamePathSeries + QStringLiteral("/") + staleSamePathFilename),
        staleSamePathFilename,
        staleSamePathSeries,
        QStringLiteral("stale path restore"),
        QStringLiteral("1"),
        QStringLiteral("7"),
        QStringLiteral("Stale Path Restore #7"),
        staleSamePathFilename,
        ComicImportMatching::normalizeFilenameSignatureStrict(staleSamePathFilename),
        ComicImportMatching::normalizeFilenameSignatureLoose(staleSamePathFilename),
        QStringLiteral("archive")
    };
    if (!insertDirtyRestoreRowEx(dbPath, staleSamePathSeed, staleSamePathId, error)) {
        printStepResult(QStringLiteral("Dirty restore same-path stale setup"), false, error);
        return 1;
    }

    const QVariantMap staleSamePathValues = {
        { QStringLiteral("series"), staleSamePathSeries },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("7") },
        { QStringLiteral("title"), QStringLiteral("Stale Path Restore #7") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap staleSamePathResult = model.importArchiveAndCreateIssueEx(
        incomingA,
        staleSamePathFilename,
        staleSamePathValues
    );
    if (!ensureImportFailureCode(staleSamePathResult, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("Dirty restore same-path stale"), false, error);
        return 1;
    }
    if (staleSamePathResult.value(QStringLiteral("existingId")).toInt() != staleSamePathId
        || staleSamePathResult.value(QStringLiteral("duplicateTier")).toString() != QStringLiteral("exact")) {
        printStepResult(
            QStringLiteral("Dirty restore same-path stale"),
            false,
            QStringLiteral("Same-path stale row should stay under the exact duplicate guard.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore same-path stale"), true);

    // 2k) dirty restore state: a single weak metadata match must stop instead of auto-restoring.
    int weakMetadataOnlyRestoreId = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("weak-metadata-restore-old.cbz"),
            QStringLiteral("Weak Metadata Restore"),
            QStringLiteral("weak metadata restore"),
            QStringLiteral("1"),
            QStringLiteral("2"),
            weakMetadataOnlyRestoreId,
            error
        )) {
        printStepResult(QStringLiteral("Dirty restore weak metadata setup"), false, error);
        return 1;
    }

    const int weakMetadataLiveCount = model.totalCount();
    const QString weakMetadataExpectedPath = QDir(libraryDirPath).filePath(
        QStringLiteral("Weak Metadata Restore/weak-metadata-restore-incoming.cbz")
    );
    const QVariantMap weakMetadataRestoreValues = {
        { QStringLiteral("series"), QStringLiteral("Weak Metadata Restore") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("002") },
        { QStringLiteral("title"), QStringLiteral("Weak Metadata Restore #002") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("importIntent"), QStringLiteral("series_add") },
        { QStringLiteral("importContextSeries"), QStringLiteral("Weak Metadata Restore") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap weakMetadataRestoreResult = model.importArchiveAndCreateIssueEx(
        incomingA,
        QStringLiteral("weak-metadata-restore-incoming.cbz"),
        weakMetadataRestoreValues
    );
    if (!ensureImportFailureCode(weakMetadataRestoreResult, QStringLiteral("restore_review_required"), error)) {
        printStepResult(QStringLiteral("Dirty restore weak metadata stop"), false, error);
        return 1;
    }
    if (weakMetadataRestoreResult.value(QStringLiteral("restoreCandidateCount")).toInt() != 1) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata stop"),
            false,
            QStringLiteral("Weak metadata stop must report the single partial restore candidate.")
        );
        return 1;
    }
    if (model.totalCount() != weakMetadataLiveCount) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata stop"),
            false,
            QStringLiteral("Weak metadata restore must not create a new live row.")
        );
        return 1;
    }
    if (QFileInfo::exists(weakMetadataExpectedPath)) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata stop"),
            false,
            QStringLiteral("Weak metadata restore left a copied archive in the library instead of cleaning it up.")
        );
        return 1;
    }
    const QVariantMap weakMetadataOnlyRestoreMeta = model.loadComicMetadata(weakMetadataOnlyRestoreId);
    if (!weakMetadataOnlyRestoreMeta.value(QStringLiteral("filePath")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata stop"),
            false,
            QStringLiteral("Weak metadata restore must leave the old detached row untouched.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore weak metadata stop"), true);

    const QVariantMap weakMetadataApprovedValues = {
        { QStringLiteral("series"), QStringLiteral("Weak Metadata Restore") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("002") },
        { QStringLiteral("title"), QStringLiteral("Weak Metadata Restore #002") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("importIntent"), QStringLiteral("series_add") },
        { QStringLiteral("importContextSeries"), QStringLiteral("Weak Metadata Restore") },
        { QStringLiteral("allowWeakMetadataRestore"), true },
        { QStringLiteral("restoreCandidateId"), weakMetadataOnlyRestoreId },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap weakMetadataApprovedResult = model.importArchiveAndCreateIssueEx(
        incomingB,
        QStringLiteral("weak-metadata-restore-approved.cbz"),
        weakMetadataApprovedValues
    );
    if (!ensureImportSuccess(weakMetadataApprovedResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Dirty restore weak metadata approved"), false, error);
        return 1;
    }
    if (weakMetadataApprovedResult.value(QStringLiteral("comicId")).toInt() != weakMetadataOnlyRestoreId) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata approved"),
            false,
            QStringLiteral("Approved weak restore must reconnect the exact requested hidden issue.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore weak metadata approved"), true);

    int weakMetadataImportAsNewSeedId = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("weak-metadata-import-as-new-old.cbz"),
            QStringLiteral("Weak Metadata Import As New"),
            QStringLiteral("weak metadata import as new"),
            QStringLiteral("1"),
            QStringLiteral("6"),
            weakMetadataImportAsNewSeedId,
            error
        )) {
        printStepResult(QStringLiteral("Dirty restore weak metadata import-as-new setup"), false, error);
        return 1;
    }

    const QVariantMap weakMetadataImportAsNewValues = {
        { QStringLiteral("series"), QStringLiteral("Weak Metadata Import As New") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("006") },
        { QStringLiteral("title"), QStringLiteral("Weak Metadata Import As New #006") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("importIntent"), QStringLiteral("series_add") },
        { QStringLiteral("importContextSeries"), QStringLiteral("Weak Metadata Import As New") },
        { QStringLiteral("duplicateDecision"), QStringLiteral("import_as_new") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap weakMetadataImportAsNewResult = model.importArchiveAndCreateIssueEx(
        incomingC,
        QStringLiteral("weak-metadata-import-as-new.cbz"),
        weakMetadataImportAsNewValues
    );
    if (!ensureImportSuccess(weakMetadataImportAsNewResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("Dirty restore weak metadata import-as-new"), false, error);
        return 1;
    }
    if (weakMetadataImportAsNewResult.value(QStringLiteral("comicId")).toInt() == weakMetadataImportAsNewSeedId) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata import-as-new"),
            false,
            QStringLiteral("Explicit import-as-new must not reconnect the old detached issue.")
        );
        return 1;
    }
    const QVariantMap weakMetadataImportAsNewSeedMeta = model.loadComicMetadata(weakMetadataImportAsNewSeedId);
    if (!weakMetadataImportAsNewSeedMeta.value(QStringLiteral("filePath")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Dirty restore weak metadata import-as-new"),
            false,
            QStringLiteral("Import-as-new must leave the old detached issue untouched.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore weak metadata import-as-new"), true);

    // 2l) dirty restore state: canonical normalized issue text should prefer 2 over stale padded 002.
    int dirtyIssue2Id = 0;
    int dirtyIssue002Id = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("legacy-absolute-batman-2.cbz"),
            QStringLiteral("Absolute Batman"),
            QStringLiteral("absolute batman"),
            QStringLiteral("1"),
            QStringLiteral("2"),
            dirtyIssue2Id,
            error
        ) || !insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("legacy-absolute-batman-002.cbz"),
            QStringLiteral("Absolute Batman"),
            QStringLiteral("absolute batman"),
            QStringLiteral("1"),
            QStringLiteral("002"),
            dirtyIssue002Id,
            error
        )) {
        printStepResult(QStringLiteral("Dirty restore exact issue setup"), false, error);
        return 1;
    }

    const QVariantMap dirtyRestoreValues = {
        { QStringLiteral("series"), QStringLiteral("Absolute Batman") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("002") },
        { QStringLiteral("title"), QStringLiteral("Absolute Batman #002") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap dirtyRestoreResult = model.importArchiveAndCreateIssueEx(incomingMultiDot, QString(), dirtyRestoreValues);
    if (!ensureImportSuccess(dirtyRestoreResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Dirty restore exact issue"), false, error);
        return 1;
    }
    if (dirtyRestoreResult.value(QStringLiteral("comicId")).toInt() != dirtyIssue2Id) {
        printStepResult(QStringLiteral("Dirty restore exact issue"), false, QStringLiteral("Restore picked stale padded 002 instead of canonical issue 2."));
        return 1;
    }
    const QVariantMap dirtyIssue002Meta = model.loadComicMetadata(dirtyIssue002Id);
    const QString dirtyRestoredPath = dirtyRestoreResult.value(QStringLiteral("filePath")).toString();
    const QVariantMap dirtyIssue2Meta = model.loadComicMetadata(dirtyIssue2Id);
    if (dirtyIssue2Meta.value(QStringLiteral("filePath")).toString().isEmpty()
        || dirtyRestoredPath.isEmpty()
        || !QFileInfo::exists(dirtyRestoredPath)) {
        printStepResult(QStringLiteral("Dirty restore exact issue"), false, QStringLiteral("Canonical issue 2 row was not relinked to a real archive."));
        return 1;
    }
    if (!dirtyIssue002Meta.value(QStringLiteral("filePath")).toString().isEmpty()) {
        printStepResult(QStringLiteral("Dirty restore exact issue"), false, QStringLiteral("Stale padded issue 002 row should remain detached."));
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore exact issue"), true);

    // 2m) dirty restore state: ambiguous same-series missing rows must stop instead of creating a new live row.
    int ambiguousRestoreAId = 0;
    int ambiguousRestoreBId = 0;
    if (!insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("ambiguous-restore-a.cbz"),
            QStringLiteral("Ambiguous Restore"),
            QStringLiteral("ambiguous restore"),
            QStringLiteral("1"),
            QStringLiteral("12"),
            ambiguousRestoreAId,
            error
        ) || !insertDirtyRestoreRow(
            dbPath,
            QStringLiteral("ambiguous-restore-b.cbz"),
            QStringLiteral("Ambiguous Restore"),
            QStringLiteral("ambiguous restore"),
            QStringLiteral("1"),
            QStringLiteral("12"),
            ambiguousRestoreBId,
            error
        )) {
        printStepResult(QStringLiteral("Dirty restore ambiguous setup"), false, error);
        return 1;
    }

    const int ambiguousRestoreLiveCount = model.totalCount();
    const QString ambiguousRestoreFilename = QStringLiteral("ambiguous-restore-incoming.cbz");
    const QString ambiguousRestoreExpectedPath = QDir(libraryDirPath).filePath(
        QStringLiteral("Ambiguous Restore/") + ambiguousRestoreFilename
    );
    const QVariantMap ambiguousRestoreValues = {
        { QStringLiteral("series"), QStringLiteral("Ambiguous Restore") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("12") },
        { QStringLiteral("title"), QStringLiteral("Ambiguous Restore #12") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap ambiguousRestoreResult = model.importArchiveAndCreateIssueEx(
        incomingA,
        ambiguousRestoreFilename,
        ambiguousRestoreValues
    );
    if (!ensureImportFailureCode(ambiguousRestoreResult, QStringLiteral("restore_conflict"), error)) {
        printStepResult(QStringLiteral("Dirty restore ambiguous conflict"), false, error);
        return 1;
    }
    if (ambiguousRestoreResult.value(QStringLiteral("restoreCandidateCount")).toInt() != 2) {
        printStepResult(
            QStringLiteral("Dirty restore ambiguous conflict"),
            false,
            QStringLiteral("Ambiguous restore must report both deleted candidates.")
        );
        return 1;
    }
    if (model.totalCount() != ambiguousRestoreLiveCount) {
        printStepResult(
            QStringLiteral("Dirty restore ambiguous conflict"),
            false,
            QStringLiteral("Ambiguous restore created a new live row instead of stopping safely.")
        );
        return 1;
    }
    if (QFileInfo::exists(ambiguousRestoreExpectedPath)) {
        printStepResult(
            QStringLiteral("Dirty restore ambiguous conflict"),
            false,
            QStringLiteral("Ambiguous restore left a copied archive in the library instead of cleaning it up.")
        );
        return 1;
    }
    const QVariantMap ambiguousRestoreAMeta = model.loadComicMetadata(ambiguousRestoreAId);
    const QVariantMap ambiguousRestoreBMeta = model.loadComicMetadata(ambiguousRestoreBId);
    if (!ambiguousRestoreAMeta.value(QStringLiteral("filePath")).toString().isEmpty()
        || !ambiguousRestoreBMeta.value(QStringLiteral("filePath")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Dirty restore ambiguous conflict"),
            false,
            QStringLiteral("Ambiguous restore must leave all deleted candidates detached.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Dirty restore ambiguous conflict"), true);

    // 2n) Delete Series -> reimport should quietly restore old rows.
    const QVariantMap absoluteBatman003Values = {
        { QStringLiteral("series"), QStringLiteral("Absolute Batman") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("003") },
        { QStringLiteral("title"), QStringLiteral("Absolute Batman #003") },
        { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap absoluteBatman003Result = model.importArchiveAndCreateIssueEx(incomingMultiDot003, QString(), absoluteBatman003Values);
    if (!ensureImportSuccess(absoluteBatman003Result, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("Delete Series restore setup"), false, error);
        return 1;
    }
    model.reload();
    const QModelIndex absoluteBatmanRow = findRowByComicId(model, idRole, dirtyIssue002Id);
    if (!absoluteBatmanRow.isValid()) {
        printStepResult(QStringLiteral("Delete Series restore setup"), false, QStringLiteral("Restored Absolute Batman row is not visible before series delete."));
        return 1;
    }
    const QString absoluteBatmanSeriesGroupKey = model.data(absoluteBatmanRow, seriesGroupKeyRole).toString();
    if (absoluteBatmanSeriesGroupKey.isEmpty()) {
        printStepResult(QStringLiteral("Delete Series restore setup"), false, QStringLiteral("Absolute Batman series group key is empty."));
        return 1;
    }

    const QString deleteSeriesError = model.deleteSeriesFilesKeepRecords(absoluteBatmanSeriesGroupKey);
    if (!deleteSeriesError.isEmpty()) {
        printStepResult(QStringLiteral("Delete Series restore"), false, deleteSeriesError);
        return 1;
    }

    const QVariantMap deleteSeriesRestoreResult = model.importArchiveAndCreateIssueEx(incomingMultiDot, QString(), dirtyRestoreValues);
    if (!ensureImportSuccess(deleteSeriesRestoreResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Delete Series restore"), false, error);
        return 1;
    }
    if (deleteSeriesRestoreResult.value(QStringLiteral("comicId")).toInt() != dirtyIssue002Id) {
        printStepResult(QStringLiteral("Delete Series restore"), false, QStringLiteral("Reimport did not restore the original 002 row."));
        return 1;
    }
    printStepResult(QStringLiteral("Delete Series restore"), true);

    // 3) importArchiveAndCreateIssueEx: unsupported format (error path).
    const QString txtPath = QDir(incomingDirPath).filePath(QStringLiteral("unsupported.txt"));
    QFile txtFile(txtPath);
    if (!txtFile.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        printStepResult(QStringLiteral("ImportEx code=unsupported_format"), false, QStringLiteral("Failed to create unsupported fixture."));
        return 1;
    }
    txtFile.write("not-an-archive\n");
    txtFile.close();
    const QVariantMap unsupportedResult = model.importArchiveAndCreateIssueEx(txtPath, QStringLiteral("unsupported.txt"), baseValues);
    if (!ensureImportFailureCode(unsupportedResult, QStringLiteral("unsupported_format"), error)) {
        printStepResult(QStringLiteral("ImportEx code=unsupported_format"), false, error);
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx code=unsupported_format"), true);

    // 4) importArchiveAndCreateIssueEx: restored (legacy/missing-file restore path).
    const QString detachForRestoreError = model.deleteComicFilesKeepRecord(createdComicId);
    if (!detachForRestoreError.isEmpty()) {
        printStepResult(QStringLiteral("ImportEx code=restored setup"), false, detachForRestoreError);
        return 1;
    }
    const QVariantMap restoredResult = model.importArchiveAndCreateIssueEx(incomingA, createdFilename, baseValues);
    if (!ensureImportSuccess(restoredResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("ImportEx code=restored"), false, error);
        return 1;
    }
    if (restoredResult.value(QStringLiteral("comicId")).toInt() != createdComicId) {
        printStepResult(QStringLiteral("ImportEx code=restored"), false, QStringLiteral("Restored comicId mismatch."));
        return 1;
    }
    const QString restoredPath = restoredResult.value(QStringLiteral("filePath")).toString();
    if (restoredPath.isEmpty() || !QFileInfo::exists(restoredPath)) {
        printStepResult(QStringLiteral("ImportEx code=restored"), false, QStringLiteral("Restored file path is missing."));
        return 1;
    }
    const QVariantMap restoredMeta = model.loadComicMetadata(createdComicId);
    if (restoredMeta.value(QStringLiteral("importOriginalFilename")).toString() != createdFilename
        || restoredMeta.value(QStringLiteral("importSourceType")).toString() != QStringLiteral("archive")
        || restoredMeta.value(QStringLiteral("importStrictFilenameSignature")).toString()
            != ComicImportMatching::normalizeFilenameSignatureStrict(createdFilename)
        || restoredMeta.value(QStringLiteral("importLooseFilenameSignature")).toString()
            != ComicImportMatching::normalizeFilenameSignatureLoose(createdFilename)) {
        printStepResult(
            QStringLiteral("ImportEx code=restored"),
            false,
            QStringLiteral("Restored issue did not refresh persisted import source signals.")
        );
        return 1;
    }
    const QString activeRestoreFilename = restoredMeta.value(QStringLiteral("filename")).toString();
    if (activeRestoreFilename.isEmpty()) {
        printStepResult(
            QStringLiteral("ImportEx code=restored"),
            false,
            QStringLiteral("Restored issue has no active filename.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("ImportEx code=restored"), true);

    // 4c) delete keep-record should not multiply detached restore ghosts for the same issue.
    int duplicateDetachedGhostId = 0;
    const DirtyRestoreSeed duplicateDetachedGhostSeed = {
        QVariant(),
        activeRestoreFilename,
        QStringLiteral("Regression Series"),
        QStringLiteral("regression series"),
        QStringLiteral("1"),
        QStringLiteral("1"),
        QStringLiteral("Ghost Cleanup Row"),
        restoredMeta.value(QStringLiteral("importOriginalFilename")).toString(),
        restoredMeta.value(QStringLiteral("importStrictFilenameSignature")).toString(),
        restoredMeta.value(QStringLiteral("importLooseFilenameSignature")).toString(),
        restoredMeta.value(QStringLiteral("importSourceType")).toString()
    };
    if (!insertDirtyRestoreRowEx(dbPath, duplicateDetachedGhostSeed, duplicateDetachedGhostId, error)) {
        printStepResult(QStringLiteral("Restore ghost cleanup setup"), false, error);
        return 1;
    }

    const QString ghostCleanupDeleteError = model.deleteComicFilesKeepRecord(createdComicId);
    if (!ghostCleanupDeleteError.isEmpty()) {
        printStepResult(QStringLiteral("Restore ghost cleanup"), false, ghostCleanupDeleteError);
        return 1;
    }

    QVector<int> detachedGhostIds;
    if (!loadDetachedRestoreIdsForKey(
            dbPath,
            QStringLiteral("regression series"),
            QStringLiteral("1"),
            QStringLiteral("1"),
            activeRestoreFilename,
            detachedGhostIds,
            error
        )) {
        printStepResult(QStringLiteral("Restore ghost cleanup"), false, error);
        return 1;
    }
    if (detachedGhostIds.size() != 1 || detachedGhostIds.first() != createdComicId) {
        printStepResult(
            QStringLiteral("Restore ghost cleanup"),
            false,
            QStringLiteral("Delete keep-record must leave exactly one detached restore row for the issue.")
        );
        return 1;
    }
    const QVariantMap deletedGhostMeta = model.loadComicMetadata(duplicateDetachedGhostId);
    if (deletedGhostMeta.value(QStringLiteral("error")).toString().isEmpty()) {
        printStepResult(
            QStringLiteral("Restore ghost cleanup"),
            false,
            QStringLiteral("Old detached restore ghost still exists after cleanup.")
        );
        return 1;
    }
    const QVariantMap ghostCleanupRestoreResult = model.importArchiveAndCreateIssueEx(incomingA, activeRestoreFilename, baseValues);
    if (!ensureImportSuccess(ghostCleanupRestoreResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Restore ghost cleanup"), false, error);
        return 1;
    }
    if (ghostCleanupRestoreResult.value(QStringLiteral("comicId")).toInt() != createdComicId) {
        printStepResult(
            QStringLiteral("Restore ghost cleanup"),
            false,
            QStringLiteral("Cleanup restore must reconnect the original issue row, not create another record.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Restore ghost cleanup"), true);

    // 5) Replace semantics + rollback primitives.
    const QVariantMap metaBeforeReplace = model.loadComicMetadata(createdComicId);
    const QString oldStoredFilePath = metaBeforeReplace.value(QStringLiteral("filePath")).toString();
    const QString oldFilePath = ghostCleanupRestoreResult.value(QStringLiteral("filePath")).toString();
    const QString oldFilename = metaBeforeReplace.value(QStringLiteral("filename")).toString();
    if (oldStoredFilePath.isEmpty() || oldFilePath.isEmpty() || oldFilename.isEmpty()) {
        printStepResult(QStringLiteral("Replace primitives setup"), false, QStringLiteral("Missing old file metadata."));
        return 1;
    }

    const QString detachError = model.detachComicFileKeepMetadata(createdComicId);
    if (!detachError.isEmpty()) {
        printStepResult(QStringLiteral("Replace primitives setup"), false, detachError);
        return 1;
    }

    const QVariantMap replaceValues = {
        { QStringLiteral("series"), QStringLiteral("Regression Series") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("1") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap replaceResult = model.importArchiveAndCreateIssueEx(incomingB, oldFilename, replaceValues);
    if (!ensureImportSuccess(replaceResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Replace action"), false, error);
        return 1;
    }
    if (replaceResult.value(QStringLiteral("comicId")).toInt() != createdComicId) {
        printStepResult(QStringLiteral("Replace action"), false, QStringLiteral("Replace did not relink same metadata row."));
        return 1;
    }
    const QString newFilePath = replaceResult.value(QStringLiteral("filePath")).toString();
    if (newFilePath.isEmpty() || !QFileInfo::exists(newFilePath)) {
        printStepResult(QStringLiteral("Replace action"), false, QStringLiteral("New file path missing after replace."));
        return 1;
    }
    // Rollback primitives for current replace.
    const QString rollbackDetach = model.detachComicFileKeepMetadata(createdComicId);
    const QString rollbackDelete = model.deleteFileAtPath(newFilePath);
    const QString rollbackRelink = model.relinkComicFileKeepMetadata(createdComicId, oldFilePath, oldFilename);
    if (!rollbackDetach.isEmpty() || !rollbackDelete.isEmpty() || !rollbackRelink.isEmpty()) {
        printStepResult(
            QStringLiteral("Rollback primitives"),
            false,
            QString("detach=%1 delete=%2 relink=%3").arg(rollbackDetach, rollbackDelete, rollbackRelink)
        );
        return 1;
    }
    const QVariantMap metaAfterRollback = model.loadComicMetadata(createdComicId);
    if (metaAfterRollback.value(QStringLiteral("filePath")).toString() != oldStoredFilePath) {
        printStepResult(QStringLiteral("Rollback primitives"), false, QStringLiteral("Old file path was not restored."));
        return 1;
    }
    printStepResult(QStringLiteral("Rollback primitives"), true);

    // 6) Replace commit semantics: old file removed after successful replace commit.
    const QString detachForCommit = model.detachComicFileKeepMetadata(createdComicId);
    if (!detachForCommit.isEmpty()) {
        printStepResult(QStringLiteral("Replace commit setup"), false, detachForCommit);
        return 1;
    }
    const QVariantMap replaceCommitResult = model.importArchiveAndCreateIssueEx(incomingB, oldFilename, replaceValues);
    if (!ensureImportSuccess(replaceCommitResult, QStringLiteral("restored"), error)) {
        printStepResult(QStringLiteral("Replace commit"), false, error);
        return 1;
    }
    const QString committedNewPath = replaceCommitResult.value(QStringLiteral("filePath")).toString();
    const QString commitDeleteOldError = model.deleteFileAtPath(oldFilePath);
    if (!commitDeleteOldError.isEmpty()) {
        printStepResult(QStringLiteral("Replace commit"), false, commitDeleteOldError);
        return 1;
    }
    if (QFileInfo::exists(oldFilePath)) {
        printStepResult(QStringLiteral("Replace commit"), false, QStringLiteral("Old file still exists after commit delete."));
        return 1;
    }
    if (committedNewPath.isEmpty() || !QFileInfo::exists(committedNewPath)) {
        printStepResult(QStringLiteral("Replace commit"), false, QStringLiteral("Committed new file is missing."));
        return 1;
    }
    printStepResult(QStringLiteral("Replace commit"), true);

    // 7) Import as new.
    const QVariantMap importAsNewValues = {
        { QStringLiteral("series"), QStringLiteral("Regression Series") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("99") },
        { QStringLiteral("title"), QStringLiteral("Regression Issue #99") },
        { QStringLiteral("deferReload"), true },
    };
    const QVariantMap importAsNewResult = model.importArchiveAndCreateIssueEx(incomingC, QStringLiteral("regression-as-new.cbz"), importAsNewValues);
    if (!ensureImportSuccess(importAsNewResult, QStringLiteral("created"), error)) {
        printStepResult(QStringLiteral("Import as new"), false, error);
        return 1;
    }
    const int importAsNewId = importAsNewResult.value(QStringLiteral("comicId")).toInt();
    if (importAsNewId < 1 || importAsNewId == createdComicId) {
        printStepResult(QStringLiteral("Import as new"), false, QStringLiteral("New import must create a distinct row."));
        return 1;
    }
    printStepResult(QStringLiteral("Import as new"), true);

    // 8) Skip semantics (no-op by design): duplicate detection should not mutate row count.
    model.reload();
    const int rowCountBeforeSkip = model.rowCount();
    const QVariantMap skipDuplicate = model.importArchiveAndCreateIssueEx(committedNewPath, QFileInfo(committedNewPath).fileName(), replaceValues);
    if (!ensureImportFailureCode(skipDuplicate, QStringLiteral("duplicate"), error)) {
        printStepResult(QStringLiteral("Skip semantics"), false, error);
        return 1;
    }
    model.reload();
    const int rowCountAfterSkip = model.rowCount();
    if (rowCountBeforeSkip != rowCountAfterSkip) {
        printStepResult(QStringLiteral("Skip semantics"), false, QStringLiteral("Row count changed after duplicate no-op."));
        return 1;
    }
    printStepResult(QStringLiteral("Skip semantics"), true);

    // 9) updateComicMetadata.
    const QString updateError = model.updateComicMetadata(createdComicId, {
        { QStringLiteral("series"), QStringLiteral("Regression Series") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("title"), QStringLiteral("Updated Regression Title") },
        { QStringLiteral("issueNumber"), QStringLiteral("1") },
        { QStringLiteral("publisher"), QStringLiteral("Updated Publisher") },
        { QStringLiteral("year"), QStringLiteral("2024") },
        { QStringLiteral("month"), QStringLiteral("5") },
    });
    if (!updateError.isEmpty()) {
        printStepResult(QStringLiteral("updateComicMetadata"), false, updateError);
        return 1;
    }
    const QVariantMap updatedMeta = model.loadComicMetadata(createdComicId);
    if (updatedMeta.value(QStringLiteral("title")).toString() != QStringLiteral("Updated Regression Title")
        || updatedMeta.value(QStringLiteral("publisher")).toString() != QStringLiteral("Updated Publisher")
        || updatedMeta.value(QStringLiteral("year")).toInt() != 2024
        || updatedMeta.value(QStringLiteral("month")).toInt() != 5) {
        printStepResult(QStringLiteral("updateComicMetadata"), false, QStringLiteral("Metadata mismatch after single update."));
        return 1;
    }
    printStepResult(QStringLiteral("updateComicMetadata"), true);

    // 10) bulkUpdateMetadata.
    const int bulkTargetId = importAsNewId;
    const QString bulkError = model.bulkUpdateMetadata(
        QVariantList{ createdComicId, bulkTargetId },
        QVariantMap{
            { QStringLiteral("publisher"), QStringLiteral("Bulk Publisher") },
            { QStringLiteral("year"), QStringLiteral("2026") },
        },
        QVariantMap{
            { QStringLiteral("publisher"), true },
            { QStringLiteral("year"), true },
        }
    );
    if (!bulkError.isEmpty()) {
        printStepResult(QStringLiteral("bulkUpdateMetadata"), false, bulkError);
        return 1;
    }
    const QVariantMap bulkMetaA = model.loadComicMetadata(createdComicId);
    const QVariantMap bulkMetaB = model.loadComicMetadata(bulkTargetId);
    if (bulkMetaA.value(QStringLiteral("publisher")).toString() != QStringLiteral("Bulk Publisher")
        || bulkMetaB.value(QStringLiteral("publisher")).toString() != QStringLiteral("Bulk Publisher")
        || bulkMetaA.value(QStringLiteral("year")).toInt() != 2026
        || bulkMetaB.value(QStringLiteral("year")).toInt() != 2026) {
        printStepResult(QStringLiteral("bulkUpdateMetadata"), false, QStringLiteral("Bulk changes not applied to all ids."));
        return 1;
    }
    printStepResult(QStringLiteral("bulkUpdateMetadata"), true);

    // 10.1) bulkUpdateMetadata with same values should still succeed.
    const QString bulkSameValuesError = model.bulkUpdateMetadata(
        QVariantList{ createdComicId, bulkTargetId },
        QVariantMap{
            { QStringLiteral("publisher"), QStringLiteral("Bulk Publisher") },
            { QStringLiteral("year"), QStringLiteral("2026") },
        },
        QVariantMap{
            { QStringLiteral("publisher"), true },
            { QStringLiteral("year"), true },
        }
    );
    if (!bulkSameValuesError.isEmpty()) {
        printStepResult(QStringLiteral("bulkUpdateMetadata same-values"), false, bulkSameValuesError);
        return 1;
    }
    printStepResult(QStringLiteral("bulkUpdateMetadata same-values"), true);

    // 10.2) bulkUpdateMetadata with stale/missing target id must fail without partial update.
    const QVariantMap beforeMissingBulkMeta = model.loadComicMetadata(createdComicId);
    const QString bulkMissingIdError = model.bulkUpdateMetadata(
        QVariantList{ createdComicId, 999999 },
        QVariantMap{
            { QStringLiteral("publisher"), QStringLiteral("Should Not Apply") },
        },
        QVariantMap{
            { QStringLiteral("publisher"), true },
        }
    );
    if (bulkMissingIdError.isEmpty() || !bulkMissingIdError.contains(QStringLiteral("no longer exist"))) {
        printStepResult(QStringLiteral("bulkUpdateMetadata missing-id"), false, QStringLiteral("Missing-id bulk update did not fail as expected."));
        return 1;
    }
    const QVariantMap afterMissingBulkMeta = model.loadComicMetadata(createdComicId);
    if (afterMissingBulkMeta.value(QStringLiteral("publisher")).toString() != beforeMissingBulkMeta.value(QStringLiteral("publisher")).toString()) {
        printStepResult(QStringLiteral("bulkUpdateMetadata missing-id"), false, QStringLiteral("Existing row changed during missing-id bulk update."));
        return 1;
    }
    printStepResult(QStringLiteral("bulkUpdateMetadata missing-id"), true);

    // 10.3) bulkUpdateMetadata with stale file-path target must fail before any live file move.
    int bulkStalePathId = 0;
    const DirtyRestoreSeed bulkStalePathSeed = {
        QDir(libraryDirPath).filePath(QStringLiteral("Bulk Stale/bulk-stale.cbz")),
        QStringLiteral("bulk-stale.cbz"),
        QStringLiteral("Bulk Stale"),
        QStringLiteral("bulk stale"),
        QStringLiteral("1"),
        QStringLiteral("13"),
        QStringLiteral("Bulk Stale #13"),
        QString(),
        QString(),
        QString(),
        QString()
    };
    if (!insertDirtyRestoreRowEx(dbPath, bulkStalePathSeed, bulkStalePathId, error)) {
        printStepResult(QStringLiteral("bulkUpdateMetadata stale-path setup"), false, error);
        return 1;
    }
    const QString pathBeforeStaleSeriesMove = model.loadComicMetadata(createdComicId).value(QStringLiteral("filePath")).toString();
    const QString bulkStalePathError = model.bulkUpdateMetadata(
        QVariantList{ createdComicId, bulkStalePathId },
        QVariantMap{
            { QStringLiteral("series"), QStringLiteral("Broken Regression") },
        },
        QVariantMap{
            { QStringLiteral("series"), true },
        }
    );
    if (bulkStalePathError.isEmpty() || !bulkStalePathError.contains(QStringLiteral("no longer available on disk"))) {
        printStepResult(QStringLiteral("bulkUpdateMetadata stale-path"), false, QStringLiteral("Stale-path bulk update did not fail as expected."));
        return 1;
    }
    const QVariantMap afterStaleSeriesMoveMeta = model.loadComicMetadata(createdComicId);
    if (afterStaleSeriesMoveMeta.value(QStringLiteral("filePath")).toString() != pathBeforeStaleSeriesMove) {
        printStepResult(QStringLiteral("bulkUpdateMetadata stale-path"), false, QStringLiteral("Live archive moved during stale-path bulk update."));
        return 1;
    }
    printStepResult(QStringLiteral("bulkUpdateMetadata stale-path"), true);

    // 10.4) bulkUpdateMetadata with series move: files must move to target folder and old folder should be removed.
    const QString oldSeriesFolder = QFileInfo(bulkMetaA.value(QStringLiteral("filePath")).toString()).absolutePath();
    const QString bulkSeriesMoveError = model.bulkUpdateMetadata(
        QVariantList{ createdComicId, bulkTargetId },
        QVariantMap{
            { QStringLiteral("series"), QStringLiteral("Merged Regression") },
        },
        QVariantMap{
            { QStringLiteral("series"), true },
        }
    );
    if (!bulkSeriesMoveError.isEmpty()) {
        printStepResult(QStringLiteral("bulkUpdateMetadata series-move"), false, bulkSeriesMoveError);
        return 1;
    }
    const QVariantMap movedMetaA = model.loadComicMetadata(createdComicId);
    const QVariantMap movedMetaB = model.loadComicMetadata(bulkTargetId);
    const QString movedPathA = movedMetaA.value(QStringLiteral("filePath")).toString();
    const QString movedPathB = movedMetaB.value(QStringLiteral("filePath")).toString();
    if (QFileInfo(movedPathA).absoluteDir().dirName() != QStringLiteral("Merged Regression")
        || QFileInfo(movedPathB).absoluteDir().dirName() != QStringLiteral("Merged Regression")) {
        printStepResult(QStringLiteral("bulkUpdateMetadata series-move"), false, QStringLiteral("Moved archives are not in target series folder."));
        return 1;
    }
    if (QFileInfo(oldSeriesFolder).exists()) {
        printStepResult(QStringLiteral("bulkUpdateMetadata series-move"), false, QStringLiteral("Old series folder was not cleaned up."));
        return 1;
    }
    printStepResult(QStringLiteral("bulkUpdateMetadata series-move"), true);

    // 10.5) bulkUpdateMetadata series-move with stale target id must not move live files.
    const QString pathBeforeFailedSeriesMove = movedMetaA.value(QStringLiteral("filePath")).toString();
    const QString failedSeriesMoveError = model.bulkUpdateMetadata(
        QVariantList{ createdComicId, 999999 },
        QVariantMap{
            { QStringLiteral("series"), QStringLiteral("Broken Regression") },
        },
        QVariantMap{
            { QStringLiteral("series"), true },
        }
    );
    if (failedSeriesMoveError.isEmpty() || !failedSeriesMoveError.contains(QStringLiteral("no longer exist"))) {
        printStepResult(QStringLiteral("bulkUpdateMetadata series-move missing-id"), false, QStringLiteral("Series-move missing-id path did not fail as expected."));
        return 1;
    }
    const QVariantMap afterFailedSeriesMoveMeta = model.loadComicMetadata(createdComicId);
    if (afterFailedSeriesMoveMeta.value(QStringLiteral("filePath")).toString() != pathBeforeFailedSeriesMove
        || QFileInfo(afterFailedSeriesMoveMeta.value(QStringLiteral("filePath")).toString()).absoluteDir().dirName() != QStringLiteral("Merged Regression")) {
        printStepResult(QStringLiteral("bulkUpdateMetadata series-move missing-id"), false, QStringLiteral("Live file moved during failed stale series-move update."));
        return 1;
    }
    printStepResult(QStringLiteral("bulkUpdateMetadata series-move missing-id"), true);

    // 10.6) large curated series: replacing one issue must preserve metadata, count, and stay ghost-free across repeated cycles.
    const int curatedSeriesBaseCount = model.totalCount();
    int curatedSeriesTargetId = 0;
    for (int issueIndex = 1; issueIndex <= 100; issueIndex += 1) {
        const QString paddedIssue = QStringLiteral("%1").arg(issueIndex, 3, 10, QLatin1Char('0'));
        const QVariantMap curatedSeriesValues = {
            { QStringLiteral("series"), QStringLiteral("Curated Marathon") },
            { QStringLiteral("volume"), QStringLiteral("1") },
            { QStringLiteral("issueNumber"), QString::number(issueIndex) },
            { QStringLiteral("title"), QStringLiteral("Curated Marathon #%1").arg(paddedIssue) },
            { QStringLiteral("publisher"), QStringLiteral("Regression Publisher") },
            { QStringLiteral("year"), QStringLiteral("2024") },
            { QStringLiteral("deferReload"), true },
        };
        const QVariantMap curatedSeriesResult = model.importArchiveAndCreateIssueEx(
            (issueIndex % 2 == 0) ? incomingA : incomingB,
            QStringLiteral("curated-marathon-%1.cbz").arg(paddedIssue),
            curatedSeriesValues
        );
        if (!ensureImportSuccess(curatedSeriesResult, QStringLiteral("created"), error)) {
            printStepResult(QStringLiteral("Large curated series setup"), false, error);
            return 1;
        }
        if (issueIndex == 42) {
            curatedSeriesTargetId = curatedSeriesResult.value(QStringLiteral("comicId")).toInt();
        }
    }
    model.reload();
    if (curatedSeriesTargetId < 1) {
        printStepResult(QStringLiteral("Large curated series setup"), false, QStringLiteral("Target issue in the curated series was not created."));
        return 1;
    }
    if (model.totalCount() != curatedSeriesBaseCount + 100) {
        printStepResult(
            QStringLiteral("Large curated series setup"),
            false,
            QStringLiteral("Curated large-series import did not produce the expected issue count.")
        );
        return 1;
    }

    const QString curatedMetadataError = model.updateComicMetadata(curatedSeriesTargetId, {
        { QStringLiteral("title"), QStringLiteral("Curated Marathon #042 Definitive") },
        { QStringLiteral("publisher"), QStringLiteral("Curated Marathon House") },
        { QStringLiteral("summary"), QStringLiteral("Hand curated summary for issue 42.") },
        { QStringLiteral("readStatus"), QStringLiteral("read") },
        { QStringLiteral("currentPage"), QStringLiteral("37") },
    });
    if (!curatedMetadataError.isEmpty()) {
        printStepResult(QStringLiteral("Large curated series setup"), false, curatedMetadataError);
        return 1;
    }

    const int curatedStableCount = model.totalCount();
    QString curatedActiveFilename = model.loadComicMetadata(curatedSeriesTargetId).value(QStringLiteral("filename")).toString();
    if (curatedActiveFilename.isEmpty()) {
        printStepResult(QStringLiteral("Large curated series setup"), false, QStringLiteral("Target curated issue has no filename before replace cycles."));
        return 1;
    }

    for (int cycle = 1; cycle <= 3; cycle += 1) {
        const QString curatedDeleteError = model.deleteComicFilesKeepRecord(curatedSeriesTargetId);
        if (!curatedDeleteError.isEmpty()) {
            printStepResult(QStringLiteral("Large curated series replace"), false, curatedDeleteError);
            return 1;
        }

        QVector<int> curatedDetachedIds;
        if (!loadDetachedRestoreIdsForKey(
                dbPath,
                QStringLiteral("curated marathon"),
                QStringLiteral("1"),
                QStringLiteral("42"),
                curatedActiveFilename,
                curatedDetachedIds,
                error
            )) {
            printStepResult(QStringLiteral("Large curated series replace"), false, error);
            return 1;
        }
        if (curatedDetachedIds.size() != 1 || curatedDetachedIds.first() != curatedSeriesTargetId) {
            printStepResult(
                QStringLiteral("Large curated series replace"),
                false,
                QStringLiteral("Repeated replace cycles must leave exactly one detached recovery row for the target issue.")
            );
            return 1;
        }

        const QVariantMap curatedRestoreValues = {
            { QStringLiteral("series"), QStringLiteral("Curated Marathon") },
            { QStringLiteral("volume"), QStringLiteral("1") },
            { QStringLiteral("issueNumber"), QStringLiteral("42") },
            { QStringLiteral("title"), QStringLiteral("Incoming Replacement #%1").arg(QString::number(cycle)) },
            { QStringLiteral("publisher"), QStringLiteral("Incoming Replacement Publisher") },
            { QStringLiteral("importIntent"), QStringLiteral("series_add") },
            { QStringLiteral("importContextSeries"), QStringLiteral("Curated Marathon") },
            { QStringLiteral("deferReload"), true },
        };
        const QVariantMap curatedRestoreResult = model.importArchiveAndCreateIssueEx(
            (cycle % 2 == 0) ? incomingC : incomingB,
            QStringLiteral("curated-marathon-042-replace-%1.cbz").arg(QString::number(cycle)),
            curatedRestoreValues
        );
        if (!ensureImportSuccess(curatedRestoreResult, QStringLiteral("restored"), error)) {
            printStepResult(QStringLiteral("Large curated series replace"), false, error);
            return 1;
        }
        if (curatedRestoreResult.value(QStringLiteral("comicId")).toInt() != curatedSeriesTargetId) {
            printStepResult(
                QStringLiteral("Large curated series replace"),
                false,
                QStringLiteral("Series add replacement must reconnect the curated issue instead of creating a new row.")
            );
            return 1;
        }

        const QVariantMap curatedCycleMeta = model.loadComicMetadata(curatedSeriesTargetId);
        if (curatedCycleMeta.value(QStringLiteral("title")).toString() != QStringLiteral("Curated Marathon #042 Definitive")
            || curatedCycleMeta.value(QStringLiteral("publisher")).toString() != QStringLiteral("Curated Marathon House")
            || curatedCycleMeta.value(QStringLiteral("summary")).toString() != QStringLiteral("Hand curated summary for issue 42.")
            || curatedCycleMeta.value(QStringLiteral("readStatus")).toString() != QStringLiteral("read")
            || curatedCycleMeta.value(QStringLiteral("currentPage")).toInt() != 37) {
            printStepResult(
                QStringLiteral("Large curated series replace"),
                false,
                QStringLiteral("Curated issue metadata was not preserved during the replacement cycle.")
            );
            return 1;
        }

        curatedActiveFilename = curatedCycleMeta.value(QStringLiteral("filename")).toString();
        if (curatedActiveFilename.isEmpty()) {
            printStepResult(
                QStringLiteral("Large curated series replace"),
                false,
                QStringLiteral("Curated issue lost its active filename after replacement.")
            );
            return 1;
        }
    }

    model.reload();
    if (model.totalCount() != curatedStableCount) {
        printStepResult(
            QStringLiteral("Large curated series replace"),
            false,
            QStringLiteral("Curated issue replacement changed the total issue count in the large series.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Large curated series replace"), true);

    // 11) series metadata save/load (with persistence across model instances).
    model.reload();
    const QModelIndex createdRow = findRowByComicId(model, idRole, createdComicId);
    if (!createdRow.isValid()) {
        printStepResult(QStringLiteral("Series summary setup"), false, QStringLiteral("Created row not found in model."));
        return 1;
    }
    const QString seriesGroupKey = model.data(createdRow, seriesGroupKeyRole).toString();
    if (seriesGroupKey.isEmpty()) {
        printStepResult(QStringLiteral("Series summary setup"), false, QStringLiteral("seriesGroupKey is empty."));
        return 1;
    }

    const QString summaryText = QStringLiteral("Regression summary: persisted.");
    const QString seriesTitleText = QStringLiteral("Regression Series Title");
    const QString saveSeriesMetadataError = model.setSeriesMetadataForKey(seriesGroupKey, {
        { QStringLiteral("summary"), summaryText },
        { QStringLiteral("seriesTitle"), seriesTitleText }
    });
    if (!saveSeriesMetadataError.isEmpty()) {
        printStepResult(QStringLiteral("Series metadata save"), false, saveSeriesMetadataError);
        return 1;
    }
    const QVariantMap readSeriesMetadata = model.seriesMetadataForKey(seriesGroupKey);
    const QString readSummary = model.seriesSummaryForKey(seriesGroupKey);
    if (readSummary != summaryText || readSeriesMetadata.value(QStringLiteral("seriesTitle")).toString() != seriesTitleText) {
        printStepResult(QStringLiteral("Series metadata save"), false, QStringLiteral("Read series metadata differs from saved values."));
        return 1;
    }

    ComicsListModel secondModel;
    const QString readSummarySecondModel = secondModel.seriesSummaryForKey(seriesGroupKey);
    const QVariantMap readSeriesMetadataSecondModel = secondModel.seriesMetadataForKey(seriesGroupKey);
    if (readSummarySecondModel != summaryText
        || readSeriesMetadataSecondModel.value(QStringLiteral("seriesTitle")).toString() != seriesTitleText) {
        printStepResult(QStringLiteral("Series metadata persistence"), false, QStringLiteral("Series metadata not persisted across model instances."));
        return 1;
    }
    const QString clearSummaryError = secondModel.removeSeriesSummaryForKey(seriesGroupKey);
    if (!clearSummaryError.isEmpty()) {
        printStepResult(QStringLiteral("Series summary clear"), false, clearSummaryError);
        return 1;
    }
    const QVariantMap seriesMetadataAfterSummaryClear = secondModel.seriesMetadataForKey(seriesGroupKey);
    if (!secondModel.seriesSummaryForKey(seriesGroupKey).isEmpty()) {
        printStepResult(QStringLiteral("Series summary clear"), false, QStringLiteral("Summary still present after remove."));
        return 1;
    }
    if (seriesMetadataAfterSummaryClear.value(QStringLiteral("seriesTitle")).toString() != seriesTitleText) {
        printStepResult(QStringLiteral("Series summary clear"), false, QStringLiteral("Series title should survive summary-only clear."));
        return 1;
    }
    const QString clearSeriesMetadataError = secondModel.removeSeriesMetadataForKey(seriesGroupKey);
    if (!clearSeriesMetadataError.isEmpty()) {
        printStepResult(QStringLiteral("Series metadata clear"), false, clearSeriesMetadataError);
        return 1;
    }
    const QVariantMap seriesMetadataAfterClear = secondModel.seriesMetadataForKey(seriesGroupKey);
    if (!seriesMetadataAfterClear.value(QStringLiteral("seriesTitle")).toString().isEmpty()
        || !seriesMetadataAfterClear.value(QStringLiteral("summary")).toString().isEmpty()) {
        printStepResult(QStringLiteral("Series metadata clear"), false, QStringLiteral("Series metadata still present after remove."));
        return 1;
    }
    printStepResult(QStringLiteral("Series metadata save/load"), true);

    // 12) deleteComicHard cleanup check (used in rollback flows).
    const QString newRowPath = importAsNewResult.value(QStringLiteral("filePath")).toString();
    const QString hardDeleteError = model.deleteComicHard(importAsNewId);
    if (!hardDeleteError.isEmpty()) {
        printStepResult(QStringLiteral("deleteComicHard"), false, hardDeleteError);
        return 1;
    }
    if (!newRowPath.isEmpty() && QFileInfo::exists(newRowPath)) {
        printStepResult(QStringLiteral("deleteComicHard"), false, QStringLiteral("Archive file still exists after hard delete."));
        return 1;
    }
    const QVariantMap deletedMeta = model.loadComicMetadata(importAsNewId);
    if (!deletedMeta.value(QStringLiteral("error")).toString().contains(QStringLiteral("not found"), Qt::CaseInsensitive)) {
        printStepResult(QStringLiteral("deleteComicHard"), false, QStringLiteral("Deleted row is still accessible."));
        return 1;
    }
    printStepResult(QStringLiteral("deleteComicHard"), true);

    QTextStream(stdout) << "[OK] Regression completed.\n";
    return 0;
}
