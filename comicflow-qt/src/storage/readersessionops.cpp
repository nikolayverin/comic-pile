#include "storage/readersessionops.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/sqliteconnectionutils.h"

#include <QUuid>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace ComicReaderSessionOps {

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

} // namespace

ReaderIssueRecord loadReaderIssueRecord(const QString &dbPath, int comicId)
{
    ReaderIssueRecord result;
    if (comicId < 1) {
        result.error = QStringLiteral("Invalid issue id.");
        return result;
    }

    const QString connectionName = QStringLiteral("comic_pile_reader_session_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db;
    QString openError;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        result.error = openError;
        return result;
    }

    QSqlQuery query(db);
    query.prepare(
        "SELECT "
        "file_path, filename, COALESCE(series, ''), COALESCE(series_key, ''), COALESCE(title, ''), "
        "COALESCE(current_page, 0), COALESCE(bookmark_page, 0), COALESCE(favorite_active, 0) "
        "FROM comics WHERE id = ? LIMIT 1"
    );
    query.addBindValue(comicId);
    if (!query.exec()) {
        result.error = QStringLiteral("Failed to read issue for reader: %1").arg(query.lastError().text());
        db.close();
        return result;
    }

    if (!query.next()) {
        result.error = QStringLiteral("Issue id %1 not found.").arg(comicId);
        db.close();
        return result;
    }

    result.found = true;
    result.filePath = trimOrEmpty(query.value(0));
    result.filename = trimOrEmpty(query.value(1));
    result.series = trimOrEmpty(query.value(2));
    result.seriesKey = trimOrEmpty(query.value(3));
    result.title = trimOrEmpty(query.value(4));
    result.currentPage = query.value(5).toInt();
    result.bookmarkPage = query.value(6).toInt();
    result.favoriteActive = query.value(7).toInt() > 0;
    db.close();
    return result;
}

QString saveReaderProgress(
    const QString &dbPath,
    int comicId,
    int currentPage,
    const QString &readStatus
)
{
    const QString connectionName = QStringLiteral("comic_pile_reader_progress_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db;
    QString openError;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QSqlQuery query(db);
    query.prepare(QStringLiteral("UPDATE comics SET current_page = ?, read_status = ? WHERE id = ?"));
    query.addBindValue(currentPage);
    query.addBindValue(readStatus);
    query.addBindValue(comicId);
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to save reader progress: %1").arg(query.lastError().text());
        db.close();
        return error;
    }
    if (query.numRowsAffected() < 1) {
        db.close();
        return QStringLiteral("Issue id %1 not found.").arg(comicId);
    }

    db.close();
    return {};
}

QString saveReaderBookmark(
    const QString &dbPath,
    int comicId,
    int bookmarkPage
)
{
    const QString connectionName = QStringLiteral("comic_pile_reader_bookmark_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db;
    QString openError;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "UPDATE comics "
            "SET bookmark_page = ?, bookmark_added_at = CASE WHEN ? > 0 THEN datetime('now') ELSE '' END "
            "WHERE id = ?"
        )
    );
    query.addBindValue(bookmarkPage);
    query.addBindValue(bookmarkPage);
    query.addBindValue(comicId);
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to save reader bookmark: %1").arg(query.lastError().text());
        db.close();
        return error;
    }
    if (query.numRowsAffected() < 1) {
        db.close();
        return QStringLiteral("Issue id %1 not found.").arg(comicId);
    }

    db.close();
    return {};
}

QString saveReaderFavorite(
    const QString &dbPath,
    int comicId,
    bool favoriteActive
)
{
    const QString connectionName = QStringLiteral("comic_pile_reader_favorite_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db;
    QString openError;
    if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
        return openError;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "UPDATE comics "
            "SET favorite_active = ?, favorite_added_at = CASE WHEN ? > 0 THEN datetime('now') ELSE '' END "
            "WHERE id = ?"
        )
    );
    query.addBindValue(favoriteActive ? 1 : 0);
    query.addBindValue(favoriteActive ? 1 : 0);
    query.addBindValue(comicId);
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to save reader favorite: %1").arg(query.lastError().text());
        db.close();
        return error;
    }
    if (query.numRowsAffected() < 1) {
        db.close();
        return QStringLiteral("Issue id %1 not found.").arg(comicId);
    }

    db.close();
    return {};
}

} // namespace ComicReaderSessionOps
