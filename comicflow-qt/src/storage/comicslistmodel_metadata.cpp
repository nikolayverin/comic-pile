#include <algorithm>

#include "storage/comicslistmodel.h"

#include "storage/comicsmodelutils.h"
#include "storage/imagepreparationops.h"
#include "storage/importmatching.h"
#include "storage/librarymutationops.h"
#include "storage/libraryqueryops.h"
#include "storage/readercacheutils.h"
#include "storage/storedpathutils.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QUrl>

namespace {

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

bool isWeakSeriesName(const QString &seriesName)
{
    return ComicImportMatching::isWeakSeriesName(seriesName);
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

QString resolveStoredSeriesHeaderPath(const QString &dataRoot, const QString &storedPath)
{
    return ComicStoragePaths::resolveStoredPathAgainstRoot(dataRoot, storedPath);
}

QString relativePathWithinDataRoot(const QString &dataRoot, const QString &absolutePath)
{
    return ComicStoragePaths::persistPathForDataRoot(dataRoot, absolutePath);
}

QString normalizeInputFilePath(const QString &rawInput)
{
    return ComicStoragePaths::normalizePathInput(rawInput);
}

QString libraryBackgroundStoreDirPath(const QString &dataRoot)
{
    return QDir(dataRoot).filePath(QStringLiteral("Backgrounds/Library"));
}

QString libraryBackgroundStoreFileBaseName()
{
    return QStringLiteral("custom-image");
}

QString sanitizeManagedImageExtension(const QString &input)
{
    QString extension = input.trimmed().toLower();
    extension.remove(QRegularExpression(QStringLiteral("[^a-z0-9]")));
    if (extension.isEmpty()) {
        return QStringLiteral("png");
    }
    return extension;
}

QString libraryBackgroundStoreFilePath(const QString &dataRoot, const QString &extension)
{
    return QDir(libraryBackgroundStoreDirPath(dataRoot)).filePath(
        QStringLiteral("%1.%2").arg(libraryBackgroundStoreFileBaseName(), sanitizeManagedImageExtension(extension))
    );
}

void pruneLibraryBackgroundStoreVariants(const QString &dataRoot, const QString &keepAbsolutePath)
{
    const QDir storeDir(libraryBackgroundStoreDirPath(dataRoot));
    if (!storeDir.exists()) {
        return;
    }

    const QString keepFileName = QFileInfo(QDir::fromNativeSeparators(keepAbsolutePath)).fileName();
    const QFileInfoList variants = storeDir.entryInfoList(
        { QStringLiteral("%1.*").arg(libraryBackgroundStoreFileBaseName()) },
        QDir::Files | QDir::NoSymLinks
    );
    for (const QFileInfo &variantInfo : variants) {
        if (!keepFileName.isEmpty()
            && variantInfo.fileName().compare(keepFileName, Qt::CaseInsensitive) == 0) {
            continue;
        }
        QFile::remove(variantInfo.absoluteFilePath());
    }
}

bool copyFileToManagedStorage(const QString &sourcePath, const QString &targetPath, QString &errorText)
{
    errorText.clear();

    if (!ComicReaderCache::ensureDirForFile(targetPath)) {
        errorText = QStringLiteral("Failed to create the library background storage folder.");
        return false;
    }

    QFile sourceFile(sourcePath);
    if (!sourceFile.open(QIODevice::ReadOnly)) {
        errorText = QStringLiteral("Failed to open the selected background image.");
        return false;
    }

    QSaveFile targetFile(targetPath);
    if (!targetFile.open(QIODevice::WriteOnly)) {
        errorText = QStringLiteral("Failed to open the managed background image file for writing.");
        return false;
    }

    while (!sourceFile.atEnd()) {
        const QByteArray chunk = sourceFile.read(64 * 1024);
        if (chunk.isEmpty() && sourceFile.error() != QFile::NoError) {
            targetFile.cancelWriting();
            errorText = QStringLiteral("Failed to read the selected background image.");
            return false;
        }
        if (!chunk.isEmpty() && targetFile.write(chunk) != chunk.size()) {
            targetFile.cancelWriting();
            errorText = QStringLiteral("Failed to save the managed background image.");
            return false;
        }
    }

    if (!targetFile.commit()) {
        errorText = QStringLiteral("Failed to finalize the managed background image.");
        return false;
    }

    return true;
}

QString formatSeriesGroupTitle(const QString &series, const QString &volume)
{
    const QString baseTitle = series.trimmed().isEmpty()
        ? QStringLiteral("Unknown Series")
        : series.trimmed();

    QString volumeText = volume.trimmed();
    if (volumeText.isEmpty()) return baseTitle;

    volumeText.remove(QRegularExpression(
        QStringLiteral("^vol(?:ume)?\\.?\\s*"),
        QRegularExpression::CaseInsensitiveOption
    ));
    volumeText = volumeText.trimmed();
    if (volumeText.isEmpty()) {
        volumeText = volume.trimmed();
    }

    return QStringLiteral("%1 - Vol. %2").arg(baseTitle, volumeText);
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

} // namespace

QString ComicsListModel::updateComicMetadata(
    int comicId,
    const QVariantMap &values
)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

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
        return QStringLiteral("No metadata fields to update.");
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
    if (ids.isEmpty()) return QStringLiteral("No issues selected.");

    ComicLibraryMutationOps::BulkMetadataUpdatePlan plan;
    plan.ids = ids;
    plan.applySeries = boolFromMap(applyMap, QStringLiteral("series"));
    plan.applyVolume = boolFromMap(applyMap, QStringLiteral("volume"));
    plan.applyTitle = boolFromMap(applyMap, QStringLiteral("title"));
    plan.applyIssueNumber =
        boolFromMap(applyMap, QStringLiteral("issueNumber"))
        || boolFromMap(applyMap, QStringLiteral("issue"));
    plan.applyPublisher = boolFromMap(applyMap, QStringLiteral("publisher"));
    plan.applyYear = boolFromMap(applyMap, QStringLiteral("year"));
    plan.applyMonth = boolFromMap(applyMap, QStringLiteral("month"));
    plan.applyWriter = boolFromMap(applyMap, QStringLiteral("writer"));
    plan.applyPenciller = boolFromMap(applyMap, QStringLiteral("penciller"));
    plan.applyInker = boolFromMap(applyMap, QStringLiteral("inker"));
    plan.applyColorist = boolFromMap(applyMap, QStringLiteral("colorist"));
    plan.applyLetterer = boolFromMap(applyMap, QStringLiteral("letterer"));
    plan.applyCoverArtist =
        boolFromMap(applyMap, QStringLiteral("coverArtist"))
        || boolFromMap(applyMap, QStringLiteral("cover_artist"));
    plan.applyEditor = boolFromMap(applyMap, QStringLiteral("editor"));
    plan.applyStoryArc =
        boolFromMap(applyMap, QStringLiteral("storyArc"))
        || boolFromMap(applyMap, QStringLiteral("story_arc"));
    plan.applySummary = boolFromMap(applyMap, QStringLiteral("summary"));
    plan.applyCharacters = boolFromMap(applyMap, QStringLiteral("characters"));
    plan.applyGenres = boolFromMap(applyMap, QStringLiteral("genres"));
    plan.applyAgeRating =
        boolFromMap(applyMap, QStringLiteral("ageRating"))
        || boolFromMap(applyMap, QStringLiteral("age_rating"));
    plan.applyReadStatus =
        boolFromMap(applyMap, QStringLiteral("readStatus"))
        || boolFromMap(applyMap, QStringLiteral("read_status"));
    plan.applyCurrentPage =
        boolFromMap(applyMap, QStringLiteral("currentPage"))
        || boolFromMap(applyMap, QStringLiteral("current_page"));

    plan.series = valueFromMap(values, QStringLiteral("series"));
    plan.volume = valueFromMap(values, QStringLiteral("volume"));
    plan.title = valueFromMap(values, QStringLiteral("title"));
    plan.issueNumber = ComicImportMatching::normalizeStoredIssueNumber(
        valueFromMap(values, QStringLiteral("issueNumber"), QStringLiteral("issue"))
    );
    plan.publisher = valueFromMap(values, QStringLiteral("publisher"));
    plan.writer = valueFromMap(values, QStringLiteral("writer"));
    plan.penciller = valueFromMap(values, QStringLiteral("penciller"));
    plan.inker = valueFromMap(values, QStringLiteral("inker"));
    plan.colorist = valueFromMap(values, QStringLiteral("colorist"));
    plan.letterer = valueFromMap(values, QStringLiteral("letterer"));
    plan.coverArtist = valueFromMap(values, QStringLiteral("coverArtist"), QStringLiteral("cover_artist"));
    plan.editor = valueFromMap(values, QStringLiteral("editor"));
    plan.storyArc = valueFromMap(values, QStringLiteral("storyArc"), QStringLiteral("story_arc"));
    plan.summary = valueFromMap(values, QStringLiteral("summary"));
    plan.characters = valueFromMap(values, QStringLiteral("characters"));
    plan.genres = valueFromMap(values, QStringLiteral("genres"));
    plan.ageRating = valueFromMap(values, QStringLiteral("ageRating"), QStringLiteral("age_rating"));

    const QString yearInput = valueFromMap(values, QStringLiteral("year"));
    bool yearOk = false;
    plan.parsedYear = parseOptionalYear(yearInput, yearOk, plan.yearIsNull);
    if (plan.applyYear && !yearOk) {
        return QStringLiteral("Year must be empty or an integer between 0 and 9999.");
    }

    const QString monthInput = valueFromMap(values, QStringLiteral("month"));
    bool monthOk = false;
    plan.parsedMonth = parseOptionalMonth(monthInput, monthOk, plan.monthIsNull);
    if (plan.applyMonth && !monthOk) {
        return QStringLiteral("Month must be empty or an integer between 1 and 12.");
    }

    const QString readStatusInput = valueFromMap(values, QStringLiteral("readStatus"), QStringLiteral("read_status"));
    plan.readStatus = ComicModelUtils::normalizeReadStatus(readStatusInput);
    if (plan.applyReadStatus && !readStatusInput.isEmpty() && plan.readStatus.isEmpty()) {
        return QStringLiteral("Read status must be one of: unread, in_progress, read.");
    }

    const QString currentPageInput = valueFromMap(values, QStringLiteral("currentPage"), QStringLiteral("current_page"));
    bool currentPageOk = false;
    plan.parsedCurrentPage = parseOptionalCurrentPage(currentPageInput, currentPageOk, plan.currentPageIsNull);
    if (plan.applyCurrentPage && !currentPageOk) {
        return QStringLiteral("Current page must be empty or an integer between 0 and 1000000.");
    }

    QVector<ComicLibraryMutationOps::BulkMetadataRuntimeRow> runtimeRows;
    runtimeRows.reserve(m_rows.size());
    for (const ComicRow &row : m_rows) {
        runtimeRows.push_back({ row.id, row.filePath, row.series });
    }

    const ComicLibraryMutationOps::BulkMetadataUpdateOutcome outcome =
        ComicLibraryMutationOps::applyBulkMetadataUpdate(
            m_dbPath,
            m_dataRoot,
            runtimeRows,
            plan
        );
    if (!outcome.ok()) {
        return outcome.error;
    }

    for (const QString &seriesKey : outcome.seriesHeroKeysToPurge) {
        purgeSeriesHeroCacheForKey(seriesKey);
    }

    bool updatedInMemory = false;
    QVector<int> updatedIndices;
    updatedIndices.reserve(ids.size());
    QSet<int> idSet;
    idSet.reserve(ids.size());
    for (int id : ids) {
        idSet.insert(id);
    }

    const bool sortSensitiveFieldsChanged =
        plan.applySeries
        || plan.applyVolume
        || plan.applyIssueNumber
        || plan.applyTitle
        || (m_sortMode == QStringLiteral("year_desc") && (plan.applyYear || plan.applyMonth));

    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        ComicRow &row = m_rows[rowIndex];
        if (!idSet.contains(row.id)) continue;

        if (plan.applySeries) {
            row.series = plan.series;
        }
        if (outcome.movedPathById.contains(row.id)) {
            row.filePath = outcome.movedPathById.value(row.id);
            const QString movedFilename = outcome.movedFilenameById.value(row.id);
            if (!movedFilename.isEmpty()) {
                row.filename = movedFilename;
            }
        }
        if (plan.applyVolume) {
            row.volume = plan.volume;
            row.volumeGroupKey = ComicModelUtils::normalizeVolumeKey(row.volume);
        }
        if (plan.applySeries || plan.applyVolume) {
            const QString normalizedSeriesKey = ComicModelUtils::normalizeSeriesKey(row.series);
            if (row.volumeGroupKey == QStringLiteral("__no_volume__")) {
                row.seriesGroupKey = normalizedSeriesKey;
            } else {
                row.seriesGroupKey = QStringLiteral("%1::vol::%2").arg(normalizedSeriesKey, row.volumeGroupKey);
            }
            row.seriesGroupTitle = formatSeriesGroupTitle(row.series, row.volume);
        }
        if (plan.applyTitle) row.title = plan.title;
        if (plan.applyIssueNumber) row.issueNumber = plan.issueNumber;
        if (plan.applyPublisher) row.publisher = plan.publisher;
        if (plan.applyYear) row.year = plan.yearIsNull ? 0 : plan.parsedYear;
        if (plan.applyMonth) row.month = plan.monthIsNull ? 0 : plan.parsedMonth;
        if (plan.applyWriter) row.writer = plan.writer;
        if (plan.applyPenciller) row.penciller = plan.penciller;
        if (plan.applyInker) row.inker = plan.inker;
        if (plan.applyColorist) row.colorist = plan.colorist;
        if (plan.applyLetterer) row.letterer = plan.letterer;
        if (plan.applyCoverArtist) row.coverArtist = plan.coverArtist;
        if (plan.applyEditor) row.editor = plan.editor;
        if (plan.applyStoryArc) row.storyArc = plan.storyArc;
        if (plan.applySummary) row.summary = plan.summary;
        if (plan.applyCharacters) row.characters = plan.characters;
        if (plan.applyGenres) row.genres = plan.genres;
        if (plan.applyAgeRating) row.ageRating = plan.ageRating;
        if (plan.applyReadStatus) row.readStatus = plan.readStatus.isEmpty() ? QStringLiteral("unread") : plan.readStatus;
        if (plan.applyCurrentPage) row.currentPage = plan.currentPageIsNull ? 0 : plan.parsedCurrentPage;
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

    m_lastMutationKind = QStringLiteral("bulk_update_metadata");
    emit statusChanged();
    return {};
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
        const QString groupTitle = ComicModelUtils::makeGroupTitle(normalizedKey).trimmed();
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
        return ComicLibraryMutationOps::setSeriesMetadataForKey(m_dbPath, normalizedKey, {
            { QStringLiteral("headerCoverPath"), QString() },
            { QStringLiteral("headerBackgroundPath"), QString() }
        });
    }
    QVariantMap valuesToPersist = retainedValues;
    valuesToPersist.insert(QStringLiteral("headerCoverPath"), QString());
    valuesToPersist.insert(QStringLiteral("headerBackgroundPath"), QString());
    return ComicLibraryMutationOps::setSeriesMetadataForKey(m_dbPath, normalizedKey, valuesToPersist);
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
    return ComicLibraryMutationOps::setIssueMetadataKnowledge(m_dbPath, retainedValues);
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

QString ComicsListModel::normalizeSeriesKeyForLookup(const QString &value) const
{
    return ComicModelUtils::normalizeSeriesKey(value);
}

QString ComicsListModel::groupTitleForKey(const QString &groupKey) const
{
    return ComicModelUtils::makeGroupTitle(groupKey);
}

QVariantMap ComicsListModel::seriesImportContext(const QString &seriesKey) const
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) {
        return {};
    }

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != normalizedKey) {
            continue;
        }

        return {
            { QStringLiteral("series"), row.series.trimmed() },
            { QStringLiteral("volume"), row.volume.trimmed() },
            { QStringLiteral("seriesKey"), row.seriesGroupKey.trimmed() },
            { QStringLiteral("seriesTitle"), row.seriesGroupTitle.trimmed() }
        };
    }

    return {};
}

QVariantMap ComicsListModel::seriesAddIssueContext(const QString &seriesKey) const
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) {
        return {};
    }

    const QVariantMap importContext = seriesImportContext(normalizedKey);
    const QVariantMap retainedMetadata = buildRetainedSeriesMetadata(normalizedKey);

    const QString targetSeries = valueFromMap(importContext, QStringLiteral("series")).isEmpty()
        ? valueFromMap(retainedMetadata, QStringLiteral("seriesTitle"))
        : valueFromMap(importContext, QStringLiteral("series"));
    const QString targetVolume = valueFromMap(importContext, QStringLiteral("volume")).isEmpty()
        ? valueFromMap(retainedMetadata, QStringLiteral("volume"))
        : valueFromMap(importContext, QStringLiteral("volume"));

    QVariantMap result;
    if (!targetSeries.isEmpty()) result.insert(QStringLiteral("series"), targetSeries);
    if (!targetVolume.isEmpty()) result.insert(QStringLiteral("volume"), targetVolume);

    const QString contextSeriesKey = valueFromMap(importContext, QStringLiteral("seriesKey"));
    if (!contextSeriesKey.isEmpty()) result.insert(QStringLiteral("seriesKey"), contextSeriesKey);

    const QString contextSeriesTitle = valueFromMap(importContext, QStringLiteral("seriesTitle"));
    if (!contextSeriesTitle.isEmpty()) result.insert(QStringLiteral("seriesTitle"), contextSeriesTitle);

    const QString publisher = valueFromMap(retainedMetadata, QStringLiteral("publisher"));
    const QString year = valueFromMap(retainedMetadata, QStringLiteral("year"));
    const QString month = valueFromMap(retainedMetadata, QStringLiteral("month"));
    const QString ageRating = valueFromMap(retainedMetadata, QStringLiteral("ageRating"));

    if (!publisher.isEmpty()) result.insert(QStringLiteral("publisher"), publisher);
    if (!year.isEmpty()) result.insert(QStringLiteral("year"), year);
    if (!month.isEmpty()) result.insert(QStringLiteral("month"), month);
    if (!ageRating.isEmpty()) result.insert(QStringLiteral("ageRating"), ageRating);

    return result;
}

QVariantMap ComicsListModel::retainedSeriesMetadataForKey(const QString &seriesKey) const
{
    return buildRetainedSeriesMetadata(seriesKey.trimmed());
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

QString ComicsListModel::resolveStoredPathAgainstDataRoot(const QString &storedPath) const
{
    return ComicStoragePaths::resolveStoredPathAgainstRoot(m_dataRoot, storedPath);
}

QVariantMap ComicsListModel::storeLibraryBackgroundImage(const QString &sourcePath)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);

    const QString normalizedSourcePath = normalizeInputFilePath(sourcePath);
    const QString absoluteSourcePath = ComicStoragePaths::absoluteExistingFilePath(normalizedSourcePath);
    if (absoluteSourcePath.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("Selected background image is unavailable."));
        return result;
    }

    QImage decodedImage;
    QString validationError;
    if (!ComicImagePreparation::loadReadableImageFile(absoluteSourcePath, decodedImage, validationError)) {
        result.insert(QStringLiteral("error"), validationError);
        return result;
    }
    Q_UNUSED(decodedImage);

    QImageReader formatReader(absoluteSourcePath);
    QString extension = QFileInfo(absoluteSourcePath).suffix().trimmed().toLower();
    if (extension.isEmpty()) {
        extension = QString::fromLatin1(formatReader.format()).trimmed().toLower();
    }
    extension = sanitizeManagedImageExtension(extension);

    const QString targetPath = QDir::toNativeSeparators(
        QFileInfo(libraryBackgroundStoreFilePath(m_dataRoot, extension)).absoluteFilePath()
    );
    const bool sameFile = absoluteSourcePath.compare(targetPath, Qt::CaseInsensitive) == 0;

    if (!sameFile) {
        QString copyError;
        if (!copyFileToManagedStorage(absoluteSourcePath, targetPath, copyError)) {
            if (copyError.isEmpty()) {
                copyError = QStringLiteral("Failed to save custom background image.");
            }
            result.insert(QStringLiteral("error"), copyError);
            return result;
        }
    }

    pruneLibraryBackgroundStoreVariants(m_dataRoot, targetPath);

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("storedPath"), relativePathWithinDataRoot(m_dataRoot, targetPath));
    result.insert(QStringLiteral("absolutePath"), targetPath);
    result.insert(QStringLiteral("fileUrl"), QUrl::fromLocalFile(targetPath).toString());
    return result;
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
    const QString writeError = ComicLibraryMutationOps::setSeriesMetadataForKey(m_dbPath, seriesKey, values);
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

        const int requestedAnchorCount =
            (requestedVolume.isEmpty() ? 0 : 1)
            + (requestedPublisher.isEmpty() ? 0 : 1)
            + (requestedYear.isEmpty() ? 0 : 1);
        const int anchorMatchCount =
            (metadataTextMatchScore(requestedVolume, candidateVolume, 1) > 0 ? 1 : 0)
            + (metadataTextMatchScore(requestedPublisher, candidatePublisher, 1) > 0 ? 1 : 0)
            + (metadataTextMatchScore(requestedYear, candidateYear, 1) > 0 ? 1 : 0);

        if (requestedAnchorCount > 0 && anchorMatchCount < 1) {
            continue;
        }

        int score =
            metadataTextMatchScore(requestedVolume, candidateVolume, 4)
            + metadataTextMatchScore(requestedPublisher, candidatePublisher, 4)
            + metadataTextMatchScore(requestedYear, candidateYear, 3)
            + metadataTextMatchScore(requestedTitle, candidateTitle, 2)
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

QString ComicsListModel::rememberIssueMetadataForAutofill(int comicId)
{
    return preserveRetainedIssueMetadata(comicId);
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

    const QString writeError = ComicLibraryMutationOps::setSeriesMetadataForKey(m_dbPath, key, {
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
    const QString writeError = ComicLibraryMutationOps::removeSeriesMetadataForKey(m_dbPath, seriesKey);
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
