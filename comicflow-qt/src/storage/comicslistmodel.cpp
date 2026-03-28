#include "storage/comicslistmodel.h"
#include "storage/archivepacking.h"
#include "storage/archiveprocessutils.h"
#include "storage/comicinfoarchive.h"
#include "storage/comicinfoops.h"
#include "storage/libraryschemamanager.h"
#include "storage/deletestagingops.h"
#include "storage/duplicaterestoreresolver.h"
#include "storage/importduplicateclassifier.h"
#include "storage/importmatching.h"
#include "storage/imagepreparationops.h"
#include "storage/issuefileops.h"
#include "storage/librarylayoututils.h"
#include "storage/libraryqueryops.h"
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
#include <QCoreApplication>
#include <QCryptographicHash>
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
#include <QStandardPaths>
#include <QStringList>
#include <QTimer>
#include <QTransform>
#include <QUrl>
#include <QUuid>
#include <QtConcurrent>
#include <QtGlobal>
#include <QtMath>

namespace {

QString absolutePathIfExists(const QString &candidate)
{
    return ComicStartupRuntime::absolutePathIfExists(candidate);
}

QString libraryStorageMigrationMarkerPath(const QString &dataRoot)
{
    return ComicStartupRuntime::libraryStorageMigrationMarkerPath(dataRoot);
}

QString buildSeriesGroupKey(const QString &series, const QString &volume)
{
    const QString normalizedSeriesKey = ComicImportMatching::normalizeSeriesKey(series);
    const QString volumeGroupKey = ComicImportMatching::normalizeVolumeKey(volume);
    if (volumeGroupKey == QStringLiteral("__no_volume__")) {
        return normalizedSeriesKey;
    }
    return QStringLiteral("%1::vol::%2").arg(normalizedSeriesKey, volumeGroupKey);
}

bool hasLibraryStorageMigrationMarker(const QString &dataRoot)
{
    return ComicStartupRuntime::hasLibraryStorageMigrationMarker(dataRoot);
}

bool writeLibraryStorageMigrationMarker(const QString &dataRoot)
{
    return ComicStartupRuntime::writeLibraryStorageMigrationMarker(dataRoot);
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

bool boolFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toBool();
}

QString normalizeImportSourceTypeValue(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("archive") || normalized == QStringLiteral("image_folder")) {
        return normalized;
    }
    return {};
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

struct PersistedImportSignals {
    QString originalFilename;
    QString strictFilenameSignature;
    QString looseFilenameSignature;
    QString sourceType;
};

PersistedImportSignals resolvedImportSignals(
    const QVariantMap &values,
    const QString &fallbackOriginalFilename,
    const QString &fallbackSourceType
)
{
    PersistedImportSignals resolvedSignals;
    resolvedSignals.originalFilename = valueFromMap(values, QStringLiteral("importOriginalFilename"));
    if (resolvedSignals.originalFilename.isEmpty()) {
        resolvedSignals.originalFilename = fallbackOriginalFilename.trimmed();
    }

    resolvedSignals.sourceType = normalizeImportSourceTypeValue(
        valueFromMap(values, QStringLiteral("importSourceType"))
    );
    if (resolvedSignals.sourceType.isEmpty()) {
        resolvedSignals.sourceType = normalizeImportSourceTypeValue(fallbackSourceType);
    }
    if (resolvedSignals.sourceType.isEmpty()) {
        resolvedSignals.sourceType = QStringLiteral("archive");
    }

    resolvedSignals.strictFilenameSignature = valueFromMap(values, QStringLiteral("importStrictFilenameSignature"));
    if (resolvedSignals.strictFilenameSignature.isEmpty()) {
        resolvedSignals.strictFilenameSignature = ComicImportMatching::normalizeFilenameSignatureStrict(resolvedSignals.originalFilename);
    }

    resolvedSignals.looseFilenameSignature = valueFromMap(values, QStringLiteral("importLooseFilenameSignature"));
    if (resolvedSignals.looseFilenameSignature.isEmpty()) {
        resolvedSignals.looseFilenameSignature = ComicImportMatching::normalizeFilenameSignatureLoose(resolvedSignals.originalFilename);
    }

    return resolvedSignals;
}

QVariantMap importSignalsToVariantMap(const PersistedImportSignals &persistedSignals)
{
    QVariantMap values;
    values.insert(QStringLiteral("importOriginalFilename"), persistedSignals.originalFilename);
    values.insert(QStringLiteral("importStrictFilenameSignature"), persistedSignals.strictFilenameSignature);
    values.insert(QStringLiteral("importLooseFilenameSignature"), persistedSignals.looseFilenameSignature);
    values.insert(QStringLiteral("importSourceType"), persistedSignals.sourceType);
    return values;
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
    return QStringLiteral("Archive support component (7z) is missing. Reinstall/repair Comic Pile or set a custom 7z path.");
}

bool tryRemoveFileWithDetails(
    const QString &filePath,
    QString &removedDirPathOut,
    DeleteFailureInfo &failureOut
)
{
    return ComicDeleteOps::tryRemoveFileWithDetails(filePath, removedDirPathOut, failureOut);
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

QVector<int> normalizeIdList(const QVariantList &raw)
{
    QVector<int> ids;
    ids.reserve(raw.size());

    QSet<int> seen;
    for (const QVariant &item : raw) {
        bool ok = false;
        const int id = item.toInt(&ok);
        if (!ok || id < 1 || seen.contains(id)) continue;
        seen.insert(id);
        ids.push_back(id);
    }

    return ids;
}

struct BulkUpdateSnapshot {
    int id = 0;
    QString filePath;
    QString filename;
    QString series;
    QString volume;
    QString title;
    QString issueNumber;
    QString publisher;
    int year = 0;
    int month = 0;
    QString writer;
    QString penciller;
    QString inker;
    QString colorist;
    QString letterer;
    QString coverArtist;
    QString editor;
    QString storyArc;
    QString summary;
    QString characters;
    QString genres;
    QString ageRating;
    QString readStatus;
    int currentPage = 0;
};

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

QString joinIssueIds(const QVector<int> &ids)
{
    QStringList parts;
    parts.reserve(ids.size());
    for (int id : ids) {
        parts.push_back(QString::number(id));
    }
    return parts.join(QStringLiteral(", "));
}

bool loadBulkUpdateSnapshots(
    QSqlDatabase &db,
    const QVector<int> &ids,
    QHash<int, BulkUpdateSnapshot> &snapshotsOut,
    QString &errorText
)
{
    snapshotsOut.clear();
    if (ids.isEmpty()) return true;

    QStringList placeholders;
    placeholders.reserve(ids.size());
    for (int i = 0; i < ids.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "SELECT "
            "id, "
            "COALESCE(file_path, ''), COALESCE(filename, ''), "
            "COALESCE(series, ''), COALESCE(volume, ''), COALESCE(title, ''), "
            "COALESCE(issue_number, issue, ''), COALESCE(publisher, ''), "
            "COALESCE(year, 0), COALESCE(month, 0), "
            "COALESCE(writer, ''), COALESCE(penciller, ''), COALESCE(inker, ''), "
            "COALESCE(colorist, ''), COALESCE(letterer, ''), COALESCE(cover_artist, ''), "
            "COALESCE(editor, ''), COALESCE(story_arc, ''), COALESCE(summary, ''), "
            "COALESCE(characters, ''), COALESCE(genres, ''), COALESCE(age_rating, ''), "
            "COALESCE(read_status, 'unread'), COALESCE(current_page, 0) "
            "FROM comics "
            "WHERE id IN (%1)"
        ).arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : ids) {
        query.addBindValue(id);
    }
    if (!query.exec()) {
        errorText = QStringLiteral("Failed to load bulk update targets: %1").arg(query.lastError().text());
        return false;
    }

    while (query.next()) {
        BulkUpdateSnapshot row;
        row.id = query.value(0).toInt();
        row.filePath = trimOrEmpty(query.value(1));
        row.filename = trimOrEmpty(query.value(2));
        row.series = trimOrEmpty(query.value(3));
        row.volume = trimOrEmpty(query.value(4));
        row.title = trimOrEmpty(query.value(5));
        row.issueNumber = trimOrEmpty(query.value(6));
        row.publisher = trimOrEmpty(query.value(7));
        row.year = query.value(8).toInt();
        row.month = query.value(9).toInt();
        row.writer = trimOrEmpty(query.value(10));
        row.penciller = trimOrEmpty(query.value(11));
        row.inker = trimOrEmpty(query.value(12));
        row.colorist = trimOrEmpty(query.value(13));
        row.letterer = trimOrEmpty(query.value(14));
        row.coverArtist = trimOrEmpty(query.value(15));
        row.editor = trimOrEmpty(query.value(16));
        row.storyArc = trimOrEmpty(query.value(17));
        row.summary = trimOrEmpty(query.value(18));
        row.characters = trimOrEmpty(query.value(19));
        row.genres = trimOrEmpty(query.value(20));
        row.ageRating = trimOrEmpty(query.value(21));
        row.readStatus = trimOrEmpty(query.value(22));
        row.currentPage = query.value(23).toInt();
        snapshotsOut.insert(row.id, row);
    }

    return true;
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

QString makeUniqueFilename(const QDir &dir, const QString &filename)
{
    return ComicLibraryLayout::makeUniqueFilename(dir, filename);
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

QString parentFolderNameForFile(const QFileInfo &fileInfo)
{
    const QString absolutePath = fileInfo.absolutePath();
    if (absolutePath.isEmpty()) return {};
    return QFileInfo(absolutePath).fileName().trimmed();
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

    const QString contextSeriesKey = normalizeSeriesKeyValue(contextSeries);
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

QString resolve7ZipExecutable();
QSet<QString> resolvedSevenZipArchiveExtensions();

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

const QSet<QString> &nativeImportArchiveExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("cbz"),
        QStringLiteral("zip")
    };
    return extensions;
}

const QSet<QString> &documentImportExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("pdf"),
        QStringLiteral("djvu"),
        QStringLiteral("djv")
    };
    return extensions;
}

const QSet<QString> &fallbackSevenZipArchiveExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("7z"),
        QStringLiteral("apk"),
        QStringLiteral("ar"),
        QStringLiteral("arj"),
        QStringLiteral("bz2"),
        QStringLiteral("cab"),
        QStringLiteral("cb7"),
        QStringLiteral("cbr"),
        QStringLiteral("chm"),
        QStringLiteral("cpio"),
        QStringLiteral("deb"),
        QStringLiteral("dmg"),
        QStringLiteral("ear"),
        QStringLiteral("epub"),
        QStringLiteral("gz"),
        QStringLiteral("iso"),
        QStringLiteral("jar"),
        QStringLiteral("lha"),
        QStringLiteral("lzh"),
        QStringLiteral("lz"),
        QStringLiteral("lzma"),
        QStringLiteral("msi"),
        QStringLiteral("nupkg"),
        QStringLiteral("pkg"),
        QStringLiteral("qcow"),
        QStringLiteral("qcow2"),
        QStringLiteral("rar"),
        QStringLiteral("rpm"),
        QStringLiteral("squashfs"),
        QStringLiteral("tar"),
        QStringLiteral("taz"),
        QStringLiteral("tbz"),
        QStringLiteral("tbz2"),
        QStringLiteral("tgz"),
        QStringLiteral("txz"),
        QStringLiteral("udf"),
        QStringLiteral("vdi"),
        QStringLiteral("vhd"),
        QStringLiteral("vhdx"),
        QStringLiteral("vmdk"),
        QStringLiteral("war"),
        QStringLiteral("wim"),
        QStringLiteral("xar"),
        QStringLiteral("xz"),
        QStringLiteral("z"),
        QStringLiteral("zipx"),
        QStringLiteral("zst"),
        QStringLiteral("tzst")
    };
    return extensions;
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

bool isPdfExtension(const QString &extension)
{
    return normalizeArchiveExtension(extension) == QStringLiteral("pdf");
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
    const QString normalized = normalizeArchiveExtension(extension);
    if (normalized.isEmpty()) return false;
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    return extensions.contains(normalized);
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
    const QSet<QString> extensions = supportedImportArchiveExtensionsSet();
    return extensions.contains(normalized);
}

bool isSupportedArchiveExtension(const QString &path)
{
    const QString extension = normalizeArchiveExtension(path);
    return isImportArchiveExtensionSupported(extension);
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

QString relativeDirUnderRoot(const QString &rootPath, const QString &filePath)
{
    return ComicLibraryLayout::relativeDirUnderRoot(rootPath, filePath);
}

using SeriesFolderState = ComicLibraryLayout::SeriesFolderState;

bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText)
{
    return ComicLibraryLayout::moveFileWithFallback(sourcePath, targetPath, errorText);
}

using StagedArchiveDeleteOp = ComicDeleteOps::StagedArchiveDeleteOp;

bool performStageArchiveDelete(
    const QString &filePath,
    StagedArchiveDeleteOp &opOut,
    DeleteFailureInfo &failureOut
)
{
    return ComicDeleteOps::stageArchiveDelete(filePath, opOut, failureOut);
}

bool performRollbackStagedArchiveDelete(const StagedArchiveDeleteOp &op, DeleteFailureInfo &failureOut)
{
    return ComicDeleteOps::rollbackStagedArchiveDelete(op, failureOut);
}

bool performFinalizeStagedArchiveDelete(
    const StagedArchiveDeleteOp &op,
    QString &cleanupDirPathOut,
    DeleteFailureInfo &failureOut
)
{
    return ComicDeleteOps::finalizeStagedArchiveDelete(op, cleanupDirPathOut, failureOut);
}

QString performRollbackStagedArchiveDeletes(const QVector<StagedArchiveDeleteOp> &ops)
{
    return ComicDeleteOps::rollbackStagedArchiveDeletes(ops);
}

QSet<QString> parseSevenZipExtensionsFromIndexOutput(const QString &output)
{
    QSet<QString> extensions;
    if (output.trimmed().isEmpty()) return extensions;

    bool inFormatsSection = false;
    const QStringList lines = output.split('\n');
    const QRegularExpression rowPattern(
        "^\\s*[0-9]{0,3}\\s*[A-Z\\.]{0,8}\\s*[A-Z\\.]{0,8}\\s+[^\\s]+\\s+(.+?)\\s*$",
        QRegularExpression::CaseInsensitiveOption
    );
    const QRegularExpression tokenCleaner("[^a-z0-9+\\-.]");
    const QRegularExpression validTokenPattern("^[a-z0-9][a-z0-9+\\-]{0,31}$");

    for (const QString &rawLine : lines) {
        const QString trimmed = rawLine.trimmed();
        if (trimmed.isEmpty()) continue;

        if (!inFormatsSection) {
            if (trimmed.compare(QStringLiteral("Formats:"), Qt::CaseInsensitive) == 0) {
                inFormatsSection = true;
            }
            continue;
        }

        if (trimmed.endsWith(':') && trimmed.compare(QStringLiteral("Formats:"), Qt::CaseInsensitive) != 0) {
            break;
        }

        const QRegularExpressionMatch rowMatch = rowPattern.match(rawLine);
        if (!rowMatch.hasMatch()) continue;

        const QString extChunk = rowMatch.captured(1);
        const QStringList rawTokens = extChunk.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        for (const QString &rawToken : rawTokens) {
            QString token = rawToken.trimmed().toLower();
            if (token.startsWith('.')) {
                token = token.mid(1);
            }
            token.remove(tokenCleaner);
            if (!validTokenPattern.match(token).hasMatch()) continue;
            extensions.insert(token);
        }
    }

    return extensions;
}

QSet<QString> resolvedSevenZipArchiveExtensions()
{
    static QString cachedExecutable;
    static QSet<QString> cachedExtensions = fallbackSevenZipArchiveExtensions();

    const QString executable = resolve7ZipExecutable();
    if (!cachedExecutable.isEmpty()
            && executable.compare(cachedExecutable, Qt::CaseInsensitive) == 0) {
        return cachedExtensions;
    }

    cachedExecutable = executable;
    cachedExtensions = fallbackSevenZipArchiveExtensions();

    if (executable.isEmpty()) {
        return cachedExtensions;
    }

    QByteArray stdOutBytes;
    QByteArray stdErrBytes;
    QString errorText;
    if (!ComicArchiveProcess::runExternalProcess(
            executable,
            { QStringLiteral("i") },
            stdOutBytes,
            stdErrBytes,
            errorText,
            15000
        )) {
        return cachedExtensions;
    }

    const QString stdOut = QString::fromUtf8(stdOutBytes);
    const QSet<QString> parsed = parseSevenZipExtensionsFromIndexOutput(stdOut);
    if (!parsed.isEmpty()) {
        cachedExtensions.unite(parsed);
    }
    return cachedExtensions;
}

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
    resetLastImportOutcome();
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

void ComicsListModel::resetLastImportOutcome()
{
    m_lastImportAction.clear();
    m_lastImportComicId = -1;
    m_lastImportDuplicateId = -1;
    m_lastImportDuplicateTier.clear();
    m_lastImportRestoreCandidateCount = 0;
    m_lastImportRestoreCandidateId = -1;
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
    m_readerArchivePathById.clear();
    m_readerImageEntriesById.clear();
    m_readerPageMetricsById.clear();
    m_deferredImportFolderBySeriesKey.clear();
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
        m_readerArchivePathById.clear();
        m_readerImageEntriesById.clear();
        m_readerPageMetricsById.clear();
        invalidateAllReaderAsyncState();
        endResetModel();
        emit statusChanged();
    });
    watcher->setFuture(QtConcurrent::run([validationGeneration, validationRows]() {
        return validateReloadRowsAsync(validationGeneration, validationRows);
    }));
}

QString ComicsListModel::updateComicMetadata(
    int comicId,
    const QVariantMap &values
)
{
    if (comicId < 1) return QString("Invalid issue id.");

    QVariantMap normalizedValues;
    QVariantMap applyMap;

    auto applyDirect = [&](const QString &key) {
        if (!values.contains(key)) return;
        applyMap.insert(key, true);
        normalizedValues.insert(key, values.value(key));
    };

    auto applyAlias = [&](const QString &canonical, const QString &alias) {
        const bool hasCanonical = values.contains(canonical);
        const bool hasAlias = values.contains(alias);
        if (!hasCanonical && !hasAlias) return;
        applyMap.insert(canonical, true);
        normalizedValues.insert(canonical, hasCanonical ? values.value(canonical) : values.value(alias));
    };

    applyDirect(QStringLiteral("series"));
    applyDirect(QStringLiteral("volume"));
    applyDirect(QStringLiteral("title"));
    applyAlias(QStringLiteral("issueNumber"), QStringLiteral("issue"));
    applyDirect(QStringLiteral("publisher"));
    applyDirect(QStringLiteral("year"));
    applyDirect(QStringLiteral("month"));
    applyDirect(QStringLiteral("writer"));
    applyDirect(QStringLiteral("penciller"));
    applyDirect(QStringLiteral("inker"));
    applyDirect(QStringLiteral("colorist"));
    applyDirect(QStringLiteral("letterer"));
    applyAlias(QStringLiteral("coverArtist"), QStringLiteral("cover_artist"));
    applyDirect(QStringLiteral("editor"));
    applyAlias(QStringLiteral("storyArc"), QStringLiteral("story_arc"));
    applyDirect(QStringLiteral("summary"));
    applyDirect(QStringLiteral("characters"));
    applyDirect(QStringLiteral("genres"));
    applyAlias(QStringLiteral("ageRating"), QStringLiteral("age_rating"));
    applyAlias(QStringLiteral("readStatus"), QStringLiteral("read_status"));
    applyAlias(QStringLiteral("currentPage"), QStringLiteral("current_page"));

    if (applyMap.isEmpty()) {
        return QString("No metadata fields to update.");
    }

    QVariantList ids;
    ids.push_back(comicId);
    return bulkUpdateMetadata(ids, normalizedValues, applyMap);
}

QString ComicsListModel::bulkUpdateMetadata(
    const QVariantList &comicIds,
    const QVariantMap &values,
    const QVariantMap &applyMap
)
{
    const QVector<int> ids = normalizeIdList(comicIds);
    if (ids.isEmpty()) return QString("No issues selected.");

    const bool applySeries = boolFromMap(applyMap, "series");
    const bool applyVolume = boolFromMap(applyMap, "volume");
    const bool applyTitle = boolFromMap(applyMap, "title");
    const bool applyIssueNumber = boolFromMap(applyMap, "issueNumber") || boolFromMap(applyMap, "issue");
    const bool applyPublisher = boolFromMap(applyMap, "publisher");
    const bool applyYear = boolFromMap(applyMap, "year");
    const bool applyMonth = boolFromMap(applyMap, "month");
    const bool applyWriter = boolFromMap(applyMap, "writer");
    const bool applyPenciller = boolFromMap(applyMap, "penciller");
    const bool applyInker = boolFromMap(applyMap, "inker");
    const bool applyColorist = boolFromMap(applyMap, "colorist");
    const bool applyLetterer = boolFromMap(applyMap, "letterer");
    const bool applyCoverArtist = boolFromMap(applyMap, "coverArtist") || boolFromMap(applyMap, "cover_artist");
    const bool applyEditor = boolFromMap(applyMap, "editor");
    const bool applyStoryArc = boolFromMap(applyMap, "storyArc") || boolFromMap(applyMap, "story_arc");
    const bool applySummary = boolFromMap(applyMap, "summary");
    const bool applyCharacters = boolFromMap(applyMap, "characters");
    const bool applyGenres = boolFromMap(applyMap, "genres");
    const bool applyAgeRating = boolFromMap(applyMap, "ageRating") || boolFromMap(applyMap, "age_rating");
    const bool applyReadStatus = boolFromMap(applyMap, "readStatus") || boolFromMap(applyMap, "read_status");
    const bool applyCurrentPage = boolFromMap(applyMap, "currentPage") || boolFromMap(applyMap, "current_page");

    QStringList sets;
    if (applySeries) sets << "series = ?" << "series_key = ?";
    if (applyVolume) sets << "volume = ?";
    if (applyTitle) sets << "title = ?";
    if (applyIssueNumber) sets << "issue_number = ?";
    if (applyIssueNumber) sets << "issue = ?";
    if (applyPublisher) sets << "publisher = ?";
    if (applyYear) sets << "year = ?";
    if (applyMonth) sets << "month = ?";
    if (applyWriter) sets << "writer = ?";
    if (applyPenciller) sets << "penciller = ?";
    if (applyInker) sets << "inker = ?";
    if (applyColorist) sets << "colorist = ?";
    if (applyLetterer) sets << "letterer = ?";
    if (applyCoverArtist) sets << "cover_artist = ?";
    if (applyEditor) sets << "editor = ?";
    if (applyStoryArc) sets << "story_arc = ?";
    if (applySummary) sets << "summary = ?";
    if (applyCharacters) sets << "characters = ?";
    if (applyGenres) sets << "genres = ?";
    if (applyAgeRating) sets << "age_rating = ?";
    if (applyReadStatus) sets << "read_status = ?";
    if (applyCurrentPage) sets << "current_page = ?";

    if (sets.isEmpty()) {
        return QString("Select at least one field to apply.");
    }

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
    if (applyYear && !yearOk) {
        return QString("Year must be empty or an integer between 0 and 9999.");
    }

    const QString monthInput = valueFromMap(values, "month");
    bool monthOk = false;
    bool monthIsNull = false;
    const int parsedMonth = parseOptionalMonth(monthInput, monthOk, monthIsNull);
    if (applyMonth && !monthOk) {
        return QString("Month must be empty or an integer between 1 and 12.");
    }

    const QString readStatusInput = valueFromMap(values, "readStatus", "read_status");
    const QString readStatus = normalizeReadStatus(readStatusInput);
    if (applyReadStatus && readStatusInput.length() > 0 && readStatus.isEmpty()) {
        return QString("Read status must be one of: unread, in_progress, read.");
    }

    const QString currentPageInput = valueFromMap(values, "currentPage", "current_page");
    bool currentPageOk = false;
    bool currentPageIsNull = false;
    const int parsedCurrentPage = parseOptionalCurrentPage(currentPageInput, currentPageOk, currentPageIsNull);
    if (applyCurrentPage && !currentPageOk) {
        return QString("Current page must be empty or an integer between 0 and 1000000.");
    }

    struct SeriesMoveOp {
        int id = 0;
        QString sourcePath;
        QString targetPath;
    };

    QVector<SeriesMoveOp> appliedSeriesMoves;
    QHash<int, QString> movedPathById;
    QHash<int, QString> movedFilenameById;
    QStringList moveCleanupDirs;
    QSet<QString> seriesHeroKeysToPurge;
    const QString libraryRootPath = QDir(m_dataRoot).filePath(QStringLiteral("Library"));

    auto rollbackSeriesMoves = [&]() -> QString {
        QStringList rollbackErrors;
        QStringList rollbackCleanupDirs = moveCleanupDirs;
        for (int i = appliedSeriesMoves.size() - 1; i >= 0; i -= 1) {
            const SeriesMoveOp &op = appliedSeriesMoves.at(i);
            QString rollbackError;
            if (!moveFileWithFallback(op.targetPath, op.sourcePath, rollbackError)) {
                rollbackErrors.push_back(
                    QStringLiteral("Issue %1: %2").arg(op.id).arg(rollbackError)
                );
            }
            rollbackCleanupDirs.push_back(QFileInfo(op.sourcePath).absolutePath());
            rollbackCleanupDirs.push_back(QFileInfo(op.targetPath).absolutePath());
        }
        if (!rollbackCleanupDirs.isEmpty()) {
            cleanupEmptyLibraryDirs(libraryRootPath, rollbackCleanupDirs);
        }
        if (!rollbackErrors.isEmpty()) {
            return rollbackErrors.join('\n');
        }
        return {};
    };

    auto failWithRollback = [&](const QString &baseError) -> QString {
        QString finalError = baseError;
        const QString rollbackError = rollbackSeriesMoves();
        if (!rollbackError.isEmpty()) {
            finalError += QStringLiteral("\nRollback warning:\n%1").arg(rollbackError);
        }
        return finalError;
    };

    const QString sql = QString("UPDATE comics SET %1 WHERE id = ?").arg(sets.join(", "));
    const QString normalizedSeriesValue = applySeries ? normalizeSeriesKey(series) : QString();
    const QString connectionName = QString("comic_pile_bulk_update_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;

    {
        QSqlDatabase db;
        if (!openDatabaseConnection(db, connectionName, openError)) {
            return failWithRollback(openError);
        }

        QHash<int, BulkUpdateSnapshot> preflightRows;
        QString preflightError;
        if (!loadBulkUpdateSnapshots(db, ids, preflightRows, preflightError)) {
            db.close();
            return failWithRollback(preflightError);
        }

        QVector<int> missingIds;
        for (int id : ids) {
            if (!preflightRows.contains(id)) {
                missingIds.push_back(id);
            }
        }
        if (!missingIds.isEmpty()) {
            db.close();
            return QStringLiteral(
                "Bulk edit stopped because %1 selected issue(s) no longer exist.\n"
                "Refresh the library and try again.\n"
                "Affected ids: %2"
            ).arg(missingIds.size()).arg(joinIssueIds(missingIds));
        }

        QVector<int> staleIds;
        for (int id : ids) {
            const BulkUpdateSnapshot row = preflightRows.value(id);
            const QString preflightPath = resolveStoredArchivePathForDataRoot(
                m_dataRoot,
                row.filePath,
                row.filename
            );
            if (preflightPath.isEmpty()) {
                staleIds.push_back(id);
            }
        }
        if (!staleIds.isEmpty()) {
            db.close();
            return QStringLiteral(
                "Bulk edit stopped because some selected archive files are no longer available on disk.\n"
                "Refresh the library and try again.\n"
                "Affected ids: %1"
            ).arg(joinIssueIds(staleIds));
        }

        if (applySeries || applyVolume) {
            for (int id : ids) {
                const BulkUpdateSnapshot row = preflightRows.value(id);
                const QString oldSeriesKey = buildSeriesGroupKey(row.series, row.volume);
                const QString nextSeriesKey = buildSeriesGroupKey(
                    applySeries ? series : row.series,
                    applyVolume ? volume : row.volume
                );
                if (!oldSeriesKey.isEmpty() && oldSeriesKey != nextSeriesKey) {
                    seriesHeroKeysToPurge.insert(oldSeriesKey);
                }
            }
        }

        if (applySeries) {
            const QString libraryPath = libraryRootPath;
            if (!QDir().mkpath(libraryPath)) {
                db.close();
                return QStringLiteral("Bulk edit could not prepare the library folder for a series move.");
            }

            QSet<int> selectedIdSet;
            selectedIdSet.reserve(ids.size());
            for (int id : ids) selectedIdSet.insert(id);

            SeriesFolderState folderState;
            for (const ComicRow &row : m_rows) {
                const QString rowSeriesKey = normalizeSeriesKey(row.series);
                const bool rowWillLeaveCurrentSeries = selectedIdSet.contains(row.id) && rowSeriesKey != normalizedSeriesValue;
                if (rowWillLeaveCurrentSeries) continue;

                if (row.filePath.trimmed().isEmpty()) continue;
                const QString relativeDir = relativeDirUnderRoot(libraryPath, row.filePath);
                if (relativeDir.isEmpty()) continue;
                ComicLibraryLayout::registerSeriesFolderAssignment(folderState, rowSeriesKey, relativeDir);
            }

            const QString targetFolderName = ComicLibraryLayout::assignSeriesFolderName(folderState, normalizedSeriesValue, series);
            const QString targetDirPath = QDir(libraryPath).filePath(targetFolderName);
            const QDir targetDir(targetDirPath);

            for (int id : ids) {
                const BulkUpdateSnapshot row = preflightRows.value(id);
                const QString sourcePath = resolveStoredArchivePathForDataRoot(
                    m_dataRoot,
                    row.filePath,
                    row.filename
                );
                if (sourcePath.isEmpty()) continue;

                const QFileInfo sourceInfo(sourcePath);
                if (!sourceInfo.exists() || !sourceInfo.isFile()) {
                    db.close();
                    return failWithRollback(
                        QStringLiteral(
                            "Bulk edit stopped because issue %1 is missing its archive file on disk."
                        ).arg(id)
                    );
                }

                QString filenameValue = row.filename.trimmed();
                if (filenameValue.isEmpty()) {
                    filenameValue = sourceInfo.fileName();
                }
                if (filenameValue.isEmpty()) continue;

                QString targetPath = targetDir.filePath(filenameValue);
                const QString sourceKey = normalizedPathForCompare(sourcePath);
                QString targetKey = normalizedPathForCompare(targetPath);
                if (sourceKey != targetKey && QFileInfo::exists(targetPath)) {
                    filenameValue = makeUniqueFilename(targetDir, filenameValue);
                    targetPath = targetDir.filePath(filenameValue);
                    targetKey = normalizedPathForCompare(targetPath);
                }

                if (sourceKey == targetKey) continue;

                QString moveError;
                if (!moveFileWithFallback(sourcePath, targetPath, moveError)) {
                    db.close();
                    return failWithRollback(
                        QStringLiteral("Bulk edit could not move issue %1 into the target series folder: %2")
                            .arg(id)
                            .arg(moveError)
                    );
                }

                SeriesMoveOp op;
                op.id = id;
                op.sourcePath = QDir::toNativeSeparators(QFileInfo(sourcePath).absoluteFilePath());
                op.targetPath = QDir::toNativeSeparators(QFileInfo(targetPath).absoluteFilePath());
                appliedSeriesMoves.push_back(op);
                movedPathById.insert(id, op.targetPath);
                movedFilenameById.insert(id, filenameValue);
                moveCleanupDirs.push_back(sourceInfo.absolutePath());
            }
        }

        if (!db.transaction()) {
            const QString error = QStringLiteral("Bulk edit could not start saving changes: %1").arg(db.lastError().text());
            db.close();
            return failWithRollback(error);
        }

        QSqlQuery query(db);
        for (int id : ids) {
            query.prepare(sql);
            if (applySeries) {
                query.addBindValue(series);
                query.addBindValue(normalizedSeriesValue);
            }
            if (applyVolume) {
                query.addBindValue(volume);
            }
            if (applyTitle) {
                query.addBindValue(title);
            }
            if (applyIssueNumber) {
                query.addBindValue(issueNumber);
                query.addBindValue(issueNumber);
            }
            if (applyPublisher) {
                query.addBindValue(publisher);
            }
            if (applyYear) {
                if (yearIsNull) {
                    query.addBindValue(QVariant());
                } else {
                    query.addBindValue(parsedYear);
                }
            }
            if (applyMonth) {
                if (monthIsNull) {
                    query.addBindValue(QVariant());
                } else {
                    query.addBindValue(parsedMonth);
                }
            }
            if (applyWriter) query.addBindValue(writer);
            if (applyPenciller) query.addBindValue(penciller);
            if (applyInker) query.addBindValue(inker);
            if (applyColorist) query.addBindValue(colorist);
            if (applyLetterer) query.addBindValue(letterer);
            if (applyCoverArtist) query.addBindValue(coverArtist);
            if (applyEditor) query.addBindValue(editor);
            if (applyStoryArc) query.addBindValue(storyArc);
            if (applySummary) query.addBindValue(summary);
            if (applyCharacters) query.addBindValue(characters);
            if (applyGenres) query.addBindValue(genres);
            if (applyAgeRating) query.addBindValue(ageRating);
            if (applyReadStatus) query.addBindValue(readStatus.isEmpty() ? QString("unread") : readStatus);
            if (applyCurrentPage) query.addBindValue(currentPageIsNull ? 0 : parsedCurrentPage);
            query.addBindValue(id);

            if (!query.exec()) {
                const QString error = QStringLiteral("Bulk edit failed while saving issue %1: %2").arg(id).arg(query.lastError().text());
                db.rollback();
                db.close();
                return failWithRollback(error);
            }
            query.finish();
        }

        if (!movedPathById.isEmpty()) {
            QSqlQuery moveQuery(db);
            moveQuery.prepare("UPDATE comics SET file_path = ?, filename = ? WHERE id = ?");
            for (auto it = movedPathById.constBegin(); it != movedPathById.constEnd(); ++it) {
                const int id = it.key();
                moveQuery.bindValue(0, ComicStoragePaths::persistPathForDataRoot(m_dataRoot, it.value()));
                moveQuery.bindValue(1, movedFilenameById.value(id));
                moveQuery.bindValue(2, id);
                if (!moveQuery.exec()) {
                    const QString error = QStringLiteral("Bulk edit moved an archive but could not save the new path for issue %1: %2").arg(id).arg(moveQuery.lastError().text());
                    db.rollback();
                    db.close();
                    return failWithRollback(error);
                }
                moveQuery.finish();
            }
        }

        QHash<int, BulkUpdateSnapshot> verifyRows;
        QString verifyLoadError;
        if (!loadBulkUpdateSnapshots(db, ids, verifyRows, verifyLoadError)) {
            db.rollback();
            db.close();
            return failWithRollback(verifyLoadError);
        }

        QStringList verifyFailures;
        auto appendTextMismatch = [&](int id, const QString &fieldName, const QString &expected, const QString &actual) {
            if (expected == actual) return;
            verifyFailures.push_back(
                QStringLiteral("Issue %1 %2 mismatch (expected \"%3\", got \"%4\").")
                    .arg(id)
                    .arg(fieldName, expected, actual)
            );
        };
        auto appendNumberMismatch = [&](int id, const QString &fieldName, int expected, int actual) {
            if (expected == actual) return;
            verifyFailures.push_back(
                QStringLiteral("Issue %1 %2 mismatch (expected %3, got %4).")
                    .arg(id)
                    .arg(fieldName)
                    .arg(expected)
                    .arg(actual)
            );
        };

        for (int id : ids) {
            if (!verifyRows.contains(id)) {
                verifyFailures.push_back(QStringLiteral("Issue %1 disappeared during verification.").arg(id));
                continue;
            }

            const BulkUpdateSnapshot actual = verifyRows.value(id);
            if (applySeries) appendTextMismatch(id, QStringLiteral("series"), series, actual.series);
            if (applyVolume) appendTextMismatch(id, QStringLiteral("volume"), volume, actual.volume);
            if (applyTitle) appendTextMismatch(id, QStringLiteral("title"), title, actual.title);
            if (applyIssueNumber) appendTextMismatch(id, QStringLiteral("issue number"), issueNumber, actual.issueNumber);
            if (applyPublisher) appendTextMismatch(id, QStringLiteral("publisher"), publisher, actual.publisher);
            if (applyYear) appendNumberMismatch(id, QStringLiteral("year"), yearIsNull ? 0 : parsedYear, actual.year);
            if (applyMonth) appendNumberMismatch(id, QStringLiteral("month"), monthIsNull ? 0 : parsedMonth, actual.month);
            if (applyWriter) appendTextMismatch(id, QStringLiteral("writer"), writer, actual.writer);
            if (applyPenciller) appendTextMismatch(id, QStringLiteral("penciller"), penciller, actual.penciller);
            if (applyInker) appendTextMismatch(id, QStringLiteral("inker"), inker, actual.inker);
            if (applyColorist) appendTextMismatch(id, QStringLiteral("colorist"), colorist, actual.colorist);
            if (applyLetterer) appendTextMismatch(id, QStringLiteral("letterer"), letterer, actual.letterer);
            if (applyCoverArtist) appendTextMismatch(id, QStringLiteral("cover artist"), coverArtist, actual.coverArtist);
            if (applyEditor) appendTextMismatch(id, QStringLiteral("editor"), editor, actual.editor);
            if (applyStoryArc) appendTextMismatch(id, QStringLiteral("story arc"), storyArc, actual.storyArc);
            if (applySummary) appendTextMismatch(id, QStringLiteral("summary"), summary, actual.summary);
            if (applyCharacters) appendTextMismatch(id, QStringLiteral("characters"), characters, actual.characters);
            if (applyGenres) appendTextMismatch(id, QStringLiteral("genres"), genres, actual.genres);
            if (applyAgeRating) appendTextMismatch(id, QStringLiteral("age rating"), ageRating, actual.ageRating);
            if (applyReadStatus) appendTextMismatch(id, QStringLiteral("read status"), readStatus.isEmpty() ? QStringLiteral("unread") : readStatus, actual.readStatus);
            if (applyCurrentPage) appendNumberMismatch(id, QStringLiteral("current page"), currentPageIsNull ? 0 : parsedCurrentPage, actual.currentPage);

            if (movedPathById.contains(id)) {
                const QString expectedFilePath = movedPathById.value(id);
                const QString actualResolvedFilePath = resolveStoredArchivePathForDataRoot(
                    m_dataRoot,
                    actual.filePath,
                    actual.filename
                );
                if (normalizedPathForCompare(expectedFilePath) != normalizedPathForCompare(actualResolvedFilePath)) {
                    verifyFailures.push_back(
                        QStringLiteral("Issue %1 file path mismatch after move.").arg(id)
                    );
                }
                if (!filePathExists(expectedFilePath)) {
                    verifyFailures.push_back(
                        QStringLiteral("Issue %1 moved archive is missing after save.").arg(id)
                    );
                }
                appendTextMismatch(id, QStringLiteral("filename"), movedFilenameById.value(id), actual.filename);
            } else if (
                (!actual.filePath.trimmed().isEmpty() || !actual.filename.trimmed().isEmpty())
                && resolveStoredArchivePathForDataRoot(m_dataRoot, actual.filePath, actual.filename).isEmpty()
            ) {
                verifyFailures.push_back(
                    QStringLiteral("Issue %1 archive file is missing after save.").arg(id)
                );
            }
        }

        if (!verifyFailures.isEmpty()) {
            const int maxErrors = std::min(8, static_cast<int>(verifyFailures.size()));
            const QStringList head = verifyFailures.mid(0, maxErrors);
            const QString suffix = verifyFailures.size() > maxErrors
                ? QStringLiteral("\n... and %1 more").arg(verifyFailures.size() - maxErrors)
                : QString();
            const QString verifyError = QStringLiteral("Bulk edit could not verify the saved result, so nothing was committed.\n%1%2")
                .arg(head.join('\n'))
                .arg(suffix);
            db.rollback();
            db.close();
            return failWithRollback(verifyError);
        }

        if (!db.commit()) {
            const QString error = QStringLiteral("Bulk edit could not finalize the save: %1").arg(db.lastError().text());
            db.close();
            return failWithRollback(error);
        }

        db.close();
    }

    if (!moveCleanupDirs.isEmpty()) {
        cleanupEmptyLibraryDirs(
            libraryRootPath,
            moveCleanupDirs
        );
    }

    for (const QString &seriesKey : seriesHeroKeysToPurge) {
        purgeSeriesHeroCacheForKey(seriesKey);
    }

    bool updatedInMemory = false;
    QVector<int> updatedIndices;
    updatedIndices.reserve(ids.size());
    QSet<int> idSet;
    idSet.reserve(ids.size());
    for (int id : ids) idSet.insert(id);

    const bool sortSensitiveFieldsChanged =
        applySeries
        || applyVolume
        || applyIssueNumber
        || applyTitle
        || (m_sortMode == QString("year_desc") && (applyYear || applyMonth));

    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (!idSet.contains(row.id)) continue;

        if (applySeries) {
            row.series = series;
        }
        if (movedPathById.contains(row.id)) {
            row.filePath = movedPathById.value(row.id);
            const QString movedFilename = movedFilenameById.value(row.id);
            if (!movedFilename.isEmpty()) {
                row.filename = movedFilename;
            }
        }
        if (applyVolume) {
            row.volume = volume;
            row.volumeGroupKey = normalizeVolumeKey(row.volume);
        }
        if (applySeries || applyVolume) {
            const QString normalizedSeriesKey = normalizeSeriesKey(row.series);
            if (row.volumeGroupKey == QString("__no_volume__")) {
                row.seriesGroupKey = normalizedSeriesKey;
            } else {
                row.seriesGroupKey = QString("%1::vol::%2").arg(normalizedSeriesKey, row.volumeGroupKey);
            }
            row.seriesGroupTitle = formatSeriesGroupTitle(row.series, row.volume);
        }
        if (applyTitle) {
            row.title = title;
        }
        if (applyIssueNumber) {
            row.issueNumber = issueNumber;
        }
        if (applyPublisher) row.publisher = publisher;
        if (applyYear) row.year = yearIsNull ? 0 : parsedYear;
        if (applyMonth) row.month = monthIsNull ? 0 : parsedMonth;
        if (applyWriter) row.writer = writer;
        if (applyPenciller) row.penciller = penciller;
        if (applyInker) row.inker = inker;
        if (applyColorist) row.colorist = colorist;
        if (applyLetterer) row.letterer = letterer;
        if (applyCoverArtist) row.coverArtist = coverArtist;
        if (applyEditor) row.editor = editor;
        if (applyStoryArc) row.storyArc = storyArc;
        if (applySummary) row.summary = summary;
        if (applyCharacters) row.characters = characters;
        if (applyGenres) row.genres = genres;
        if (applyAgeRating) row.ageRating = ageRating;
        if (applyReadStatus) row.readStatus = readStatus.isEmpty() ? QString("unread") : readStatus;
        if (applyCurrentPage) row.currentPage = currentPageIsNull ? 0 : parsedCurrentPage;
        updatedInMemory = true;
        updatedIndices.push_back(rowIndex);
    }

    if (updatedInMemory) {
        if (sortSensitiveFieldsChanged) {
            beginResetModel();
            std::sort(m_rows.begin(), m_rows.end(), [this](const ComicRow &left, const ComicRow &right) {
                return compareRows(left, right) < 0;
            });
            endResetModel();
        } else {
            for (int rowIndex : updatedIndices) {
                const QModelIndex index = this->index(rowIndex, 0);
                emit dataChanged(index, index);
            }
        }
    }
    m_lastMutationKind = QString("bulk_update_metadata");
    emit statusChanged();
    return {};
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

    const QString cachedPath = m_readerArchivePathById.value(comicId).trimmed();
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
    const QString seriesKey = seriesGroupKeyForComicId(comicId);

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
        existingFilename = ensureTargetCbzFilename(filenameHint, QFileInfo(sourcePath).fileName());
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
    const PersistedImportSignals previousImportSignals = resolvedImportSignals(
        metadata,
        existingFilename,
        QStringLiteral("archive")
    );
    const PersistedImportSignals newImportSignals = resolvedImportSignals(
        values,
        importSourceLabel,
        normalizedSourceType
    );
    const bool keepBackupForRollback = values.value(QStringLiteral("keepBackupForRollback")).toBool();
    result.insert(QStringLiteral("sourcePath"), normalizedSourcePath);
    result.insert(QStringLiteral("sourceType"), normalizedSourceType);
    result.insert(QStringLiteral("previousImportSignals"), importSignalsToVariantMap(previousImportSignals));
    result.insert(QStringLiteral("importSignals"), importSignalsToVariantMap(newImportSignals));

    QVector<FingerprintHistoryEntrySpec> fingerprintHistoryEntries;
    FingerprintSnapshot oldLibraryFingerprint;
    QString oldLibraryFingerprintError;
    if (computeFileFingerprint(existingFilePath, oldLibraryFingerprint, oldLibraryFingerprintError)) {
        appendFingerprintHistoryEntry(
            fingerprintHistoryEntries,
            comicId,
            seriesKey,
            QStringLiteral("replace_outgoing"),
            QStringLiteral("archive"),
            QStringLiteral("library"),
            oldLibraryFingerprint,
            existingFilename
        );
    }

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
    if (!performStageArchiveDelete(existingFilePath, stagedDelete, stageFailure)) {
        result.insert(QStringLiteral("code"), QStringLiteral("replace_stage_failed"));
        result.insert(QStringLiteral("error"), formatDeleteFailureText(stageFailure));
        return result;
    }

    auto rollbackStage = [&]() -> QString {
        DeleteFailureInfo rollbackFailure;
        if (performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
            return {};
        }
        return formatDeleteFailureText(rollbackFailure);
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
        importSignalsToVariantMap(newImportSignals)
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

    FingerprintSnapshot sourceFingerprint;
    QString sourceFingerprintError;
    if (computeImportSourceFingerprint(normalizedSourcePath, normalizedSourceType, sourceFingerprint, sourceFingerprintError)) {
        appendFingerprintHistoryEntry(
            fingerprintHistoryEntries,
            comicId,
            seriesKey,
            QStringLiteral("replace_incoming"),
            normalizedSourceType,
            QStringLiteral("source"),
            sourceFingerprint,
            importSourceLabel
        );
    }

    FingerprintSnapshot newLibraryFingerprint;
    QString newLibraryFingerprintError;
    if (computeFileFingerprint(existingFilePath, newLibraryFingerprint, newLibraryFingerprintError)) {
        appendFingerprintHistoryEntry(
            fingerprintHistoryEntries,
            comicId,
            seriesKey,
            QStringLiteral("replace_incoming"),
            QStringLiteral("archive"),
            QStringLiteral("library"),
            newLibraryFingerprint,
            existingFilename
        );
    }

    QVariantList fingerprintHistoryIds;
    insertFingerprintHistoryEntries(m_dbPath, fingerprintHistoryEntries, &fingerprintHistoryIds);
    if (!fingerprintHistoryIds.isEmpty()) {
        result.insert(QStringLiteral("fingerprintHistoryIds"), fingerprintHistoryIds);
    }

    if (keepBackupForRollback) {
        result.insert(QStringLiteral("backupPath"), stagedDelete.stagedPath);
        ComicDeleteOps::rememberPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);
        return result;
    }

    QString cleanupDirPath;
    DeleteFailureInfo finalizeFailure;
    if (!performFinalizeStagedArchiveDelete(stagedDelete, cleanupDirPath, finalizeFailure)) {
        ComicDeleteOps::rememberPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);
        result.insert(
            QStringLiteral("cleanupWarning"),
            QStringLiteral("Old archive backup cleanup failed: %1").arg(formatDeleteFailureText(finalizeFailure))
        );
        return result;
    }

    ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);
    if (!cleanupDirPath.isEmpty()) {
        cleanupEmptyLibraryDirs(
            QDir(m_dataRoot).filePath(QStringLiteral("Library")),
            { cleanupDirPath }
        );
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

    QFile::remove(normalizedTargetPath);

    QString moveError;
    if (!moveFileWithFallback(normalizedBackupPath, normalizedTargetPath, moveError)) {
        return moveError;
    }

    ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, normalizedBackupPath);

    return relinkComicFileKeepMetadataInternal(comicId, normalizedTargetPath, filename, importSignalValues);
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
    const PersistedImportSignals importSignals = resolvedImportSignals(
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
    const QString envValuePrimary = qEnvironmentVariable("COMIC_PILE_DATA_DIR").trimmed();
    if (!envValuePrimary.isEmpty()) {
        return QDir(envValuePrimary).absolutePath();
    }
    // Backward compatibility for previous builds and docs.
    const QString envValueLegacy = qEnvironmentVariable("COMICFLOW_DATA_DIR").trimmed();
    if (!envValueLegacy.isEmpty()) {
        return QDir(envValueLegacy).absolutePath();
    }
    const QString configuredOverride = ComicDataRootSettings::configuredDataRootOverridePath();
    if (!configuredOverride.isEmpty()) {
        return QDir(configuredOverride).absolutePath();
    }
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    const QStringList candidates = {
        QDir(appDir).filePath("Database"),
        QDir(appDir).filePath("../Database"),
        QDir(appDir).filePath("../../Database"),
        QDir(appDir).filePath("../../../Database"),
        QDir(currentDir).filePath("Database"),
        QDir(currentDir).filePath("../Database"),
        QDir(currentDir).filePath("../../Database"),
    };

    for (const QString &candidate : candidates) {
        const QString found = absolutePathIfExists(candidate);
        if (!found.isEmpty()) return found;
    }

    return QDir(appDir).filePath("Database");
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
