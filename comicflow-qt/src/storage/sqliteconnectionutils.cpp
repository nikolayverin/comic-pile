#include "storage/sqliteconnectionutils.h"

#include <QSqlDatabase>
#include <QSqlError>

namespace ComicStorageSqlite {

bool openDatabaseConnection(
    QSqlDatabase &db,
    const QString &dbPath,
    const QString &connectionName,
    QString &errorText
)
{
    db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    if (db.open()) {
        errorText.clear();
        return true;
    }

    errorText = QStringLiteral("Failed to open DB: %1").arg(db.lastError().text());
    return false;
}

} // namespace ComicStorageSqlite
