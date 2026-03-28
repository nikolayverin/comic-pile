#include "storage/comicinfoarchive.h"
#include "storage/archiveprocessutils.h"
#include "storage/storedpathutils.h"

#include <algorithm>

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QVector>
#include <QUuid>

namespace {

QString normalizeInputFilePath(const QString &rawInput)
{
    return ComicStoragePaths::absolutePathFromInput(rawInput);
}

QString normalizeReadStatus(const QString &value)
{
    QString normalized = value.trimmed().toLower();
    if (normalized.isEmpty()) return QStringLiteral("unread");

    normalized.replace(QLatin1Char('-'), QLatin1Char('_'));
    normalized.replace(QLatin1Char(' '), QLatin1Char('_'));
    if (normalized == QStringLiteral("inprogress")) normalized = QStringLiteral("in_progress");

    if (normalized == QStringLiteral("unread")
        || normalized == QStringLiteral("in_progress")
        || normalized == QStringLiteral("read")) {
        return normalized;
    }

    return {};
}

int parseOptionalBoundedInt(const QString &input, int minValue, int maxValue, bool &ok, bool &isNull)
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty()) {
        ok = true;
        isNull = true;
        return 0;
    }

    const int value = trimmed.toInt(&ok);
    if (!ok || value < minValue || value > maxValue) {
        ok = false;
        isNull = false;
        return 0;
    }

    isNull = false;
    return value;
}

QString escapeXml(const QString &value)
{
    QString escaped = value;
    escaped.replace(QLatin1Char('&'), QStringLiteral("&amp;"));
    escaped.replace(QLatin1Char('<'), QStringLiteral("&lt;"));
    escaped.replace(QLatin1Char('>'), QStringLiteral("&gt;"));
    escaped.replace(QLatin1Char('"'), QStringLiteral("&quot;"));
    escaped.replace(QLatin1Char('\''), QStringLiteral("&apos;"));
    return escaped;
}

QString resolve7ZipExecutableFromHint(const QString &hintPath)
{
    const QString existingFilePath = ComicStoragePaths::absoluteExistingFilePath(hintPath);
    if (!existingFilePath.isEmpty()) {
        return existingFilePath;
    }

    const QString existingDirPath = ComicStoragePaths::absoluteExistingDirPath(hintPath);
    if (!existingDirPath.isEmpty()) {
        static const QStringList executableNames = {
            QStringLiteral("7z.exe"),
            QStringLiteral("7z"),
            QStringLiteral("7za.exe"),
            QStringLiteral("7za")
        };
        for (const QString &name : executableNames) {
            const QFileInfo nested(QDir(existingDirPath).filePath(name));
            if (nested.exists() && nested.isFile()) {
                return QDir::toNativeSeparators(nested.absoluteFilePath());
            }
        }
    }
    return {};
}

QString resolve7ZipExecutable()
{
    const QStringList envCandidates = {
        QStringLiteral("COMIC_PILE_7ZIP_PATH"),
        QStringLiteral("SEVENZIP_PATH")
    };
    for (const QString &envKey : envCandidates) {
        const QString resolved = resolve7ZipExecutableFromHint(qEnvironmentVariable(envKey.toUtf8().constData()));
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    const QStringList bundledCandidates = {
        QDir(appDir).filePath(QStringLiteral("7z.exe")),
        QDir(appDir).filePath(QStringLiteral("7za.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/7zip/7z.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/7zip/7za.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/7zip/7z.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/7zip/7za.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/7zip/7z.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/7zip/7za.exe")),
        QDir(currentDir).filePath(QStringLiteral("7z.exe")),
        QDir(currentDir).filePath(QStringLiteral("7za.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/7zip/7z.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/7zip/7za.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/7zip/7z.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/7zip/7za.exe"))
    };
    for (const QString &candidate : bundledCandidates) {
        const QString resolved = resolve7ZipExecutableFromHint(candidate);
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    const QStringList programCandidates = {
        QStringLiteral("7z.exe"),
        QStringLiteral("7z"),
        QStringLiteral("7za.exe"),
        QStringLiteral("7za")
    };
    for (const QString &candidate : programCandidates) {
        const QString found = QStandardPaths::findExecutable(candidate);
        if (!found.isEmpty()) {
            return QDir::toNativeSeparators(found);
        }
    }

    const QStringList absoluteCandidates = {
        QStringLiteral("C:/Program Files/7-Zip/7z.exe"),
        QStringLiteral("C:/Program Files (x86)/7-Zip/7z.exe")
    };
    for (const QString &candidate : absoluteCandidates) {
        const QString resolved = ComicStoragePaths::absoluteExistingFilePath(candidate);
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    return {};
}

QString sevenZipMissingMessage()
{
    return QStringLiteral("Archive support component (7z) is missing. Reinstall/repair Comic Pile or set a custom 7z path.");
}

int compareText(const QString &left, const QString &right)
{
    return QString::localeAwareCompare(left, right);
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

bool usesSevenZipArchiveBackend(const QString &extension)
{
    const QString normalized = extension.trimmed().toLower();
    return !normalized.isEmpty()
        && normalized != QStringLiteral("cbz")
        && normalized != QStringLiteral("zip");
}

} // namespace

namespace ComicInfoArchive {

bool readComicInfoXmlFromArchive(
    const QString &archivePath,
    QString &xmlOut,
    QString &errorText
)
{
    xmlOut.clear();
    errorText.clear();

    const QFileInfo archiveInfo(archivePath);
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        errorText = QStringLiteral("Archive not found: %1").arg(archivePath);
        return false;
    }

    const QString extension = archiveInfo.suffix().toLower();
    if (extension != QStringLiteral("cbz") && extension != QStringLiteral("zip")) {
        errorText = QStringLiteral("Unsupported archive format for ComicInfo.xml: .%1").arg(extension);
        return false;
    }

    const QString script = QString(
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
        "Add-Type -AssemblyName System.IO.Compression\n"
        "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
        "$archivePath = '%1'\n"
        "try {\n"
        "  $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)\n"
        "  try {\n"
        "    $entry = $null\n"
        "    foreach ($item in $zip.Entries) {\n"
        "      if ($item.FullName -ieq 'ComicInfo.xml') { $entry = $item; break }\n"
        "    }\n"
        "    if ($null -eq $entry) { exit 4 }\n"
        "    $stream = $entry.Open()\n"
        "    try {\n"
        "      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)\n"
        "      try {\n"
        "        [Console]::Write($reader.ReadToEnd())\n"
        "      } finally {\n"
        "        $reader.Dispose()\n"
        "      }\n"
        "    } finally {\n"
        "      $stream.Dispose()\n"
        "    }\n"
        "  } finally {\n"
        "    $zip.Dispose()\n"
        "  }\n"
        "} catch {\n"
        "  [Console]::Error.WriteLine($_.Exception.Message)\n"
        "  exit 2\n"
        "}\n"
    ).arg(ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(archivePath)));

    QString stdOut;
    QString stdErr;
    if (!ComicArchiveProcess::runPowerShellScript(script, stdOut, stdErr, errorText)) {
        if (errorText.contains(QStringLiteral("code 4"), Qt::CaseInsensitive)) {
            errorText = QStringLiteral("ComicInfo.xml not found in archive.");
        }
        return false;
    }

    xmlOut = stdOut;
    return true;
}

bool writeComicInfoXmlToArchive(
    const QString &archivePath,
    const QString &xml,
    QString &errorText
)
{
    errorText.clear();

    const QFileInfo archiveInfo(archivePath);
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        errorText = QStringLiteral("Archive not found: %1").arg(archivePath);
        return false;
    }

    const QString extension = archiveInfo.suffix().toLower();
    if (extension != QStringLiteral("cbz") && extension != QStringLiteral("zip")) {
        errorText = QStringLiteral("Unsupported archive format for ComicInfo.xml: .%1").arg(extension);
        return false;
    }

    const QString xmlBase64 = QString::fromLatin1(xml.toUtf8().toBase64());
    const QString script = QString(
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
        "Add-Type -AssemblyName System.IO.Compression\n"
        "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
        "$archivePath = '%1'\n"
        "$xmlBase64 = '%2'\n"
        "try {\n"
        "  $xml = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($xmlBase64))\n"
        "  $fs = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)\n"
        "  try {\n"
        "    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Update, $false)\n"
        "    try {\n"
        "      $toDelete = @()\n"
        "      foreach ($entry in $zip.Entries) {\n"
        "        if ($entry.FullName -ieq 'ComicInfo.xml') { $toDelete += $entry }\n"
        "      }\n"
        "      foreach ($entry in $toDelete) { $entry.Delete() }\n"
        "      $newEntry = $zip.CreateEntry('ComicInfo.xml', [System.IO.Compression.CompressionLevel]::Optimal)\n"
        "      $stream = $newEntry.Open()\n"
        "      try {\n"
        "        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)))\n"
        "        try {\n"
        "          $writer.Write($xml)\n"
        "        } finally {\n"
        "          $writer.Dispose()\n"
        "        }\n"
        "      } finally {\n"
        "        $stream.Dispose()\n"
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
        ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(archivePath)),
        ComicArchiveProcess::quotePowerShellLiteral(xmlBase64)
    );

    QString stdOut;
    QString stdErr;
    return ComicArchiveProcess::runPowerShellScript(script, stdOut, stdErr, errorText);
}

bool listImageEntriesInArchive(
    const QString &archivePath,
    QStringList &entriesOut,
    QString &errorText
)
{
    entriesOut.clear();
    errorText.clear();

    const QFileInfo archiveInfo(archivePath);
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        errorText = QStringLiteral("Archive not found: %1").arg(archivePath);
        return false;
    }

    const QString extension = archiveInfo.suffix().toLower();
    if (extension == QStringLiteral("cbz") || extension == QStringLiteral("zip")) {
        const QString script = QString(
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
            "Add-Type -AssemblyName System.IO.Compression\n"
            "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
            "$archivePath = '%1'\n"
            "$exts = @('.jpg','.jpeg','.png','.bmp','.webp')\n"
            "try {\n"
            "  $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)\n"
            "  try {\n"
            "    $items = @()\n"
            "    foreach ($entry in $zip.Entries) {\n"
            "      if ([string]::IsNullOrEmpty($entry.Name)) { continue }\n"
            "      $entryExt = [System.IO.Path]::GetExtension($entry.FullName).ToLowerInvariant()\n"
            "      if ($exts -contains $entryExt) { $items += $entry.FullName }\n"
            "    }\n"
            "    $items = $items | Sort-Object\n"
            "    foreach ($item in $items) { [Console]::WriteLine($item) }\n"
            "  } finally {\n"
            "    $zip.Dispose()\n"
            "  }\n"
            "} catch {\n"
            "  [Console]::Error.WriteLine($_.Exception.Message)\n"
            "  exit 2\n"
            "}\n"
        ).arg(ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(archivePath)));

        QString stdOut;
        QString stdErr;
        if (!ComicArchiveProcess::runPowerShellScript(script, stdOut, stdErr, errorText)) {
            return false;
        }

        entriesOut = stdOut.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
        return true;
    }

    if (usesSevenZipArchiveBackend(extension)) {
        const QString sevenZip = resolve7ZipExecutable();
        if (sevenZip.isEmpty()) {
            errorText = sevenZipMissingMessage();
            return false;
        }

        QByteArray stdOutBytes;
        QByteArray stdErrBytes;
        if (!ComicArchiveProcess::runExternalProcess(
                sevenZip,
                {
                    QStringLiteral("l"),
                    QStringLiteral("-slt"),
                    QStringLiteral("-ba"),
                    QStringLiteral("-scsUTF-8"),
                    QStringLiteral("--"),
                    QDir::toNativeSeparators(archivePath)
                },
                stdOutBytes,
                stdErrBytes,
                errorText,
                120000,
                true
            )) {
            return false;
        }

        const QString output = QString::fromUtf8(stdOutBytes);
        QString currentPath;
        bool currentIsFolder = false;

        auto flushCurrent = [&]() {
            const QString candidate = currentPath.trimmed();
            if (candidate.isEmpty()) return;
            if (currentIsFolder) return;
            if (!isSupportedImageEntry(candidate)) return;
            entriesOut.push_back(candidate);
        };

        const QStringList lines = output.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::KeepEmptyParts);
        for (const QString &line : lines) {
            if (line.startsWith(QStringLiteral("Path = "))) {
                flushCurrent();
                currentPath = line.mid(7).trimmed();
                currentIsFolder = false;
                continue;
            }
            if (line.startsWith(QStringLiteral("Folder = "))) {
                currentIsFolder = line.mid(9).trimmed() == QStringLiteral("+");
            }
        }
        flushCurrent();

        std::sort(entriesOut.begin(), entriesOut.end(), [](const QString &left, const QString &right) {
            return compareText(left, right) < 0;
        });

        if (entriesOut.isEmpty()) {
            errorText = QStringLiteral("No image pages found in archive.");
            return false;
        }

        return true;
    }

    errorText = QStringLiteral("Unsupported archive format for reader: .%1").arg(extension);
    return false;
}

bool extractArchiveEntryToFile(
    const QString &archivePath,
    const QString &entryName,
    const QString &outputFilePath,
    QString &errorText
)
{
    errorText.clear();

    const QFileInfo archiveInfo(archivePath);
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        errorText = QStringLiteral("Archive not found: %1").arg(archivePath);
        return false;
    }

    const QString outputDir = QFileInfo(outputFilePath).absolutePath();
    if (!QDir().mkpath(outputDir)) {
        errorText = QStringLiteral("Failed to create output directory: %1").arg(outputDir);
        return false;
    }

    const QString extension = archiveInfo.suffix().toLower();
    if (extension == QStringLiteral("cbz") || extension == QStringLiteral("zip")) {
        const QString script = QString(
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
            "Add-Type -AssemblyName System.IO.Compression\n"
            "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
            "$archivePath = '%1'\n"
            "$entryName = '%2'\n"
            "$outputPath = '%3'\n"
            "try {\n"
            "  $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)\n"
            "  try {\n"
            "    $entry = $null\n"
            "    foreach ($item in $zip.Entries) {\n"
            "      if ($item.FullName -ceq $entryName) { $entry = $item; break }\n"
            "    }\n"
            "    if ($null -eq $entry) { exit 4 }\n"
            "    $inStream = $entry.Open()\n"
            "    try {\n"
            "      $outStream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)\n"
            "      try {\n"
            "        $inStream.CopyTo($outStream)\n"
            "      } finally {\n"
            "        $outStream.Dispose()\n"
            "      }\n"
            "    } finally {\n"
            "      $inStream.Dispose()\n"
            "    }\n"
            "  } finally {\n"
            "    $zip.Dispose()\n"
            "  }\n"
            "} catch {\n"
            "  [Console]::Error.WriteLine($_.Exception.Message)\n"
            "  exit 2\n"
            "}\n"
        ).arg(
            ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(archivePath)),
            ComicArchiveProcess::quotePowerShellLiteral(entryName),
            ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(outputFilePath))
        );

        QString stdOut;
        QString stdErr;
        if (!ComicArchiveProcess::runPowerShellScript(script, stdOut, stdErr, errorText)) {
            if (errorText.contains(QStringLiteral("code 4"), Qt::CaseInsensitive)) {
                errorText = QStringLiteral("Page entry not found in archive.");
            }
            return false;
        }

        return true;
    }

    if (usesSevenZipArchiveBackend(extension)) {
        const QString sevenZip = resolve7ZipExecutable();
        if (sevenZip.isEmpty()) {
            errorText = sevenZipMissingMessage();
            return false;
        }

        const QString tempDirPath = QDir(outputDir).filePath(
            QStringLiteral("extract-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
        );
        if (!QDir().mkpath(tempDirPath)) {
            errorText = QStringLiteral("Failed to create temp extraction folder: %1").arg(tempDirPath);
            return false;
        }

        QByteArray stdOutBytes;
        QByteArray stdErrBytes;
        if (!ComicArchiveProcess::runExternalProcess(
                sevenZip,
                {
                    QStringLiteral("e"),
                    QStringLiteral("-y"),
                    QStringLiteral("-aoa"),
                    QStringLiteral("-bb0"),
                    QStringLiteral("-scsUTF-8"),
                    QStringLiteral("-o%1").arg(QDir::toNativeSeparators(tempDirPath)),
                    QStringLiteral("--"),
                    QDir::toNativeSeparators(archivePath),
                    entryName
                },
                stdOutBytes,
                stdErrBytes,
                errorText,
                120000,
                true
            )) {
            QDir(tempDirPath).removeRecursively();
            return false;
        }

        const QString extractedPath = QDir(tempDirPath).filePath(QFileInfo(entryName).fileName());
        if (!QFileInfo::exists(extractedPath)) {
            QDir(tempDirPath).removeRecursively();
            errorText = QStringLiteral("Extracted page entry not found after 7-Zip operation.");
            return false;
        }

        QFile::remove(outputFilePath);
        if (!QFile::rename(extractedPath, outputFilePath)) {
            if (!QFile::copy(extractedPath, outputFilePath)) {
                QDir(tempDirPath).removeRecursively();
                errorText = QStringLiteral("Failed to move extracted page to output file.");
                return false;
            }
            QFile::remove(extractedPath);
        }
        QDir(tempDirPath).removeRecursively();
        return true;
    }

    errorText = QStringLiteral("Unsupported archive format for reader: .%1").arg(extension);
    return false;
}

bool listImageEntryMetricsInArchive(
    const QString &archivePath,
    QVariantList &metricsOut,
    QString &errorText
)
{
    metricsOut.clear();
    errorText.clear();

    const QFileInfo archiveInfo(archivePath);
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        errorText = QStringLiteral("Archive not found: %1").arg(archivePath);
        return false;
    }

    const QString extension = archiveInfo.suffix().toLower();
    if (extension == QStringLiteral("cbz") || extension == QStringLiteral("zip")) {
        const QString script = QString(
            "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
            "Add-Type -AssemblyName System.IO.Compression\n"
            "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
            "Add-Type -AssemblyName System.Drawing\n"
            "$archivePath = '%1'\n"
            "$exts = @('.jpg','.jpeg','.png','.bmp','.webp')\n"
            "try {\n"
            "  $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)\n"
            "  try {\n"
            "    $items = @()\n"
            "    foreach ($entry in $zip.Entries) {\n"
            "      if ([string]::IsNullOrEmpty($entry.Name)) { continue }\n"
            "      $entryExt = [System.IO.Path]::GetExtension($entry.FullName).ToLowerInvariant()\n"
            "      if ($exts -contains $entryExt) { $items += $entry }\n"
            "    }\n"
            "    $items = $items | Sort-Object FullName\n"
            "    foreach ($entry in $items) {\n"
            "      $width = 0\n"
            "      $height = 0\n"
            "      try {\n"
            "        $stream = $entry.Open()\n"
            "        try {\n"
            "          $image = [System.Drawing.Image]::FromStream($stream, $false, $false)\n"
            "          try {\n"
            "            $width = $image.Width\n"
            "            $height = $image.Height\n"
            "          } finally {\n"
            "            $image.Dispose()\n"
            "          }\n"
            "        } finally {\n"
            "          $stream.Dispose()\n"
            "        }\n"
            "      } catch {\n"
            "        $width = 0\n"
            "        $height = 0\n"
            "      }\n"
            "      [Console]::WriteLine('{0}`t{1}`t{2}' -f $entry.FullName, $width, $height)\n"
            "    }\n"
            "  } finally {\n"
            "    $zip.Dispose()\n"
            "  }\n"
            "} catch {\n"
            "  [Console]::Error.WriteLine($_.Exception.Message)\n"
            "  exit 2\n"
            "}\n"
        ).arg(ComicArchiveProcess::quotePowerShellLiteral(QDir::toNativeSeparators(archivePath)));

        QString stdOut;
        QString stdErr;
        if (!ComicArchiveProcess::runPowerShellScript(script, stdOut, stdErr, errorText)) {
            return false;
        }

        const QStringList lines = stdOut.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
        metricsOut.reserve(lines.size());
        for (const QString &line : lines) {
            const QStringList parts = line.split(QChar('\t'));
            if (parts.size() < 3) {
                continue;
            }

            const QString entryName = parts[0].trimmed();
            bool widthOk = false;
            bool heightOk = false;
            const int width = parts[1].trimmed().toInt(&widthOk);
            const int height = parts[2].trimmed().toInt(&heightOk);
            metricsOut.push_back(QVariantMap {
                { QStringLiteral("entryName"), entryName },
                { QStringLiteral("width"), widthOk ? width : 0 },
                { QStringLiteral("height"), heightOk ? height : 0 }
            });
        }
        return true;
    }

    if (usesSevenZipArchiveBackend(extension)) {
        QStringList entries;
        if (!listImageEntriesInArchive(archivePath, entries, errorText)) {
            return false;
        }

        const QString tempDirPath = QDir(QDir::tempPath()).filePath(
            QStringLiteral("comicflow-metrics-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
        );
        if (!QDir().mkpath(tempDirPath)) {
            errorText = QStringLiteral("Failed to create temp extraction folder for page metrics.");
            return false;
        }

        metricsOut.reserve(entries.size());
        for (const QString &entryName : entries) {
            QString suffix = QFileInfo(entryName).suffix().toLower();
            if (suffix.isEmpty()) {
                suffix = QStringLiteral("img");
            }

            const QString extractedPath = QDir(tempDirPath).filePath(
                QStringLiteral("%1.%2")
                    .arg(QUuid::createUuid().toString(QUuid::WithoutBraces), suffix)
            );

            QString extractError;
            if (!extractArchiveEntryToFile(archivePath, entryName, extractedPath, extractError)) {
                QDir(tempDirPath).removeRecursively();
                errorText = extractError;
                return false;
            }

            QImageReader reader(extractedPath);
            const QSize size = reader.size();
            metricsOut.push_back(QVariantMap {
                { QStringLiteral("entryName"), entryName },
                { QStringLiteral("width"), size.isValid() ? size.width() : 0 },
                { QStringLiteral("height"), size.isValid() ? size.height() : 0 }
            });

            QFile::remove(extractedPath);
        }

        QDir(tempDirPath).removeRecursively();
        return true;
    }

    errorText = QStringLiteral("Unsupported archive format for reader: .%1").arg(extension);
    return false;
}

QVariantMap parseComicInfoXml(const QString &xml, QString &errorText)
{
    errorText.clear();
    QVariantMap values;
    const QString trimmedXml = xml.trimmed();
    if (trimmedXml.isEmpty()) {
        errorText = QStringLiteral("ComicInfo.xml content is empty.");
        return values;
    }

    auto decodeXmlEntities = [](QString text) {
        text.replace(QStringLiteral("&apos;"), QStringLiteral("'"));
        text.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
        text.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
        text.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
        text.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
        return text;
    };

    auto extractTagValue = [&](const QString &tagName, bool &present) {
        const QRegularExpression tagPattern(
            QStringLiteral("<%1\\b[^>]*>([\\s\\S]*?)</%1>").arg(QRegularExpression::escape(tagName)),
            QRegularExpression::CaseInsensitiveOption
        );
        const QRegularExpressionMatch match = tagPattern.match(trimmedXml);
        if (!match.hasMatch()) {
            present = false;
            return QString();
        }

        present = true;
        QString body = match.captured(1);
        const QRegularExpression cdataPattern(
            QStringLiteral("^\\s*<!\\[CDATA\\[([\\s\\S]*)\\]\\]>\\s*$"),
            QRegularExpression::CaseInsensitiveOption
        );
        const QRegularExpressionMatch cdataMatch = cdataPattern.match(body);
        if (cdataMatch.hasMatch()) {
            body = cdataMatch.captured(1);
        }

        return decodeXmlEntities(body).trimmed();
    };

    const QVector<QPair<QString, QString>> textTags = {
        { QStringLiteral("Series"), QStringLiteral("series") },
        { QStringLiteral("Volume"), QStringLiteral("volume") },
        { QStringLiteral("Number"), QStringLiteral("issue") },
        { QStringLiteral("Title"), QStringLiteral("title") },
        { QStringLiteral("Publisher"), QStringLiteral("publisher") },
        { QStringLiteral("Writer"), QStringLiteral("writer") },
        { QStringLiteral("Penciller"), QStringLiteral("penciller") },
        { QStringLiteral("Inker"), QStringLiteral("inker") },
        { QStringLiteral("Colorist"), QStringLiteral("colorist") },
        { QStringLiteral("Letterer"), QStringLiteral("letterer") },
        { QStringLiteral("CoverArtist"), QStringLiteral("cover_artist") },
        { QStringLiteral("Editor"), QStringLiteral("editor") },
        { QStringLiteral("StoryArc"), QStringLiteral("story_arc") },
        { QStringLiteral("Summary"), QStringLiteral("summary") },
        { QStringLiteral("Characters"), QStringLiteral("characters") },
        { QStringLiteral("Genre"), QStringLiteral("genres") },
        { QStringLiteral("AgeRating"), QStringLiteral("age_rating") },
        { QStringLiteral("ComicPileReadStatus"), QStringLiteral("read_status") },
        { QStringLiteral("ComicFlowReadStatus"), QStringLiteral("read_status") }
    };

    for (const auto &entry : textTags) {
        bool present = false;
        const QString extracted = extractTagValue(entry.first, present);
        if (!present) continue;

        if (entry.second == QStringLiteral("read_status")) {
            const QString normalized = normalizeReadStatus(extracted);
            if (normalized.isEmpty()) {
                values.insert(entry.second, QVariant());
            } else {
                values.insert(entry.second, normalized);
            }
        } else if (extracted.isEmpty()) {
            values.insert(entry.second, QVariant());
        } else {
            values.insert(entry.second, extracted);
        }
    }

    struct NumberTag {
        QString tagName;
        QString target;
        int minValue = 0;
        int maxValue = 0;
    };
    const QVector<NumberTag> numberTags = {
        { QStringLiteral("Year"), QStringLiteral("year"), 0, 9999 },
        { QStringLiteral("Month"), QStringLiteral("month"), 1, 12 },
        { QStringLiteral("PageCount"), QStringLiteral("page_count"), 0, 1000000 },
        { QStringLiteral("ComicPileCurrentPage"), QStringLiteral("current_page"), 0, 1000000 },
        { QStringLiteral("ComicFlowCurrentPage"), QStringLiteral("current_page"), 0, 1000000 }
    };

    for (const NumberTag &entry : numberTags) {
        bool present = false;
        const QString extracted = extractTagValue(entry.tagName, present);
        if (!present) continue;

        bool ok = false;
        bool isNull = false;
        const int parsed = parseOptionalBoundedInt(extracted, entry.minValue, entry.maxValue, ok, isNull);
        if (!ok || isNull) {
            values.insert(entry.target, QVariant());
        } else {
            values.insert(entry.target, parsed);
        }
    }

    return values;
}

QString buildComicInfoXmlFromMap(const QVariantMap &values)
{
    auto nullableText = [&](const QString &key) {
        return values.value(key).toString().trimmed();
    };

    auto nullableIntString = [&](const QString &key, int minValue, int maxValue) {
        const QVariant raw = values.value(key);
        if (!raw.isValid() || raw.isNull()) return QString();

        bool ok = false;
        bool isNull = false;
        const int parsed = parseOptionalBoundedInt(raw.toString(), minValue, maxValue, ok, isNull);
        if (!ok || isNull) return QString();
        return QString::number(parsed);
    };

    const QString readStatus = normalizeReadStatus(nullableText(QStringLiteral("read_status")));

    QVector<QPair<QString, QString>> tags;
    tags.reserve(24);
    tags.push_back({ QStringLiteral("Series"), nullableText(QStringLiteral("series")) });
    tags.push_back({ QStringLiteral("Volume"), nullableText(QStringLiteral("volume")) });
    tags.push_back({ QStringLiteral("Number"), nullableText(QStringLiteral("issue")) });
    tags.push_back({ QStringLiteral("Title"), nullableText(QStringLiteral("title")) });
    tags.push_back({ QStringLiteral("Publisher"), nullableText(QStringLiteral("publisher")) });
    tags.push_back({ QStringLiteral("Year"), nullableIntString(QStringLiteral("year"), 0, 9999) });
    tags.push_back({ QStringLiteral("Month"), nullableIntString(QStringLiteral("month"), 1, 12) });
    tags.push_back({ QStringLiteral("Writer"), nullableText(QStringLiteral("writer")) });
    tags.push_back({ QStringLiteral("Penciller"), nullableText(QStringLiteral("penciller")) });
    tags.push_back({ QStringLiteral("Inker"), nullableText(QStringLiteral("inker")) });
    tags.push_back({ QStringLiteral("Colorist"), nullableText(QStringLiteral("colorist")) });
    tags.push_back({ QStringLiteral("Letterer"), nullableText(QStringLiteral("letterer")) });
    tags.push_back({ QStringLiteral("CoverArtist"), nullableText(QStringLiteral("cover_artist")) });
    tags.push_back({ QStringLiteral("Editor"), nullableText(QStringLiteral("editor")) });
    tags.push_back({ QStringLiteral("StoryArc"), nullableText(QStringLiteral("story_arc")) });
    tags.push_back({ QStringLiteral("Summary"), nullableText(QStringLiteral("summary")) });
    tags.push_back({ QStringLiteral("Characters"), nullableText(QStringLiteral("characters")) });
    tags.push_back({ QStringLiteral("Genre"), nullableText(QStringLiteral("genres")) });
    tags.push_back({ QStringLiteral("AgeRating"), nullableText(QStringLiteral("age_rating")) });
    tags.push_back({ QStringLiteral("PageCount"), nullableIntString(QStringLiteral("page_count"), 0, 1000000) });
    tags.push_back({ QStringLiteral("ComicPileReadStatus"), readStatus });
    tags.push_back({ QStringLiteral("ComicPileCurrentPage"), nullableIntString(QStringLiteral("current_page"), 0, 1000000) });

    QStringList lines;
    lines.push_back(QStringLiteral("<?xml version=\"1.0\" encoding=\"utf-8\"?>"));
    lines.push_back(QStringLiteral("<ComicInfo xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">"));

    for (const auto &tag : tags) {
        const QString value = tag.second.trimmed();
        if (value.isEmpty()) continue;
        lines.push_back(QStringLiteral("  <%1>%2</%1>").arg(tag.first, escapeXml(value)));
    }

    lines.push_back(QStringLiteral("</ComicInfo>"));
    lines.push_back(QString());
    return lines.join(QLatin1Char('\n'));
}

} // namespace ComicInfoArchive
