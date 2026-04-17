#include "storage/imagepreparationops.h"

#include "storage/comicinfoarchive.h"
#include "storage/readercacheutils.h"

#include <algorithm>
#include <cmath>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QSaveFile>
#include <QTransform>
#include <QVariantList>
#include <QtMath>

namespace ComicImagePreparation {

bool loadReadableImageFile(const QString &filePath, QImage &imageOut, QString &errorText)
{
    imageOut = QImage();
    errorText.clear();

    const QString normalizedPath = QDir::toNativeSeparators(QFileInfo(filePath.trimmed()).absoluteFilePath());
    if (normalizedPath.isEmpty()) {
        errorText = QStringLiteral("Image file path is required.");
        return false;
    }

    const QFileInfo info(normalizedPath);
    if (!info.exists() || !info.isFile()) {
        errorText = QStringLiteral("Image file not found: %1").arg(filePath.trimmed());
        return false;
    }

    QImageReader reader(normalizedPath);
    reader.setAutoTransform(true);
    const QImage image = reader.read();
    if (image.isNull()) {
        errorText = QStringLiteral("Selected image could not be opened.");
        return false;
    }

    if (image.width() <= 0 || image.height() <= 0) {
        errorText = QStringLiteral("Selected image is invalid.");
        return false;
    }

    imageOut = image;
    return true;
}

bool writeThumbnailImage(
    const QImage &sourceImage,
    const QString &targetThumbnailPath,
    const QByteArray &targetFormat,
    QString &errorText
)
{
    errorText.clear();

    constexpr int kThumbTargetWidth = 510;
    constexpr int kThumbTargetHeight = 780;
    constexpr int kThumbQualityWebp = 90;
    constexpr int kThumbQualityJpeg = 90;

    QImage working = sourceImage;
    const int srcW = working.width();
    const int srcH = working.height();
    if (srcW <= 0 || srcH <= 0) {
        errorText = QStringLiteral("Invalid source image size for thumbnail.");
        return false;
    }

    const double targetAspect = static_cast<double>(kThumbTargetWidth) / static_cast<double>(kThumbTargetHeight);
    const double srcAspect = static_cast<double>(srcW) / static_cast<double>(srcH);

    QRect cropRect(0, 0, srcW, srcH);
    if (srcAspect > targetAspect) {
        const int cropW = std::max(1, static_cast<int>(std::round(srcH * targetAspect)));
        const int offsetX = std::max(0, (srcW - cropW) / 2);
        cropRect = QRect(offsetX, 0, std::min(cropW, srcW), srcH);
    } else if (srcAspect < targetAspect) {
        const int cropH = std::max(1, static_cast<int>(std::round(srcW / targetAspect)));
        const int offsetY = std::max(0, (srcH - cropH) / 2);
        cropRect = QRect(0, offsetY, srcW, std::min(cropH, srcH));
    }

    if (cropRect.width() > 0 && cropRect.height() > 0
        && (cropRect.width() != srcW || cropRect.height() != srcH)) {
        working = working.copy(cropRect);
    }

    const QImage scaled = working.scaled(
        kThumbTargetWidth,
        kThumbTargetHeight,
        Qt::IgnoreAspectRatio,
        Qt::SmoothTransformation
    );
    if (scaled.isNull()) {
        errorText = QStringLiteral("Failed to scale image for thumbnail.");
        return false;
    }

    if (!ComicReaderCache::ensureDirForFile(targetThumbnailPath)) {
        errorText = QStringLiteral("Failed to create thumbnail cache directory.");
        return false;
    }

    QSaveFile file(targetThumbnailPath);
    if (!file.open(QIODevice::WriteOnly)) {
        errorText = QStringLiteral("Failed to open thumbnail file for writing.");
        return false;
    }

    {
        QImageWriter writer(&file, targetFormat);
        if (targetFormat == QByteArrayLiteral("webp")) {
            writer.setQuality(kThumbQualityWebp);
        } else if (targetFormat == QByteArrayLiteral("jpg") || targetFormat == QByteArrayLiteral("jpeg")) {
            writer.setQuality(kThumbQualityJpeg);
        }
        if (!writer.write(scaled)) {
            file.cancelWriting();
            errorText = QStringLiteral("Failed to write thumbnail image: %1").arg(writer.errorString());
            return false;
        }
    }

    if (!file.commit()) {
        errorText = QStringLiteral("Failed to finalize thumbnail image.");
        return false;
    }

    return true;
}

bool generateThumbnailImage(
    const QString &sourceImagePath,
    const QString &targetThumbnailPath,
    const QByteArray &targetFormat,
    QString &errorText
)
{
    QImage image;
    if (!loadReadableImageFile(sourceImagePath, image, errorText)) {
        return false;
    }
    return writeThumbnailImage(image, targetThumbnailPath, targetFormat, errorText);
}

bool writeSeriesHeaderBackgroundImage(
    const QImage &sourceImage,
    const QString &targetImagePath,
    const QByteArray &targetFormat,
    QString &errorText
)
{
    errorText.clear();

    constexpr int kHeaderTargetWidth = 660;
    constexpr int kHeaderTargetHeight = 220;
    constexpr int kHeaderQualityWebp = 90;
    constexpr int kHeaderQualityJpeg = 90;

    QImage working = sourceImage;
    const int srcW = working.width();
    const int srcH = working.height();
    if (srcW <= 0 || srcH <= 0) {
        errorText = QStringLiteral("Invalid source image size for series background.");
        return false;
    }

    if (srcW != kHeaderTargetWidth || srcH != kHeaderTargetHeight) {
        const double targetAspect = static_cast<double>(kHeaderTargetWidth) / static_cast<double>(kHeaderTargetHeight);
        const double srcAspect = static_cast<double>(srcW) / static_cast<double>(srcH);

        QRect cropRect(0, 0, srcW, srcH);
        if (srcAspect > targetAspect) {
            const int cropW = std::max(1, static_cast<int>(std::round(srcH * targetAspect)));
            const int offsetX = std::max(0, (srcW - cropW) / 2);
            cropRect = QRect(offsetX, 0, std::min(cropW, srcW), srcH);
        } else if (srcAspect < targetAspect) {
            const int cropH = std::max(1, static_cast<int>(std::round(srcW / targetAspect)));
            const int offsetY = std::max(0, (srcH - cropH) / 2);
            cropRect = QRect(0, offsetY, srcW, std::min(cropH, srcH));
        }

        if (cropRect.width() > 0 && cropRect.height() > 0
            && (cropRect.width() != srcW || cropRect.height() != srcH)) {
            working = working.copy(cropRect);
        }

        working = working.scaled(
            kHeaderTargetWidth,
            kHeaderTargetHeight,
            Qt::IgnoreAspectRatio,
            Qt::SmoothTransformation
        );
    }

    if (working.isNull()) {
        errorText = QStringLiteral("Failed to prepare series background image.");
        return false;
    }

    if (!ComicReaderCache::ensureDirForFile(targetImagePath)) {
        errorText = QStringLiteral("Failed to create series background cache directory.");
        return false;
    }

    QSaveFile file(targetImagePath);
    if (!file.open(QIODevice::WriteOnly)) {
        errorText = QStringLiteral("Failed to open series background file for writing.");
        return false;
    }

    {
        QImageWriter writer(&file, targetFormat);
        if (targetFormat == QByteArrayLiteral("webp")) {
            writer.setQuality(kHeaderQualityWebp);
        } else if (targetFormat == QByteArrayLiteral("jpg") || targetFormat == QByteArrayLiteral("jpeg")) {
            writer.setQuality(kHeaderQualityJpeg);
        }
        if (!writer.write(working)) {
            file.cancelWriting();
            errorText = QStringLiteral("Failed to write series background image: %1").arg(writer.errorString());
            return false;
        }
    }

    if (!file.commit()) {
        errorText = QStringLiteral("Failed to finalize series background image.");
        return false;
    }

    return true;
}

bool writeHeroBackgroundImage(
    const QImage &sourceImage,
    const QString &targetImagePath,
    const QByteArray &targetFormat,
    QString &errorText
)
{
    errorText.clear();

    QImage working = sourceImage.convertToFormat(QImage::Format_ARGB32_Premultiplied);
    const int srcW = working.width();
    const int srcH = working.height();
    if (srcW <= 0 || srcH <= 0) {
        errorText = QStringLiteral("Invalid source image size for hero background.");
        return false;
    }

    constexpr double kHeroAspect = 3.0;
    constexpr double kHeroRotationDegrees = 35.0;
    constexpr int kCropInsetSafetyPx = 2;

    const double radians = qDegreesToRadians(kHeroRotationDegrees);
    const double cosTheta = std::abs(std::cos(radians));
    const double sinTheta = std::abs(std::sin(radians));

    const double maxCropHeightByWidth = static_cast<double>(srcW) / ((kHeroAspect * cosTheta) + sinTheta);
    const double maxCropHeightByHeight = static_cast<double>(srcH) / ((kHeroAspect * sinTheta) + cosTheta);
    const int cropH = std::max(
        1,
        static_cast<int>(std::floor(std::min(maxCropHeightByWidth, maxCropHeightByHeight))) - kCropInsetSafetyPx
    );
    const int cropW = std::max(1, static_cast<int>(std::floor(static_cast<double>(cropH) * kHeroAspect)));

    QTransform transform;
    transform.rotate(kHeroRotationDegrees);
    working = working.transformed(transform, Qt::SmoothTransformation);

    if (working.width() <= 0 || working.height() <= 0) {
        errorText = QStringLiteral("Failed to rotate source image for hero background.");
        return false;
    }

    const int boundedCropW = std::min(cropW, working.width());
    const int boundedCropH = std::min(cropH, working.height());
    const QRect cropRect(
        std::max(0, (working.width() - boundedCropW) / 2),
        std::max(0, (working.height() - boundedCropH) / 2),
        boundedCropW,
        boundedCropH
    );

    if (cropRect.width() > 0 && cropRect.height() > 0) {
        working = working.copy(cropRect);
    }

    if (!ComicReaderCache::ensureDirForFile(targetImagePath)) {
        errorText = QStringLiteral("Failed to create hero background cache directory.");
        return false;
    }

    QSaveFile file(targetImagePath);
    if (!file.open(QIODevice::WriteOnly)) {
        errorText = QStringLiteral("Failed to open hero background file for writing.");
        return false;
    }

    {
        QImageWriter writer(&file, targetFormat);
        if (targetFormat == QByteArrayLiteral("webp")) {
            writer.setQuality(90);
        } else if (targetFormat == QByteArrayLiteral("jpg") || targetFormat == QByteArrayLiteral("jpeg")) {
            writer.setQuality(90);
        }
        if (!writer.write(working)) {
            file.cancelWriting();
            errorText = QStringLiteral("Failed to write hero background image: %1").arg(writer.errorString());
            return false;
        }
    }

    if (!file.commit()) {
        errorText = QStringLiteral("Failed to finalize hero background image.");
        return false;
    }

    return true;
}

bool generateHeroBackgroundImage(
    const QString &sourceImagePath,
    const QString &targetImagePath,
    const QByteArray &targetFormat,
    QString &errorText
)
{
    QImage image;
    if (!loadReadableImageFile(sourceImagePath, image, errorText)) {
        return false;
    }
    return writeHeroBackgroundImage(image, targetImagePath, targetFormat, errorText);
}

QVariantMap loadReaderPageMetricsPayload(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath,
    const QStringList &entries,
    const ArchiveExtractFn &extractArchiveEntry
)
{
    if (comicId < 1) {
        return {
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        };
    }

    if (archivePath.trimmed().isEmpty() || entries.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("Reader session is not ready.") }
        };
    }

    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(dataRoot, archivePath);
    QVariantList pageMetrics;
    pageMetrics.reserve(entries.size());
    QHash<QString, QVariantMap> bulkMetricsByEntryName;
    bool touchedReaderIssueCache = false;

    QVariantList bulkMetrics;
    QString bulkMetricsError;
    if (ComicInfoArchive::listImageEntryMetricsInArchive(archivePath, bulkMetrics, bulkMetricsError)) {
        for (const QVariant &item : bulkMetrics) {
            const QVariantMap metric = item.toMap();
            const QString entryName = metric.value(QStringLiteral("entryName")).toString().trimmed();
            if (entryName.isEmpty()) continue;
            bulkMetricsByEntryName.insert(entryName, metric);
        }
    }

    for (int pageIndex = 0; pageIndex < entries.size(); ++pageIndex) {
        const QString entryName = entries.at(pageIndex);
        const QVariantMap bulkMetric = bulkMetricsByEntryName.value(entryName);
        const int bulkWidth = bulkMetric.value(QStringLiteral("width")).toInt();
        const int bulkHeight = bulkMetric.value(QStringLiteral("height")).toInt();
        if (bulkWidth > 0 && bulkHeight > 0) {
            pageMetrics.push_back(QVariantMap {
                { QStringLiteral("pageIndex"), pageIndex },
                { QStringLiteral("entryName"), entryName },
                { QStringLiteral("width"), bulkWidth },
                { QStringLiteral("height"), bulkHeight }
            });
            continue;
        }

        QString extension = QFileInfo(entryName).suffix().toLower();
        if (extension.isEmpty()) {
            extension = QStringLiteral("img");
        }

        const QString cacheFilePath = ComicReaderCache::buildReaderCachePath(
            dataRoot,
            comicId,
            cacheStamp,
            pageIndex,
            extension
        );
        if (!ComicReaderCache::ensureDirForFile(cacheFilePath)) {
            return {
                { QStringLiteral("error"), QStringLiteral("Failed to create reader cache directory.") }
            };
        }

        const QFileInfo cachedPageInfo(cacheFilePath);
        if (cachedPageInfo.exists() && cachedPageInfo.size() <= 0) {
            QFile::remove(cacheFilePath);
        }

        if (!QFileInfo(cacheFilePath).exists()) {
            QString extractError;
            if (!extractArchiveEntry(archivePath, entryName, cacheFilePath, extractError)) {
                return {
                    { QStringLiteral("error"), extractError }
                };
            }
        }

        touchedReaderIssueCache = true;

        QImageReader reader(cacheFilePath);
        const QSize imageSize = reader.size();
        if (imageSize.width() <= 0 || imageSize.height() <= 0) {
            return {
                { QStringLiteral("error"), QStringLiteral("Failed to read page size for reader entry.") }
            };
        }

        pageMetrics.push_back(QVariantMap {
            { QStringLiteral("pageIndex"), pageIndex },
            { QStringLiteral("entryName"), entryName },
            { QStringLiteral("width"), imageSize.width() },
            { QStringLiteral("height"), imageSize.height() }
        });
    }

    if (touchedReaderIssueCache) {
        ComicReaderCache::noteReaderIssueCacheUsage(dataRoot, comicId);
        ComicReaderCache::pruneReaderCache(dataRoot);
    }

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("pageMetrics"), pageMetrics }
    };
}

} // namespace ComicImagePreparation
