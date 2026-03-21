#pragma once

#include <QSqlDatabase>
#include <QString>

class LibrarySchemaManager
{
public:
    explicit LibrarySchemaManager(QString dbPath);

    QString ensureSchemaUpToDate() const;

    static bool ensureSeriesMetadataTable(QSqlDatabase &db, QString &errorText);
    static bool ensureFileFingerprintHistoryTable(QSqlDatabase &db, QString &errorText);

private:
    bool migrateSchemaToVersion1(QSqlDatabase &db, QString &errorText) const;
    bool migrateSchemaToVersion2(QSqlDatabase &db, QString &errorText) const;
    bool migrateSchemaToVersion3(QSqlDatabase &db, QString &errorText) const;
    bool migrateSchemaToVersion4(QSqlDatabase &db, QString &errorText) const;
    bool migrateSchemaToVersion5(QSqlDatabase &db, QString &errorText) const;
    bool migrateSchemaToVersion6(QSqlDatabase &db, QString &errorText) const;
    bool migrateSchemaToVersion7(QSqlDatabase &db, QString &errorText) const;
    bool backfillNormalizedSeriesKeys(QSqlDatabase &db, QString &errorText) const;
    bool backfillImportSignals(QSqlDatabase &db, QString &errorText) const;
    bool pruneObviousDetachedRestoreDuplicates(QSqlDatabase &db, QString &errorText) const;

    QString m_dbPath;
};
