#pragma once

#include <QHash>
#include <QList>
#include <QString>
#include <QVector>

namespace ComicReaderRequests {

QString pagePendingKey(int comicId, const QString &cacheStamp, int pageIndex);
QString thumbnailPendingKey(int comicId, const QString &cacheStamp);

bool beginPendingImageRequest(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QString &pendingKey,
    int requestId
);

QList<int> takePendingImageRequestIds(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QString &pendingKey
);

bool hasPendingImageRequest(
    const QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QString &pendingKey
);

void clearPendingImageRequestsForComic(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    int comicId
);

void clearPendingImageRequestsForComics(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QVector<int> &comicIds
);

} // namespace ComicReaderRequests
