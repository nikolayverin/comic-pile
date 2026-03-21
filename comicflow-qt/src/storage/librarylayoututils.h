#pragma once

#include <QDir>
#include <QHash>
#include <QSet>
#include <QString>

namespace ComicLibraryLayout {

struct SeriesFolderState {
    QHash<QString, QString> folderBySeriesKey;
    QHash<QString, QSet<QString>> seriesKeysByFolderKey;
    QHash<QString, QString> displayFolderByFolderKey;
};

QString makeUniqueFilename(const QDir &dir, const QString &filename);
QString normalizedPathForCompare(const QString &path);
QString relativeDirUnderRoot(const QString &rootPath, const QString &filePath);
void registerSeriesFolderAssignment(SeriesFolderState &state, const QString &seriesKey, const QString &folderName);
QString assignSeriesFolderName(
    SeriesFolderState &state,
    const QString &seriesKey,
    const QString &seriesName
);
bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText);

} // namespace ComicLibraryLayout
