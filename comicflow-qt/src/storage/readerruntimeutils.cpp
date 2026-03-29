#include "storage/readerruntimeutils.h"

namespace {

QString readerValueFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toString().trimmed();
}

} // namespace

namespace ComicReaderRuntime {

ReaderPageRequestState buildPageRequestState(
    int comicId,
    int requestedPageIndex,
    const QString &cachedArchivePath,
    const QStringList &cachedEntries,
    const QVariantMap &sessionFallback
)
{
    ReaderPageRequestState state;
    if (comicId < 1) {
        state.error = QStringLiteral("Invalid issue id.");
        return state;
    }

    state.archivePath = cachedArchivePath.trimmed();
    state.entries = cachedEntries;
    if (state.archivePath.isEmpty() || state.entries.isEmpty()) {
        const QString sessionError = readerValueFromMap(sessionFallback, QStringLiteral("error"));
        if (!sessionError.isEmpty()) {
            state.error = sessionError;
            return state;
        }

        state.archivePath = readerValueFromMap(sessionFallback, QStringLiteral("archivePath"));
        state.entries = sessionFallback.value(QStringLiteral("entries")).toStringList();
        if (!state.archivePath.isEmpty() && !state.entries.isEmpty()) {
            state.sessionToCache = sessionFallback;
        }
    }

    if (state.archivePath.isEmpty()) {
        state.error = QStringLiteral("Archive path is empty for issue id %1.").arg(comicId);
        return state;
    }
    if (state.entries.isEmpty()) {
        state.error = QStringLiteral("No image pages found in archive.");
        return state;
    }

    state.resolvedPageIndex = requestedPageIndex;
    if (state.resolvedPageIndex < 0 || state.resolvedPageIndex >= state.entries.size()) {
        state.resolvedPageIndex = 0;
    }

    return state;
}

QVariantMap makeAsyncImageResult(
    const QString &imageSource,
    const QString &error
)
{
    QVariantMap result;
    result.insert(QStringLiteral("imageSource"), imageSource);
    result.insert(QStringLiteral("error"), error);
    return result;
}

QVariantMap makeCanceledReaderAsyncResult()
{
    return {
        { QStringLiteral("error"), QStringLiteral("Reader session is not ready.") }
    };
}

QString warmupPagePendingKey(int comicId, int pageIndex)
{
    return QStringLiteral("reader-warm:%1:%2").arg(comicId).arg(pageIndex);
}

void removePendingRequestIds(
    QHash<int, QList<int>> &pendingRequestIdsByComicId,
    int comicId,
    const QList<int> &requestIds
)
{
    if (comicId < 1 || requestIds.isEmpty()) {
        return;
    }

    QList<int> pendingRequestIds = pendingRequestIdsByComicId.value(comicId);
    if (pendingRequestIds.isEmpty()) {
        return;
    }

    for (int requestId : requestIds) {
        pendingRequestIds.removeAll(requestId);
    }

    if (pendingRequestIds.isEmpty()) {
        pendingRequestIdsByComicId.remove(comicId);
    } else {
        pendingRequestIdsByComicId.insert(comicId, pendingRequestIds);
    }
}

void clearPendingWarmupPageRequestsForComic(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    int comicId
)
{
    if (comicId < 1 || pendingRequestIdsByKey.isEmpty()) {
        return;
    }

    const QString pendingKeyPrefix = QStringLiteral("reader-warm:%1:").arg(comicId);
    const QStringList pendingKeys = pendingRequestIdsByKey.keys();
    for (const QString &pendingKey : pendingKeys) {
        if (pendingKey.startsWith(pendingKeyPrefix)) {
            pendingRequestIdsByKey.remove(pendingKey);
        }
    }
}

void cacheSession(ReaderRuntimeState &state, const QVariantMap &session)
{
    const QString error = session.value(QStringLiteral("error")).toString().trimmed();
    if (!error.isEmpty()) {
        return;
    }

    const int comicId = session.value(QStringLiteral("comicId")).toInt();
    const QString archivePath = session.value(QStringLiteral("archivePath")).toString().trimmed();
    const QStringList entries = session.value(QStringLiteral("entries")).toStringList();
    if (comicId < 1 || archivePath.isEmpty() || entries.isEmpty()) {
        return;
    }

    state.archivePathById.insert(comicId, archivePath);
    state.imageEntriesById.insert(comicId, entries);
}

void cachePageMetrics(
    ReaderRuntimeState &state,
    int comicId,
    const QVariantList &pageMetrics
)
{
    if (comicId < 1 || pageMetrics.isEmpty()) {
        return;
    }
    state.pageMetricsById.insert(comicId, pageMetrics);
}

} // namespace ComicReaderRuntime
