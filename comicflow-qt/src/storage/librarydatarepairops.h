#pragma once

#include <QSqlDatabase>
#include <QString>

namespace ComicLibraryDataRepair {

bool backfillNormalizedSeriesKeys(QSqlDatabase &db, QString &errorText);
bool backfillImportSignals(QSqlDatabase &db, QString &errorText);
bool pruneObviousDetachedRestoreDuplicates(QSqlDatabase &db, QString &errorText);
bool canonicalizeDefaultVolumeOneMetadata(QSqlDatabase &db, QString &errorText);

} // namespace ComicLibraryDataRepair
