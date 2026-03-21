import QtQuick

Item {
    id: facade
    visible: false
    width: 0
    height: 0

    property var libraryModelRef: null

    readonly property string lastError: libraryModelRef ? String(libraryModelRef.lastError || "") : ""
    readonly property int totalCount: libraryModelRef ? Number(libraryModelRef.totalCount || 0) : 0

    function expandImportSources(paths, includeImageFolders) {
        return libraryModelRef ? libraryModelRef.expandImportSources(paths, includeImageFolders) : []
    }

    function fileSizeBytes(pathValue) {
        return libraryModelRef ? Number(libraryModelRef.fileSizeBytes(pathValue) || 0) : 0
    }

    function issuesForSeries(seriesKey, volumeKey, readFilter, searchText) {
        return libraryModelRef
            ? libraryModelRef.issuesForSeries(seriesKey, volumeKey, readFilter, searchText)
            : []
    }

    function issuesForQuickFilter(filterKey, lastImportComicIds) {
        return libraryModelRef
            ? libraryModelRef.issuesForQuickFilter(filterKey, lastImportComicIds || [])
            : []
    }

    function quickFilterIssueCount(filterKey, lastImportComicIds) {
        return libraryModelRef
            ? Number(libraryModelRef.quickFilterIssueCount(filterKey, lastImportComicIds || []) || 0)
            : 0
    }

    function groupTitleForKey(seriesKey) {
        return libraryModelRef ? String(libraryModelRef.groupTitleForKey(seriesKey) || "") : ""
    }

    function seriesSummaryForKey(seriesKey) {
        return libraryModelRef ? String(libraryModelRef.seriesSummaryForKey(seriesKey) || "") : ""
    }

    function loadComicMetadata(comicId) {
        return libraryModelRef ? libraryModelRef.loadComicMetadata(comicId) : ({ error: "Library model is unavailable." })
    }

    function isImportArchiveSupported(pathValue) {
        return libraryModelRef ? Boolean(libraryModelRef.isImportArchiveSupported(String(pathValue || ""))) : false
    }

    function importArchiveUnsupportedReason(pathValue) {
        return libraryModelRef ? String(libraryModelRef.importArchiveUnsupportedReason(String(pathValue || "")) || "") : ""
    }

    function isSevenZipRequiredForArchive(pathValue) {
        return libraryModelRef ? Boolean(libraryModelRef.isSevenZipRequiredForArchive(pathValue)) : false
    }

    function isCbrBackendAvailable() {
        return libraryModelRef ? Boolean(libraryModelRef.isCbrBackendAvailable()) : false
    }

    function cbrBackendMissingMessage() {
        return libraryModelRef ? String(libraryModelRef.cbrBackendMissingMessage() || "") : ""
    }

    function configuredSevenZipExecutablePath() {
        return libraryModelRef ? String(libraryModelRef.configuredSevenZipExecutablePath() || "") : ""
    }

    function effectiveSevenZipExecutablePath() {
        return libraryModelRef ? String(libraryModelRef.effectiveSevenZipExecutablePath() || "") : ""
    }

    function setSevenZipExecutablePath(pathValue) {
        return libraryModelRef ? String(libraryModelRef.setSevenZipExecutablePath(String(pathValue || "")) || "") : ""
    }

    function browseArchiveFiles(initialPath) {
        return libraryModelRef ? libraryModelRef.browseArchiveFiles(initialPath) : []
    }

    function browseArchiveFile(initialPath) {
        return libraryModelRef ? String(libraryModelRef.browseArchiveFile(initialPath) || "") : ""
    }

    function browseArchiveFolder(initialPath) {
        return libraryModelRef ? String(libraryModelRef.browseArchiveFolder(initialPath) || "") : ""
    }

    function browseDataRootFolder(initialPath) {
        return libraryModelRef ? String(libraryModelRef.browseDataRootFolder(initialPath) || "") : ""
    }

    function browseImageFile(initialPath) {
        return libraryModelRef ? String(libraryModelRef.browseImageFile(initialPath) || "") : ""
    }

    function pendingDataRootRelocationPath() {
        return libraryModelRef ? String(libraryModelRef.pendingDataRootRelocationPath() || "") : ""
    }

    function scheduleDataRootRelocation(targetPath) {
        return libraryModelRef
            ? (libraryModelRef.scheduleDataRootRelocation(String(targetPath || "")) || {})
            : ({ ok: false, error: "Library model is unavailable." })
    }

    function reload() {
        if (libraryModelRef) {
            libraryModelRef.reload()
        }
    }

    function seriesGroups() {
        return libraryModelRef ? libraryModelRef.seriesGroups() : []
    }

    function volumeGroupsForSeries(seriesKey) {
        return libraryModelRef ? libraryModelRef.volumeGroupsForSeries(seriesKey) : []
    }

    function updateComicMetadata(comicId, draft) {
        return libraryModelRef ? String(libraryModelRef.updateComicMetadata(comicId, draft) || "") : "Library model is unavailable."
    }

    function seriesMetadataForKey(seriesKey) {
        return libraryModelRef ? (libraryModelRef.seriesMetadataForKey(seriesKey) || {}) : ({})
    }

    function setSeriesMetadataForKey(seriesKey, values) {
        return libraryModelRef ? String(libraryModelRef.setSeriesMetadataForKey(seriesKey, values) || "") : "Library model is unavailable."
    }

    function saveSeriesHeaderImages(seriesKey, coverSourcePath, backgroundSourcePath) {
        return libraryModelRef
            ? (libraryModelRef.saveSeriesHeaderImages(seriesKey, coverSourcePath, backgroundSourcePath) || {})
            : ({ ok: false, error: "Library model is unavailable." })
    }

    function removeSeriesMetadataForKey(seriesKey) {
        if (libraryModelRef) {
            libraryModelRef.removeSeriesMetadataForKey(seriesKey)
        }
    }

    function bulkUpdateMetadata(ids, values, applyMap) {
        return libraryModelRef ? String(libraryModelRef.bulkUpdateMetadata(ids, values, applyMap) || "") : "Library model is unavailable."
    }

    function replaceComicFileFromSourceEx(comicId, sourcePath, sourceType, filenameHint, values) {
        return libraryModelRef
            ? (libraryModelRef.replaceComicFileFromSourceEx(comicId, sourcePath, sourceType, filenameHint, values) || {})
            : ({ ok: false, code: "runtime_error", error: "Library model is unavailable." })
    }

    function deleteFileAtPath(filePath) {
        return libraryModelRef ? String(libraryModelRef.deleteFileAtPath(filePath) || "") : "Library model is unavailable."
    }

    function saveReaderProgress(comicId, pageValue) {
        return libraryModelRef ? String(libraryModelRef.saveReaderProgress(comicId, pageValue) || "") : "Library model is unavailable."
    }

    function saveReaderBookmark(comicId, pageValue) {
        return libraryModelRef ? String(libraryModelRef.saveReaderBookmark(comicId, pageValue) || "") : "Library model is unavailable."
    }

    function saveReaderFavorite(comicId, favoriteActive) {
        return libraryModelRef ? String(libraryModelRef.saveReaderFavorite(comicId, favoriteActive) || "") : "Library model is unavailable."
    }
}
