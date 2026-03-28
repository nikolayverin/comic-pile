#include "storage/issuefileops.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/sqliteconnectionutils.h"
#include "storage/storedpathutils.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

} // namespace

namespace ComicIssueFileOps {

QString applyComicFilePathBindings(
    const QString &dbPath,
    const QString &dataRoot,
    const QVector<ComicFilePathBinding> &bindings,
    const QString &connectionTag
)
{
    if (bindings.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_%1_%2")
        .arg(connectionTag, QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    QString result;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    if (!db.transaction()) {
        result = QStringLiteral("Failed to start transaction: %1").arg(db.lastError().text());
    } else {
        QSqlQuery updateQuery(db);
        updateQuery.prepare(QStringLiteral("UPDATE comics SET file_path = ? WHERE id = ?"));
        for (const ComicFilePathBinding &binding : bindings) {
            const QString storedFilePath = binding.filePath.trimmed().isEmpty()
                ? QString()
                : ComicStoragePaths::persistPathForDataRoot(dataRoot, binding.filePath);
            updateQuery.bindValue(0, storedFilePath);
            updateQuery.bindValue(1, binding.comicId);
            if (!updateQuery.exec()) {
                result = QStringLiteral("Failed to update file binding for id %1: %2")
                    .arg(binding.comicId)
                    .arg(updateQuery.lastError().text());
                break;
            }
            if (updateQuery.numRowsAffected() < 1) {
                result = QStringLiteral("Issue id %1 not found.").arg(binding.comicId);
                break;
            }
            updateQuery.finish();
        }

        if (!result.isEmpty()) {
            db.rollback();
        } else if (!db.commit()) {
            result = QStringLiteral("Failed to commit transaction: %1").arg(db.lastError().text());
        }
    }

    db.close();
    return result;
}

QString loadComicFilePath(
    const QString &dbPath,
    const QString &dataRoot,
    int comicId,
    QString &filePathOut
)
{
    filePathOut.clear();
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString connectionName = QStringLiteral("comic_pile_issue_file_path_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QSqlQuery selectQuery(db);
    selectQuery.prepare(
        QStringLiteral(
            "SELECT COALESCE(file_path, ''), COALESCE(filename, '') "
            "FROM comics WHERE id = ? LIMIT 1"
        )
    );
    selectQuery.addBindValue(comicId);
    if (!selectQuery.exec()) {
        const QString error = QStringLiteral("Failed to read issue before file delete: %1")
            .arg(selectQuery.lastError().text());
        db.close();
        return error;
    }
    if (!selectQuery.next()) {
        db.close();
        return QStringLiteral("Issue id %1 not found.").arg(comicId);
    }

    filePathOut = ComicStoragePaths::resolveStoredArchivePath(
        dataRoot,
        trimOrEmpty(selectQuery.value(0)),
        trimOrEmpty(selectQuery.value(1))
    );
    db.close();
    return {};
}

QString hardDeleteComicRecord(
    const QString &dbPath,
    int comicId
)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString connectionName = QStringLiteral("comic_pile_delete_hard_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QSqlQuery deleteQuery(db);
    deleteQuery.prepare(QStringLiteral("DELETE FROM comics WHERE id = ?"));
    deleteQuery.addBindValue(comicId);
    if (!deleteQuery.exec()) {
        const QString error = QStringLiteral("Failed to hard delete issue: %1").arg(deleteQuery.lastError().text());
        db.close();
        return error;
    }
    if (deleteQuery.numRowsAffected() < 1) {
        db.close();
        return QStringLiteral("Issue id %1 not found.").arg(comicId);
    }

    db.close();
    return {};
}

QString relinkComicFileKeepMetadata(
    const QString &dbPath,
    const QString &dataRoot,
    const RelinkInput &input
)
{
    if (input.comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString connectionName = QStringLiteral("comic_pile_relink_issue_file_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    QString resultError;

    QSqlDatabase db;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QSqlQuery updateQuery(db);
    if (input.updateImportSignals) {
        updateQuery.prepare(
            QStringLiteral(
                "UPDATE comics SET "
                "file_path = ?, filename = ?, "
                "import_original_filename = ?, import_strict_filename_signature = ?, "
                "import_loose_filename_signature = ?, import_source_type = ? "
                "WHERE id = ?"
            )
        );
    } else {
        updateQuery.prepare(QStringLiteral("UPDATE comics SET file_path = ?, filename = ? WHERE id = ?"));
    }
    updateQuery.addBindValue(ComicStoragePaths::persistPathForDataRoot(dataRoot, input.absoluteFilePath));
    updateQuery.addBindValue(input.filename);
    if (input.updateImportSignals) {
        updateQuery.addBindValue(input.importOriginalFilename);
        updateQuery.addBindValue(input.importStrictFilenameSignature);
        updateQuery.addBindValue(input.importLooseFilenameSignature);
        updateQuery.addBindValue(input.importSourceType);
    }
    updateQuery.addBindValue(input.comicId);

    if (!updateQuery.exec()) {
        resultError = QStringLiteral("Failed to relink issue file: %1").arg(updateQuery.lastError().text());
    } else if (updateQuery.numRowsAffected() < 1) {
        resultError = QStringLiteral("Issue id %1 not found.").arg(input.comicId);
    }

    db.close();
    return resultError;
}

} // namespace ComicIssueFileOps
