#include "storage/comicslistmodel.h"

#include "storage/imagepreparationops.h"
#include "storage/importmatching.h"
#include "storage/readercacheutils.h"
#include "storage/readerrequestutils.h"

#include <algorithm>
#include <limits>

#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QMetaObject>
#include <QRandomGenerator>
#include <QSet>
#include <QUrl>
#include <QtConcurrent>

namespace {

constexpr int kRandomSeriesHeroCandidateLimit = 10;

QString seriesHeroPendingKeyPrefix(const QString &seriesKey)
{
    const QByteArray digest = QCryptographicHash::hash(
        seriesKey.trimmed().toUtf8(),
        QCryptographicHash::Sha1
    ).toHex();
    return QStringLiteral("series-hero:%1").arg(QString::fromLatin1(digest));
}

QString seriesHeroPendingKey(const QString &seriesKey, const QString &requestToken = QString())
{
    const QString prefix = seriesHeroPendingKeyPrefix(seriesKey);
    const QString normalizedToken = requestToken.trimmed();
    if (normalizedToken.isEmpty()) {
        return prefix;
    }
    return QStringLiteral("%1:%2").arg(prefix, normalizedToken);
}

int seriesHeroPageIndexForEntryCount(int entryCount)
{
    if (entryCount < 1) return -1;
    if (entryCount <= 4) {
        return std::clamp(entryCount / 2, 0, entryCount - 1);
    }

    const int startIndex = 2;
    const int endIndex = std::max(startIndex, entryCount - 3);
    return startIndex + ((endIndex - startIndex) / 2);
}

QVariantMap makeAsyncSeriesHeroResult(
    const QString &seriesKey = QString(),
    const QString &imageSource = QString(),
    const QString &localFilePath = QString(),
    const QString &error = QString()
)
{
    QVariantMap result;
    result.insert(QStringLiteral("seriesKey"), seriesKey);
    result.insert(QStringLiteral("imageSource"), imageSource);
    result.insert(QStringLiteral("localFilePath"), localFilePath);
    result.insert(QStringLiteral("error"), error);
    return result;
}

} // namespace

int ComicsListModel::heroCoverComicIdForSeries(const QString &seriesKey) const
{
    const QString requestedSeriesKey = seriesKey.trimmed();
    if (requestedSeriesKey.isEmpty()) return -1;

    int bestIssueId = -1;
    int bestIssueNumber = std::numeric_limits<int>::max();
    int bestFilenameId = -1;
    int bestFilenameNumber = std::numeric_limits<int>::max();
    int fallbackId = -1;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;

        if (fallbackId < 0 || row.id < fallbackId) {
            fallbackId = row.id;
        }

        const int parsedIssue = ComicImportMatching::extractPositiveIssueNumber(row.issueNumber);
        if (parsedIssue > 0) {
            if (parsedIssue < bestIssueNumber || (parsedIssue == bestIssueNumber && (bestIssueId < 0 || row.id < bestIssueId))) {
                bestIssueNumber = parsedIssue;
                bestIssueId = row.id;
            }
            continue;
        }

        const int parsedFromFilename = ComicImportMatching::extractPositiveNumberFromFilename(row.filename);
        if (parsedFromFilename > 0) {
            if (parsedFromFilename < bestFilenameNumber
                || (parsedFromFilename == bestFilenameNumber && (bestFilenameId < 0 || row.id < bestFilenameId))) {
                bestFilenameNumber = parsedFromFilename;
                bestFilenameId = row.id;
            }
        }
    }

    if (bestIssueId > 0) return bestIssueId;
    if (bestFilenameId > 0) return bestFilenameId;
    return fallbackId;
}

int ComicsListModel::requestSeriesHeroAsync(const QString &seriesKey)
{
    const int requestId = m_nextAsyncRequestId++;
    const QString requestedSeriesKey = seriesKey.trimmed();
    auto emitLaterSingle = [this, requestId, requestedSeriesKey](const QString &imageSource, const QString &errorText) {
        emitSeriesHeroReadyForRequestIds({ requestId }, requestedSeriesKey, imageSource, errorText);
    };

    if (requestedSeriesKey.isEmpty()) {
        emitLaterSingle({}, {});
        return requestId;
    }

    const QString cachedHeroPath = ComicReaderCache::cachedSeriesHeroPath(m_dataRoot, requestedSeriesKey);
    if (!cachedHeroPath.isEmpty()) {
        m_artworkState.latestSeriesHeroPendingKeyBySeriesKey.remove(requestedSeriesKey);
        ComicReaderCache::pruneSeriesHeroVariantsForKey(m_dataRoot, requestedSeriesKey, cachedHeroPath);
        emitLaterSingle(QUrl::fromLocalFile(cachedHeroPath).toString(), {});
        return requestId;
    }

    const int comicId = heroCoverComicIdForSeries(requestedSeriesKey);
    if (comicId < 1) {
        emitLaterSingle({}, {});
        return requestId;
    }

    const QString archivePath = archivePathForComicId(comicId);
    if (archivePath.trimmed().isEmpty()) {
        emitLaterSingle({}, {});
        return requestId;
    }

    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
    const QString pendingKey = seriesHeroPendingKey(
        requestedSeriesKey,
        QStringLiteral("%1:%2").arg(comicId).arg(cacheStamp)
    );
    if (!ComicReaderRequests::beginPendingImageRequest(m_artworkState.pendingSeriesHeroRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }
    m_artworkState.latestSeriesHeroPendingKeyBySeriesKey.insert(requestedSeriesKey, pendingKey);

    const QueuedSeriesHeroGeneration job {
        pendingKey,
        requestedSeriesKey,
        comicId,
        archivePath,
        cacheStamp,
        ComicReaderCache::preferredThumbnailFormat()
    };

    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;
    if (m_artworkState.activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount) {
        startQueuedSeriesHeroGeneration(job);
    } else {
        m_artworkState.seriesHeroGenerationQueue.push_back(job);
    }

    return requestId;
}

int ComicsListModel::requestRandomSeriesHeroAsync(const QString &seriesKey)
{
    const int requestId = m_nextAsyncRequestId++;
    const QString requestedSeriesKey = seriesKey.trimmed();
    const QString requestKey = QStringLiteral("__series_header_shuffle_preview__");
    auto emitLaterSingle = [this, requestId, requestKey](const QString &imageSource, const QString &errorText) {
        emitSeriesHeroReadyForRequestIds({ requestId }, requestKey, imageSource, errorText);
    };

    if (requestedSeriesKey.isEmpty()) {
        emitLaterSingle({}, {});
        return requestId;
    }

    QVector<int> candidateComicIds;
    QStringList candidateArchivePaths;
    QVector<QVector<int>> candidateShownPageIndices;
    candidateComicIds.reserve(std::min(static_cast<int>(m_rows.size()), kRandomSeriesHeroCandidateLimit));
    candidateArchivePaths.reserve(std::min(static_cast<int>(m_rows.size()), kRandomSeriesHeroCandidateLimit));
    candidateShownPageIndices.reserve(std::min(static_cast<int>(m_rows.size()), kRandomSeriesHeroCandidateLimit));

    SeriesHeroShuffleState &shuffleState = m_artworkState.randomSeriesHeroStateBySeriesKey[requestedSeriesKey];

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;

        const QString archivePath = archivePathForComicId(row.id);
        if (archivePath.trimmed().isEmpty()) continue;

        candidateComicIds.push_back(row.id);
        candidateArchivePaths.push_back(archivePath);
        candidateShownPageIndices.push_back(shuffleState.shownPageIndicesByComicId.value(row.id));

        if (candidateComicIds.size() >= kRandomSeriesHeroCandidateLimit) {
            break;
        }
    }

    if (candidateComicIds.isEmpty()) {
        m_artworkState.randomSeriesHeroStateBySeriesKey.remove(requestedSeriesKey);
        emitLaterSingle({}, QStringLiteral("No issues are available for shuffled background."));
        return requestId;
    }

    {
        QSet<int> candidateComicIdSet;
        candidateComicIdSet.reserve(candidateComicIds.size());
        for (int comicId : candidateComicIds) {
            candidateComicIdSet.insert(comicId);
        }

        const QList<int> trackedComicIds = shuffleState.shownPageIndicesByComicId.keys();
        for (int trackedComicId : trackedComicIds) {
            if (!candidateComicIdSet.contains(trackedComicId)) {
                shuffleState.shownPageIndicesByComicId.remove(trackedComicId);
            }
        }
    }

    const int candidateCount = std::min(candidateComicIds.size(), candidateArchivePaths.size());
    const int candidateStartIndex = candidateCount > 0
        ? (shuffleState.nextCandidateIndex % candidateCount)
        : 0;

    ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, requestKey);

    const QString pendingKey = seriesHeroPendingKey(requestKey);
    if (!ComicReaderRequests::beginPendingImageRequest(m_artworkState.pendingSeriesHeroRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }
    m_artworkState.latestSeriesHeroPendingKeyBySeriesKey.insert(requestKey, pendingKey);

    const QueuedSeriesHeroGeneration job {
        pendingKey,
        requestKey,
        requestedSeriesKey,
        0,
        QString(),
        QString(),
        ComicReaderCache::preferredThumbnailFormat(),
        true,
        candidateStartIndex,
        candidateComicIds,
        candidateArchivePaths,
        candidateShownPageIndices
    };

    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;
    if (m_artworkState.activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount) {
        startQueuedSeriesHeroGeneration(job);
    } else {
        m_artworkState.seriesHeroGenerationQueue.push_back(job);
    }

    return requestId;
}

void ComicsListModel::startQueuedSeriesHeroGeneration(const QueuedSeriesHeroGeneration &job)
{
    m_artworkState.activeSeriesHeroGenerationCount += 1;

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(
        watcher,
        &QFutureWatcher<QVariantMap>::finished,
        this,
        [this, watcher, pendingKey = job.pendingKey, seriesKey = job.seriesKey, shuffleStateKey = job.shuffleStateKey]() {
            const QVariantMap result = watcher->result();
            const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
                m_artworkState.pendingSeriesHeroRequestIdsByKey,
                pendingKey
            );
            m_artworkState.activeSeriesHeroGenerationCount = std::max(0, m_artworkState.activeSeriesHeroGenerationCount - 1);

            const QString imageSource = result.value(QStringLiteral("imageSource")).toString();
            const QString localFilePath = result.value(QStringLiteral("localFilePath")).toString();
            const QString errorText = result.value(QStringLiteral("error")).toString();
            const QString latestPendingKey = m_artworkState.latestSeriesHeroPendingKeyBySeriesKey.value(seriesKey);
            const bool staleResult = !latestPendingKey.isEmpty() && latestPendingKey != pendingKey;

            if (latestPendingKey == pendingKey) {
                m_artworkState.latestSeriesHeroPendingKeyBySeriesKey.remove(seriesKey);
            }

            if (staleResult || requestIds.isEmpty()) {
                if (!localFilePath.trimmed().isEmpty()) {
                    QFile::remove(localFilePath);
                }
            } else {
                if (!shuffleStateKey.trimmed().isEmpty() && errorText.trimmed().isEmpty()) {
                    SeriesHeroShuffleState &shuffleState = m_artworkState.randomSeriesHeroStateBySeriesKey[shuffleStateKey];
                    const int candidateCount = std::min(
                        result.value(QStringLiteral("candidateCount")).toInt(),
                        std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size())
                    );
                    if (candidateCount > 0) {
                        const int selectedCandidateIndex = result.contains(QStringLiteral("selectedCandidateIndex"))
                            ? result.value(QStringLiteral("selectedCandidateIndex")).toInt()
                            : -1;
                        if (selectedCandidateIndex >= 0) {
                            shuffleState.nextCandidateIndex = (selectedCandidateIndex + 1) % candidateCount;
                        } else {
                            shuffleState.nextCandidateIndex %= candidateCount;
                        }
                    }

                    const int selectedComicId = result.value(QStringLiteral("selectedComicId")).toInt();
                    if (selectedComicId > 0) {
                        QVector<int> shownPageIndices;
                        const QVariantList shownPageValues = result.value(QStringLiteral("shownPageIndices")).toList();
                        shownPageIndices.reserve(shownPageValues.size());
                        for (const QVariant &shownPageValue : shownPageValues) {
                            shownPageIndices.push_back(shownPageValue.toInt());
                        }
                        shuffleState.shownPageIndicesByComicId.insert(selectedComicId, shownPageIndices);
                    }
                }

                if (errorText.trimmed().isEmpty() && !localFilePath.trimmed().isEmpty()) {
                    ComicReaderCache::pruneSeriesHeroVariantsForKey(m_dataRoot, seriesKey, localFilePath);
                }
                emitSeriesHeroReadyForRequestIds(requestIds, seriesKey, imageSource, errorText);
            }

            watcher->deleteLater();
            pumpQueuedSeriesHeroGeneration();
        }
    );

    const auto task = [job, dataRoot = m_dataRoot]() {
        int resolvedComicId = job.comicId;
        QString resolvedArchivePath = job.archivePath;
        QString resolvedCacheStamp = job.cacheStamp;
        QStringList entries;
        int pageIndex = -1;
        int selectedCandidateIndex = -1;
        QVector<int> updatedShownPageIndices;

        if (job.randomEligiblePage) {
            QString lastListError;

            const int candidateCount = std::min(
                std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size()),
                job.candidateShownPageIndices.size()
            );
            const int startIndex = candidateCount > 0
                ? (job.candidateStartIndex % candidateCount)
                : 0;

            for (int offset = 0; offset < candidateCount; ++offset) {
                const int index = (startIndex + offset) % candidateCount;
                const int comicId = job.candidateComicIds.at(index);
                const QString archivePath = job.candidateArchivePaths.at(index).trimmed();
                if (comicId < 1 || archivePath.isEmpty()) continue;

                QStringList candidateEntries;
                QString listError;
                if (!ComicsListModel::listImageEntriesInArchive(archivePath, candidateEntries, listError)) {
                    lastListError = listError;
                    continue;
                }

                QVector<int> eligiblePageIndices;
                eligiblePageIndices.reserve(std::max(0, static_cast<int>(candidateEntries.size()) - 4));
                for (int candidatePageIndex = 2; candidatePageIndex < (candidateEntries.size() - 2); ++candidatePageIndex) {
                    eligiblePageIndices.push_back(candidatePageIndex);
                }
                if (eligiblePageIndices.isEmpty()) {
                    continue;
                }

                QVector<int> normalizedShownPageIndices;
                normalizedShownPageIndices.reserve(job.candidateShownPageIndices.at(index).size());
                for (int shownPageIndex : job.candidateShownPageIndices.at(index)) {
                    if (shownPageIndex < 0 || shownPageIndex >= candidateEntries.size()) continue;
                    if (!eligiblePageIndices.contains(shownPageIndex)) continue;
                    if (normalizedShownPageIndices.contains(shownPageIndex)) continue;
                    normalizedShownPageIndices.push_back(shownPageIndex);
                }

                QVector<int> availablePageIndices;
                availablePageIndices.reserve(eligiblePageIndices.size());
                for (int eligiblePageIndex : eligiblePageIndices) {
                    if (!normalizedShownPageIndices.contains(eligiblePageIndex)) {
                        availablePageIndices.push_back(eligiblePageIndex);
                    }
                }

                if (availablePageIndices.isEmpty()) {
                    normalizedShownPageIndices.clear();
                    availablePageIndices = eligiblePageIndices;
                }

                if (availablePageIndices.isEmpty()) {
                    continue;
                }

                selectedCandidateIndex = index;
                resolvedComicId = comicId;
                resolvedArchivePath = archivePath;
                resolvedCacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
                entries = candidateEntries;
                pageIndex = availablePageIndices.at(QRandomGenerator::global()->bounded(availablePageIndices.size()));
                updatedShownPageIndices = normalizedShownPageIndices;
                updatedShownPageIndices.push_back(pageIndex);
                break;
            }

            if (selectedCandidateIndex < 0 || resolvedComicId < 1 || entries.isEmpty()) {
                return makeAsyncSeriesHeroResult(
                    job.seriesKey,
                    QString(),
                    QString(),
                    lastListError.trimmed().isEmpty()
                        ? QStringLiteral("No eligible pages are available for shuffled background.")
                        : lastListError
                );
            }
        } else {
            const QString cachedHeroPath = ComicReaderCache::cachedSeriesHeroPath(dataRoot, job.seriesKey);
            if (!cachedHeroPath.isEmpty()) {
                return makeAsyncSeriesHeroResult(
                    job.seriesKey,
                    QUrl::fromLocalFile(cachedHeroPath).toString(),
                    cachedHeroPath,
                    QString()
                );
            }

            QString listError;
            if (!ComicsListModel::listImageEntriesInArchive(resolvedArchivePath, entries, listError)) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), listError);
            }
            if (entries.isEmpty()) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), QStringLiteral("No image pages found in archive."));
            }

            pageIndex = seriesHeroPageIndexForEntryCount(entries.size());
        }

        if (pageIndex < 0 || pageIndex >= entries.size()) {
            return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), QStringLiteral("No valid hero page found in archive."));
        }

        const QString entryName = entries.at(pageIndex);
        QString extension = QFileInfo(entryName).suffix().toLower();
        if (extension.isEmpty()) extension = QStringLiteral("img");

        const QString pageCachePath = ComicReaderCache::buildReaderCachePath(
            dataRoot,
            resolvedComicId,
            resolvedCacheStamp,
            pageIndex,
            extension
        );
        const QString heroCacheStamp = QStringLiteral("%1-p%2").arg(resolvedCacheStamp).arg(pageIndex + 1);
        const QString heroPath = ComicReaderCache::buildSeriesHeroPathWithFormat(
            dataRoot,
            job.seriesKey,
            heroCacheStamp,
            job.heroFormat
        );

        if (!ComicReaderCache::ensureDirForFile(pageCachePath) || !ComicReaderCache::ensureDirForFile(heroPath)) {
            return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), QStringLiteral("Failed to create hero cache directory."));
        }

        const QFileInfo localPageInfo(pageCachePath);
        if (localPageInfo.exists() && localPageInfo.size() <= 0) {
            QFile::remove(pageCachePath);
        }

        if (!QFileInfo::exists(pageCachePath)) {
            QString extractError;
            if (!ComicsListModel::extractArchiveEntryToFile(resolvedArchivePath, entryName, pageCachePath, extractError)) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), extractError);
            }
        }

        const QFileInfo localHeroInfo(heroPath);
        if (localHeroInfo.exists() && localHeroInfo.size() <= 0) {
            QFile::remove(heroPath);
        }

        if (!QFileInfo::exists(heroPath)) {
            QString heroError;
            if (!ComicImagePreparation::generateHeroBackgroundImage(pageCachePath, heroPath, job.heroFormat, heroError)) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), heroError);
            }
        }

        QVariantMap result = makeAsyncSeriesHeroResult(
            job.seriesKey,
            QUrl::fromLocalFile(heroPath).toString(),
            heroPath,
            QString()
        );
        if (job.randomEligiblePage) {
            QVariantList shownPageValues;
            shownPageValues.reserve(updatedShownPageIndices.size());
            for (int shownPageIndex : updatedShownPageIndices) {
                shownPageValues.push_back(shownPageIndex);
            }
            result.insert(
                QStringLiteral("candidateCount"),
                std::min(
                    std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size()),
                    job.candidateShownPageIndices.size()
                )
            );
            result.insert(QStringLiteral("selectedCandidateIndex"), selectedCandidateIndex);
            result.insert(QStringLiteral("selectedComicId"), resolvedComicId);
            result.insert(QStringLiteral("shownPageIndices"), shownPageValues);
        }
        return result;
    };

    watcher->setFuture(QtConcurrent::run(task));
}

void ComicsListModel::resetRandomSeriesHeroState(const QString &seriesKey)
{
    const QString normalizedSeriesKey = seriesKey.trimmed();
    if (normalizedSeriesKey.isEmpty()) return;

    m_artworkState.randomSeriesHeroStateBySeriesKey.remove(normalizedSeriesKey);
}

void ComicsListModel::pumpQueuedSeriesHeroGeneration()
{
    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;

    while (m_artworkState.activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount
           && !m_artworkState.seriesHeroGenerationQueue.isEmpty()) {
        const QueuedSeriesHeroGeneration job = m_artworkState.seriesHeroGenerationQueue.takeFirst();
        if (!ComicReaderRequests::hasPendingImageRequest(m_artworkState.pendingSeriesHeroRequestIdsByKey, job.pendingKey)) {
            continue;
        }
        startQueuedSeriesHeroGeneration(job);
    }
}

void ComicsListModel::emitSeriesHeroReadyForRequestIds(
    const QList<int> &requestIds,
    const QString &seriesKey,
    const QString &imageSource,
    const QString &error
)
{
    if (requestIds.isEmpty()) return;

    QMetaObject::invokeMethod(
        this,
        [this, requestIds, seriesKey, imageSource, error]() {
            for (int requestId : requestIds) {
                emit seriesHeroReady(requestId, seriesKey, imageSource, error);
            }
        },
        Qt::QueuedConnection
    );
}

void ComicsListModel::purgeSeriesHeroCacheForKey(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return;

    ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, normalizedKey);
    m_artworkState.latestSeriesHeroPendingKeyBySeriesKey.remove(normalizedKey);

    const QString pendingKeyPrefix = seriesHeroPendingKeyPrefix(normalizedKey);
    const QStringList pendingKeys = m_artworkState.pendingSeriesHeroRequestIdsByKey.keys();
    for (const QString &pendingKey : pendingKeys) {
        if (pendingKey == pendingKeyPrefix || pendingKey.startsWith(pendingKeyPrefix + QLatin1Char(':'))) {
            m_artworkState.pendingSeriesHeroRequestIdsByKey.remove(pendingKey);
        }
    }

    m_artworkState.seriesHeroGenerationQueue.erase(
        std::remove_if(
            m_artworkState.seriesHeroGenerationQueue.begin(),
            m_artworkState.seriesHeroGenerationQueue.end(),
            [normalizedKey](const QueuedSeriesHeroGeneration &job) {
                return job.seriesKey == normalizedKey;
            }
        ),
        m_artworkState.seriesHeroGenerationQueue.end()
    );
}
