#pragma once

#include <QSqlDatabase>
#include <QString>

class ScopedSqlConnectionRemoval
{
public:
    explicit ScopedSqlConnectionRemoval(const QString &connectionName)
        : m_connectionName(connectionName)
    {
    }

    ~ScopedSqlConnectionRemoval()
    {
        if (!m_connectionName.isEmpty()) {
            QSqlDatabase::removeDatabase(m_connectionName);
        }
    }

    ScopedSqlConnectionRemoval(const ScopedSqlConnectionRemoval &) = delete;
    ScopedSqlConnectionRemoval &operator=(const ScopedSqlConnectionRemoval &) = delete;

private:
    QString m_connectionName;
};
