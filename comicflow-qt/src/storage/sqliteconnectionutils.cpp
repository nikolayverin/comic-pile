#include "storage/sqliteconnectionutils.h"

#include <QDebug>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>

namespace ComicStorageSqlite {

namespace {

constexpr int kConnectionBusyTimeoutMs = 5000;

bool execPolicyPragma(
    QSqlDatabase &db,
    const QString &statement,
    const QString &label,
    const QString &connectionName,
    QString &errorText
)
{
    QSqlQuery query(db);
    if (query.exec(statement)) {
        return true;
    }

    errorText = QStringLiteral("Failed to apply SQLite %1 policy: %2")
        .arg(label, query.lastError().text());
    qWarning().noquote()
        << "sqlite connection policy failed"
        << QStringLiteral("connection=%1").arg(connectionName)
        << QStringLiteral("policy=%1").arg(label);
    return false;
}

} // namespace

int connectionBusyTimeoutMs()
{
    return kConnectionBusyTimeoutMs;
}

bool openDatabaseConnection(
    QSqlDatabase &db,
    const QString &dbPath,
    const QString &connectionName,
    QString &errorText
)
{
    db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    db.setConnectOptions(QStringLiteral("QSQLITE_BUSY_TIMEOUT=%1").arg(kConnectionBusyTimeoutMs));
    if (!db.open()) {
        errorText = QStringLiteral("Failed to open DB: %1").arg(db.lastError().text());
        qWarning().noquote()
            << "sqlite connection open failed"
            << QStringLiteral("connection=%1").arg(connectionName);
        return false;
    }

    if (!execPolicyPragma(
            db,
            QStringLiteral("PRAGMA busy_timeout = %1").arg(kConnectionBusyTimeoutMs),
            QStringLiteral("busy_timeout"),
            connectionName,
            errorText)
        || !execPolicyPragma(
            db,
            QStringLiteral("PRAGMA foreign_keys = ON"),
            QStringLiteral("foreign_keys"),
            connectionName,
            errorText)
        || !execPolicyPragma(
            db,
            QStringLiteral("PRAGMA journal_mode = WAL"),
            QStringLiteral("journal_mode"),
            connectionName,
            errorText)
        || !execPolicyPragma(
            db,
            QStringLiteral("PRAGMA synchronous = NORMAL"),
            QStringLiteral("synchronous"),
            connectionName,
            errorText)) {
        db.close();
        return false;
    }

    errorText.clear();
    return true;
}

} // namespace ComicStorageSqlite
