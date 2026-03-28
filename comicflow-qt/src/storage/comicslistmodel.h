#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QDirIterator>
#include <QHash>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class ComicsListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString dataRoot READ dataRoot CONSTANT)
    Q_PROPERTY(QString dbPath READ dbPath CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY statusChanged)
    Q_PROPERTY(QString lastMutationKind READ lastMutationKind NOTIFY statusChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY statusChanged)

public:
    enum ComicRoles {
        IdRole = Qt::UserRole + 1,
        FilenameRole,
        SeriesRole,
        SeriesGroupKeyRole,
        SeriesGroupTitleRole,
        VolumeGroupKeyRole,
        VolumeRole,
        TitleRole,
        IssueNumberRole,
        PublisherRole,
        YearRole,
        MonthRole,
        MonthNameRole,
        WriterRole,
        PencillerRole,
        InkerRole,
        ColoristRole,
        LettererRole,
        CoverArtistRole,
        EditorRole,
        StoryArcRole,
        SummaryRole,
        CharactersRole,
        GenresRole,
        AgeRatingRole,
        ReadStatusRole,
        CurrentPageRole,
        BookmarkPageRole,
        HasBookmarkRole,
        HasFavoriteRole,
        AddedDateRole,
        DisplayTitleRole,
        DisplaySubtitleRole
    };
    Q_ENUM(ComicRoles)

    explicit ComicsListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString dataRoot() const;
    QString dbPath() const;
    QString lastError() const;
    QString lastMutationKind() const;
    int totalCount() const;

    Q_INVOKABLE void reload();
    Q_INVOKABLE QVariantMap checkDatabaseHealth() const;
    Q_INVOKABLE int requestDatabaseHealthCheckAsync();
    Q_INVOKABLE bool isLibraryStorageMigrationPending() const;
    Q_INVOKABLE int requestLibraryStorageMigrationAsync();
    Q_INVOKABLE QString updateComicMetadata(
        int comicId,
        const QVariantMap &values
    );
    Q_INVOKABLE QString bulkUpdateMetadata(
        const QVariantList &comicIds,
        const QVariantMap &values,
        const QVariantMap &applyMap
    );
    Q_INVOKABLE QString createComicFromLibrary(
        const QString &filename,
        const QVariantMap &values
    );
    Q_INVOKABLE QString importArchiveAndCreateIssue(
        const QString &sourcePath,
        const QString &filenameHint,
        const QVariantMap &values
    );
    Q_INVOKABLE QVariantMap importSourceAndCreateIssueEx(
        const QString &sourcePath,
        const QString &sourceType,
        const QString &filenameHint,
        const QVariantMap &values
    );
    Q_INVOKABLE int requestNormalizeImportArchiveAsync(const QString &sourcePath);
    Q_INVOKABLE QVariantMap importArchiveAndCreateIssueEx(
        const QString &sourcePath,
        const QString &filenameHint,
        const QVariantMap &values
    );
    Q_INVOKABLE int countPendingImportDuplicates(const QVariantList &entries) const;
    Q_INVOKABLE QVariantMap previewPendingImportDuplicate(const QVariantList &entries, int skipMatches = 0) const;
    Q_INVOKABLE QString browseArchiveFile(const QString &currentPath) const;
    Q_INVOKABLE QStringList browseArchiveFiles(const QString &currentPath) const;
    Q_INVOKABLE QString browseArchiveFolder(const QString &currentPath) const;
    Q_INVOKABLE QString browseDataRootFolder(const QString &currentPath) const;
    Q_INVOKABLE QString browseImageFile(const QString &currentPath) const;
    Q_INVOKABLE QVariantList expandImportSources(const QVariantList &sourcePaths, bool recursive = true) const;
    Q_INVOKABLE QStringList listArchiveFilesInFolder(const QString &folderPath, bool recursive = true) const;
    Q_INVOKABLE qint64 fileSizeBytes(const QString &path) const;
    Q_INVOKABLE QStringList supportedImportArchiveExtensions() const;
    Q_INVOKABLE bool isImportArchiveSupported(const QString &path) const;
    Q_INVOKABLE bool isSevenZipRequiredForArchive(const QString &path) const;
    Q_INVOKABLE QString importArchiveUnsupportedReason(const QString &path) const;
    Q_INVOKABLE QString setSevenZipExecutablePath(const QString &path);
    Q_INVOKABLE QString configuredSevenZipExecutablePath() const;
    Q_INVOKABLE QString effectiveSevenZipExecutablePath() const;
    Q_INVOKABLE bool isCbrBackendAvailable() const;
    Q_INVOKABLE QString cbrBackendMissingMessage() const;
    Q_INVOKABLE QString pendingDataRootRelocationPath() const;
    Q_INVOKABLE QVariantMap scheduleDataRootRelocation(const QString &targetPath);
    Q_INVOKABLE QString readStartupSnapshot() const;
    Q_INVOKABLE bool writeStartupSnapshot(const QString &payload) const;
    Q_INVOKABLE QVariantMap currentStartupInventorySignature() const;
    Q_INVOKABLE int requestStartupInventorySignatureAsync();
    Q_INVOKABLE QString startupLogPath() const;
    Q_INVOKABLE QString startupDebugLogPath() const;
    Q_INVOKABLE QString startupPreviewPath() const;
    Q_INVOKABLE QString startupPreviewMetaPath() const;
    Q_INVOKABLE bool writeStartupPreviewMeta(const QString &payload) const;
    Q_INVOKABLE QString readStartupPreviewMeta() const;
    Q_INVOKABLE void resetStartupLog() const;
    Q_INVOKABLE void appendStartupLog(const QString &line) const;
    Q_INVOKABLE void resetStartupDebugLog() const;
    Q_INVOKABLE void appendStartupDebugLog(const QString &line) const;
    Q_INVOKABLE QVariantList seriesGroups() const;
    Q_INVOKABLE QVariantList volumeGroupsForSeries(const QString &seriesKey) const;
    Q_INVOKABLE QVariantList issuesForSeries(
        const QString &seriesKey,
        const QString &volumeKey,
        const QString &readStatusFilter,
        const QString &searchText
    ) const;
    Q_INVOKABLE QVariantList issuesForQuickFilter(
        const QString &filterKey,
        const QVariantList &lastImportComicIds
    ) const;
    Q_INVOKABLE int quickFilterIssueCount(
        const QString &filterKey,
        const QVariantList &lastImportComicIds
    ) const;
    Q_INVOKABLE int heroCoverComicIdForSeries(const QString &seriesKey) const;
    Q_INVOKABLE int requestSeriesHeroAsync(const QString &seriesKey);
    Q_INVOKABLE int requestRandomSeriesHeroAsync(const QString &seriesKey);
    Q_INVOKABLE QString setSortMode(const QString &sortMode);
    Q_INVOKABLE QVariantMap openReaderSession(int comicId);
    Q_INVOKABLE int requestReaderSessionAsync(int comicId);
    Q_INVOKABLE QVariantMap loadReaderPage(int comicId, int pageIndex);
    Q_INVOKABLE int requestReaderPageAsync(int comicId, int pageIndex);
    Q_INVOKABLE QVariantList cachedReaderPageMetrics(int comicId) const;
    Q_INVOKABLE int requestReaderPageMetricsAsync(int comicId);
    Q_INVOKABLE int requestIssueThumbnailAsync(int comicId);
    Q_INVOKABLE QString cachedIssueThumbnailSource(int comicId) const;
    Q_INVOKABLE QString copyImageFileToClipboard(const QString &imageSource);
    Q_INVOKABLE QString saveReaderProgress(int comicId, int currentPage);
    Q_INVOKABLE QString saveReaderBookmark(int comicId, int bookmarkPage);
    Q_INVOKABLE QString saveReaderFavorite(int comicId, bool favoriteActive);
    Q_INVOKABLE QVariantMap deleteReaderPageFromArchive(int comicId, int pageIndex);
    Q_INVOKABLE QString deleteSeriesFiles(const QString &seriesKey);
    Q_INVOKABLE QString deleteSeriesFilesKeepRecords(const QString &seriesKey);
    Q_INVOKABLE QString deleteComicFilesKeepRecord(int comicId);
    Q_INVOKABLE QString detachComicFileKeepMetadata(int comicId);
    Q_INVOKABLE QVariantMap replaceComicFileFromSourceEx(
        int comicId,
        const QString &sourcePath,
        const QString &sourceType,
        const QString &filenameHint,
        const QVariantMap &values
    );
    Q_INVOKABLE QString restoreReplacedComicFileFromBackup(
        int comicId,
        const QString &backupPath,
        const QString &targetPath,
        const QString &filename
    );
    Q_INVOKABLE QString restoreReplacedComicFileFromBackupEx(
        int comicId,
        const QString &backupPath,
        const QString &targetPath,
        const QString &filename,
        const QVariantMap &importSignalValues
    );
    Q_INVOKABLE QString relinkComicFileKeepMetadata(int comicId, const QString &filePath, const QString &filename);
    Q_INVOKABLE QString relinkComicFileKeepMetadataEx(
        int comicId,
        const QString &filePath,
        const QString &filename,
        const QVariantMap &importSignalValues
    );
    Q_INVOKABLE QString deleteFileAtPath(const QString &filePath);
    Q_INVOKABLE QString deleteFileFingerprintHistoryEntries(const QVariantList &entryIds);
    Q_INVOKABLE QVariantMap exportComicInfoXml(int comicId);
    Q_INVOKABLE QString syncComicInfoToArchive(int comicId);
    Q_INVOKABLE QString importComicInfoFromArchive(int comicId, const QString &mode);
    Q_INVOKABLE QVariantMap loadComicMetadata(int comicId) const;
    Q_INVOKABLE QString archivePathForComic(int comicId) const;
    Q_INVOKABLE QString deleteComic(int comicId);
    Q_INVOKABLE QString deleteComicHard(int comicId);
    Q_INVOKABLE QString normalizeSeriesKeyForLookup(const QString &value) const;
    Q_INVOKABLE QString groupTitleForKey(const QString &groupKey) const;
    Q_INVOKABLE QVariantMap seriesMetadataForKey(const QString &seriesKey) const;
    Q_INVOKABLE QVariantMap seriesMetadataSuggestion(const QVariantMap &values, const QString &currentSeriesKey) const;
    Q_INVOKABLE QString setSeriesMetadataForKey(const QString &seriesKey, const QVariantMap &values);
    Q_INVOKABLE QVariantMap issueMetadataSuggestion(const QVariantMap &values, int currentComicId) const;
    Q_INVOKABLE QVariantMap saveSeriesHeaderImages(
        const QString &seriesKey,
        const QString &coverSourcePath,
        const QString &backgroundSourcePath
    );
    Q_INVOKABLE QString removeSeriesMetadataForKey(const QString &seriesKey);
    Q_INVOKABLE QString seriesSummaryForKey(const QString &seriesKey) const;
    Q_INVOKABLE QString setSeriesSummaryForKey(const QString &seriesKey, const QString &summary);
    Q_INVOKABLE QString removeSeriesSummaryForKey(const QString &seriesKey);

signals:
    void statusChanged();
    void databaseHealthChecked(int requestId, QVariantMap result);
    void libraryStorageMigrationFinished(int requestId, QVariantMap result);
    void startupInventorySignatureReady(int requestId, QVariantMap result);
    void readerSessionReady(int requestId, QVariantMap result);
    void pageImageReady(
        int requestId,
        int comicId,
        int pageIndex,
        const QString &imageSource,
        const QString &error,
        bool thumbnail
    );
    void readerPageMetricsReady(int requestId, int comicId, QVariantMap result);
    void seriesHeroReady(
        int requestId,
        const QString &seriesKey,
        const QString &imageSource,
        const QString &error
    );
    void normalizeImportArchiveFinished(int requestId, QVariantMap result);

private:
    struct ComicRow {
        int id = 0;
        QString filePath;
        QString filename;
        QString series;
        QString volumeGroupKey;
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
        int bookmarkPage = 0;
        QString bookmarkAddedAt;
        bool favoriteActive = false;
        QString favoriteAddedAt;
        QString addedDate;
        QString seriesGroupKey;
        QString seriesGroupTitle;
    };

    struct QueuedCoverGeneration {
        QString pendingKey;
        int comicId = 0;
        QString archivePath;
        QString cacheStamp;
        QString coverPath;
        QByteArray coverFormat;
    };

    struct QueuedSeriesHeroGeneration {
        QString pendingKey;
        QString seriesKey;
        int comicId = 0;
        QString archivePath;
        QString cacheStamp;
        QByteArray heroFormat;
        bool randomEligiblePage = false;
        QVector<int> candidateComicIds;
        QStringList candidateArchivePaths;
    };

    bool openDatabaseConnection(QSqlDatabase &db, const QString &connectionName, QString &errorText) const;
    static QVariantMap loadReaderSessionPayload(
        const QString &dbPath,
        const QString &dataRoot,
        int comicId
    );
    static QVariantMap loadReaderPageMetricsPayload(
        const QString &dataRoot,
        int comicId,
        const QString &archivePath,
        const QStringList &entries
    );
    void cacheReaderSession(const QVariantMap &session);
    void cacheReaderPageMetrics(int comicId, const QVariantList &pageMetrics);
    QVariantMap cachedReaderSessionPayload(int comicId) const;
    void emitReaderSessionReadyForRequestIds(
        const QList<int> &requestIds,
        const QVariantMap &result
    );
    QString archivePathForComicId(int comicId) const;
    QString seriesGroupKeyForComicId(int comicId) const;
    void startQueuedCoverGeneration(const QueuedCoverGeneration &job);
    void pumpQueuedCoverGeneration();
    void startQueuedSeriesHeroGeneration(const QueuedSeriesHeroGeneration &job);
    void pumpQueuedSeriesHeroGeneration();
    static QString normalizeSeriesKey(const QString &value);
    static QString normalizeVolumeKey(const QString &value);
    static QString normalizeReadStatus(const QString &value);
    QString predictedPendingImportTargetPath(
        const QVariantMap &entry,
        QHash<QString, QString> &simulatedDeferredImportFolders
    ) const;
    static bool listImageEntriesInArchive(
        const QString &archivePath,
        QStringList &entriesOut,
        QString &errorText
    );
    static bool extractArchiveEntryToFile(
        const QString &archivePath,
        const QString &entryName,
        const QString &outputFilePath,
        QString &errorText
    );
    static bool normalizeArchiveToCbz(
        const QString &sourceArchivePath,
        const QString &targetCbzPath,
        QString &errorText
    );
    static bool createCbzFromDirectory(
        const QString &sourceDirPath,
        const QString &targetCbzPath,
        QString &errorText
    );
    static bool packageImageFolderToCbz(
        const QString &folderPath,
        const QString &targetCbzPath,
        QString &errorText
    );
    void emitPageReadyForRequestIds(
        const QList<int> &requestIds,
        int comicId,
        int pageIndex,
        const QString &imageSource,
        const QString &error,
        bool thumbnail
    );
    void emitSeriesHeroReadyForRequestIds(
        const QList<int> &requestIds,
        const QString &seriesKey,
        const QString &imageSource,
        const QString &error
    );
    void purgeSeriesHeroCacheForKey(const QString &seriesKey);
    void updateReaderProgressCache(int comicId, int currentPage, const QString &readStatus);
    void updateReaderBookmarkCache(int comicId, int bookmarkPage);
    void updateReaderFavoriteCache(int comicId, bool favoriteActive);
    static QString makeGroupTitle(const QString &groupKey);
    static QString resolveLibraryFilePath(const QString &libraryPath, const QString &inputFilename);
    static QString resolveStoredArchivePathForDataRoot(
        const QString &dataRoot,
        const QString &storedFilePath,
        const QString &storedFilename
    );
    QString resolveDataRoot() const;
    static QString baseNameWithoutExtension(const QString &filename);
    static QString buildSubtitle(const ComicRow &row);
    int compareRows(const ComicRow &left, const ComicRow &right) const;
    QString importArchiveAndCreateIssueInternal(
        const QString &sourcePath,
        const QString &filenameHint,
        const QVariantMap &values,
        QVariantMap *outResult
    );
    QString importImageFolderAndCreateIssueInternal(
        const QString &folderPath,
        const QString &filenameHint,
        const QVariantMap &values,
        QVariantMap *outResult
    );
    QString relinkComicFileKeepMetadataInternal(
        int comicId,
        const QString &filePath,
        const QString &filename,
        const QVariantMap &importSignalValues
    );
    QString restoreComicFileBindingsAfterRecovery(
        const QHash<int, QString> &bindingsByComicId,
        const QString &connectionTag
    );
    QString restoreBackupFileAfterRecovery(
        const QString &backupPath,
        const QString &targetPath
    );
    bool deleteComicHardInternal(int comicId, QString &messageOut);
    QString deleteFileFingerprintHistoryForComicIds(const QVector<int> &comicIds);
    QString pruneEquivalentDetachedGhostRowsForComic(int comicId);
    int liveIssueCountForSeries(const QString &seriesKey) const;
    QVariantMap buildRetainedSeriesMetadata(const QString &seriesKey) const;
    QVariantMap buildRetainedIssueMetadata(int comicId) const;
    QString preserveRetainedSeriesMetadata(const QString &seriesKey);
    QString preserveRetainedIssueMetadata(int comicId);
    void resetLastImportOutcome();
    QString deleteSeriesKeyForComic(int comicId) const;
    void invalidateAllReaderAsyncState();
    void clearReaderRuntimeStateForComic(int comicId);
    void clearReaderRuntimeStateForComics(const QVector<int> &comicIds);
    void setReaderArchivePathForComic(int comicId, const QString &archivePath);

    QString m_dataRoot;
    QString m_dbPath;
    QString m_lastError;
    QString m_lastMutationKind;
    QVector<ComicRow> m_rows;
    QHash<int, QString> m_readerArchivePathById;
    QHash<int, QStringList> m_readerImageEntriesById;
    QHash<int, QVariantList> m_readerPageMetricsById;
    QHash<QString, QString> m_deferredImportFolderBySeriesKey;
    QHash<int, QList<int>> m_pendingReaderSessionRequestIdsByComicId;
    QHash<int, QList<int>> m_pendingReaderPageRequestIdsByComicId;
    QHash<int, QList<int>> m_pendingReaderPageMetricsRequestIdsByComicId;
    QHash<QString, QList<int>> m_pendingImageRequestIdsByKey;
    QHash<QString, QList<int>> m_pendingSeriesHeroRequestIdsByKey;
    QVector<QueuedCoverGeneration> m_coverGenerationQueue;
    QVector<QueuedSeriesHeroGeneration> m_seriesHeroGenerationQueue;
    int m_activeCoverGenerationCount = 0;
    int m_activeSeriesHeroGenerationCount = 0;
    int m_nextAsyncRequestId = 1;
    int m_readerAsyncEpoch = 0;
    int m_reloadValidationGeneration = 0;
    QString m_sortMode = QString("series_issue");
    QString m_lastImportAction;
    int m_lastImportComicId = -1;
    int m_lastImportDuplicateId = -1;
    QString m_lastImportDuplicateTier;
    int m_lastImportRestoreCandidateCount = 0;
    int m_lastImportRestoreCandidateId = -1;
    QHash<int, int> m_readerAsyncRevisionByComicId;
};
