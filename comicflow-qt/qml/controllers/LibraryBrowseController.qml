import QtQuick
import "../components/AppText.js" as AppText
import "../components/SeriesContext.js" as SeriesContext

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var startupControllerRef: null
    property var navigationSurfaceControllerRef: null
    property var readerCoverControllerRef: null
    property var heroSeriesControllerRef: null
    property var uiTokensRef: null
    property var seriesListModelRef: null
    property var volumeListModelRef: null
    property var mainLibraryPaneRef: null
    property var issuesGridRefreshDebounceRef: null
    readonly property string textLanguage: rootObject
        ? String(rootObject.appLanguage || AppText.fallbackLanguageCode)
        : AppText.fallbackLanguageCode

    property string selectedSeriesKey: ""
    property string selectedSeriesTitle: ""
    property string selectedVolumeKey: "__all__"
    property string selectedVolumeTitle: AppText.libraryAllVolumes
    readonly property var selectedSeriesContext: SeriesContext.selectedContext(
        selectedSeriesKey,
        selectedSeriesTitle,
        selectedVolumeKey,
        selectedVolumeTitle,
        AppText.libraryAllVolumes
    )
    property string sidebarSearchText: ""
    property string sidebarQuickFilterKey: ""
    property string librarySeriesColorFilter: ""
    property var librarySeriesAvailableColorTags: ({})
    property var lastImportSessionComicIds: []
    property int quickFilterLastImportCount: 0
    property int quickFilterFavoritesCount: 0
    property int quickFilterBookmarksCount: 0
    property string librarySearchText: ""
    property string libraryReadStatusFilter: "all"
    property bool libraryLoading: false
    property bool hideCurrentImportBatchIssues: false
    property var hiddenCurrentImportBatchComicIds: ({})
    property var hiddenCurrentImportBatchSeriesKeys: ({})

    function activeRoot() {
        return rootObject
    }

    function traceBrowse(message) {
        const root = activeRoot()
        if (!root || typeof root.runtimeDebugLog !== "function") return
        root.runtimeDebugLog("library-browse", String(message || ""))
    }

    function applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle) {
        const context = SeriesContext.selectedContext(
            seriesKey,
            seriesTitle,
            volumeKey,
            volumeTitle,
            AppText.libraryAllVolumes
        )
        traceBrowse(
            "apply context"
            + " seriesKey=" + String(context.seriesKey || "")
            + " seriesTitle=" + String(context.seriesTitle || "")
            + " volumeKey=" + String(context.volumeKey || "")
            + " volumeTitle=" + String(context.volumeTitle || "")
        )
        selectedSeriesKey = context.seriesKey
        selectedSeriesTitle = context.seriesTitle
        selectedVolumeKey = context.volumeKey
        selectedVolumeTitle = context.volumeTitle
    }

    function currentSelectedSeriesContext() {
        return SeriesContext.selectedContext(
            selectedSeriesKey,
            selectedSeriesTitle,
            selectedVolumeKey,
            selectedVolumeTitle,
            AppText.libraryAllVolumes
        )
    }

    function refreshQuickFilterCounts() {
        if (!libraryModelRef) return
        quickFilterLastImportCount = libraryModelRef.quickFilterIssueCount("last_import", lastImportSessionComicIds)
        quickFilterFavoritesCount = libraryModelRef.quickFilterIssueCount("favorites", lastImportSessionComicIds)
        quickFilterBookmarksCount = libraryModelRef.quickFilterIssueCount("bookmarks", lastImportSessionComicIds)
    }

    function sidebarQuickFilterCount(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return quickFilterLastImportCount
        if (key === "favorites") return quickFilterFavoritesCount
        if (key === "bookmarks") return quickFilterBookmarksCount
        return 0
    }

    function quickFilterTitleText(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return AppText.t("quickFilterLastImportedIssuesTitle", textLanguage)
        if (key === "favorites") return AppText.t("quickFilterFavoriteIssuesTitle", textLanguage)
        if (key === "bookmarks") return AppText.t("quickFilterBookmarkedIssuesTitle", textLanguage)
        return ""
    }

    function quickFilterEmptyText(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return AppText.t("quickFilterLastImportedEmpty", textLanguage)
        if (key === "favorites") return AppText.t("quickFilterFavoriteEmpty", textLanguage)
        if (key === "bookmarks") return AppText.t("quickFilterBookmarkedEmpty", textLanguage)
        return ""
    }

    function quickFilterTitleIconSource(filterKey) {
        if (!uiTokensRef) return ""
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return uiTokensRef.quickFilterTitleLastImportIcon
        if (key === "favorites") return uiTokensRef.quickFilterTitleFavoriteIcon
        if (key === "bookmarks") return uiTokensRef.quickFilterTitleBookmarkIcon
        return ""
    }

    function isQuickFilterModeActive() {
        return String(sidebarQuickFilterKey || "").trim().length > 0
    }

    function resetLastImportSession() {
        const root = activeRoot()
        lastImportSessionComicIds = []
        hideCurrentImportBatchIssues = false
        hiddenCurrentImportBatchComicIds = ({})
        hiddenCurrentImportBatchSeriesKeys = ({})
        refreshQuickFilterCounts()
        if (String(sidebarQuickFilterKey || "") === "last_import") {
            if (root && typeof root.setGridScrollToTop === "function") {
                root.setGridScrollToTop()
            }
            scheduleIssuesGridRefresh(true)
        }
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
    }

    function currentImportBatchIssueHidden(comicId, seriesKey) {
        if (!hideCurrentImportBatchIssues) return false
        const normalizedComicId = Number(comicId || 0)
        if (normalizedComicId < 1) return false
        if (hiddenCurrentImportBatchComicIds[String(normalizedComicId)] !== true) return false

        const normalizedSeriesKey = String(seriesKey || "").trim()
        if (normalizedSeriesKey.length > 0) {
            return hiddenCurrentImportBatchSeriesKeys[normalizedSeriesKey] === true
        }
        return true
    }

    function filterHiddenCurrentImportBatchIssues(issues, seriesKey) {
        if (!hideCurrentImportBatchIssues) return issues
        if (!Array.isArray(issues) || issues.length < 1) return []
        const normalizedSeriesKey = String(seriesKey || "").trim()
        if (normalizedSeriesKey.length > 0
                && hiddenCurrentImportBatchSeriesKeys[normalizedSeriesKey] !== true) {
            return issues
        }
        const visibleIssues = []
        for (let i = 0; i < issues.length; i += 1) {
            const issue = issues[i] || ({})
            if (currentImportBatchIssueHidden(Number(issue.id || 0), normalizedSeriesKey)) continue
            visibleIssues.push(issue)
        }
        return visibleIssues
    }

    function currentImportBatchSeriesHidden(seriesKey) {
        if (!hideCurrentImportBatchIssues) return false
        const normalizedSeriesKey = String(seriesKey || "").trim()
        if (normalizedSeriesKey.length < 1) return false
        return hiddenCurrentImportBatchSeriesKeys[normalizedSeriesKey] === true
    }

    function importCancelGridSnapshotForSeries(seriesKey, volumeKey) {
        const root = activeRoot()
        if (!root) return []
        const normalizedSeriesKey = String(seriesKey || "").trim()
        if (normalizedSeriesKey.length < 1) return []
        if (String(root.importCancelGridSnapshotSeriesKey || "").trim() !== normalizedSeriesKey) return []

        const normalizedVolumeKey = String(volumeKey || "__all__").trim()
        const snapshotVolumeKey = String(root.importCancelGridSnapshotVolumeKey || "__all__").trim()
        if (snapshotVolumeKey.length > 0 && snapshotVolumeKey !== normalizedVolumeKey) return []

        return Array.isArray(root.importCancelGridSnapshotIssues)
            ? root.importCancelGridSnapshotIssues.slice(0)
            : []
    }

    function hideCurrentImportBatch(comicIds) {
        const ids = Array.isArray(comicIds) ? comicIds : []
        const nextComicIds = ({})
        const nextSeriesKeys = ({})
        for (let i = 0; i < ids.length; i += 1) {
            const comicId = Number(ids[i] || 0)
            if (comicId < 1) continue
            nextComicIds[String(comicId)] = true
            if (libraryModelRef && typeof libraryModelRef.navigationTargetForComic === "function") {
                const target = libraryModelRef.navigationTargetForComic(comicId) || ({})
                const seriesKey = String(target.seriesKey || "").trim()
                if (seriesKey.length > 0) nextSeriesKeys[seriesKey] = true
            }
        }
        hiddenCurrentImportBatchComicIds = nextComicIds
        hiddenCurrentImportBatchSeriesKeys = nextSeriesKeys
        hideCurrentImportBatchIssues = true
        scheduleIssuesGridRefresh(true, true)
    }

    function clearCurrentImportBatchHide() {
        if (!hideCurrentImportBatchIssues) return
        hideCurrentImportBatchIssues = false
        hiddenCurrentImportBatchComicIds = ({})
        hiddenCurrentImportBatchSeriesKeys = ({})
        scheduleIssuesGridRefresh(true, true)
    }

    function rememberLastImportComicId(comicId) {
        const normalizedComicId = Number(comicId || 0)
        if (normalizedComicId < 1) return

        const nextIds = [normalizedComicId]
        const existingIds = Array.isArray(lastImportSessionComicIds) ? lastImportSessionComicIds : []
        for (let i = 0; i < existingIds.length; i += 1) {
            const existingId = Number(existingIds[i] || 0)
            if (existingId < 1 || existingId === normalizedComicId) continue
            nextIds.push(existingId)
        }
        lastImportSessionComicIds = nextIds
        refreshQuickFilterCounts()
        if (String(sidebarQuickFilterKey || "") === "last_import") {
            scheduleIssuesGridRefresh(true)
        }
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
    }

    function selectSidebarQuickFilter(filterKey) {
        const root = activeRoot()
        const key = String(filterKey || "").trim().toLowerCase()
        if (key.length < 1 || !root) return
        traceBrowse("select quick filter key=" + key)
        sidebarQuickFilterKey = key
        if (typeof root.clearSelection === "function") {
            root.clearSelection()
        }
        if (typeof root.setGridScrollToTop === "function") {
            root.setGridScrollToTop()
        }
        if (mainLibraryPaneRef) {
            mainLibraryPaneRef.heroCollapseOffset = 0
        }
        scheduleIssuesGridRefresh(true)
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
    }

    function setLibrarySeriesColorFilter(colorTag) {
        const root = activeRoot()
        const normalizedTag = String(colorTag || "").trim().toLowerCase()
        const availableTags = librarySeriesAvailableColorTags || ({})
        if (normalizedTag.length > 0 && availableTags[normalizedTag] !== true) return
        librarySeriesColorFilter = librarySeriesColorFilter === normalizedTag ? "" : normalizedTag
        sidebarQuickFilterKey = ""
        if (root && typeof root.setGridScrollToTop === "function") {
            root.setGridScrollToTop()
        }
        refreshSeriesList()
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
    }

    function refreshSeriesList() {
        const root = activeRoot()
        if (!root || !libraryModelRef || !seriesListModelRef) return

        const groups = libraryModelRef.seriesGroups().slice(0)
        traceBrowse(
            "refresh series list"
            + " groups=" + String(groups.length || 0)
            + " sidebarSearch=" + String(sidebarSearchText || "")
        )
        if (
            root.startupSnapshotApplied
                && root.startupHydrationInProgress
                && groups.length < 1
                && seriesListModelRef.count > 0
        ) {
            startupControllerRef.startupLog("refreshSeriesList keep snapshot: live groups empty during hydration")
            return
        }

        groups.sort(function(a, b) {
            const left = String(a.seriesTitle || "").toLowerCase()
            const right = String(b.seriesTitle || "").toLowerCase()
            if (left < right) return -1
            if (left > right) return 1
            return 0
        })

        const availableColorTags = ({})
        for (let i = 0; i < groups.length; i += 1) {
            const tag = String((groups[i] || {}).colorTag || "").trim().toLowerCase()
            if (tag.length > 0) availableColorTags[tag] = true
        }
        librarySeriesAvailableColorTags = availableColorTags

        const searchNeedle = String(sidebarSearchText || "").trim().toLowerCase()
        let colorFilter = String(librarySeriesColorFilter || "").trim().toLowerCase()
        if (colorFilter.length > 0 && availableColorTags[colorFilter] !== true) {
            librarySeriesColorFilter = ""
            colorFilter = ""
        }
        seriesListModelRef.clear()
        for (let i = 0; i < groups.length; i += 1) {
            const item = groups[i]
            const title = String(item.seriesTitle || "")
            if (searchNeedle.length > 0 && title.toLowerCase().indexOf(searchNeedle) < 0) {
                continue
            }
            const itemColorTag = String(item.colorTag || "").trim().toLowerCase()
            if (colorFilter.length > 0 && itemColorTag !== colorFilter) {
                continue
            }
            seriesListModelRef.append({
                seriesKey: String(item.seriesKey || ""),
                seriesTitle: title,
                count: Number(item.count || 0),
                colorTag: itemColorTag
            })
        }

        libraryLoading = false

        if (typeof root.applyConfiguredLaunchViewAfterRefreshIfNeeded === "function"
                && root.applyConfiguredLaunchViewAfterRefreshIfNeeded()) {
            return
        }

        if (seriesListModelRef.count < 1) {
            if (typeof root.clearImportSeriesFocusState === "function") {
                root.clearImportSeriesFocusState()
            }
            applySelectedSeriesContext("", "", "__all__", AppText.libraryAllVolumes)
            const emptySelection = {}
            root.selectedSeriesKeys = emptySelection
            root.seriesSelectionAnchorIndex = -1
            if (volumeListModelRef) {
                volumeListModelRef.clear()
            }
            heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
            heroSeriesControllerRef.refreshSeriesData()
            refreshQuickFilterCounts()
            return
        }

        if (typeof root.applyPendingImportedSeriesFocus === "function"
                && root.applyPendingImportedSeriesFocus()) {
            heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
            heroSeriesControllerRef.refreshSeriesData()
            refreshQuickFilterCounts()
            return
        }

        const preservedSelection = {}
        for (let i = 0; i < seriesListModelRef.count; i += 1) {
            const item = seriesListModelRef.get(i)
            const key = String(item.seriesKey || "")
            if (root.selectedSeriesKeys[key] === true) {
                preservedSelection[key] = true
            }
        }
        root.selectedSeriesKeys = preservedSelection

        for (let i = 0; i < seriesListModelRef.count; i += 1) {
            const item = seriesListModelRef.get(i)
            if (item.seriesKey === selectedSeriesKey) {
                applySelectedSeriesContext(item.seriesKey, item.seriesTitle, selectedVolumeKey, selectedVolumeTitle)
                if (typeof root.isSeriesSelected === "function" && !root.isSeriesSelected(selectedSeriesKey)) {
                    const next = Object.assign({}, root.selectedSeriesKeys)
                    next[String(selectedSeriesKey)] = true
                    root.selectedSeriesKeys = next
                }
                root.seriesSelectionAnchorIndex = i
                refreshVolumeList()
                refreshIssuesGridData(true)
                heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
                heroSeriesControllerRef.refreshSeriesData()
                refreshQuickFilterCounts()
                return
            }
        }

        applySelectedSeriesContext(
            seriesListModelRef.get(0).seriesKey,
            seriesListModelRef.get(0).seriesTitle,
            "__all__",
            AppText.libraryAllVolumes
        )
        const nextSelection = {}
        nextSelection[String(selectedSeriesKey)] = true
        root.selectedSeriesKeys = nextSelection
        root.seriesSelectionAnchorIndex = 0
        refreshVolumeList()
        heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
        heroSeriesControllerRef.refreshSeriesData()
        refreshQuickFilterCounts()
    }

    function applyVolumeSelectionByIndex(index) {
        if (!volumeListModelRef || index < 0 || index >= volumeListModelRef.count) {
            applySelectedSeriesContext(selectedSeriesKey, selectedSeriesTitle, "__all__", AppText.libraryAllVolumes)
            return
        }
        const item = volumeListModelRef.get(index)
        applySelectedSeriesContext(
            selectedSeriesKey,
            selectedSeriesTitle,
            String(item.volumeKey || "__all__"),
            String(item.volumeTitle || AppText.libraryAllVolumes)
        )
    }

    function refreshVolumeList() {
        if (!libraryModelRef || !volumeListModelRef) return
        const currentContext = currentSelectedSeriesContext()
        const previousKey = String(currentContext.volumeKey || "__all__")
        const groups = currentContext.hasSeries
            ? libraryModelRef.volumeGroupsForSeries(currentContext.seriesKey)
            : []
        traceBrowse(
            "refresh volume list"
            + " seriesKey=" + String(currentContext.seriesKey || "")
            + " previousVolumeKey=" + previousKey
            + " groups=" + String(groups.length || 0)
        )

        volumeListModelRef.clear()

        let totalCount = 0
        for (let i = 0; i < groups.length; i += 1) {
            totalCount += Number(groups[i].count || 0)
        }

        volumeListModelRef.append({
            volumeKey: "__all__",
            volumeTitle: AppText.libraryAllVolumes,
            count: totalCount,
            displayLabel: AppText.libraryAllVolumes + " (" + totalCount + ")"
        })

        let restoredIndex = 0
        for (let i = 0; i < groups.length; i += 1) {
            const item = groups[i]
            const volumeKey = String(item.volumeKey || "")
            const volumeTitle = String(item.volumeTitle || AppText.libraryNoVolume)
            const count = Number(item.count || 0)
            volumeListModelRef.append({
                volumeKey: volumeKey,
                volumeTitle: volumeTitle,
                count: count,
                displayLabel: volumeTitle + " (" + count + ")"
            })
            if (volumeKey === previousKey) {
                restoredIndex = i + 1
            }
        }

        applyVolumeSelectionByIndex(restoredIndex)
    }

    function refreshIssuesGridData(preserveSplitScroll) {
        const root = activeRoot()
        if (!root) return
        const shouldPreserveSplitScroll = preserveSplitScroll === true
        const preservedSplitScroll = shouldPreserveSplitScroll && mainLibraryPaneRef
            ? Number(mainLibraryPaneRef.currentSplitScroll || 0)
            : 0

        if (isQuickFilterModeActive()) {
            refreshQuickFilterGridData(shouldPreserveSplitScroll, preservedSplitScroll)
            return
        }

        refreshSeriesGridData(shouldPreserveSplitScroll, preservedSplitScroll)
    }

    function refreshQuickFilterGridData(shouldPreserveSplitScroll, preservedSplitScroll) {
        const root = activeRoot()
        if (!root || !libraryModelRef || !navigationSurfaceControllerRef) return
        const activeQuickFilterKey = String(sidebarQuickFilterKey || "").trim().toLowerCase()
        const liveIssues = libraryModelRef.issuesForQuickFilter(activeQuickFilterKey, lastImportSessionComicIds)
        const visibleIssues = filterHiddenCurrentImportBatchIssues(liveIssues)
        traceBrowse(
            "refresh quick filter grid"
            + " key=" + activeQuickFilterKey
            + " count=" + String(liveIssues.length || 0)
            + " visible=" + String(visibleIssues.length || 0)
            + " preserveSplitScroll=" + String(shouldPreserveSplitScroll === true)
        )
        root.issuesGridData = navigationSurfaceControllerRef.applyIssueOrder(visibleIssues)
        if (typeof root.primeVisibleIssueCoverSourcesFromCache === "function") {
            root.primeVisibleIssueCoverSourcesFromCache()
        }
        if (root.startupReconcileCompleted || !root.startupSnapshotApplied) {
            if (typeof root.warmVisibleIssueThumbnails === "function") {
                root.warmVisibleIssueThumbnails()
            }
        } else {
            startupControllerRef.startupLog("defer warmVisibleIssueThumbnails until first reconcile")
        }
        refreshQuickFilterCounts()
        if (shouldPreserveSplitScroll && typeof root.scheduleGridSplitScrollRestore === "function") {
            root.scheduleGridSplitScrollRestore(preservedSplitScroll)
        }
    }

    function refreshSeriesGridData(shouldPreserveSplitScroll, preservedSplitScroll) {
        const root = activeRoot()
        if (!root || !libraryModelRef || !navigationSurfaceControllerRef) return

        const currentContext = currentSelectedSeriesContext()
        traceBrowse(
            "refresh series grid"
            + " seriesKey=" + String(currentContext.seriesKey || "")
            + " volumeKey=" + String(currentContext.volumeKey || "")
            + " readFilter=" + String(libraryReadStatusFilter || "")
            + " search=" + String(librarySearchText || "")
        )
        if (!currentContext.hasSeries) {
            if (root.startupSnapshotApplied && root.startupHydrationInProgress && root.issuesGridData.length > 0) {
                startupControllerRef.startupLog("refreshIssuesGridData keep snapshot: selectedSeriesKey empty during hydration")
                return
            }
            root.issuesGridData = []
            return
        }

        const previousIssues = Array.isArray(root.issuesGridData) ? root.issuesGridData.slice(0) : []
        if (hideCurrentImportBatchIssues && !currentImportBatchSeriesHidden(currentContext.seriesKey)) {
            const frozenIssues = importCancelGridSnapshotForSeries(
                currentContext.seriesKey,
                currentContext.volumeKey
            )
            if (frozenIssues.length > 0) {
                traceBrowse(
                    "keep frozen grid during import cancel"
                    + " seriesKey=" + String(currentContext.seriesKey || "")
                    + " frozen=" + String(frozenIssues.length || 0)
                )
                root.issuesGridData = frozenIssues
                if (shouldPreserveSplitScroll && typeof root.scheduleGridSplitScrollRestore === "function") {
                    root.scheduleGridSplitScrollRestore(preservedSplitScroll)
                }
                return
            }
        }

        const liveIssues = libraryModelRef.issuesForSeries(
            currentContext.seriesKey,
            currentContext.volumeKey,
            libraryReadStatusFilter,
            librarySearchText
        )
        const visibleIssues = filterHiddenCurrentImportBatchIssues(liveIssues, currentContext.seriesKey)
        traceBrowse(
            "series grid live issues"
            + " seriesKey=" + String(currentContext.seriesKey || "")
            + " count=" + String(liveIssues.length || 0)
            + " visible=" + String(visibleIssues.length || 0)
        )
        if (hideCurrentImportBatchIssues
                && !currentImportBatchSeriesHidden(currentContext.seriesKey)
                && liveIssues.length < 1
                && previousIssues.length > 0) {
            traceBrowse(
                "keep previous grid during import cancel"
                + " seriesKey=" + String(currentContext.seriesKey || "")
                + " previous=" + String(previousIssues.length || 0)
            )
            return
        }
        const orderedIssues = navigationSurfaceControllerRef.applyIssueOrder(visibleIssues)
        const liveIssueListChanged = !startupControllerRef.issueListsEquivalentByIdAndOrder(previousIssues, orderedIssues)
        if (
            root.startupSnapshotApplied
                && !root.startupHydrationInProgress
                && liveIssues.length < 1
                && currentContext.volumeKey === "__all__"
                && String(librarySearchText || "").trim().length < 1
                && String(libraryReadStatusFilter || "all") === "all"
                && !root.startupSnapshotLiveReloadRequested
        ) {
            root.startupSnapshotLiveReloadRequested = true
            startupControllerRef.startupLog("refreshIssuesGridData request live reload for key=" + String(currentContext.seriesKey))
            libraryModelRef.reload()
        }
        if (root.startupSnapshotApplied && root.startupHydrationInProgress) {
            if (visibleIssues.length < 1 && root.issuesGridData.length > 0) {
                startupControllerRef.startupLog("refreshIssuesGridData keep snapshot: live issues empty during hydration")
            } else if (startupControllerRef.issueListsEquivalentByIdAndOrder(root.issuesGridData, orderedIssues)) {
                startupControllerRef.startupLog("refreshIssuesGridData keep snapshot: live issues equivalent during hydration")
            } else {
                root.issuesGridData = orderedIssues
            }
        } else {
            root.issuesGridData = orderedIssues
        }
        if (liveIssueListChanged && readerCoverControllerRef) {
            const previousIdMap = ({})
            const liveIdMap = ({})
            const resetComicIds = []
            for (let i = 0; i < previousIssues.length; i += 1) {
                const previousId = Number((previousIssues[i] || {}).id || 0)
                if (previousId > 0) previousIdMap[String(previousId)] = true
            }
            for (let i = 0; i < visibleIssues.length; i += 1) {
                const liveId = Number((visibleIssues[i] || {}).id || 0)
                if (liveId > 0) liveIdMap[String(liveId)] = true
            }
            const previousKeys = Object.keys(previousIdMap)
            for (let i = 0; i < previousKeys.length; i += 1) {
                const key = String(previousKeys[i] || "")
                if (liveIdMap[key] !== true) resetComicIds.push(Number(key))
            }
            const liveKeys = Object.keys(liveIdMap)
            for (let i = 0; i < liveKeys.length; i += 1) {
                const key = String(liveKeys[i] || "")
                if (previousIdMap[key] !== true) resetComicIds.push(Number(key))
            }
            traceBrowse(
                "refresh grid clearing cover sources"
                + " seriesKey=" + String(currentContext.seriesKey || "")
                + " resetCount=" + String(resetComicIds.length)
                + " orderDescending=" + String(Boolean(
                    navigationSurfaceControllerRef
                    && navigationSurfaceControllerRef.issueOrderDescending
                ))
                + " heroComicId=" + String(Number(root.heroCoverComicId || -1))
                + " heroAutoSourceEmpty=" + String(String(root.heroAutoCoverSource || "").trim().length < 1)
            )
            readerCoverControllerRef.clearCoverSourcesForComicIds(resetComicIds)
        }
        if (typeof root.primeVisibleIssueCoverSourcesFromCache === "function") {
            root.primeVisibleIssueCoverSourcesFromCache()
        }
        if (root.startupReconcileCompleted || !root.startupSnapshotApplied) {
            if (typeof root.warmVisibleIssueThumbnails === "function") {
                root.warmVisibleIssueThumbnails()
            }
        } else {
            startupControllerRef.startupLog("defer warmVisibleIssueThumbnails until first reconcile")
        }
        if (readerCoverControllerRef
                && currentContext.hasSeries
                && String(root.heroCustomCoverSource || "").trim().length < 1
                && String(root.heroAutoCoverSource || "").trim().length < 1
                && typeof readerCoverControllerRef.resolveHeroCoverForSelectedSeries === "function") {
            traceBrowse(
                "refresh grid hero fallback resolve"
                + " seriesKey=" + String(currentContext.seriesKey || "")
                + " heroComicId=" + String(Number(root.heroCoverComicId || -1))
            )
            readerCoverControllerRef.resolveHeroCoverForSelectedSeries(false)
        }

        if (shouldPreserveSplitScroll && typeof root.scheduleGridSplitScrollRestore === "function") {
            root.scheduleGridSplitScrollRestore(preservedSplitScroll)
        }
        refreshQuickFilterCounts()
    }

    function scheduleIssuesGridRefresh(immediate, preserveSplitScroll) {
        if (!issuesGridRefreshDebounceRef) return
        if (immediate === true) {
            issuesGridRefreshDebounceRef.stop()
            refreshIssuesGridData(preserveSplitScroll)
            return
        }
        issuesGridRefreshDebounceRef.restart()
    }
}
