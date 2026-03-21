#pragma once

#include <QString>
#include <QVariantMap>

namespace ComicInfoOps {

QVariantMap exportComicInfoXml(const QString &dbPath, int comicId);
QString syncComicInfoToArchive(const QString &dbPath, int comicId);
QVariantMap buildComicInfoImportPatch(const QString &dbPath, int comicId, const QString &mode);

} // namespace ComicInfoOps
