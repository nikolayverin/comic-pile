#pragma once

#include <QString>

namespace ComicModelUtils {

QString normalizeSeriesKey(const QString &value);
QString normalizeVolumeKey(const QString &value);
QString normalizeReadStatus(const QString &value);
QString makeGroupTitle(const QString &groupKey);
QString resolveLibraryFilePath(const QString &libraryPath, const QString &inputFilename);
QString resolveStoredArchivePathForDataRoot(
    const QString &dataRoot,
    const QString &storedFilePath,
    const QString &storedFilename
);
QString baseNameWithoutExtension(const QString &filename);

} // namespace ComicModelUtils
