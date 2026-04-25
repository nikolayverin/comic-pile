#pragma once

#include <QString>

class QSqlDatabase;

namespace ComicStorageSqlite {

int connectionBusyTimeoutMs();

bool openDatabaseConnection(
    QSqlDatabase &db,
    const QString &dbPath,
    const QString &connectionName,
    QString &errorText
);

} // namespace ComicStorageSqlite
