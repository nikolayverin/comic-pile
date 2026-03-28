#include "storage/readerrequestutils.h"

#include <QSet>

namespace {

bool matchesComicPendingImageKey(const QString &pendingKey, int comicId)
{
    const QString legacyThumbKey = QStringLiteral("thumb:%1").arg(comicId);
    const QString thumbPrefix = QStringLiteral("thumb:%1:").arg(comicId);
    const QString pagePrefix = QStringLiteral("page:%1:").arg(comicId);
    return pendingKey == legacyThumbKey
        || pendingKey.startsWith(thumbPrefix)
        || pendingKey.startsWith(pagePrefix);
}

} // namespace

namespace ComicReaderRequests {

QString pagePendingKey(int comicId, const QString &cacheStamp, int pageIndex)
{
    return QStringLiteral("page:%1:%2:%3").arg(comicId).arg(cacheStamp).arg(pageIndex);
}

QString thumbnailPendingKey(int comicId, const QString &cacheStamp)
{
    return QStringLiteral("thumb:%1:%2").arg(comicId).arg(cacheStamp);
}

bool beginPendingImageRequest(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QString &pendingKey,
    int requestId
)
{
    if (pendingRequestIdsByKey.contains(pendingKey)) {
        pendingRequestIdsByKey[pendingKey].push_back(requestId);
        return false;
    }

    pendingRequestIdsByKey.insert(pendingKey, { requestId });
    return true;
}

QList<int> takePendingImageRequestIds(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QString &pendingKey
)
{
    const QList<int> requestIds = pendingRequestIdsByKey.value(pendingKey);
    pendingRequestIdsByKey.remove(pendingKey);
    return requestIds;
}

QList<int> takePendingImageRequestIdsForComic(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    int comicId
)
{
    QList<int> requestIds;
    const QStringList pendingKeys = pendingRequestIdsByKey.keys();
    for (const QString &key : pendingKeys) {
        if (!matchesComicPendingImageKey(key, comicId)) {
            continue;
        }

        requestIds.append(pendingRequestIdsByKey.value(key));
        pendingRequestIdsByKey.remove(key);
    }
    return requestIds;
}

bool hasPendingImageRequest(
    const QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QString &pendingKey
)
{
    return pendingRequestIdsByKey.contains(pendingKey);
}

void clearPendingImageRequestsForComic(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    int comicId
)
{
    const QStringList pendingKeys = pendingRequestIdsByKey.keys();
    for (const QString &key : pendingKeys) {
        if (matchesComicPendingImageKey(key, comicId)) {
            pendingRequestIdsByKey.remove(key);
        }
    }
}

void clearPendingImageRequestsForComics(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    const QVector<int> &comicIds
)
{
    if (comicIds.isEmpty()) {
        return;
    }

    QSet<int> uniqueIds;
    uniqueIds.reserve(comicIds.size());
    for (int comicId : comicIds) {
        if (comicId > 0) {
            uniqueIds.insert(comicId);
        }
    }

    if (uniqueIds.isEmpty()) {
        return;
    }

    const QStringList pendingKeys = pendingRequestIdsByKey.keys();
    for (const QString &key : pendingKeys) {
        for (int comicId : uniqueIds) {
            if (matchesComicPendingImageKey(key, comicId)) {
                pendingRequestIdsByKey.remove(key);
                break;
            }
        }
    }
}

} // namespace ComicReaderRequests
