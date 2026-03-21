#include "storage/readerpayloadutils.h"

#include "storage/readercacheutils.h"

#include <algorithm>

#include <QFile>
#include <QFileInfo>
#include <QUrl>

namespace {

QVariantMap errorResult(const QString &message)
{
    return {
        { QStringLiteral("error"), message }
    };
}

} // namespace

namespace ComicReaderPayloads {

QVariantMap buildCachedReaderSessionPayload(
    int comicId,
    const QString &archivePath,
    const QStringList &entries,
    const QString &seriesKey,
    const QString &displayTitle,
    int currentPage,
    int bookmarkPage,
    bool favoriteActive
)
{
    if (comicId < 1 || archivePath.trimmed().isEmpty() || entries.isEmpty()) {
        return {};
    }

    const int pageCount = entries.size();
    const int effectiveBookmarkPage = (bookmarkPage > 0 && bookmarkPage <= pageCount)
        ? bookmarkPage
        : 0;
    int startPageIndex = 0;
    if (effectiveBookmarkPage > 0) {
        startPageIndex = effectiveBookmarkPage - 1;
    } else if (currentPage > 0 && pageCount > 0) {
        startPageIndex = std::clamp(currentPage - 1, 0, pageCount - 1);
    }

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("seriesKey"), seriesKey.trimmed() },
        { QStringLiteral("title"), displayTitle },
        { QStringLiteral("archivePath"), archivePath.trimmed() },
        { QStringLiteral("pageCount"), pageCount },
        { QStringLiteral("currentPage"), currentPage },
        { QStringLiteral("bookmarkPage"), bookmarkPage },
        { QStringLiteral("favoriteActive"), favoriteActive },
        { QStringLiteral("startPageIndex"), startPageIndex }
    };
}

QVariantMap loadReaderPagePayload(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath,
    const QStringList &entries,
    int pageIndex,
    const ArchiveExtractFn &extractArchiveEntry
)
{
    if (comicId < 1) {
        return errorResult(QStringLiteral("Invalid issue id."));
    }

    if (archivePath.trimmed().isEmpty() || entries.isEmpty()) {
        return errorResult(QStringLiteral("Reader session is not ready."));
    }

    if (pageIndex < 0 || pageIndex >= entries.size()) {
        return errorResult(QStringLiteral("Page index out of range."));
    }

    const QString entryName = entries.at(pageIndex);
    QString extension = QFileInfo(entryName).suffix().toLower();
    if (extension.isEmpty()) {
        extension = QStringLiteral("img");
    }

    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
    const QString cacheFilePath = ComicReaderCache::buildReaderCachePath(
        dataRoot,
        comicId,
        cacheStamp,
        pageIndex,
        extension
    );
    if (!ComicReaderCache::ensureDirForFile(cacheFilePath)) {
        return errorResult(QStringLiteral("Failed to create reader cache directory."));
    }

    const QFileInfo cachedPageInfo(cacheFilePath);
    if (cachedPageInfo.exists() && cachedPageInfo.size() <= 0) {
        QFile::remove(cacheFilePath);
    }

    if (!QFileInfo(cacheFilePath).exists()) {
        QString extractError;
        if (!extractArchiveEntry(archivePath, entryName, cacheFilePath, extractError)) {
            return errorResult(extractError);
        }
    }

    ComicReaderCache::noteReaderIssueCacheUsage(dataRoot, comicId);
    ComicReaderCache::pruneReaderCache(dataRoot);

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("pageIndex"), pageIndex },
        { QStringLiteral("displayPage"), pageIndex + 1 },
        { QStringLiteral("pageCount"), entries.size() },
        { QStringLiteral("entryName"), entryName },
        { QStringLiteral("imageSource"), QUrl::fromLocalFile(cacheFilePath).toString() }
    };
}

QString cachedIssueThumbnailSource(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath
)
{
    if (comicId < 1 || archivePath.trimmed().isEmpty()) {
        return {};
    }

    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
    const QByteArray thumbFormat = ComicReaderCache::preferredThumbnailFormat();
    const QString preferredPath = ComicReaderCache::buildThumbnailPathWithFormat(
        dataRoot,
        comicId,
        cacheStamp,
        thumbFormat
    );
    const QFileInfo preferredInfo(preferredPath);
    if (preferredInfo.exists() && preferredInfo.size() > 0) {
        return QUrl::fromLocalFile(preferredPath).toString();
    }

    return {};
}

} // namespace ComicReaderPayloads
