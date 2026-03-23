#include "storage/librarystoragemigrationops.h"

#include "storage/importmatching.h"
#include "storage/librarylayoututils.h"
#include "storage/startupruntimeutils.h"

#include "common/scopedsqlconnectionremoval.h"

#include <algorithm>

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QMultiHash>
#include <QSet>
#include <QStringList>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUrl>
#include <QUuid>
#include <QVariant>
#include <QVector>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString normalizeInputFilePath(const QString &rawInput)
{
    QString input = rawInput.trimmed();
    if (input.isEmpty()) return {};

    if ((input.startsWith(QLatin1Char('"')) && input.endsWith(QLatin1Char('"')))
        || (input.startsWith(QLatin1Char('\'')) && input.endsWith(QLatin1Char('\'')))) {
        input = input.mid(1, input.length() - 2).trimmed();
    }

    const QUrl url = QUrl::fromUserInput(input);
    if (url.isValid() && url.isLocalFile()) {
        return QDir::toNativeSeparators(url.toLocalFile());
    }

    return QDir::toNativeSeparators(input);
}

QString normalizeSeriesKeyValue(const QString &value)
{
    return ComicImportMatching::normalizeSeriesKey(value);
}

QString relativePathWithinDataRoot(const QString &dataRoot, const QString &absolutePath)
{
    const QFileInfo dataRootInfo(dataRoot);
    const QFileInfo absoluteInfo(absolutePath);
    const QString normalizedDataRoot = QDir::cleanPath(dataRootInfo.absoluteFilePath());
    const QString normalizedAbsolute = QDir::cleanPath(absoluteInfo.absoluteFilePath());
    if (!normalizedAbsolute.startsWith(normalizedDataRoot, Qt::CaseInsensitive)) {
        return QDir::toNativeSeparators(normalizedAbsolute);
    }
    return QDir::toNativeSeparators(QDir(normalizedDataRoot).relativeFilePath(normalizedAbsolute));
}

bool openDatabaseConnectionForPath(
    QSqlDatabase &db,
    const QString &dbPath,
    const QString &connectionName,
    QString &errorText
)
{
    db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    if (db.open()) return true;

    errorText = QStringLiteral("Failed to open DB: %1").arg(db.lastError().text());
    return false;
}

void cleanupEmptyLibraryDirs(const QString &libraryRootPath, const QStringList &candidateDirs)
{
    if (libraryRootPath.trimmed().isEmpty() || candidateDirs.isEmpty()) {
        return;
    }

    QSet<QString> uniqueDirs;
    for (const QString &dirPath : candidateDirs) {
        const QString normalized = QDir::cleanPath(QDir::fromNativeSeparators(dirPath.trimmed()));
        if (normalized.isEmpty()) continue;
        uniqueDirs.insert(normalized);
    }

    QStringList sortedDirs = uniqueDirs.values();
    std::sort(sortedDirs.begin(), sortedDirs.end(), [](const QString &left, const QString &right) {
        return left.size() > right.size();
    });

    const QString normalizedRoot = QDir::cleanPath(QDir::fromNativeSeparators(libraryRootPath.trimmed()));
    for (const QString &dirPath : sortedDirs) {
        QString current = dirPath;
        while (!current.isEmpty()) {
            const QString normalizedCurrent = QDir::cleanPath(current);
            if (!normalizedCurrent.startsWith(normalizedRoot, Qt::CaseInsensitive)
                || normalizedCurrent.compare(normalizedRoot, Qt::CaseInsensitive) == 0) {
                break;
            }

            QDir dir(normalizedCurrent);
            if (!dir.exists() || !dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot).isEmpty()) {
                break;
            }

            const QFileInfo info(normalizedCurrent);
            const QString parentPath = info.absolutePath();
            if (parentPath.isEmpty() || parentPath.compare(normalizedCurrent, Qt::CaseInsensitive) == 0) {
                break;
            }

            QDir parentDir(parentPath);
            if (!parentDir.rmdir(info.fileName())) {
                break;
            }
            current = parentPath;
        }
    }
}

} // namespace

namespace ComicLibraryStorageMigration {

QVariantMap runLibraryStorageLayoutMigration(const QString &dataRoot, const QString &dbPath)
{
    QVariantMap result;
    result.insert(QStringLiteral("changed"), false);
    result.insert(QStringLiteral("completed"), false);
    result.insert(QStringLiteral("warning"), QString());
    result.insert(QStringLiteral("error"), QString());
    result.insert(QStringLiteral("skipped"), false);
    result.insert(QStringLiteral("skipReason"), QString());

    if (dataRoot.trimmed().isEmpty() || dbPath.trimmed().isEmpty()) {
        result.insert(QStringLiteral("skipped"), true);
        result.insert(QStringLiteral("skipReason"), QStringLiteral("missing_paths"));
        return result;
    }

    if (ComicStartupRuntime::hasLibraryStorageMigrationMarker(dataRoot)) {
        result.insert(QStringLiteral("completed"), true);
        result.insert(QStringLiteral("skipped"), true);
        result.insert(QStringLiteral("skipReason"), QStringLiteral("already_completed"));
        return result;
    }

    const QFileInfo dbInfo(dbPath);
    if (!dbInfo.exists() || !dbInfo.isFile()) {
        result.insert(QStringLiteral("completed"), true);
        result.insert(QStringLiteral("skipped"), true);
        result.insert(QStringLiteral("skipReason"), QStringLiteral("missing_db"));
        return result;
    }

    const QString libraryPath = QDir(dataRoot).filePath(QStringLiteral("Library"));
    if (!QDir().mkpath(libraryPath)) {
        result.insert(
            QStringLiteral("error"),
            QStringLiteral("Failed to ensure Library folder for migration: %1").arg(libraryPath)
        );
        return result;
    }

    struct MigrationRow {
        int id = 0;
        QString filePath;
        QString filename;
        QString series;
        QString seriesKey;
    };

    QVector<MigrationRow> rows;
    QMultiHash<QString, QString> filesByFilenameLower;
    {
        QDirIterator iterator(
            libraryPath,
            QDir::Files | QDir::NoDotAndDotDot,
            QDirIterator::Subdirectories
        );
        while (iterator.hasNext()) {
            const QString filePath = QDir::toNativeSeparators(iterator.next());
            const QString fileName = QFileInfo(filePath).fileName().trimmed();
            if (fileName.isEmpty()) continue;
            filesByFilenameLower.insert(fileName.toLower(), QFileInfo(filePath).absoluteFilePath());
        }
    }

    const QString connectionName = QStringLiteral("comic_pile_migrate_library_layout_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    QStringList errors;
    QStringList dirsToCleanup;
    bool changed = false;

    {
        QSqlDatabase db;
        if (!openDatabaseConnectionForPath(db, dbPath, connectionName, openError)) {
            result.insert(QStringLiteral("error"), openError);
            return result;
        }

        QSqlQuery query(db);
        query.prepare(
            "SELECT id, COALESCE(file_path, ''), COALESCE(filename, ''), "
            "COALESCE(series, ''), COALESCE(series_key, '') "
            "FROM comics "
            "ORDER BY id"
        );
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to scan comics for migration: %1").arg(query.lastError().text());
            db.close();
            result.insert(QStringLiteral("error"), error);
            return result;
        }

        while (query.next()) {
            MigrationRow row;
            row.id = query.value(0).toInt();
            row.filePath = trimOrEmpty(query.value(1));
            row.filename = trimOrEmpty(query.value(2));
            row.series = trimOrEmpty(query.value(3));
            row.seriesKey = trimOrEmpty(query.value(4));
            rows.push_back(row);
        }

        ComicLibraryLayout::SeriesFolderState folderState;
        QSet<QString> consumedSourcePaths;

        auto chooseExistingPath = [&](const MigrationRow &row) -> QString {
            const QString normalizedDbPath = normalizeInputFilePath(row.filePath);
            if (!normalizedDbPath.isEmpty()) {
                const QFileInfo dbPathInfo(normalizedDbPath);
                if (dbPathInfo.exists() && dbPathInfo.isFile()) {
                    const QString abs = QDir::toNativeSeparators(dbPathInfo.absoluteFilePath());
                    const QString key = ComicLibraryLayout::normalizedPathForCompare(abs);
                    if (!consumedSourcePaths.contains(key)) {
                        consumedSourcePaths.insert(key);
                        return abs;
                    }
                }
            }

            const QString filename = row.filename.trimmed();
            if (filename.isEmpty()) return {};
            const QList<QString> candidates = filesByFilenameLower.values(filename.toLower());
            for (const QString &candidate : candidates) {
                const QFileInfo info(candidate);
                if (!info.exists() || !info.isFile()) continue;
                const QString abs = QDir::toNativeSeparators(info.absoluteFilePath());
                const QString key = ComicLibraryLayout::normalizedPathForCompare(abs);
                if (consumedSourcePaths.contains(key)) continue;
                consumedSourcePaths.insert(key);
                return abs;
            }
            return {};
        };

        struct ResolvedMigrationRow {
            MigrationRow row;
            QString existingPath;
        };
        QVector<ResolvedMigrationRow> resolvedRows;
        resolvedRows.reserve(rows.size());

        for (const MigrationRow &row : rows) {
            const QString existingPath = chooseExistingPath(row);
            if (existingPath.isEmpty()) continue;

            const QString normalizedSeriesKey = row.seriesKey.trimmed().isEmpty()
                ? normalizeSeriesKeyValue(row.series)
                : row.seriesKey.trimmed();

            const QString relativeDir = ComicLibraryLayout::relativeDirUnderRoot(libraryPath, existingPath);
            if (!relativeDir.isEmpty()) {
                ComicLibraryLayout::registerSeriesFolderAssignment(folderState, normalizedSeriesKey, relativeDir);
            }

            ResolvedMigrationRow resolved;
            resolved.row = row;
            resolved.row.seriesKey = normalizedSeriesKey;
            resolved.existingPath = existingPath;
            resolvedRows.push_back(resolved);
        }

        QSqlQuery updateQuery(db);
        updateQuery.prepare(
            "UPDATE comics "
            "SET file_path = ?, filename = ?, series_key = ? "
            "WHERE id = ?"
        );

        for (const ResolvedMigrationRow &resolved : resolvedRows) {
            const MigrationRow &row = resolved.row;
            const QFileInfo existingInfo(resolved.existingPath);
            if (!existingInfo.exists() || !existingInfo.isFile()) continue;

            const QString seriesName = row.series.trimmed().isEmpty()
                ? QFileInfo(row.filename).completeBaseName()
                : row.series.trimmed();
            const QString normalizedSeriesKey = row.seriesKey.trimmed().isEmpty()
                ? normalizeSeriesKeyValue(seriesName)
                : row.seriesKey.trimmed();
            const QString targetFolderName = ComicLibraryLayout::assignSeriesFolderName(
                folderState,
                normalizedSeriesKey,
                seriesName
            );
            const QString targetDirPath = QDir(libraryPath).filePath(targetFolderName);

            QString filenameValue = row.filename.trimmed();
            if (filenameValue.isEmpty()) {
                filenameValue = existingInfo.fileName();
            }
            if (filenameValue.isEmpty()) {
                filenameValue = QStringLiteral("issue-%1.cbz").arg(row.id);
            }

            QString targetFilePath = QDir(targetDirPath).filePath(filenameValue);
            const QString sourceAbsolutePath = QDir::toNativeSeparators(existingInfo.absoluteFilePath());
            const QString sourcePathKey = ComicLibraryLayout::normalizedPathForCompare(sourceAbsolutePath);
            QString targetPathKey = ComicLibraryLayout::normalizedPathForCompare(targetFilePath);

            if (sourcePathKey != targetPathKey && QFileInfo::exists(targetFilePath)) {
                const QDir targetDir(targetDirPath);
                filenameValue = ComicLibraryLayout::makeUniqueFilename(targetDir, filenameValue);
                targetFilePath = targetDir.filePath(filenameValue);
                targetPathKey = ComicLibraryLayout::normalizedPathForCompare(targetFilePath);
            }

            QString rowError;
            if (sourcePathKey != targetPathKey) {
                if (!ComicLibraryLayout::moveFileWithFallback(sourceAbsolutePath, targetFilePath, rowError)) {
                    errors.push_back(QStringLiteral("Issue %1 move failed: %2").arg(row.id).arg(rowError));
                    continue;
                }
                dirsToCleanup.push_back(existingInfo.absolutePath());
                changed = true;
            }

            const QString finalAbsolutePath = QDir::toNativeSeparators(QFileInfo(targetFilePath).absoluteFilePath());
            const bool rowChanged =
                sourcePathKey != targetPathKey
                || ComicLibraryLayout::normalizedPathForCompare(row.filePath)
                    != ComicLibraryLayout::normalizedPathForCompare(finalAbsolutePath)
                || row.filename.trimmed() != filenameValue
                || row.seriesKey.trimmed() != normalizedSeriesKey;
            updateQuery.bindValue(0, relativePathWithinDataRoot(dataRoot, finalAbsolutePath));
            updateQuery.bindValue(1, filenameValue);
            updateQuery.bindValue(2, normalizedSeriesKey);
            updateQuery.bindValue(3, row.id);
            if (!updateQuery.exec()) {
                QString rollbackError;
                if (sourcePathKey != targetPathKey) {
                    ComicLibraryLayout::moveFileWithFallback(targetFilePath, sourceAbsolutePath, rollbackError);
                }
                errors.push_back(
                    QStringLiteral("Issue %1 DB update failed: %2")
                        .arg(row.id)
                        .arg(updateQuery.lastError().text())
                );
                if (!rollbackError.isEmpty()) {
                    errors.push_back(
                        QStringLiteral("Issue %1 rollback move failed: %2")
                            .arg(row.id)
                            .arg(rollbackError)
                    );
                }
            } else if (rowChanged) {
                changed = true;
            }
            updateQuery.finish();
        }

        db.close();
    }

    cleanupEmptyLibraryDirs(libraryPath, dirsToCleanup);

    if (!errors.isEmpty()) {
        const int maxErrors = std::min(8, static_cast<int>(errors.size()));
        const QStringList head = errors.mid(0, maxErrors);
        const QString suffix = errors.size() > maxErrors
            ? QStringLiteral("\n... and %1 more").arg(errors.size() - maxErrors)
            : QString();
        result.insert(
            QStringLiteral("warning"),
            QStringLiteral("Library migration completed with warnings:\n%1%2").arg(head.join(QLatin1Char('\n'))).arg(suffix)
        );
        result.insert(QStringLiteral("changed"), changed);
        return result;
    }

    if (!ComicStartupRuntime::writeLibraryStorageMigrationMarker(dataRoot)) {
        result.insert(
            QStringLiteral("warning"),
            QStringLiteral("Library migration completed, but marker file could not be written.")
        );
        result.insert(QStringLiteral("changed"), changed);
        return result;
    }

    result.insert(QStringLiteral("changed"), changed);
    result.insert(QStringLiteral("completed"), true);
    return result;
}

} // namespace ComicLibraryStorageMigration
