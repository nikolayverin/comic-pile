#include "storage/archivepacking.h"
#include "storage/archiveprocessutils.h"
#include "storage/archivesupportutils.h"
#include "storage/comicinfoarchive.h"
#include "storage/storedpathutils.h"

#include <algorithm>

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QPainter>
#include <QSet>
#include <QStringList>
#include <QUuid>

#include <QtPdf/QPdfDocument>

namespace {

QString normalizeInputFilePath(const QString &rawInput)
{
    return ComicStoragePaths::absolutePathFromInput(rawInput);
}

int compareNaturalText(const QString &left, const QString &right)
{
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    return collator.compare(left, right);
}

bool ensureDirForFile(const QString &filePath)
{
    return QDir().mkpath(QFileInfo(filePath).absolutePath());
}

QString normalizeArchiveExtension(const QString &pathOrExtension)
{
    return ComicArchiveSupport::normalizeArchiveExtension(pathOrExtension);
}

const QSet<QString> &nativeImportArchiveExtensions()
{
    return ComicArchiveSupport::nativeImportArchiveExtensions();
}

const QSet<QString> &documentImportExtensions()
{
    return ComicArchiveSupport::documentImportExtensions();
}

QSet<QString> resolvedSevenZipArchiveExtensions()
{
    return ComicArchiveSupport::resolvedSevenZipArchiveExtensions();
}

QSet<QString> supportedImportArchiveExtensionsSet()
{
    QSet<QString> extensions = nativeImportArchiveExtensions();
    extensions.unite(documentImportExtensions());
    extensions.unite(resolvedSevenZipArchiveExtensions());
    return extensions;
}

QString formatSupportedArchiveList()
{
    QStringList tokens;
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    tokens.reserve(extensions.size());
    for (const QString &ext : extensions) {
        tokens.push_back(QStringLiteral(".%1").arg(ext));
    }
    std::sort(tokens.begin(), tokens.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
    });
    return tokens.join(QStringLiteral(", "));
}

bool isImportArchiveExtensionSupported(const QString &extension)
{
    return supportedImportArchiveExtensionsSet().contains(normalizeArchiveExtension(extension));
}

bool isSevenZipExtension(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    if (normalized.isEmpty()) return false;
    if (nativeImportArchiveExtensions().contains(normalized)) {
        return false;
    }
    if (documentImportExtensions().contains(normalized)) {
        return false;
    }
    return resolvedSevenZipArchiveExtensions().contains(normalized);
}

bool isSupportedImageEntry(const QString &entryPath)
{
    const QString extension = QStringLiteral(".%1").arg(QFileInfo(entryPath).suffix().toLower());
    return extension == QStringLiteral(".jpg")
        || extension == QStringLiteral(".jpeg")
        || extension == QStringLiteral(".png")
        || extension == QStringLiteral(".bmp")
        || extension == QStringLiteral(".webp");
}

QString normalizedRelativePathForSort(const QString &rootPath, const QString &candidatePath)
{
    const QDir rootDir(rootPath);
    return rootDir.relativeFilePath(candidatePath).replace('\\', '/').trimmed();
}

QStringList listSupportedImageFilesInFolderByRelativePath(const QString &folderPath)
{
    const QString normalizedFolderPath = normalizeInputFilePath(folderPath);
    if (normalizedFolderPath.isEmpty()) return {};

    const QFileInfo folderInfo(normalizedFolderPath);
    if (!folderInfo.exists() || !folderInfo.isDir()) return {};

    QStringList paths;
    QSet<QString> dedupe;
    QDirIterator iterator(
        folderInfo.absoluteFilePath(),
        QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::Subdirectories
    );
    while (iterator.hasNext()) {
        const QString candidate = QDir::toNativeSeparators(iterator.next());
        if (!isSupportedImageEntry(candidate)) continue;
        const QString key = normalizedRelativePathForSort(folderInfo.absoluteFilePath(), candidate).toLower();
        if (dedupe.contains(key)) continue;
        dedupe.insert(key);
        paths.push_back(candidate);
    }

    std::sort(paths.begin(), paths.end(), [normalizedFolderPath](const QString &left, const QString &right) {
        return compareNaturalText(
            normalizedRelativePathForSort(normalizedFolderPath, left),
            normalizedRelativePathForSort(normalizedFolderPath, right)
        ) < 0;
    });
    return paths;
}

QStringList listSupportedImageFilesInFolder(const QString &folderPath)
{
    const QString normalizedFolderPath = normalizeInputFilePath(folderPath);
    if (normalizedFolderPath.isEmpty()) return {};

    const QFileInfo folderInfo(normalizedFolderPath);
    if (!folderInfo.exists() || !folderInfo.isDir()) return {};

    QStringList paths;
    QSet<QString> dedupe;
    QDirIterator iterator(
        folderInfo.absoluteFilePath(),
        QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::NoIteratorFlags
    );
    while (iterator.hasNext()) {
        const QString candidate = QDir::toNativeSeparators(iterator.next());
        if (!isSupportedImageEntry(candidate)) continue;
        const QString key = candidate.toLower();
        if (dedupe.contains(key)) continue;
        dedupe.insert(key);
        paths.push_back(candidate);
    }

    std::sort(paths.begin(), paths.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(QFileInfo(left).fileName(), QFileInfo(right).fileName()) < 0;
    });
    return paths;
}

bool extractZipLikeArchiveToDirectory(
    const QString &sourceArchivePath,
    const QString &targetDirPath,
    QString &errorText
)
{
    errorText.clear();

    if (!QDir().mkpath(targetDirPath)) {
        errorText = QStringLiteral("Failed to create temporary extraction directory.");
        return false;
    }

    const QString script = QString(
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
        "Add-Type -AssemblyName System.IO.Compression\n"
        "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
        "$archivePath = [System.IO.Path]::GetFullPath('%1')\n"
        "$targetDir = [System.IO.Path]::GetFullPath('%2').TrimEnd(@([char]92, [char]47))\n"
        "try {\n"
        "  if (-not (Test-Path -LiteralPath $archivePath)) { throw 'Archive not found.' }\n"
        "  [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null\n"
        "  $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)\n"
        "  try {\n"
        "    foreach ($entry in $zip.Entries) {\n"
        "      if ([string]::IsNullOrWhiteSpace($entry.FullName)) { continue }\n"
        "      $targetPath = [System.IO.Path]::GetFullPath((Join-Path $targetDir $entry.FullName))\n"
        "      if (-not $targetPath.StartsWith($targetDir, [System.StringComparison]::OrdinalIgnoreCase)) {\n"
        "        throw 'Archive contains an unsafe entry path.'\n"
        "      }\n"
        "      if ([string]::IsNullOrEmpty($entry.Name)) {\n"
        "        [System.IO.Directory]::CreateDirectory($targetPath) | Out-Null\n"
        "        continue\n"
        "      }\n"
        "      $parent = [System.IO.Path]::GetDirectoryName($targetPath)\n"
        "      if (-not [string]::IsNullOrWhiteSpace($parent)) {\n"
        "        [System.IO.Directory]::CreateDirectory($parent) | Out-Null\n"
        "      }\n"
        "      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)\n"
        "    }\n"
        "  } finally {\n"
        "    $zip.Dispose()\n"
        "  }\n"
        "} catch {\n"
        "  [Console]::Error.WriteLine($_.Exception.Message)\n"
        "  exit 2\n"
        "}\n"
    ).arg(
        ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(sourceArchivePath)),
        ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(targetDirPath))
    );

    QString stdOut;
    QString stdErr;
    return ComicArchiveProcess::runPowerShellScript(
        script,
        stdOut,
        stdErr,
        errorText,
        120000,
        QStringLiteral("Archive extraction")
    );
}

bool stageExtractedArchiveForCbz(
    const QString &extractRootPath,
    const QString &stagePagesPath,
    QString &errorText
)
{
    errorText.clear();

    const QStringList imagePaths = listSupportedImageFilesInFolderByRelativePath(extractRootPath);
    if (imagePaths.isEmpty()) {
        errorText = QStringLiteral("No image pages found in archive.");
        return false;
    }

    if (!QDir().mkpath(stagePagesPath)) {
        errorText = QStringLiteral("Failed to create temporary staging directory for archive normalization.");
        return false;
    }

    int index = 1;
    for (const QString &imagePath : imagePaths) {
        const QFileInfo imageInfo(imagePath);
        const QString extension = imageInfo.suffix().trimmed().toLower();
        QString stagedName = QStringLiteral("%1").arg(index, 6, 10, QLatin1Char('0'));
        if (!extension.isEmpty()) {
            stagedName += QStringLiteral(".%1").arg(extension);
        }

        const QString stagedPath = QDir(stagePagesPath).filePath(stagedName);
        if (!QFile::rename(imageInfo.absoluteFilePath(), stagedPath)) {
            if (!QFile::copy(imageInfo.absoluteFilePath(), stagedPath)) {
                errorText = QStringLiteral("Failed to stage extracted page: %1")
                    .arg(QDir::toNativeSeparators(imageInfo.absoluteFilePath()));
                return false;
            }
            QFile::remove(imageInfo.absoluteFilePath());
        }
        index += 1;
    }

    const QString comicInfoPath = QDir(extractRootPath).filePath(QStringLiteral("ComicInfo.xml"));
    if (QFileInfo::exists(comicInfoPath) && QFileInfo(comicInfoPath).isFile()) {
        const QString stagedComicInfoPath = QDir(stagePagesPath).filePath(QStringLiteral("ComicInfo.xml"));
        QFile::remove(stagedComicInfoPath);
        if (!QFile::copy(comicInfoPath, stagedComicInfoPath)) {
            errorText = QStringLiteral("Failed to stage ComicInfo.xml from extracted archive.");
            return false;
        }
    }

    return true;
}

bool isPdfExtension(const QString &extension)
{
    return normalizeArchiveExtension(extension) == QStringLiteral("pdf");
}

bool isDjvuExtension(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    return normalized == QStringLiteral("djvu") || normalized == QStringLiteral("djv");
}

constexpr int kTargetImportedPageWidth = 1600;
constexpr int kTargetImportedPageHeight = 2112;

QSize renderPixelSizeFromPointSize(const QSizeF &pointSize)
{
    // Keep imported document pages close to the current library's average comic page size.
    const qreal widthPoints = pointSize.width();
    const qreal heightPoints = pointSize.height();
    if (widthPoints <= 0.0 || heightPoints <= 0.0) {
        return QSize(kTargetImportedPageWidth, kTargetImportedPageHeight);
    }

    const qreal scale = std::min(
        static_cast<qreal>(kTargetImportedPageWidth) / widthPoints,
        static_cast<qreal>(kTargetImportedPageHeight) / heightPoints
    );
    const int width = std::max(1, qRound(widthPoints * scale));
    const int height = std::max(1, qRound(heightPoints * scale));
    return QSize(width, height);
}

bool saveImageAsJpeg(const QImage &sourceImage, const QString &outputPath, QString &errorText)
{
    errorText.clear();

    if (sourceImage.isNull()) {
        errorText = QStringLiteral("Rendered page image is empty.");
        return false;
    }
    if (!ensureDirForFile(outputPath)) {
        errorText = QStringLiteral("Failed to create page output directory.");
        return false;
    }

    QImage image = sourceImage;
    if (image.hasAlphaChannel()) {
        QImage flattened(image.size(), QImage::Format_RGB32);
        flattened.fill(Qt::white);
        QPainter painter(&flattened);
        painter.drawImage(QPoint(0, 0), image);
        painter.end();
        image = flattened;
    } else if (image.format() != QImage::Format_RGB32 && image.format() != QImage::Format_RGB888) {
        image = image.convertToFormat(QImage::Format_RGB32);
    }

    if (!image.save(outputPath, "JPEG", 92)) {
        errorText = QStringLiteral("Failed to save rendered page image.");
        return false;
    }

    const QFileInfo info(outputPath);
    if (!info.exists() || info.size() <= 0) {
        errorText = QStringLiteral("Rendered page image was not created.");
        return false;
    }
    return true;
}

bool convertPdfToCbz(
    const QString &sourcePdfPath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    errorText.clear();

    QPdfDocument document;
    const QPdfDocument::Error loadError = document.load(sourcePdfPath);
    if (loadError != QPdfDocument::Error::None || document.status() != QPdfDocument::Status::Ready) {
        errorText = QStringLiteral("Failed to open PDF file.");
        return false;
    }

    const int pageCount = document.pageCount();
    if (pageCount < 1) {
        errorText = QStringLiteral("No pages found in PDF file.");
        return false;
    }

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-pdf-stage-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    const QString stagePagesPath = QDir(tempRootPath).filePath(QStringLiteral("pages"));
    if (!QDir().mkpath(stagePagesPath)) {
        errorText = QStringLiteral("Failed to create temporary directory for PDF import.");
        return false;
    }

    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    for (int pageIndex = 0; pageIndex < pageCount; ++pageIndex) {
        const QSize imageSize = renderPixelSizeFromPointSize(document.pagePointSize(pageIndex));
        const QImage rendered = document.render(pageIndex, imageSize);
        if (rendered.isNull()) {
            cleanupTemp();
            errorText = QStringLiteral("Failed to render PDF page %1.").arg(pageIndex + 1);
            return false;
        }

        const QString stagedPath = QDir(stagePagesPath).filePath(
            QStringLiteral("%1.jpg").arg(pageIndex + 1, 6, 10, QLatin1Char('0'))
        );
        QString saveError;
        if (!saveImageAsJpeg(rendered, stagedPath, saveError)) {
            cleanupTemp();
            errorText = QStringLiteral("Failed to save PDF page %1. %2").arg(pageIndex + 1).arg(saveError);
            return false;
        }
    }

    const bool ok = ComicArchivePacking::createCbzFromDirectory(stagePagesPath, targetCbzPath, errorText);
    cleanupTemp();
    return ok;
}

bool convertDjvuToCbz(
    const QString &sourceDjvuPath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    errorText.clear();

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-djvu-stage-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    const QString rawPagesPath = QDir(tempRootPath).filePath(QStringLiteral("raw"));
    const QString finalPagesPath = QDir(tempRootPath).filePath(QStringLiteral("pages"));
    if (!QDir().mkpath(rawPagesPath) || !QDir().mkpath(finalPagesPath)) {
        errorText = QStringLiteral("Failed to create temporary directory for DJVU import.");
        return false;
    }

    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    QByteArray stdOutBytes;
    QByteArray stdErrBytes;
    const QString outputPattern = QDir(rawPagesPath).filePath(QStringLiteral("page%06d.ppm"));
    if (!ComicArchiveSupport::runDjVuProcess(
            {
                QStringLiteral("-format=ppm"),
                QStringLiteral("-size=%1x%2").arg(kTargetImportedPageWidth).arg(kTargetImportedPageHeight),
                QStringLiteral("-eachpage"),
                QDir::toNativeSeparators(sourceDjvuPath),
                QDir::toNativeSeparators(outputPattern)
            },
            stdOutBytes,
            stdErrBytes,
            errorText,
            600000,
            true,
            QStringLiteral("DJVU page rendering")
        )) {
        cleanupTemp();
        return false;
    }

    QStringList rawPages;
    QDirIterator iterator(
        rawPagesPath,
        QStringList{ QStringLiteral("*.ppm") },
        QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::NoIteratorFlags
    );
    while (iterator.hasNext()) {
        rawPages.push_back(QDir::toNativeSeparators(iterator.next()));
    }
    std::sort(rawPages.begin(), rawPages.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(QFileInfo(left).fileName(), QFileInfo(right).fileName()) < 0;
    });
    if (rawPages.isEmpty()) {
        cleanupTemp();
        errorText = QStringLiteral("No pages were rendered from the DJVU file.");
        return false;
    }

    int pageNumber = 1;
    for (const QString &rawPagePath : rawPages) {
        const QImage rawImage(rawPagePath);
        if (rawImage.isNull()) {
            cleanupTemp();
            errorText = QStringLiteral("Failed to decode rendered DJVU page %1.").arg(pageNumber);
            return false;
        }

        const QString stagedPath = QDir(finalPagesPath).filePath(
            QStringLiteral("%1.jpg").arg(pageNumber, 6, 10, QLatin1Char('0'))
        );
        QString saveError;
        if (!saveImageAsJpeg(rawImage, stagedPath, saveError)) {
            cleanupTemp();
            errorText = QStringLiteral("Failed to save DJVU page %1. %2").arg(pageNumber).arg(saveError);
            return false;
        }
        ++pageNumber;
    }

    const bool ok = ComicArchivePacking::createCbzFromDirectory(finalPagesPath, targetCbzPath, errorText);
    cleanupTemp();
    return ok;
}

bool convertArchiveVia7ZipToCbz(
    const QString &sourceArchivePath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    errorText.clear();

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-normalize-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    const QString extractPath = QDir(tempRootPath).filePath(QStringLiteral("extract"));
    if (!QDir().mkpath(extractPath)) {
        errorText = QStringLiteral("Failed to create temporary directory for archive conversion.");
        return false;
    }

    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    QByteArray stdOutBytes;
    QByteArray stdErrBytes;
    if (!ComicArchiveSupport::runSevenZipProcess(
            {
                QStringLiteral("x"),
                QStringLiteral("-y"),
                QStringLiteral("-aoa"),
                QStringLiteral("-bb0"),
                QStringLiteral("-scsUTF-8"),
                QStringLiteral("-o%1").arg(QDir::toNativeSeparators(extractPath)),
                QStringLiteral("--"),
                QDir::toNativeSeparators(sourceArchivePath)
            },
            stdOutBytes,
            stdErrBytes,
            errorText,
            120000,
            true,
            QStringLiteral("7-Zip archive extraction")
        )) {
        cleanupTemp();
        return false;
    }
    if (!ComicArchivePacking::createCbzFromDirectory(extractPath, targetCbzPath, errorText)) {
        cleanupTemp();
        return false;
    }

    cleanupTemp();
    return true;
}

} // namespace

namespace ComicArchivePacking {

bool normalizeArchiveToCbz(
    const QString &sourceArchivePath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    errorText.clear();

    const QFileInfo sourceInfo(sourceArchivePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        errorText = QStringLiteral("Import file not found: %1").arg(sourceArchivePath);
        return false;
    }

    const QString sourceExt = normalizeArchiveExtension(sourceInfo.suffix());
    if (!isImportArchiveExtensionSupported(sourceExt)) {
        errorText = QStringLiteral("Supported import formats: %1").arg(formatSupportedArchiveList());
        return false;
    }

    const QFileInfo targetInfo(targetCbzPath);
    if (targetInfo.suffix().toLower() != QStringLiteral("cbz")) {
        errorText = QStringLiteral("Normalized archive target must use .cbz extension.");
        return false;
    }

    if (!ensureDirForFile(targetCbzPath)) {
        errorText = QStringLiteral("Failed to create target directory for archive normalization.");
        return false;
    }

    if (isPdfExtension(sourceExt)) {
        return convertPdfToCbz(sourceInfo.absoluteFilePath(), targetCbzPath, errorText);
    }

    if (isDjvuExtension(sourceExt)) {
        return convertDjvuToCbz(sourceInfo.absoluteFilePath(), targetCbzPath, errorText);
    }

    QFile::remove(targetCbzPath);

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-archive-stage-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    const QString extractPath = QDir(tempRootPath).filePath(QStringLiteral("extract"));
    const QString stagePagesPath = QDir(tempRootPath).filePath(QStringLiteral("pages"));
    if (!QDir().mkpath(extractPath) || !QDir().mkpath(stagePagesPath)) {
        errorText = QStringLiteral("Failed to create temporary directory for archive normalization.");
        return false;
    }

    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    if (sourceExt == QStringLiteral("cbz") || sourceExt == QStringLiteral("zip")) {
        if (!extractZipLikeArchiveToDirectory(sourceArchivePath, extractPath, errorText)) {
            cleanupTemp();
            return false;
        }
        if (!stageExtractedArchiveForCbz(extractPath, stagePagesPath, errorText)) {
            cleanupTemp();
            return false;
        }
        if (!ComicArchivePacking::createCbzFromDirectory(stagePagesPath, targetCbzPath, errorText)) {
            cleanupTemp();
            return false;
        }
        cleanupTemp();
        return true;
    }

    QStringList imageEntries;
    if (!ComicInfoArchive::listImageEntriesInArchive(sourceArchivePath, imageEntries, errorText)) {
        cleanupTemp();
        return false;
    }

    int index = 1;
    for (const QString &entryName : imageEntries) {
        const QString extension = QFileInfo(entryName).suffix().trimmed().toLower();
        QString stagedName = QStringLiteral("%1").arg(index, 6, 10, QLatin1Char('0'));
        if (!extension.isEmpty()) {
            stagedName += QStringLiteral(".%1").arg(extension);
        }

        const QString stagedPath = QDir(stagePagesPath).filePath(stagedName);
        QString extractError;
        if (!ComicInfoArchive::extractArchiveEntryToFile(sourceArchivePath, entryName, stagedPath, extractError)) {
            cleanupTemp();
            errorText = extractError;
            return false;
        }
        index += 1;
    }

    if (!ComicArchivePacking::createCbzFromDirectory(stagePagesPath, targetCbzPath, errorText)) {
        cleanupTemp();
        return false;
    }

    cleanupTemp();
    return true;
}

bool createCbzFromDirectory(
    const QString &sourceDirPath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    errorText.clear();

    const QString normalizedSourceDirPath = normalizeInputFilePath(sourceDirPath);
    if (normalizedSourceDirPath.isEmpty()) {
        errorText = QStringLiteral("Source folder path is required.");
        return false;
    }

    const QFileInfo sourceInfo(normalizedSourceDirPath);
    if (!sourceInfo.exists() || !sourceInfo.isDir()) {
        errorText = QStringLiteral("Source folder not found: %1").arg(sourceDirPath);
        return false;
    }

    const QFileInfo targetInfo(targetCbzPath);
    if (targetInfo.suffix().toLower() != QStringLiteral("cbz")) {
        errorText = QStringLiteral("Normalized archive target must use .cbz extension.");
        return false;
    }

    if (!ensureDirForFile(targetCbzPath)) {
        errorText = QStringLiteral("Failed to create target directory for archive packaging.");
        return false;
    }

    QFile::remove(targetCbzPath);

    const QString script = QString(
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
        "Add-Type -AssemblyName System.IO.Compression\n"
        "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
        "$sourceDir = [System.IO.Path]::GetFullPath('%1').TrimEnd(@([char]92, [char]47))\n"
        "$targetPath = '%2'\n"
        "try {\n"
        "  if (-not (Test-Path -LiteralPath $sourceDir)) { throw 'Source folder not found.' }\n"
        "  if (Test-Path -LiteralPath $targetPath) { Remove-Item -LiteralPath $targetPath -Force }\n"
        "  $parent = [System.IO.Path]::GetDirectoryName($targetPath)\n"
        "  if (-not [string]::IsNullOrWhiteSpace($parent)) {\n"
        "    [System.IO.Directory]::CreateDirectory($parent) | Out-Null\n"
        "  }\n"
        "  $fs = [System.IO.File]::Open($targetPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)\n"
        "  try {\n"
        "    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create, $false)\n"
        "    try {\n"
        "      $files = Get-ChildItem -LiteralPath $sourceDir -Recurse -File | Sort-Object FullName\n"
        "      foreach ($file in $files) {\n"
        "        $fullPath = [System.IO.Path]::GetFullPath($file.FullName)\n"
        "        if ($fullPath.Length -le $sourceDir.Length) { continue }\n"
        "        $entryName = $fullPath.Substring($sourceDir.Length)\n"
        "        $entryName = $entryName.TrimStart(@([char]92, [char]47))\n"
        "        if ([string]::IsNullOrWhiteSpace($entryName)) { continue }\n"
        "        $entryName = $entryName -replace '\\\\', '/'\n"
        "        $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)\n"
        "        $inStream = [System.IO.File]::OpenRead($file.FullName)\n"
        "        try {\n"
        "          $outStream = $entry.Open()\n"
        "          try { $inStream.CopyTo($outStream) } finally { $outStream.Dispose() }\n"
        "        } finally {\n"
        "          $inStream.Dispose()\n"
        "        }\n"
        "      }\n"
        "    } finally {\n"
        "      $zip.Dispose()\n"
        "    }\n"
        "  } finally {\n"
        "    $fs.Dispose()\n"
        "  }\n"
        "} catch {\n"
        "  [Console]::Error.WriteLine($_.Exception.Message)\n"
        "  exit 2\n"
        "}\n"
    ).arg(
        ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(sourceInfo.absoluteFilePath())),
        ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(targetCbzPath))
    );

    QString stdOut;
    QString stdErr;
    if (!ComicArchiveProcess::runPowerShellScript(
            script,
            stdOut,
            stdErr,
            errorText,
            120000,
            QStringLiteral("Archive packaging")
        )) {
        return false;
    }

    const QFileInfo finalTargetInfo(targetCbzPath);
    if (!finalTargetInfo.exists() || !finalTargetInfo.isFile() || finalTargetInfo.size() <= 0) {
        errorText = QStringLiteral("Archive conversion produced an invalid .cbz archive.");
        return false;
    }

    return true;
}

bool packageImageFolderToCbz(
    const QString &folderPath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    errorText.clear();

    const QString normalizedFolderPath = normalizeInputFilePath(folderPath);
    if (normalizedFolderPath.isEmpty()) {
        errorText = QStringLiteral("Image folder path is required.");
        return false;
    }

    const QFileInfo folderInfo(normalizedFolderPath);
    if (!folderInfo.exists() || !folderInfo.isDir()) {
        errorText = QStringLiteral("Image folder not found: %1").arg(folderPath);
        return false;
    }

    const QStringList imagePaths = listSupportedImageFilesInFolder(normalizedFolderPath);
    if (imagePaths.isEmpty()) {
        errorText = QStringLiteral("No supported image files found in folder: %1")
            .arg(QDir::toNativeSeparators(folderInfo.absoluteFilePath()));
        return false;
    }

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-image-stage-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    const QString stagePagesPath = QDir(tempRootPath).filePath(QStringLiteral("pages"));
    if (!QDir().mkpath(stagePagesPath)) {
        errorText = QStringLiteral("Failed to create temporary directory for image folder packaging.");
        return false;
    }

    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    int index = 1;
    for (const QString &imagePath : imagePaths) {
        const QFileInfo imageInfo(imagePath);
        const QString extension = imageInfo.suffix().trimmed().toLower();
        QString stagedName = QStringLiteral("%1").arg(index, 6, 10, QLatin1Char('0'));
        if (!extension.isEmpty()) {
            stagedName += QStringLiteral(".%1").arg(extension);
        }

        const QString stagedPath = QDir(stagePagesPath).filePath(stagedName);
        if (!QFile::copy(imageInfo.absoluteFilePath(), stagedPath)) {
            cleanupTemp();
            errorText = QStringLiteral("Failed to copy image page into temporary package: %1")
                .arg(QDir::toNativeSeparators(imageInfo.absoluteFilePath()));
            return false;
        }
        index += 1;
    }

    const bool ok = createCbzFromDirectory(stagePagesPath, targetCbzPath, errorText);
    cleanupTemp();
    return ok;
}

bool deletePageFromArchive(
    const QString &archivePath,
    int pageIndex,
    int &remainingPageCount,
    QString &errorText
)
{
    errorText.clear();
    remainingPageCount = 0;

    const QString normalizedArchivePath = normalizeInputFilePath(archivePath);
    if (normalizedArchivePath.isEmpty()) {
        errorText = QStringLiteral("Archive path is required.");
        return false;
    }

    const QFileInfo archiveInfo(normalizedArchivePath);
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        errorText = QStringLiteral("Archive not found: %1").arg(archivePath);
        return false;
    }

    const QString extension = archiveInfo.suffix().trimmed().toLower();
    if (extension != QStringLiteral("cbz") && extension != QStringLiteral("zip")) {
        errorText = QStringLiteral("Page deletion is only supported for .cbz and .zip archives.");
        return false;
    }

    QStringList imageEntries;
    if (!ComicInfoArchive::listImageEntriesInArchive(normalizedArchivePath, imageEntries, errorText)) {
        return false;
    }

    if (imageEntries.size() < 2) {
        errorText = QStringLiteral("Cannot delete the only page from the archive.");
        return false;
    }
    if (pageIndex < 0 || pageIndex >= imageEntries.size()) {
        errorText = QStringLiteral("Page index is out of range.");
        return false;
    }

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-page-delete-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    const QString extractPath = QDir(tempRootPath).filePath(QStringLiteral("extract"));
    const QString stagePagesPath = QDir(tempRootPath).filePath(QStringLiteral("pages"));
    const QString rebuiltArchivePath = QDir(tempRootPath).filePath(QStringLiteral("rebuilt.cbz"));
    if (!QDir().mkpath(extractPath) || !QDir().mkpath(stagePagesPath)) {
        errorText = QStringLiteral("Failed to create temporary directory for page deletion.");
        return false;
    }

    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    if (!extractZipLikeArchiveToDirectory(normalizedArchivePath, extractPath, errorText)) {
        cleanupTemp();
        return false;
    }

    const QString entryToDelete = imageEntries.at(pageIndex);
    const QString extractedEntryPath = QDir(extractPath).filePath(entryToDelete);
    const QFileInfo extractedInfo(extractedEntryPath);
    if (!extractedInfo.exists() || !extractedInfo.isFile()) {
        cleanupTemp();
        errorText = QStringLiteral("Selected page was not found after archive extraction.");
        return false;
    }

    if (!QFile::remove(extractedInfo.absoluteFilePath())) {
        cleanupTemp();
        errorText = QStringLiteral("Failed to remove the selected page from the extracted archive.");
        return false;
    }

    if (!stageExtractedArchiveForCbz(extractPath, stagePagesPath, errorText)) {
        cleanupTemp();
        return false;
    }

    if (!ComicArchivePacking::createCbzFromDirectory(stagePagesPath, rebuiltArchivePath, errorText)) {
        cleanupTemp();
        return false;
    }

    remainingPageCount = imageEntries.size() - 1;
    if (remainingPageCount < 1) {
        cleanupTemp();
        errorText = QStringLiteral("Cannot delete the only page from the archive.");
        return false;
    }

    const QString backupPath = archiveInfo.absolutePath().isEmpty()
        ? normalizedArchivePath + QStringLiteral(".comicpile-backup")
        : QDir(archiveInfo.absolutePath()).filePath(
            archiveInfo.fileName() + QStringLiteral(".comicpile-backup")
        );
    QFile::remove(backupPath);

    if (!QFile::rename(normalizedArchivePath, backupPath)) {
        cleanupTemp();
        errorText = QStringLiteral("Failed to prepare the original archive for replacement.");
        return false;
    }

    if (!QFile::rename(rebuiltArchivePath, normalizedArchivePath)) {
        QFile::rename(backupPath, normalizedArchivePath);
        cleanupTemp();
        errorText = QStringLiteral("Failed to replace the archive after page deletion.");
        return false;
    }

    QFile::remove(backupPath);
    cleanupTemp();
    return true;
}

} // namespace ComicArchivePacking
