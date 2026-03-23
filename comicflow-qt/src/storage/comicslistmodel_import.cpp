#include <algorithm>

#include "storage/comicslistmodel.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/archivepacking.h"
#include "storage/comicinfoarchive.h"
#include "storage/importmatching.h"
#include "storage/librarylayoututils.h"

#include <QCollator>
#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFileDialog>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImageReader>
#include <QMetaType>
#include <QSqlQuery>
#include <QSet>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QUuid>
#include <QtConcurrent>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString normalizeInputFilePath(const QString &rawInput)
{
    QString input = rawInput.trimmed();
    if (input.isEmpty()) return {};

    if ((input.startsWith('"') && input.endsWith('"')) || (input.startsWith('\'') && input.endsWith('\''))) {
        input = input.mid(1, input.length() - 2).trimmed();
    }

    const QUrl url = QUrl::fromUserInput(input);
    if (url.isValid() && url.isLocalFile()) {
        return QDir::toNativeSeparators(url.toLocalFile());
    }

    return QDir::toNativeSeparators(input);
}

QString valueFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toString().trimmed();
}

bool boolFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toBool();
}

int compareText(const QString &left, const QString &right)
{
    return QString::localeAwareCompare(left, right);
}

int compareNaturalText(const QString &left, const QString &right)
{
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    return collator.compare(left, right);
}

QString sevenZipMissingMessage()
{
    return QStringLiteral("Archive support component (7z) is missing. Reinstall/repair Comic Pile or set a custom 7z path.");
}

QString parentFolderNameForFile(const QFileInfo &fileInfo)
{
    const QString absolutePath = fileInfo.absolutePath();
    if (absolutePath.isEmpty()) return {};
    return QFileInfo(absolutePath).fileName().trimmed();
}

QVariantMap readComicInfoIdentityHints(const QString &archivePath)
{
    const QString normalizedArchivePath = normalizeInputFilePath(archivePath);
    if (normalizedArchivePath.isEmpty()) return {};

    QString xml;
    QString readError;
    if (!ComicInfoArchive::readComicInfoXmlFromArchive(normalizedArchivePath, xml, readError)) {
        Q_UNUSED(readError);
        return {};
    }

    QString parseError;
    const QVariantMap parsed = ComicInfoArchive::parseComicInfoXml(xml, parseError);
    if (!parseError.isEmpty()) {
        return {};
    }

    QVariantMap hints;
    auto copyField = [&](const char *sourceKey, const char *targetKey = nullptr) {
        const QString value = trimOrEmpty(parsed.value(QString::fromLatin1(sourceKey)));
        if (value.isEmpty()) return;
        hints.insert(QString::fromLatin1(targetKey ? targetKey : sourceKey), value);
    };

    copyField("series");
    copyField("volume");
    copyField("issue", "issueNumber");
    copyField("title");
    return hints;
}

QVariantMap withImportSeriesContext(const QVariantMap &values, const QString &seriesContext)
{
    QVariantMap result = values;
    const QString trimmedContext = seriesContext.trimmed();
    if (trimmedContext.isEmpty()) {
        return result;
    }

    if (valueFromMap(result, QStringLiteral("importContextSeries")).isEmpty()) {
        result.insert(QStringLiteral("importContextSeries"), trimmedContext);
    }
    if (valueFromMap(result, QStringLiteral("series")).isEmpty()) {
        result.insert(QStringLiteral("series"), trimmedContext);
    }
    return result;
}

ComicImportMatching::ImportIdentityPassport buildArchiveImportPassport(
    const QFileInfo &sourceInfo,
    const QString &normalizedSourcePath,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    QString passportSourcePath = valueFromMap(values, QStringLiteral("importHistorySourcePath"));
    if (passportSourcePath.isEmpty()) {
        passportSourcePath = normalizedSourcePath;
    }

    QString passportSourceLabel = valueFromMap(values, QStringLiteral("importHistorySourceLabel"));
    if (passportSourceLabel.isEmpty()) {
        passportSourceLabel = filenameHint.trimmed();
    }
    if (passportSourceLabel.isEmpty()) {
        passportSourceLabel = sourceInfo.fileName();
    } else {
        passportSourceLabel = QFileInfo(passportSourceLabel).fileName().trimmed();
    }

    QString passportParentFolderLabel = parentFolderNameForFile(sourceInfo);
    const QFileInfo originalSourceInfo(passportSourcePath);
    const QString originalParentFolderLabel = parentFolderNameForFile(originalSourceInfo);
    if (!originalParentFolderLabel.isEmpty()) {
        passportParentFolderLabel = originalParentFolderLabel;
    }

    return ComicImportMatching::buildImportIdentityPassport(
        QStringLiteral("archive"),
        passportSourcePath,
        passportSourceLabel,
        passportParentFolderLabel,
        filenameHint,
        values,
        readComicInfoIdentityHints(normalizedSourcePath)
    );
}

ComicImportMatching::ImportIdentityPassport buildImageFolderImportPassport(
    const QFileInfo &folderInfo,
    const QString &normalizedFolderPath,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    return ComicImportMatching::buildImportIdentityPassport(
        QStringLiteral("image_folder"),
        normalizedFolderPath,
        folderInfo.fileName(),
        QFileInfo(folderInfo.absolutePath()).fileName().trimmed(),
        filenameHint,
        values
    );
}

QString ensureTargetCbzFilename(const QString &filenameHint, const QString &sourceFilename)
{
    auto stripKnownArchiveExtension = [](const QString &value) -> QString {
        const QString trimmedValue = value.trimmed();
        if (trimmedValue.isEmpty()) return {};

        const QFileInfo info(trimmedValue);
        const QString suffix = info.suffix().trimmed().toLower();
        static const QSet<QString> knownArchiveSuffixes = {
            QStringLiteral("cbz"),
            QStringLiteral("zip"),
            QStringLiteral("cbr"),
            QStringLiteral("rar"),
            QStringLiteral("7z"),
            QStringLiteral("cb7"),
            QStringLiteral("cbt"),
            QStringLiteral("tar"),
        };
        if (knownArchiveSuffixes.contains(suffix)) {
            return info.completeBaseName().trimmed();
        }
        return trimmedValue;
    };

    QString baseName = filenameHint.trimmed();
    if (!baseName.isEmpty()) {
        baseName = QFileInfo(baseName).fileName().trimmed();
        baseName = stripKnownArchiveExtension(baseName);
    } else {
        baseName = stripKnownArchiveExtension(QFileInfo(sourceFilename).fileName());
    }

    if (baseName.isEmpty()) {
        baseName = QStringLiteral("imported");
    }

    return QStringLiteral("%1.cbz").arg(baseName);
}

QString normalizeArchiveExtension(const QString &pathOrExtension)
{
    QString value = pathOrExtension.trimmed().toLower();
    if (value.isEmpty()) return {};
    if (value.contains('/') || value.contains('\\')) {
        value = QFileInfo(value).suffix().toLower();
    }
    if (value.startsWith('.')) {
        value = value.mid(1);
    }
    return value.trimmed();
}

QString resolve7ZipExecutableFromHint(const QString &hintPath)
{
    const QString hint = normalizeInputFilePath(hintPath);
    if (hint.isEmpty()) return {};

    QFileInfo info(hint);
    if (info.exists() && info.isFile()) {
        return QDir::toNativeSeparators(info.absoluteFilePath());
    }
    if (info.exists() && info.isDir()) {
        static const QStringList executableNames = {
            QStringLiteral("7z.exe"),
            QStringLiteral("7z"),
            QStringLiteral("7za.exe"),
            QStringLiteral("7za")
        };
        for (const QString &name : executableNames) {
            const QFileInfo nested(QDir(info.absoluteFilePath()).filePath(name));
            if (nested.exists() && nested.isFile()) {
                return QDir::toNativeSeparators(nested.absoluteFilePath());
            }
        }
    }
    return {};
}

QString resolveDjVuExecutableFromHint(const QString &hintPath)
{
    const QString hint = normalizeInputFilePath(hintPath);
    if (hint.isEmpty()) return {};

    QFileInfo info(hint);
    if (info.exists() && info.isFile()) {
        return QDir::toNativeSeparators(info.absoluteFilePath());
    }
    if (info.exists() && info.isDir()) {
        static const QStringList executableNames = {
            QStringLiteral("ddjvu.exe"),
            QStringLiteral("ddjvu")
        };
        for (const QString &name : executableNames) {
            const QFileInfo nested(QDir(info.absoluteFilePath()).filePath(name));
            if (nested.exists() && nested.isFile()) {
                return QDir::toNativeSeparators(nested.absoluteFilePath());
            }
        }
    }
    return {};
}

QString resolveDjVuExecutable()
{
    const QStringList envCandidates = {
        QStringLiteral("COMIC_PILE_DJVU_PATH"),
        QStringLiteral("DJVU_PATH")
    };
    for (const QString &envKey : envCandidates) {
        const QString resolved = resolveDjVuExecutableFromHint(qEnvironmentVariable(envKey.toUtf8().constData()));
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    const QStringList bundledCandidates = {
        QDir(appDir).filePath(QStringLiteral("ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/djvulibre/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/djvulibre/runtime/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/djvulibre/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/djvulibre/runtime/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/djvulibre/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/djvulibre/runtime/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/djvulibre/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/djvulibre/runtime/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/djvulibre/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/djvulibre/runtime/ddjvu.exe"))
    };
    for (const QString &candidate : bundledCandidates) {
        const QString resolved = resolveDjVuExecutableFromHint(candidate);
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    const QStringList programCandidates = {
        QStringLiteral("ddjvu.exe"),
        QStringLiteral("ddjvu")
    };
    for (const QString &candidate : programCandidates) {
        const QString found = QStandardPaths::findExecutable(candidate);
        if (!found.isEmpty()) {
            return QDir::toNativeSeparators(found);
        }
    }

    return {};
}

bool isDjvuExtension(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    return normalized == QStringLiteral("djvu") || normalized == QStringLiteral("djv");
}

QString djvuBackendMissingMessage()
{
    return QStringLiteral("DJVU import component (ddjvu) is missing. Reinstall/repair Comic Pile or set a custom DjVuLibre path.");
}

QSet<QString> supportedImportArchiveExtensionsSet()
{
    static const QSet<QString> extensions = {
        QStringLiteral("cbz"),
        QStringLiteral("zip"),
        QStringLiteral("pdf"),
        QStringLiteral("djvu"),
        QStringLiteral("djv"),
        QStringLiteral("cbr"),
        QStringLiteral("rar"),
        QStringLiteral("cb7"),
        QStringLiteral("7z"),
        QStringLiteral("cbt"),
        QStringLiteral("tar")
    };
    return extensions;
}

QString formatSupportedArchiveList()
{
    QStringList tokens;
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    tokens.reserve(extensions.size());
    for (const QString &ext : extensions) {
        tokens.push_back(QString(".%1").arg(ext));
    }
    std::sort(tokens.begin(), tokens.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
    });
    return tokens.join(QString(", "));
}

QString buildImportArchiveDialogFilter()
{
    QStringList wildcards;
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    wildcards.reserve(extensions.size());
    for (const QString &ext : extensions) {
        wildcards.push_back(QString("*.%1").arg(ext));
    }
    std::sort(wildcards.begin(), wildcards.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
    });

    return QString("Comic files (%1);;All files (*)").arg(wildcards.join(QString(" ")));
}

QString buildImageDialogFilter()
{
    QStringList wildcards;
    const QList<QByteArray> formats = QImageReader::supportedImageFormats();
    wildcards.reserve(formats.size());
    for (const QByteArray &format : formats) {
        const QString extension = QString::fromLatin1(format).trimmed().toLower();
        if (extension.isEmpty()) continue;
        wildcards.push_back(QStringLiteral("*.%1").arg(extension));
    }
    wildcards.removeDuplicates();
    std::sort(wildcards.begin(), wildcards.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
    });

    if (wildcards.isEmpty()) {
        return QStringLiteral("All files (*)");
    }
    return QStringLiteral("Images (%1);;All files (*)").arg(wildcards.join(QStringLiteral(" ")));
}

bool isImportArchiveExtensionSupported(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    if (normalized.isEmpty()) return false;
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    return extensions.contains(normalized);
}

bool isSevenZipExtension(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    if (normalized.isEmpty()) return false;
    return normalized == QStringLiteral("cbr")
        || normalized == QStringLiteral("rar")
        || normalized == QStringLiteral("cb7")
        || normalized == QStringLiteral("7z")
        || normalized == QStringLiteral("cbt")
        || normalized == QStringLiteral("tar");
}

bool isSupportedArchiveExtension(const QString &path)
{
    const QString extension = normalizeArchiveExtension(path);
    return isImportArchiveExtensionSupported(extension);
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
        QString("7z.exe"),
        QString("7z"),
        QString("7za.exe"),
        QString("7za")
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
        if (QFileInfo::exists(candidate)) {
            return QDir::toNativeSeparators(QFileInfo(candidate).absoluteFilePath());
        }
    }

    return {};
}

bool filePathExists(const QString &filePath)
{
    const QString normalized = QDir::toNativeSeparators(filePath.trimmed());
    if (normalized.isEmpty()) return false;
    const QFileInfo info(normalized);
    return info.exists() && info.isFile();
}

bool lookupComicIdByFilePath(QSqlDatabase &db, const QString &normalizedFilePath, int &comicIdOut, QString &errorText)
{
    comicIdOut = -1;
    errorText.clear();

    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT id FROM comics WHERE file_path = ? COLLATE NOCASE ORDER BY id ASC"));
    query.addBindValue(normalizedFilePath);
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to check duplicates: %1").arg(query.lastError().text());
        return false;
    }

    if (!query.next()) {
        comicIdOut = 0;
        return true;
    }

    comicIdOut = filePathExists(normalizedFilePath) ? query.value(0).toInt() : 0;
    return true;
}

bool isSupportedImageEntry(const QString &entryPath)
{
    const QString extension = QString(".%1").arg(QFileInfo(entryPath).suffix().toLower());
    return extension == QString(".jpg")
        || extension == QString(".jpeg")
        || extension == QString(".png")
        || extension == QString(".bmp")
        || extension == QString(".webp");
}

QStringList listSupportedArchiveFilesInFolder(const QString &folderPath, bool recursive)
{
    const QString normalizedFolderPath = normalizeInputFilePath(folderPath);
    if (normalizedFolderPath.isEmpty()) return {};

    const QFileInfo folderInfo(normalizedFolderPath);
    if (!folderInfo.exists() || !folderInfo.isDir()) return {};

    const QDir::Filters filters = QDir::Files | QDir::NoDotAndDotDot;
    const QDirIterator::IteratorFlags iteratorFlags = recursive
        ? QDirIterator::Subdirectories
        : QDirIterator::NoIteratorFlags;

    QStringList paths;
    QSet<QString> dedupe;
    QDirIterator iterator(folderInfo.absoluteFilePath(), filters, iteratorFlags);
    while (iterator.hasNext()) {
        const QString candidate = QDir::toNativeSeparators(iterator.next());
        if (!isSupportedArchiveExtension(candidate)) continue;
        const QString key = candidate.toLower();
        if (dedupe.contains(key)) continue;
        dedupe.insert(key);
        paths.push_back(candidate);
    }

    std::sort(paths.begin(), paths.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
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

QVariantMap makeImportSourceEntry(const QString &path, const QString &sourceType)
{
    QVariantMap entry;
    entry.insert(QStringLiteral("path"), QDir::toNativeSeparators(QFileInfo(path).absoluteFilePath()));
    entry.insert(QStringLiteral("sourceType"), sourceType.trimmed().toLower());
    return entry;
}

void appendExpandedImportSource(
    QVariantList &entries,
    QSet<QString> &dedupe,
    const QString &path,
    const QString &sourceType
)
{
    const QString absolutePath = QDir::toNativeSeparators(QFileInfo(path).absoluteFilePath());
    if (absolutePath.isEmpty()) return;

    const QString normalizedType = sourceType.trimmed().toLower();
    if (normalizedType.isEmpty()) return;

    const QString dedupeKey = QStringLiteral("%1|%2").arg(normalizedType, absolutePath.toLower());
    if (dedupe.contains(dedupeKey)) return;

    dedupe.insert(dedupeKey);
    entries.push_back(makeImportSourceEntry(absolutePath, normalizedType));
}

void collectExpandedImportSources(
    const QString &sourcePath,
    bool recursive,
    QVariantList &entries,
    QSet<QString> &dedupe
)
{
    const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
    if (normalizedSourcePath.isEmpty()) return;

    const QFileInfo sourceInfo(normalizedSourcePath);
    if (!sourceInfo.exists()) return;

    if (sourceInfo.isFile()) {
        const QString candidatePath = QDir::toNativeSeparators(sourceInfo.absoluteFilePath());
        if (!isSupportedArchiveExtension(candidatePath)) return;
        appendExpandedImportSource(entries, dedupe, candidatePath, QStringLiteral("archive"));
        return;
    }

    if (!sourceInfo.isDir()) return;

    const QString absoluteFolderPath = QDir::toNativeSeparators(sourceInfo.absoluteFilePath());
    const QStringList directArchives = listSupportedArchiveFilesInFolder(absoluteFolderPath, false);
    for (const QString &archivePath : directArchives) {
        appendExpandedImportSource(entries, dedupe, archivePath, QStringLiteral("archive"));
    }

    const QStringList directImages = listSupportedImageFilesInFolder(absoluteFolderPath);
    if (!directImages.isEmpty()) {
        appendExpandedImportSource(entries, dedupe, absoluteFolderPath, QStringLiteral("image_folder"));
    }

    if (!recursive) return;

    QDirIterator subdirIterator(
        absoluteFolderPath,
        QDir::Dirs | QDir::NoDotAndDotDot,
        QDirIterator::NoIteratorFlags
    );
    while (subdirIterator.hasNext()) {
        collectExpandedImportSources(subdirIterator.next(), true, entries, dedupe);
    }
}

} // namespace

QString ComicsListModel::importArchiveAndCreateIssue(
    const QString &sourcePath,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    return importArchiveAndCreateIssueInternal(sourcePath, filenameHint, values, nullptr);
}

QVariantMap ComicsListModel::importSourceAndCreateIssueEx(
    const QString &sourcePath,
    const QString &sourceType,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    QVariantMap out;
    const QString normalizedSourceType = sourceType.trimmed().toLower();
    QString error;

    if (normalizedSourceType.isEmpty() || normalizedSourceType == QStringLiteral("archive")) {
        error = importArchiveAndCreateIssueInternal(sourcePath, filenameHint, values, &out);
    } else if (normalizedSourceType == QStringLiteral("image_folder")) {
        error = importImageFolderAndCreateIssueInternal(sourcePath, filenameHint, values, &out);
    } else {
        error = QStringLiteral("Unsupported import source type: %1").arg(sourceType.trimmed());
        out.insert(QStringLiteral("ok"), false);
        out.insert(QStringLiteral("code"), QStringLiteral("unsupported_source_type"));
        out.insert(QStringLiteral("error"), error);
        out.insert(QStringLiteral("sourcePath"), normalizeInputFilePath(sourcePath));
        out.insert(QStringLiteral("sourceType"), normalizedSourceType);
        return out;
    }

    if (!error.isEmpty() && !out.contains(QStringLiteral("ok"))) {
        out.insert(QStringLiteral("ok"), false);
        out.insert(QStringLiteral("code"), QStringLiteral("create_issue_failed"));
        out.insert(QStringLiteral("error"), error);
        out.insert(QStringLiteral("sourcePath"), normalizeInputFilePath(sourcePath));
        out.insert(QStringLiteral("sourceType"), normalizedSourceType.isEmpty() ? QStringLiteral("archive") : normalizedSourceType);
    }
    return out;
}

int ComicsListModel::requestNormalizeImportArchiveAsync(const QString &sourcePath)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId](const QVariantMap &result) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId, result]() {
                emit normalizeImportArchiveFinished(requestId, result);
            },
            Qt::QueuedConnection
        );
    };

    const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
    if (normalizedSourcePath.isEmpty()) {
        emitLaterSingle({
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("invalid_input") },
            { QStringLiteral("error"), QStringLiteral("Import file path is required.") },
            { QStringLiteral("sourcePath"), normalizedSourcePath }
        });
        return requestId;
    }

    const QFileInfo sourceInfo(normalizedSourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        emitLaterSingle({
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("file_not_found") },
            { QStringLiteral("error"), QStringLiteral("Import file not found: %1").arg(sourcePath.trimmed()) },
            { QStringLiteral("sourcePath"), normalizedSourcePath }
        });
        return requestId;
    }

    const QString extension = normalizeArchiveExtension(sourceInfo.suffix());
    if (!isImportArchiveExtensionSupported(extension)) {
        emitLaterSingle({
            { QStringLiteral("ok"), false },
            { QStringLiteral("code"), QStringLiteral("unsupported_format") },
            { QStringLiteral("error"), QStringLiteral("Supported import formats: %1").arg(formatSupportedArchiveList()) },
            { QStringLiteral("sourcePath"), normalizedSourcePath }
        });
        return requestId;
    }

    if (extension == QStringLiteral("cbz")) {
        emitLaterSingle({
            { QStringLiteral("ok"), true },
            { QStringLiteral("sourcePath"), normalizedSourcePath },
            { QStringLiteral("normalizedPath"), normalizedSourcePath },
            { QStringLiteral("filenameHint"), sourceInfo.fileName() },
            { QStringLiteral("temporaryFile"), false }
        });
        return requestId;
    }

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, requestId]() {
        const QVariantMap result = watcher->result();
        emit normalizeImportArchiveFinished(requestId, result);
        watcher->deleteLater();
    });

    watcher->setFuture(QtConcurrent::run([normalizedSourcePath]() {
        QVariantMap result;
        const QFileInfo localSourceInfo(normalizedSourcePath);
        const QString tempTargetPath = QDir(QDir::tempPath()).filePath(
            QStringLiteral("comicpile-import-stage-%1.cbz")
                .arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
        );

        QString normalizeError;
        if (!ComicArchivePacking::normalizeArchiveToCbz(
                normalizedSourcePath,
                tempTargetPath,
                normalizeError)) {
            result.insert(QStringLiteral("ok"), false);
            result.insert(QStringLiteral("code"), QStringLiteral("archive_normalize_failed"));
            result.insert(QStringLiteral("error"), normalizeError);
            result.insert(QStringLiteral("sourcePath"), normalizedSourcePath);
            result.insert(QStringLiteral("normalizedPath"), tempTargetPath);
            result.insert(QStringLiteral("temporaryFile"), true);
            return result;
        }

        result.insert(QStringLiteral("ok"), true);
        result.insert(QStringLiteral("sourcePath"), normalizedSourcePath);
        result.insert(QStringLiteral("normalizedPath"), tempTargetPath);
        result.insert(QStringLiteral("filenameHint"), localSourceInfo.fileName());
        result.insert(QStringLiteral("temporaryFile"), true);
        return result;
    }));

    return requestId;
}

QVariantMap ComicsListModel::importArchiveAndCreateIssueEx(
    const QString &sourcePath,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    QVariantMap out;
    const QString error = importArchiveAndCreateIssueInternal(sourcePath, filenameHint, values, &out);
    if (!error.isEmpty() && !out.contains("ok")) {
        out.insert("ok", false);
        out.insert("code", "create_issue_failed");
        out.insert("error", error);
    }
    return out;
}

int ComicsListModel::countPendingImportDuplicates(const QVariantList &entries) const
{
    if (entries.isEmpty()) return 0;

    QHash<QString, QString> simulatedDeferredImportFolders = m_deferredImportFolderBySeriesKey;

    const QString connectionName = QStringLiteral("comic_pile_duplicate_count_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return 0;
    }

    int count = 0;
    for (const QVariant &entryValue : entries) {
        const QVariantMap entry = entryValue.toMap();
        if (entry.isEmpty()) continue;

        const QString predictedPath = predictedPendingImportTargetPath(entry, simulatedDeferredImportFolders);
        if (predictedPath.isEmpty()) continue;

        int existingId = -1;
        QString duplicateCheckError;
        if (!lookupComicIdByFilePath(db, predictedPath, existingId, duplicateCheckError)) {
            continue;
        }
        if (existingId > 0) {
            count += 1;
        }
    }

    db.close();
    return count;
}

QVariantMap ComicsListModel::previewPendingImportDuplicate(const QVariantList &entries, int skipMatches) const
{
    if (entries.isEmpty()) return {};

    QHash<QString, QString> simulatedDeferredImportFolders = m_deferredImportFolderBySeriesKey;

    const QString connectionName = QStringLiteral("comic_pile_duplicate_preview_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return {};
    }

    int remainingToSkip = std::max(0, skipMatches);
    QVariantMap preview;
    for (const QVariant &entryValue : entries) {
        const QVariantMap entry = entryValue.toMap();
        if (entry.isEmpty()) continue;

        const QString predictedPath = predictedPendingImportTargetPath(entry, simulatedDeferredImportFolders);
        if (predictedPath.isEmpty()) continue;

        int existingId = -1;
        QString duplicateCheckError;
        if (!lookupComicIdByFilePath(db, predictedPath, existingId, duplicateCheckError)) {
            continue;
        }
        if (existingId < 1) {
            continue;
        }

        if (remainingToSkip > 0) {
            remainingToSkip -= 1;
            continue;
        }

        preview.insert(QStringLiteral("path"), trimOrEmpty(entry.value(QStringLiteral("path"))));
        preview.insert(QStringLiteral("sourceType"), trimOrEmpty(entry.value(QStringLiteral("sourceType"))));
        preview.insert(QStringLiteral("filenameHint"), trimOrEmpty(entry.value(QStringLiteral("filenameHint"))));
        preview.insert(QStringLiteral("predictedPath"), predictedPath);
        preview.insert(QStringLiteral("existingId"), existingId);
        preview.insert(QStringLiteral("duplicateTier"), QStringLiteral("exact"));
        break;
    }

    db.close();
    return preview;
}

QString ComicsListModel::predictedPendingImportTargetPath(
    const QVariantMap &entry,
    QHash<QString, QString> &simulatedDeferredImportFolders
) const
{
    if (entry.isEmpty()) return {};

    const QString libraryPath = QDir(m_dataRoot).filePath(QStringLiteral("Library"));
    QDir libraryDir(libraryPath);
    if (!libraryDir.exists()) {
        return {};
    }

    const QString sourcePath = trimOrEmpty(entry.value(QStringLiteral("path")));
    const QString sourceType = trimOrEmpty(entry.value(QStringLiteral("sourceType"))).toLower();
    const QString filenameHint = trimOrEmpty(entry.value(QStringLiteral("filenameHint")));
    const QString seriesOverride = trimOrEmpty(entry.value(QStringLiteral("seriesOverride")));
    QVariantMap values = withImportSeriesContext(entry.value(QStringLiteral("values")).toMap(), seriesOverride);
    const bool deferReload = boolFromMap(values, QStringLiteral("deferReload"))
        || boolFromMap(values, QStringLiteral("defer_reload"));

    QVariantMap createValues = values;
    if (deferReload) {
        createValues.insert(QStringLiteral("deferReload"), true);
    }

    QString targetFilename;

    if (sourceType.isEmpty() || sourceType == QStringLiteral("archive")) {
        const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
        if (normalizedSourcePath.isEmpty()) return {};

        const QFileInfo sourceInfo(normalizedSourcePath);
        if (!sourceInfo.exists() || !sourceInfo.isFile()) return {};

        const QString extension = normalizeArchiveExtension(sourceInfo.suffix());
        if (!isImportArchiveExtensionSupported(extension)) return {};
        if (isSevenZipExtension(extension) && !isCbrBackendAvailable()) return {};

        const ComicImportMatching::ImportIdentityPassport passport = buildArchiveImportPassport(
            sourceInfo,
            normalizedSourcePath,
            filenameHint,
            createValues
        );
        createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);

        targetFilename = ensureTargetCbzFilename(filenameHint, sourceInfo.fileName());
        if (targetFilename.isEmpty()) return {};
    } else if (sourceType == QStringLiteral("image_folder")) {
        const QString normalizedFolderPath = normalizeInputFilePath(sourcePath);
        if (normalizedFolderPath.isEmpty()) return {};

        const QFileInfo folderInfo(normalizedFolderPath);
        if (!folderInfo.exists() || !folderInfo.isDir()) return {};

        const QStringList imagePaths = listSupportedImageFilesInFolder(normalizedFolderPath);
        if (imagePaths.isEmpty()) return {};

        const ComicImportMatching::ImportIdentityPassport passport = buildImageFolderImportPassport(
            folderInfo,
            normalizedFolderPath,
            filenameHint,
            createValues
        );
        createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);

        QString folderName = folderInfo.fileName().trimmed();
        if (folderName.isEmpty()) {
            folderName = QStringLiteral("imported");
        }

        const QString effectiveFilenameHint = filenameHint.trimmed().isEmpty()
            ? folderName
            : filenameHint.trimmed();
        targetFilename = ensureTargetCbzFilename(effectiveFilenameHint, folderName);
        if (targetFilename.isEmpty()) return {};
    } else {
        return {};
    }

    const QString effectiveSeries = valueFromMap(createValues, QStringLiteral("series"));
    const QString effectiveSeriesKey = normalizeSeriesKey(effectiveSeries);
    QString folderSeriesName = effectiveSeries;
    const QString inferredFolderSeriesName = ComicImportMatching::guessSeriesFromFilename(effectiveSeries);
    if (!ComicImportMatching::isWeakSeriesName(inferredFolderSeriesName)
        && normalizeSeriesKey(inferredFolderSeriesName) == effectiveSeriesKey) {
        folderSeriesName = inferredFolderSeriesName;
    }

    ComicLibraryLayout::SeriesFolderState folderState;
    for (const ComicRow &row : m_rows) {
        if (row.filePath.trimmed().isEmpty()) continue;
        const QString relativeDir = ComicLibraryLayout::relativeDirUnderRoot(libraryPath, row.filePath);
        if (relativeDir.isEmpty()) continue;
        ComicLibraryLayout::registerSeriesFolderAssignment(folderState, normalizeSeriesKey(row.series), relativeDir);
    }
    for (auto it = simulatedDeferredImportFolders.constBegin(); it != simulatedDeferredImportFolders.constEnd(); ++it) {
        ComicLibraryLayout::registerSeriesFolderAssignment(folderState, it.key(), it.value());
    }

    const QString seriesFolderName = ComicLibraryLayout::assignSeriesFolderName(folderState, effectiveSeriesKey, folderSeriesName);
    if (deferReload && !seriesFolderName.trimmed().isEmpty()) {
        simulatedDeferredImportFolders.insert(effectiveSeriesKey, seriesFolderName);
    }

    const QDir seriesDir(libraryDir.filePath(seriesFolderName));
    const QString finalFilePath = seriesDir.filePath(targetFilename);

    return QDir::toNativeSeparators(QFileInfo(finalFilePath).absoluteFilePath());
}

QString ComicsListModel::importImageFolderAndCreateIssueInternal(
    const QString &folderPath,
    const QString &filenameHint,
    const QVariantMap &values,
    QVariantMap *outResult
)
{
    auto setOutError = [&](const QString &code, const QString &message, const QString &normalizedFolderPath) {
        if (!outResult) return;
        outResult->clear();
        outResult->insert(QStringLiteral("ok"), false);
        outResult->insert(QStringLiteral("code"), code);
        outResult->insert(QStringLiteral("error"), message);
        outResult->insert(QStringLiteral("sourcePath"), normalizedFolderPath);
        outResult->insert(QStringLiteral("sourceType"), QStringLiteral("image_folder"));
    };

    resetLastImportOutcome();

    const QString normalizedFolderPath = normalizeInputFilePath(folderPath);
    if (normalizedFolderPath.isEmpty()) {
        const QString error = QStringLiteral("Image folder path is required.");
        setOutError(QStringLiteral("invalid_input"), error, normalizedFolderPath);
        return error;
    }

    const QFileInfo folderInfo(normalizedFolderPath);
    if (!folderInfo.exists() || !folderInfo.isDir()) {
        const QString error = QStringLiteral("Image folder not found: %1").arg(folderPath.trimmed());
        setOutError(QStringLiteral("folder_not_found"), error, normalizedFolderPath);
        return error;
    }

    const QStringList imagePaths = listSupportedImageFilesInFolder(normalizedFolderPath);
    if (imagePaths.isEmpty()) {
        const QString error = QStringLiteral("No supported image files found in folder: %1")
            .arg(QDir::toNativeSeparators(folderInfo.absoluteFilePath()));
        setOutError(QStringLiteral("image_folder_empty"), error, normalizedFolderPath);
        return error;
    }

    const bool deferReload = boolFromMap(values, QStringLiteral("deferReload"))
        || boolFromMap(values, QStringLiteral("defer_reload"));

    QVariantMap createValues = values;
    if (deferReload) {
        createValues.insert(QStringLiteral("deferReload"), true);
    }

    QString folderName = folderInfo.fileName().trimmed();
    if (folderName.isEmpty()) {
        folderName = QStringLiteral("imported");
    }
    const ComicImportMatching::ImportIdentityPassport passport = buildImageFolderImportPassport(
        folderInfo,
        normalizedFolderPath,
        filenameHint,
        createValues
    );
    createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);
    createValues.insert(QStringLiteral("importHistorySourcePath"), normalizedFolderPath);
    createValues.insert(QStringLiteral("importHistorySourceType"), QStringLiteral("image_folder"));
    createValues.insert(QStringLiteral("importHistorySourceLabel"), folderName);

    const QString effectiveFilenameHint = filenameHint.trimmed().isEmpty()
        ? folderName
        : filenameHint.trimmed();

    const QString tempRootPath = QDir(QDir::tempPath()).filePath(
        QStringLiteral("comicpile-image-folder-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
    );
    if (!QDir().mkpath(tempRootPath)) {
        const QString error = QStringLiteral("Failed to create temporary directory for image folder import.");
        setOutError(QStringLiteral("temp_dir_create_failed"), error, normalizedFolderPath);
        return error;
    }

    const QString tempCbzPath = QDir(tempRootPath).filePath(
        ensureTargetCbzFilename(effectiveFilenameHint, folderName)
    );
    auto cleanupTemp = [&]() {
        QDir(tempRootPath).removeRecursively();
    };

    QString packageError;
    if (!packageImageFolderToCbz(normalizedFolderPath, tempCbzPath, packageError)) {
        cleanupTemp();
        setOutError(QStringLiteral("image_folder_package_failed"), packageError, normalizedFolderPath);
        return packageError;
    }

    QVariantMap delegateResult;
    const QString importError = importArchiveAndCreateIssueInternal(
        tempCbzPath,
        effectiveFilenameHint,
        createValues,
        &delegateResult
    );
    cleanupTemp();

    if (outResult) {
        *outResult = delegateResult;
        outResult->insert(QStringLiteral("sourcePath"), normalizedFolderPath);
        outResult->insert(QStringLiteral("sourceType"), QStringLiteral("image_folder"));
    }

    if (!importError.isEmpty() && outResult && !outResult->contains(QStringLiteral("ok"))) {
        setOutError(QStringLiteral("create_issue_failed"), importError, normalizedFolderPath);
    }
    return importError;
}

QString ComicsListModel::browseArchiveFile(const QString &currentPath) const
{
    QString initialDir = QDir(m_dataRoot).filePath("Library");

    const QString normalizedInput = normalizeInputFilePath(currentPath);
    if (!normalizedInput.isEmpty()) {
        const QFileInfo info(normalizedInput);
        if (info.exists() && info.isFile()) {
            initialDir = info.absolutePath();
        } else if (info.exists() && info.isDir()) {
            initialDir = info.absoluteFilePath();
        } else if (!info.absolutePath().isEmpty()) {
            initialDir = info.absolutePath();
        }
    }

    const QString selectedPath = QFileDialog::getOpenFileName(
        nullptr,
        QString("Select comic file"),
        initialDir,
        buildImportArchiveDialogFilter()
    );
    if (selectedPath.isEmpty()) return {};
    return QDir::toNativeSeparators(selectedPath);
}

QStringList ComicsListModel::browseArchiveFiles(const QString &currentPath) const
{
    QString initialDir = QDir(m_dataRoot).filePath("Library");

    const QString normalizedInput = normalizeInputFilePath(currentPath);
    if (!normalizedInput.isEmpty()) {
        const QFileInfo info(normalizedInput);
        if (info.exists() && info.isFile()) {
            initialDir = info.absolutePath();
        } else if (info.exists() && info.isDir()) {
            initialDir = info.absoluteFilePath();
        } else if (!info.absolutePath().isEmpty()) {
            initialDir = info.absolutePath();
        }
    }

    const QStringList selectedPaths = QFileDialog::getOpenFileNames(
        nullptr,
        QString("Select comic files"),
        initialDir,
        buildImportArchiveDialogFilter()
    );

    QStringList normalized;
    normalized.reserve(selectedPaths.size());
    for (const QString &path : selectedPaths) {
        if (path.trimmed().isEmpty()) continue;
        normalized.push_back(QDir::toNativeSeparators(path));
    }
    return normalized;
}

QString ComicsListModel::browseArchiveFolder(const QString &currentPath) const
{
    QString initialDir = QDir(m_dataRoot).filePath("Library");

    const QString normalizedInput = normalizeInputFilePath(currentPath);
    if (!normalizedInput.isEmpty()) {
        const QFileInfo info(normalizedInput);
        if (info.exists() && info.isFile()) {
            initialDir = info.absolutePath();
        } else if (info.exists() && info.isDir()) {
            initialDir = info.absoluteFilePath();
        } else if (!info.absolutePath().isEmpty()) {
            initialDir = info.absolutePath();
        }
    }

    const QString selectedPath = QFileDialog::getExistingDirectory(
        nullptr,
        QString("Select folder with comic files or page folders"),
        initialDir,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );
    if (selectedPath.isEmpty()) return {};
    return QDir::toNativeSeparators(selectedPath);
}

QString ComicsListModel::browseDataRootFolder(const QString &currentPath) const
{
    QString initialDir = m_dataRoot;

    const QString normalizedInput = normalizeInputFilePath(currentPath);
    if (!normalizedInput.isEmpty()) {
        const QFileInfo info(normalizedInput);
        if (info.exists() && info.isFile()) {
            initialDir = info.absolutePath();
        } else if (info.exists() && info.isDir()) {
            initialDir = info.absoluteFilePath();
        } else if (!info.absolutePath().isEmpty()) {
            initialDir = info.absolutePath();
        }
    }

    const QString selectedPath = QFileDialog::getExistingDirectory(
        nullptr,
        QStringLiteral("Select new library data folder"),
        initialDir,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );
    if (selectedPath.isEmpty()) return {};
    return QDir::toNativeSeparators(selectedPath);
}

QString ComicsListModel::browseImageFile(const QString &currentPath) const
{
    QString initialDir = QDir(m_dataRoot).filePath(QStringLiteral("Library"));

    const QString normalizedInput = normalizeInputFilePath(currentPath);
    if (!normalizedInput.isEmpty()) {
        const QFileInfo info(normalizedInput);
        if (info.exists() && info.isFile()) {
            initialDir = info.absolutePath();
        } else if (info.exists() && info.isDir()) {
            initialDir = info.absoluteFilePath();
        } else if (!info.absolutePath().isEmpty()) {
            initialDir = info.absolutePath();
        }
    }

    const QString selectedPath = QFileDialog::getOpenFileName(
        nullptr,
        QStringLiteral("Select image"),
        initialDir,
        buildImageDialogFilter()
    );
    if (selectedPath.isEmpty()) return {};
    return QDir::toNativeSeparators(selectedPath);
}

QVariantList ComicsListModel::expandImportSources(const QVariantList &sourcePaths, bool recursive) const
{
    QVariantList expandedEntries;
    QSet<QString> dedupe;

    for (const QVariant &sourceValue : sourcePaths) {
        QString rawSourcePath = sourceValue.toString();
        if (sourceValue.metaType().id() == QMetaType::QVariantMap) {
            rawSourcePath = sourceValue.toMap().value(QStringLiteral("path")).toString();
        }
        collectExpandedImportSources(rawSourcePath, recursive, expandedEntries, dedupe);
    }

    std::sort(expandedEntries.begin(), expandedEntries.end(), [](const QVariant &leftValue, const QVariant &rightValue) {
        const QVariantMap left = leftValue.toMap();
        const QVariantMap right = rightValue.toMap();
        const QString leftPath = left.value(QStringLiteral("path")).toString();
        const QString rightPath = right.value(QStringLiteral("path")).toString();
        const int pathCompare = compareNaturalText(leftPath, rightPath);
        if (pathCompare != 0) return pathCompare < 0;

        const QString leftType = left.value(QStringLiteral("sourceType")).toString();
        const QString rightType = right.value(QStringLiteral("sourceType")).toString();
        return compareText(leftType, rightType) < 0;
    });
    return expandedEntries;
}

QStringList ComicsListModel::listArchiveFilesInFolder(const QString &folderPath, bool recursive) const
{
    return listSupportedArchiveFilesInFolder(folderPath, recursive);
}

qint64 ComicsListModel::fileSizeBytes(const QString &path) const
{
    const QString normalizedPath = normalizeInputFilePath(path);
    if (normalizedPath.isEmpty()) return 0;

    const QFileInfo info(normalizedPath);
    if (!info.exists() || !info.isFile()) return 0;
    return std::max<qint64>(0, info.size());
}

QStringList ComicsListModel::supportedImportArchiveExtensions() const
{
    QStringList out;
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    out.reserve(extensions.size());
    for (const QString &ext : extensions) {
        out.push_back(ext);
    }
    std::sort(out.begin(), out.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
    });
    return out;
}

bool ComicsListModel::isImportArchiveSupported(const QString &path) const
{
    const QString extension = normalizeArchiveExtension(path);
    return isImportArchiveExtensionSupported(extension);
}

bool ComicsListModel::isSevenZipRequiredForArchive(const QString &path) const
{
    const QString extension = normalizeArchiveExtension(path);
    return isSevenZipExtension(extension);
}

QString ComicsListModel::importArchiveUnsupportedReason(const QString &path) const
{
    const QString extension = normalizeArchiveExtension(path);
    if (extension.isEmpty()) {
        return QString("Import file path is required.");
    }
    if (!isImportArchiveExtensionSupported(extension)) {
        return QString("Supported import formats: %1").arg(formatSupportedArchiveList());
    }
    if (isSevenZipExtension(extension) && !isCbrBackendAvailable()) {
        return cbrBackendMissingMessage();
    }
    if (isDjvuExtension(extension) && resolveDjVuExecutable().isEmpty()) {
        return djvuBackendMissingMessage();
    }
    return {};
}

QString ComicsListModel::setSevenZipExecutablePath(const QString &path)
{
    const QString normalized = normalizeInputFilePath(path);
    if (normalized.isEmpty()) {
        qunsetenv("COMIC_PILE_7ZIP_PATH");
        qunsetenv("SEVENZIP_PATH");
        return {};
    }

    QFileInfo info(normalized);
    if (info.exists() && info.isDir()) {
        info = QFileInfo(QDir(info.absoluteFilePath()).filePath(QStringLiteral("7z.exe")));
    }
    if (!info.exists() || !info.isFile()) {
        return QString("7z was not found at the provided path.");
    }

    const QByteArray resolvedPath = QDir::toNativeSeparators(info.absoluteFilePath()).toUtf8();
    const bool primaryOk = qputenv("COMIC_PILE_7ZIP_PATH", resolvedPath);
    const bool legacyOk = qputenv("SEVENZIP_PATH", resolvedPath);
    if (!primaryOk || !legacyOk) {
        return QString("Failed to apply custom 7z path.");
    }
    return {};
}

QString ComicsListModel::configuredSevenZipExecutablePath() const
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
    return {};
}

QString ComicsListModel::effectiveSevenZipExecutablePath() const
{
    return resolve7ZipExecutable();
}

bool ComicsListModel::isCbrBackendAvailable() const
{
    return !resolve7ZipExecutable().isEmpty();
}

QString ComicsListModel::cbrBackendMissingMessage() const
{
    if (isCbrBackendAvailable()) return {};
    return sevenZipMissingMessage();
}
