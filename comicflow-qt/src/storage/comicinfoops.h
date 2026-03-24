#pragma once

#include <QString>
#include <QVariantMap>

namespace ComicInfoOps {

QVariantMap exportComicInfoXml(const QString &dbPath, int comicId, const QString &archivePathOverride = QString());
QString syncComicInfoToArchive(const QString &dbPath, int comicId, const QString &archivePathOverride = QString());
QVariantMap buildComicInfoImportPatch(
    const QString &dbPath,
    int comicId,
    const QString &mode,
    const QString &archivePathOverride = QString()
);

} // namespace ComicInfoOps
