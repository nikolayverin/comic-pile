#pragma once

#include "storage/importmatching.h"

#include <QFileInfo>
#include <QString>
#include <QVariantMap>

namespace ComicImportWorkflow {

struct PersistedImportSignals {
    QString originalFilename;
    QString strictFilenameSignature;
    QString looseFilenameSignature;
    QString sourceType;
};

PersistedImportSignals resolvePersistedImportSignals(
    const QVariantMap &values,
    const QString &fallbackOriginalFilename,
    const QString &fallbackSourceType
);
QVariantMap importSignalsToVariantMap(const PersistedImportSignals &persistedSignals);

QVariantMap withImportSeriesContext(const QVariantMap &values, const QString &seriesContext);
QString ensureTargetCbzFilename(const QString &filenameHint, const QString &sourceFilename);
QString importIntentKey(const QVariantMap &values);
bool hasNarrowImportSeriesContext(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
);
bool shouldAllowMetadataRestoreForImport(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
);

ComicImportMatching::ImportIdentityPassport buildArchiveImportPassport(
    const QFileInfo &sourceInfo,
    const QString &normalizedSourcePath,
    const QString &filenameHint,
    const QVariantMap &values
);
ComicImportMatching::ImportIdentityPassport buildImageFolderImportPassport(
    const QFileInfo &folderInfo,
    const QString &normalizedFolderPath,
    const QString &filenameHint,
    const QVariantMap &values
);

} // namespace ComicImportWorkflow
