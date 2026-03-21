#pragma once

#include <functional>

#include <QString>
#include <QStringList>
#include <QVariantMap>

namespace ComicReaderPayloads {

using ArchiveExtractFn = std::function<bool(
    const QString &archivePath,
    const QString &entryName,
    const QString &outputFilePath,
    QString &errorText
)>;

QVariantMap buildCachedReaderSessionPayload(
    int comicId,
    const QString &archivePath,
    const QStringList &entries,
    const QString &seriesKey,
    const QString &displayTitle,
    int currentPage,
    int bookmarkPage,
    bool favoriteActive
);

QVariantMap loadReaderPagePayload(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath,
    const QStringList &entries,
    int pageIndex,
    const ArchiveExtractFn &extractArchiveEntry
);

QString cachedIssueThumbnailSource(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath
);

} // namespace ComicReaderPayloads
