#pragma once

#include <functional>

#include <QByteArray>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class QImage;

namespace ComicImagePreparation {

using ArchiveExtractFn = std::function<bool(
    const QString &archivePath,
    const QString &entryName,
    const QString &outputFilePath,
    QString &errorText
)>;

bool loadReadableImageFile(const QString &filePath, QImage &imageOut, QString &errorText);

bool writeThumbnailImage(
    const QImage &sourceImage,
    const QString &targetThumbnailPath,
    const QByteArray &targetFormat,
    QString &errorText
);

bool generateThumbnailImage(
    const QString &sourceImagePath,
    const QString &targetThumbnailPath,
    const QByteArray &targetFormat,
    QString &errorText
);

bool writeSeriesHeaderBackgroundImage(
    const QImage &sourceImage,
    const QString &targetImagePath,
    const QByteArray &targetFormat,
    QString &errorText
);

bool writeHeroBackgroundImage(
    const QImage &sourceImage,
    const QString &targetImagePath,
    const QByteArray &targetFormat,
    QString &errorText
);

bool generateHeroBackgroundImage(
    const QString &sourceImagePath,
    const QString &targetImagePath,
    const QByteArray &targetFormat,
    QString &errorText
);

QVariantMap loadReaderPageMetricsPayload(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath,
    const QStringList &entries,
    const ArchiveExtractFn &extractArchiveEntry
);

} // namespace ComicImagePreparation
