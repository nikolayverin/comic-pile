#include "storage/comicslistmodel.h"

#include "storage/archivepacking.h"
#include "storage/comicsmodelutils.h"
#include "storage/imagepreparationops.h"
#include "storage/importmatching.h"
#include "storage/readercacheutils.h"
#include "storage/readerpayloadutils.h"
#include "storage/readerrequestutils.h"
#include "storage/readerruntimeutils.h"
#include "storage/readersessionops.h"

#include <algorithm>

#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QImageReader>
#include <QMetaObject>
#include <QUrl>
#include <QtConcurrent>

QVariantMap ComicsListModel::loadReaderSessionPayload(
    const QString &dbPath,
    const QString &dataRoot,
    int comicId
)
{
    const ComicReaderSessionOps::ReaderIssueRecord record =
        ComicReaderSessionOps::loadReaderIssueRecord(dbPath, comicId);
    if (!record.error.isEmpty()) {
        return {
            { QStringLiteral("error"), record.error }
        };
    }

    QString archivePath = ComicModelUtils::resolveStoredArchivePathForDataRoot(
        dataRoot,
        record.filePath,
        record.filename
    );
    if (archivePath.isEmpty() && !record.filename.isEmpty()) {
        const QString fallbackPath = ComicModelUtils::resolveLibraryFilePath(
            QDir(dataRoot).filePath(QStringLiteral("Library")),
            record.filename
        );
        if (!fallbackPath.isEmpty() && QFileInfo::exists(fallbackPath)) {
            archivePath = fallbackPath;
        }
    }

    if (archivePath.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("Archive path is empty for issue id %1.").arg(comicId) }
        };
    }

    QStringList entries;
    QString listError;
    if (!listImageEntriesInArchive(archivePath, entries, listError)) {
        return {
            { QStringLiteral("error"), listError }
        };
    }
    if (entries.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("No image pages found in archive.") }
        };
    }

    const QString displayTitle = !record.series.isEmpty()
        ? record.series
        : (!record.title.isEmpty() ? record.title : record.filename);
    const int pageCount = entries.size();
    const int effectiveBookmarkPage = (record.bookmarkPage > 0 && record.bookmarkPage <= pageCount)
        ? record.bookmarkPage
        : 0;
    int startPageIndex = 0;
    if (effectiveBookmarkPage > 0) {
        startPageIndex = effectiveBookmarkPage - 1;
    } else if (record.currentPage > 0) {
        startPageIndex = std::clamp(record.currentPage - 1, 0, pageCount - 1);
    }

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("seriesKey"), record.seriesKey },
        { QStringLiteral("title"), displayTitle },
        { QStringLiteral("archivePath"), archivePath },
        { QStringLiteral("pageCount"), pageCount },
        { QStringLiteral("currentPage"), record.currentPage },
        { QStringLiteral("bookmarkPage"), record.bookmarkPage },
        { QStringLiteral("favoriteActive"), record.favoriteActive },
        { QStringLiteral("startPageIndex"), startPageIndex },
        { QStringLiteral("entries"), entries }
    };
}

QVariantMap ComicsListModel::loadReaderPageMetricsPayload(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath,
    const QStringList &entries
)
{
    return ComicImagePreparation::loadReaderPageMetricsPayload(
        dataRoot,
        comicId,
        archivePath,
        entries,
        [](const QString &sourceArchivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
            return ComicsListModel::extractArchiveEntryToFile(sourceArchivePath, entryName, outputFilePath, errorText);
        }
    );
}

void ComicsListModel::cacheReaderSession(const QVariantMap &session)
{
    ComicReaderRuntime::cacheSession(m_readerState, session);
}

void ComicsListModel::cacheReaderPageMetrics(int comicId, const QVariantList &pageMetrics)
{
    ComicReaderRuntime::cachePageMetrics(m_readerState, comicId, pageMetrics);
}

void ComicsListModel::invalidateAllReaderAsyncState()
{
    const QHash<int, QList<int>> pendingSessionRequestIdsByComicId = m_readerState.pendingSessionRequestIdsByComicId;
    const QHash<int, QList<int>> pendingPageRequestIdsByComicId = m_readerState.pendingPageRequestIdsByComicId;
    const QHash<int, QList<int>> pendingPageMetricsRequestIdsByComicId = m_readerState.pendingPageMetricsRequestIdsByComicId;
    QList<int> pendingImageRequestIds;
    for (auto it = m_artworkState.pendingImageRequestIdsByKey.cbegin(); it != m_artworkState.pendingImageRequestIdsByKey.cend(); ++it) {
        pendingImageRequestIds.append(it.value());
    }

    m_readerState.asyncEpoch += 1;
    m_readerState.asyncRevisionByComicId.clear();
    m_readerState.pendingSessionRequestIdsByComicId.clear();
    m_readerState.pendingPageRequestIdsByComicId.clear();
    m_readerState.pendingWarmupPageRequestIdsByKey.clear();
    m_readerState.pendingPageMetricsRequestIdsByComicId.clear();
    m_artworkState.pendingImageRequestIdsByKey.clear();
    m_artworkState.pendingSeriesHeroRequestIdsByKey.clear();
    m_artworkState.coverGenerationQueue.clear();
    m_artworkState.seriesHeroGenerationQueue.clear();
    m_artworkState.activeCoverGenerationCount = 0;
    m_artworkState.activeSeriesHeroGenerationCount = 0;

    const QVariantMap canceledResult = ComicReaderRuntime::makeCanceledReaderAsyncResult();
    for (auto it = pendingSessionRequestIdsByComicId.cbegin(); it != pendingSessionRequestIdsByComicId.cend(); ++it) {
        emitReaderSessionReadyForRequestIds(it.value(), canceledResult);
    }

    for (auto it = pendingPageMetricsRequestIdsByComicId.cbegin(); it != pendingPageMetricsRequestIdsByComicId.cend(); ++it) {
        const QList<int> requestIds = it.value();
        if (requestIds.isEmpty()) {
            continue;
        }

        const int comicId = it.key();
        QMetaObject::invokeMethod(
            this,
            [this, requestIds, comicId, canceledResult]() {
                for (int requestId : requestIds) {
                    emit readerPageMetricsReady(requestId, comicId, canceledResult);
                }
            },
            Qt::QueuedConnection
        );
    }

    for (auto it = pendingPageRequestIdsByComicId.cbegin(); it != pendingPageRequestIdsByComicId.cend(); ++it) {
        emitPageReadyForRequestIds(
            it.value(),
            it.key(),
            0,
            QString(),
            canceledResult.value(QStringLiteral("error")).toString(),
            false
        );
    }

    emitPageReadyForRequestIds(
        pendingImageRequestIds,
        0,
        0,
        QString(),
        canceledResult.value(QStringLiteral("error")).toString(),
        false
    );
}

void ComicsListModel::clearReaderRuntimeStateForComic(int comicId)
{
    if (comicId < 1) {
        return;
    }

    const QList<int> pendingSessionRequestIds = m_readerState.pendingSessionRequestIdsByComicId.take(comicId);
    const QList<int> pendingPageRequestIds = m_readerState.pendingPageRequestIdsByComicId.take(comicId);
    const QList<int> pendingPageMetricsRequestIds = m_readerState.pendingPageMetricsRequestIdsByComicId.take(comicId);
    const QList<int> pendingImageRequestIds = ComicReaderRequests::takePendingImageRequestIdsForComic(
        m_artworkState.pendingImageRequestIdsByKey,
        comicId
    );
    ComicReaderRuntime::clearPendingWarmupPageRequestsForComic(
        m_readerState.pendingWarmupPageRequestIdsByKey,
        comicId
    );
    m_readerState.asyncRevisionByComicId.insert(comicId, m_readerState.asyncRevisionByComicId.value(comicId) + 1);
    m_readerState.archivePathById.remove(comicId);
    m_readerState.imageEntriesById.remove(comicId);
    m_readerState.pageMetricsById.remove(comicId);

    const QVariantMap canceledResult = ComicReaderRuntime::makeCanceledReaderAsyncResult();
    emitReaderSessionReadyForRequestIds(pendingSessionRequestIds, canceledResult);
    emitPageReadyForRequestIds(
        pendingPageRequestIds,
        comicId,
        0,
        QString(),
        canceledResult.value(QStringLiteral("error")).toString(),
        false
    );
    if (!pendingPageMetricsRequestIds.isEmpty()) {
        QMetaObject::invokeMethod(
            this,
            [this, pendingPageMetricsRequestIds, comicId, canceledResult]() {
                for (int requestId : pendingPageMetricsRequestIds) {
                    emit readerPageMetricsReady(requestId, comicId, canceledResult);
                }
            },
            Qt::QueuedConnection
        );
    }

    emitPageReadyForRequestIds(
        pendingImageRequestIds,
        comicId,
        0,
        QString(),
        canceledResult.value(QStringLiteral("error")).toString(),
        false
    );
}

void ComicsListModel::clearReaderRuntimeStateForComics(const QVector<int> &comicIds)
{
    for (int comicId : comicIds) {
        clearReaderRuntimeStateForComic(comicId);
    }
}

void ComicsListModel::setReaderArchivePathForComic(int comicId, const QString &archivePath)
{
    clearReaderRuntimeStateForComic(comicId);
    const QString normalizedArchivePath = archivePath.trimmed();
    if (!normalizedArchivePath.isEmpty()) {
        m_readerState.archivePathById.insert(comicId, normalizedArchivePath);
    }
}

QVariantMap ComicsListModel::cachedReaderSessionPayload(int comicId) const
{
    if (comicId < 1) {
        return {};
    }

    const QString archivePath = m_readerState.archivePathById.value(comicId).trimmed();
    const QStringList entries = m_readerState.imageEntriesById.value(comicId);
    if (archivePath.isEmpty() || entries.isEmpty()) {
        return {};
    }

    QString displayTitle = QStringLiteral("Issue #%1").arg(comicId);
    QString seriesKey;
    int currentPage = 0;
    int bookmarkPage = 0;
    bool favoriteActive = false;
    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) continue;
        seriesKey = row.seriesGroupKey.trimmed();
        displayTitle = !row.series.isEmpty() ? row.series : (!row.title.isEmpty() ? row.title : row.filename);
        currentPage = row.currentPage;
        bookmarkPage = row.bookmarkPage;
        favoriteActive = row.favoriteActive;
        break;
    }

    return ComicReaderPayloads::buildCachedReaderSessionPayload(
        comicId,
        archivePath,
        entries,
        seriesKey,
        displayTitle,
        currentPage,
        bookmarkPage,
        favoriteActive
    );
}

QVariantList ComicsListModel::cachedReaderPageMetrics(int comicId) const
{
    if (comicId < 1) {
        return {};
    }
    return m_readerState.pageMetricsById.value(comicId);
}

void ComicsListModel::emitReaderSessionReadyForRequestIds(
    const QList<int> &requestIds,
    const QVariantMap &result
)
{
    if (requestIds.isEmpty()) return;

    QMetaObject::invokeMethod(
        this,
        [this, requestIds, result]() {
            for (int requestId : requestIds) {
                emit readerSessionReady(requestId, result);
            }
        },
        Qt::QueuedConnection
    );
}

QVariantMap ComicsListModel::openReaderSession(int comicId)
{
    const QVariantMap session = loadReaderSessionPayload(m_dbPath, m_dataRoot, comicId);
    cacheReaderSession(session);
    return session;
}

QVariantMap ComicsListModel::buildIssueNavigationTarget(const ComicRow &row) const
{
    const QString normalizedSeriesKey = row.seriesGroupKey.trimmed();
    if (row.id < 1 || normalizedSeriesKey.isEmpty()) {
        return {
            { QStringLiteral("ok"), false },
            { QStringLiteral("message"), QStringLiteral("Issue target is unavailable.") }
        };
    }

    const QString displayTitle = row.title.trimmed().isEmpty()
        ? row.filename.trimmed()
        : row.title.trimmed();
    const QString normalizedReadStatus = ComicModelUtils::normalizeReadStatus(row.readStatus);
    const bool hasBookmark = row.bookmarkPage > 0;
    const bool hasProgress = row.currentPage > 0 && normalizedReadStatus != QStringLiteral("read");
    const int startPageIndex = hasBookmark
        ? std::max(0, row.bookmarkPage - 1)
        : (hasProgress ? std::max(0, row.currentPage - 1) : 0);

    return {
        { QStringLiteral("ok"), true },
        { QStringLiteral("comicId"), row.id },
        { QStringLiteral("anchorComicId"), row.id },
        { QStringLiteral("seriesKey"), normalizedSeriesKey },
        { QStringLiteral("seriesTitle"), row.seriesGroupTitle.trimmed().isEmpty() ? row.series.trimmed() : row.seriesGroupTitle.trimmed() },
        { QStringLiteral("title"), row.title.trimmed() },
        { QStringLiteral("displayTitle"), displayTitle.isEmpty() ? QStringLiteral("Issue #%1").arg(row.id) : displayTitle },
        { QStringLiteral("filename"), row.filename.trimmed() },
        { QStringLiteral("issueNumber"), ComicImportMatching::displayIssueNumber(row.issueNumber) },
        { QStringLiteral("readStatus"), normalizedReadStatus.isEmpty() ? QStringLiteral("unread") : normalizedReadStatus },
        { QStringLiteral("currentPage"), row.currentPage },
        { QStringLiteral("bookmarkPage"), row.bookmarkPage },
        { QStringLiteral("hasBookmark"), hasBookmark },
        { QStringLiteral("hasProgress"), hasProgress },
        { QStringLiteral("startPageIndex"), startPageIndex }
    };
}

QVariantMap ComicsListModel::continueReadingTarget() const
{
    const ComicRow *bestBookmarkedRow = nullptr;
    const ComicRow *bestProgressRow = nullptr;
    QString bestBookmarkTimestamp;

    auto progressRank = [](const ComicRow &row) {
        const QString normalizedStatus = ComicModelUtils::normalizeReadStatus(row.readStatus);
        if (normalizedStatus == QStringLiteral("in_progress")) {
            return 2;
        }
        if (row.currentPage > 0) {
            return 1;
        }
        return 0;
    };

    for (const ComicRow &row : m_rows) {
        const QString normalizedStatus = ComicModelUtils::normalizeReadStatus(row.readStatus);
        const bool hasBookmark = row.bookmarkPage > 0;
        const bool hasProgress = row.currentPage > 0 && normalizedStatus != QStringLiteral("read");
        if (!hasBookmark && !hasProgress) {
            continue;
        }

        if (hasBookmark) {
            const QString bookmarkTimestamp = row.bookmarkAddedAt.trimmed();
            if (!bestBookmarkedRow) {
                bestBookmarkedRow = &row;
                bestBookmarkTimestamp = bookmarkTimestamp;
                continue;
            }

            if (bookmarkTimestamp != bestBookmarkTimestamp) {
                if (bookmarkTimestamp > bestBookmarkTimestamp) {
                    bestBookmarkedRow = &row;
                    bestBookmarkTimestamp = bookmarkTimestamp;
                }
                continue;
            }

            if (compareRows(row, *bestBookmarkedRow) < 0) {
                bestBookmarkedRow = &row;
                bestBookmarkTimestamp = bookmarkTimestamp;
            }
            continue;
        }

        if (!bestProgressRow) {
            bestProgressRow = &row;
            continue;
        }

        const int candidateRank = progressRank(row);
        const int bestRank = progressRank(*bestProgressRow);
        if (candidateRank != bestRank) {
            if (candidateRank > bestRank) {
                bestProgressRow = &row;
            }
            continue;
        }

        if (row.currentPage != bestProgressRow->currentPage) {
            if (row.currentPage > bestProgressRow->currentPage) {
                bestProgressRow = &row;
            }
            continue;
        }

        if (compareRows(row, *bestProgressRow) < 0) {
            bestProgressRow = &row;
        }
    }

    if (bestBookmarkedRow) {
        return buildIssueNavigationTarget(*bestBookmarkedRow);
    }
    if (bestProgressRow) {
        return buildIssueNavigationTarget(*bestProgressRow);
    }

    return {
        { QStringLiteral("ok"), false },
        { QStringLiteral("message"), QStringLiteral("No active reading session is available yet.") }
    };
}

QVariantMap ComicsListModel::navigationTargetForComic(int comicId) const
{
    if (comicId < 1) {
        return {
            { QStringLiteral("ok"), false },
            { QStringLiteral("message"), QStringLiteral("Issue target is unavailable.") }
        };
    }

    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) {
            continue;
        }
        return buildIssueNavigationTarget(row);
    }

    return {
        { QStringLiteral("ok"), false },
        { QStringLiteral("message"), QStringLiteral("Issue target is unavailable.") }
    };
}

QVariantMap ComicsListModel::nextUnreadTarget(const QString &preferredSeriesKey, int afterComicId) const
{
    const QString normalizedSeriesKey = preferredSeriesKey.trimmed();
    if (normalizedSeriesKey.isEmpty()) {
        return {
            { QStringLiteral("ok"), false },
            { QStringLiteral("message"), QStringLiteral("Select a series first.") }
        };
    }

    bool seriesFound = false;
    bool afterComicSeen = afterComicId < 1;
    const ComicRow *firstUnreadRow = nullptr;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != normalizedSeriesKey) {
            continue;
        }

        seriesFound = true;
        const QString normalizedStatus = ComicModelUtils::normalizeReadStatus(row.readStatus);
        const bool unread = normalizedStatus != QStringLiteral("read");

        if (afterComicSeen) {
            if (row.id != afterComicId && unread) {
                return buildIssueNavigationTarget(row);
            }
        } else if (row.id == afterComicId) {
            afterComicSeen = true;
            continue;
        }

        if (!firstUnreadRow && unread) {
            firstUnreadRow = &row;
        }
    }

    if (!seriesFound) {
        return {
            { QStringLiteral("ok"), false },
            { QStringLiteral("message"), QStringLiteral("The selected series is unavailable.") }
        };
    }

    if (afterComicId < 1 && firstUnreadRow) {
        return buildIssueNavigationTarget(*firstUnreadRow);
    }

    return {
        { QStringLiteral("ok"), false },
        { QStringLiteral("message"), QStringLiteral("No next unread issue is queued for this series.") }
    };
}

int ComicsListModel::requestReaderPageMetricsAsync(int comicId)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId, comicId](const QVariantMap &result) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId, comicId, result]() {
                emit readerPageMetricsReady(requestId, comicId, result);
            },
            Qt::QueuedConnection
        );
    };

    if (comicId < 1) {
        emitLaterSingle({
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        });
        return requestId;
    }

    const QVariantList cachedMetrics = cachedReaderPageMetrics(comicId);
    if (!cachedMetrics.isEmpty()) {
        emitLaterSingle({
            { QStringLiteral("comicId"), comicId },
            { QStringLiteral("pageMetrics"), cachedMetrics }
        });
        return requestId;
    }

    m_readerState.pendingPageMetricsRequestIdsByComicId[comicId].push_back(requestId);
    if (m_readerState.pendingPageMetricsRequestIdsByComicId.value(comicId).size() > 1) {
        return requestId;
    }

    const int asyncEpoch = m_readerState.asyncEpoch;
    const int comicAsyncRevision = m_readerState.asyncRevisionByComicId.value(comicId);
    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, comicId, asyncEpoch, comicAsyncRevision]() {
        if (asyncEpoch != m_readerState.asyncEpoch
            || comicAsyncRevision != m_readerState.asyncRevisionByComicId.value(comicId)) {
            watcher->deleteLater();
            return;
        }

        const QVariantMap result = watcher->result();
        const QVariantList pageMetrics = result.value(QStringLiteral("pageMetrics")).toList();
        if (!pageMetrics.isEmpty()) {
            cacheReaderPageMetrics(comicId, pageMetrics);
        }
        const QVariantMap rebuiltSession = result.value(QStringLiteral("session")).toMap();
        if (!rebuiltSession.isEmpty()) {
            cacheReaderSession(rebuiltSession);
        }

        const QList<int> requestIds = m_readerState.pendingPageMetricsRequestIdsByComicId.take(comicId);
        for (int requestId : requestIds) {
            emit readerPageMetricsReady(requestId, comicId, result);
        }
        watcher->deleteLater();
    });

    watcher->setFuture(QtConcurrent::run([dbPath = m_dbPath, dataRoot = m_dataRoot, comicId]() {
        QString archivePath;
        QStringList entries;
        QVariantMap rebuiltSession;

        const QVariantMap session = ComicsListModel::loadReaderSessionPayload(dbPath, dataRoot, comicId);
        const QString sessionError = session.value(QStringLiteral("error")).toString().trimmed();
        if (!sessionError.isEmpty()) {
            return QVariantMap {
                { QStringLiteral("error"), sessionError }
            };
        }

        rebuiltSession = session;
        archivePath = session.value(QStringLiteral("archivePath")).toString().trimmed();
        entries = session.value(QStringLiteral("entries")).toStringList();

        QVariantMap result = ComicsListModel::loadReaderPageMetricsPayload(
            dataRoot,
            comicId,
            archivePath,
            entries
        );
        if (!rebuiltSession.isEmpty()) {
            result.insert(QStringLiteral("session"), rebuiltSession);
        }
        return result;
    }));

    return requestId;
}

int ComicsListModel::requestReaderSessionAsync(int comicId)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId](const QVariantMap &result) {
        emitReaderSessionReadyForRequestIds({ requestId }, result);
    };

    if (comicId < 1) {
        emitLaterSingle({
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        });
        return requestId;
    }

    const QVariantMap cached = cachedReaderSessionPayload(comicId);
    if (!cached.isEmpty()) {
        emitLaterSingle(cached);
        return requestId;
    }

    m_readerState.pendingSessionRequestIdsByComicId[comicId].push_back(requestId);
    if (m_readerState.pendingSessionRequestIdsByComicId.value(comicId).size() > 1) {
        return requestId;
    }

    const int asyncEpoch = m_readerState.asyncEpoch;
    const int comicAsyncRevision = m_readerState.asyncRevisionByComicId.value(comicId);
    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, comicId, asyncEpoch, comicAsyncRevision]() {
        if (asyncEpoch != m_readerState.asyncEpoch
            || comicAsyncRevision != m_readerState.asyncRevisionByComicId.value(comicId)) {
            watcher->deleteLater();
            return;
        }

        const QVariantMap session = watcher->result();
        cacheReaderSession(session);
        const QList<int> requestIds = m_readerState.pendingSessionRequestIdsByComicId.take(comicId);
        emitReaderSessionReadyForRequestIds(requestIds, session);
        watcher->deleteLater();
    });

    watcher->setFuture(QtConcurrent::run([dbPath = m_dbPath, dataRoot = m_dataRoot, comicId]() {
        return ComicsListModel::loadReaderSessionPayload(dbPath, dataRoot, comicId);
    }));
    return requestId;
}

QVariantMap ComicsListModel::loadReaderPage(int comicId, int pageIndex)
{
    const QString cachedArchivePath = m_readerState.archivePathById.value(comicId);
    const QStringList cachedEntries = m_readerState.imageEntriesById.value(comicId);
    QVariantMap rebuiltSession;
    if (cachedArchivePath.trimmed().isEmpty() || cachedEntries.isEmpty()) {
        rebuiltSession = loadReaderSessionPayload(m_dbPath, m_dataRoot, comicId);
    }

    const ComicReaderRuntime::ReaderPageRequestState state = ComicReaderRuntime::buildPageRequestState(
        comicId,
        pageIndex,
        cachedArchivePath,
        cachedEntries,
        rebuiltSession
    );
    if (!state.sessionToCache.isEmpty()) {
        cacheReaderSession(state.sessionToCache);
    }
    if (!state.error.isEmpty()) {
        return {
            { QStringLiteral("error"), state.error }
        };
    }

    return ComicReaderPayloads::loadReaderPagePayload(
        m_dataRoot,
        comicId,
        state.archivePath,
        state.entries,
        state.resolvedPageIndex,
        [](const QString &archivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
            return ComicsListModel::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
        }
    );
}

int ComicsListModel::requestReaderPageAsync(int comicId, int pageIndex)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId, comicId](int resolvedPageIndex, const QString &imageSource, const QString &errorText) {
        emitPageReadyForRequestIds({ requestId }, comicId, resolvedPageIndex, imageSource, errorText, false);
    };

    if (comicId < 1) {
        emitLaterSingle(pageIndex, QString(), QStringLiteral("Invalid issue id."));
        return requestId;
    }

    const QString cachedArchivePath = m_readerState.archivePathById.value(comicId);
    const QStringList cachedEntries = m_readerState.imageEntriesById.value(comicId);
    const bool needsSessionRebuild = cachedArchivePath.trimmed().isEmpty() || cachedEntries.isEmpty();
    if (needsSessionRebuild) {
        const QString pendingKey = ComicReaderRuntime::warmupPagePendingKey(comicId, pageIndex);
        const int asyncEpoch = m_readerState.asyncEpoch;
        const int comicAsyncRevision = m_readerState.asyncRevisionByComicId.value(comicId);
        m_readerState.pendingPageRequestIdsByComicId[comicId].push_back(requestId);
        if (!ComicReaderRequests::beginPendingImageRequest(
                m_readerState.pendingWarmupPageRequestIdsByKey,
                pendingKey,
                requestId
            )) {
            return requestId;
        }

        auto *watcher = new QFutureWatcher<QVariantMap>(this);
        connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, pendingKey, comicId, pageIndex, asyncEpoch, comicAsyncRevision]() {
            const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
                m_readerState.pendingWarmupPageRequestIdsByKey,
                pendingKey
            );
            ComicReaderRuntime::removePendingRequestIds(
                m_readerState.pendingPageRequestIdsByComicId,
                comicId,
                requestIds
            );
            if (requestIds.isEmpty()) {
                watcher->deleteLater();
                return;
            }

            if (asyncEpoch != m_readerState.asyncEpoch
                || comicAsyncRevision != m_readerState.asyncRevisionByComicId.value(comicId)) {
                watcher->deleteLater();
                return;
            }

            const QVariantMap result = watcher->result();
            const QVariantMap rebuiltSession = result.value(QStringLiteral("session")).toMap();
            if (!rebuiltSession.isEmpty()) {
                cacheReaderSession(rebuiltSession);
            }

            const int resolvedPageIndex = result.contains(QStringLiteral("pageIndex"))
                ? result.value(QStringLiteral("pageIndex")).toInt()
                : pageIndex;
            emitPageReadyForRequestIds(
                requestIds,
                comicId,
                resolvedPageIndex,
                result.value(QStringLiteral("imageSource")).toString(),
                result.value(QStringLiteral("error")).toString(),
                false
            );
            watcher->deleteLater();
        });

        const auto task = [dbPath = m_dbPath, dataRoot = m_dataRoot, comicId, pageIndex]() {
            const QVariantMap rebuiltSession = ComicsListModel::loadReaderSessionPayload(dbPath, dataRoot, comicId);
            const ComicReaderRuntime::ReaderPageRequestState state = ComicReaderRuntime::buildPageRequestState(
                comicId,
                pageIndex,
                QString(),
                QStringList(),
                rebuiltSession
            );
            if (!state.error.isEmpty()) {
                return QVariantMap {
                    { QStringLiteral("error"), state.error },
                    { QStringLiteral("pageIndex"), state.resolvedPageIndex }
                };
            }

            QVariantMap result = ComicReaderPayloads::loadReaderPagePayload(
                dataRoot,
                comicId,
                state.archivePath,
                state.entries,
                state.resolvedPageIndex,
                [](const QString &archivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
                    return ComicsListModel::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
                }
            );
            if (!state.sessionToCache.isEmpty()) {
                result.insert(QStringLiteral("session"), state.sessionToCache);
            }
            return result;
        };

        watcher->setFuture(QtConcurrent::run(task));
        return requestId;
    }

    const ComicReaderRuntime::ReaderPageRequestState state = ComicReaderRuntime::buildPageRequestState(
        comicId,
        pageIndex,
        cachedArchivePath,
        cachedEntries,
        QVariantMap()
    );
    if (!state.error.isEmpty()) {
        emitLaterSingle(state.resolvedPageIndex, QString(), state.error);
        return requestId;
    }

    const QString entryName = state.entries.at(state.resolvedPageIndex);
    QString extension = QFileInfo(entryName).suffix().toLower();
    if (extension.isEmpty()) extension = QStringLiteral("img");
    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(m_dataRoot, state.archivePath);
    const QString cacheFilePath = ComicReaderCache::buildReaderCachePath(
        m_dataRoot,
        comicId,
        cacheStamp,
        state.resolvedPageIndex,
        extension
    );

    const QFileInfo cacheInfo(cacheFilePath);
    if (cacheInfo.exists() && cacheInfo.size() > 0) {
        emitLaterSingle(state.resolvedPageIndex, QUrl::fromLocalFile(cacheFilePath).toString(), QString());
        return requestId;
    }
    if (cacheInfo.exists() && cacheInfo.size() <= 0) {
        QFile::remove(cacheFilePath);
    }

    const QString pendingKey = ComicReaderRequests::pagePendingKey(comicId, cacheStamp, state.resolvedPageIndex);
    if (!ComicReaderRequests::beginPendingImageRequest(m_artworkState.pendingImageRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, pendingKey, comicId, pageIndex]() {
        const QVariantMap result = watcher->result();
        const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
            m_artworkState.pendingImageRequestIdsByKey,
            pendingKey
        );
        const int resolvedPageIndex = result.contains(QStringLiteral("pageIndex"))
            ? result.value(QStringLiteral("pageIndex")).toInt()
            : pageIndex;
        emitPageReadyForRequestIds(
            requestIds,
            comicId,
            resolvedPageIndex,
            result.value(QStringLiteral("imageSource")).toString(),
            result.value(QStringLiteral("error")).toString(),
            false
        );
        watcher->deleteLater();
    });

    const auto task = [dataRoot = m_dataRoot, comicId, archivePath = state.archivePath, entries = state.entries, resolvedPageIndex = state.resolvedPageIndex]() {
        return ComicReaderPayloads::loadReaderPagePayload(
            dataRoot,
            comicId,
            archivePath,
            entries,
            resolvedPageIndex,
            [](const QString &archivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
                return ComicsListModel::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
            }
        );
    };

    watcher->setFuture(QtConcurrent::run(task));
    return requestId;
}

void ComicsListModel::startQueuedCoverGeneration(const QueuedCoverGeneration &job)
{
    m_artworkState.activeCoverGenerationCount += 1;

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(
        watcher,
        &QFutureWatcher<QVariantMap>::finished,
        this,
        [this, watcher, pendingKey = job.pendingKey, comicId = job.comicId, coverPath = job.coverPath]() {
            const QVariantMap result = watcher->result();
            const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
                m_artworkState.pendingImageRequestIdsByKey,
                pendingKey
            );
            m_artworkState.activeCoverGenerationCount = std::max(0, m_artworkState.activeCoverGenerationCount - 1);

            const QString currentArchivePath = archivePathForComicId(comicId);
            const QString currentPendingKey = currentArchivePath.trimmed().isEmpty()
                ? QString()
                : ComicReaderRequests::thumbnailPendingKey(
                    comicId,
                    ComicReaderCache::buildArchiveCacheStamp(m_dataRoot, currentArchivePath)
                );
            const bool staleResult = currentPendingKey != pendingKey;

            if (staleResult) {
                QFile::remove(coverPath);
            } else if (requestIds.isEmpty()) {
                ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
            } else {
                const QString imageSource = result.value(QStringLiteral("imageSource")).toString();
                const QString errorText = result.value(QStringLiteral("error")).toString();
                if (errorText.trimmed().isEmpty() && !imageSource.trimmed().isEmpty()) {
                    ComicReaderCache::pruneThumbnailVariantsForComic(m_dataRoot, comicId, coverPath);
                }
                emitPageReadyForRequestIds(
                    requestIds,
                    comicId,
                    0,
                    imageSource,
                    errorText,
                    true
                );
            }

            watcher->deleteLater();
            pumpQueuedCoverGeneration();
        }
    );

    const auto task = [job, dataRoot = m_dataRoot]() {
        QStringList entries;
        QString listError;
        if (!ComicsListModel::listImageEntriesInArchive(job.archivePath, entries, listError)) {
            return ComicReaderRuntime::makeAsyncImageResult({}, listError);
        }
        if (entries.isEmpty()) {
            return ComicReaderRuntime::makeAsyncImageResult({}, QStringLiteral("No image pages found in archive."));
        }

        const QString entryName = entries.at(0);
        QString extension = QFileInfo(entryName).suffix().toLower();
        if (extension.isEmpty()) extension = QStringLiteral("img");
        const QString pageCachePath = ComicReaderCache::buildReaderCachePath(dataRoot, job.comicId, job.cacheStamp, 0, extension);

        if (!ComicReaderCache::ensureDirForFile(pageCachePath) || !ComicReaderCache::ensureDirForFile(job.coverPath)) {
            return ComicReaderRuntime::makeAsyncImageResult({}, QStringLiteral("Failed to create thumbnail cache directory."));
        }

        const QFileInfo localPageInfo(pageCachePath);
        if (localPageInfo.exists() && localPageInfo.size() <= 0) {
            QFile::remove(pageCachePath);
        }

        if (!QFileInfo::exists(pageCachePath)) {
            QString extractError;
            if (!ComicsListModel::extractArchiveEntryToFile(job.archivePath, entryName, pageCachePath, extractError)) {
                return ComicReaderRuntime::makeAsyncImageResult({}, extractError);
            }
        }

        const QFileInfo localThumbInfo(job.coverPath);
        if (localThumbInfo.exists() && localThumbInfo.size() <= 0) {
            QFile::remove(job.coverPath);
        }

        if (!QFileInfo::exists(job.coverPath)) {
            QString thumbError;
            if (!ComicImagePreparation::generateThumbnailImage(pageCachePath, job.coverPath, job.coverFormat, thumbError)) {
                return ComicReaderRuntime::makeAsyncImageResult({}, thumbError);
            }
        }

        return ComicReaderRuntime::makeAsyncImageResult(QUrl::fromLocalFile(job.coverPath).toString(), {});
    };

    watcher->setFuture(QtConcurrent::run(task));
}

void ComicsListModel::pumpQueuedCoverGeneration()
{
    constexpr int kMaxQueuedCoverGenerationCount = 3;

    while (m_artworkState.activeCoverGenerationCount < kMaxQueuedCoverGenerationCount && !m_artworkState.coverGenerationQueue.isEmpty()) {
        const QueuedCoverGeneration job = m_artworkState.coverGenerationQueue.takeFirst();
        if (!ComicReaderRequests::hasPendingImageRequest(m_artworkState.pendingImageRequestIdsByKey, job.pendingKey)) {
            continue;
        }
        startQueuedCoverGeneration(job);
    }
}

int ComicsListModel::requestIssueThumbnailAsync(int comicId)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId, comicId](const QString &imageSource, const QString &errorText) {
        emitPageReadyForRequestIds({ requestId }, comicId, 0, imageSource, errorText, true);
    };

    if (comicId < 1) {
        emitLaterSingle({}, QStringLiteral("Invalid issue id."));
        return requestId;
    }

    const QString archivePath = archivePathForComicId(comicId);
    if (archivePath.isEmpty()) {
        emitLaterSingle({}, QStringLiteral("Archive path is not available for cover generation."));
        return requestId;
    }

    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(m_dataRoot, archivePath);
    const QByteArray thumbFormat = ComicReaderCache::preferredThumbnailFormat();
    const QString thumbPath = ComicReaderCache::buildThumbnailPathWithFormat(m_dataRoot, comicId, cacheStamp, thumbFormat);

    const QFileInfo thumbInfo(thumbPath);
    if (thumbInfo.exists() && thumbInfo.size() > 0) {
        ComicReaderCache::pruneThumbnailVariantsForComic(m_dataRoot, comicId, thumbPath);
        emitLaterSingle(QUrl::fromLocalFile(thumbPath).toString(), {});
        return requestId;
    }
    if (thumbInfo.exists() && thumbInfo.size() <= 0) {
        QFile::remove(thumbPath);
    }

    const QString pendingKey = ComicReaderRequests::thumbnailPendingKey(comicId, cacheStamp);
    if (!ComicReaderRequests::beginPendingImageRequest(m_artworkState.pendingImageRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    const QueuedCoverGeneration job {
        pendingKey,
        comicId,
        archivePath,
        cacheStamp,
        thumbPath,
        thumbFormat
    };

    constexpr int kMaxQueuedCoverGenerationCount = 3;
    if (m_artworkState.activeCoverGenerationCount < kMaxQueuedCoverGenerationCount) {
        startQueuedCoverGeneration(job);
    } else {
        m_artworkState.coverGenerationQueue.push_back(job);
    }
    return requestId;
}

QString ComicsListModel::cachedIssueThumbnailSource(int comicId) const
{
    if (comicId < 1) return {};

    const QString archivePath = archivePathForComicId(comicId);
    if (archivePath.isEmpty()) return {};

    return ComicReaderPayloads::cachedIssueThumbnailSource(m_dataRoot, comicId, archivePath);
}

void ComicsListModel::emitPageReadyForRequestIds(
    const QList<int> &requestIds,
    int comicId,
    int pageIndex,
    const QString &imageSource,
    const QString &error,
    bool thumbnail
)
{
    if (requestIds.isEmpty()) return;

    QMetaObject::invokeMethod(
        this,
        [this, requestIds, comicId, pageIndex, imageSource, error, thumbnail]() {
            for (int requestId : requestIds) {
                emit pageImageReady(requestId, comicId, pageIndex, imageSource, error, thumbnail);
            }
        },
        Qt::QueuedConnection
    );
}

QString ComicsListModel::saveReaderProgress(int comicId, int currentPage)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");
    if (currentPage < 0 || currentPage > 1000000) {
        return QStringLiteral("Current page must be between 0 and 1000000.");
    }

    const int pageCount = m_readerState.imageEntriesById.value(comicId).size();
    QString readStatus = QStringLiteral("unread");
    if (currentPage > 0) {
        if (pageCount > 0 && currentPage >= pageCount) {
            readStatus = QStringLiteral("read");
        } else {
            readStatus = QStringLiteral("in_progress");
        }
    }

    const QString saveError = ComicReaderSessionOps::saveReaderProgress(
        m_dbPath,
        comicId,
        currentPage,
        readStatus
    );
    if (!saveError.isEmpty()) {
        return saveError;
    }

    updateReaderProgressCache(comicId, currentPage, readStatus);
    return {};
}

QString ComicsListModel::saveReaderBookmark(int comicId, int bookmarkPage)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");
    if (bookmarkPage < 0 || bookmarkPage > 1000000) {
        return QStringLiteral("Bookmark page must be between 0 and 1000000.");
    }

    const QString saveError = ComicReaderSessionOps::saveReaderBookmark(
        m_dbPath,
        comicId,
        bookmarkPage
    );
    if (!saveError.isEmpty()) {
        return saveError;
    }

    updateReaderBookmarkCache(comicId, bookmarkPage);
    return {};
}

QString ComicsListModel::saveReaderFavorite(int comicId, bool favoriteActive)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString saveError = ComicReaderSessionOps::saveReaderFavorite(
        m_dbPath,
        comicId,
        favoriteActive
    );
    if (!saveError.isEmpty()) {
        return saveError;
    }

    updateReaderFavoriteCache(comicId, favoriteActive);
    return {};
}

QVariantMap ComicsListModel::deleteReaderPageFromArchive(int comicId, int pageIndex)
{
    if (comicId < 1) {
        return {
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        };
    }

    const QVariantMap session = loadReaderSessionPayload(m_dbPath, m_dataRoot, comicId);
    const QString sessionError = session.value(QStringLiteral("error")).toString().trimmed();
    if (!sessionError.isEmpty()) {
        return {
            { QStringLiteral("error"), sessionError }
        };
    }

    const QString archivePath = session.value(QStringLiteral("archivePath")).toString().trimmed();
    const QStringList entries = session.value(QStringLiteral("entries")).toStringList();
    if (archivePath.isEmpty() || entries.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("No image pages found in archive.") }
        };
    }
    if (pageIndex < 0 || pageIndex >= entries.size()) {
        return {
            { QStringLiteral("error"), QStringLiteral("Page index is out of range.") }
        };
    }

    int remainingPageCount = 0;
    QString deleteError;
    if (!ComicArchivePacking::deletePageFromArchive(
            archivePath,
            pageIndex,
            remainingPageCount,
            deleteError
        )) {
        return {
            { QStringLiteral("error"), deleteError }
        };
    }

    const int deletedPageNumber = pageIndex + 1;
    int currentPage = session.value(QStringLiteral("currentPage")).toInt();
    int bookmarkPage = session.value(QStringLiteral("bookmarkPage")).toInt();
    QString readStatus = QStringLiteral("unread");
    QString seriesKey;
    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) continue;
        readStatus = row.readStatus.trimmed().isEmpty() ? QStringLiteral("unread") : row.readStatus.trimmed();
        seriesKey = row.seriesGroupKey.trimmed();
        break;
    }

    auto adjustStoredPage = [deletedPageNumber, remainingPageCount](int storedPage) -> int {
        if (storedPage <= 0) return 0;
        if (storedPage > deletedPageNumber) return std::max(1, storedPage - 1);
        return std::min(storedPage, remainingPageCount);
    };

    const int adjustedCurrentPage = adjustStoredPage(currentPage);
    const int adjustedBookmarkPage = adjustStoredPage(bookmarkPage);

    const QString progressError = ComicReaderSessionOps::saveReaderProgress(
        m_dbPath,
        comicId,
        adjustedCurrentPage,
        readStatus
    );
    if (!progressError.isEmpty()) {
        return {
            { QStringLiteral("error"), progressError }
        };
    }

    const QString bookmarkError = ComicReaderSessionOps::saveReaderBookmark(
        m_dbPath,
        comicId,
        adjustedBookmarkPage
    );
    if (!bookmarkError.isEmpty()) {
        return {
            { QStringLiteral("error"), bookmarkError }
        };
    }

    updateReaderProgressCache(comicId, adjustedCurrentPage, readStatus);
    updateReaderBookmarkCache(comicId, adjustedBookmarkPage);

    clearReaderRuntimeStateForComic(comicId);
    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    if (!seriesKey.isEmpty()) {
        ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, seriesKey);
    }

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("deletedPageIndex"), pageIndex },
        { QStringLiteral("pageCount"), remainingPageCount },
        { QStringLiteral("currentPage"), adjustedCurrentPage },
        { QStringLiteral("bookmarkPage"), adjustedBookmarkPage }
    };
}

QString ComicsListModel::copyImageFileToClipboard(const QString &imageSource)
{
    const QString sourceText = imageSource.trimmed();
    if (sourceText.isEmpty()) {
        return QStringLiteral("Page image is not ready.");
    }

    QString localPath;
    const QUrl sourceUrl(sourceText);
    if (sourceUrl.isValid() && sourceUrl.isLocalFile()) {
        localPath = sourceUrl.toLocalFile();
    } else {
        localPath = sourceText;
    }

    if (localPath.isEmpty()) {
        return QStringLiteral("Page image path is invalid.");
    }

    QFileInfo fileInfo(localPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        return QStringLiteral("Page image file was not found.");
    }

    QImageReader reader(localPath);
    const QImage image = reader.read();
    if (image.isNull()) {
        const QString readerError = reader.errorString().trimmed();
        if (!readerError.isEmpty()) {
            return readerError;
        }
        return QStringLiteral("Failed to load page image.");
    }

    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        return QStringLiteral("Clipboard is unavailable.");
    }

    clipboard->setImage(image);
    return {};
}

void ComicsListModel::updateReaderProgressCache(int comicId, int currentPage, const QString &readStatus)
{
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (row.id != comicId) continue;

        row.currentPage = currentPage;
        row.readStatus = readStatus;
        const QModelIndex index = this->index(rowIndex, 0);
        emit dataChanged(
            index,
            index,
            { ReadStatusRole, CurrentPageRole, DisplaySubtitleRole }
        );
        break;
    }
}

void ComicsListModel::updateReaderBookmarkCache(int comicId, int bookmarkPage)
{
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (row.id != comicId) continue;

        row.bookmarkPage = bookmarkPage;
        row.bookmarkAddedAt = bookmarkPage > 0
            ? QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"))
            : QString();
        const QModelIndex index = this->index(rowIndex, 0);
        emit dataChanged(
            index,
            index,
            { BookmarkPageRole, HasBookmarkRole }
        );
        break;
    }
}

void ComicsListModel::updateReaderFavoriteCache(int comicId, bool favoriteActive)
{
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (row.id != comicId) continue;

        row.favoriteActive = favoriteActive;
        row.favoriteAddedAt = favoriteActive
            ? QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"))
            : QString();
        const QModelIndex index = this->index(rowIndex, 0);
        emit dataChanged(
            index,
            index,
            { HasFavoriteRole }
        );
        break;
    }
}
