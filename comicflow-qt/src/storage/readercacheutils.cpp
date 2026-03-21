#include "storage/readercacheutils.h"

#include <algorithm>

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileInfoList>
#include <QImageWriter>
#include <QRegularExpression>
#include <QSet>

namespace {

QString coverStoreRootPath(const QString &dataRoot)
{
    return QDir(dataRoot).filePath(QStringLiteral("Covers"));
}

QString seriesHeroStoreRootPath(const QString &dataRoot)
{
    return QDir(coverStoreRootPath(dataRoot)).filePath(QStringLiteral("SeriesHero"));
}

QString seriesHeaderStoreRootPath(const QString &dataRoot)
{
    return QDir(coverStoreRootPath(dataRoot)).filePath(QStringLiteral("SeriesHeader"));
}

QString coverStoreBucketName(int comicId)
{
    return QStringLiteral("%1").arg(std::max(0, comicId / 1000), 4, 10, QChar('0'));
}

QString seriesHeroKeyDigest(const QString &seriesKey)
{
    const QByteArray seed = seriesKey.trimmed().toUtf8();
    return QString::fromLatin1(
        QCryptographicHash::hash(seed, QCryptographicHash::Sha1).toHex()
    );
}

QString seriesHeroDirPath(const QString &dataRoot, const QString &seriesKey)
{
    const QString digest = seriesHeroKeyDigest(seriesKey);
    const QString bucket = digest.left(4);
    return QDir(seriesHeroStoreRootPath(dataRoot)).filePath(
        QStringLiteral("%1/series-%2").arg(bucket, digest)
    );
}

QString seriesHeaderDirPath(const QString &dataRoot, const QString &seriesKey)
{
    const QString digest = seriesHeroKeyDigest(seriesKey);
    const QString bucket = digest.left(4);
    return QDir(seriesHeaderStoreRootPath(dataRoot)).filePath(
        QStringLiteral("%1/series-%2").arg(bucket, digest)
    );
}

QString coverStoreComicDirPath(const QString &dataRoot, int comicId)
{
    return QDir(coverStoreRootPath(dataRoot)).filePath(
        QStringLiteral("%1/comic-%2")
            .arg(coverStoreBucketName(comicId))
            .arg(comicId)
    );
}

void trimEmptyParentDirs(const QString &rootPath, const QString &leafPath)
{
    const QString normalizedRoot = QDir::cleanPath(QFileInfo(rootPath).absoluteFilePath());
    QString current = QDir::cleanPath(QFileInfo(leafPath).absoluteFilePath());

    while (!current.isEmpty() && current.startsWith(normalizedRoot, Qt::CaseInsensitive)) {
        if (current.compare(normalizedRoot, Qt::CaseInsensitive) == 0) {
            break;
        }

        QDir dir(current);
        if (dir.exists() && !dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot).isEmpty()) {
            break;
        }

        const QFileInfo info(current);
        const QString parentPath = info.absolutePath();
        if (parentPath.isEmpty() || parentPath.compare(current, Qt::CaseInsensitive) == 0) {
            break;
        }

        QDir parentDir(parentPath);
        parentDir.rmdir(info.fileName());
        current = parentPath;
    }
}

QString thumbnailExtensionForFormat(const QByteArray &format)
{
    if (format == QByteArrayLiteral("webp")) return QStringLiteral("webp");
    if (format == QByteArrayLiteral("png")) return QStringLiteral("png");
    return QStringLiteral("jpg");
}

QString readerCacheRootPath(const QString &dataRoot)
{
    return QDir(dataRoot).filePath(QStringLiteral(".runtime/reader-cache"));
}

QString readerIssueStampFilePath(const QString &dataRoot, int comicId)
{
    return QDir(readerCacheRootPath(dataRoot)).filePath(
        QStringLiteral("issue-%1.stamp").arg(comicId)
    );
}

void touchFileTimestamp(const QString &filePath)
{
    const QFileInfo info(filePath);
    if (!info.exists()) return;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadWrite)) return;

    const QDateTime now = QDateTime::currentDateTimeUtc();
    file.setFileTime(now, QFileDevice::FileModificationTime);
    file.setFileTime(now, QFileDevice::FileAccessTime);
    file.close();
}

struct ReaderCacheIssueEntry {
    int comicId = 0;
    qint64 totalBytes = 0;
    QDateTime lastTouchedUtc;
    QStringList filePaths;
    QString stampPath;
};

} // namespace

namespace ComicReaderCache {

QString buildArchiveCacheStamp(const QString &archivePath)
{
    const QFileInfo archiveInfo(archivePath);
    const QString normalizedPath = QDir::toNativeSeparators(archiveInfo.absoluteFilePath());
    const qint64 size = archiveInfo.exists() ? archiveInfo.size() : 0;
    const qint64 mtimeUtcMs = archiveInfo.exists()
        ? archiveInfo.lastModified().toUTC().toMSecsSinceEpoch()
        : 0;

    const QByteArray seed = QStringLiteral("%1|%2|%3")
        .arg(normalizedPath)
        .arg(size)
        .arg(mtimeUtcMs)
        .toUtf8();
    const QByteArray digest = QCryptographicHash::hash(seed, QCryptographicHash::Sha1).toHex();
    return QString::fromLatin1(digest.left(12));
}

QString buildReaderCachePath(
    const QString &dataRoot,
    int comicId,
    const QString &cacheStamp,
    int pageIndex,
    const QString &extension
)
{
    const QString cacheDirPath = readerCacheRootPath(dataRoot);
    return QDir(cacheDirPath).filePath(
        QStringLiteral("comic-%1-%2-page-%3.%4")
            .arg(comicId)
            .arg(cacheStamp)
            .arg(pageIndex + 1)
            .arg(extension)
    );
}

QByteArray preferredThumbnailFormat()
{
    static const QByteArray chosen = []() {
        const QList<QByteArray> supported = QImageWriter::supportedImageFormats();
        if (supported.contains(QByteArrayLiteral("webp"))) return QByteArrayLiteral("webp");
        if (supported.contains(QByteArrayLiteral("png"))) return QByteArrayLiteral("png");
        return QByteArrayLiteral("jpg");
    }();
    return chosen;
}

QString buildThumbnailPathWithFormat(
    const QString &dataRoot,
    int comicId,
    const QString &cacheStamp,
    const QByteArray &format
)
{
    const QString coverDirPath = coverStoreComicDirPath(dataRoot, comicId);
    return QDir(coverDirPath).filePath(
        QStringLiteral("grid-%1.%2")
            .arg(cacheStamp)
            .arg(thumbnailExtensionForFormat(format))
    );
}

QString buildSeriesHeroPathWithFormat(
    const QString &dataRoot,
    const QString &seriesKey,
    const QString &cacheStamp,
    const QByteArray &format
)
{
    const QString heroDirPath = seriesHeroDirPath(dataRoot, seriesKey);
    return QDir(heroDirPath).filePath(
        QStringLiteral("hero-%1.%2")
            .arg(cacheStamp, thumbnailExtensionForFormat(format))
    );
}

QString cachedSeriesHeroPath(const QString &dataRoot, const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return {};

    const QDir heroDir(seriesHeroDirPath(dataRoot, normalizedKey));
    if (!heroDir.exists()) return {};

    const QFileInfoList entries = heroDir.entryInfoList(
        { QStringLiteral("hero-*"), QStringLiteral("hero-*.*") },
        QDir::Files | QDir::NoDotAndDotDot,
        QDir::Time
    );
    for (const QFileInfo &entry : entries) {
        if (entry.size() > 0) {
            return entry.absoluteFilePath();
        }
    }

    return {};
}

QString buildSeriesHeaderOverridePath(
    const QString &dataRoot,
    const QString &seriesKey,
    const QString &slotName,
    const QString &extension
)
{
    const QString normalizedKey = seriesKey.trimmed();
    const QString normalizedSlot = slotName.trimmed().toLower();
    const QString normalizedExtension = extension.trimmed().toLower();
    if (normalizedKey.isEmpty() || normalizedSlot.isEmpty()) return {};

    return QDir(seriesHeaderDirPath(dataRoot, normalizedKey)).filePath(
        normalizedExtension.isEmpty()
            ? normalizedSlot
            : QStringLiteral("%1.%2").arg(normalizedSlot, normalizedExtension)
    );
}

void pruneThumbnailVariantsForComic(const QString &dataRoot, int comicId, const QString &keepThumbnailPath)
{
    if (comicId < 1) return;

    const QDir coverDir(coverStoreComicDirPath(dataRoot, comicId));
    if (!coverDir.exists()) return;

    const QString keepAbsPath = keepThumbnailPath.trimmed().isEmpty()
        ? QString()
        : QFileInfo(keepThumbnailPath).absoluteFilePath();

    const QFileInfoList entries = coverDir.entryInfoList(
        { QStringLiteral("grid-*"), QStringLiteral("grid-*.*") },
        QDir::Files | QDir::NoDotAndDotDot
    );
    for (const QFileInfo &entry : entries) {
        const QString entryPath = entry.absoluteFilePath();
        if (!keepAbsPath.isEmpty() && entryPath.compare(keepAbsPath, Qt::CaseInsensitive) == 0) {
            continue;
        }
        QFile::remove(entryPath);
    }
}

void pruneSeriesHeroVariantsForKey(const QString &dataRoot, const QString &seriesKey, const QString &keepHeroPath)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return;

    const QDir heroDir(seriesHeroDirPath(dataRoot, normalizedKey));
    if (!heroDir.exists()) return;

    const QString keepAbsPath = keepHeroPath.trimmed().isEmpty()
        ? QString()
        : QFileInfo(keepHeroPath).absoluteFilePath();

    const QFileInfoList entries = heroDir.entryInfoList(
        { QStringLiteral("hero-*"), QStringLiteral("hero-*.*") },
        QDir::Files | QDir::NoDotAndDotDot
    );
    for (const QFileInfo &entry : entries) {
        const QString entryPath = entry.absoluteFilePath();
        if (!keepAbsPath.isEmpty() && entryPath.compare(keepAbsPath, Qt::CaseInsensitive) == 0) {
            continue;
        }
        QFile::remove(entryPath);
    }
}

void pruneSeriesHeaderOverrideVariantsForKey(
    const QString &dataRoot,
    const QString &seriesKey,
    const QString &slotName,
    const QString &keepOverridePath
)
{
    const QString normalizedKey = seriesKey.trimmed();
    const QString normalizedSlot = slotName.trimmed().toLower();
    if (normalizedKey.isEmpty() || normalizedSlot.isEmpty()) return;

    const QDir headerDir(seriesHeaderDirPath(dataRoot, normalizedKey));
    if (!headerDir.exists()) return;

    const QString keepAbsPath = keepOverridePath.trimmed().isEmpty()
        ? QString()
        : QFileInfo(keepOverridePath).absoluteFilePath();

    const QFileInfoList entries = headerDir.entryInfoList(
        { QStringLiteral("%1").arg(normalizedSlot), QStringLiteral("%1.*").arg(normalizedSlot) },
        QDir::Files | QDir::NoDotAndDotDot
    );
    for (const QFileInfo &entry : entries) {
        const QString entryPath = entry.absoluteFilePath();
        if (!keepAbsPath.isEmpty() && entryPath.compare(keepAbsPath, Qt::CaseInsensitive) == 0) {
            continue;
        }
        QFile::remove(entryPath);
    }
}

void purgeSeriesHeaderOverrideSlotForKey(const QString &dataRoot, const QString &seriesKey, const QString &slotName)
{
    const QString normalizedKey = seriesKey.trimmed();
    const QString normalizedSlot = slotName.trimmed().toLower();
    if (normalizedKey.isEmpty() || normalizedSlot.isEmpty()) return;

    const QDir headerDir(seriesHeaderDirPath(dataRoot, normalizedKey));
    if (!headerDir.exists()) return;

    const QFileInfoList entries = headerDir.entryInfoList(
        { QStringLiteral("%1").arg(normalizedSlot), QStringLiteral("%1.*").arg(normalizedSlot) },
        QDir::Files | QDir::NoDotAndDotDot
    );
    for (const QFileInfo &entry : entries) {
        QFile::remove(entry.absoluteFilePath());
    }
}

void purgeSeriesHeaderOverridesForKey(const QString &dataRoot, const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return;

    const QString headerRoot = seriesHeaderStoreRootPath(dataRoot);
    const QString headerDirPath = seriesHeaderDirPath(dataRoot, normalizedKey);
    const QDir headerDir(headerDirPath);
    if (!headerDir.exists()) return;

    QDir(headerDirPath).removeRecursively();
    trimEmptyParentDirs(headerRoot, QFileInfo(headerDirPath).absolutePath());
}

void purgeRuntimeCacheForComic(const QString &dataRoot, int comicId)
{
    if (comicId < 1) return;

    const QString coverRoot = coverStoreRootPath(dataRoot);
    const QString coverDirPath = coverStoreComicDirPath(dataRoot, comicId);
    const QDir coverDir(coverDirPath);
    if (coverDir.exists()) {
        QDir(coverDirPath).removeRecursively();
        trimEmptyParentDirs(coverRoot, QFileInfo(coverDirPath).absolutePath());
    }

    const QDir thumbCacheDir(QDir(dataRoot).filePath(QStringLiteral(".runtime/thumb-cache")));
    if (thumbCacheDir.exists()) {
        const QStringList thumbPatterns = {
            QStringLiteral("comic-%1-cover.jpg").arg(comicId),
            QStringLiteral("comic-%1-cover-*").arg(comicId),
            QStringLiteral("comic-%1-cover-*.*").arg(comicId)
        };
        const QFileInfoList thumbEntries = thumbCacheDir.entryInfoList(
            thumbPatterns,
            QDir::Files | QDir::NoDotAndDotDot
        );
        for (const QFileInfo &entry : thumbEntries) {
            QFile::remove(entry.absoluteFilePath());
        }
    }

    QFile::remove(readerIssueStampFilePath(dataRoot, comicId));

    const QDir readerCacheDir(readerCacheRootPath(dataRoot));
    if (!readerCacheDir.exists()) return;

    const QStringList patterns = {
        QStringLiteral("comic-%1-page-*").arg(comicId),
        QStringLiteral("comic-%1-page-*.*").arg(comicId),
        QStringLiteral("comic-%1-*-page-*").arg(comicId),
        QStringLiteral("comic-%1-*-page-*.*").arg(comicId)
    };
    const QFileInfoList entries = readerCacheDir.entryInfoList(patterns, QDir::Files | QDir::NoDotAndDotDot);
    for (const QFileInfo &entry : entries) {
        QFile::remove(entry.absoluteFilePath());
    }
}

void noteReaderIssueCacheUsage(const QString &dataRoot, int comicId)
{
    if (comicId < 1) return;

    const QString stampPath = readerIssueStampFilePath(dataRoot, comicId);
    if (!ensureDirForFile(stampPath)) return;

    QFile file(stampPath);
    if (!file.exists()) {
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.close();
        }
    }

    touchFileTimestamp(stampPath);
}

void pruneReaderCache(const QString &dataRoot)
{
    constexpr int kMaxIssues = 10;
    constexpr qint64 kMaxBytes = 500ll * 1024ll * 1024ll;

    const QDir cacheDir(readerCacheRootPath(dataRoot));
    if (!cacheDir.exists()) return;

    const QRegularExpression pagePattern(QStringLiteral("^comic-(\\d+)-.+-page-\\d+\\.[^.]+$"));
    QHash<int, ReaderCacheIssueEntry> entriesByComicId;
    const QFileInfoList allFiles = cacheDir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot, QDir::Time);

    for (const QFileInfo &fileInfo : allFiles) {
        const QRegularExpressionMatch match = pagePattern.match(fileInfo.fileName());
        if (!match.hasMatch()) continue;

        bool ok = false;
        const int comicId = match.captured(1).toInt(&ok);
        if (!ok || comicId < 1) continue;

        ReaderCacheIssueEntry &entry = entriesByComicId[comicId];
        entry.comicId = comicId;
        entry.totalBytes += std::max<qint64>(0, fileInfo.size());
        entry.filePaths.push_back(fileInfo.absoluteFilePath());
        if (!entry.lastTouchedUtc.isValid() || fileInfo.lastModified().toUTC() > entry.lastTouchedUtc) {
            entry.lastTouchedUtc = fileInfo.lastModified().toUTC();
        }
    }

    if (entriesByComicId.isEmpty()) return;

    for (auto it = entriesByComicId.begin(); it != entriesByComicId.end(); ++it) {
        ReaderCacheIssueEntry &entry = it.value();
        entry.stampPath = readerIssueStampFilePath(dataRoot, entry.comicId);
        const QFileInfo stampInfo(entry.stampPath);
        if (stampInfo.exists() && stampInfo.isFile()) {
            const QDateTime stampTimeUtc = stampInfo.lastModified().toUTC();
            if (!entry.lastTouchedUtc.isValid() || stampTimeUtc > entry.lastTouchedUtc) {
                entry.lastTouchedUtc = stampTimeUtc;
            }
        }
    }

    QList<ReaderCacheIssueEntry> orderedEntries = entriesByComicId.values();
    std::sort(
        orderedEntries.begin(),
        orderedEntries.end(),
        [](const ReaderCacheIssueEntry &a, const ReaderCacheIssueEntry &b) {
            if (a.lastTouchedUtc == b.lastTouchedUtc) {
                return a.comicId > b.comicId;
            }
            if (!a.lastTouchedUtc.isValid()) return false;
            if (!b.lastTouchedUtc.isValid()) return true;
            return a.lastTouchedUtc > b.lastTouchedUtc;
        }
    );

    QSet<int> keepComicIds;
    qint64 keptBytes = 0;
    for (int i = 0; i < orderedEntries.size(); ++i) {
        const ReaderCacheIssueEntry &entry = orderedEntries.at(i);
        if (i < kMaxIssues) {
            keepComicIds.insert(entry.comicId);
            keptBytes += entry.totalBytes;
        }
    }

    for (int i = orderedEntries.size() - 1; i >= 0 && keptBytes > kMaxBytes; --i) {
        const ReaderCacheIssueEntry &entry = orderedEntries.at(i);
        if (!keepComicIds.contains(entry.comicId)) continue;
        if (keepComicIds.size() <= 1) break;
        keepComicIds.remove(entry.comicId);
        keptBytes -= entry.totalBytes;
    }

    for (const ReaderCacheIssueEntry &entry : orderedEntries) {
        if (keepComicIds.contains(entry.comicId)) continue;

        for (const QString &filePath : entry.filePaths) {
            QFile::remove(filePath);
        }
        if (!entry.stampPath.isEmpty()) {
            QFile::remove(entry.stampPath);
        }
    }
}

void purgeSeriesHeroForKey(const QString &dataRoot, const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return;

    const QString heroRoot = seriesHeroStoreRootPath(dataRoot);
    const QString heroDirPath = seriesHeroDirPath(dataRoot, normalizedKey);
    const QDir heroDir(heroDirPath);
    if (!heroDir.exists()) return;

    QDir(heroDirPath).removeRecursively();
    trimEmptyParentDirs(heroRoot, QFileInfo(heroDirPath).absolutePath());
}

bool ensureDirForFile(const QString &filePath)
{
    return QDir().mkpath(QFileInfo(filePath).absolutePath());
}

} // namespace ComicReaderCache
