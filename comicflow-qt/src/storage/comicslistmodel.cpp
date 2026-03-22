#include "storage/comicslistmodel.h"
#include "storage/archivepacking.h"
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
#include "storage/startupinventoryops.h"
#include "storage/startupruntimeutils.h"
#include "common/scopedsqlconnectionremoval.h"
#include "metadata/comicvineautofillservice.h"

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
#include <QEventLoop>
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
#include <QProcess>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSaveFile>
#include <QSettings>
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

QString seriesHeroPendingKey(const QString &seriesKey)
{
    const QByteArray digest = QCryptographicHash::hash(
        seriesKey.trimmed().toUtf8(),
        QCryptographicHash::Sha1
    ).toHex();
    return QStringLiteral("series-hero:%1").arg(QString::fromLatin1(digest));
}

int seriesHeroPageIndexForEntryCount(int entryCount)
{
    if (entryCount < 1) return -1;
    if (entryCount <= 4) {
        return std::clamp(entryCount / 2, 0, entryCount - 1);
    }

    const int startIndex = 2;
    const int endIndex = std::max(startIndex, entryCount - 3);
    return startIndex + ((endIndex - startIndex) / 2);
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

struct ReaderPageRequestState {
    QVariantMap sessionToCache;
    QString archivePath;
    QStringList entries;
    int resolvedPageIndex = 0;
    QString error;
};

ReaderPageRequestState buildReaderPageRequestState(
    int comicId,
    int requestedPageIndex,
    const QString &cachedArchivePath,
    const QStringList &cachedEntries,
    const QVariantMap &sessionFallback
)
{
    ReaderPageRequestState state;
    if (comicId < 1) {
        state.error = QStringLiteral("Invalid issue id.");
        return state;
    }

    state.archivePath = cachedArchivePath.trimmed();
    state.entries = cachedEntries;
    if (state.archivePath.isEmpty() || state.entries.isEmpty()) {
        const QString sessionError = valueFromMap(sessionFallback, QStringLiteral("error"));
        if (!sessionError.isEmpty()) {
            state.error = sessionError;
            return state;
        }

        state.archivePath = valueFromMap(sessionFallback, QStringLiteral("archivePath"));
        state.entries = sessionFallback.value(QStringLiteral("entries")).toStringList();
        if (!state.archivePath.isEmpty() && !state.entries.isEmpty()) {
            state.sessionToCache = sessionFallback;
        }
    }

    if (state.archivePath.isEmpty()) {
        state.error = QStringLiteral("Archive path is empty for issue id %1.").arg(comicId);
        return state;
    }
    if (state.entries.isEmpty()) {
        state.error = QStringLiteral("No image pages found in archive.");
        return state;
    }

    state.resolvedPageIndex = requestedPageIndex;
    if (state.resolvedPageIndex < 0 || state.resolvedPageIndex >= state.entries.size()) {
        state.resolvedPageIndex = 0;
    }

    return state;
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

QString dataRootOverrideSettingsKey()
{
    return QStringLiteral("AppSettings/libraryDataRootPath");
}

QSettings relocationSettingsStore()
{
    return QSettings(
        QSettings::IniFormat,
        QSettings::UserScope,
        QStringLiteral("ComicPile"),
        QStringLiteral("ComicPile")
    );
}

QString pendingDataRootRelocationSettingsKey()
{
    return QStringLiteral("AppSettings/libraryDataRelocationPendingPath");
}

QString normalizedFolderPath(const QString &rawPath)
{
    const QString normalized = normalizeInputFilePath(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }
    return QDir::cleanPath(QDir::fromNativeSeparators(normalized));
}

QString configuredDataRootOverridePath()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(dataRootOverrideSettingsKey()).toString());
}

QString pendingDataRootRelocationPathFromSettings()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(pendingDataRootRelocationSettingsKey()).toString());
}

QString persistedFolderPathForDisplay(const QString &rawPath)
{
    const QString normalized = normalizedFolderPath(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }
    return QDir::toNativeSeparators(normalized);
}

bool writePendingDataRootRelocationPath(const QString &rawPath, QString &errorText)
{
    QSettings settings = relocationSettingsStore();
    settings.setValue(
        pendingDataRootRelocationSettingsKey(),
        persistedFolderPathForDisplay(rawPath)
    );
    settings.sync();
    if (settings.status() != QSettings::NoError) {
        if (settings.status() == QSettings::AccessError) {
            errorText = QStringLiteral(
                "Could not schedule the new library data location because the app could not write its transfer request to settings storage."
            );
        } else {
            errorText = QStringLiteral(
                "Could not schedule the new library data location because the app could not update its settings storage."
            );
        }
        return false;
    }
    return true;
}

bool hasExternalDataRootOverride()
{
    return !qEnvironmentVariable("COMIC_PILE_DATA_DIR").trimmed().isEmpty()
        || !qEnvironmentVariable("COMICFLOW_DATA_DIR").trimmed().isEmpty();
}

bool isSameOrNestedFolderPath(const QString &leftPath, const QString &rightPath)
{
    const QString left = normalizedFolderPath(leftPath);
    const QString right = normalizedFolderPath(rightPath);
    if (left.isEmpty() || right.isEmpty()) {
        return false;
    }
    if (left.compare(right, Qt::CaseInsensitive) == 0) {
        return true;
    }
    return right.startsWith(left + QLatin1Char('/'), Qt::CaseInsensitive)
        || left.startsWith(right + QLatin1Char('/'), Qt::CaseInsensitive);
}

QString validateScheduledDataRootRelocationTarget(
    const QString &currentDataRoot,
    const QString &targetPath
)
{
    if (hasExternalDataRootOverride()) {
        return QStringLiteral("Library data location is currently forced by an external launch override. Remove that override before changing it here.");
    }

    const QString normalizedCurrent = normalizedFolderPath(currentDataRoot);
    const QString normalizedTarget = normalizedFolderPath(targetPath);
    if (normalizedTarget.isEmpty()) {
        return QStringLiteral("Choose a new folder for library data.");
    }
    if (normalizedCurrent.isEmpty()) {
        return QStringLiteral("Current library data location is unavailable.");
    }
    if (normalizedCurrent.compare(normalizedTarget, Qt::CaseInsensitive) == 0) {
        return QStringLiteral("Choose a different folder for library data.");
    }
    if (isSameOrNestedFolderPath(normalizedCurrent, normalizedTarget)) {
        return QStringLiteral("Choose a folder outside the current library data location.");
    }

    const QFileInfo targetInfo(QDir::toNativeSeparators(normalizedTarget));
    if (targetInfo.exists() && !targetInfo.isDir()) {
        return QStringLiteral("The selected library data location is not a folder.");
    }

    if (targetInfo.exists()) {
        const QDir targetDir(targetInfo.absoluteFilePath());
        if (!targetDir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).isEmpty()) {
            return QStringLiteral("Choose an empty folder for the new library data location.");
        }
    }

    const QFileInfo currentInfo(QDir::toNativeSeparators(normalizedCurrent));
    if (!currentInfo.exists() || !currentInfo.isDir()) {
        return QStringLiteral("Current library data location is unavailable.");
    }

    return {};
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
    const QString &libraryPath,
    const QString &storedFilePath,
    const QString &storedFilename
)
{
    QString candidatePath = normalizeInputFilePath(storedFilePath);
    if (candidatePath.isEmpty()) {
        const QString filenameInput = storedFilename.trimmed();
        if (filenameInput.isEmpty()) return {};

        const QDir libraryDir(libraryPath);
        const QString normalizedFilename = QDir::fromNativeSeparators(filenameInput);
        const QFileInfo filenameInfo(normalizedFilename);

        if (filenameInfo.isAbsolute()) {
            candidatePath = filenameInfo.absoluteFilePath();
        } else {
            candidatePath = libraryDir.absoluteFilePath(normalizedFilename);
        }
    }

    const QFileInfo candidateInfo(candidatePath);
    if (!candidateInfo.exists() || !candidateInfo.isFile()) {
        return {};
    }

    return QDir::toNativeSeparators(candidateInfo.absoluteFilePath());
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

int extractPositiveIssueNumber(const QString &issueNumber)
{
    return ComicImportMatching::extractPositiveIssueNumber(issueNumber);
}

int extractPositiveNumberFromFilename(const QString &filename)
{
    return ComicImportMatching::extractPositiveNumberFromFilename(filename);
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
    return ComicImportMatching::buildImportIdentityPassport(
        QStringLiteral("archive"),
        normalizedSourcePath,
        sourceInfo.fileName(),
        parentFolderNameForFile(sourceInfo),
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
    const QString trimmedPath = storedPath.trimmed();
    if (trimmedPath.isEmpty()) return {};

    const QFileInfo rawInfo(trimmedPath);
    QString absolutePath;
    if (rawInfo.isAbsolute()) {
        absolutePath = rawInfo.absoluteFilePath();
    } else {
        absolutePath = QDir(dataRoot).filePath(QDir::fromNativeSeparators(trimmedPath));
    }

    const QFileInfo absoluteInfo(absolutePath);
    if (!absoluteInfo.exists() || !absoluteInfo.isFile()) {
        return {};
    }
    return QDir::toNativeSeparators(absoluteInfo.absoluteFilePath());
}

QString relativePathWithinDataRoot(const QString &dataRoot, const QString &absolutePath)
{
    const QFileInfo dataRootInfo(dataRoot);
    const QFileInfo absoluteInfo(absolutePath);
    const QString normalizedDataRoot = QDir::cleanPath(dataRootInfo.absoluteFilePath());
    const QString normalizedAbsolute = QDir::cleanPath(absoluteInfo.absoluteFilePath());
    if (!normalizedAbsolute.startsWith(normalizedDataRoot, Qt::CaseInsensitive)) {
        return QDir::toNativeSeparators(normalizedAbsolute);
    }
    return QDir::toNativeSeparators(QDir(normalizedDataRoot).relativeFilePath(normalizedAbsolute));
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

bool runExternalProcess(
    const QString &program,
    const QStringList &arguments,
    QByteArray &stdOut,
    QByteArray &stdErr,
    QString &errorText,
    int timeoutMs = 120000
)
{
    stdOut.clear();
    stdErr.clear();
    errorText.clear();

    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.start();

    if (!process.waitForStarted(15000)) {
        errorText = QString("Failed to start process: %1").arg(program);
        return false;
    }

    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(5000);
        errorText = QString("Process timed out: %1").arg(program);
        return false;
    }

    stdOut = process.readAllStandardOutput();
    stdErr = process.readAllStandardError();

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        errorText = QString("Process failed (%1), exit code %2.").arg(program).arg(process.exitCode());
        const QString trimmedErr = QString::fromUtf8(stdErr).trimmed();
        if (!trimmedErr.isEmpty()) {
            errorText += QString(" %1").arg(trimmedErr);
        }
        return false;
    }

    return true;
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
    if (!runExternalProcess(executable, { QStringLiteral("i") }, stdOutBytes, stdErrBytes, errorText, 15000)) {
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

QVariantMap makeAsyncImageResult(
    const QString &imageSource = QString(),
    const QString &error = QString()
)
{
    QVariantMap result;
    result.insert("imageSource", imageSource);
    result.insert("error", error);
    return result;
}

QVariantMap makeAsyncSeriesHeroResult(
    const QString &seriesKey = QString(),
    const QString &imageSource = QString(),
    const QString &localFilePath = QString(),
    const QString &error = QString()
)
{
    QVariantMap result;
    result.insert(QStringLiteral("seriesKey"), seriesKey);
    result.insert(QStringLiteral("imageSource"), imageSource);
    result.insert(QStringLiteral("localFilePath"), localFilePath);
    result.insert(QStringLiteral("error"), error);
    return result;
}

} // namespace

ComicsListModel::ComicsListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_dataRoot = resolveDataRoot();
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_ctor_begin"));
    m_dbPath = QDir(m_dataRoot).filePath("library.db");
    appendLaunchTimelineEventForDataRoot(m_dataRoot, QStringLiteral("library_model_paths_ready"));
    m_comicVineAutofillService = new ComicVineAutofillService(m_dataRoot, this);
    connect(
        m_comicVineAutofillService,
        &ComicVineAutofillService::autofillFinished,
        this,
        &ComicsListModel::comicVineAutofillFinished
    );
    connect(
        m_comicVineAutofillService,
        &ComicVineAutofillService::apiKeyValidationFinished,
        this,
        &ComicsListModel::comicVineApiKeyValidationFinished
    );
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
    m_pendingImageRequestIdsByKey.clear();
    m_pendingSeriesHeroRequestIdsByKey.clear();
    m_coverGenerationQueue.clear();
    m_seriesHeroGenerationQueue.clear();
    m_activeCoverGenerationCount = 0;
    m_activeSeriesHeroGenerationCount = 0;

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

            const QString resolvedPath = fastResolveStoredFilePath(libraryPath, row.filePath, row.filename);
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
        endResetModel();
        emit statusChanged();
    });
    watcher->setFuture(QtConcurrent::run([validationGeneration, validationRows]() {
        return validateReloadRowsAsync(validationGeneration, validationRows);
    }));
}

QVariantMap ComicsListModel::checkDatabaseHealth() const
{
    return ComicStartupInventoryOps::checkDatabaseHealth(m_dbPath);
}

int ComicsListModel::requestDatabaseHealthCheckAsync()
{
    return ComicStartupInventoryOps::requestDatabaseHealthCheckAsync(
        this,
        m_dbPath,
        [this](int requestId, const QVariantMap &result) {
            emit databaseHealthChecked(requestId, result);
        }
    );
}

bool ComicsListModel::isLibraryStorageMigrationPending() const
{
    return ComicStartupInventoryOps::isLibraryStorageMigrationPending(m_dataRoot);
}

int ComicsListModel::requestLibraryStorageMigrationAsync()
{
    return ComicStartupInventoryOps::requestLibraryStorageMigrationAsync(
        this,
        m_dataRoot,
        m_dbPath,
        [this](int requestId, const QVariantMap &result) {
            emit libraryStorageMigrationFinished(requestId, result);
        }
    );
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
            const QString preflightPath = row.filePath.trimmed();
            if (preflightPath.isEmpty()) continue;
            if (!filePathExists(preflightPath)) {
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
                const QString sourcePath = normalizeInputFilePath(row.filePath);
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
                moveQuery.bindValue(0, it.value());
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
                if (normalizedPathForCompare(expectedFilePath) != normalizedPathForCompare(actual.filePath)) {
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
            } else if (!actual.filePath.trimmed().isEmpty() && !filePathExists(actual.filePath)) {
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
        candidateIssueValue = guessIssueNumberFromFilename(resolvedFilename);
    }
    const QString candidateIssueKey = normalizeIssueKey(candidateIssueValue);
    const QString strictInputSignature = normalizeFilenameSignatureStrict(resolvedFilename);
    const QString looseInputSignature = normalizeFilenameSignatureLoose(resolvedFilename);
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

            if (isWeakSeriesName(candidate.series)) {
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

        // Priority 2: exact known file fingerprint among missing/stale rows.
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

        // Priority 3: filename among missing/stale rows (case-insensitive), with optional metadata disambiguation.
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

        // Priority 4: series + issue (+ volume when provided) among missing/stale rows.
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
                if (allowImportAsNew) {
                    // User explicitly chose to keep this as a separate issue instead of restoring the stale row.
                } else {
                    return failWeakMetadataRestore(metadataResolution.candidates);
                }
            }
            if (metadataResolution.candidates.size() > 1) {
                if (allowImportAsNew) {
                    // Explicit "import as new" should bypass ambiguous stale restore candidates.
                } else {
                    return failAmbiguousRestore(metadataResolution.candidates);
                }
            }
        }

        // Priority 5: strict filename signature among missing/stale rows (auto only when unique).
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
                if (normalizeFilenameSignatureStrict(candidate.filename) != strictInputSignature) continue;
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
    const QString inferredFolderSeriesName = guessSeriesFromFilename(effectiveSeries);
    if (!isWeakSeriesName(inferredFolderSeriesName)
        && normalizeSeriesKey(inferredFolderSeriesName) == effectiveSeriesKey) {
        folderSeriesName = inferredFolderSeriesName;
    }
    SeriesFolderState folderState;
    for (const ComicRow &row : m_rows) {
        if (row.filePath.trimmed().isEmpty()) continue;
        const QString relativeDir = relativeDirUnderRoot(libraryPath, row.filePath);
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
        const QString candidateSeriesKey = normalizeSeriesKeyValue(candidateSeries);
        const QString candidateVolume = valueFromMap(createValues, QStringLiteral("volume"));
        const QString candidateVolumeKey = normalizeVolumeKeyValue(candidateVolume);
        QString candidateIssue = valueFromMap(createValues, QStringLiteral("issueNumber"), QStringLiteral("issue"));
        if (candidateIssue.isEmpty()) {
            candidateIssue = guessIssueNumberFromFilename(sourceInfo.fileName());
        }
        const QString candidateIssueKey = normalizeIssueKey(candidateIssue);
        const QString strictTargetSignature = normalizeFilenameSignatureStrict(targetFilename);
        const QString looseTargetSignature = normalizeFilenameSignatureLoose(targetFilename);
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
            finalFilename = makeUniqueFilename(seriesDir, targetFilename);
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
            cleanupEmptyLibraryDirs(libraryPath, { QFileInfo(finalFilePath).absolutePath() });
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

        const QVariantMap currentMetadata = loadComicMetadata(importedComicId);
        if (!currentMetadata.contains(QStringLiteral("error"))) {
            // Import path uses local metadata cache only (no network call).
            const QVariantMap localCacheFill = m_comicVineAutofillService->requestAutofillFromCache(currentMetadata);
            const QVariantMap autofillPatch = localCacheFill.value(QStringLiteral("values")).toMap();
            if (!autofillPatch.isEmpty()) {
                const QString updateError = updateComicMetadata(importedComicId, autofillPatch);
                if (outResult) {
                    outResult->insert(QStringLiteral("comicVineAutofillAttempted"), true);
                    outResult->insert(QStringLiteral("comicVineAutofillFromCache"), localCacheFill.value(QStringLiteral("fromCache")).toBool());
                    outResult->insert(QStringLiteral("comicVineAutofillApplied"), updateError.trimmed().isEmpty());
                    if (!updateError.trimmed().isEmpty()) {
                        outResult->insert(QStringLiteral("comicVineAutofillError"), updateError);
                    }
                }
            }
        }
    }

    return {};
}

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
    QString sourceCanonicalPath;

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
        sourceCanonicalPath = sourceInfo.canonicalFilePath();
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
    const QString inferredFolderSeriesName = guessSeriesFromFilename(effectiveSeries);
    if (!isWeakSeriesName(inferredFolderSeriesName)
        && normalizeSeriesKey(inferredFolderSeriesName) == effectiveSeriesKey) {
        folderSeriesName = inferredFolderSeriesName;
    }

    SeriesFolderState folderState;
    for (const ComicRow &row : m_rows) {
        if (row.filePath.trimmed().isEmpty()) continue;
        const QString relativeDir = relativeDirUnderRoot(libraryPath, row.filePath);
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
    Q_UNUSED(sourceCanonicalPath);

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

QString ComicsListModel::pendingDataRootRelocationPath() const
{
    return persistedFolderPathForDisplay(pendingDataRootRelocationPathFromSettings());
}

QVariantMap ComicsListModel::scheduleDataRootRelocation(const QString &targetPath)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("error"), QString());
    result.insert(QStringLiteral("pendingPath"), QString());
    result.insert(QStringLiteral("restartRequired"), false);

    const QString validationError = validateScheduledDataRootRelocationTarget(m_dataRoot, targetPath);
    if (!validationError.isEmpty()) {
        result.insert(QStringLiteral("error"), validationError);
        return result;
    }

    QString persistError;
    if (!writePendingDataRootRelocationPath(targetPath, persistError)) {
        result.insert(QStringLiteral("error"), persistError);
        return result;
    }

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pendingPath"), persistedFolderPathForDisplay(targetPath));
    result.insert(QStringLiteral("restartRequired"), true);
    return result;
}

QString ComicsListModel::readStartupSnapshot() const
{
    return ComicStartupRuntime::readStartupSnapshot(m_dataRoot);
}

bool ComicsListModel::writeStartupSnapshot(const QString &payload) const
{
    return ComicStartupRuntime::writeStartupSnapshot(m_dataRoot, payload);
}

QVariantMap ComicsListModel::currentStartupInventorySignature() const
{
    return ComicStartupInventoryOps::currentStartupInventorySignature(m_dataRoot, m_dbPath);
}

int ComicsListModel::requestStartupInventorySignatureAsync()
{
    return ComicStartupInventoryOps::requestStartupInventorySignatureAsync(
        this,
        m_dataRoot,
        m_dbPath,
        [this](int requestId, const QVariantMap &result) {
            emit startupInventorySignatureReady(requestId, result);
        }
    );
}

QString ComicsListModel::startupLogPath() const
{
    return ComicStartupRuntime::startupLogPath(m_dataRoot);
}

QString ComicsListModel::startupDebugLogPath() const
{
    return ComicStartupRuntime::startupDebugLogPath(m_dataRoot);
}

QString ComicsListModel::startupPreviewPath() const
{
    return ComicStartupRuntime::startupPreviewPath(m_dataRoot);
}

QString ComicsListModel::startupPreviewMetaPath() const
{
    return ComicStartupRuntime::startupPreviewMetaPath(m_dataRoot);
}

bool ComicsListModel::writeStartupPreviewMeta(const QString &payload) const
{
    return ComicStartupRuntime::writeStartupPreviewMeta(m_dataRoot, payload);
}

QString ComicsListModel::readStartupPreviewMeta() const
{
    return ComicStartupRuntime::readStartupPreviewMeta(m_dataRoot);
}

void ComicsListModel::resetStartupLog() const
{
    ComicStartupRuntime::resetTextLogFile(startupLogPath());
}

void ComicsListModel::appendStartupLog(const QString &line) const
{
    ComicStartupRuntime::appendNormalizedTextLogLine(startupLogPath(), line);
}

void ComicsListModel::resetStartupDebugLog() const
{
    ComicStartupRuntime::resetTextLogFile(startupDebugLogPath());
}

void ComicsListModel::appendStartupDebugLog(const QString &line) const
{
    ComicStartupRuntime::appendNormalizedTextLogLine(startupDebugLogPath(), line);
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

int ComicsListModel::heroCoverComicIdForSeries(const QString &seriesKey) const
{
    const QString requestedSeriesKey = seriesKey.trimmed();
    if (requestedSeriesKey.isEmpty()) return -1;

    int bestIssueId = -1;
    int bestIssueNumber = std::numeric_limits<int>::max();
    int bestFilenameId = -1;
    int bestFilenameNumber = std::numeric_limits<int>::max();
    int fallbackId = -1;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;

        if (fallbackId < 0 || row.id < fallbackId) {
            fallbackId = row.id;
        }

        const int parsedIssue = extractPositiveIssueNumber(row.issueNumber);
        if (parsedIssue > 0) {
            if (parsedIssue < bestIssueNumber || (parsedIssue == bestIssueNumber && (bestIssueId < 0 || row.id < bestIssueId))) {
                bestIssueNumber = parsedIssue;
                bestIssueId = row.id;
            }
            continue;
        }

        const int parsedFromFilename = extractPositiveNumberFromFilename(row.filename);
        if (parsedFromFilename > 0) {
            if (parsedFromFilename < bestFilenameNumber
                || (parsedFromFilename == bestFilenameNumber && (bestFilenameId < 0 || row.id < bestFilenameId))) {
                bestFilenameNumber = parsedFromFilename;
                bestFilenameId = row.id;
            }
        }
    }

    if (bestIssueId > 0) return bestIssueId;
    if (bestFilenameId > 0) return bestFilenameId;
    return fallbackId;
}

int ComicsListModel::requestSeriesHeroAsync(const QString &seriesKey)
{
    const int requestId = m_nextAsyncRequestId++;
    const QString requestedSeriesKey = seriesKey.trimmed();
    auto emitLaterSingle = [this, requestId, requestedSeriesKey](const QString &imageSource, const QString &errorText) {
        emitSeriesHeroReadyForRequestIds({ requestId }, requestedSeriesKey, imageSource, errorText);
    };

    if (requestedSeriesKey.isEmpty()) {
        emitLaterSingle({}, {});
        return requestId;
    }

    const QString cachedHeroPath = ComicReaderCache::cachedSeriesHeroPath(m_dataRoot, requestedSeriesKey);
    if (!cachedHeroPath.isEmpty()) {
        ComicReaderCache::pruneSeriesHeroVariantsForKey(m_dataRoot, requestedSeriesKey, cachedHeroPath);
        emitLaterSingle(QUrl::fromLocalFile(cachedHeroPath).toString(), {});
        return requestId;
    }

    const int comicId = heroCoverComicIdForSeries(requestedSeriesKey);
    if (comicId < 1) {
        emitLaterSingle({}, {});
        return requestId;
    }

    const QString archivePath = archivePathForComicId(comicId);
    if (archivePath.trimmed().isEmpty()) {
        emitLaterSingle({}, {});
        return requestId;
    }

    const QString pendingKey = seriesHeroPendingKey(requestedSeriesKey);
    if (!ComicReaderRequests::beginPendingImageRequest(m_pendingSeriesHeroRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    const QueuedSeriesHeroGeneration job {
        pendingKey,
        requestedSeriesKey,
        comicId,
        archivePath,
        ComicReaderCache::buildArchiveCacheStamp(archivePath),
        ComicReaderCache::preferredThumbnailFormat()
    };

    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;
    if (m_activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount) {
        startQueuedSeriesHeroGeneration(job);
    } else {
        m_seriesHeroGenerationQueue.push_back(job);
    }

    return requestId;
}

int ComicsListModel::requestRandomSeriesHeroAsync(const QString &seriesKey)
{
    const int requestId = m_nextAsyncRequestId++;
    const QString requestedSeriesKey = seriesKey.trimmed();
    const QString requestKey = QStringLiteral("__series_header_shuffle_preview__");
    auto emitLaterSingle = [this, requestId, requestKey](const QString &imageSource, const QString &errorText) {
        emitSeriesHeroReadyForRequestIds({ requestId }, requestKey, imageSource, errorText);
    };

    if (requestedSeriesKey.isEmpty()) {
        emitLaterSingle({}, {});
        return requestId;
    }

    QVector<int> candidateComicIds;
    QStringList candidateArchivePaths;
    candidateComicIds.reserve(m_rows.size());
    candidateArchivePaths.reserve(m_rows.size());

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != requestedSeriesKey) continue;

        const QString archivePath = archivePathForComicId(row.id);
        if (archivePath.trimmed().isEmpty()) continue;

        candidateComicIds.push_back(row.id);
        candidateArchivePaths.push_back(archivePath);
    }

    if (candidateComicIds.isEmpty()) {
        emitLaterSingle({}, QStringLiteral("No issues are available for shuffled background."));
        return requestId;
    }

    ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, requestKey);

    const QString pendingKey = seriesHeroPendingKey(requestKey);
    if (!ComicReaderRequests::beginPendingImageRequest(m_pendingSeriesHeroRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    const QueuedSeriesHeroGeneration job {
        pendingKey,
        requestKey,
        0,
        QString(),
        QString(),
        ComicReaderCache::preferredThumbnailFormat(),
        true,
        candidateComicIds,
        candidateArchivePaths
    };

    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;
    if (m_activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount) {
        startQueuedSeriesHeroGeneration(job);
    } else {
        m_seriesHeroGenerationQueue.push_back(job);
    }

    return requestId;
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

QVariantMap ComicsListModel::loadReaderSessionPayload(
    const QString &dbPath,
    const QString &dataRoot,
    int comicId
)
{
    const ComicReaderSessionOps::ReaderIssueRecord record =
        ComicReaderSessionOps::loadReaderIssueRecord(dbPath, comicId);
    if (!record.error.isEmpty()) {
        return {
            { QStringLiteral("error"), record.error }
        };
    }

    QString archivePath = record.filePath;
    if (archivePath.isEmpty() && !record.filename.isEmpty()) {
        const QString fallbackPath = resolveLibraryFilePath(
            QDir(dataRoot).filePath(QStringLiteral("Library")),
            record.filename
        );
        if (!fallbackPath.isEmpty() && QFileInfo::exists(fallbackPath)) {
            archivePath = fallbackPath;
        }
    }

    if (archivePath.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("Archive path is empty for issue id %1.").arg(comicId) }
        };
    }

    QStringList entries;
    QString listError;
    if (!listImageEntriesInArchive(archivePath, entries, listError)) {
        return {
            { QStringLiteral("error"), listError }
        };
    }
    if (entries.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("No image pages found in archive.") }
        };
    }

    const QString displayTitle = !record.series.isEmpty()
        ? record.series
        : (!record.title.isEmpty() ? record.title : record.filename);
    const int pageCount = entries.size();
    const int effectiveBookmarkPage = (record.bookmarkPage > 0 && record.bookmarkPage <= pageCount)
        ? record.bookmarkPage
        : 0;
    int startPageIndex = 0;
    if (effectiveBookmarkPage > 0) {
        startPageIndex = effectiveBookmarkPage - 1;
    } else if (record.currentPage > 0) {
        startPageIndex = std::clamp(record.currentPage - 1, 0, pageCount - 1);
    }

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("seriesKey"), record.seriesKey },
        { QStringLiteral("title"), displayTitle },
        { QStringLiteral("archivePath"), archivePath },
        { QStringLiteral("pageCount"), pageCount },
        { QStringLiteral("currentPage"), record.currentPage },
        { QStringLiteral("bookmarkPage"), record.bookmarkPage },
        { QStringLiteral("favoriteActive"), record.favoriteActive },
        { QStringLiteral("startPageIndex"), startPageIndex },
        { QStringLiteral("entries"), entries }
    };
}

QVariantMap ComicsListModel::loadReaderPageMetricsPayload(
    const QString &dataRoot,
    int comicId,
    const QString &archivePath,
    const QStringList &entries
)
{
    return ComicImagePreparation::loadReaderPageMetricsPayload(
        dataRoot,
        comicId,
        archivePath,
        entries,
        [](const QString &sourceArchivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
            return ComicsListModel::extractArchiveEntryToFile(sourceArchivePath, entryName, outputFilePath, errorText);
        }
    );
}

void ComicsListModel::cacheReaderSession(const QVariantMap &session)
{
    const QString error = session.value(QStringLiteral("error")).toString().trimmed();
    if (!error.isEmpty()) {
        return;
    }

    const int comicId = session.value(QStringLiteral("comicId")).toInt();
    const QString archivePath = session.value(QStringLiteral("archivePath")).toString().trimmed();
    const QStringList entries = session.value(QStringLiteral("entries")).toStringList();
    if (comicId < 1 || archivePath.isEmpty() || entries.isEmpty()) {
        return;
    }

    m_readerArchivePathById.insert(comicId, archivePath);
    m_readerImageEntriesById.insert(comicId, entries);
}

void ComicsListModel::cacheReaderPageMetrics(int comicId, const QVariantList &pageMetrics)
{
    if (comicId < 1 || pageMetrics.isEmpty()) {
        return;
    }
    m_readerPageMetricsById.insert(comicId, pageMetrics);
}

QVariantMap ComicsListModel::cachedReaderSessionPayload(int comicId) const
{
    if (comicId < 1) {
        return {};
    }

    const QString archivePath = m_readerArchivePathById.value(comicId).trimmed();
    const QStringList entries = m_readerImageEntriesById.value(comicId);
    if (archivePath.isEmpty() || entries.isEmpty()) {
        return {};
    }

    QString displayTitle = QString("Issue #%1").arg(comicId);
    QString seriesKey;
    int currentPage = 0;
    int bookmarkPage = 0;
    bool favoriteActive = false;
    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) continue;
        seriesKey = row.seriesGroupKey.trimmed();
        displayTitle = !row.series.isEmpty() ? row.series : (!row.title.isEmpty() ? row.title : row.filename);
        currentPage = row.currentPage;
        bookmarkPage = row.bookmarkPage;
        favoriteActive = row.favoriteActive;
        break;
    }

    return ComicReaderPayloads::buildCachedReaderSessionPayload(
        comicId,
        archivePath,
        entries,
        seriesKey,
        displayTitle,
        currentPage,
        bookmarkPage,
        favoriteActive
    );
}

QVariantList ComicsListModel::cachedReaderPageMetrics(int comicId) const
{
    if (comicId < 1) {
        return {};
    }
    return m_readerPageMetricsById.value(comicId);
}

void ComicsListModel::emitReaderSessionReadyForRequestIds(
    const QList<int> &requestIds,
    const QVariantMap &result
)
{
    if (requestIds.isEmpty()) return;

    QMetaObject::invokeMethod(
        this,
        [this, requestIds, result]() {
            for (int requestId : requestIds) {
                emit readerSessionReady(requestId, result);
            }
        },
        Qt::QueuedConnection
    );
}

QVariantMap ComicsListModel::openReaderSession(int comicId)
{
    const QVariantMap session = loadReaderSessionPayload(m_dbPath, m_dataRoot, comicId);
    cacheReaderSession(session);
    return session;
}

int ComicsListModel::requestReaderPageMetricsAsync(int comicId)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId, comicId](const QVariantMap &result) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId, comicId, result]() {
                emit readerPageMetricsReady(requestId, comicId, result);
            },
            Qt::QueuedConnection
        );
    };

    if (comicId < 1) {
        emitLaterSingle({
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        });
        return requestId;
    }

    const QVariantList cachedMetrics = cachedReaderPageMetrics(comicId);
    if (!cachedMetrics.isEmpty()) {
        emitLaterSingle({
            { QStringLiteral("comicId"), comicId },
            { QStringLiteral("pageMetrics"), cachedMetrics }
        });
        return requestId;
    }

    m_pendingReaderPageMetricsRequestIdsByComicId[comicId].push_back(requestId);
    if (m_pendingReaderPageMetricsRequestIdsByComicId.value(comicId).size() > 1) {
        return requestId;
    }

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, comicId]() {
        const QVariantMap result = watcher->result();
        const QVariantList pageMetrics = result.value(QStringLiteral("pageMetrics")).toList();
        if (!pageMetrics.isEmpty()) {
            cacheReaderPageMetrics(comicId, pageMetrics);
        }
        const QVariantMap rebuiltSession = result.value(QStringLiteral("session")).toMap();
        if (!rebuiltSession.isEmpty()) {
            cacheReaderSession(rebuiltSession);
        }

        const QList<int> requestIds = m_pendingReaderPageMetricsRequestIdsByComicId.take(comicId);
        for (int requestId : requestIds) {
            emit readerPageMetricsReady(requestId, comicId, result);
        }
        watcher->deleteLater();
    });

    watcher->setFuture(QtConcurrent::run([dbPath = m_dbPath, dataRoot = m_dataRoot, comicId]() {
        QString archivePath = QString();
        QStringList entries;
        QVariantMap rebuiltSession;

        const QVariantMap session = ComicsListModel::loadReaderSessionPayload(dbPath, dataRoot, comicId);
        const QString sessionError = session.value(QStringLiteral("error")).toString().trimmed();
        if (!sessionError.isEmpty()) {
            return QVariantMap {
                { QStringLiteral("error"), sessionError }
            };
        }

        rebuiltSession = session;
        archivePath = session.value(QStringLiteral("archivePath")).toString().trimmed();
        entries = session.value(QStringLiteral("entries")).toStringList();

        QVariantMap result = ComicsListModel::loadReaderPageMetricsPayload(
            dataRoot,
            comicId,
            archivePath,
            entries
        );
        if (!rebuiltSession.isEmpty()) {
            result.insert(QStringLiteral("session"), rebuiltSession);
        }
        return result;
    }));

    return requestId;
}

int ComicsListModel::requestReaderSessionAsync(int comicId)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId](const QVariantMap &result) {
        emitReaderSessionReadyForRequestIds({ requestId }, result);
    };

    if (comicId < 1) {
        emitLaterSingle({
            { QString("error"), QString("Invalid issue id.") }
        });
        return requestId;
    }

    const QVariantMap cached = cachedReaderSessionPayload(comicId);
    if (!cached.isEmpty()) {
        emitLaterSingle(cached);
        return requestId;
    }

    m_pendingReaderSessionRequestIdsByComicId[comicId].push_back(requestId);
    if (m_pendingReaderSessionRequestIdsByComicId.value(comicId).size() > 1) {
        return requestId;
    }

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, comicId]() {
        const QVariantMap session = watcher->result();
        cacheReaderSession(session);
        const QList<int> requestIds = m_pendingReaderSessionRequestIdsByComicId.take(comicId);
        emitReaderSessionReadyForRequestIds(requestIds, session);
        watcher->deleteLater();
    });

    watcher->setFuture(QtConcurrent::run([dbPath = m_dbPath, dataRoot = m_dataRoot, comicId]() {
        return ComicsListModel::loadReaderSessionPayload(dbPath, dataRoot, comicId);
    }));
    return requestId;
}

QVariantMap ComicsListModel::loadReaderPage(int comicId, int pageIndex)
{
    const QString cachedArchivePath = m_readerArchivePathById.value(comicId);
    const QStringList cachedEntries = m_readerImageEntriesById.value(comicId);
    QVariantMap rebuiltSession;
    if (cachedArchivePath.trimmed().isEmpty() || cachedEntries.isEmpty()) {
        rebuiltSession = loadReaderSessionPayload(m_dbPath, m_dataRoot, comicId);
    }

    const ReaderPageRequestState state = buildReaderPageRequestState(
        comicId,
        pageIndex,
        cachedArchivePath,
        cachedEntries,
        rebuiltSession
    );
    if (!state.sessionToCache.isEmpty()) {
        cacheReaderSession(state.sessionToCache);
    }
    if (!state.error.isEmpty()) {
        return {
            { QStringLiteral("error"), state.error }
        };
    }

    return ComicReaderPayloads::loadReaderPagePayload(
        m_dataRoot,
        comicId,
        state.archivePath,
        state.entries,
        state.resolvedPageIndex,
        [](const QString &archivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
            return ComicsListModel::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
        }
    );
}

int ComicsListModel::requestReaderPageAsync(int comicId, int pageIndex)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId, comicId](int resolvedPageIndex, const QString &imageSource, const QString &errorText) {
        emitPageReadyForRequestIds({ requestId }, comicId, resolvedPageIndex, imageSource, errorText, false);
    };

    if (comicId < 1) {
        emitLaterSingle(pageIndex, QString(), QStringLiteral("Invalid issue id."));
        return requestId;
    }

    const QString cachedArchivePath = m_readerArchivePathById.value(comicId);
    const QStringList cachedEntries = m_readerImageEntriesById.value(comicId);
    const bool needsSessionRebuild = cachedArchivePath.trimmed().isEmpty() || cachedEntries.isEmpty();
    if (needsSessionRebuild) {
        auto *watcher = new QFutureWatcher<QVariantMap>(this);
        connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, requestId, comicId, pageIndex]() {
            const QVariantMap result = watcher->result();
            const QVariantMap rebuiltSession = result.value(QStringLiteral("session")).toMap();
            if (!rebuiltSession.isEmpty()) {
                cacheReaderSession(rebuiltSession);
            }

            const int resolvedPageIndex = result.contains(QStringLiteral("pageIndex"))
                ? result.value(QStringLiteral("pageIndex")).toInt()
                : pageIndex;
            emitPageReadyForRequestIds(
                { requestId },
                comicId,
                resolvedPageIndex,
                result.value(QStringLiteral("imageSource")).toString(),
                result.value(QStringLiteral("error")).toString(),
                false
            );
            watcher->deleteLater();
        });

        const auto task = [dbPath = m_dbPath, dataRoot = m_dataRoot, comicId, pageIndex]() {
            const QVariantMap rebuiltSession = ComicsListModel::loadReaderSessionPayload(dbPath, dataRoot, comicId);
            const ReaderPageRequestState state = buildReaderPageRequestState(
                comicId,
                pageIndex,
                QString(),
                QStringList(),
                rebuiltSession
            );
            if (!state.error.isEmpty()) {
                return QVariantMap {
                    { QStringLiteral("error"), state.error },
                    { QStringLiteral("pageIndex"), state.resolvedPageIndex }
                };
            }

            QVariantMap result = ComicReaderPayloads::loadReaderPagePayload(
                dataRoot,
                comicId,
                state.archivePath,
                state.entries,
                state.resolvedPageIndex,
                [](const QString &archivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
                    return ComicsListModel::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
                }
            );
            if (!state.sessionToCache.isEmpty()) {
                result.insert(QStringLiteral("session"), state.sessionToCache);
            }
            return result;
        };

        watcher->setFuture(QtConcurrent::run(task));
        return requestId;
    }

    const ReaderPageRequestState state = buildReaderPageRequestState(
        comicId,
        pageIndex,
        cachedArchivePath,
        cachedEntries,
        QVariantMap()
    );
    if (!state.error.isEmpty()) {
        emitLaterSingle(state.resolvedPageIndex, QString(), state.error);
        return requestId;
    }

    const QString entryName = state.entries.at(state.resolvedPageIndex);
    QString extension = QFileInfo(entryName).suffix().toLower();
    if (extension.isEmpty()) extension = QString("img");
    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(state.archivePath);
    const QString cacheFilePath = ComicReaderCache::buildReaderCachePath(
        m_dataRoot,
        comicId,
        cacheStamp,
        state.resolvedPageIndex,
        extension
    );

    const QFileInfo cacheInfo(cacheFilePath);
    if (cacheInfo.exists() && cacheInfo.size() > 0) {
        emitLaterSingle(state.resolvedPageIndex, QUrl::fromLocalFile(cacheFilePath).toString(), QString());
        return requestId;
    }
    if (cacheInfo.exists() && cacheInfo.size() <= 0) {
        QFile::remove(cacheFilePath);
    }

    const QString pendingKey = ComicReaderRequests::pagePendingKey(comicId, cacheStamp, state.resolvedPageIndex);
    if (!ComicReaderRequests::beginPendingImageRequest(m_pendingImageRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher, pendingKey, comicId, pageIndex]() {
        const QVariantMap result = watcher->result();
        const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
            m_pendingImageRequestIdsByKey,
            pendingKey
        );
        const int resolvedPageIndex = result.contains(QStringLiteral("pageIndex"))
            ? result.value(QStringLiteral("pageIndex")).toInt()
            : pageIndex;
        emitPageReadyForRequestIds(
            requestIds,
            comicId,
            resolvedPageIndex,
            result.value(QStringLiteral("imageSource")).toString(),
            result.value(QStringLiteral("error")).toString(),
            false
        );
        watcher->deleteLater();
    });

    const auto task = [dataRoot = m_dataRoot, comicId, archivePath = state.archivePath, entries = state.entries, resolvedPageIndex = state.resolvedPageIndex]() {
        return ComicReaderPayloads::loadReaderPagePayload(
            dataRoot,
            comicId,
            archivePath,
            entries,
            resolvedPageIndex,
            [](const QString &archivePath, const QString &entryName, const QString &outputFilePath, QString &errorText) {
                return ComicsListModel::extractArchiveEntryToFile(archivePath, entryName, outputFilePath, errorText);
            }
        );
    };

    watcher->setFuture(QtConcurrent::run(task));
    return requestId;
}

QString ComicsListModel::archivePathForComicId(int comicId) const
{
    if (comicId < 1) return {};

    const QString cachedPath = m_readerArchivePathById.value(comicId).trimmed();
    if (!cachedPath.isEmpty()) {
        return cachedPath;
    }

    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) continue;
        return row.filePath.trimmed();
    }

    return {};
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

void ComicsListModel::startQueuedCoverGeneration(const QueuedCoverGeneration &job)
{
    m_activeCoverGenerationCount += 1;

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(
        watcher,
        &QFutureWatcher<QVariantMap>::finished,
        this,
        [this, watcher, pendingKey = job.pendingKey, comicId = job.comicId, coverPath = job.coverPath]() {
        const QVariantMap result = watcher->result();
        const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
            m_pendingImageRequestIdsByKey,
            pendingKey
        );
        m_activeCoverGenerationCount = std::max(0, m_activeCoverGenerationCount - 1);

        const QString currentArchivePath = archivePathForComicId(comicId);
        const QString currentPendingKey = currentArchivePath.trimmed().isEmpty()
            ? QString()
            : ComicReaderRequests::thumbnailPendingKey(
                comicId,
                ComicReaderCache::buildArchiveCacheStamp(currentArchivePath)
            );
        const bool staleResult = currentPendingKey != pendingKey;

        if (staleResult) {
            QFile::remove(coverPath);
        } else if (requestIds.isEmpty()) {
            ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
        } else {
            const QString imageSource = result.value("imageSource").toString();
            const QString errorText = result.value("error").toString();
            if (errorText.trimmed().isEmpty() && !imageSource.trimmed().isEmpty()) {
                ComicReaderCache::pruneThumbnailVariantsForComic(m_dataRoot, comicId, coverPath);
            }
            emitPageReadyForRequestIds(
                requestIds,
                comicId,
                0,
                imageSource,
                errorText,
                true
            );
        }

        watcher->deleteLater();
        pumpQueuedCoverGeneration();
        }
    );

    const auto task = [job, dataRoot = m_dataRoot]() {
        QStringList entries;
        QString listError;
        if (!ComicsListModel::listImageEntriesInArchive(job.archivePath, entries, listError)) {
            return makeAsyncImageResult({}, listError);
        }
        if (entries.isEmpty()) {
            return makeAsyncImageResult({}, QString("No image pages found in archive."));
        }

        const QString entryName = entries.at(0);
        QString extension = QFileInfo(entryName).suffix().toLower();
        if (extension.isEmpty()) extension = QString("img");
        const QString pageCachePath = ComicReaderCache::buildReaderCachePath(dataRoot, job.comicId, job.cacheStamp, 0, extension);

        if (!ComicReaderCache::ensureDirForFile(pageCachePath) || !ComicReaderCache::ensureDirForFile(job.coverPath)) {
            return makeAsyncImageResult({}, QString("Failed to create thumbnail cache directory."));
        }

        const QFileInfo localPageInfo(pageCachePath);
        if (localPageInfo.exists() && localPageInfo.size() <= 0) {
            QFile::remove(pageCachePath);
        }

        if (!QFileInfo::exists(pageCachePath)) {
            QString extractError;
            if (!ComicsListModel::extractArchiveEntryToFile(job.archivePath, entryName, pageCachePath, extractError)) {
                return makeAsyncImageResult({}, extractError);
            }
        }

        const QFileInfo localThumbInfo(job.coverPath);
        if (localThumbInfo.exists() && localThumbInfo.size() <= 0) {
            QFile::remove(job.coverPath);
        }

        if (!QFileInfo::exists(job.coverPath)) {
            QString thumbError;
            if (!ComicImagePreparation::generateThumbnailImage(pageCachePath, job.coverPath, job.coverFormat, thumbError)) {
                return makeAsyncImageResult({}, thumbError);
            }
        }

        return makeAsyncImageResult(QUrl::fromLocalFile(job.coverPath).toString(), {});
    };

    watcher->setFuture(QtConcurrent::run(task));
}

void ComicsListModel::pumpQueuedCoverGeneration()
{
    constexpr int kMaxQueuedCoverGenerationCount = 3;

    while (m_activeCoverGenerationCount < kMaxQueuedCoverGenerationCount && !m_coverGenerationQueue.isEmpty()) {
        const QueuedCoverGeneration job = m_coverGenerationQueue.takeFirst();
        if (!ComicReaderRequests::hasPendingImageRequest(m_pendingImageRequestIdsByKey, job.pendingKey)) {
            continue;
        }
        startQueuedCoverGeneration(job);
    }
}

void ComicsListModel::startQueuedSeriesHeroGeneration(const QueuedSeriesHeroGeneration &job)
{
    m_activeSeriesHeroGenerationCount += 1;

    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(
        watcher,
        &QFutureWatcher<QVariantMap>::finished,
        this,
        [this, watcher, pendingKey = job.pendingKey, seriesKey = job.seriesKey]() {
            const QVariantMap result = watcher->result();
            const QList<int> requestIds = ComicReaderRequests::takePendingImageRequestIds(
                m_pendingSeriesHeroRequestIdsByKey,
                pendingKey
            );
            m_activeSeriesHeroGenerationCount = std::max(0, m_activeSeriesHeroGenerationCount - 1);

            const QString imageSource = result.value(QStringLiteral("imageSource")).toString();
            const QString localFilePath = result.value(QStringLiteral("localFilePath")).toString();
            const QString errorText = result.value(QStringLiteral("error")).toString();

            if (requestIds.isEmpty()) {
                ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, seriesKey);
            } else {
                if (errorText.trimmed().isEmpty() && !localFilePath.trimmed().isEmpty()) {
                    ComicReaderCache::pruneSeriesHeroVariantsForKey(m_dataRoot, seriesKey, localFilePath);
                }
                emitSeriesHeroReadyForRequestIds(requestIds, seriesKey, imageSource, errorText);
            }

            watcher->deleteLater();
            pumpQueuedSeriesHeroGeneration();
        }
    );

    const auto task = [job, dataRoot = m_dataRoot]() {
        struct HeroSource {
            int comicId = 0;
            QString archivePath;
            QString cacheStamp;
            QStringList entries;
            int eligiblePageCount = 0;
        };

        int resolvedComicId = job.comicId;
        QString resolvedArchivePath = job.archivePath;
        QString resolvedCacheStamp = job.cacheStamp;
        QStringList entries;
        int pageIndex = -1;

        if (job.randomEligiblePage) {
            QVector<HeroSource> sources;
            sources.reserve(std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size()));
            int totalEligiblePages = 0;
            QString lastListError;

            const int candidateCount = std::min(job.candidateComicIds.size(), job.candidateArchivePaths.size());
            for (int index = 0; index < candidateCount; ++index) {
                const int comicId = job.candidateComicIds.at(index);
                const QString archivePath = job.candidateArchivePaths.at(index).trimmed();
                if (comicId < 1 || archivePath.isEmpty()) continue;

                QStringList candidateEntries;
                QString listError;
                if (!ComicsListModel::listImageEntriesInArchive(archivePath, candidateEntries, listError)) {
                    lastListError = listError;
                    continue;
                }

                const int eligiblePageCount = std::max(0, static_cast<int>(candidateEntries.size()) - 4);
                if (eligiblePageCount < 1) {
                    continue;
                }

                HeroSource source;
                source.comicId = comicId;
                source.archivePath = archivePath;
                source.cacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
                source.entries = candidateEntries;
                source.eligiblePageCount = eligiblePageCount;
                sources.push_back(source);
                totalEligiblePages += eligiblePageCount;
            }

            if (totalEligiblePages < 1) {
                const QString errorText = lastListError.trimmed().isEmpty()
                    ? QStringLiteral("No eligible pages are available for shuffled background.")
                    : lastListError;
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), errorText);
            }

            int selectedOffset = QRandomGenerator::global()->bounded(totalEligiblePages);
            HeroSource selectedSource;
            for (const HeroSource &source : sources) {
                if (selectedOffset >= source.eligiblePageCount) {
                    selectedOffset -= source.eligiblePageCount;
                    continue;
                }
                selectedSource = source;
                break;
            }

            if (selectedSource.comicId < 1 || selectedSource.entries.isEmpty()) {
                return makeAsyncSeriesHeroResult(
                    job.seriesKey,
                    QString(),
                    QString(),
                    QStringLiteral("Failed to resolve shuffled background source.")
                );
            }

            resolvedComicId = selectedSource.comicId;
            resolvedArchivePath = selectedSource.archivePath;
            resolvedCacheStamp = selectedSource.cacheStamp;
            entries = selectedSource.entries;
            pageIndex = 2 + selectedOffset;
        } else {
            const QString cachedHeroPath = ComicReaderCache::cachedSeriesHeroPath(dataRoot, job.seriesKey);
            if (!cachedHeroPath.isEmpty()) {
                return makeAsyncSeriesHeroResult(
                    job.seriesKey,
                    QUrl::fromLocalFile(cachedHeroPath).toString(),
                    cachedHeroPath,
                    QString()
                );
            }

            QString listError;
            if (!ComicsListModel::listImageEntriesInArchive(resolvedArchivePath, entries, listError)) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), listError);
            }
            if (entries.isEmpty()) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), QStringLiteral("No image pages found in archive."));
            }

            pageIndex = seriesHeroPageIndexForEntryCount(entries.size());
        }

        if (pageIndex < 0 || pageIndex >= entries.size()) {
            return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), QStringLiteral("No valid hero page found in archive."));
        }

        const QString entryName = entries.at(pageIndex);
        QString extension = QFileInfo(entryName).suffix().toLower();
        if (extension.isEmpty()) extension = QStringLiteral("img");

        const QString pageCachePath = ComicReaderCache::buildReaderCachePath(
            dataRoot,
            resolvedComicId,
            resolvedCacheStamp,
            pageIndex,
            extension
        );
        const QString heroCacheStamp = QStringLiteral("%1-p%2").arg(resolvedCacheStamp).arg(pageIndex + 1);
        const QString heroPath = ComicReaderCache::buildSeriesHeroPathWithFormat(
            dataRoot,
            job.seriesKey,
            heroCacheStamp,
            job.heroFormat
        );

        if (!ComicReaderCache::ensureDirForFile(pageCachePath) || !ComicReaderCache::ensureDirForFile(heroPath)) {
            return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), QStringLiteral("Failed to create hero cache directory."));
        }

        const QFileInfo localPageInfo(pageCachePath);
        if (localPageInfo.exists() && localPageInfo.size() <= 0) {
            QFile::remove(pageCachePath);
        }

        if (!QFileInfo::exists(pageCachePath)) {
            QString extractError;
            if (!ComicsListModel::extractArchiveEntryToFile(resolvedArchivePath, entryName, pageCachePath, extractError)) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), extractError);
            }
        }

        const QFileInfo localHeroInfo(heroPath);
        if (localHeroInfo.exists() && localHeroInfo.size() <= 0) {
            QFile::remove(heroPath);
        }

        if (!QFileInfo::exists(heroPath)) {
            QString heroError;
            if (!ComicImagePreparation::generateHeroBackgroundImage(pageCachePath, heroPath, job.heroFormat, heroError)) {
                return makeAsyncSeriesHeroResult(job.seriesKey, QString(), QString(), heroError);
            }
        }

        return makeAsyncSeriesHeroResult(
            job.seriesKey,
            QUrl::fromLocalFile(heroPath).toString(),
            heroPath,
            QString()
        );
    };

    watcher->setFuture(QtConcurrent::run(task));
}

void ComicsListModel::pumpQueuedSeriesHeroGeneration()
{
    constexpr int kMaxQueuedSeriesHeroGenerationCount = 1;

    while (m_activeSeriesHeroGenerationCount < kMaxQueuedSeriesHeroGenerationCount && !m_seriesHeroGenerationQueue.isEmpty()) {
        const QueuedSeriesHeroGeneration job = m_seriesHeroGenerationQueue.takeFirst();
        if (!ComicReaderRequests::hasPendingImageRequest(m_pendingSeriesHeroRequestIdsByKey, job.pendingKey)) {
            continue;
        }
        startQueuedSeriesHeroGeneration(job);
    }
}

int ComicsListModel::requestIssueThumbnailAsync(int comicId)
{
    const int requestId = m_nextAsyncRequestId++;
    auto emitLaterSingle = [this, requestId, comicId](const QString &imageSource, const QString &errorText) {
        emitPageReadyForRequestIds({ requestId }, comicId, 0, imageSource, errorText, true);
    };

    if (comicId < 1) {
        emitLaterSingle({}, QString("Invalid issue id."));
        return requestId;
    }

    const QString archivePath = archivePathForComicId(comicId);
    if (archivePath.isEmpty()) {
        emitLaterSingle({}, QString("Archive path is not available for cover generation."));
        return requestId;
    }

    const QString cacheStamp = ComicReaderCache::buildArchiveCacheStamp(archivePath);
    const QByteArray thumbFormat = ComicReaderCache::preferredThumbnailFormat();
    const QString thumbPath = ComicReaderCache::buildThumbnailPathWithFormat(m_dataRoot, comicId, cacheStamp, thumbFormat);

    const QFileInfo thumbInfo(thumbPath);
    if (thumbInfo.exists() && thumbInfo.size() > 0) {
        ComicReaderCache::pruneThumbnailVariantsForComic(m_dataRoot, comicId, thumbPath);
        emitLaterSingle(QUrl::fromLocalFile(thumbPath).toString(), {});
        return requestId;
    }
    if (thumbInfo.exists() && thumbInfo.size() <= 0) {
        QFile::remove(thumbPath);
    }

    const QString pendingKey = ComicReaderRequests::thumbnailPendingKey(comicId, cacheStamp);
    if (!ComicReaderRequests::beginPendingImageRequest(m_pendingImageRequestIdsByKey, pendingKey, requestId)) {
        return requestId;
    }

    const QueuedCoverGeneration job {
        pendingKey,
        comicId,
        archivePath,
        cacheStamp,
        thumbPath,
        thumbFormat
    };

    constexpr int kMaxQueuedCoverGenerationCount = 3;
    if (m_activeCoverGenerationCount < kMaxQueuedCoverGenerationCount) {
        startQueuedCoverGeneration(job);
    } else {
        m_coverGenerationQueue.push_back(job);
    }
    return requestId;
}

QString ComicsListModel::cachedIssueThumbnailSource(int comicId) const
{
    if (comicId < 1) return {};

    QString archivePath = m_readerArchivePathById.value(comicId).trimmed();
    if (archivePath.isEmpty()) {
        for (const ComicRow &row : m_rows) {
            if (row.id != comicId) continue;
            archivePath = row.filePath.trimmed();
            break;
        }
    }
    if (archivePath.isEmpty()) return {};

    return ComicReaderPayloads::cachedIssueThumbnailSource(m_dataRoot, comicId, archivePath);
}

void ComicsListModel::emitPageReadyForRequestIds(
    const QList<int> &requestIds,
    int comicId,
    int pageIndex,
    const QString &imageSource,
    const QString &error,
    bool thumbnail
)
{
    if (requestIds.isEmpty()) return;

    QMetaObject::invokeMethod(
        this,
        [this, requestIds, comicId, pageIndex, imageSource, error, thumbnail]() {
            for (int requestId : requestIds) {
                emit pageImageReady(requestId, comicId, pageIndex, imageSource, error, thumbnail);
            }
        },
        Qt::QueuedConnection
    );
}

void ComicsListModel::emitSeriesHeroReadyForRequestIds(
    const QList<int> &requestIds,
    const QString &seriesKey,
    const QString &imageSource,
    const QString &error
)
{
    if (requestIds.isEmpty()) return;

    QMetaObject::invokeMethod(
        this,
        [this, requestIds, seriesKey, imageSource, error]() {
            for (int requestId : requestIds) {
                emit seriesHeroReady(requestId, seriesKey, imageSource, error);
            }
        },
        Qt::QueuedConnection
    );
}

void ComicsListModel::purgeSeriesHeroCacheForKey(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return;

    ComicReaderCache::purgeSeriesHeroForKey(m_dataRoot, normalizedKey);

    const QString pendingKey = seriesHeroPendingKey(normalizedKey);
    m_pendingSeriesHeroRequestIdsByKey.remove(pendingKey);

    m_seriesHeroGenerationQueue.erase(
        std::remove_if(
            m_seriesHeroGenerationQueue.begin(),
            m_seriesHeroGenerationQueue.end(),
            [normalizedKey](const QueuedSeriesHeroGeneration &job) {
                return job.seriesKey == normalizedKey;
            }
        ),
        m_seriesHeroGenerationQueue.end()
    );
}

QString ComicsListModel::saveReaderProgress(int comicId, int currentPage)
{
    if (comicId < 1) return QString("Invalid issue id.");
    if (currentPage < 0 || currentPage > 1000000) {
        return QString("Current page must be between 0 and 1000000.");
    }

    const int pageCount = m_readerImageEntriesById.value(comicId).size();
    QString readStatus = QString("unread");
    if (currentPage > 0) {
        if (pageCount > 0 && currentPage >= pageCount) {
            readStatus = QString("read");
        } else {
            readStatus = QString("in_progress");
        }
    }

    const QString saveError = ComicReaderSessionOps::saveReaderProgress(
        m_dbPath,
        comicId,
        currentPage,
        readStatus
    );
    if (!saveError.isEmpty()) {
        return saveError;
    }

    updateReaderProgressCache(comicId, currentPage, readStatus);
    return {};
}

QString ComicsListModel::saveReaderBookmark(int comicId, int bookmarkPage)
{
    if (comicId < 1) return QString("Invalid issue id.");
    if (bookmarkPage < 0 || bookmarkPage > 1000000) {
        return QString("Bookmark page must be between 0 and 1000000.");
    }

    const QString saveError = ComicReaderSessionOps::saveReaderBookmark(
        m_dbPath,
        comicId,
        bookmarkPage
    );
    if (!saveError.isEmpty()) {
        return saveError;
    }

    updateReaderBookmarkCache(comicId, bookmarkPage);
    return {};
}

QString ComicsListModel::saveReaderFavorite(int comicId, bool favoriteActive)
{
    if (comicId < 1) return QString("Invalid issue id.");

    const QString saveError = ComicReaderSessionOps::saveReaderFavorite(
        m_dbPath,
        comicId,
        favoriteActive
    );
    if (!saveError.isEmpty()) {
        return saveError;
    }

    updateReaderFavoriteCache(comicId, favoriteActive);
    return {};
}

QString ComicsListModel::copyImageFileToClipboard(const QString &imageSource)
{
    const QString sourceText = imageSource.trimmed();
    if (sourceText.isEmpty()) {
        return QStringLiteral("Page image is not ready.");
    }

    QString localPath;
    const QUrl sourceUrl(sourceText);
    if (sourceUrl.isValid() && sourceUrl.isLocalFile()) {
        localPath = sourceUrl.toLocalFile();
    } else {
        localPath = sourceText;
    }

    if (localPath.isEmpty()) {
        return QStringLiteral("Page image path is invalid.");
    }

    QFileInfo fileInfo(localPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        return QStringLiteral("Page image file was not found.");
    }

    QImageReader reader(localPath);
    const QImage image = reader.read();
    if (image.isNull()) {
        const QString readerError = reader.errorString().trimmed();
        if (!readerError.isEmpty()) {
            return readerError;
        }
        return QStringLiteral("Failed to load page image.");
    }

    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        return QStringLiteral("Clipboard is unavailable.");
    }

    clipboard->setImage(image);
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

QVariantMap ComicsListModel::buildRetainedSeriesMetadata(const QString &seriesKey) const
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty() || normalizedKey == QStringLiteral("unknown-series")) {
        return {};
    }

    const QVariantMap storedMetadata = ComicLibraryQueries::seriesMetadataForKey(m_dbPath, normalizedKey);
    QString retainedSeriesTitle = valueFromMap(storedMetadata, QStringLiteral("seriesTitle"));
    QString retainedSummary = valueFromMap(storedMetadata, QStringLiteral("summary"));
    QString retainedYear = valueFromMap(storedMetadata, QStringLiteral("year"));
    QString retainedMonth = valueFromMap(storedMetadata, QStringLiteral("month"));
    QString retainedGenres = valueFromMap(storedMetadata, QStringLiteral("genres"));
    QString retainedVolume = valueFromMap(storedMetadata, QStringLiteral("volume"));
    QString retainedPublisher = valueFromMap(storedMetadata, QStringLiteral("publisher"));
    QString retainedAgeRating = valueFromMap(storedMetadata, QStringLiteral("ageRating"));

    int earliestYear = 0;
    int singleMonth = 0;
    bool multipleMonths = false;
    QString singleVolume;
    bool multipleVolumes = false;
    QString singleAgeRating;
    bool multipleAgeRatings = false;
    QHash<QString, int> publisherCounts;
    QHash<QString, QString> publisherLabels;
    QSet<QString> genreKeys;
    QStringList genreTokens;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != normalizedKey) continue;

        const QString rowSeries = row.series.trimmed();
        if (retainedSeriesTitle.isEmpty() && !rowSeries.isEmpty() && !isWeakSeriesName(rowSeries)) {
            retainedSeriesTitle = rowSeries;
        }

        if (row.year > 0 && (earliestYear < 1 || row.year < earliestYear)) {
            earliestYear = row.year;
        }

        if (retainedMonth.isEmpty() && row.month > 0) {
            if (singleMonth < 1) {
                singleMonth = row.month;
            } else if (singleMonth != row.month) {
                multipleMonths = true;
            }
        }

        const QString rowVolume = row.volume.trimmed();
        if (retainedVolume.isEmpty() && !rowVolume.isEmpty()) {
            if (singleVolume.isEmpty()) {
                singleVolume = rowVolume;
            } else if (singleVolume.compare(rowVolume, Qt::CaseInsensitive) != 0) {
                multipleVolumes = true;
            }
        }

        const QString rowPublisher = row.publisher.trimmed();
        if (retainedPublisher.isEmpty() && !rowPublisher.isEmpty()) {
            const QString publisherKey = rowPublisher.toLower();
            publisherCounts[publisherKey] = publisherCounts.value(publisherKey) + 1;
            if (!publisherLabels.contains(publisherKey)) {
                publisherLabels.insert(publisherKey, rowPublisher);
            }
        }

        const QString rowAgeRating = row.ageRating.trimmed();
        if (retainedAgeRating.isEmpty() && !rowAgeRating.isEmpty()) {
            if (singleAgeRating.isEmpty()) {
                singleAgeRating = rowAgeRating;
            } else if (singleAgeRating.compare(rowAgeRating, Qt::CaseInsensitive) != 0) {
                multipleAgeRatings = true;
            }
        }

        if (retainedGenres.isEmpty()) {
            const QStringList rowGenreValues = row.genres.split('/', Qt::SkipEmptyParts);
            for (const QString &rawToken : rowGenreValues) {
                const QString token = rawToken.trimmed();
                if (token.isEmpty()) continue;
                const QString genreKey = token.toLower();
                if (genreKeys.contains(genreKey)) continue;
                genreKeys.insert(genreKey);
                genreTokens.push_back(token);
            }
        }
    }

    if (retainedSeriesTitle.isEmpty()) {
        const QString groupTitle = makeGroupTitle(normalizedKey).trimmed();
        if (!groupTitle.isEmpty() && !isWeakSeriesName(groupTitle)) {
            retainedSeriesTitle = groupTitle;
        }
    }

    if (retainedYear.isEmpty() && earliestYear > 0) {
        retainedYear = QString::number(earliestYear);
    }

    if (retainedMonth.isEmpty() && !multipleMonths && singleMonth > 0) {
        retainedMonth = QString::number(singleMonth);
    }

    if (retainedGenres.isEmpty() && !genreTokens.isEmpty()) {
        retainedGenres = genreTokens.join(QStringLiteral(" / "));
    }

    if (retainedVolume.isEmpty() && !multipleVolumes && !singleVolume.isEmpty()) {
        retainedVolume = singleVolume;
    }

    if (retainedPublisher.isEmpty() && !publisherCounts.isEmpty()) {
        QString topPublisher;
        int topPublisherCount = -1;
        for (auto it = publisherCounts.constBegin(); it != publisherCounts.constEnd(); ++it) {
            if (it.value() > topPublisherCount) {
                topPublisherCount = it.value();
                topPublisher = publisherLabels.value(it.key()).trimmed();
            }
        }
        retainedPublisher = topPublisher;
    }

    if (retainedAgeRating.isEmpty() && !multipleAgeRatings && !singleAgeRating.isEmpty()) {
        retainedAgeRating = singleAgeRating;
    }

    const bool hasMeaningfulTitle = !retainedSeriesTitle.isEmpty() && !isWeakSeriesName(retainedSeriesTitle);
    const bool hasSupportingData = !retainedSummary.isEmpty()
        || !retainedYear.isEmpty()
        || !retainedMonth.isEmpty()
        || !retainedGenres.isEmpty()
        || !retainedVolume.isEmpty()
        || !retainedPublisher.isEmpty()
        || !retainedAgeRating.isEmpty();
    if (!hasMeaningfulTitle || !hasSupportingData) {
        return {};
    }

    QVariantMap retainedValues;
    retainedValues.insert(QStringLiteral("seriesTitle"), retainedSeriesTitle);
    if (!retainedSummary.isEmpty()) retainedValues.insert(QStringLiteral("summary"), retainedSummary);
    if (!retainedYear.isEmpty()) retainedValues.insert(QStringLiteral("year"), retainedYear);
    if (!retainedMonth.isEmpty()) retainedValues.insert(QStringLiteral("month"), retainedMonth);
    if (!retainedGenres.isEmpty()) retainedValues.insert(QStringLiteral("genres"), retainedGenres);
    if (!retainedVolume.isEmpty()) retainedValues.insert(QStringLiteral("volume"), retainedVolume);
    if (!retainedPublisher.isEmpty()) retainedValues.insert(QStringLiteral("publisher"), retainedPublisher);
    if (!retainedAgeRating.isEmpty()) retainedValues.insert(QStringLiteral("ageRating"), retainedAgeRating);
    return retainedValues;
}

QString ComicsListModel::preserveRetainedSeriesMetadata(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return {};

    const QVariantMap retainedValues = buildRetainedSeriesMetadata(normalizedKey);
    if (retainedValues.isEmpty()) {
        return ComicLibraryQueries::setSeriesMetadataForKey(m_dbPath, normalizedKey, {
            { QStringLiteral("headerCoverPath"), QString() },
            { QStringLiteral("headerBackgroundPath"), QString() }
        });
    }
    QVariantMap valuesToPersist = retainedValues;
    valuesToPersist.insert(QStringLiteral("headerCoverPath"), QString());
    valuesToPersist.insert(QStringLiteral("headerBackgroundPath"), QString());
    return ComicLibraryQueries::setSeriesMetadataForKey(m_dbPath, normalizedKey, valuesToPersist);
}

QVariantMap ComicsListModel::buildRetainedIssueMetadata(int comicId) const
{
    if (comicId < 1) {
        return {};
    }

    for (const ComicRow &row : m_rows) {
        if (row.id != comicId) {
            continue;
        }

        const QString seriesTitle = row.series.trimmed();
        const QString issueNumber = row.issueNumber.trimmed();
        if (seriesTitle.isEmpty() || isWeakSeriesName(seriesTitle) || normalizeIssueKey(issueNumber).isEmpty()) {
            return {};
        }

        const bool hasSupportingData = !row.title.trimmed().isEmpty()
            || !row.publisher.trimmed().isEmpty()
            || row.year > 0
            || row.month > 0
            || !row.ageRating.trimmed().isEmpty()
            || !row.writer.trimmed().isEmpty()
            || !row.penciller.trimmed().isEmpty()
            || !row.inker.trimmed().isEmpty()
            || !row.colorist.trimmed().isEmpty()
            || !row.letterer.trimmed().isEmpty()
            || !row.coverArtist.trimmed().isEmpty()
            || !row.editor.trimmed().isEmpty()
            || !row.storyArc.trimmed().isEmpty()
            || !row.characters.trimmed().isEmpty();
        if (!hasSupportingData) {
            return {};
        }

        QVariantMap retainedValues;
        retainedValues.insert(QStringLiteral("series"), seriesTitle);
        retainedValues.insert(QStringLiteral("volume"), row.volume.trimmed());
        retainedValues.insert(QStringLiteral("issueNumber"), issueNumber);
        if (!row.title.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("title"), row.title.trimmed());
        if (!row.publisher.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("publisher"), row.publisher.trimmed());
        if (row.year > 0) retainedValues.insert(QStringLiteral("year"), QString::number(row.year));
        if (row.month > 0) retainedValues.insert(QStringLiteral("month"), QString::number(row.month));
        if (!row.ageRating.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("ageRating"), row.ageRating.trimmed());
        if (!row.writer.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("writer"), row.writer.trimmed());
        if (!row.penciller.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("penciller"), row.penciller.trimmed());
        if (!row.inker.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("inker"), row.inker.trimmed());
        if (!row.colorist.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("colorist"), row.colorist.trimmed());
        if (!row.letterer.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("letterer"), row.letterer.trimmed());
        if (!row.coverArtist.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("coverArtist"), row.coverArtist.trimmed());
        if (!row.editor.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("editor"), row.editor.trimmed());
        if (!row.storyArc.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("storyArc"), row.storyArc.trimmed());
        if (!row.characters.trimmed().isEmpty()) retainedValues.insert(QStringLiteral("characters"), row.characters.trimmed());
        return retainedValues;
    }

    return {};
}

QString ComicsListModel::preserveRetainedIssueMetadata(int comicId)
{
    const QVariantMap retainedValues = buildRetainedIssueMetadata(comicId);
    if (retainedValues.isEmpty()) {
        return {};
    }
    return ComicLibraryQueries::setIssueMetadataKnowledge(m_dbPath, retainedValues);
}

QString ComicsListModel::deleteSeriesFiles(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return QStringLiteral("Series key is required.");

    QVector<int> idsToDelete;
    QVector<int> deletedComicIds;
    idsToDelete.reserve(m_rows.size());
    deletedComicIds.reserve(m_rows.size());
    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey == normalizedKey) {
            idsToDelete.push_back(row.id);
        }
    }

    if (idsToDelete.isEmpty()) {
        return QStringLiteral("No issues found for selected series.");
    }

    const QString preserveError = preserveRetainedSeriesMetadata(normalizedKey);
    if (!preserveError.isEmpty()) {
        return preserveError;
    }
    purgeSeriesHeroCacheForKey(normalizedKey);
    ComicReaderCache::purgeSeriesHeaderOverridesForKey(m_dataRoot, normalizedKey);

    QStringList errors;
    for (int comicId : idsToDelete) {
        const QString preserveIssueError = preserveRetainedIssueMetadata(comicId);
        if (!preserveIssueError.isEmpty()) {
            errors.push_back(preserveIssueError);
            continue;
        }
        const QString deleteError = deleteComicHard(comicId);
        if (!deleteError.isEmpty()) {
            errors.push_back(deleteError);
        } else {
            deletedComicIds.push_back(comicId);
        }
    }

    const QString historyCleanupError = deleteFileFingerprintHistoryForComicIds(deletedComicIds);
    if (!historyCleanupError.isEmpty()) {
        errors.push_back(QStringLiteral("Fingerprint history cleanup failed: %1").arg(historyCleanupError));
    }

    if (!errors.isEmpty()) {
        return QStringLiteral("Some issues could not be removed:\n%1").arg(errors.join('\n'));
    }
    return {};
}

QString ComicsListModel::deleteSeriesFilesKeepRecords(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return QString("Series key is required.");

    QVector<int> idsToMarkMissing;
    QVector<DeleteFailureInfo> failedFiles;
    QVector<StagedArchiveDeleteOp> stagedDeletes;
    QVector<ComicIssueFileOps::ComicFilePathBinding> clearBindings;
    QStringList dirsToCleanup;
    QHash<int, FingerprintHistoryEntrySpec> deleteFingerprintEntriesById;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != normalizedKey) continue;

        StagedArchiveDeleteOp stagedDelete;
        stagedDelete.comicId = row.id;
        bool markMissing = true;
        if (!row.filePath.isEmpty()) {
            FingerprintSnapshot deleteFingerprint;
            QString deleteFingerprintError;
            if (computeFileFingerprint(row.filePath, deleteFingerprint, deleteFingerprintError)) {
                QVector<FingerprintHistoryEntrySpec> historyEntries;
                appendFingerprintHistoryEntry(
                    historyEntries,
                    row.id,
                    row.seriesGroupKey,
                    QStringLiteral("delete_keep_record"),
                    QStringLiteral("archive"),
                    QStringLiteral("library"),
                    deleteFingerprint,
                    row.filename
                );
                if (!historyEntries.isEmpty()) {
                    deleteFingerprintEntriesById.insert(row.id, historyEntries.first());
                }
            }

            DeleteFailureInfo failure;
            if (!performStageArchiveDelete(row.filePath, stagedDelete, failure)) {
                markMissing = false;
                failedFiles.push_back(failure);
            }
        }

        if (markMissing) {
            idsToMarkMissing.push_back(row.id);
            stagedDeletes.push_back(stagedDelete);
            clearBindings.push_back({ row.id, QString() });
        }
    }

    if (idsToMarkMissing.isEmpty() && failedFiles.isEmpty()) {
        return QString("No issues found for selected series.");
    }

    if (!clearBindings.isEmpty()) {
        const QString applyError = ComicIssueFileOps::applyComicFilePathBindings(
            m_dbPath,
            clearBindings,
            QStringLiteral("delete_series_files")
        );
        if (!applyError.isEmpty()) {
            const QString rollbackWarning = performRollbackStagedArchiveDeletes(stagedDeletes);
            if (!rollbackWarning.isEmpty()) {
                return QString("%1\nRollback warning:\n%2").arg(applyError, rollbackWarning);
            }
            return applyError;
        }
    }

    QVector<int> finalRemovedIds = idsToMarkMissing;
    if (!stagedDeletes.isEmpty()) {
        QVector<ComicIssueFileOps::ComicFilePathBinding> restoreBindings;
        QSet<int> restoredIds;
        QStringList recoveryWarnings;

        for (const StagedArchiveDeleteOp &stagedDelete : stagedDeletes) {
            QString cleanupDirPath;
            DeleteFailureInfo finalizeFailure;
            if (performFinalizeStagedArchiveDelete(stagedDelete, cleanupDirPath, finalizeFailure)) {
                if (!cleanupDirPath.isEmpty()) {
                    dirsToCleanup.push_back(cleanupDirPath);
                }
                continue;
            }

            failedFiles.push_back(finalizeFailure);

            DeleteFailureInfo rollbackFailure;
            if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
                recoveryWarnings.push_back(formatDeleteFailureText(rollbackFailure));
                continue;
            }

            if (!stagedDelete.originalPath.trimmed().isEmpty()) {
                restoreBindings.push_back({ stagedDelete.comicId, stagedDelete.originalPath });
            }
            restoredIds.insert(stagedDelete.comicId);
        }

        if (!restoreBindings.isEmpty()) {
            const QString restoreError = ComicIssueFileOps::applyComicFilePathBindings(
                m_dbPath,
                restoreBindings,
                QStringLiteral("restore_series_files_after_delete")
            );
            if (!restoreError.isEmpty()) {
                recoveryWarnings.push_back(
                    QStringLiteral("Failed to restore DB links for recovered archives: %1").arg(restoreError)
                );
            } else {
                QVector<int> keptIds;
                keptIds.reserve(finalRemovedIds.size());
                for (int id : finalRemovedIds) {
                    if (!restoredIds.contains(id)) {
                        keptIds.push_back(id);
                    }
                }
                finalRemovedIds.swap(keptIds);
            }
        }

        cleanupEmptyLibraryDirs(QDir(m_dataRoot).filePath(QStringLiteral("Library")), dirsToCleanup);

        if (!recoveryWarnings.isEmpty()) {
            reload();
            QStringList lines;
            lines.reserve(failedFiles.size() + recoveryWarnings.size());
            for (const DeleteFailureInfo &info : failedFiles) {
                lines.push_back(formatDeleteFailureText(info));
            }
            for (const QString &warning : recoveryWarnings) {
                lines.push_back(QStringLiteral("Recovery: %1").arg(warning));
            }
            return QString("Some files could not be removed:\n%1").arg(lines.join('\n'));
        }
    } else {
        cleanupEmptyLibraryDirs(QDir(m_dataRoot).filePath(QStringLiteral("Library")), dirsToCleanup);
    }

    if (!finalRemovedIds.isEmpty()) {
        QVector<FingerprintHistoryEntrySpec> fingerprintEntries;
        for (int id : finalRemovedIds) {
            const auto found = deleteFingerprintEntriesById.constFind(id);
            if (found != deleteFingerprintEntriesById.constEnd()) {
                fingerprintEntries.push_back(found.value());
            }
        }
        insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, nullptr);

        purgeSeriesHeroCacheForKey(normalizedKey);

        for (int id : finalRemovedIds) {
            ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, id);
            m_readerArchivePathById.remove(id);
            m_readerImageEntriesById.remove(id);
            m_readerPageMetricsById.remove(id);
        }

        ComicReaderRequests::clearPendingImageRequestsForComics(
            m_pendingImageRequestIdsByKey,
            finalRemovedIds
        );

        m_lastMutationKind = QString("delete_series_files_keep_records");
        emit statusChanged();
        reload();
    }

    if (!failedFiles.isEmpty()) {
        if (finalRemovedIds.isEmpty()) {
            reload();
        }
        QStringList lines;
        lines.reserve(failedFiles.size());
        for (const DeleteFailureInfo &info : failedFiles) {
            lines.push_back(formatDeleteFailureText(info));
        }
        return QString("Some files could not be removed:\n%1").arg(lines.join('\n'));
    }

    return {};
}

QString ComicsListModel::deleteComicFilesKeepRecord(int comicId)
{
    if (comicId < 1) return QString("Invalid issue id.");

    const QString seriesKey = seriesGroupKeyForComicId(comicId);

    QString filePath;
    {
        const QString loadError = ComicIssueFileOps::loadComicFilePath(m_dbPath, comicId, filePath);
        if (!loadError.isEmpty()) {
            return loadError;
        }
    }

    QVector<FingerprintHistoryEntrySpec> fingerprintEntries;
    if (!filePath.isEmpty()) {
        FingerprintSnapshot deleteFingerprint;
        QString deleteFingerprintError;
        if (computeFileFingerprint(filePath, deleteFingerprint, deleteFingerprintError)) {
            appendFingerprintHistoryEntry(
                fingerprintEntries,
                comicId,
                seriesKey,
                QStringLiteral("delete_keep_record"),
                QStringLiteral("archive"),
                QStringLiteral("library"),
                deleteFingerprint,
                QFileInfo(filePath).fileName().trimmed()
            );
        }
    }

    StagedArchiveDeleteOp stagedDelete;
    stagedDelete.comicId = comicId;
    if (!filePath.isEmpty()) {
        DeleteFailureInfo stageFailure;
        if (!performStageArchiveDelete(filePath, stagedDelete, stageFailure)) {
            return QString("Could not remove archive file.\n%1").arg(formatDeleteFailureText(stageFailure));
        }
    }

    const QString applyError = ComicIssueFileOps::applyComicFilePathBindings(
        m_dbPath,
        { { comicId, QString() } },
        QStringLiteral("delete_issue_files")
    );
    if (!applyError.isEmpty()) {
        DeleteFailureInfo rollbackFailure;
        if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
            return QString("%1\nRollback warning:\n%2")
                .arg(applyError, formatDeleteFailureText(rollbackFailure));
        }
        return applyError;
    }

    QString removedDirPath;
    DeleteFailureInfo finalizeFailure;
    if (!performFinalizeStagedArchiveDelete(stagedDelete, removedDirPath, finalizeFailure)) {
        DeleteFailureInfo rollbackFailure;
        if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
            reload();
            return QString("Could not remove archive file.\n%1\nRecovery warning:\n%2")
                .arg(formatDeleteFailureText(finalizeFailure), formatDeleteFailureText(rollbackFailure));
        }

        const QString restoreError = ComicIssueFileOps::applyComicFilePathBindings(
            m_dbPath,
            { { comicId, stagedDelete.originalPath } },
            QStringLiteral("restore_issue_file_after_delete")
        );
        if (!restoreError.isEmpty()) {
            reload();
            return QString("Could not remove archive file.\n%1\nRecovery warning: archive was restored on disk but DB relink failed: %2")
                .arg(formatDeleteFailureText(finalizeFailure), restoreError);
        }

        return QString("Could not remove archive file.\n%1").arg(formatDeleteFailureText(finalizeFailure));
    }

    insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, nullptr);
    const QString ghostCleanupError = pruneEquivalentDetachedGhostRowsForComic(comicId);
    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);
    m_readerArchivePathById.remove(comicId);
    m_readerImageEntriesById.remove(comicId);
    m_readerPageMetricsById.remove(comicId);
    ComicReaderRequests::clearPendingImageRequestsForComic(m_pendingImageRequestIdsByKey, comicId);

    m_lastMutationKind = QString("delete_issue_files_keep_record");
    emit statusChanged();
    if (!removedDirPath.isEmpty()) {
        cleanupEmptyLibraryDirs(
            QDir(m_dataRoot).filePath(QStringLiteral("Library")),
            { removedDirPath }
        );
    }
    reload();
    if (!ghostCleanupError.isEmpty()) {
        return QStringLiteral(
            "Archive file was removed, but cleanup of older restore duplicates failed.\n%1"
        ).arg(ghostCleanupError);
    }
    return {};
}

QString ComicsListModel::detachComicFileKeepMetadata(int comicId)
{
    if (comicId < 1) return QString("Invalid issue id.");

    const QString seriesKey = seriesGroupKeyForComicId(comicId);

    const QString updateError = ComicIssueFileOps::applyComicFilePathBindings(
        m_dbPath,
        { { comicId, QString() } },
        QStringLiteral("detach_issue_file")
    );
    if (!updateError.isEmpty()) {
        return updateError;
    }

    const QString ghostCleanupError = pruneEquivalentDetachedGhostRowsForComic(comicId);
    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);

    int removeIndex = -1;
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        if (m_rows.at(rowIndex).id == comicId) {
            removeIndex = rowIndex;
            break;
        }
    }
    if (removeIndex >= 0) {
        beginRemoveRows(QModelIndex(), removeIndex, removeIndex);
        m_rows.removeAt(removeIndex);
        endRemoveRows();
    }

    m_readerArchivePathById.remove(comicId);
    m_readerImageEntriesById.remove(comicId);
    m_readerPageMetricsById.remove(comicId);
    ComicReaderRequests::clearPendingImageRequestsForComic(m_pendingImageRequestIdsByKey, comicId);

    m_lastMutationKind = QString("detach_issue_file_keep_metadata");
    emit statusChanged();
    if (!ghostCleanupError.isEmpty()) {
        return QStringLiteral(
            "Issue file was detached, but cleanup of older restore duplicates failed.\n%1"
        ).arg(ghostCleanupError);
    }
    return {};
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

    const QString existingFilePath = normalizeInputFilePath(metadata.value(QStringLiteral("filePath")).toString());
    if (existingFilePath.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Replace failed: existing archive path is missing."));
        return result;
    }

    QString existingFilename = metadata.value(QStringLiteral("filename")).toString().trimmed();
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
    result.insert(QStringLiteral("backupPath"), stagedDelete.stagedPath);
    ComicDeleteOps::rememberPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);

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

QString ComicsListModel::pruneEquivalentDetachedGhostRowsForComic(int comicId)
{
    if (comicId < 1) return {};

    struct DetachedGhostIdentity {
        int id = 0;
        QString filename;
        QString importOriginalFilename;
        QString importStrictFilenameSignature;
        QString importLooseFilenameSignature;
        QString seriesKey;
        QString volume;
        QString issue;
    };

    auto effectiveFilenameLabel = [](const DetachedGhostIdentity &identity) -> QString {
        const QString original = identity.importOriginalFilename.trimmed();
        if (!original.isEmpty()) {
            return original;
        }
        return identity.filename.trimmed();
    };

    auto effectiveStrictSignature = [&](const DetachedGhostIdentity &identity) -> QString {
        const QString stored = identity.importStrictFilenameSignature.trimmed();
        if (!stored.isEmpty()) {
            return stored;
        }
        const QString sourceName = effectiveFilenameLabel(identity);
        if (sourceName.isEmpty()) {
            return {};
        }
        return normalizeFilenameSignatureStrict(sourceName);
    };

    auto effectiveLooseSignature = [&](const DetachedGhostIdentity &identity) -> QString {
        const QString stored = identity.importLooseFilenameSignature.trimmed();
        if (!stored.isEmpty()) {
            return stored;
        }
        const QString sourceName = effectiveFilenameLabel(identity);
        if (sourceName.isEmpty()) {
            return {};
        }
        return normalizeFilenameSignatureLoose(sourceName);
    };

    auto sameTextCi = [](const QString &left, const QString &right) -> bool {
        return !left.trimmed().isEmpty()
            && !right.trimmed().isEmpty()
            && QString::compare(left.trimmed(), right.trimmed(), Qt::CaseInsensitive) == 0;
    };

    const QString connectionName = QStringLiteral("comic_pile_prune_detached_ghosts_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return openError;
    }

    DetachedGhostIdentity current;
    {
        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT "
                "COALESCE(filename, ''), "
                "COALESCE(import_original_filename, ''), "
                "COALESCE(import_strict_filename_signature, ''), "
                "COALESCE(import_loose_filename_signature, ''), "
                "COALESCE(series_key, ''), "
                "COALESCE(volume, ''), "
                "COALESCE(issue_number, issue, '') "
                "FROM comics "
                "WHERE id = ?"
            )
        );
        query.addBindValue(comicId);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to inspect restore duplicates: %1").arg(query.lastError().text());
            db.close();
            return error;
        }
        if (!query.next()) {
            db.close();
            return {};
        }

        current.id = comicId;
        current.filename = trimOrEmpty(query.value(0));
        current.importOriginalFilename = trimOrEmpty(query.value(1));
        current.importStrictFilenameSignature = trimOrEmpty(query.value(2));
        current.importLooseFilenameSignature = trimOrEmpty(query.value(3));
        current.seriesKey = trimOrEmpty(query.value(4));
        current.volume = trimOrEmpty(query.value(5));
        current.issue = trimOrEmpty(query.value(6));
    }

    const QString currentSeriesKey = current.seriesKey.trimmed();
    const QString currentIssueKey = normalizeIssueKey(current.issue);
    const QString currentVolumeKey = normalizeVolumeKey(current.volume);
    const QString currentStrictSignature = effectiveStrictSignature(current);
    const QString currentLooseSignature = effectiveLooseSignature(current);

    if (currentSeriesKey.isEmpty() || currentIssueKey.isEmpty()) {
        db.close();
        return {};
    }

    QVector<int> duplicateIds;
    {
        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT "
                "id, "
                "COALESCE(filename, ''), "
                "COALESCE(import_original_filename, ''), "
                "COALESCE(import_strict_filename_signature, ''), "
                "COALESCE(import_loose_filename_signature, ''), "
                "COALESCE(volume, ''), "
                "COALESCE(issue_number, issue, '') "
                "FROM comics "
                "WHERE id <> ? "
                "AND series_key = ? "
                "AND COALESCE(file_path, '') = ''"
            )
        );
        query.addBindValue(comicId);
        query.addBindValue(currentSeriesKey);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to load restore duplicates: %1").arg(query.lastError().text());
            db.close();
            return error;
        }

        while (query.next()) {
            DetachedGhostIdentity candidate;
            candidate.id = query.value(0).toInt();
            candidate.filename = trimOrEmpty(query.value(1));
            candidate.importOriginalFilename = trimOrEmpty(query.value(2));
            candidate.importStrictFilenameSignature = trimOrEmpty(query.value(3));
            candidate.importLooseFilenameSignature = trimOrEmpty(query.value(4));
            candidate.volume = trimOrEmpty(query.value(5));
            candidate.issue = trimOrEmpty(query.value(6));

            if (normalizeIssueKey(candidate.issue) != currentIssueKey) {
                continue;
            }
            if (normalizeVolumeKey(candidate.volume) != currentVolumeKey) {
                continue;
            }

            const bool nameMatch =
                sameTextCi(current.filename, candidate.filename)
                || sameTextCi(current.filename, candidate.importOriginalFilename)
                || sameTextCi(current.importOriginalFilename, candidate.filename)
                || sameTextCi(current.importOriginalFilename, candidate.importOriginalFilename);

            const QString candidateStrictSignature = effectiveStrictSignature(candidate);
            const QString candidateLooseSignature = effectiveLooseSignature(candidate);
            const bool signatureMatch =
                !currentStrictSignature.isEmpty()
                && !candidateStrictSignature.isEmpty()
                && currentStrictSignature == candidateStrictSignature
                && !currentLooseSignature.isEmpty()
                && !candidateLooseSignature.isEmpty()
                && currentLooseSignature == candidateLooseSignature;

            if (!nameMatch && !signatureMatch) {
                continue;
            }

            duplicateIds.push_back(candidate.id);
        }
    }

    if (duplicateIds.isEmpty()) {
        db.close();
        return {};
    }

    QStringList placeholders;
    placeholders.reserve(duplicateIds.size());
    for (int i = 0; i < duplicateIds.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery deleteQuery(db);
    deleteQuery.prepare(
        QStringLiteral("DELETE FROM comics WHERE id IN (%1)").arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : duplicateIds) {
        deleteQuery.addBindValue(id);
    }
    if (!deleteQuery.exec()) {
        const QString error = QStringLiteral("Failed to remove stale restore duplicates: %1").arg(deleteQuery.lastError().text());
        db.close();
        return error;
    }

    db.close();

    for (int id : duplicateIds) {
        ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, id);
        m_readerArchivePathById.remove(id);
        m_readerImageEntriesById.remove(id);
        m_readerPageMetricsById.remove(id);
    }
    ComicReaderRequests::clearPendingImageRequestsForComics(
        m_pendingImageRequestIdsByKey,
        duplicateIds
    );

    return {};
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
    m_readerArchivePathById.insert(comicId, absoluteFilePath);
    m_readerImageEntriesById.remove(comicId);
    m_readerPageMetricsById.remove(comicId);
    ComicReaderRequests::clearPendingImageRequestsForComic(m_pendingImageRequestIdsByKey, comicId);
    requestIssueThumbnailAsync(comicId);

    m_lastMutationKind = QString("relink_issue_file_keep_metadata");
    emit statusChanged();
    return {};
}

QString ComicsListModel::deleteFileAtPath(const QString &filePath)
{
    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        return QString("File path is required.");
    }

    QFile file(normalizedPath);
    if (!file.exists()) {
        ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, normalizedPath);
        return {};
    }
    if (!file.remove()) {
        const DeleteFailureInfo failure = makeDeleteFailureInfo(normalizedPath, file.error(), file.errorString());
        return QString("Failed to remove file: %1\n%2")
            .arg(QDir::toNativeSeparators(QFileInfo(normalizedPath).absoluteFilePath()), formatDeleteFailureText(failure));
    }
    ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, normalizedPath);
    cleanupEmptyLibraryDirs(
        QDir(m_dataRoot).filePath(QStringLiteral("Library")),
        { QFileInfo(normalizedPath).absolutePath() }
    );
    return {};
}

QString ComicsListModel::deleteFileFingerprintHistoryEntries(const QVariantList &entryIds)
{
    QVector<int> ids;
    ids.reserve(entryIds.size());
    for (const QVariant &value : entryIds) {
        const int id = value.toInt();
        if (id > 0) {
            ids.push_back(id);
        }
    }
    if (ids.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_delete_fingerprint_history_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureFileFingerprintHistoryTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    QStringList placeholders;
    placeholders.reserve(ids.size());
    for (int i = 0; i < ids.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral("DELETE FROM file_fingerprint_history WHERE id IN (%1)")
            .arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : ids) {
        query.addBindValue(id);
    }
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to remove fingerprint history: %1").arg(query.lastError().text());
        db.close();
        return error;
    }

    db.close();
    return {};
}

QString ComicsListModel::deleteFileFingerprintHistoryForComicIds(const QVector<int> &comicIds)
{
    QVector<int> ids;
    ids.reserve(comicIds.size());
    for (int comicId : comicIds) {
        if (comicId > 0 && !ids.contains(comicId)) {
            ids.push_back(comicId);
        }
    }
    if (ids.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_delete_fingerprint_history_by_comic_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureFileFingerprintHistoryTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    QStringList placeholders;
    placeholders.reserve(ids.size());
    for (int i = 0; i < ids.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral("DELETE FROM file_fingerprint_history WHERE comic_id IN (%1)")
            .arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : ids) {
        query.addBindValue(id);
    }
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to remove fingerprint history: %1").arg(query.lastError().text());
        db.close();
        return error;
    }

    db.close();
    return {};
}

void ComicsListModel::updateReaderProgressCache(int comicId, int currentPage, const QString &readStatus)
{
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (row.id != comicId) continue;

        row.currentPage = currentPage;
        row.readStatus = readStatus;
        const QModelIndex index = this->index(rowIndex, 0);
        emit dataChanged(
            index,
            index,
            { ReadStatusRole, CurrentPageRole, DisplaySubtitleRole }
        );
        break;
    }
}

void ComicsListModel::updateReaderBookmarkCache(int comicId, int bookmarkPage)
{
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (row.id != comicId) continue;

        row.bookmarkPage = bookmarkPage;
        row.bookmarkAddedAt = bookmarkPage > 0
            ? QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"))
            : QString();
        const QModelIndex index = this->index(rowIndex, 0);
        emit dataChanged(
            index,
            index,
            { BookmarkPageRole, HasBookmarkRole }
        );
        break;
    }
}

void ComicsListModel::updateReaderFavoriteCache(int comicId, bool favoriteActive)
{
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (row.id != comicId) continue;

        row.favoriteActive = favoriteActive;
        row.favoriteAddedAt = favoriteActive
            ? QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"))
            : QString();
        const QModelIndex index = this->index(rowIndex, 0);
        emit dataChanged(
            index,
            index,
            { HasFavoriteRole }
        );
        break;
    }
}

QVariantMap ComicsListModel::exportComicInfoXml(int comicId)
{
    return ComicInfoOps::exportComicInfoXml(m_dbPath, comicId);
}

QString ComicsListModel::syncComicInfoToArchive(int comicId)
{
    return ComicInfoOps::syncComicInfoToArchive(m_dbPath, comicId);
}

QString ComicsListModel::importComicInfoFromArchive(int comicId, const QString &mode)
{
    const QVariantMap patch = ComicInfoOps::buildComicInfoImportPatch(m_dbPath, comicId, mode);
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

QVariantMap ComicsListModel::loadComicMetadata(int comicId) const
{
    QVariantMap values = ComicLibraryQueries::loadComicMetadata(m_dbPath, comicId);
    if (values.contains(QStringLiteral("error"))) {
        return values;
    }

    const int monthNumber = values.value(QStringLiteral("month")).toInt();
    values.insert(QStringLiteral("monthName"), monthNameForNumber(monthNumber));
    return values;
}

int ComicsListModel::requestComicVineAutofillAsync(const QVariantMap &seedValues)
{
    const int requestId = m_nextAsyncRequestId++;
    m_comicVineAutofillService->requestAutofillAsync(requestId, seedValues);
    return requestId;
}

QVariantMap ComicsListModel::requestComicVineAutofill(const QVariantMap &seedValues)
{
    return m_comicVineAutofillService->requestAutofillFromCache(seedValues);
}

QString ComicsListModel::configuredComicVineApiKey() const
{
    return m_comicVineAutofillService
        ? m_comicVineAutofillService->configuredApiKey()
        : QString();
}

QString ComicsListModel::saveComicVineApiKey(const QString &apiKey)
{
    return m_comicVineAutofillService
        ? m_comicVineAutofillService->saveApiKey(apiKey)
        : QStringLiteral("ComicVine service is unavailable.");
}

int ComicsListModel::requestComicVineApiKeyValidationAsync(const QString &apiKey)
{
    const int requestId = m_nextAsyncRequestId++;
    if (!m_comicVineAutofillService) {
        QMetaObject::invokeMethod(
            this,
            [this, requestId]() {
                emit comicVineApiKeyValidationFinished(requestId, {
                    { QStringLiteral("ok"), false },
                    { QStringLiteral("code"), QStringLiteral("service_unavailable") },
                    { QStringLiteral("error"), QStringLiteral("ComicVine service is unavailable.") }
                });
            },
            Qt::QueuedConnection
        );
        return requestId;
    }
    m_comicVineAutofillService->requestApiKeyValidationAsync(requestId, apiKey);
    return requestId;
}

QString ComicsListModel::deleteComic(int comicId)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString seriesKey = seriesGroupKeyForComicId(comicId);
    const bool deletingLastIssueInSeries = !seriesKey.isEmpty() && liveIssueCountForSeries(seriesKey) <= 1;
    if (deletingLastIssueInSeries) {
        const QString preserveError = preserveRetainedSeriesMetadata(seriesKey);
        if (!preserveError.isEmpty()) {
            return preserveError;
        }
        purgeSeriesHeroCacheForKey(seriesKey);
        ComicReaderCache::purgeSeriesHeaderOverridesForKey(m_dataRoot, seriesKey);
    }

    const QString preserveIssueError = preserveRetainedIssueMetadata(comicId);
    if (!preserveIssueError.isEmpty()) {
        return preserveIssueError;
    }

    const QString deleteError = deleteComicHard(comicId);
    if (!deleteError.isEmpty()) {
        return deleteError;
    }
    if (deletingLastIssueInSeries) {
        const QString historyCleanupError = deleteFileFingerprintHistoryForComicIds({ comicId });
        if (!historyCleanupError.isEmpty()) {
            return QStringLiteral("Issue was removed, but fingerprint history cleanup failed: %1").arg(historyCleanupError);
        }
    }

    return {};
}

QString ComicsListModel::deleteComicHard(int comicId)
{
    if (comicId < 1) return QString("Invalid issue id.");

    const QString seriesKey = seriesGroupKeyForComicId(comicId);

    QString filePath;
    QString removedDirPath;
    {
        const QString deleteError = ComicIssueFileOps::hardDeleteComicRecord(m_dbPath, comicId, filePath);
        if (!deleteError.isEmpty()) {
            return deleteError;
        }
    }

    QVector<FingerprintHistoryEntrySpec> fingerprintEntries;
    if (!filePath.isEmpty()) {
        FingerprintSnapshot deleteFingerprint;
        QString deleteFingerprintError;
        if (computeFileFingerprint(filePath, deleteFingerprint, deleteFingerprintError)) {
            appendFingerprintHistoryEntry(
                fingerprintEntries,
                comicId,
                seriesKey,
                QStringLiteral("delete_hard"),
                QStringLiteral("archive"),
                QStringLiteral("library"),
                deleteFingerprint,
                QFileInfo(filePath).fileName().trimmed()
            );
        }
    }

    QString deleteFileWarning;
    if (!filePath.isEmpty()) {
        QFile file(filePath);
        if (file.exists() && !file.remove()) {
            deleteFileWarning = QString("Issue removed from DB, but file delete failed: %1").arg(filePath);
        } else if (!filePath.trimmed().isEmpty()) {
            removedDirPath = QFileInfo(filePath).absolutePath();
        }
    }

    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);

    int removeIndex = -1;
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        if (m_rows.at(rowIndex).id == comicId) {
            removeIndex = rowIndex;
            break;
        }
    }
    if (removeIndex >= 0) {
        beginRemoveRows(QModelIndex(), removeIndex, removeIndex);
        m_rows.removeAt(removeIndex);
        endRemoveRows();
    }

    m_readerArchivePathById.remove(comicId);
    m_readerImageEntriesById.remove(comicId);
    m_readerPageMetricsById.remove(comicId);
    ComicReaderRequests::clearPendingImageRequestsForComic(m_pendingImageRequestIdsByKey, comicId);

    m_lastMutationKind = QString("delete_comic_hard");
    emit statusChanged();

    if (!removedDirPath.isEmpty()) {
        cleanupEmptyLibraryDirs(
            QDir(m_dataRoot).filePath(QStringLiteral("Library")),
            { removedDirPath }
        );
    }

    insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, nullptr);

    if (!deleteFileWarning.isEmpty()) {
        return deleteFileWarning;
    }
    return {};
}

QString ComicsListModel::normalizeSeriesKeyForLookup(const QString &value) const
{
    return normalizeSeriesKey(value);
}

QString ComicsListModel::groupTitleForKey(const QString &groupKey) const
{
    return makeGroupTitle(groupKey);
}

QVariantMap ComicsListModel::seriesMetadataForKey(const QString &seriesKey) const
{
    QVariantMap metadata = ComicLibraryQueries::seriesMetadataForKey(m_dbPath, seriesKey);
    const QString resolvedCoverPath = resolveStoredSeriesHeaderPath(
        m_dataRoot,
        valueFromMap(metadata, QStringLiteral("headerCoverPath"))
    );
    const QString resolvedBackgroundPath = resolveStoredSeriesHeaderPath(
        m_dataRoot,
        valueFromMap(metadata, QStringLiteral("headerBackgroundPath"))
    );
    metadata.insert(
        QStringLiteral("headerCoverPath"),
        resolvedCoverPath.isEmpty()
            ? QString()
            : QUrl::fromLocalFile(resolvedCoverPath).toString()
    );
    metadata.insert(
        QStringLiteral("headerBackgroundPath"),
        resolvedBackgroundPath.isEmpty()
            ? QString()
            : QUrl::fromLocalFile(resolvedBackgroundPath).toString()
    );
    return metadata;
}

QVariantMap ComicsListModel::seriesMetadataSuggestion(const QVariantMap &values, const QString &currentSeriesKey) const
{
    const QString seriesName = valueFromMap(values, QStringLiteral("series"));
    if (seriesName.isEmpty() || isWeakSeriesName(seriesName)) {
        return {};
    }

    const QString requestedVolume = valueFromMap(values, QStringLiteral("volume"));
    const QString requestedPublisher = valueFromMap(values, QStringLiteral("publisher"));
    const QString requestedYear = valueFromMap(values, QStringLiteral("year"));
    const QString requestedMonth = valueFromMap(values, QStringLiteral("month"));
    const QString requestedAgeRating = valueFromMap(values, QStringLiteral("ageRating"));
    const QString normalizedCurrentKey = currentSeriesKey.trimmed();

    const QVariantList candidates = ComicLibraryQueries::seriesMetadataCandidates(m_dbPath, seriesName);
    int bestScore = -1;
    int bestCount = 0;
    QVariantMap bestCandidate;

    for (const QVariant &candidateValue : candidates) {
        const QVariantMap candidate = candidateValue.toMap();
        const QString candidateKey = valueFromMap(candidate, QStringLiteral("seriesKey"));
        if (candidateKey.isEmpty() || candidateKey == normalizedCurrentKey) {
            continue;
        }

        const QString candidateVolume = valueFromMap(candidate, QStringLiteral("volume"));
        const QString candidatePublisher = valueFromMap(candidate, QStringLiteral("publisher"));
        const QString candidateYear = valueFromMap(candidate, QStringLiteral("year"));
        const QString candidateMonth = valueFromMap(candidate, QStringLiteral("month"));
        const QString candidateAgeRating = valueFromMap(candidate, QStringLiteral("ageRating"));

        if (optionalMetadataTextConflict(requestedVolume, candidateVolume)
            || optionalMetadataTextConflict(requestedPublisher, candidatePublisher)
            || optionalMetadataTextConflict(requestedYear, candidateYear)
            || optionalMetadataTextConflict(requestedMonth, candidateMonth)
            || optionalMetadataTextConflict(requestedAgeRating, candidateAgeRating)) {
            continue;
        }

        const int score =
            metadataTextMatchScore(requestedVolume, candidateVolume, 4)
            + metadataTextMatchScore(requestedPublisher, candidatePublisher, 3)
            + metadataTextMatchScore(requestedYear, candidateYear, 3)
            + metadataTextMatchScore(requestedMonth, candidateMonth, 2)
            + metadataTextMatchScore(requestedAgeRating, candidateAgeRating, 2);
        if (score < 1) {
            continue;
        }

        if (score > bestScore) {
            bestScore = score;
            bestCount = 1;
            bestCandidate = candidate;
        } else if (score == bestScore) {
            bestCount += 1;
        }
    }

    if (bestScore < 1 || bestCount != 1) {
        return {};
    }

    QVariantMap patch;
    const QString currentSeriesTitle = valueFromMap(values, QStringLiteral("seriesTitle"));
    const QString currentSummary = valueFromMap(values, QStringLiteral("summary"));
    const QString currentGenres = valueFromMap(values, QStringLiteral("genres"));
    if (currentSeriesTitle.isEmpty()) {
        const QString storedSeriesTitle = valueFromMap(bestCandidate, QStringLiteral("seriesTitle"));
        if (!storedSeriesTitle.isEmpty()) patch.insert(QStringLiteral("seriesTitle"), storedSeriesTitle);
    }
    if (currentSummary.isEmpty()) {
        const QString storedSummary = valueFromMap(bestCandidate, QStringLiteral("summary"));
        if (!storedSummary.isEmpty()) patch.insert(QStringLiteral("summary"), storedSummary);
    }
    if (requestedYear.isEmpty()) {
        const QString storedYear = valueFromMap(bestCandidate, QStringLiteral("year"));
        if (!storedYear.isEmpty()) patch.insert(QStringLiteral("year"), storedYear);
    }
    if (requestedMonth.isEmpty()) {
        const QString storedMonth = valueFromMap(bestCandidate, QStringLiteral("month"));
        if (!storedMonth.isEmpty()) patch.insert(QStringLiteral("month"), storedMonth);
    }
    if (currentGenres.isEmpty()) {
        const QString storedGenres = valueFromMap(bestCandidate, QStringLiteral("genres"));
        if (!storedGenres.isEmpty()) patch.insert(QStringLiteral("genres"), storedGenres);
    }
    if (requestedVolume.isEmpty()) {
        const QString storedVolume = valueFromMap(bestCandidate, QStringLiteral("volume"));
        if (!storedVolume.isEmpty()) patch.insert(QStringLiteral("volume"), storedVolume);
    }
    if (requestedPublisher.isEmpty()) {
        const QString storedPublisher = valueFromMap(bestCandidate, QStringLiteral("publisher"));
        if (!storedPublisher.isEmpty()) patch.insert(QStringLiteral("publisher"), storedPublisher);
    }
    if (requestedAgeRating.isEmpty()) {
        const QString storedAgeRating = valueFromMap(bestCandidate, QStringLiteral("ageRating"));
        if (!storedAgeRating.isEmpty()) patch.insert(QStringLiteral("ageRating"), storedAgeRating);
    }

    if (patch.isEmpty()) {
        return {};
    }

    return {
        { QStringLiteral("targetKey"), valueFromMap(bestCandidate, QStringLiteral("seriesKey")) },
        { QStringLiteral("displayTitle"), valueFromMap(bestCandidate, QStringLiteral("seriesTitle")) },
        { QStringLiteral("patch"), patch }
    };
}

QString ComicsListModel::setSeriesMetadataForKey(const QString &seriesKey, const QVariantMap &values)
{
    const QString writeError = ComicLibraryQueries::setSeriesMetadataForKey(m_dbPath, seriesKey, values);
    if (!writeError.isEmpty()) {
        return writeError;
    }

    m_lastMutationKind = QString("series_metadata_update");
    emit statusChanged();
    return {};
}

QVariantMap ComicsListModel::issueMetadataSuggestion(const QVariantMap &values, int currentComicId) const
{
    Q_UNUSED(currentComicId);

    const QString seriesName = valueFromMap(values, QStringLiteral("series"));
    const QString issueNumber = valueFromMap(values, QStringLiteral("issueNumber"));
    if (seriesName.isEmpty() || isWeakSeriesName(seriesName) || normalizeIssueKey(issueNumber).isEmpty()) {
        return {};
    }

    const QString requestedVolume = valueFromMap(values, QStringLiteral("volume"));
    const QString requestedTitle = valueFromMap(values, QStringLiteral("title"));
    const QString requestedPublisher = valueFromMap(values, QStringLiteral("publisher"));
    const QString requestedYear = valueFromMap(values, QStringLiteral("year"));
    const QString requestedMonth = valueFromMap(values, QStringLiteral("month"));
    const QString requestedAgeRating = valueFromMap(values, QStringLiteral("ageRating"));

    const QVariantList candidates = ComicLibraryQueries::issueMetadataKnowledgeCandidates(
        m_dbPath,
        seriesName,
        issueNumber
    );
    if (candidates.isEmpty()) {
        return {};
    }

    int bestScore = -1;
    int bestCount = 0;
    QVariantMap bestCandidate;

    for (const QVariant &candidateValue : candidates) {
        const QVariantMap candidate = candidateValue.toMap();
        const QString candidateVolume = valueFromMap(candidate, QStringLiteral("volume"));
        const QString candidateTitle = valueFromMap(candidate, QStringLiteral("title"));
        const QString candidatePublisher = valueFromMap(candidate, QStringLiteral("publisher"));
        const QString candidateYear = valueFromMap(candidate, QStringLiteral("year"));
        const QString candidateMonth = valueFromMap(candidate, QStringLiteral("month"));
        const QString candidateAgeRating = valueFromMap(candidate, QStringLiteral("ageRating"));

        if (optionalMetadataTextConflict(requestedVolume, candidateVolume)
            || optionalMetadataTextConflict(requestedTitle, candidateTitle)
            || optionalMetadataTextConflict(requestedPublisher, candidatePublisher)
            || optionalMetadataTextConflict(requestedYear, candidateYear)
            || optionalMetadataTextConflict(requestedMonth, candidateMonth)
            || optionalMetadataTextConflict(requestedAgeRating, candidateAgeRating)) {
            continue;
        }

        int score =
            metadataTextMatchScore(requestedVolume, candidateVolume, 4)
            + metadataTextMatchScore(requestedTitle, candidateTitle, 3)
            + metadataTextMatchScore(requestedPublisher, candidatePublisher, 3)
            + metadataTextMatchScore(requestedYear, candidateYear, 2)
            + metadataTextMatchScore(requestedMonth, candidateMonth, 1)
            + metadataTextMatchScore(requestedAgeRating, candidateAgeRating, 1);
        if (score < 1 && candidates.size() > 1) {
            continue;
        }

        if (score > bestScore) {
            bestScore = score;
            bestCount = 1;
            bestCandidate = candidate;
        } else if (score == bestScore) {
            bestCount += 1;
        }
    }

    if (bestCount != 1 || bestCandidate.isEmpty()) {
        return {};
    }

    QVariantMap patch;
    const auto applyIfBlank = [&](const QString &fieldKey) {
        if (!valueFromMap(values, fieldKey).isEmpty()) {
            return;
        }
        const QString storedValue = valueFromMap(bestCandidate, fieldKey);
        if (!storedValue.isEmpty()) {
            patch.insert(fieldKey, storedValue);
        }
    };

    applyIfBlank(QStringLiteral("volume"));
    applyIfBlank(QStringLiteral("title"));
    applyIfBlank(QStringLiteral("publisher"));
    applyIfBlank(QStringLiteral("year"));
    applyIfBlank(QStringLiteral("month"));
    applyIfBlank(QStringLiteral("ageRating"));
    applyIfBlank(QStringLiteral("writer"));
    applyIfBlank(QStringLiteral("penciller"));
    applyIfBlank(QStringLiteral("inker"));
    applyIfBlank(QStringLiteral("colorist"));
    applyIfBlank(QStringLiteral("letterer"));
    applyIfBlank(QStringLiteral("coverArtist"));
    applyIfBlank(QStringLiteral("editor"));
    applyIfBlank(QStringLiteral("storyArc"));
    applyIfBlank(QStringLiteral("characters"));

    if (patch.isEmpty()) {
        return {};
    }

    return {
        { QStringLiteral("seriesKey"), valueFromMap(bestCandidate, QStringLiteral("seriesKey")) },
        { QStringLiteral("displayTitle"), valueFromMap(bestCandidate, QStringLiteral("seriesTitle")) },
        { QStringLiteral("issueNumber"), valueFromMap(bestCandidate, QStringLiteral("issueNumber")) },
        { QStringLiteral("patch"), patch }
    };
}

QVariantMap ComicsListModel::saveSeriesHeaderImages(
    const QString &seriesKey,
    const QString &coverSourcePath,
    const QString &backgroundSourcePath
)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);

    const QString key = seriesKey.trimmed();
    if (key.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Series key is required."));
        return result;
    }

    const QVariantMap currentMetadata = ComicLibraryQueries::seriesMetadataForKey(m_dbPath, key);
    const QString currentCoverStored = valueFromMap(currentMetadata, QStringLiteral("headerCoverPath"));
    const QString currentBackgroundStored = valueFromMap(currentMetadata, QStringLiteral("headerBackgroundPath"));
    const QString currentCoverPath = resolveStoredSeriesHeaderPath(m_dataRoot, currentCoverStored);
    const QString currentBackgroundPath = resolveStoredSeriesHeaderPath(m_dataRoot, currentBackgroundStored);

    const QString desiredCoverPath = normalizeInputFilePath(coverSourcePath);
    const QString desiredBackgroundPath = normalizeInputFilePath(backgroundSourcePath);
    const QByteArray preferredFormat = ComicReaderCache::preferredThumbnailFormat();
    const QString preferredExtension = QString::fromLatin1(preferredFormat);
    const QString normalizedCoverTargetPath = ComicReaderCache::buildSeriesHeaderOverridePath(
        m_dataRoot,
        key,
        QStringLiteral("cover"),
        preferredExtension
    );
    const QString normalizedBackgroundTargetPath = ComicReaderCache::buildSeriesHeaderOverridePath(
        m_dataRoot,
        key,
        QStringLiteral("background"),
        preferredExtension
    );
    const bool coverNeedsWrite = !desiredCoverPath.isEmpty()
        && (
            desiredCoverPath.compare(currentCoverPath, Qt::CaseInsensitive) != 0
            || currentCoverPath.compare(normalizedCoverTargetPath, Qt::CaseInsensitive) != 0
        );
    const bool backgroundNeedsWrite = !desiredBackgroundPath.isEmpty()
        && (
            desiredBackgroundPath.compare(currentBackgroundPath, Qt::CaseInsensitive) != 0
            || currentBackgroundPath.compare(normalizedBackgroundTargetPath, Qt::CaseInsensitive) != 0
        );

    QImage decodedCoverImage;
    if (coverNeedsWrite) {
        QString coverValidationError;
        if (!ComicImagePreparation::loadReadableImageFile(desiredCoverPath, decodedCoverImage, coverValidationError)) {
            result.insert(QStringLiteral("error"), coverValidationError);
            return result;
        }
    }

    QImage decodedBackgroundImage;
    if (backgroundNeedsWrite) {
        QString backgroundValidationError;
        if (!ComicImagePreparation::loadReadableImageFile(desiredBackgroundPath, decodedBackgroundImage, backgroundValidationError)) {
            result.insert(QStringLiteral("error"), backgroundValidationError);
            return result;
        }
    }

    QString nextCoverStored = currentCoverStored;
    QString nextBackgroundStored = currentBackgroundStored;
    QString nextCoverPath = currentCoverPath;
    QString nextBackgroundPath = currentBackgroundPath;

    if (desiredCoverPath.isEmpty()) {
        ComicReaderCache::purgeSeriesHeaderOverrideSlotForKey(m_dataRoot, key, QStringLiteral("cover"));
        nextCoverStored.clear();
        nextCoverPath.clear();
    } else if (coverNeedsWrite) {
        QString coverWriteError;
        if (!ComicImagePreparation::writeThumbnailImage(decodedCoverImage, normalizedCoverTargetPath, preferredFormat, coverWriteError)) {
            if (coverWriteError.isEmpty()) {
                coverWriteError = QStringLiteral("Failed to save custom cover image.");
            }
            result.insert(QStringLiteral("error"), coverWriteError);
            return result;
        }
        nextCoverPath = QDir::toNativeSeparators(QFileInfo(normalizedCoverTargetPath).absoluteFilePath());
        ComicReaderCache::pruneSeriesHeaderOverrideVariantsForKey(
            m_dataRoot,
            key,
            QStringLiteral("cover"),
            nextCoverPath
        );
        nextCoverStored = relativePathWithinDataRoot(m_dataRoot, nextCoverPath);
    }

    if (desiredBackgroundPath.isEmpty()) {
        ComicReaderCache::purgeSeriesHeaderOverrideSlotForKey(m_dataRoot, key, QStringLiteral("background"));
        nextBackgroundStored.clear();
        nextBackgroundPath.clear();
    } else if (backgroundNeedsWrite) {
        QString backgroundWriteError;
        if (!ComicImagePreparation::writeSeriesHeaderBackgroundImage(decodedBackgroundImage, normalizedBackgroundTargetPath, preferredFormat, backgroundWriteError)) {
            if (backgroundWriteError.isEmpty()) {
                backgroundWriteError = QStringLiteral("Failed to save custom background image.");
            }
            result.insert(QStringLiteral("error"), backgroundWriteError);
            return result;
        }
        nextBackgroundPath = QDir::toNativeSeparators(QFileInfo(normalizedBackgroundTargetPath).absoluteFilePath());
        ComicReaderCache::pruneSeriesHeaderOverrideVariantsForKey(
            m_dataRoot,
            key,
            QStringLiteral("background"),
            nextBackgroundPath
        );
        nextBackgroundStored = relativePathWithinDataRoot(m_dataRoot, nextBackgroundPath);
    }

    const QString writeError = ComicLibraryQueries::setSeriesMetadataForKey(m_dbPath, key, {
        { QStringLiteral("headerCoverPath"), nextCoverStored },
        { QStringLiteral("headerBackgroundPath"), nextBackgroundStored }
    });
    if (!writeError.isEmpty()) {
        result.insert(QStringLiteral("error"), writeError);
        return result;
    }

    m_lastMutationKind = QStringLiteral("series_header_update");
    emit statusChanged();
    result.insert(QStringLiteral("ok"), true);
    result.insert(
        QStringLiteral("coverPath"),
        nextCoverPath.isEmpty() ? QString() : QUrl::fromLocalFile(nextCoverPath).toString()
    );
    result.insert(
        QStringLiteral("backgroundPath"),
        nextBackgroundPath.isEmpty() ? QString() : QUrl::fromLocalFile(nextBackgroundPath).toString()
    );
    return result;
}

QString ComicsListModel::removeSeriesMetadataForKey(const QString &seriesKey)
{
    const QString writeError = ComicLibraryQueries::removeSeriesMetadataForKey(m_dbPath, seriesKey);
    if (!writeError.isEmpty()) {
        return writeError;
    }

    purgeSeriesHeroCacheForKey(seriesKey);
    ComicReaderCache::purgeSeriesHeaderOverridesForKey(m_dataRoot, seriesKey);
    m_lastMutationKind = QString("series_metadata_update");
    emit statusChanged();
    return {};
}

QString ComicsListModel::seriesSummaryForKey(const QString &seriesKey) const
{
    return valueFromMap(seriesMetadataForKey(seriesKey), QStringLiteral("summary"));
}

QString ComicsListModel::setSeriesSummaryForKey(const QString &seriesKey, const QString &summary)
{
    return setSeriesMetadataForKey(seriesKey, {
        { QStringLiteral("summary"), summary.trimmed() }
    });
}

QString ComicsListModel::removeSeriesSummaryForKey(const QString &seriesKey)
{
    return setSeriesMetadataForKey(seriesKey, {
        { QStringLiteral("summary"), QString() }
    });
}

bool ComicsListModel::openDatabaseConnection(QSqlDatabase &db, const QString &connectionName, QString &errorText) const
{
    db = QSqlDatabase::addDatabase("QSQLITE", connectionName);
    db.setDatabaseName(m_dbPath);
    if (db.open()) return true;

    errorText = QString("Failed to open DB: %1").arg(db.lastError().text());
    return false;
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
    const QString configuredOverride = configuredDataRootOverridePath();
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
