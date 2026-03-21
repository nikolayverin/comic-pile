#pragma once

#include <QByteArray>
#include <QString>

namespace ComicReaderCache {

QString buildArchiveCacheStamp(const QString &archivePath);
QString buildReaderCachePath(
    const QString &dataRoot,
    int comicId,
    const QString &cacheStamp,
    int pageIndex,
    const QString &extension
);

QByteArray preferredThumbnailFormat();
QString buildThumbnailPathWithFormat(
    const QString &dataRoot,
    int comicId,
    const QString &cacheStamp,
    const QByteArray &format
);
QString buildSeriesHeroPathWithFormat(
    const QString &dataRoot,
    const QString &seriesKey,
    const QString &cacheStamp,
    const QByteArray &format
);
QString cachedSeriesHeroPath(const QString &dataRoot, const QString &seriesKey);
QString buildSeriesHeaderOverridePath(
    const QString &dataRoot,
    const QString &seriesKey,
    const QString &slotName,
    const QString &extension
);

void pruneThumbnailVariantsForComic(const QString &dataRoot, int comicId, const QString &keepThumbnailPath);
void pruneSeriesHeroVariantsForKey(const QString &dataRoot, const QString &seriesKey, const QString &keepHeroPath);
void pruneSeriesHeaderOverrideVariantsForKey(
    const QString &dataRoot,
    const QString &seriesKey,
    const QString &slotName,
    const QString &keepOverridePath
);
void purgeSeriesHeaderOverrideSlotForKey(const QString &dataRoot, const QString &seriesKey, const QString &slotName);
void purgeSeriesHeaderOverridesForKey(const QString &dataRoot, const QString &seriesKey);
void purgeRuntimeCacheForComic(const QString &dataRoot, int comicId);
void purgeSeriesHeroForKey(const QString &dataRoot, const QString &seriesKey);
void noteReaderIssueCacheUsage(const QString &dataRoot, int comicId);
void pruneReaderCache(const QString &dataRoot);
bool ensureDirForFile(const QString &filePath);

} // namespace ComicReaderCache
