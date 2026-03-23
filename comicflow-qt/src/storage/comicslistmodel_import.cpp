#include <algorithm>

#include "storage/comicslistmodel.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/archivepacking.h"
#include "storage/comicinfoarchive.h"
#include "storage/deletestagingops.h"
#include "storage/duplicaterestoreresolver.h"
#include "storage/importduplicateclassifier.h"
#include "storage/importmatching.h"
#include "storage/libraryschemamanager.h"
#include "storage/librarylayoututils.h"
#include "storage/readercacheutils.h"

#include <QCollator>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImageReader>
#include <QMetaType>
#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlError>
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

int parseOptionalYear(const QString &input, bool &ok, bool &isNull)
{
    return parseOptionalBoundedInt(input, 0, 9999, ok, isNull);
}

int parseOptionalMonth(const QString &input, bool &ok, bool &isNull)
{
    return parseOptionalBoundedInt(input, 1, 12, ok, isNull);
}

int parseOptionalCurrentPage(const QString &input, bool &ok, bool &isNull)
{
    return parseOptionalBoundedInt(input, 0, 1000000, ok, isNull);
}

QString normalizeImportIntentValue(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("global_add")
        || normalized == QStringLiteral("series_add")
        || normalized == QStringLiteral("issue_replace")) {
        return normalized;
    }
    return {};
}

QString importIntentKey(const QVariantMap &values)
{
    const QString explicitIntent = normalizeImportIntentValue(valueFromMap(values, QStringLiteral("importIntent")));
    if (!explicitIntent.isEmpty()) {
        return explicitIntent;
    }

    QString contextSeries = valueFromMap(values, QStringLiteral("importContextSeries")).trimmed();
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("seriesContext")).trimmed();
    }
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("selectedSeriesContext")).trimmed();
    }
    if (!contextSeries.isEmpty()) {
        return QStringLiteral("series_add");
    }

    return {};
}

bool hasNarrowImportSeriesContext(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
)
{
    QString contextSeries = valueFromMap(values, QStringLiteral("importContextSeries")).trimmed();
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("seriesContext")).trimmed();
    }
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("selectedSeriesContext")).trimmed();
    }
    if (contextSeries.isEmpty()) {
        return false;
    }

    const QString contextSeriesKey = ComicImportMatching::normalizeSeriesKey(contextSeries);
    if (contextSeriesKey.isEmpty() || contextSeriesKey == QStringLiteral("unknown-series")) {
        return false;
    }

    return contextSeriesKey == effectiveSeriesKey.trimmed();
}

bool shouldAllowMetadataRestoreForImport(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
)
{
    const QString intent = importIntentKey(values);
    if (intent == QStringLiteral("global_add")) {
        return false;
    }
    if (intent == QStringLiteral("series_add")) {
        return hasNarrowImportSeriesContext(values, effectiveSeriesKey);
    }
    return true;
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

QVector<ImportDuplicateClassifier::Candidate> loadLiveDuplicateCandidates(
    QSqlDatabase &db,
    const QString &seriesKey,
    QString &errorText
)
{
    errorText.clear();
    if (seriesKey.trimmed().isEmpty() || seriesKey == QStringLiteral("unknown-series")) {
        return {};
    }

    QVector<ImportDuplicateClassifier::Candidate> candidates;
    QSqlQuery query(db);
    query.prepare(
        "SELECT id, COALESCE(filename, ''), COALESCE(file_path, ''), "
        "COALESCE(series, ''), COALESCE(series_key, ''), COALESCE(volume, ''), "
        "COALESCE(issue_number, issue, ''), COALESCE(title, '') "
        "FROM comics "
        "WHERE series_key = ?"
    );
    query.addBindValue(seriesKey);
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to check duplicates: %1").arg(query.lastError().text());
        return {};
    }

    while (query.next()) {
        ImportDuplicateClassifier::Candidate candidate;
        candidate.id = query.value(0).toInt();
        candidate.filename = trimOrEmpty(query.value(1));
        candidate.filePath = trimOrEmpty(query.value(2));
        candidate.series = trimOrEmpty(query.value(3));
        candidate.seriesKey = trimOrEmpty(query.value(4));
        candidate.volume = trimOrEmpty(query.value(5));
        candidate.issue = trimOrEmpty(query.value(6));
        candidate.title = trimOrEmpty(query.value(7));
        if (!filePathExists(candidate.filePath)) continue;
        candidate.strictFilenameSignature = ComicImportMatching::normalizeFilenameSignatureStrict(candidate.filename);
        candidate.looseFilenameSignature = ComicImportMatching::normalizeFilenameSignatureLoose(candidate.filename);
        candidates.push_back(candidate);
    }

    return candidates;
}

struct LiveDuplicateCheckResult {
    ImportDuplicateClassifier::Tier tier = ImportDuplicateClassifier::Tier::None;
    ImportDuplicateClassifier::Candidate candidate;
    QString reasonKey;

    bool hasMatch() const
    {
        return tier != ImportDuplicateClassifier::Tier::None && candidate.id > 0;
    }
};

LiveDuplicateCheckResult evaluateLiveDuplicateForImport(
    QSqlDatabase &db,
    const QString &plannedFilePath,
    const QString &seriesKey,
    const QString &volumeKey,
    const QString &issueKey,
    const QString &exactVolumeValue,
    const QString &exactIssueValue,
    const QString &strictFilenameSignature,
    const QString &looseFilenameSignature,
    bool relaxWeakLiveDuplicateChecks,
    QString &errorText
)
{
    LiveDuplicateCheckResult result;
    errorText.clear();

    int existingId = -1;
    if (!lookupComicIdByFilePath(db, plannedFilePath, existingId, errorText)) {
        return result;
    }
    if (existingId > 0) {
        result.tier = ImportDuplicateClassifier::Tier::Exact;
        result.candidate.id = existingId;
        result.reasonKey = QStringLiteral("same_path");
        return result;
    }

    const QVector<ImportDuplicateClassifier::Candidate> liveCandidates = loadLiveDuplicateCandidates(
        db,
        seriesKey,
        errorText
    );
    if (!errorText.isEmpty()) {
        return result;
    }

    const ImportDuplicateClassifier::Input duplicateInput = {
        plannedFilePath,
        seriesKey,
        volumeKey,
        issueKey,
        exactVolumeValue.trimmed(),
        exactIssueValue.trimmed(),
        strictFilenameSignature,
        looseFilenameSignature,
        relaxWeakLiveDuplicateChecks
    };
    const ImportDuplicateClassifier::MatchResult match = ImportDuplicateClassifier::classifyLiveDuplicate(
        duplicateInput,
        liveCandidates
    );
    if (match.isUnique()) {
        result.tier = match.tier;
        result.candidate = match.candidates.first();
        result.reasonKey = match.reasonKey;
    }
    return result;
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

struct FingerprintSnapshot {
    QString sha1;
    qint64 sizeBytes = 0;

    bool isValid() const
    {
        return !sha1.trimmed().isEmpty() && sizeBytes > 0;
    }
};

struct FingerprintHistoryEntrySpec {
    int comicId = 0;
    QString seriesKey;
    QString eventType;
    QString sourceType;
    QString fingerprintOrigin;
    QString fingerprintSha1;
    qint64 fingerprintSizeBytes = 0;
    QString entryLabel;
};

bool computeFileFingerprint(const QString &filePath, FingerprintSnapshot &fingerprintOut, QString &errorText)
{
    fingerprintOut = {};
    errorText.clear();

    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        errorText = QStringLiteral("Fingerprint path is empty.");
        return false;
    }

    QFile file(normalizedPath);
    if (!file.open(QIODevice::ReadOnly)) {
        errorText = QStringLiteral("Failed to open file for fingerprinting: %1").arg(normalizedPath);
        return false;
    }

    QCryptographicHash hash(QCryptographicHash::Sha1);
    qint64 totalBytes = 0;
    while (!file.atEnd()) {
        const QByteArray chunk = file.read(1024 * 1024);
        if (chunk.isEmpty() && file.error() != QFileDevice::NoError) {
            errorText = QStringLiteral("Failed to read file for fingerprinting: %1").arg(normalizedPath);
            file.close();
            return false;
        }
        if (!chunk.isEmpty()) {
            hash.addData(chunk);
            totalBytes += chunk.size();
        }
    }
    file.close();

    if (totalBytes < 1) {
        errorText = QStringLiteral("Fingerprint source is empty: %1").arg(normalizedPath);
        return false;
    }

    fingerprintOut.sha1 = QString::fromLatin1(hash.result().toHex());
    fingerprintOut.sizeBytes = totalBytes;
    return true;
}

bool computeImageFolderFingerprint(const QString &folderPath, FingerprintSnapshot &fingerprintOut, QString &errorText)
{
    fingerprintOut = {};
    errorText.clear();

    const QString normalizedFolderPath = normalizeInputFilePath(folderPath);
    if (normalizedFolderPath.isEmpty()) {
        errorText = QStringLiteral("Fingerprint folder path is empty.");
        return false;
    }

    const QStringList imagePaths = listSupportedImageFilesInFolder(normalizedFolderPath);
    if (imagePaths.isEmpty()) {
        errorText = QStringLiteral("No supported images found for folder fingerprint.");
        return false;
    }

    QCryptographicHash manifestHash(QCryptographicHash::Sha1);
    qint64 totalBytes = 0;
    const QDir rootDir(normalizedFolderPath);
    for (const QString &imagePath : imagePaths) {
        FingerprintSnapshot fileFingerprint;
        QString fingerprintError;
        if (!computeFileFingerprint(imagePath, fileFingerprint, fingerprintError)) {
            errorText = fingerprintError;
            return false;
        }

        const QString relativePath = rootDir.relativeFilePath(imagePath).replace('\\', '/').trimmed().toLower();
        const QByteArray manifestLine = QStringLiteral("%1|%2|%3\n")
            .arg(relativePath)
            .arg(QString::number(fileFingerprint.sizeBytes))
            .arg(fileFingerprint.sha1)
            .toUtf8();
        manifestHash.addData(manifestLine);
        totalBytes += fileFingerprint.sizeBytes;
    }

    if (totalBytes < 1) {
        errorText = QStringLiteral("Folder fingerprint source is empty.");
        return false;
    }

    fingerprintOut.sha1 = QString::fromLatin1(manifestHash.result().toHex());
    fingerprintOut.sizeBytes = totalBytes;
    return true;
}

bool computeImportSourceFingerprint(
    const QString &sourcePath,
    const QString &sourceType,
    FingerprintSnapshot &fingerprintOut,
    QString &errorText)
{
    const QString normalizedSourceType = sourceType.trimmed().toLower();
    if (normalizedSourceType == QStringLiteral("image_folder")) {
        return computeImageFolderFingerprint(sourcePath, fingerprintOut, errorText);
    }
    return computeFileFingerprint(sourcePath, fingerprintOut, errorText);
}

bool loadFingerprintSnapshotFromValues(
    const QVariantMap &values,
    const QString &sha1Key,
    const QString &sizeKey,
    FingerprintSnapshot &fingerprintOut)
{
    fingerprintOut = {};

    const QString sha1 = values.value(sha1Key).toString().trimmed().toLower();
    if (sha1.isEmpty()) {
        return false;
    }

    bool sizeOk = false;
    const qint64 sizeBytes = values.value(sizeKey).toLongLong(&sizeOk);
    if (!sizeOk || sizeBytes < 1) {
        return false;
    }

    fingerprintOut.sha1 = sha1;
    fingerprintOut.sizeBytes = sizeBytes;
    return true;
}

void appendFingerprintHistoryEntry(
    QVector<FingerprintHistoryEntrySpec> &entries,
    int comicId,
    const QString &seriesKey,
    const QString &eventType,
    const QString &sourceType,
    const QString &fingerprintOrigin,
    const FingerprintSnapshot &fingerprint,
    const QString &entryLabel)
{
    if (!fingerprint.isValid()) {
        return;
    }

    FingerprintHistoryEntrySpec entry;
    entry.comicId = comicId;
    entry.seriesKey = seriesKey.trimmed();
    entry.eventType = eventType.trimmed().toLower();
    entry.sourceType = sourceType.trimmed().toLower();
    entry.fingerprintOrigin = fingerprintOrigin.trimmed().toLower();
    entry.fingerprintSha1 = fingerprint.sha1.trimmed().toLower();
    entry.fingerprintSizeBytes = fingerprint.sizeBytes;
    entry.entryLabel = entryLabel.trimmed();
    entries.push_back(entry);
}

QString insertFingerprintHistoryEntries(
    const QString &dbPath,
    const QVector<FingerprintHistoryEntrySpec> &entries,
    QVariantList *insertedIdsOut = nullptr)
{
    if (insertedIdsOut) {
        insertedIdsOut->clear();
    }
    if (entries.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_fingerprint_history_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    if (!db.open()) {
        return QStringLiteral("Failed to open DB for fingerprint history: %1").arg(db.lastError().text());
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureFileFingerprintHistoryTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    if (!db.transaction()) {
        const QString error = QStringLiteral("Failed to start fingerprint history transaction: %1").arg(db.lastError().text());
        db.close();
        return error;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "INSERT INTO file_fingerprint_history ("
            "comic_id, series_key, event_type, source_type, "
            "fingerprint_origin, fingerprint_sha1, fingerprint_size_bytes, entry_label"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
    );

    for (const FingerprintHistoryEntrySpec &entry : entries) {
        query.addBindValue(entry.comicId);
        query.addBindValue(entry.seriesKey);
        query.addBindValue(entry.eventType);
        query.addBindValue(entry.sourceType);
        query.addBindValue(entry.fingerprintOrigin);
        query.addBindValue(entry.fingerprintSha1);
        query.addBindValue(entry.fingerprintSizeBytes);
        query.addBindValue(entry.entryLabel);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to write fingerprint history: %1").arg(query.lastError().text());
            db.rollback();
            db.close();
            return error;
        }
        if (insertedIdsOut) {
            insertedIdsOut->push_back(query.lastInsertId());
        }
        query.finish();
    }

    if (!db.commit()) {
        const QString error = QStringLiteral("Failed to commit fingerprint history: %1").arg(db.lastError().text());
        db.rollback();
        db.close();
        return error;
    }

    db.close();
    return {};
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

QString ComicsListModel::createComicFromLibrary(
    const QString &filename,
    const QVariantMap &values
)
{
    resetLastImportOutcome();

    const QString inputRef = filename.trimmed();
    if (inputRef.isEmpty()) {
        return QString("Filename is required.");
    }
    const QString inputName = QFileInfo(QDir::fromNativeSeparators(inputRef)).fileName().trimmed();
    if (inputName.isEmpty()) {
        return QString("Filename is required.");
    }
    const bool deferReload = boolFromMap(values, "deferReload")
        || boolFromMap(values, "defer_reload");
    const QString duplicateDecision = valueFromMap(values, "duplicateDecision").toLower();
    const bool allowImportAsNew = duplicateDecision == QStringLiteral("import_as_new");
    const bool allowWeakMetadataRestore = boolFromMap(values, "allowWeakMetadataRestore");
    const int requestedRestoreCandidateId = values.value(QStringLiteral("restoreCandidateId")).toInt();

    const QString series = valueFromMap(values, "series");
    const QString volume = valueFromMap(values, "volume");
    const QString title = valueFromMap(values, "title");
    const QString issueNumber = valueFromMap(values, "issueNumber", "issue");
    const QString publisher = valueFromMap(values, "publisher");
    const QString writer = valueFromMap(values, "writer");
    const QString penciller = valueFromMap(values, "penciller");
    const QString inker = valueFromMap(values, "inker");
    const QString colorist = valueFromMap(values, "colorist");
    const QString letterer = valueFromMap(values, "letterer");
    const QString coverArtist = valueFromMap(values, "coverArtist", "cover_artist");
    const QString editor = valueFromMap(values, "editor");
    const QString storyArc = valueFromMap(values, "storyArc", "story_arc");
    const QString summary = valueFromMap(values, "summary");
    const QString characters = valueFromMap(values, "characters");
    const QString genres = valueFromMap(values, "genres");
    const QString ageRating = valueFromMap(values, "ageRating", "age_rating");

    const QString yearInput = valueFromMap(values, "year");
    bool yearOk = false;
    bool yearIsNull = false;
    const int parsedYear = parseOptionalYear(yearInput, yearOk, yearIsNull);
    if (!yearOk) {
        return QString("Year must be empty or an integer between 0 and 9999.");
    }

    const QString monthInput = valueFromMap(values, "month");
    bool monthOk = false;
    bool monthIsNull = false;
    const int parsedMonth = parseOptionalMonth(monthInput, monthOk, monthIsNull);
    if (!monthOk) {
        return QString("Month must be empty or an integer between 1 and 12.");
    }

    const QString readStatusInput = valueFromMap(values, "readStatus", "read_status");
    const QString readStatus = normalizeReadStatus(readStatusInput);
    if (readStatusInput.length() > 0 && readStatus.isEmpty()) {
        return QString("Read status must be one of: unread, in_progress, read.");
    }

    const QString currentPageInput = valueFromMap(values, "currentPage", "current_page");
    bool currentPageOk = false;
    bool currentPageIsNull = false;
    const int parsedCurrentPage = parseOptionalCurrentPage(currentPageInput, currentPageOk, currentPageIsNull);
    if (!currentPageOk) {
        return QString("Current page must be empty or an integer between 0 and 1000000.");
    }

    const QString libraryPath = QDir(m_dataRoot).filePath("Library");
    const QString resolvedFilePath = resolveLibraryFilePath(libraryPath, inputRef);
    if (resolvedFilePath.isEmpty()) {
        return QString("File not found in Database/Library: %1").arg(inputRef);
    }
    const QString normalizedFilePath = QDir::toNativeSeparators(QFileInfo(resolvedFilePath).absoluteFilePath());
    const QString resolvedFilename = QFileInfo(normalizedFilePath).fileName().trimmed();
    const PersistedImportSignals importSignals = resolvedImportSignals(
        values,
        resolvedFilename,
        QStringLiteral("archive")
    );
    const QString candidateSeriesKey = normalizeSeriesKey(series);
    const bool allowMetadataRestore = shouldAllowMetadataRestoreForImport(values, candidateSeriesKey);
    const bool relaxWeakLiveDuplicateChecks = hasNarrowImportSeriesContext(values, candidateSeriesKey);
    const QString candidateVolumeKey = normalizeVolumeKey(volume);
    QString candidateIssueValue = issueNumber;
    if (candidateIssueValue.isEmpty()) {
        candidateIssueValue = ComicImportMatching::guessIssueNumberFromFilename(resolvedFilename);
    }
    const QString candidateIssueKey = ComicImportMatching::normalizeIssueKey(candidateIssueValue);
    const QString strictInputSignature = ComicImportMatching::normalizeFilenameSignatureStrict(resolvedFilename);
    const QString looseInputSignature = ComicImportMatching::normalizeFilenameSignatureLoose(resolvedFilename);
    FingerprintSnapshot importFingerprint;
    const bool hasImportFingerprint = loadFingerprintSnapshotFromValues(
        values,
        QStringLiteral("importFingerprintSha1"),
        QStringLiteral("importFingerprintSizeBytes"),
        importFingerprint
    );

    const QString connectionName = QString("comic_pile_create_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    {
        QSqlDatabase db;
        if (!openDatabaseConnection(db, connectionName, openError)) {
            return openError;
        }

        using RestoreCandidate = DuplicateRestoreResolver::RestoreCandidate;
        const DuplicateRestoreResolver::RestoreMatchInput restoreMatchInput = {
            candidateSeriesKey,
            candidateIssueKey,
            candidateVolumeKey,
            candidateIssueValue.trimmed(),
            volume.trimmed()
        };

        auto shouldRefreshLegacyMetadata = [&](const RestoreCandidate &candidate) -> bool {
            if (series.trimmed().isEmpty() || candidateSeriesKey == QString("unknown-series")) {
                return false;
            }

            const QString existingSeriesKey = candidate.seriesKey.trimmed();
            if (existingSeriesKey.isEmpty() || existingSeriesKey == QString("unknown-series")) {
                return true;
            }

            if (existingSeriesKey != candidateSeriesKey) {
                return true;
            }

            if (ComicImportMatching::isWeakSeriesName(candidate.series)) {
                return true;
            }

            static const QRegularExpression trailingIssueYearInSeriesPattern(
                "^(.*?)(?:[\\s\\-]+(?:(?:issue|iss|no|n|ch|chapter|ep|episode)\\s*#?(\\d+(?:\\.\\d+)?)|#?(\\d{1,6}(?:\\.\\d+)?)))[\\s\\-]+((?:19|20)\\d{2})\\s*$",
                QRegularExpression::CaseInsensitiveOption
            );
            if (trailingIssueYearInSeriesPattern.match(candidate.series.trimmed()).hasMatch()) {
                return true;
            }

            return false;
        };

        auto restoreExistingIssue = [&](const RestoreCandidate &candidate) -> QString {
            const bool refreshLegacyMetadata = shouldRefreshLegacyMetadata(candidate);
            QSqlQuery restoreQuery(db);

            if (refreshLegacyMetadata) {
                const QString restoredSeries = series.trimmed();
                const QString restoredSeriesKey = candidateSeriesKey;
                const QString restoredVolume = !volume.trimmed().isEmpty() ? volume.trimmed() : candidate.volume;
                const QString restoredIssue = !candidateIssueValue.trimmed().isEmpty()
                    ? candidateIssueValue.trimmed()
                    : candidate.issue;

                restoreQuery.prepare(
                    "UPDATE comics SET "
                    "file_path = ?, filename = ?, "
                    "series = ?, series_key = ?, volume = ?, issue_number = ?, issue = ?, "
                    "import_original_filename = ?, import_strict_filename_signature = ?, "
                    "import_loose_filename_signature = ?, import_source_type = ? "
                    "WHERE id = ?"
                );
                restoreQuery.addBindValue(normalizedFilePath);
                restoreQuery.addBindValue(resolvedFilename);
                restoreQuery.addBindValue(restoredSeries);
                restoreQuery.addBindValue(restoredSeriesKey);
                restoreQuery.addBindValue(restoredVolume);
                restoreQuery.addBindValue(restoredIssue);
                restoreQuery.addBindValue(restoredIssue);
                restoreQuery.addBindValue(importSignals.originalFilename);
                restoreQuery.addBindValue(importSignals.strictFilenameSignature);
                restoreQuery.addBindValue(importSignals.looseFilenameSignature);
                restoreQuery.addBindValue(importSignals.sourceType);
                restoreQuery.addBindValue(candidate.id);
            } else {
                restoreQuery.prepare(
                    "UPDATE comics SET "
                    "file_path = ?, filename = ?, "
                    "import_original_filename = ?, import_strict_filename_signature = ?, "
                    "import_loose_filename_signature = ?, import_source_type = ? "
                    "WHERE id = ?"
                );
                restoreQuery.addBindValue(normalizedFilePath);
                restoreQuery.addBindValue(resolvedFilename);
                restoreQuery.addBindValue(importSignals.originalFilename);
                restoreQuery.addBindValue(importSignals.strictFilenameSignature);
                restoreQuery.addBindValue(importSignals.looseFilenameSignature);
                restoreQuery.addBindValue(importSignals.sourceType);
                restoreQuery.addBindValue(candidate.id);
            }

            if (!restoreQuery.exec()) {
                return QString("Failed to restore existing issue: %1").arg(restoreQuery.lastError().text());
            }
            return {};
        };

        auto finishRestore = [&](const RestoreCandidate &candidate) -> QString {
            const QString restoreError = restoreExistingIssue(candidate);
            if (!restoreError.isEmpty()) {
                db.close();
                return restoreError;
            }

            m_lastImportAction = QString("restored");
            m_lastImportComicId = candidate.id;

            db.close();
            ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, candidate.id);
            m_readerArchivePathById.insert(candidate.id, normalizedFilePath);
            m_readerImageEntriesById.remove(candidate.id);
            m_readerPageMetricsById.remove(candidate.id);
            requestIssueThumbnailAsync(candidate.id);
            if (!deferReload) {
                reload();
            }
            return {};
        };

        auto failAmbiguousRestore = [&](const QVector<RestoreCandidate> &candidates) -> QString {
            QSet<int> uniqueCandidateIds;
            for (const RestoreCandidate &candidate : candidates) {
                if (candidate.id > 0) {
                    uniqueCandidateIds.insert(candidate.id);
                }
            }

            m_lastImportAction = QStringLiteral("restore_conflict");
            m_lastImportRestoreCandidateCount = uniqueCandidateIds.size();
            m_lastImportRestoreCandidateId = -1;
            db.close();

            return QStringLiteral(
                "Import is blocked because %1 deleted issue records match this archive. The app cannot safely restore it automatically."
            ).arg(QString::number(m_lastImportRestoreCandidateCount));
        };

        auto failWeakMetadataRestore = [&](const QVector<RestoreCandidate> &candidates) -> QString {
            QSet<int> uniqueCandidateIds;
            int candidateId = -1;
            for (const RestoreCandidate &candidate : candidates) {
                if (candidate.id > 0) {
                    uniqueCandidateIds.insert(candidate.id);
                    if (candidateId < 1) {
                        candidateId = candidate.id;
                    }
                }
            }

            m_lastImportAction = QStringLiteral("restore_review_required");
            m_lastImportRestoreCandidateCount = std::max(1, static_cast<int>(uniqueCandidateIds.size()));
            m_lastImportRestoreCandidateId = candidateId;
            db.close();

            return QStringLiteral(
                "Import is blocked because a deleted issue only partially matches this archive. The app cannot safely restore it automatically."
            );
        };

        auto isMissingCandidate = [&](const RestoreCandidate &candidate) -> bool {
            const QString currentPath = candidate.filePath.trimmed();
            if (currentPath.isEmpty()) return true;
            return !filePathExists(currentPath);
        };

        if (!allowImportAsNew && hasImportFingerprint) {
            QVector<RestoreCandidate> fingerprintCandidates;
            QSet<int> seenCandidateIds;
            QSqlQuery fingerprintQuery(db);
            fingerprintQuery.prepare(
                "SELECT c.id, COALESCE(c.filename, ''), COALESCE(c.file_path, ''), "
                "COALESCE(c.series, ''), COALESCE(c.series_key, ''), COALESCE(c.volume, ''), COALESCE(c.issue_number, c.issue, '') "
                "FROM file_fingerprint_history fh "
                "JOIN comics c ON c.id = fh.comic_id "
                "WHERE fh.comic_id > 0 "
                "AND fh.fingerprint_sha1 = ? "
                "AND fh.fingerprint_size_bytes = ?"
            );
            fingerprintQuery.addBindValue(importFingerprint.sha1);
            fingerprintQuery.addBindValue(importFingerprint.sizeBytes);
            if (!fingerprintQuery.exec()) {
                const QString error = QString("Failed to check file fingerprint history: %1").arg(fingerprintQuery.lastError().text());
                db.close();
                return error;
            }
            while (fingerprintQuery.next()) {
                RestoreCandidate candidate;
                candidate.id = fingerprintQuery.value(0).toInt();
                if (candidate.id < 1 || seenCandidateIds.contains(candidate.id)) continue;
                candidate.filename = trimOrEmpty(fingerprintQuery.value(1));
                candidate.filePath = trimOrEmpty(fingerprintQuery.value(2));
                candidate.series = trimOrEmpty(fingerprintQuery.value(3));
                candidate.seriesKey = trimOrEmpty(fingerprintQuery.value(4));
                candidate.volume = trimOrEmpty(fingerprintQuery.value(5));
                candidate.issue = trimOrEmpty(fingerprintQuery.value(6));
                if (!isMissingCandidate(candidate)) continue;
                seenCandidateIds.insert(candidate.id);
                fingerprintCandidates.push_back(candidate);
            }
            if (fingerprintCandidates.size() == 1) {
                return finishRestore(fingerprintCandidates.first());
            }
            if (fingerprintCandidates.size() > 1) {
                return failAmbiguousRestore(fingerprintCandidates);
            }
        }

        QVector<RestoreCandidate> filenameCandidates;
        QSqlQuery filenameQuery(db);
        filenameQuery.prepare(
            "SELECT id, COALESCE(filename, ''), COALESCE(file_path, ''), "
            "COALESCE(series, ''), COALESCE(series_key, ''), COALESCE(volume, ''), COALESCE(issue_number, issue, '') "
            "FROM comics "
            "WHERE filename = ? COLLATE NOCASE"
        );
        filenameQuery.addBindValue(resolvedFilename);
        if (!filenameQuery.exec()) {
            const QString error = QString("Failed to check duplicates: %1").arg(filenameQuery.lastError().text());
            db.close();
            return error;
        }
        while (filenameQuery.next()) {
            RestoreCandidate candidate;
            candidate.id = filenameQuery.value(0).toInt();
            candidate.filename = trimOrEmpty(filenameQuery.value(1));
            candidate.filePath = trimOrEmpty(filenameQuery.value(2));
            candidate.series = trimOrEmpty(filenameQuery.value(3));
            candidate.seriesKey = trimOrEmpty(filenameQuery.value(4));
            candidate.volume = trimOrEmpty(filenameQuery.value(5));
            candidate.issue = trimOrEmpty(filenameQuery.value(6));
            if (!isMissingCandidate(candidate)) continue;
            filenameCandidates.push_back(candidate);
        }
        const auto filenameResolution = DuplicateRestoreResolver::resolveFilenameCandidates(
            filenameCandidates,
            restoreMatchInput
        );
        if (filenameResolution.isUnique()) {
            return finishRestore(filenameResolution.candidates.first());
        }

        if (allowMetadataRestore
            && candidateSeriesKey != QString("unknown-series")
            && !candidateIssueKey.isEmpty()) {
            QVector<RestoreCandidate> metadataCandidates;
            QSqlQuery metadataQuery(db);
            metadataQuery.prepare(
                "SELECT id, COALESCE(file_path, ''), COALESCE(series, ''), COALESCE(series_key, ''), "
                "COALESCE(volume, ''), COALESCE(issue_number, issue, '') "
                "FROM comics "
                "WHERE series_key = ?"
            );
            metadataQuery.addBindValue(candidateSeriesKey);
            if (!metadataQuery.exec()) {
                const QString error = QString("Failed to check duplicates: %1").arg(metadataQuery.lastError().text());
                db.close();
                return error;
            }
            while (metadataQuery.next()) {
                RestoreCandidate candidate;
                candidate.id = metadataQuery.value(0).toInt();
                candidate.filePath = trimOrEmpty(metadataQuery.value(1));
                candidate.series = trimOrEmpty(metadataQuery.value(2));
                candidate.seriesKey = trimOrEmpty(metadataQuery.value(3));
                candidate.volume = trimOrEmpty(metadataQuery.value(4));
                candidate.issue = trimOrEmpty(metadataQuery.value(5));
                if (!isMissingCandidate(candidate)) continue;
                if (!DuplicateRestoreResolver::matchesIssueKey(restoreMatchInput, candidate.issue)) continue;
                if (!DuplicateRestoreResolver::matchesVolumeKey(restoreMatchInput, candidate.volume)) continue;
                metadataCandidates.push_back(candidate);
            }
            const auto metadataResolution = DuplicateRestoreResolver::resolveMetadataCandidates(
                metadataCandidates,
                restoreMatchInput
            );
            if (metadataResolution.isUnique()) {
                const RestoreCandidate candidate = metadataResolution.candidates.first();
                if (DuplicateRestoreResolver::isExactMetadataCandidate(candidate, restoreMatchInput)) {
                    return finishRestore(candidate);
                }
                if (allowWeakMetadataRestore
                    && requestedRestoreCandidateId > 0
                    && candidate.id == requestedRestoreCandidateId) {
                    return finishRestore(candidate);
                }
                if (!allowImportAsNew) {
                    return failWeakMetadataRestore(metadataResolution.candidates);
                }
            }
            if (metadataResolution.candidates.size() > 1 && !allowImportAsNew) {
                return failAmbiguousRestore(metadataResolution.candidates);
            }
        }

        if (!strictInputSignature.isEmpty()) {
            QVector<RestoreCandidate> strictSignatureCandidates;
            QSqlQuery signatureQuery(db);
            signatureQuery.prepare(
                "SELECT id, COALESCE(filename, ''), COALESCE(file_path, ''), "
                "COALESCE(series, ''), COALESCE(series_key, ''), COALESCE(volume, ''), COALESCE(issue_number, issue, '') "
                "FROM comics"
            );
            if (!signatureQuery.exec()) {
                const QString error = QString("Failed to check duplicates: %1").arg(signatureQuery.lastError().text());
                db.close();
                return error;
            }
            while (signatureQuery.next()) {
                RestoreCandidate candidate;
                candidate.id = signatureQuery.value(0).toInt();
                candidate.filename = trimOrEmpty(signatureQuery.value(1));
                candidate.filePath = trimOrEmpty(signatureQuery.value(2));
                candidate.series = trimOrEmpty(signatureQuery.value(3));
                candidate.seriesKey = trimOrEmpty(signatureQuery.value(4));
                candidate.volume = trimOrEmpty(signatureQuery.value(5));
                candidate.issue = trimOrEmpty(signatureQuery.value(6));
                if (!isMissingCandidate(candidate)) continue;
                if (ComicImportMatching::normalizeFilenameSignatureStrict(candidate.filename) != strictInputSignature) continue;
                strictSignatureCandidates.push_back(candidate);
            }

            const auto strictResolution = DuplicateRestoreResolver::resolveStrictSignatureCandidates(
                strictSignatureCandidates
            );
            if (strictResolution.isUnique()) {
                return finishRestore(strictResolution.candidates.first());
            }
        }

        QString liveDuplicateError;
        const LiveDuplicateCheckResult liveDuplicate = evaluateLiveDuplicateForImport(
            db,
            normalizedFilePath,
            candidateSeriesKey,
            candidateVolumeKey,
            candidateIssueKey,
            volume,
            candidateIssueValue,
            strictInputSignature,
            looseInputSignature,
            relaxWeakLiveDuplicateChecks,
            liveDuplicateError
        );
        if (!liveDuplicateError.isEmpty()) {
            db.close();
            return liveDuplicateError;
        }
        if (liveDuplicate.hasMatch() && (!allowImportAsNew || liveDuplicate.tier == ImportDuplicateClassifier::Tier::Exact)) {
            m_lastImportAction = QStringLiteral("duplicate");
            m_lastImportDuplicateId = liveDuplicate.candidate.id;
            m_lastImportDuplicateTier = ImportDuplicateClassifier::tierKey(liveDuplicate.tier);
            db.close();

            if (liveDuplicate.tier == ImportDuplicateClassifier::Tier::VeryLikely) {
                return QStringLiteral("Likely duplicate issue found in DB (id %1).").arg(liveDuplicate.candidate.id);
            }
            if (liveDuplicate.tier == ImportDuplicateClassifier::Tier::Weak) {
                return QStringLiteral("Suspicious duplicate issue found in DB (id %1).").arg(liveDuplicate.candidate.id);
            }
            return QStringLiteral("Issue already exists in DB (id %1).").arg(liveDuplicate.candidate.id);
        }

        QSqlQuery insertQuery(db);
        insertQuery.prepare(
            "INSERT INTO comics ("
            "file_path, filename, series, series_key, volume, title, issue_number, issue, "
            "publisher, year, month, writer, penciller, inker, colorist, letterer, cover_artist, "
            "editor, story_arc, summary, characters, genres, age_rating, read_status, current_page, "
            "import_original_filename, import_strict_filename_signature, import_loose_filename_signature, import_source_type"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        );
        insertQuery.addBindValue(normalizedFilePath);
        insertQuery.addBindValue(resolvedFilename);
        insertQuery.addBindValue(series);
        insertQuery.addBindValue(normalizeSeriesKey(series));
        insertQuery.addBindValue(volume);
        insertQuery.addBindValue(title);
        insertQuery.addBindValue(issueNumber);
        insertQuery.addBindValue(issueNumber);
        insertQuery.addBindValue(publisher);
        if (yearIsNull) {
            insertQuery.addBindValue(QVariant());
        } else {
            insertQuery.addBindValue(parsedYear);
        }
        if (monthIsNull) {
            insertQuery.addBindValue(QVariant());
        } else {
            insertQuery.addBindValue(parsedMonth);
        }
        insertQuery.addBindValue(writer);
        insertQuery.addBindValue(penciller);
        insertQuery.addBindValue(inker);
        insertQuery.addBindValue(colorist);
        insertQuery.addBindValue(letterer);
        insertQuery.addBindValue(coverArtist);
        insertQuery.addBindValue(editor);
        insertQuery.addBindValue(storyArc);
        insertQuery.addBindValue(summary);
        insertQuery.addBindValue(characters);
        insertQuery.addBindValue(genres);
        insertQuery.addBindValue(ageRating);
        insertQuery.addBindValue(readStatus.isEmpty() ? QString("unread") : readStatus);
        insertQuery.addBindValue(currentPageIsNull ? 0 : parsedCurrentPage);
        insertQuery.addBindValue(importSignals.originalFilename);
        insertQuery.addBindValue(importSignals.strictFilenameSignature);
        insertQuery.addBindValue(importSignals.looseFilenameSignature);
        insertQuery.addBindValue(importSignals.sourceType);

        if (!insertQuery.exec()) {
            const QString error = QString("Failed to create issue: %1").arg(insertQuery.lastError().text());
            db.close();
            return error;
        }

        m_lastImportAction = QString("created");
        m_lastImportComicId = insertQuery.lastInsertId().toInt();

        db.close();
    }

    if (!deferReload) {
        reload();
    }
    if (m_lastImportComicId > 0) {
        ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, m_lastImportComicId);
        m_readerArchivePathById.insert(m_lastImportComicId, normalizedFilePath);
        m_readerImageEntriesById.remove(m_lastImportComicId);
        m_readerPageMetricsById.remove(m_lastImportComicId);
        requestIssueThumbnailAsync(m_lastImportComicId);
    }
    return {};
}

QString ComicsListModel::importArchiveAndCreateIssueInternal(
    const QString &sourcePath,
    const QString &filenameHint,
    const QVariantMap &values,
    QVariantMap *outResult
)
{
    auto setOutError = [&](const QString &code, const QString &message) {
        if (!outResult) return;
        outResult->clear();
        outResult->insert("ok", false);
        outResult->insert("code", code);
        outResult->insert("error", message);
    };

    auto setOutSuccess = [&](const QString &action, int comicId, const QString &finalFilename, const QString &finalFilePath, bool createdArchiveFile, const QString &normalizedSourcePath) {
        if (!outResult) return;
        outResult->clear();
        outResult->insert("ok", true);
        outResult->insert("code", action);
        outResult->insert("comicId", comicId);
        outResult->insert("filename", finalFilename);
        outResult->insert("filePath", QDir::toNativeSeparators(QFileInfo(finalFilePath).absoluteFilePath()));
        outResult->insert("createdArchiveFile", createdArchiveFile);
        outResult->insert("sourcePath", normalizedSourcePath);
    };

    resetLastImportOutcome();

    const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
    if (normalizedSourcePath.isEmpty()) {
        const QString error = QString("Import file path is required.");
        setOutError("invalid_input", error);
        return error;
    }

    const QFileInfo sourceInfo(normalizedSourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        const QString error = QString("Import file not found: %1").arg(sourcePath.trimmed());
        setOutError("file_not_found", error);
        return error;
    }

    const QString extension = normalizeArchiveExtension(sourceInfo.suffix());
    if (!isImportArchiveExtensionSupported(extension)) {
        const QString error = QString("Supported import formats: %1").arg(formatSupportedArchiveList());
        setOutError("unsupported_format", error);
        return error;
    }
    if (isSevenZipExtension(extension) && !isCbrBackendAvailable()) {
        const QString error = cbrBackendMissingMessage();
        setOutError("cbr_backend_missing", error);
        return error;
    }
    if (isDjvuExtension(extension) && resolveDjVuExecutable().isEmpty()) {
        const QString error = djvuBackendMissingMessage();
        setOutError("djvu_backend_missing", error);
        return error;
    }

    if (!isPdfExtension(extension) && !isDjvuExtension(extension)) {
        const QString archiveValidationError = validateArchiveImageEntries(sourceInfo.absoluteFilePath());
        if (!archiveValidationError.isEmpty()) {
            setOutError(archiveValidationCode(archiveValidationError), archiveValidationError);
            return archiveValidationError;
        }
    }

    const QString libraryPath = QDir(m_dataRoot).filePath("Library");
    QDir libraryDir(libraryPath);
    if (!libraryDir.exists()) {
        if (!QDir().mkpath(libraryPath)) {
            const QString error = QString("Failed to create Library folder: %1").arg(libraryPath);
            setOutError("library_dir_create_failed", error);
            return error;
        }
        libraryDir = QDir(libraryPath);
    }

    const bool deferReload = boolFromMap(values, "deferReload")
        || boolFromMap(values, "defer_reload");
    const QString duplicateDecision = valueFromMap(values, "duplicateDecision").toLower();
    const bool allowImportAsNew = duplicateDecision == QStringLiteral("import_as_new");

    QVariantMap createValues = values;
    if (deferReload) {
        createValues.insert("deferReload", true);
    }
    const ComicImportMatching::ImportIdentityPassport passport = buildArchiveImportPassport(
        sourceInfo,
        normalizedSourcePath,
        filenameHint,
        createValues
    );
    createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);

    const QString effectiveSeries = valueFromMap(createValues, "series");
    const QString effectiveSeriesKey = normalizeSeriesKey(effectiveSeries);
    if (!deferReload) {
        m_deferredImportFolderBySeriesKey.clear();
    }
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
    for (auto it = m_deferredImportFolderBySeriesKey.constBegin(); it != m_deferredImportFolderBySeriesKey.constEnd(); ++it) {
        ComicLibraryLayout::registerSeriesFolderAssignment(folderState, it.key(), it.value());
    }
    const QString seriesFolderName = ComicLibraryLayout::assignSeriesFolderName(folderState, effectiveSeriesKey, folderSeriesName);
    if (deferReload && !seriesFolderName.trimmed().isEmpty()) {
        m_deferredImportFolderBySeriesKey.insert(effectiveSeriesKey, seriesFolderName);
    }
    const QString seriesFolderPath = libraryDir.filePath(seriesFolderName);
    QDir seriesDir(seriesFolderPath);
    if (!seriesDir.exists() && !QDir().mkpath(seriesFolderPath)) {
        const QString error = QStringLiteral("Failed to create series folder: %1").arg(seriesFolderPath);
        setOutError("series_dir_create_failed", error);
        return error;
    }

    const QString targetFilename = ensureTargetCbzFilename(filenameHint, sourceInfo.fileName());
    if (targetFilename.isEmpty()) {
        const QString error = QString("Invalid archive filename.");
        setOutError("invalid_filename", error);
        return error;
    }

    createValues.remove(QStringLiteral("importFingerprintSha1"));
    createValues.remove(QStringLiteral("importFingerprintSizeBytes"));
    const QString historySourcePath = valueFromMap(createValues, QStringLiteral("importHistorySourcePath")).isEmpty()
        ? normalizedSourcePath
        : valueFromMap(createValues, QStringLiteral("importHistorySourcePath"));
    const QString historySourceType = valueFromMap(createValues, QStringLiteral("importHistorySourceType")).isEmpty()
        ? QStringLiteral("archive")
        : valueFromMap(createValues, QStringLiteral("importHistorySourceType"));
    FingerprintSnapshot importSourceFingerprint;
    QString importSourceFingerprintError;
    if (computeImportSourceFingerprint(
            historySourcePath,
            historySourceType,
            importSourceFingerprint,
            importSourceFingerprintError)) {
        createValues.insert(QStringLiteral("importFingerprintSha1"), importSourceFingerprint.sha1);
        createValues.insert(QStringLiteral("importFingerprintSizeBytes"), importSourceFingerprint.sizeBytes);
    }

    QString finalFilename = targetFilename;
    QString finalFilePath = seriesDir.filePath(finalFilename);
    bool createdArchiveFile = false;

    const QString sourceCanonicalPath = sourceInfo.canonicalFilePath();
    const QFileInfo targetInfo(finalFilePath);
    const QString targetCanonicalPath = targetInfo.exists() ? targetInfo.canonicalFilePath() : QString();
    const bool sameFile = !sourceCanonicalPath.isEmpty()
        && !targetCanonicalPath.isEmpty()
        && sourceCanonicalPath.compare(targetCanonicalPath, Qt::CaseInsensitive) == 0;

    if (!sameFile) {
        const QString plannedLibraryFilePath = QDir::toNativeSeparators(QFileInfo(finalFilePath).absoluteFilePath());
        const QString duplicateConnectionName = QStringLiteral("comic_pile_import_duplicate_%1")
            .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
        const ScopedSqlConnectionRemoval cleanupDuplicateConnection(duplicateConnectionName);
        QString duplicateOpenError;
        QSqlDatabase duplicateDb;
        if (!openDatabaseConnection(duplicateDb, duplicateConnectionName, duplicateOpenError)) {
            setOutError("duplicate_check_failed", duplicateOpenError);
            return duplicateOpenError;
        }

        const QString candidateSeries = valueFromMap(createValues, QStringLiteral("series"));
        const QString candidateSeriesKey = ComicImportMatching::normalizeSeriesKey(candidateSeries);
        const QString candidateVolume = valueFromMap(createValues, QStringLiteral("volume"));
        const QString candidateVolumeKey = ComicImportMatching::normalizeVolumeKey(candidateVolume);
        QString candidateIssue = valueFromMap(createValues, QStringLiteral("issueNumber"), QStringLiteral("issue"));
        if (candidateIssue.isEmpty()) {
            candidateIssue = ComicImportMatching::guessIssueNumberFromFilename(sourceInfo.fileName());
        }
        const QString candidateIssueKey = ComicImportMatching::normalizeIssueKey(candidateIssue);
        const QString strictTargetSignature = ComicImportMatching::normalizeFilenameSignatureStrict(targetFilename);
        const QString looseTargetSignature = ComicImportMatching::normalizeFilenameSignatureLoose(targetFilename);
        const bool relaxWeakLiveDuplicateChecks = hasNarrowImportSeriesContext(createValues, candidateSeriesKey);

        QString liveDuplicateError;
        const LiveDuplicateCheckResult liveDuplicate = evaluateLiveDuplicateForImport(
            duplicateDb,
            plannedLibraryFilePath,
            candidateSeriesKey,
            candidateVolumeKey,
            candidateIssueKey,
            candidateVolume,
            candidateIssue,
            strictTargetSignature,
            looseTargetSignature,
            relaxWeakLiveDuplicateChecks,
            liveDuplicateError
        );
        duplicateDb.close();
        if (!liveDuplicateError.isEmpty()) {
            setOutError(QStringLiteral("duplicate_check_failed"), liveDuplicateError);
            return liveDuplicateError;
        }
        if (liveDuplicate.hasMatch() && (!allowImportAsNew || liveDuplicate.tier == ImportDuplicateClassifier::Tier::Exact)) {
            m_lastImportAction = QStringLiteral("duplicate");
            m_lastImportDuplicateId = liveDuplicate.candidate.id;
            m_lastImportDuplicateTier = ImportDuplicateClassifier::tierKey(liveDuplicate.tier);
            QString duplicateError = QStringLiteral("Issue already exists in DB (id %1). Use replace instead.").arg(liveDuplicate.candidate.id);
            if (liveDuplicate.tier == ImportDuplicateClassifier::Tier::VeryLikely) {
                duplicateError = QStringLiteral("Likely duplicate issue found in DB (id %1).").arg(liveDuplicate.candidate.id);
            } else if (liveDuplicate.tier == ImportDuplicateClassifier::Tier::Weak) {
                duplicateError = QStringLiteral("Suspicious duplicate issue found in DB (id %1).").arg(liveDuplicate.candidate.id);
            }
            setOutError(QStringLiteral("duplicate"), duplicateError);
            if (outResult) {
                outResult->insert(QStringLiteral("existingId"), liveDuplicate.candidate.id);
                outResult->insert(QStringLiteral("duplicateTier"), ImportDuplicateClassifier::tierKey(liveDuplicate.tier));
                outResult->insert(QStringLiteral("sourcePath"), normalizedSourcePath);
            }
            return duplicateError;
        }

        if (targetInfo.exists()) {
            finalFilename = ComicLibraryLayout::makeUniqueFilename(seriesDir, targetFilename);
            finalFilePath = seriesDir.filePath(finalFilename);
        }

        QString normalizeError;
        if (!normalizeArchiveToCbz(sourceInfo.absoluteFilePath(), finalFilePath, normalizeError)) {
            setOutError("archive_normalize_failed", normalizeError);
            return normalizeError;
        }
        createdArchiveFile = true;
    }

    const QString finalRelativePath = QDir(libraryPath).relativeFilePath(finalFilePath);
    const QString createError = createComicFromLibrary(finalRelativePath, createValues);
    if (!createError.isEmpty()) {
        if (createdArchiveFile) {
            QFile copiedArchive(finalFilePath);
            copiedArchive.remove();
            ComicDeleteOps::cleanupEmptyLibraryDirs(libraryPath, { QFileInfo(finalFilePath).absolutePath() });
        }

        if (m_lastImportAction == QString("duplicate") && m_lastImportDuplicateId > 0) {
            if (outResult) {
                outResult->clear();
                outResult->insert("ok", false);
                outResult->insert("code", "duplicate");
                outResult->insert("error", createError);
                outResult->insert("existingId", m_lastImportDuplicateId);
                outResult->insert("duplicateTier", m_lastImportDuplicateTier);
                outResult->insert("sourcePath", normalizedSourcePath);
            }
        } else if (m_lastImportAction == QStringLiteral("restore_conflict")) {
            if (outResult) {
                outResult->clear();
                outResult->insert("ok", false);
                outResult->insert("code", "restore_conflict");
                outResult->insert("error", createError);
                outResult->insert("restoreCandidateCount", m_lastImportRestoreCandidateCount);
                outResult->insert("sourcePath", normalizedSourcePath);
            }
        } else if (m_lastImportAction == QStringLiteral("restore_review_required")) {
            if (outResult) {
                outResult->clear();
                outResult->insert("ok", false);
                outResult->insert("code", "restore_review_required");
                outResult->insert("error", createError);
                outResult->insert("restoreCandidateCount", m_lastImportRestoreCandidateCount);
                if (m_lastImportRestoreCandidateId > 0) {
                    outResult->insert("existingId", m_lastImportRestoreCandidateId);
                }
                outResult->insert("sourcePath", normalizedSourcePath);
            }
        } else {
            setOutError("create_issue_failed", createError);
        }
        return createError;
    }

    const QString action = m_lastImportAction.trimmed().isEmpty()
        ? QString("created")
        : m_lastImportAction;
    const int importedComicId = m_lastImportComicId;
    setOutSuccess(action, importedComicId, finalFilename, finalFilePath, createdArchiveFile, normalizedSourcePath);

    QVariantList fingerprintHistoryIds;
    {
        QString historySourceLabel = valueFromMap(createValues, QStringLiteral("importHistorySourceLabel"));
        if (historySourceLabel.isEmpty()) {
            historySourceLabel = QFileInfo(historySourcePath).fileName().trimmed();
        }

        const QString seriesKeyForHistory = normalizeSeriesKey(valueFromMap(createValues, QStringLiteral("series")));
        const QString fingerprintEvent = action == QStringLiteral("restored")
            ? QStringLiteral("import_restored")
            : QStringLiteral("import_created");
        QVector<FingerprintHistoryEntrySpec> fingerprintEntries;

        FingerprintSnapshot sourceFingerprint;
        QString sourceFingerprintError;
        if (loadFingerprintSnapshotFromValues(
                createValues,
                QStringLiteral("importFingerprintSha1"),
                QStringLiteral("importFingerprintSizeBytes"),
                sourceFingerprint)
            || computeImportSourceFingerprint(historySourcePath, historySourceType, sourceFingerprint, sourceFingerprintError)) {
            appendFingerprintHistoryEntry(
                fingerprintEntries,
                importedComicId,
                seriesKeyForHistory,
                fingerprintEvent,
                historySourceType,
                QStringLiteral("source"),
                sourceFingerprint,
                historySourceLabel
            );
        }

        FingerprintSnapshot libraryFingerprint;
        QString libraryFingerprintError;
        if (computeFileFingerprint(finalFilePath, libraryFingerprint, libraryFingerprintError)) {
            appendFingerprintHistoryEntry(
                fingerprintEntries,
                importedComicId,
                seriesKeyForHistory,
                fingerprintEvent,
                QStringLiteral("archive"),
                QStringLiteral("library"),
                libraryFingerprint,
                finalFilename
            );
        }

        insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, &fingerprintHistoryIds);
        if (outResult && !fingerprintHistoryIds.isEmpty()) {
            outResult->insert(QStringLiteral("fingerprintHistoryIds"), fingerprintHistoryIds);
        }
    }

    if (importedComicId > 0) {
        ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, importedComicId);
        m_readerArchivePathById.insert(importedComicId, QDir::toNativeSeparators(QFileInfo(finalFilePath).absoluteFilePath()));
        m_readerImageEntriesById.remove(importedComicId);
        m_readerPageMetricsById.remove(importedComicId);
        if (!deferReload) {
            requestIssueThumbnailAsync(importedComicId);
        }
    }

    return {};
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
