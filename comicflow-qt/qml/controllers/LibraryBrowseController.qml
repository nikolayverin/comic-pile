import QtQuick

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

    property string selectedSeriesKey: ""
    property string selectedSeriesTitle: ""
    property string selectedVolumeKey: "__all__"
    property string selectedVolumeTitle: "All volumes"
    property string sidebarSearchText: ""
    property string sidebarQuickFilterKey: ""
    property var lastImportSessionComicIds: []
    property int quickFilterLastImportCount: 0
    property int quickFilterFavoritesCount: 0
    property int quickFilterBookmarksCount: 0
    property string librarySearchText: ""
    property string libraryReadStatusFilter: "all"
    property bool libraryLoading: false

    function activeRoot() {
        return rootObject
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
        if (key === "last_import") return "Last imported issues"
        if (key === "favorites") return "Favorite issues"
        if (key === "bookmarks") return "Bookmarked issues"
        return ""
    }

    function quickFilterEmptyText(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return "No recent import yet"
        if (key === "favorites") return "No favorite issues yet"
        if (key === "bookmarks") return "No bookmarked issues yet"
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

    function refreshSeriesList() {
        const root = activeRoot()
        if (!root || !libraryModelRef || !seriesListModelRef) return

        const groups = libraryModelRef.seriesGroups().slice(0)
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

        const searchNeedle = String(sidebarSearchText || "").trim().toLowerCase()
        seriesListModelRef.clear()
        for (let i = 0; i < groups.length; i += 1) {
            const item = groups[i]
            const title = String(item.seriesTitle || "")
            if (searchNeedle.length > 0 && title.toLowerCase().indexOf(searchNeedle) < 0) {
                continue
            }
            seriesListModelRef.append({
                seriesKey: String(item.seriesKey || ""),
                seriesTitle: title,
                count: Number(item.count || 0)
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
            selectedSeriesKey = ""
            selectedSeriesTitle = ""
            const emptySelection = {}
            root.selectedSeriesKeys = emptySelection
            root.seriesSelectionAnchorIndex = -1
            selectedVolumeKey = "__all__"
            selectedVolumeTitle = "All volumes"
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
                selectedSeriesTitle = item.seriesTitle
                if (typeof root.isSeriesSelected === "function" && !root.isSeriesSelected(selectedSeriesKey)) {
                    const next = Object.assign({}, root.selectedSeriesKeys)
                    next[String(selectedSeriesKey)] = true
                    root.selectedSeriesKeys = next
                }
                root.seriesSelectionAnchorIndex = i
                refreshVolumeList()
                heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
                heroSeriesControllerRef.refreshSeriesData()
                refreshQuickFilterCounts()
                return
            }
        }

        selectedSeriesTitle = seriesListModelRef.get(0).seriesTitle
        selectedSeriesKey = seriesListModelRef.get(0).seriesKey
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
            selectedVolumeKey = "__all__"
            selectedVolumeTitle = "All volumes"
            return
        }
        const item = volumeListModelRef.get(index)
        selectedVolumeKey = String(item.volumeKey || "__all__")
        selectedVolumeTitle = String(item.volumeTitle || "All volumes")
    }

    function refreshVolumeList() {
        if (!libraryModelRef || !volumeListModelRef) return
        const previousKey = selectedVolumeKey
        const groups = selectedSeriesKey.length > 0
            ? libraryModelRef.volumeGroupsForSeries(selectedSeriesKey)
            : []

        volumeListModelRef.clear()

        let totalCount = 0
        for (let i = 0; i < groups.length; i += 1) {
            totalCount += Number(groups[i].count || 0)
        }

        volumeListModelRef.append({
            volumeKey: "__all__",
            volumeTitle: "All volumes",
            count: totalCount,
            displayLabel: "All volumes (" + totalCount + ")"
        })

        let restoredIndex = 0
        for (let i = 0; i < groups.length; i += 1) {
            const item = groups[i]
            const volumeKey = String(item.volumeKey || "")
            const volumeTitle = String(item.volumeTitle || "No Volume")
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
        root.issuesGridData = navigationSurfaceControllerRef.applyIssueOrder(liveIssues)
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

        if (selectedSeriesKey.length < 1) {
            if (root.startupSnapshotApplied && root.startupHydrationInProgress && root.issuesGridData.length > 0) {
                startupControllerRef.startupLog("refreshIssuesGridData keep snapshot: selectedSeriesKey empty during hydration")
                return
            }
            root.issuesGridData = []
            return
        }

        const previousIssues = Array.isArray(root.issuesGridData) ? root.issuesGridData.slice(0) : []
        const liveIssues = libraryModelRef.issuesForSeries(
            selectedSeriesKey,
            selectedVolumeKey,
            libraryReadStatusFilter,
            librarySearchText
        )
        const orderedIssues = navigationSurfaceControllerRef.applyIssueOrder(liveIssues)
        const liveIssueListChanged = !startupControllerRef.issueListsEquivalentByIdAndOrder(previousIssues, orderedIssues)
        if (
            root.startupSnapshotApplied
                && !root.startupHydrationInProgress
                && liveIssues.length < 1
                && selectedVolumeKey === "__all__"
                && String(librarySearchText || "").trim().length < 1
                && String(libraryReadStatusFilter || "all") === "all"
                && !root.startupSnapshotLiveReloadRequested
        ) {
            root.startupSnapshotLiveReloadRequested = true
            startupControllerRef.startupLog("refreshIssuesGridData request live reload for key=" + String(selectedSeriesKey))
            libraryModelRef.reload()
        }
        if (root.startupSnapshotApplied && root.startupHydrationInProgress) {
            if (liveIssues.length < 1 && root.issuesGridData.length > 0) {
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
            const resetComicIds = []
            for (let i = 0; i < previousIssues.length; i += 1) {
                const previousId = Number((previousIssues[i] || {}).id || 0)
                if (previousId > 0) resetComicIds.push(previousId)
            }
            for (let i = 0; i < liveIssues.length; i += 1) {
                const liveId = Number((liveIssues[i] || {}).id || 0)
                if (liveId > 0) resetComicIds.push(liveId)
            }
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
