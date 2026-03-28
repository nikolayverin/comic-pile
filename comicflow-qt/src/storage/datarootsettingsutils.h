#pragma once

#include <QString>

namespace ComicDataRootSettings {

QString normalizePathInput(const QString &rawInput);
QString normalizedFolderPath(const QString &rawPath);
QString persistedFolderPathForDisplay(const QString &rawPath);

QString configuredDataRootOverridePath();
QString pendingDataRootRelocationPath();
QString resolveActiveDataRootPath();

bool writeConfiguredDataRootOverridePath(const QString &rawPath);
bool writePendingDataRootRelocationPath(const QString &rawPath, QString &errorText);
bool clearPendingDataRootRelocationPath();

bool hasExternalDataRootOverride();
bool isSameOrNestedFolderPath(const QString &leftPath, const QString &rightPath);

} // namespace ComicDataRootSettings
