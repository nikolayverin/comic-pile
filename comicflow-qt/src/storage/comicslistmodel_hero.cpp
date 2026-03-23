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
#include <QUrl>
#include <QtConcurrent>

namespace {

QString seriesHeroPendingKey(const QString &seriesKey)
{
    const QByteArray digest = QCryptographicHash::hash(
        seriesKey.trimmed().toUtf8(),
        QCryptographicHash::Sha1
    ).toHex();
    return QStringLiteral("series-hero:%1").arg(QString::fromLatin1(digest));
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

    const QString pendingKey = seriesHeroPendingKey(requestedSeriesKey);
    if (!ComicReaderRequests::beginPendingImageRequest(m_pendingSeriesHeroRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    const QueuedSeriesHeroGeneration job {
        pendingKey,
        requestedSeriesKey,
        comicId,
        archivePath,
        ComicReaderCache::buildArchiveCacheStamp(archivePath),
        ComicReaderCache::preferredThumbnailFormat()
    };

    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;
    if (m_activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount) {
        startQueuedSeriesHeroGeneration(job);
    } else {
        m_seriesHeroGenerationQueue.push_back(job);
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
    candidateComicIds.reserve(m_rows.size());
    candidateArchivePaths.reserve(m_rows.size());

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;

        const QString archivePath = archivePathForComicId(row.id);
        if (archivePath.trimmed().isEmpty()) continue;

        candidateComicIds.push_back(row.id);
        candidateArchivePaths.push_back(archivePath);
    }

    if (candidateComicIds.isEmpty()) {
        emitLaterSingle({}, QStringLiteral("No issues are available for shuffled background."));
        return requestId;
    }

    ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, requestKey);

    const QString pendingKey = seriesHeroPendingKey(requestKey);
    if (!ComicReaderRequests::beginPendingImageRequest(m_pendingSeriesHeroRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    const QueuedSeriesHeroGeneration job {
        pendingKey,
        requestKey,
        0,
        QString(),
        QString(),
        ComicReaderCache::preferredThumbnailFormat(),
        true,
        candidateComicIds,
        candidateArchivePaths
    };

    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;
    if (m_activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount) {
        startQueuedSeriesHeroGeneration(job);
    } else {
        m_seriesHeroGenerationQueue.push_back(job);
    }

    return requestId;
}

void ComicsListModel::startQueuedSeriesHeroGeneration(const QueuedSeriesHeroGeneration &job)
{
    m_activeSeriesHeroGenerationCount += 1;

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(
        watcher,
        &QFutureWatcher<QVariantMap>::finished,
        this,
        [this, watcher, pendingKey = job.pendingKey, seriesKey = job.seriesKey]() {
            const QVariantMap result = watcher->result();
            const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
                m_pendingSeriesHeroRequestIdsByKey,
                pendingKey
            );
            m_activeSeriesHeroGenerationCount = std::max(0, m_activeSeriesHeroGenerationCount - 1);

            const QString imageSource = result.value(QStringLiteral("imageSource")).toString();
            const QString localFilePath = result.value(QStringLiteral("localFilePath")).toString();
            const QString errorText = result.value(QStringLiteral("error")).toString();

            if (requestIds.isEmpty()) {
                ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, seriesKey);
            } else {
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
        struct HeroSource {
            int comicId = 0;
            QString archivePath;
            QString cacheStamp;
            QStringList entries;
            int eligiblePageCount = 0;
        };

        int resolvedComicId = job.comicId;
        QString resolvedArchivePath = job.archivePath;
        QString resolvedCacheStamp = job.cacheStamp;
        QStringList entries;
        int pageIndex = -1;

        if (job.randomEligiblePage) {
            QVector<HeroSource> sources;
            sources.reserve(std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size()));
            int totalEligiblePages = 0;
            QString lastListError;

            const int candidateCount = std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size());
            for (int index = 0; index < candidateCount; ++index) {
                const int comicId = job.candidateComicIds.at(index);
                const QString archivePath = job.candidateArchivePaths.at(index).trimmed();
                if (comicId < 1 || archivePath.isEmpty()) continue;

                QStringList candidateEntries;
                QString listError;
                if (!ComicsListModel::listImageEntriesInArchive(archivePath, candidateEntries, listError)) {
                    lastListError = listError;
                    continue;
                }

                const int eligiblePageCount = std::max(0, static_cast<int>(candidateEntries.size()) - 4);
                if (eligiblePageCount < 1) {
                    continue;
                }

                HeroSource source;
                source.comicId = comicId;
                source.archivePath = archivePath;
                source.cacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
                source.entries = candidateEntries;
                source.eligiblePageCount = eligiblePageCount;
                sources.push_back(source);
                totalEligiblePages += eligiblePageCount;
            }

            if (totalEligiblePages < 1) {
                const QString errorText = lastListError.trimmed().isEmpty()
                    ? QStringLiteral("No eligible pages are available for shuffled background.")
                    : lastListError;
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), errorText);
            }

            int selectedOffset = QRandomGenerator::global()->bounded(totalEligiblePages);
            HeroSource selectedSource;
            for (const HeroSource &source : sources) {
                if (selectedOffset >= source.eligiblePageCount) {
                    selectedOffset -= source.eligiblePageCount;
                    continue;
                }
                selectedSource = source;
                break;
            }

            if (selectedSource.comicId < 1 || selectedSource.entries.isEmpty()) {
                return makeAsyncSeriesHeroResult(
                    job.seriesKey,
                    QString(),
                    QString(),
                    QStringLiteral("Failed to resolve shuffled background source.")
                );
            }

            resolvedComicId = selectedSource.comicId;
            resolvedArchivePath = selectedSource.archivePath;
            resolvedCacheStamp = selectedSource.cacheStamp;
            entries = selectedSource.entries;
            pageIndex = 2 + selectedOffset;
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

        return makeAsyncSeriesHeroResult(
            job.seriesKey,
            QUrl::fromLocalFile(heroPath).toString(),
            heroPath,
            QString()
        );
    };

    watcher->setFuture(QtConcurrent::run(task));
}

void ComicsListModel::pumpQueuedSeriesHeroGeneration()
{
    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;

    while (m_activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount && !m_seriesHeroGenerationQueue.isEmpty()) {
        const QueuedSeriesHeroGeneration job = m_seriesHeroGenerationQueue.takeFirst();
        if (!ComicReaderRequests::hasPendingImageRequest(m_pendingSeriesHeroRequestIdsByKey, job.pendingKey)) {
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

    const QString pendingKey = seriesHeroPendingKey(normalizedKey);
    m_pendingSeriesHeroRequestIdsByKey.remove(pendingKey);

    m_seriesHeroGenerationQueue.erase(
        std::remove_if(
            m_seriesHeroGenerationQueue.begin(),
            m_seriesHeroGenerationQueue.end(),
            [normalizedKey](const QueuedSeriesHeroGeneration &job) {
                return job.seriesKey == normalizedKey;
            }
        ),
        m_seriesHeroGenerationQueue.end()
    );
}
