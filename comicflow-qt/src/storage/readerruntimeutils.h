#pragma once

#include <QHash>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

namespace ComicReaderRuntime {

struct ReaderRuntimeState {
    QHash<int, QString> archivePathById;
    QHash<int, QStringList> imageEntriesById;
    QHash<int, QVariantList> pageMetricsById;
    QHash<int, QList<int>> pendingSessionRequestIdsByComicId;
    QHash<int, QList<int>> pendingPageRequestIdsByComicId;
    QHash<QString, QList<int>> pendingWarmupPageRequestIdsByKey;
    QHash<int, QList<int>> pendingPageMetricsRequestIdsByComicId;
    QHash<int, int> asyncRevisionByComicId;
    int asyncEpoch = 0;
};

struct ReaderPageRequestState {
    QVariantMap sessionToCache;
    QString archivePath;
    QStringList entries;
    int resolvedPageIndex = 0;
    QString error;
};

ReaderPageRequestState buildPageRequestState(
    int comicId,
    int requestedPageIndex,
    const QString &cachedArchivePath,
    const QStringList &cachedEntries,
    const QVariantMap &sessionFallback
);

QVariantMap makeAsyncImageResult(
    const QString &imageSource = QString(),
    const QString &error = QString()
);

QVariantMap makeCanceledReaderAsyncResult();

QString warmupPagePendingKey(int comicId, int pageIndex);

void removePendingRequestIds(
    QHash<int, QList<int>> &pendingRequestIdsByComicId,
    int comicId,
    const QList<int> &requestIds
);

void clearPendingWarmupPageRequestsForComic(
    QHash<QString, QList<int>> &pendingRequestIdsByKey,
    int comicId
);

void cacheSession(ReaderRuntimeState &state, const QVariantMap &session);

void cachePageMetrics(
    ReaderRuntimeState &state,
    int comicId,
    const QVariantList &pageMetrics
);

} // namespace ComicReaderRuntime
