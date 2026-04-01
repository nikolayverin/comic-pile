#include "storage/comicslistmodel.h"
#include "storage/archivepacking.h"
#include "storage/archiveprocessutils.h"
#include "storage/archivesupportutils.h"
#include "storage/comicinfoarchive.h"
#include "storage/comicinfoops.h"
#include "storage/deletestagingops.h"
#include "storage/duplicaterestoreresolver.h"
#include "storage/importduplicateclassifier.h"
#include "storage/importmatching.h"
#include "storage/importworkflowutils.h"
#include "storage/imagepreparationops.h"
#include "storage/issuefileops.h"
#include "storage/librarylayoututils.h"
#include "storage/libraryqueryops.h"
#include "storage/libraryschemamanager.h"
#include "storage/readercacheutils.h"
#include "storage/readerpayloadutils.h"
#include "storage/readerrequestutils.h"
#include "storage/readersessionops.h"
#include "storage/datarootsettingsutils.h"
#include "storage/sqliteconnectionutils.h"
#include "storage/startupruntimeutils.h"
#include "storage/storedpathutils.h"
#include "common/scopedsqlconnectionremoval.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <QCollator>
#include <QClipboard>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImageReader>
#include <QImageWriter>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSaveFile>
#include <QStringList>
#include <QTimer>
#include <QTransform>
#include <QUuid>
#include <QtConcurrent>
#include <QtGlobal>
#include <QtMath>

namespace {

QString buildSeriesGroupKey(const QString &series, const QString &volume)
{
    const QString normalizedSeriesKey = ComicImportMatching::normalizeSeriesKey(series);
    const QString volumeGroupKey = ComicImportMatching::normalizeVolumeKey(volume);
    if (volumeGroupKey == QStringLiteral("__no_volume__")) {
        return normalizedSeriesKey;
    }
    return QStringLiteral("%1::vol::%2").arg(normalizedSeriesKey, volumeGroupKey);
}

void appendLaunchTimelineEventForDataRoot(const QString &dataRoot, const QString &message)
{
    ComicStartupRuntime::appendLaunchTimelineEventForDataRoot(dataRoot, message);
}

QString normalizeSeriesKeyValue(const QString &value)
{
    return ComicImportMatching::normalizeSeriesKey(value);
}

QString normalizeVolumeKeyValue(const QString &value)
{
    return ComicImportMatching::normalizeVolumeKey(value);
}

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString normalizeInputFilePath(const QString &rawInput);

QString valueFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toString().trimmed();
}

QString valueFromMap(const QVariantMap &map, const QString &primary, const QString &fallback)
{
    const QString primaryValue = valueFromMap(map, primary);
    if (!primaryValue.isEmpty()) return primaryValue;
    return valueFromMap(map, fallback);
}

QString validateArchiveImageEntries(const QString &archivePath)
{
    QStringList entries;
    QString errorText;
    if (!ComicInfoArchive::listImageEntriesInArchive(archivePath, entries, errorText)) {
        return errorText.trimmed();
    }
    if (entries.isEmpty()) {
        return QStringLiteral("No image pages found in archive.");
    }
    return {};
}

QString archiveValidationCode(const QString &errorText)
{
    return errorText == QStringLiteral("No image pages found in archive.")
        ? QStringLiteral("archive_has_no_images")
        : QStringLiteral("archive_validation_failed");
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

using DeleteFailureInfo = ComicDeleteOps::DeleteFailureInfo;

DeleteFailureInfo makeDeleteFailureInfo(
    const QString &rawPath,
    QFileDevice::FileError error,
    const QString &systemMessage
)
{
    return ComicDeleteOps::makeDeleteFailureInfo(rawPath, error, systemMessage);
}

QString formatDeleteFailureText(const DeleteFailureInfo &info)
{
    return ComicDeleteOps::formatDeleteFailureLine(info);
}

QString sevenZipMissingMessage()
{
    return ComicArchiveSupport::sevenZipMissingMessage();
}

bool tryRemoveFileWithDetails(
    const QString &filePath,
    QString &removedDirPathOut,
    DeleteFailureInfo &failureOut
)
{
    return ComicDeleteOps::tryRemoveFileWithDetails(filePath, removedDirPathOut, failureOut);
}

QString monthNameForNumber(int month)
{
    static const QStringList kMonthNames = {
        QStringLiteral("January"),
        QStringLiteral("February"),
        QStringLiteral("March"),
        QStringLiteral("April"),
        QStringLiteral("May"),
        QStringLiteral("June"),
        QStringLiteral("July"),
        QStringLiteral("August"),
        QStringLiteral("September"),
        QStringLiteral("October"),
        QStringLiteral("November"),
        QStringLiteral("December")
    };

    if (month < 1 || month > 12) return {};
    return kMonthNames.at(month - 1);
}

struct ReloadValidationInputRow {
    int id = 0;
    QString filePath;
};

struct ReloadValidationResult {
    int generation = 0;
    qint64 elapsedMs = 0;
    QHash<int, QString> normalizedPaths;
    QSet<int> invalidIds;
};

QString normalizeInputFilePath(const QString &rawInput)
{
    return ComicStoragePaths::normalizePathInput(rawInput);
}

QString fastResolveStoredFilePath(
    const QString &dataRoot,
    const QString &libraryPath,
    const QString &storedFilePath,
    const QString &storedFilename
)
{
    Q_UNUSED(libraryPath);
    return ComicStoragePaths::resolveStoredArchivePath(dataRoot, storedFilePath, storedFilename);
}

ReloadValidationResult validateReloadRowsAsync(
    int generation,
    const QVector<ReloadValidationInputRow> &rows
)
{
    QElapsedTimer timer;
    timer.start();

    ReloadValidationResult result;
    result.generation = generation;

    for (const ReloadValidationInputRow &row : rows) {
        if (row.id < 1) continue;
        const QString normalizedPath = normalizeInputFilePath(row.filePath);
        if (normalizedPath.isEmpty()) {
            result.invalidIds.insert(row.id);
            continue;
        }

        const QFileInfo info(normalizedPath);
        if (!info.exists() || !info.isFile()) {
            result.invalidIds.insert(row.id);
            continue;
        }

        result.normalizedPaths.insert(row.id, QDir::toNativeSeparators(info.absoluteFilePath()));
    }

    result.elapsedMs = timer.elapsed();
    return result;
}

bool filePathExists(const QString &filePath);

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

QString guessIssueNumberFromFilename(const QString &filename)
{
    return ComicImportMatching::guessIssueNumberFromFilename(filename);
}

QString guessSeriesFromFilename(const QString &filename)
{
    return ComicImportMatching::guessSeriesFromFilename(filename);
}

bool isWeakSeriesName(const QString &seriesName)
{
    return ComicImportMatching::isWeakSeriesName(seriesName);
}

QString normalizeFilenameSignatureStrict(const QString &filename)
{
    return ComicImportMatching::normalizeFilenameSignatureStrict(filename);
}

QString normalizeFilenameSignatureLoose(const QString &filename)
{
    return ComicImportMatching::normalizeFilenameSignatureLoose(filename);
}

QString normalizeIssueKey(const QString &issueValue)
{
    return ComicImportMatching::normalizeIssueKey(issueValue);
}

QString normalizedMetadataTextKey(const QString &value)
{
    return value.trimmed().toLower();
}

bool optionalMetadataTextConflict(const QString &input, const QString &candidate)
{
    const QString left = normalizedMetadataTextKey(input);
    const QString right = normalizedMetadataTextKey(candidate);
    return !left.isEmpty() && !right.isEmpty() && left != right;
}

int metadataTextMatchScore(const QString &input, const QString &candidate, int weight)
{
    const QString left = normalizedMetadataTextKey(input);
    const QString right = normalizedMetadataTextKey(candidate);
    if (left.isEmpty() || right.isEmpty() || left != right) {
        return 0;
    }
    return weight;
}

bool filePathExists(const QString &filePath)
{
    const QString normalized = QDir::toNativeSeparators(filePath.trimmed());
    if (normalized.isEmpty()) return false;
    const QFileInfo info(normalized);
    return info.exists() && info.isFile();
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
        candidate.strictFilenameSignature = normalizeFilenameSignatureStrict(candidate.filename);
        candidate.looseFilenameSignature = normalizeFilenameSignatureLoose(candidate.filename);
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

bool isSupportedArchiveExtension(const QString &path);

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

QString normalizeArchiveExtension(const QString &pathOrExtension)
{
    return ComicArchiveSupport::normalizeArchiveExtension(pathOrExtension);
}

QString resolve7ZipExecutableFromHint(const QString &hintPath)
{
    return ComicArchiveSupport::resolve7ZipExecutableFromHint(hintPath);
}

const QSet<QString> &nativeImportArchiveExtensions()
{
    return ComicArchiveSupport::nativeImportArchiveExtensions();
}

const QSet<QString> &documentImportExtensions()
{
    return ComicArchiveSupport::documentImportExtensions();
}

const QSet<QString> &fallbackSevenZipArchiveExtensions()
{
    return ComicArchiveSupport::fallbackSevenZipArchiveExtensions();
}

QString resolveDjVuExecutableFromHint(const QString &hintPath)
{
    return ComicArchiveSupport::resolveDjVuExecutableFromHint(hintPath);
}

QString resolveDjVuExecutable()
{
    return ComicArchiveSupport::resolveDjVuExecutable();
}

bool isPdfExtension(const QString &extension)
{
    return ComicArchiveSupport::isPdfExtension(extension);
}

bool isDjvuExtension(const QString &extension)
{
    return ComicArchiveSupport::isDjvuExtension(extension);
}

QString djvuBackendMissingMessage()
{
    return ComicArchiveSupport::djvuMissingMessage();
}

QSet<QString> supportedImportArchiveExtensionsSet()
{
    return ComicArchiveSupport::declaredImportArchiveExtensions();
}

QString formatSupportedArchiveList()
{
    return ComicArchiveSupport::formatDeclaredSupportedArchiveList();
}

QString buildImportArchiveDialogFilter()
{
    return ComicArchiveSupport::buildDeclaredImportArchiveDialogFilter();
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

QString resolveStoredSeriesHeaderPath(const QString &dataRoot, const QString &storedPath)
{
    return ComicStoragePaths::resolveStoredPathAgainstRoot(dataRoot, storedPath);
}

QString relativePathWithinDataRoot(const QString &dataRoot, const QString &absolutePath)
{
    return ComicStoragePaths::persistPathForDataRoot(dataRoot, absolutePath);
}

bool isImportArchiveExtensionSupported(const QString &extension)
{
    return ComicArchiveSupport::isDeclaredImportArchiveExtensionSupported(extension);
}

bool isSevenZipExtension(const QString &extension)
{
    return ComicArchiveSupport::isDeclaredSevenZipExtension(extension);
}

bool isSupportedArchiveExtension(const QString &path)
{
    return ComicArchiveSupport::isDeclaredSupportedArchivePath(path);
}

QString formatSeriesGroupTitle(const QString &series, const QString &volume)
{
    const QString baseTitle = series.trimmed().isEmpty()
        ? QString("Unknown Series")
        : series.trimmed();

    QString volumeText = volume.trimmed();
    if (volumeText.isEmpty()) return baseTitle;

    volumeText.remove(QRegularExpression("^vol(?:ume)?\\.?\\s*", QRegularExpression::CaseInsensitiveOption));
    volumeText = volumeText.trimmed();
    if (volumeText.isEmpty()) {
        volumeText = volume.trimmed();
    }

    return QString("%1 - Vol. %2").arg(baseTitle, volumeText);
}

QString resolve7ZipExecutable()
{
    return ComicArchiveSupport::resolve7ZipExecutable();
}

QString readTrimmedTextFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    const QString raw = QString::fromUtf8(file.readAll()).trimmed();
    if (raw.isEmpty()) return {};
    const QStringList lines = raw.split(QRegularExpression("[\\r\\n]+"), Qt::SkipEmptyParts);
    if (lines.isEmpty()) return {};
    return lines.first().trimmed();
}

QString normalizedPathForCompare(const QString &path)
{
    return ComicLibraryLayout::normalizedPathForCompare(path);
}

bool isPathInsideDirectory(const QString &candidatePath, const QString &directoryPath)
{
    const QString base = normalizedPathForCompare(directoryPath);
    const QString candidate = normalizedPathForCompare(candidatePath);
    if (base.isEmpty() || candidate.isEmpty()) return false;
    if (candidate == base) return true;
    return candidate.startsWith(base + QString("/"));
}

bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText)
{
    return ComicLibraryLayout::moveFileWithFallback(sourcePath, targetPath, errorText);
}

using StagedArchiveDeleteOp = ComicDeleteOps::StagedArchiveDeleteOp;

void cleanupEmptyLibraryDirs(const QString &libraryRootPath, const QStringList &candidateDirs)
{
    ComicDeleteOps::cleanupEmptyLibraryDirs(libraryRootPath, candidateDirs);
}


} // namespace

ComicsListModel::ComicsListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_dataRoot = resolveDataRoot();
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_ctor_begin"));
    m_dbPath = QDir(m_dataRoot).filePath("library.db");
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_paths_ready"));
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_services_ready"));
    ComicImportRuntime::resetOutcome(m_importState);
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_schema_check_begin"));
    const QString schemaError = LibrarySchemaManager(m_dbPath).ensureSchemaUpToDate();
    if (!schemaError.isEmpty()) {
        appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_schema_check_failed"));
        m_lastError = schemaError;
        m_lastMutationKind = QStringLiteral("schema_migration");
        appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_ctor_end"));
        return;
    }
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_schema_check_end"));
    ComicDeleteOps::cleanupPendingStagedDeletes(
        m_dataRoot,
        QDir(m_dataRoot).filePath(QStringLiteral("Library"))
    );
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_ctor_end"));
}

int ComicsListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_rows.size();
}

QVariant ComicsListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size()) {
        return {};
    }

    const ComicRow &row = m_rows.at(index.row());
    switch (role) {
    case IdRole:
        return row.id;
    case FilenameRole:
        return row.filename;
    case SeriesRole:
        return row.series;
    case SeriesGroupKeyRole:
        return row.seriesGroupKey;
    case SeriesGroupTitleRole:
        return row.seriesGroupTitle;
    case VolumeGroupKeyRole:
        return row.volumeGroupKey;
    case VolumeRole:
        return row.volume;
    case TitleRole:
        return row.title;
    case IssueNumberRole:
        return row.issueNumber;
    case PublisherRole:
        return row.publisher;
    case YearRole:
        return row.year > 0 ? row.year : QVariant();
    case MonthRole:
        return row.month > 0 ? row.month : QVariant();
    case MonthNameRole:
        return monthNameForNumber(row.month);
    case WriterRole:
        return row.writer;
    case PencillerRole:
        return row.penciller;
    case InkerRole:
        return row.inker;
    case ColoristRole:
        return row.colorist;
    case LettererRole:
        return row.letterer;
    case CoverArtistRole:
        return row.coverArtist;
    case EditorRole:
        return row.editor;
    case StoryArcRole:
        return row.storyArc;
    case SummaryRole:
        return row.summary;
    case CharactersRole:
        return row.characters;
    case GenresRole:
        return row.genres;
    case AgeRatingRole:
        return row.ageRating;
    case ReadStatusRole:
        return row.readStatus;
    case CurrentPageRole:
        return row.currentPage;
    case BookmarkPageRole:
        return row.bookmarkPage;
    case HasBookmarkRole:
        return row.bookmarkPage > 0;
    case HasFavoriteRole:
        return row.favoriteActive;
    case AddedDateRole:
        return row.addedDate;
    case DisplayTitleRole:
        if (!row.series.isEmpty()) return row.series;
        if (!row.title.isEmpty()) return row.title;
        return baseNameWithoutExtension(row.filename);
    case DisplaySubtitleRole:
        return buildSubtitle(row);
    default:
        return {};
    }
}

QHash<int, QByteArray> ComicsListModel::roleNames() const
{
    return {
        { IdRole, "id" },
        { FilenameRole, "filename" },
        { SeriesRole, "series" },
        { SeriesGroupKeyRole, "seriesGroupKey" },
        { SeriesGroupTitleRole, "seriesGroupTitle" },
        { VolumeGroupKeyRole, "volumeGroupKey" },
        { VolumeRole, "volume" },
        { TitleRole, "title" },
        { IssueNumberRole, "issueNumber" },
        { PublisherRole, "publisher" },
        { YearRole, "year" },
        { MonthRole, "month" },
        { MonthNameRole, "monthName" },
        { WriterRole, "writer" },
        { PencillerRole, "penciller" },
        { InkerRole, "inker" },
        { ColoristRole, "colorist" },
        { LettererRole, "letterer" },
        { CoverArtistRole, "coverArtist" },
        { EditorRole, "editor" },
        { StoryArcRole, "storyArc" },
        { SummaryRole, "summary" },
        { CharactersRole, "characters" },
        { GenresRole, "genres" },
        { AgeRatingRole, "ageRating" },
        { ReadStatusRole, "readStatus" },
        { CurrentPageRole, "currentPage" },
        { BookmarkPageRole, "bookmarkPage" },
        { HasBookmarkRole, "hasBookmark" },
        { HasFavoriteRole, "hasFavorite" },
        { AddedDateRole, "addedDate" },
        { DisplayTitleRole, "displayTitle" },
        { DisplaySubtitleRole, "displaySubtitle" },
    };
}

QString ComicsListModel::dataRoot() const
{
    return m_dataRoot;
}

QString ComicsListModel::dbPath() const
{
    return m_dbPath;
}

QString ComicsListModel::lastError() const
{
    return m_lastError;
}

QString ComicsListModel::lastMutationKind() const
{
    return m_lastMutationKind;
}

int ComicsListModel::totalCount() const
{
    return m_rows.size();
}

void ComicsListModel::reload()
{
    QElapsedTimer reloadTimer;
    reloadTimer.start();

    beginResetModel();
    m_rows.clear();
    m_readerState.archivePathById.clear();
    m_readerState.imageEntriesById.clear();
    m_readerState.pageMetricsById.clear();
    m_importState.deferredFolderBySeriesKey.clear();
    invalidateAllReaderAsyncState();

    const QFileInfo dbInfo(m_dbPath);
    if (!dbInfo.exists() || !dbInfo.isFile()) {
        m_lastError = QString("Database file not found: %1").arg(m_dbPath);
        m_lastMutationKind = QString("reload");
        endResetModel();
        emit statusChanged();
        return;
    }

    QString loadError;
    int loadedRowCount = 0;
    QVector<ComicLibraryQueries::ComicRecord> records;
    if (ComicLibraryQueries::loadComicRecords(m_dbPath, records, loadError)) {
        const QString libraryPath = QDir(m_dataRoot).filePath(QStringLiteral("Library"));
        for (const ComicLibraryQueries::ComicRecord &record : records) {
            ComicRow row;
            row.id = record.id;
            row.filePath = record.filePath;
            row.filename = record.filename;
            row.series = record.series;
            row.volume = record.volume;
            row.volumeGroupKey = normalizeVolumeKey(row.volume);
            row.title = record.title;
            row.issueNumber = record.issueNumber;
            row.publisher = record.publisher;
            row.year = record.year;
            row.month = record.month;
            row.writer = record.writer;
            row.penciller = record.penciller;
            row.inker = record.inker;
            row.colorist = record.colorist;
            row.letterer = record.letterer;
            row.coverArtist = record.coverArtist;
            row.editor = record.editor;
            row.storyArc = record.storyArc;
            row.summary = record.summary;
            row.characters = record.characters;
            row.genres = record.genres;
            row.ageRating = record.ageRating;
            row.readStatus = normalizeReadStatus(record.readStatus);
            if (row.readStatus.isEmpty()) row.readStatus = QString("unread");
            row.currentPage = record.currentPage;
            row.bookmarkPage = record.bookmarkPage;
            row.bookmarkAddedAt = record.bookmarkAddedAt;
            row.favoriteActive = record.favoriteActive;
            row.favoriteAddedAt = record.favoriteAddedAt;
            row.addedDate = record.addedDate;

            const QString resolvedPath = fastResolveStoredFilePath(m_dataRoot, libraryPath, row.filePath, row.filename);
            if (resolvedPath.isEmpty()) {
                ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, row.id);
                continue;
            }
            row.filePath = resolvedPath;

            const QString normalizedSeriesKey = normalizeSeriesKey(row.series);
            if (row.volumeGroupKey == QString("__no_volume__")) {
                row.seriesGroupKey = normalizedSeriesKey;
            } else {
                row.seriesGroupKey = QString("%1::vol::%2").arg(normalizedSeriesKey, row.volumeGroupKey);
            }
            row.seriesGroupTitle = formatSeriesGroupTitle(row.series, row.volume);
            m_rows.push_back(row);
            loadedRowCount += 1;
        }
    }
    std::sort(m_rows.begin(), m_rows.end(), [this](const ComicRow &left, const ComicRow &right) {
        return compareRows(left, right) < 0;
    });

    m_lastError = loadError;
    m_lastMutationKind = QString("reload");
    endResetModel();
    emit statusChanged();

    const int validationGeneration = ++m_reloadValidationGeneration;
    QVector<ReloadValidationInputRow> validationRows;
    validationRows.reserve(m_rows.size());
    for (const ComicRow &row : m_rows) {
        validationRows.push_back({ row.id, row.filePath });
    }
    auto *watcher = new QFutureWatcher<ReloadValidationResult>(this);
    connect(watcher, &QFutureWatcher<ReloadValidationResult>::finished, this, [this, watcher]() {
        const ReloadValidationResult result = watcher->result();
        watcher->deleteLater();

        if (result.generation != m_reloadValidationGeneration) return;
        if (m_rows.isEmpty()) return;

        bool changed = false;
        QVector<ComicRow> filteredRows;
        filteredRows.reserve(m_rows.size());

        for (ComicRow row : m_rows) {
            if (result.invalidIds.contains(row.id)) {
                ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, row.id);
                changed = true;
                continue;
            }

            const auto normalizedPathIt = result.normalizedPaths.constFind(row.id);
            if (normalizedPathIt == result.normalizedPaths.constEnd()) {
                ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, row.id);
                changed = true;
                continue;
            }

            const QString normalizedPath = normalizedPathIt.value();
            if (row.filePath != normalizedPath) {
                row.filePath = normalizedPath;
                changed = true;
            }

            filteredRows.push_back(row);
        }

        if (!changed) {
            return;
        }

        beginResetModel();
        m_rows = filteredRows;
        m_readerState.archivePathById.clear();
        m_readerState.imageEntriesById.clear();
        m_readerState.pageMetricsById.clear();
        invalidateAllReaderAsyncState();
        endResetModel();
        emit statusChanged();
    });
    watcher->setFuture(QtConcurrent::run([validationGeneration, validationRows]() {
        return validateReloadRowsAsync(validationGeneration, validationRows);
    }));
}

bool ComicsListModel::normalizeArchiveToCbz(
    const QString &sourceArchivePath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    return ComicArchivePacking::normalizeArchiveToCbz(sourceArchivePath, targetCbzPath, errorText);
}

bool ComicsListModel::createCbzFromDirectory(
    const QString &sourceDirPath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    return ComicArchivePacking::createCbzFromDirectory(sourceDirPath, targetCbzPath, errorText);
}

bool ComicsListModel::packageImageFolderToCbz(
    const QString &folderPath,
    const QString &targetCbzPath,
    QString &errorText
)
{
    return ComicArchivePacking::packageImageFolderToCbz(folderPath, targetCbzPath, errorText);
}

QVariantList ComicsListModel::seriesGroups() const
{
    QVariantList groups;
    QHash<QString, int> indexByKey;

    for (const ComicRow &row : m_rows) {
        const QString key = row.seriesGroupKey;
        if (key.isEmpty()) continue;

        const auto found = indexByKey.constFind(key);
        if (found == indexByKey.constEnd()) {
            QVariantMap group;
            group.insert("seriesKey", key);
            group.insert("seriesTitle", row.seriesGroupTitle);
            group.insert("count", 1);
            groups.push_back(group);
            indexByKey.insert(key, groups.size() - 1);
            continue;
        }

        QVariantMap group = groups.at(found.value()).toMap();
        group.insert("count", group.value("count").toInt() + 1);
        groups[found.value()] = group;
    }

    return groups;
}

QVariantList ComicsListModel::volumeGroupsForSeries(const QString &seriesKey) const
{
    struct VolumeGroup {
        QString key;
        QString title;
        int count = 0;
    };

    QVariantList groups;
    QVector<VolumeGroup> collected;
    QHash<QString, int> indexByKey;
    const QString requestedSeriesKey = seriesKey.trimmed();
    if (requestedSeriesKey.isEmpty()) return groups;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;

        const QString key = row.volumeGroupKey;
        const QString title = row.volume.trimmed().isEmpty()
            ? QString("No Volume")
            : row.volume.trimmed();

        const auto found = indexByKey.constFind(key);
        if (found == indexByKey.constEnd()) {
            VolumeGroup group;
            group.key = key;
            group.title = title;
            group.count = 1;
            indexByKey.insert(key, collected.size());
            collected.push_back(group);
            continue;
        }

        VolumeGroup &group = collected[found.value()];
        group.count += 1;
    }

    std::sort(collected.begin(), collected.end(), [](const VolumeGroup &left, const VolumeGroup &right) {
        if (left.key == QString("__no_volume__")) return right.key != QString("__no_volume__");
        if (right.key == QString("__no_volume__")) return false;

        const int byTitle = compareNaturalText(left.title, right.title);
        if (byTitle != 0) return byTitle < 0;
        return compareText(left.key, right.key) < 0;
    });

    groups.reserve(collected.size());
    for (const VolumeGroup &group : collected) {
        QVariantMap item;
        item.insert("volumeKey", group.key);
        item.insert("volumeTitle", group.title);
        item.insert("count", group.count);
        groups.push_back(item);
    }

    return groups;
}

QVariantList ComicsListModel::issuesForSeries(
    const QString &seriesKey,
    const QString &volumeKey,
    const QString &readStatusFilter,
    const QString &searchText
) const
{
    QVariantList result;

    const QString requestedSeriesKey = seriesKey.trimmed();
    if (requestedSeriesKey.isEmpty()) return result;

    const QString requestedVolumeKey = volumeKey.trimmed().isEmpty()
        ? QString("__all__")
        : volumeKey.trimmed();
    const QString normalizedStatusFilter = normalizeReadStatus(readStatusFilter);
    const bool filterByReadStatus = readStatusFilter.trimmed().compare(QString("all"), Qt::CaseInsensitive) != 0
        && !normalizedStatusFilter.isEmpty();
    const QString searchNeedle = searchText.trimmed().toLower();

    result.reserve(m_rows.size());
    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;
        if (requestedVolumeKey != QString("__all__") && row.volumeGroupKey != requestedVolumeKey) continue;
        if (filterByReadStatus && normalizeReadStatus(row.readStatus) != normalizedStatusFilter) continue;

        if (!searchNeedle.isEmpty()) {
            const QString haystack = (
                row.title + " " + row.issueNumber + " " + row.filename + " " + row.series + " " + row.volume + " " + row.publisher + " "
                + row.writer + " " + row.penciller + " " + row.inker + " " + row.colorist + " " + row.letterer + " "
                + row.coverArtist + " " + row.editor + " " + row.storyArc + " " + row.summary + " " + row.characters + " "
                + row.genres + " " + row.ageRating
            ).toLower();
            if (!haystack.contains(searchNeedle)) continue;
        }

        QVariantMap item;
        item.insert("id", row.id);
        item.insert("series", row.series);
        item.insert("volume", row.volume);
        item.insert("title", row.title);
        item.insert("issueNumber", row.issueNumber);
        item.insert("publisher", row.publisher);
        item.insert("year", row.year);
        item.insert("month", row.month);
        item.insert("monthName", monthNameForNumber(row.month));
        item.insert("writer", row.writer);
        item.insert("penciller", row.penciller);
        item.insert("inker", row.inker);
        item.insert("colorist", row.colorist);
        item.insert("letterer", row.letterer);
        item.insert("coverArtist", row.coverArtist);
        item.insert("editor", row.editor);
        item.insert("storyArc", row.storyArc);
        item.insert("summary", row.summary);
        item.insert("characters", row.characters);
        item.insert("genres", row.genres);
        item.insert("ageRating", row.ageRating);
        item.insert("readStatus", row.readStatus);
        item.insert("currentPage", row.currentPage);
        item.insert("bookmarkPage", row.bookmarkPage);
        item.insert("hasBookmark", row.bookmarkPage > 0);
        item.insert("hasFavorite", row.favoriteActive);
        item.insert("filename", row.filename);
        result.push_back(item);
    }

    return result;
}

QVariantList ComicsListModel::issuesForQuickFilter(
    const QString &filterKey,
    const QVariantList &lastImportComicIds
) const
{
    const QString normalizedFilterKey = filterKey.trimmed().toLower();
    QVariantList result;

    auto appendIssueItem = [&](const ComicRow &row) {
        QVariantMap item;
        item.insert("id", row.id);
        item.insert("series", row.series);
        item.insert("volume", row.volume);
        item.insert("title", row.title);
        item.insert("issueNumber", row.issueNumber);
        item.insert("publisher", row.publisher);
        item.insert("year", row.year);
        item.insert("month", row.month);
        item.insert("monthName", monthNameForNumber(row.month));
        item.insert("writer", row.writer);
        item.insert("penciller", row.penciller);
        item.insert("inker", row.inker);
        item.insert("colorist", row.colorist);
        item.insert("letterer", row.letterer);
        item.insert("coverArtist", row.coverArtist);
        item.insert("editor", row.editor);
        item.insert("storyArc", row.storyArc);
        item.insert("summary", row.summary);
        item.insert("characters", row.characters);
        item.insert("genres", row.genres);
        item.insert("ageRating", row.ageRating);
        item.insert("readStatus", row.readStatus);
        item.insert("currentPage", row.currentPage);
        item.insert("bookmarkPage", row.bookmarkPage);
        item.insert("hasBookmark", row.bookmarkPage > 0);
        item.insert("hasFavorite", row.favoriteActive);
        item.insert("filename", row.filename);
        result.push_back(item);
    };

    if (normalizedFilterKey == QStringLiteral("last_import")) {
        QHash<int, const ComicRow *> rowsById;
        rowsById.reserve(m_rows.size());
        for (const ComicRow &row : m_rows) {
            rowsById.insert(row.id, &row);
        }

        QSet<int> seenIds;
        for (const QVariant &value : lastImportComicIds) {
            const int comicId = value.toInt();
            if (comicId < 1 || seenIds.contains(comicId)) continue;
            const auto found = rowsById.constFind(comicId);
            if (found == rowsById.constEnd()) continue;
            appendIssueItem(*found.value());
            seenIds.insert(comicId);
        }
        return result;
    }

    QVector<const ComicRow *> filteredRows;
    filteredRows.reserve(m_rows.size());
    for (const ComicRow &row : m_rows) {
        if (normalizedFilterKey == QStringLiteral("bookmarks")) {
            if (row.bookmarkPage <= 0) continue;
        } else if (normalizedFilterKey == QStringLiteral("favorites")) {
            if (!row.favoriteActive) continue;
        } else {
            continue;
        }
        filteredRows.push_back(&row);
    }

    auto effectiveTimestamp = [&](const ComicRow &row) -> QString {
        if (normalizedFilterKey == QStringLiteral("bookmarks")) {
            const QString bookmarkAt = row.bookmarkAddedAt.trimmed();
            if (!bookmarkAt.isEmpty()) return bookmarkAt;
        }
        if (normalizedFilterKey == QStringLiteral("favorites")) {
            const QString favoriteAt = row.favoriteAddedAt.trimmed();
            if (!favoriteAt.isEmpty()) return favoriteAt;
        }
        return row.addedDate.trimmed();
    };

    std::sort(filteredRows.begin(), filteredRows.end(), [&](const ComicRow *leftPtr, const ComicRow *rightPtr) {
        const ComicRow &left = *leftPtr;
        const ComicRow &right = *rightPtr;
        const QString leftTimestamp = effectiveTimestamp(left);
        const QString rightTimestamp = effectiveTimestamp(right);
        if (leftTimestamp != rightTimestamp) {
            return leftTimestamp > rightTimestamp;
        }
        return compareRows(left, right) < 0;
    });

    for (const ComicRow *rowPtr : filteredRows) {
        appendIssueItem(*rowPtr);
    }
    return result;
}

int ComicsListModel::quickFilterIssueCount(
    const QString &filterKey,
    const QVariantList &lastImportComicIds
) const
{
    const QString normalizedFilterKey = filterKey.trimmed().toLower();
    if (normalizedFilterKey == QStringLiteral("last_import")) {
        QSet<int> seenIds;
        int count = 0;
        for (const QVariant &value : lastImportComicIds) {
            const int comicId = value.toInt();
            if (comicId < 1 || seenIds.contains(comicId)) continue;
            for (const ComicRow &row : m_rows) {
                if (row.id != comicId) continue;
                seenIds.insert(comicId);
                count += 1;
                break;
            }
        }
        return count;
    }

    int count = 0;
    for (const ComicRow &row : m_rows) {
        if (normalizedFilterKey == QStringLiteral("bookmarks")) {
            if (row.bookmarkPage > 0) count += 1;
        } else if (normalizedFilterKey == QStringLiteral("favorites")) {
            if (row.favoriteActive) count += 1;
        }
    }
    return count;
}

QString ComicsListModel::setSortMode(const QString &sortMode)
{
    const QString normalized = sortMode.trimmed().toLower();
    if (normalized != QString("series_issue")
        && normalized != QString("title_asc")
        && normalized != QString("year_desc")
        && normalized != QString("added_desc")) {
        return QString("Unsupported sort mode.");
    }

    if (m_sortMode == normalized) return {};
    m_sortMode = normalized;
    reload();
    return {};
}


QString ComicsListModel::archivePathForComicId(int comicId) const
{
    if (comicId < 1) return {};

    const QString cachedPath = m_readerState.archivePathById.value(comicId).trimmed();
    if (!cachedPath.isEmpty()) {
        const QString resolvedCachedPath = resolveStoredArchivePathForDataRoot(
            m_dataRoot,
            cachedPath,
            QString()
        );
        return resolvedCachedPath.isEmpty() ? cachedPath : resolvedCachedPath;
    }

    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) continue;
        const QString resolvedRowPath = resolveStoredArchivePathForDataRoot(
            m_dataRoot,
            row.filePath,
            row.filename
        );
        return resolvedRowPath.isEmpty() ? row.filePath.trimmed() : resolvedRowPath;
    }

    return {};
}

QString ComicsListModel::archivePathForComic(int comicId) const
{
    return archivePathForComicId(comicId);
}

QString ComicsListModel::seriesGroupKeyForComicId(int comicId) const
{
    if (comicId < 1) return {};

    for (const ComicRow &row : m_rows) {
        if (row.id == comicId) {
            return row.seriesGroupKey.trimmed();
        }
    }

    return {};
}

int ComicsListModel::liveIssueCountForSeries(const QString &seriesKey) const
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return 0;

    int count = 0;
    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey == normalizedKey) {
            count += 1;
        }
    }
    return count;
}

QVariantMap ComicsListModel::replaceComicFileFromSourceEx(
    int comicId,
    const QString &sourcePath,
    const QString &sourceType,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("code"), QStringLiteral("replace_failed"));
    result.insert(QStringLiteral("comicId"), comicId);

    if (comicId < 1) {
        result.insert(QStringLiteral("error"), QStringLiteral("Invalid issue id."));
        return result;
    }

    const QVariantMap metadata = loadComicMetadata(comicId);
    if (metadata.contains(QStringLiteral("error"))) {
        result.insert(QStringLiteral("error"), metadata.value(QStringLiteral("error")).toString());
        return result;
    }
    QString existingFilename = metadata.value(QStringLiteral("filename")).toString().trimmed();
    const QString existingFilePath = resolveStoredArchivePathForDataRoot(
        m_dataRoot,
        metadata.value(QStringLiteral("filePath")).toString(),
        existingFilename
    );
    if (existingFilePath.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Replace failed: existing archive path is missing."));
        return result;
    }
    if (existingFilename.isEmpty()) {
        existingFilename = QFileInfo(existingFilePath).fileName().trimmed();
    }
    if (existingFilename.isEmpty()) {
        existingFilename = ComicImportWorkflow::ensureTargetCbzFilename(
            filenameHint,
            QFileInfo(sourcePath).fileName()
        );
    }
    if (existingFilename.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Replace failed: existing archive filename is missing."));
        return result;
    }

    const QString normalizedSourceType = sourceType.trimmed().toLower().isEmpty()
        ? QStringLiteral("archive")
        : sourceType.trimmed().toLower();
    const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
    QString importSourceLabel = QFileInfo(normalizedSourcePath).fileName().trimmed();
    if (importSourceLabel.isEmpty()) {
        importSourceLabel = QFileInfo(sourcePath.trimmed()).fileName().trimmed();
    }
    const ComicImportWorkflow::PersistedImportSignals previousImportSignals = ComicImportWorkflow::resolvePersistedImportSignals(
        metadata,
        existingFilename,
        QStringLiteral("archive")
    );
    const ComicImportWorkflow::PersistedImportSignals newImportSignals = ComicImportWorkflow::resolvePersistedImportSignals(
        values,
        importSourceLabel,
        normalizedSourceType
    );
    const bool keepBackupForRollback = values.value(QStringLiteral("keepBackupForRollback")).toBool();
    result.insert(QStringLiteral("sourcePath"), normalizedSourcePath);
    result.insert(QStringLiteral("sourceType"), normalizedSourceType);
    result.insert(
        QStringLiteral("previousImportSignals"),
        ComicImportWorkflow::importSignalsToVariantMap(previousImportSignals)
    );
    result.insert(
        QStringLiteral("importSignals"),
        ComicImportWorkflow::importSignalsToVariantMap(newImportSignals)
    );

    if (normalizedSourceType == QStringLiteral("archive")) {
        const QFileInfo sourceInfo(normalizedSourcePath);
        if (!sourceInfo.exists() || !sourceInfo.isFile()) {
            result.insert(QStringLiteral("code"), QStringLiteral("file_not_found"));
            result.insert(QStringLiteral("error"), QStringLiteral("Import file not found: %1").arg(sourcePath.trimmed()));
            return result;
        }

        const QString extension = normalizeArchiveExtension(sourceInfo.suffix());
        if (!isImportArchiveExtensionSupported(extension)) {
            result.insert(QStringLiteral("code"), QStringLiteral("unsupported_format"));
            result.insert(QStringLiteral("error"), QStringLiteral("Supported import formats: %1").arg(formatSupportedArchiveList()));
            return result;
        }
        if (isSevenZipExtension(extension) && !isCbrBackendAvailable()) {
            result.insert(QStringLiteral("code"), QStringLiteral("cbr_backend_missing"));
            result.insert(QStringLiteral("error"), cbrBackendMissingMessage());
            return result;
        }
        if (isDjvuExtension(extension) && resolveDjVuExecutable().isEmpty()) {
            result.insert(QStringLiteral("code"), QStringLiteral("djvu_backend_missing"));
            result.insert(QStringLiteral("error"), djvuBackendMissingMessage());
            return result;
        }

        const QString sourceCanonicalPath = sourceInfo.canonicalFilePath();
        const QFileInfo targetInfo(existingFilePath);
        const QString targetCanonicalPath = targetInfo.exists() ? targetInfo.canonicalFilePath() : QString();
        if (!sourceCanonicalPath.isEmpty()
            && !targetCanonicalPath.isEmpty()
            && sourceCanonicalPath.compare(targetCanonicalPath, Qt::CaseInsensitive) == 0) {
            result.insert(QStringLiteral("code"), QStringLiteral("same_source"));
            result.insert(QStringLiteral("error"), QStringLiteral("Replace source matches the existing archive."));
            return result;
        }

        if (!isPdfExtension(extension) && !isDjvuExtension(extension)) {
            const QString archiveValidationError = validateArchiveImageEntries(sourceInfo.absoluteFilePath());
            if (!archiveValidationError.isEmpty()) {
                result.insert(QStringLiteral("code"), archiveValidationCode(archiveValidationError));
                result.insert(QStringLiteral("error"), archiveValidationError);
                return result;
            }
        }
    } else if (normalizedSourceType == QStringLiteral("image_folder")) {
        const QFileInfo folderInfo(normalizedSourcePath);
        if (!folderInfo.exists() || !folderInfo.isDir()) {
            result.insert(QStringLiteral("code"), QStringLiteral("folder_not_found"));
            result.insert(QStringLiteral("error"), QStringLiteral("Image folder not found: %1").arg(sourcePath.trimmed()));
            return result;
        }
        if (listSupportedImageFilesInFolder(normalizedSourcePath).isEmpty()) {
            result.insert(QStringLiteral("code"), QStringLiteral("image_folder_empty"));
            result.insert(QStringLiteral("error"), QStringLiteral("No supported image files found in folder: %1")
                .arg(QDir::toNativeSeparators(folderInfo.absoluteFilePath())));
            return result;
        }
    } else {
        result.insert(QStringLiteral("code"), QStringLiteral("unsupported_source_type"));
        result.insert(QStringLiteral("error"), QStringLiteral("Unsupported import source type: %1").arg(sourceType.trimmed()));
        return result;
    }

    StagedArchiveDeleteOp stagedDelete;
    DeleteFailureInfo stageFailure;
    if (!ComicDeleteOps::stageArchiveDelete(existingFilePath, stagedDelete, stageFailure)) {
        result.insert(QStringLiteral("code"), QStringLiteral("replace_stage_failed"));
        result.insert(QStringLiteral("error"), formatDeleteFailureText(stageFailure));
        return result;
    }

    auto rollbackStage = [&]() -> QString {
        return rollbackStagedArchiveDeleteWithWarning(stagedDelete);
    };

    QString writeError;
    bool writeOk = false;
    if (normalizedSourceType == QStringLiteral("archive")) {
        writeOk = normalizeArchiveToCbz(normalizedSourcePath, existingFilePath, writeError);
    } else {
        writeOk = packageImageFolderToCbz(normalizedSourcePath, existingFilePath, writeError);
    }
    if (!writeOk) {
        const QString rollbackError = rollbackStage();
        result.insert(QStringLiteral("code"), QStringLiteral("replace_write_failed"));
        result.insert(
            QStringLiteral("error"),
            rollbackError.isEmpty()
                ? writeError
                : QStringLiteral("%1 | Rollback: %2").arg(writeError, rollbackError)
        );
        return result;
    }

    const QString relinkError = relinkComicFileKeepMetadataInternal(
        comicId,
        existingFilePath,
        existingFilename,
        ComicImportWorkflow::importSignalsToVariantMap(newImportSignals)
    );
    if (!relinkError.isEmpty()) {
        deleteFileAtPath(existingFilePath);
        const QString rollbackError = rollbackStage();
        result.insert(QStringLiteral("code"), QStringLiteral("replace_relink_failed"));
        result.insert(
            QStringLiteral("error"),
            rollbackError.isEmpty()
                ? relinkError
                : QStringLiteral("%1 | Rollback: %2").arg(relinkError, rollbackError)
        );
        return result;
    }

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("code"), QStringLiteral("replaced"));
    result.insert(QStringLiteral("filePath"), QDir::toNativeSeparators(QFileInfo(existingFilePath).absoluteFilePath()));
    result.insert(QStringLiteral("filename"), existingFilename);

    if (keepBackupForRollback) {
        result.insert(QStringLiteral("backupPath"), stagedDelete.stagedPath);
        ComicDeleteOps::rememberPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);
        return result;
    }

    const QString cleanupWarning = finalizePendingStagedArchiveDelete(
        stagedDelete,
        QStringLiteral("Old archive backup cleanup failed: ")
    );
    if (!cleanupWarning.isEmpty()) {
        result.insert(QStringLiteral("cleanupWarning"), cleanupWarning);
        return result;
    }

    return result;
}

QString ComicsListModel::restoreReplacedComicFileFromBackup(
    int comicId,
    const QString &backupPath,
    const QString &targetPath,
    const QString &filename
)
{
    return restoreReplacedComicFileFromBackupEx(
        comicId,
        backupPath,
        targetPath,
        filename,
        {}
    );
}

QString ComicsListModel::restoreReplacedComicFileFromBackupEx(
    int comicId,
    const QString &backupPath,
    const QString &targetPath,
    const QString &filename,
    const QVariantMap &importSignalValues
)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString normalizedBackupPath = normalizeInputFilePath(backupPath);
    const QString normalizedTargetPath = normalizeInputFilePath(targetPath);
    if (normalizedTargetPath.isEmpty()) {
        return QStringLiteral("Restore target path is required.");
    }
    if (normalizedBackupPath.isEmpty()) {
        return QStringLiteral("Restore backup path is required.");
    }

    const QFileInfo backupInfo(normalizedBackupPath);
    if (!backupInfo.exists() || !backupInfo.isFile()) {
        return QStringLiteral("Restore backup file not found: %1").arg(backupPath.trimmed());
    }

    const QString restoreFileError = restoreBackupFileAfterRecovery(normalizedBackupPath, normalizedTargetPath);
    if (!restoreFileError.isEmpty()) {
        return restoreFileError;
    }

    const QString relinkError = relinkComicFileKeepMetadataInternal(comicId, normalizedTargetPath, filename, importSignalValues);
    if (!relinkError.isEmpty()) {
        return QStringLiteral("Backup archive was restored on disk, but DB relink failed: %1").arg(relinkError);
    }

    return {};
}

QString ComicsListModel::relinkComicFileKeepMetadata(int comicId, const QString &filePath, const QString &filename)
{
    return relinkComicFileKeepMetadataEx(comicId, filePath, filename, {});
}

QString ComicsListModel::relinkComicFileKeepMetadataEx(
    int comicId,
    const QString &filePath,
    const QString &filename,
    const QVariantMap &importSignalValues
)
{
    const QString normalizedPath = normalizeInputFilePath(filePath);
    const QFileInfo pathInfo(normalizedPath);
    if (!normalizedPath.isEmpty() && pathInfo.exists() && pathInfo.isFile()) {
        const QString archiveValidationError = validateArchiveImageEntries(normalizedPath);
        if (!archiveValidationError.isEmpty()) {
            return archiveValidationError;
        }
    }
    return relinkComicFileKeepMetadataInternal(comicId, filePath, filename, importSignalValues);
}

QString ComicsListModel::relinkComicFileKeepMetadataInternal(
    int comicId,
    const QString &filePath,
    const QString &filename,
    const QVariantMap &importSignalValues
)
{
    if (comicId < 1) return QString("Invalid issue id.");
    const QString seriesKey = seriesGroupKeyForComicId(comicId);
    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        return QString("File path is required.");
    }

    const QFileInfo pathInfo(normalizedPath);
    if (!pathInfo.exists() || !pathInfo.isFile()) {
        return QString("File not found for relink: %1").arg(filePath.trimmed());
    }

    QString filenameValue = filename.trimmed();
    if (filenameValue.isEmpty()) {
        filenameValue = pathInfo.fileName();
    }
    const bool shouldUpdateImportSignals = !importSignalValues.isEmpty();
    const ComicImportWorkflow::PersistedImportSignals importSignals = ComicImportWorkflow::resolvePersistedImportSignals(
        importSignalValues,
        filenameValue,
        QStringLiteral("archive")
    );
    const QString absoluteFilePath = QDir::toNativeSeparators(pathInfo.absoluteFilePath());
    const QString resultError = ComicIssueFileOps::relinkComicFileKeepMetadata(
        m_dbPath,
        m_dataRoot,
        {
            comicId,
            absoluteFilePath,
            filenameValue,
            shouldUpdateImportSignals,
            importSignals.originalFilename,
            importSignals.strictFilenameSignature,
            importSignals.looseFilenameSignature,
            importSignals.sourceType
        }
    );
    if (!resultError.isEmpty()) {
        return resultError;
    }

    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);
    setReaderArchivePathForComic(comicId, absoluteFilePath);
    requestIssueThumbnailAsync(comicId);

    m_lastMutationKind = QString("relink_issue_file_keep_metadata");
    emit statusChanged();
    return {};
}

QString ComicsListModel::rollbackStagedArchiveDeleteWithWarning(
    const ComicDeleteOps::StagedArchiveDeleteOp &stagedDelete
) const
{
    DeleteFailureInfo rollbackFailure;
    if (ComicDeleteOps::rollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
        return {};
    }
    return formatDeleteFailureText(rollbackFailure);
}

QString ComicsListModel::finalizePendingStagedArchiveDelete(
    const ComicDeleteOps::StagedArchiveDeleteOp &stagedDelete,
    const QString &warningPrefix
) const
{
    if (stagedDelete.stagedPath.trimmed().isEmpty()) {
        return {};
    }

    ComicDeleteOps::rememberPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);

    QString cleanupDirPath;
    DeleteFailureInfo finalizeFailure;
    if (!ComicDeleteOps::finalizeStagedArchiveDelete(stagedDelete, cleanupDirPath, finalizeFailure)) {
        const QString detail = formatDeleteFailureText(finalizeFailure);
        return warningPrefix.isEmpty() ? detail : QStringLiteral("%1%2").arg(warningPrefix, detail);
    }

    ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);
    if (!cleanupDirPath.isEmpty()) {
        cleanupEmptyLibraryDirs(
            QDir(m_dataRoot).filePath(QStringLiteral("Library")),
            { cleanupDirPath }
        );
    }

    return {};
}

QString ComicsListModel::restoreComicFileBindingsAfterRecovery(
    const QHash<int, QString> &bindingsByComicId,
    const QString &connectionTag
)
{
    if (bindingsByComicId.isEmpty()) {
        return {};
    }

    QVector<int> comicIds;
    comicIds.reserve(bindingsByComicId.size());
    for (auto it = bindingsByComicId.constBegin(); it != bindingsByComicId.constEnd(); ++it) {
        comicIds.push_back(it.key());
    }
    std::sort(comicIds.begin(), comicIds.end());

    QVector<ComicIssueFileOps::ComicFilePathBinding> bindings;
    bindings.reserve(comicIds.size());
    for (int comicId : comicIds) {
        bindings.push_back({ comicId, bindingsByComicId.value(comicId) });
    }

    return ComicIssueFileOps::applyComicFilePathBindings(
        m_dbPath,
        m_dataRoot,
        bindings,
        connectionTag
    );
}

QString ComicsListModel::restoreBackupFileAfterRecovery(
    const QString &backupPath,
    const QString &targetPath
)
{
    const QString normalizedBackupPath = normalizeInputFilePath(backupPath);
    const QString normalizedTargetPath = normalizeInputFilePath(targetPath);
    if (normalizedTargetPath.isEmpty()) {
        return QStringLiteral("Restore target path is required.");
    }
    if (normalizedBackupPath.isEmpty()) {
        return QStringLiteral("Restore backup path is required.");
    }

    const QFileInfo backupInfo(normalizedBackupPath);
    if (!backupInfo.exists() || !backupInfo.isFile()) {
        return QStringLiteral("Restore backup file not found: %1").arg(backupPath.trimmed());
    }

    QString removedDirPath;
    DeleteFailureInfo removeFailure;
    if (!ComicDeleteOps::tryRemoveFileWithDetails(normalizedTargetPath, removedDirPath, removeFailure)) {
        return QStringLiteral("Failed to clear the current archive before rollback.\n%1")
            .arg(ComicDeleteOps::formatDeleteFailureLine(removeFailure));
    }

    QString moveError;
    if (!moveFileWithFallback(normalizedBackupPath, normalizedTargetPath, moveError)) {
        return moveError;
    }

    ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, normalizedBackupPath);
    return {};
}

QVariantMap ComicsListModel::exportComicInfoXml(int comicId)
{
    return ComicInfoOps::exportComicInfoXml(m_dbPath, comicId, archivePathForComicId(comicId));
}

QString ComicsListModel::syncComicInfoToArchive(int comicId)
{
    return ComicInfoOps::syncComicInfoToArchive(m_dbPath, comicId, archivePathForComicId(comicId));
}

QString ComicsListModel::importComicInfoFromArchive(int comicId, const QString &mode)
{
    const QVariantMap patch = ComicInfoOps::buildComicInfoImportPatch(
        m_dbPath,
        comicId,
        mode,
        archivePathForComicId(comicId)
    );
    if (patch.contains(QStringLiteral("error"))) {
        return patch.value(QStringLiteral("error")).toString();
    }
    if (patch.isEmpty()) {
        return {};
    }

    QVariantList ids;
    ids.push_back(comicId);
    return bulkUpdateMetadata(
        ids,
        patch.value(QStringLiteral("values")).toMap(),
        patch.value(QStringLiteral("applyMap")).toMap()
    );
}

bool ComicsListModel::openDatabaseConnection(QSqlDatabase &db, const QString &connectionName, QString &errorText) const
{
    return ComicStorageSqlite::openDatabaseConnection(db, m_dbPath, connectionName, errorText);
}

QString ComicsListModel::normalizeSeriesKey(const QString &value)
{
    return ComicImportMatching::normalizeSeriesKey(value);
}

QString ComicsListModel::normalizeVolumeKey(const QString &value)
{
    return ComicImportMatching::normalizeVolumeKey(value);
}

QString ComicsListModel::normalizeReadStatus(const QString &value)
{
    QString normalized = value.trimmed().toLower();
    if (normalized.isEmpty()) return QString("unread");

    normalized.replace('-', '_');
    normalized.replace(' ', '_');
    if (normalized == QString("inprogress")) normalized = QString("in_progress");

    if (normalized == QString("unread") || normalized == QString("in_progress") || normalized == QString("read")) {
        return normalized;
    }

    return {};
}

QString ComicsListModel::makeGroupTitle(const QString &groupKey)
{
    if (groupKey.trimmed().isEmpty() || groupKey == QString("unknown-series")) {
        return QString("Unknown Series");
    }

    QStringList words = groupKey.split(' ', Qt::SkipEmptyParts);
    for (QString &word : words) {
        if (word.isEmpty()) continue;
        word[0] = word[0].toUpper();
    }
    return words.join(' ');
}

QString ComicsListModel::resolveLibraryFilePath(const QString &libraryPath, const QString &inputFilename)
{
    const QDir libraryDir(libraryPath);
    if (!libraryDir.exists()) return {};

    const QString rawInput = inputFilename.trimmed();
    if (rawInput.isEmpty()) return {};

    const QString normalizedInput = QDir::fromNativeSeparators(rawInput);
    const QFileInfo inputInfo(normalizedInput);

    if (inputInfo.isAbsolute()) {
        if (inputInfo.exists() && inputInfo.isFile()
            && isPathInsideDirectory(inputInfo.absoluteFilePath(), libraryDir.absolutePath())) {
            return QDir::toNativeSeparators(inputInfo.absoluteFilePath());
        }
    }

    const QFileInfo directRelative(libraryDir.filePath(normalizedInput));
    if (directRelative.exists() && directRelative.isFile()) {
        return QDir::toNativeSeparators(directRelative.absoluteFilePath());
    }

    const QString inputFileName = QFileInfo(normalizedInput).fileName().trimmed();
    if (inputFileName.isEmpty()) return {};
    const QString inputRelativeKey = QDir::cleanPath(normalizedInput).toLower();

    QString filenameMatchPath;
    QDirIterator iterator(
        libraryDir.absolutePath(),
        QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::Subdirectories
    );
    while (iterator.hasNext()) {
        const QString candidatePath = iterator.next();
        const QFileInfo candidateInfo(candidatePath);
        const QString candidateName = candidateInfo.fileName();
        if (candidateName.isEmpty()) continue;

        const QString relative = QDir::cleanPath(libraryDir.relativeFilePath(candidateInfo.absoluteFilePath()));
        if (!inputRelativeKey.isEmpty() && relative.toLower() == inputRelativeKey) {
            return QDir::toNativeSeparators(candidateInfo.absoluteFilePath());
        }

        bool nameMatches = candidateName.compare(inputFileName, Qt::CaseInsensitive) == 0;
        if (!nameMatches) {
            const int dashIndex = candidateName.indexOf('-');
            if (dashIndex > 0 && dashIndex + 1 < candidateName.length()) {
                const QString originalName = candidateName.mid(dashIndex + 1);
                nameMatches = originalName.compare(inputFileName, Qt::CaseInsensitive) == 0;
            }
        }
        if (!nameMatches) continue;
        if (filenameMatchPath.isEmpty()) {
            filenameMatchPath = candidateInfo.absoluteFilePath();
        }
    }

    if (!filenameMatchPath.isEmpty()) {
        return QDir::toNativeSeparators(filenameMatchPath);
    }
    return {};
}

QString ComicsListModel::resolveStoredArchivePathForDataRoot(
    const QString &dataRoot,
    const QString &storedFilePath,
    const QString &storedFilename
)
{
    return ComicStoragePaths::resolveStoredArchivePath(dataRoot, storedFilePath, storedFilename);
}

QString ComicsListModel::resolveDataRoot() const
{
    return ComicDataRootSettings::resolveActiveDataRootPath();
}

QString ComicsListModel::baseNameWithoutExtension(const QString &filename)
{
    return QFileInfo(filename).completeBaseName();
}

QString ComicsListModel::buildSubtitle(const ComicRow &row)
{
    QStringList parts;
    if (!row.volume.isEmpty()) parts << QString("Vol %1").arg(row.volume);
    if (!row.issueNumber.isEmpty()) parts << QString("#%1").arg(row.issueNumber);
    if (!row.title.isEmpty()) parts << row.title;
    if (!row.publisher.isEmpty()) parts << row.publisher;
    if (row.year > 0) {
        if (row.month > 0) {
            const QString monthName = monthNameForNumber(row.month);
            if (!monthName.isEmpty()) {
                parts << QString("%1 %2").arg(monthName).arg(row.year);
            } else {
                parts << QString::number(row.year);
            }
        } else {
            parts << QString::number(row.year);
        }
    }
    if (!row.readStatus.isEmpty()) parts << row.readStatus;
    if (row.currentPage > 0) parts << QString("page %1").arg(row.currentPage);

    const QString details = parts.join(" | ");
    const QString filePart = row.filename.isEmpty() ? QString() : row.filename;
    if (details.isEmpty()) return filePart;
    if (filePart.isEmpty()) return details;
    return QString("%1 | %2").arg(details, filePart);
}

int ComicsListModel::compareRows(const ComicRow &left, const ComicRow &right) const
{
    if (m_sortMode == QString("title_asc")) {
        const int byTitle = compareText(left.title, right.title);
        if (byTitle != 0) return byTitle;

        const int bySeries = compareText(left.series, right.series);
        if (bySeries != 0) return bySeries;

        const int byIssue = compareNaturalText(left.issueNumber, right.issueNumber);
        if (byIssue != 0) return byIssue;
    } else if (m_sortMode == QString("year_desc")) {
        if (left.year != right.year) return left.year > right.year ? -1 : 1;
        if (left.month != right.month) return left.month > right.month ? -1 : 1;

        const int bySeries = compareText(left.series, right.series);
        if (bySeries != 0) return bySeries;

        const int byIssue = compareNaturalText(left.issueNumber, right.issueNumber);
        if (byIssue != 0) return byIssue;
    } else if (m_sortMode == QString("added_desc")) {
        const int byAdded = compareText(right.addedDate, left.addedDate);
        if (byAdded != 0) return byAdded;
        if (left.id != right.id) return left.id > right.id ? -1 : 1;
    }

    const int byGroup = compareText(left.seriesGroupKey, right.seriesGroupKey);
    if (byGroup != 0) return byGroup;

    const int bySeries = compareText(left.series, right.series);
    if (bySeries != 0) return bySeries;

    const int byVolume = compareNaturalText(left.volume, right.volume);
    if (byVolume != 0) return byVolume;

    const int byIssue = compareNaturalText(left.issueNumber, right.issueNumber);
    if (byIssue != 0) return byIssue;

    const int byTitle = compareText(left.title, right.title);
    if (byTitle != 0) return byTitle;

    const int byFilename = compareText(left.filename, right.filename);
    if (byFilename != 0) return byFilename;

    if (left.id < right.id) return -1;
    if (left.id > right.id) return 1;
    return 0;
}

bool ComicsListModel::listImageEntriesInArchive(
    const QString &archivePath,
    QStringList &entriesOut,
    QString &errorText
)
{
    return ComicInfoArchive::listImageEntriesInArchive(archivePath, entriesOut, errorText);
}

bool ComicsListModel::extractArchiveEntryToFile(
    const QString &archivePath,
    const QString &entryName,
    const QString &outputFilePath,
    QString &errorText
)
{
    return ComicInfoArchive::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
}
