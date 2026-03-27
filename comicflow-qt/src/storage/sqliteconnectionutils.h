#pragma once

#include <QString>

class QSqlDatabase;

namespace ComicStorageSqlite {

bool openDatabaseConnection(
    QSqlDatabase &db,
    const QString &dbPath,
    const QString &connectionName,
    QString &errorText
);

} // namespace ComicStorageSqlite
