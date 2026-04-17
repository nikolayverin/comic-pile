#include <algorithm>

#include "storage/comicslistmodel.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/archivepacking.h"
#include "storage/archivesupportutils.h"
#include "storage/comicinfoarchive.h"
#include "storage/comicsmodelutils.h"
#include "storage/deletestagingops.h"
#include "storage/duplicaterestoreresolver.h"
#include "storage/importduplicateclassifier.h"
#include "storage/importmatching.h"
#include "storage/importruntimeutils.h"
#include "storage/importworkflowutils.h"
#include "storage/libraryschemamanager.h"
#include "storage/librarylayoututils.h"
#include "storage/readercacheutils.h"
#include "storage/storedpathutils.h"

#include <QCollator>
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
#include <QStringList>
#include <QUuid>
#include <QtConcurrent>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString normalizeInputFilePath(const QString &rawInput)
{
    return ComicStoragePaths::normalizePathInput(rawInput);
}

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
    return ComicArchiveSupport::sevenZipMissingMessage();
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

QString normalizeArchiveExtension(const QString &pathOrExtension)
{
    return ComicArchiveSupport::normalizeArchiveExtension(pathOrExtension);
}

QString resolve7ZipExecutableFromHint(const QString &hintPath)
{
    return ComicArchiveSupport::resolve7ZipExecutableFromHint(hintPath);
}

QString resolveDjVuExecutableFromHint(const QString &hintPath)
{
    return ComicArchiveSupport::resolveDjVuExecutableFromHint(hintPath);
}

QString resolveDjVuExecutable()
{
    return ComicArchiveSupport::resolveDjVuExecutable();
}

bool isDjvuExtension(const QString &extension)
{
    return ComicArchiveSupport::isDjvuExtension(extension);
}

bool isPdfExtension(const QString &extension)
{
    return ComicArchiveSupport::isPdfExtension(extension);
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

QString resolve7ZipExecutable()
{
    return ComicArchiveSupport::resolve7ZipExecutable();
}

bool lookupComicIdByFilePath(
    QSqlDatabase &db,
    const QString &dataRoot,
    const QString &candidatePath,
    int &comicIdOut,
    QString &errorText
)
{
    comicIdOut = -1;
    errorText.clear();

    const QString normalizedCandidatePath = ComicStoragePaths::normalizePathInput(candidatePath);
    const QFileInfo candidateInfo(QDir::fromNativeSeparators(normalizedCandidatePath));
    const bool candidateExists = candidateInfo.exists() && candidateInfo.isFile();

    const QStringList lookupCandidates = ComicStoragePaths::archivePathLookupCandidates(
        dataRoot,
        normalizedCandidatePath
    );
    if (lookupCandidates.isEmpty()) {
        comicIdOut = 0;
        return true;
    }

    QStringList predicates;
    predicates.reserve(lookupCandidates.size());
    for (int i = 0; i < lookupCandidates.size(); i += 1) {
        predicates.push_back(QStringLiteral("file_path = ? COLLATE NOCASE"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral("SELECT id FROM comics WHERE %1 ORDER BY id ASC LIMIT 1")
            .arg(predicates.join(QStringLiteral(" OR ")))
    );
    for (const QString &lookupCandidate : lookupCandidates) {
        query.addBindValue(lookupCandidate);
    }
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to check duplicates: %1").arg(query.lastError().text());
        return false;
    }

    if (!query.next()) {
        comicIdOut = 0;
        return true;
    }

    comicIdOut = candidateExists ? query.value(0).toInt() : 0;
    return true;
}

QVector<ImportDuplicateClassifier::Candidate> loadLiveDuplicateCandidates(
    QSqlDatabase &db,
    const QString &dataRoot,
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
        const QString resolvedPath = ComicStoragePaths::resolveStoredArchivePath(
            dataRoot,
            candidate.filePath,
            candidate.filename
        );
        if (resolvedPath.isEmpty()) continue;
        candidate.filePath = resolvedPath;
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
    const QString &dataRoot,
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
    if (!lookupComicIdByFilePath(db, dataRoot, plannedFilePath, existingId, errorText)) {
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
        dataRoot,
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

    QHash<QString, QString> simulatedDeferredImportFolders = m_importState.deferredFolderBySeriesKey;

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
        if (!lookupComicIdByFilePath(db, m_dataRoot, predictedPath, existingId, duplicateCheckError)) {
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

    QHash<QString, QString> simulatedDeferredImportFolders = m_importState.deferredFolderBySeriesKey;

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
        if (!lookupComicIdByFilePath(db, m_dataRoot, predictedPath, existingId, duplicateCheckError)) {
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
    QVariantMap values = ComicImportWorkflow::withImportSeriesContext(
        entry.value(QStringLiteral("values")).toMap(),
        seriesOverride
    );
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

        const ComicImportMatching::ImportIdentityPassport passport = ComicImportWorkflow::buildArchiveImportPassport(
            sourceInfo,
            normalizedSourcePath,
            filenameHint,
            createValues
        );
        createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);

        targetFilename = ComicImportWorkflow::ensureTargetCbzFilename(filenameHint, sourceInfo.fileName());
        if (targetFilename.isEmpty()) return {};
    } else if (sourceType == QStringLiteral("image_folder")) {
        const QString normalizedFolderPath = normalizeInputFilePath(sourcePath);
        if (normalizedFolderPath.isEmpty()) return {};

        const QFileInfo folderInfo(normalizedFolderPath);
        if (!folderInfo.exists() || !folderInfo.isDir()) return {};

        const QStringList imagePaths = listSupportedImageFilesInFolder(normalizedFolderPath);
        if (imagePaths.isEmpty()) return {};

        const ComicImportMatching::ImportIdentityPassport passport = ComicImportWorkflow::buildImageFolderImportPassport(
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
        targetFilename = ComicImportWorkflow::ensureTargetCbzFilename(effectiveFilenameHint, folderName);
        if (targetFilename.isEmpty()) return {};
    } else {
        return {};
    }

    const QString effectiveSeries = valueFromMap(createValues, QStringLiteral("series"));
    const QString effectiveSeriesKey = ComicModelUtils::normalizeSeriesKey(effectiveSeries);
    QString folderSeriesName = effectiveSeries;
    const QString inferredFolderSeriesName = ComicImportMatching::guessSeriesFromFilename(effectiveSeries);
    if (!ComicImportMatching::isWeakSeriesName(inferredFolderSeriesName)
        && ComicModelUtils::normalizeSeriesKey(inferredFolderSeriesName) == effectiveSeriesKey) {
        folderSeriesName = inferredFolderSeriesName;
    }

    ComicLibraryLayout::SeriesFolderState folderState;
    for (const ComicRow &row : m_rows) {
        if (row.filePath.trimmed().isEmpty()) continue;
        const QString relativeDir = ComicLibraryLayout::relativeDirUnderRoot(libraryPath, row.filePath);
        if (relativeDir.isEmpty()) continue;
        ComicLibraryLayout::registerSeriesFolderAssignment(folderState, ComicModelUtils::normalizeSeriesKey(row.series), relativeDir);
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
    ComicImportRuntime::resetOutcome(m_importState);

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
    const QString issueNumber = ComicImportMatching::normalizeStoredIssueNumber(
        valueFromMap(values, "issueNumber", "issue")
    );
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
    const QString readStatus = ComicModelUtils::normalizeReadStatus(readStatusInput);
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
    const QString resolvedFilePath = ComicModelUtils::resolveLibraryFilePath(libraryPath, inputRef);
    if (resolvedFilePath.isEmpty()) {
        return QString("File not found in Database/Library: %1").arg(inputRef);
    }
    const QString normalizedFilePath = QDir::toNativeSeparators(QFileInfo(resolvedFilePath).absoluteFilePath());
    const QString storedFilePath = ComicStoragePaths::persistPathForDataRoot(m_dataRoot, normalizedFilePath);
    const QString resolvedFilename = QFileInfo(normalizedFilePath).fileName().trimmed();
    const ComicImportWorkflow::PersistedImportSignals importSignals = ComicImportWorkflow::resolvePersistedImportSignals(
        values,
        resolvedFilename,
        QStringLiteral("archive")
    );
    const QString candidateSeriesKey = ComicModelUtils::normalizeSeriesKey(series);
    auto purgeSeriesHeroCacheKeys = [this](const QSet<QString> &seriesKeys) {
        for (const QString &seriesKey : seriesKeys) {
            if (!seriesKey.trimmed().isEmpty()) {
                purgeSeriesHeroCacheForKey(seriesKey);
            }
        }
    };
    const bool allowMetadataRestore = ComicImportWorkflow::shouldAllowMetadataRestoreForImport(values, candidateSeriesKey);
    const bool relaxWeakLiveDuplicateChecks = ComicImportWorkflow::hasNarrowImportSeriesContext(values, candidateSeriesKey);
    const QString candidateVolumeKey = ComicModelUtils::normalizeVolumeKey(volume);
    QString candidateIssueValue = issueNumber;
    if (candidateIssueValue.isEmpty()) {
        candidateIssueValue = ComicImportMatching::normalizeStoredIssueNumber(
            ComicImportMatching::guessIssueNumberFromFilename(resolvedFilename)
        );
    }
    const QString candidateIssueKey = ComicImportMatching::normalizeIssueKey(candidateIssueValue);
    const QString strictInputSignature = ComicImportMatching::normalizeFilenameSignatureStrict(resolvedFilename);
    const QString looseInputSignature = ComicImportMatching::normalizeFilenameSignatureLoose(resolvedFilename);
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
                    : ComicImportMatching::normalizeStoredIssueNumber(candidate.issue);

                restoreQuery.prepare(
                    "UPDATE comics SET "
                    "file_path = ?, filename = ?, "
                    "series = ?, series_key = ?, volume = ?, issue_number = ?, issue = ?, "
                    "import_original_filename = ?, import_strict_filename_signature = ?, "
                    "import_loose_filename_signature = ?, import_source_type = ? "
                    "WHERE id = ?"
                );
                restoreQuery.addBindValue(storedFilePath);
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
                restoreQuery.addBindValue(storedFilePath);
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

            ComicImportRuntime::recordRestored(m_importState, candidate.id);

            QSet<QString> seriesHeroKeysToPurge;
            const QString existingSeriesKey = candidate.seriesKey.trimmed().isEmpty()
                ? ComicModelUtils::normalizeSeriesKey(candidate.series)
                : candidate.seriesKey.trimmed();
            if (!existingSeriesKey.isEmpty()) {
                seriesHeroKeysToPurge.insert(existingSeriesKey);
            }
            if (!candidateSeriesKey.isEmpty()) {
                seriesHeroKeysToPurge.insert(candidateSeriesKey);
            }

            db.close();
            ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, candidate.id);
            purgeSeriesHeroCacheKeys(seriesHeroKeysToPurge);
            setReaderArchivePathForComic(candidate.id, normalizedFilePath);
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

            ComicImportRuntime::recordRestoreConflict(m_importState, uniqueCandidateIds.size());
            db.close();

            return QStringLiteral(
                "Import is blocked because %1 deleted issue records match this archive. The app cannot safely restore it automatically."
            ).arg(QString::number(m_importState.lastRestoreCandidateCount));
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

            ComicImportRuntime::recordRestoreReviewRequired(
                m_importState,
                static_cast<int>(uniqueCandidateIds.size()),
                candidateId
            );
            db.close();

            return QStringLiteral(
                "Import is blocked because a deleted issue only partially matches this archive. The app cannot safely restore it automatically."
            );
        };

        auto isMissingCandidate = [&](const RestoreCandidate &candidate) -> bool {
            const QString resolvedPath = ComicStoragePaths::resolveStoredArchivePath(
                m_dataRoot,
                candidate.filePath,
                candidate.filename
            );
            return resolvedPath.isEmpty();
        };

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
            m_dataRoot,
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
            ComicImportRuntime::recordDuplicate(
                m_importState,
                liveDuplicate.candidate.id,
                ImportDuplicateClassifier::tierKey(liveDuplicate.tier)
            );
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
        insertQuery.addBindValue(storedFilePath);
        insertQuery.addBindValue(resolvedFilename);
        insertQuery.addBindValue(series);
        insertQuery.addBindValue(ComicModelUtils::normalizeSeriesKey(series));
        insertQuery.addBindValue(volume);
        insertQuery.addBindValue(title);
        insertQuery.addBindValue(candidateIssueValue);
        insertQuery.addBindValue(candidateIssueValue);
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

        ComicImportRuntime::recordCreated(m_importState, insertQuery.lastInsertId().toInt());

        db.close();
    }

    if (!deferReload) {
        reload();
    }
    if (m_importState.lastComicId > 0) {
        ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, m_importState.lastComicId);
        purgeSeriesHeroCacheForKey(candidateSeriesKey);
        setReaderArchivePathForComic(m_importState.lastComicId, normalizedFilePath);
        requestIssueThumbnailAsync(m_importState.lastComicId);
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
    auto setOutError = [&](const QString &code, const QString &message, const QString &sourcePath = QString()) {
        if (!outResult) return;
        *outResult = ComicImportRuntime::makeFailureResult(code, message, sourcePath);
    };

    auto setOutSuccess = [&](const QString &finalFilename, const QString &finalFilePath, bool createdArchiveFile, const QString &normalizedSourcePath) {
        if (!outResult) return;
        *outResult = ComicImportRuntime::makeSuccessResult(
            m_importState,
            finalFilename,
            finalFilePath,
            createdArchiveFile,
            normalizedSourcePath
        );
    };

    ComicImportRuntime::resetOutcome(m_importState);

    const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
    if (normalizedSourcePath.isEmpty()) {
        const QString error = QString("Import file path is required.");
        setOutError("invalid_input", error, normalizedSourcePath);
        return error;
    }

    const QFileInfo sourceInfo(normalizedSourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        const QString error = QString("Import file not found: %1").arg(sourcePath.trimmed());
        setOutError("file_not_found", error, normalizedSourcePath);
        return error;
    }

    const QString extension = normalizeArchiveExtension(sourceInfo.suffix());
    if (!isImportArchiveExtensionSupported(extension)) {
        const QString error = QString("Supported import formats: %1").arg(formatSupportedArchiveList());
        setOutError("unsupported_format", error, normalizedSourcePath);
        return error;
    }
    if (isSevenZipExtension(extension) && !isCbrBackendAvailable()) {
        const QString error = cbrBackendMissingMessage();
        setOutError("cbr_backend_missing", error, normalizedSourcePath);
        return error;
    }
    if (isDjvuExtension(extension) && resolveDjVuExecutable().isEmpty()) {
        const QString error = djvuBackendMissingMessage();
        setOutError("djvu_backend_missing", error, normalizedSourcePath);
        return error;
    }

    if (!isPdfExtension(extension) && !isDjvuExtension(extension)) {
        const QString archiveValidationError = validateArchiveImageEntries(sourceInfo.absoluteFilePath());
        if (!archiveValidationError.isEmpty()) {
            setOutError(archiveValidationCode(archiveValidationError), archiveValidationError, normalizedSourcePath);
            return archiveValidationError;
        }
    }

    const QString libraryPath = QDir(m_dataRoot).filePath("Library");
    QDir libraryDir(libraryPath);
    if (!libraryDir.exists()) {
        if (!QDir().mkpath(libraryPath)) {
            const QString error = QString("Failed to create Library folder: %1").arg(libraryPath);
            setOutError("library_dir_create_failed", error, normalizedSourcePath);
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
    const ComicImportMatching::ImportIdentityPassport passport = ComicImportWorkflow::buildArchiveImportPassport(
        sourceInfo,
        normalizedSourcePath,
        filenameHint,
        createValues
    );
    createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);

    const QString effectiveSeries = valueFromMap(createValues, "series");
    const QString effectiveSeriesKey = ComicModelUtils::normalizeSeriesKey(effectiveSeries);
    if (!deferReload) {
        m_importState.deferredFolderBySeriesKey.clear();
    }
    QString folderSeriesName = effectiveSeries;
    const QString inferredFolderSeriesName = ComicImportMatching::guessSeriesFromFilename(effectiveSeries);
    if (!ComicImportMatching::isWeakSeriesName(inferredFolderSeriesName)
        && ComicModelUtils::normalizeSeriesKey(inferredFolderSeriesName) == effectiveSeriesKey) {
        folderSeriesName = inferredFolderSeriesName;
    }
    ComicLibraryLayout::SeriesFolderState folderState;
    for (const ComicRow &row : m_rows) {
        if (row.filePath.trimmed().isEmpty()) continue;
        const QString relativeDir = ComicLibraryLayout::relativeDirUnderRoot(libraryPath, row.filePath);
        if (relativeDir.isEmpty()) continue;
        ComicLibraryLayout::registerSeriesFolderAssignment(folderState, ComicModelUtils::normalizeSeriesKey(row.series), relativeDir);
    }
    for (auto it = m_importState.deferredFolderBySeriesKey.constBegin(); it != m_importState.deferredFolderBySeriesKey.constEnd(); ++it) {
        ComicLibraryLayout::registerSeriesFolderAssignment(folderState, it.key(), it.value());
    }
    const QString seriesFolderName = ComicLibraryLayout::assignSeriesFolderName(folderState, effectiveSeriesKey, folderSeriesName);
    if (deferReload && !seriesFolderName.trimmed().isEmpty()) {
        m_importState.deferredFolderBySeriesKey.insert(effectiveSeriesKey, seriesFolderName);
    }
    const QString seriesFolderPath = libraryDir.filePath(seriesFolderName);
    QDir seriesDir(seriesFolderPath);
    if (!seriesDir.exists() && !QDir().mkpath(seriesFolderPath)) {
        const QString error = QStringLiteral("Failed to create series folder: %1").arg(seriesFolderPath);
        setOutError("series_dir_create_failed", error, normalizedSourcePath);
        return error;
    }

    const QString targetFilename = ComicImportWorkflow::ensureTargetCbzFilename(filenameHint, sourceInfo.fileName());
    if (targetFilename.isEmpty()) {
        const QString error = QString("Invalid archive filename.");
        setOutError("invalid_filename", error, normalizedSourcePath);
        return error;
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
            setOutError("duplicate_check_failed", duplicateOpenError, normalizedSourcePath);
            return duplicateOpenError;
        }

        const QString candidateSeries = valueFromMap(createValues, QStringLiteral("series"));
        const QString candidateSeriesKey = ComicImportMatching::normalizeSeriesKey(candidateSeries);
        const QString candidateVolume = valueFromMap(createValues, QStringLiteral("volume"));
        const QString candidateVolumeKey = ComicImportMatching::normalizeVolumeKey(candidateVolume);
        QString candidateIssue = ComicImportMatching::normalizeStoredIssueNumber(
            valueFromMap(createValues, QStringLiteral("issueNumber"), QStringLiteral("issue"))
        );
        if (candidateIssue.isEmpty()) {
            candidateIssue = ComicImportMatching::normalizeStoredIssueNumber(
                ComicImportMatching::guessIssueNumberFromFilename(sourceInfo.fileName())
            );
        }
        const QString candidateIssueKey = ComicImportMatching::normalizeIssueKey(candidateIssue);
        const QString strictTargetSignature = ComicImportMatching::normalizeFilenameSignatureStrict(targetFilename);
        const QString looseTargetSignature = ComicImportMatching::normalizeFilenameSignatureLoose(targetFilename);
        const bool relaxWeakLiveDuplicateChecks =
            ComicImportWorkflow::hasNarrowImportSeriesContext(createValues, candidateSeriesKey);

        QString liveDuplicateError;
        const LiveDuplicateCheckResult liveDuplicate = evaluateLiveDuplicateForImport(
            duplicateDb,
            m_dataRoot,
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
            setOutError(QStringLiteral("duplicate_check_failed"), liveDuplicateError, normalizedSourcePath);
            return liveDuplicateError;
        }
        if (liveDuplicate.hasMatch() && (!allowImportAsNew || liveDuplicate.tier == ImportDuplicateClassifier::Tier::Exact)) {
            ComicImportRuntime::recordDuplicate(
                m_importState,
                liveDuplicate.candidate.id,
                ImportDuplicateClassifier::tierKey(liveDuplicate.tier)
            );
            QString duplicateError = QStringLiteral("Issue already exists in DB (id %1). Use replace instead.").arg(liveDuplicate.candidate.id);
            if (liveDuplicate.tier == ImportDuplicateClassifier::Tier::VeryLikely) {
                duplicateError = QStringLiteral("Likely duplicate issue found in DB (id %1).").arg(liveDuplicate.candidate.id);
            } else if (liveDuplicate.tier == ImportDuplicateClassifier::Tier::Weak) {
                duplicateError = QStringLiteral("Suspicious duplicate issue found in DB (id %1).").arg(liveDuplicate.candidate.id);
            }
            if (outResult) {
                *outResult = ComicImportRuntime::makeCreateFailureResult(
                    m_importState,
                    QStringLiteral("duplicate"),
                    duplicateError,
                    normalizedSourcePath
                );
            }
            return duplicateError;
        }

        if (targetInfo.exists()) {
            finalFilename = ComicLibraryLayout::makeUniqueFilename(seriesDir, targetFilename);
            finalFilePath = seriesDir.filePath(finalFilename);
        }

        QString normalizeError;
        if (!normalizeArchiveToCbz(sourceInfo.absoluteFilePath(), finalFilePath, normalizeError)) {
            setOutError("archive_normalize_failed", normalizeError, normalizedSourcePath);
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

        if (outResult) {
            *outResult = ComicImportRuntime::makeCreateFailureResult(
                m_importState,
                QStringLiteral("create_issue_failed"),
                createError,
                normalizedSourcePath
            );
        }
        return createError;
    }

    setOutSuccess(finalFilename, finalFilePath, createdArchiveFile, normalizedSourcePath);

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
        *outResult = ComicImportRuntime::makeFailureResult(
            code,
            message,
            normalizedFolderPath,
            QStringLiteral("image_folder")
        );
    };

    ComicImportRuntime::resetOutcome(m_importState);

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
    const ComicImportMatching::ImportIdentityPassport passport = ComicImportWorkflow::buildImageFolderImportPassport(
        folderInfo,
        normalizedFolderPath,
        filenameHint,
        createValues
    );
    createValues = ComicImportMatching::applyPassportDefaults(createValues, passport);
    createValues.insert(QStringLiteral("importHistorySourcePath"), normalizedFolderPath);
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
        ComicImportWorkflow::ensureTargetCbzFilename(effectiveFilenameHint, folderName)
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
