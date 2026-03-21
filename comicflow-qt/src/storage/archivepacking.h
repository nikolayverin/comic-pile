#pragma once

#include <QString>

namespace ComicArchivePacking {

bool normalizeArchiveToCbz(
    const QString &sourceArchivePath,
    const QString &targetCbzPath,
    QString &errorText
);
bool createCbzFromDirectory(
    const QString &sourceDirPath,
    const QString &targetCbzPath,
    QString &errorText
);
bool packageImageFolderToCbz(
    const QString &folderPath,
    const QString &targetCbzPath,
    QString &errorText
);

} // namespace ComicArchivePacking
