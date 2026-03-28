#pragma once

#include <QString>
#include <QStringList>

namespace ComicStoragePaths {

QString normalizePathInput(const QString &rawInput);
QString absolutePathFromInput(const QString &rawInput);
QString absoluteExistingFilePath(const QString &rawInput);
QString absoluteExistingDirPath(const QString &rawInput);
QString persistPathForRoot(const QString &rootPath, const QString &absolutePath);
QString persistPathForDataRoot(const QString &dataRoot, const QString &absolutePath);
QString resolveStoredPathAgainstRoot(
    const QString &rootPath,
    const QString &storedPath,
    const QString &storedFilename = QString()
);
QString resolveStoredArchivePath(
    const QString &dataRoot,
    const QString &storedFilePath,
    const QString &storedFilename = QString()
);
QStringList archivePathLookupCandidates(const QString &dataRoot, const QString &path);

} // namespace ComicStoragePaths
