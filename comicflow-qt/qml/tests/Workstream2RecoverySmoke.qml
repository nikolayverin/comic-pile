import QtQuick
import QtQml.Models
import "../controllers"

Item {
    id: harness

    signal finished(bool success, string details)

    property bool completed: false
    property bool success: false
    property string details: ""

    readonly property var modelRef: (typeof workstream2Model !== "undefined") ? workstream2Model : null
    readonly property var emptyModelRef: (typeof workstream2EmptyModel !== "undefined") ? workstream2EmptyModel : null
    readonly property var seed: (typeof workstream2Seed !== "undefined") ? workstream2Seed : ({})

    function fail(message) {
        if (completed) return
        completed = true
        success = false
        details = String(message || "Unknown Workstream 2 smoke failure.")
        finished(false, details)
    }

    function pass() {
        if (completed) return
        completed = true
        success = true
        details = "Workstream 2 recovery smoke passed."
        finished(true, details)
    }

    function assertCondition(condition, message) {
        if (condition) return true
        fail(message)
        return false
    }

    function arrayEquals(left, right) {
        const a = Array.isArray(left) ? left : []
        const b = Array.isArray(right) ? right : []
        if (a.length !== b.length) return false
        for (let i = 0; i < a.length; i += 1) {
            if (Number(a[i] || 0) !== Number(b[i] || 0)) return false
        }
        return true
    }

    function gridComicIds(items) {
        const out = []
        const rows = Array.isArray(items) ? items : []
        for (let i = 0; i < rows.length; i += 1) {
            out.push(Number((rows[i] || {}).id || 0))
        }
        return out
    }

    function buildSnapshotPayload(seriesTitle) {
        return {
            version: 1,
            selectedSeriesKey: String(seed.alphaSeriesKey || ""),
            selectedSeriesTitle: String(seriesTitle || ""),
            selectedVolumeKey: "__all__",
            selectedVolumeTitle: "All volumes",
            sidebarQuickFilterKey: "last_import",
            lastImportSessionComicIds: [
                Number(seed.alphaIssue2Id || 0),
                999001,
                Number(seed.alphaIssue1Id || 0)
            ],
            sidebarSearchText: "Alpha",
            librarySearchText: "Issue",
            libraryReadStatusFilter: "unread",
            sevenZipConfiguredPath: "",
            inventorySignature: modelRef.currentStartupInventorySignature(),
            heroCoverComicId: Number(seed.alphaIssue1Id || 0),
            heroSeriesData: {
                seriesTitle: String(seriesTitle || ""),
                summary: "Alpha summary",
                year: "2025",
                volume: "1",
                publisher: "Smoke Publisher",
                genres: "Adventure",
                logoSource: ""
            },
            seriesItems: [
                {
                    seriesKey: String(seed.alphaSeriesKey || ""),
                    seriesTitle: String(seriesTitle || ""),
                    count: 2
                }
            ],
            issuesItems: [
                {
                    id: Number(seed.alphaIssue2Id || 0),
                    series: "Alpha Series",
                    volume: "1",
                    title: "Alpha Issue 002",
                    issueNumber: "2",
                    filename: "alpha-002.cbz",
                    readStatus: "unread",
                    currentPage: 0,
                    publisher: "Smoke Publisher",
                    year: 2025,
                    month: 0
                },
                {
                    id: Number(seed.alphaIssue1Id || 0),
                    series: "Alpha Series",
                    volume: "1",
                    title: "Alpha Issue 001",
                    issueNumber: "1",
                    filename: "alpha-001.cbz",
                    readStatus: "unread",
                    currentPage: 0,
                    publisher: "Smoke Publisher",
                    year: 2024,
                    month: 0
                }
            ],
            coverByComicId: {},
            windowState: "windowed",
            windowX: 120,
            windowY: 80,
            windowWidth: 1024,
            windowHeight: 820,
            seriesContentY: 480,
            issuesContentY: 960
        }
    }

    function syncBrowseStateFromRoot() {
        browse.sidebarQuickFilterKey = String(rootState.sidebarQuickFilterKey || "")
        browse.lastImportSessionComicIds = Array.isArray(rootState.lastImportSessionComicIds)
            ? rootState.lastImportSessionComicIds.slice(0)
            : []
    }

    function runStartupSnapshotVerification() {
        details = "writing primary snapshot"
        const payload = buildSnapshotPayload(seed.alphaSeriesTitle)
        const saved = modelRef.writeStartupSnapshot(JSON.stringify(payload))
        if (!assertCondition(saved === true, "Startup snapshot verification: failed to write snapshot payload.")) return false

        details = "restoring primary snapshot"
        const rawSnapshot = String(modelRef.readStartupSnapshot() || "")
        const restored = startupSnapshotController.restoreStartupSnapshot()
        if (!assertCondition(
                restored === true,
                "Startup snapshot verification: non-empty library snapshot did not restore."
                + " totalCount=" + String(Number(modelRef.totalCount || 0))
                + " rawLen=" + String(rawSnapshot.length)
            )) return false
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Startup snapshot verification: selected series key did not restore.")) return false
        if (!assertCondition(rootState.selectedSeriesTitle === String(seed.alphaSeriesTitle || ""), "Startup snapshot verification: selected series title did not restore.")) return false
        if (!assertCondition(rootState.sidebarQuickFilterKey === "last_import", "Startup snapshot verification: quick filter did not restore.")) return false
        if (!assertCondition(rootState.sidebarSearchText === "Alpha", "Startup snapshot verification: Library search restore is missing.")) return false
        if (!assertCondition(rootState.librarySearchText === "Issue", "Startup snapshot verification: Issues search restore is missing.")) return false
        if (!assertCondition(rootState.libraryReadStatusFilter === "unread", "Startup snapshot verification: read-status filter did not restore.")) return false
        if (!assertCondition(rootState.windowSnapshot.windowState === "windowed", "Startup snapshot verification: window snapshot did not restore.")) return false
        if (!assertCondition(rootState.startupSnapshotSeriesContentY === 0 && rootState.startupSnapshotIssuesContentY === 0, "Startup snapshot verification: snapshot scroll state should not restore.")) return false
        if (!assertCondition(seriesListModel.count === 1, "Startup snapshot verification: series list did not restore expected snapshot items.")) return false
        if (!assertCondition(rootState.issuesGridData.length === 2, "Startup snapshot verification: Issues snapshot data did not restore.")) return false
        return true
    }

    function runImportSessionRecoveryChecks() {
        syncBrowseStateFromRoot()
        details = "refreshing last import from mixed ids"
        browse.refreshQuickFilterCounts()
        browse.refreshQuickFilterGridData(false, 0)
        if (!assertCondition(browse.quickFilterLastImportCount === 2, "Import session recovery: Last import count still includes stale ids.")) return false
        const expectedOrder = [Number(seed.alphaIssue2Id || 0), Number(seed.alphaIssue1Id || 0)]
        const actualOrder = gridComicIds(rootState.issuesGridData)
        if (!assertCondition(
                arrayEquals(actualOrder, expectedOrder),
                "Import session recovery: Last import grid did not keep only live issues in snapshot order."
                + " actual=" + JSON.stringify(actualOrder)
                + " expected=" + JSON.stringify(expectedOrder)
            )) return false

        details = "refreshing last import from stale ids only"
        rootState.lastImportSessionComicIds = [999002, 999003]
        syncBrowseStateFromRoot()
        browse.refreshQuickFilterCounts()
        browse.refreshQuickFilterGridData(false, 0)
        if (!assertCondition(browse.quickFilterLastImportCount === 0, "Import session recovery: stale Last import state still shows a non-zero count.")) return false
        if (!assertCondition(rootState.issuesGridData.length === 0, "Import session recovery: stale Last import state still shows phantom issues.")) return false
        return true
    }

    function runEmptyLibraryRecoveryChecks() {
        details = "writing empty-library snapshot"
        const payload = buildSnapshotPayload(seed.alphaSeriesTitle)
        const saved = emptyModelRef.writeStartupSnapshot(JSON.stringify(payload))
        if (!assertCondition(saved === true, "Startup snapshot verification: failed to write empty-library snapshot payload.")) return false

        details = "restoring empty-library snapshot"
        const restored = emptySnapshotController.restoreStartupSnapshot()
        if (!assertCondition(restored === false, "Startup snapshot verification: empty live library should reject stale snapshot content.")) return false
        if (!assertCondition(emptyRootState.selectedSeriesKey === "", "Startup snapshot verification: empty live library should not restore stale selection.")) return false
        if (!assertCondition(emptyRootState.issuesGridData.length === 0, "Startup snapshot verification: empty live library should not restore stale Issues content.")) return false
        if (!assertCondition(emptyRootState.windowSnapshot.windowState === "windowed", "Startup snapshot verification: empty live library should still restore window state.")) return false
        return true
    }

    function continueAfterScrollReset() {
        details = "checking scroll reset after restore"
        if (!assertCondition(rootState.gridScrollToTopCount > 0, "Startup snapshot verification: launch restore did not reset grid scroll.")) return
        if (!assertCondition(seriesListView.contentY === 0, "Startup snapshot verification: series list scroll was not reset.")) return
        if (!runImportSessionRecoveryChecks()) return
        if (!runEmptyLibraryRecoveryChecks()) return
        pass()
    }

    function runAll() {
        details = "starting workstream 2 harness"
        if (!assertCondition(!!modelRef, "Workstream 2 smoke: populated library model context is missing.")) return
        if (!assertCondition(!!emptyModelRef, "Workstream 2 smoke: empty library model context is missing.")) return
        if (!assertCondition(Number(seed.alphaIssue1Id || 0) > 0 && Number(seed.alphaIssue2Id || 0) > 0, "Workstream 2 smoke: seed data is incomplete.")) return

        if (!runStartupSnapshotVerification()) return
        Qt.callLater(continueAfterScrollReset)
    }

    QtObject {
        id: startupController
        property bool startupWindowStateRestored: false

        function normalizedInventorySignatureKey(signature) {
            const source = signature && typeof signature === "object" ? signature : ({})
            return String(source.signatureKey || "").trim()
        }

        function startupLog() {}
        function startupStep() {}
        function markStartupInteractive() {}
        function logStartupUiState() {}
        function trackingLog() {}
        function logWindowTrackingState() {}
    }

    QtObject {
        id: emptyStartupController
        property bool startupWindowStateRestored: false

        function normalizedInventorySignatureKey(signature) {
            const source = signature && typeof signature === "object" ? signature : ({})
            return String(source.signatureKey || "").trim()
        }

        function startupLog() {}
        function startupStep() {}
        function markStartupInteractive() {}
        function logStartupUiState() {}
        function trackingLog() {}
        function logWindowTrackingState() {}
    }

    QtObject {
        id: navigationSurfaceController
        function applyIssueOrder(items) {
            if (Array.isArray(items)) {
                return items.slice(0)
            }
            const out = []
            const length = Number(items && items.length || 0)
            for (let i = 0; i < length; i += 1) {
                out.push(items[i])
            }
            return out
        }
    }

    QtObject {
        id: heroSeriesController
        function refreshSeriesData() {}
    }

    QtObject {
        id: readerCoverController
        function clearCoverSourcesForComicIds() {}
    }

    QtObject {
        id: issuesGridRefreshDebounce
        function stop() {}
        function restart() {}
    }

    QtObject {
        id: mainLibraryPane
        property real currentSplitScroll: 0
    }

    QtObject {
        id: rootState
        property string selectedSeriesKey: ""
        property string selectedSeriesTitle: ""
        property string selectedVolumeKey: "__all__"
        property string selectedVolumeTitle: "All volumes"
        property var selectedSeriesKeys: ({})
        property int seriesSelectionAnchorIndex: -1
        property string sidebarQuickFilterKey: ""
        property var lastImportSessionComicIds: []
        property string sidebarSearchText: ""
        property string librarySearchText: ""
        property string libraryReadStatusFilter: "all"
        property string sevenZipConfiguredPath: ""
        property var startupInventorySignature: ({})
        property var heroSeriesData: ({})
        property int heroCoverComicId: -1
        property var coverByComicId: ({})
        property var issuesGridData: []
        property real startupSnapshotSeriesContentY: 0
        property real startupSnapshotIssuesContentY: 0
        property bool startupSnapshotApplied: false
        property bool startupReconcileCompleted: true
        property bool startupHydrationInProgress: false
        property bool startupSnapshotLiveReloadRequested: false
        property bool libraryLoading: false
        property bool restoringStartupSnapshot: false
        property bool suspendSidebarSearchRefresh: false
        property int gridScrollToTopCount: 0
        property var windowSnapshot: ({})
        property int quickFilterRefreshCount: 0

        function applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle) {
            selectedSeriesKey = String(seriesKey || "")
            selectedSeriesTitle = String(seriesTitle || "")
            selectedVolumeKey = String(volumeKey || "__all__")
            selectedVolumeTitle = String(volumeTitle || "All volumes")
        }

        function setGridScrollToTop() {
            gridScrollToTopCount += 1
        }

        function refreshQuickFilterCounts() {
            quickFilterRefreshCount += 1
            browse.sidebarQuickFilterKey = String(sidebarQuickFilterKey || "")
            browse.lastImportSessionComicIds = Array.isArray(lastImportSessionComicIds)
                ? lastImportSessionComicIds.slice(0)
                : []
            browse.refreshQuickFilterCounts()
        }

        function applyConfiguredLaunchViewDuringStartupRestore() {}
        function primeVisibleIssueCoverSourcesFromCache() {}
        function warmVisibleIssueThumbnails() {}
        function scheduleGridSplitScrollRestore() {}
        function requestIssueThumbnail() {}

        function coverSourceForComic(comicId) {
            return String((coverByComicId || {})[String(comicId)] || "")
        }
    }

    QtObject {
        id: emptyRootState
        property string selectedSeriesKey: ""
        property string selectedSeriesTitle: ""
        property string selectedVolumeKey: "__all__"
        property string selectedVolumeTitle: "All volumes"
        property var selectedSeriesKeys: ({})
        property int seriesSelectionAnchorIndex: -1
        property string sidebarQuickFilterKey: ""
        property var lastImportSessionComicIds: []
        property string sidebarSearchText: ""
        property string librarySearchText: ""
        property string libraryReadStatusFilter: "all"
        property string sevenZipConfiguredPath: ""
        property var startupInventorySignature: ({})
        property var heroSeriesData: ({})
        property int heroCoverComicId: -1
        property var coverByComicId: ({})
        property var issuesGridData: []
        property real startupSnapshotSeriesContentY: 0
        property real startupSnapshotIssuesContentY: 0
        property bool startupSnapshotApplied: false
        property bool startupReconcileCompleted: true
        property bool startupHydrationInProgress: false
        property bool startupSnapshotLiveReloadRequested: false
        property bool libraryLoading: false
        property bool restoringStartupSnapshot: false
        property bool suspendSidebarSearchRefresh: false
        property int gridScrollToTopCount: 0
        property var windowSnapshot: ({})

        function applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle) {
            selectedSeriesKey = String(seriesKey || "")
            selectedSeriesTitle = String(seriesTitle || "")
            selectedVolumeKey = String(volumeKey || "__all__")
            selectedVolumeTitle = String(volumeTitle || "All volumes")
        }

        function setGridScrollToTop() {
            gridScrollToTopCount += 1
        }

        function refreshQuickFilterCounts() {}
        function applyConfiguredLaunchViewDuringStartupRestore() {}
        function primeVisibleIssueCoverSourcesFromCache() {}
        function warmVisibleIssueThumbnails() {}
        function scheduleGridSplitScrollRestore() {}
        function requestIssueThumbnail() {}

        function coverSourceForComic(comicId) {
            return String((coverByComicId || {})[String(comicId)] || "")
        }
    }

    QtObject {
        id: windowDisplayController
        property var appliedSnapshot: ({})

        function stampWindowState(snapshotObject) {
            return snapshotObject
        }

        function applyWindowSnapshot(parsed) {
            appliedSnapshot = parsed && typeof parsed === "object" ? parsed : ({})
            rootState.windowSnapshot = appliedSnapshot
        }
    }

    QtObject {
        id: emptyWindowDisplayController
        property var appliedSnapshot: ({})

        function stampWindowState(snapshotObject) {
            return snapshotObject
        }

        function applyWindowSnapshot(parsed) {
            appliedSnapshot = parsed && typeof parsed === "object" ? parsed : ({})
            emptyRootState.windowSnapshot = appliedSnapshot
        }
    }

    ListModel {
        id: seriesListModel
    }

    ListModel {
        id: emptySeriesListModel
    }

    QtObject {
        id: seriesListView
        property real contentY: 222
    }

    QtObject {
        id: emptySeriesListView
        property real contentY: 111
    }

    StartupSnapshotController {
        id: startupSnapshotController
        startupControllerRef: startupController
        rootObject: rootState
        libraryModelRef: modelRef
        heroSeriesControllerRef: heroSeriesController
        windowDisplayControllerRef: windowDisplayController
        seriesListModel: seriesListModel
        seriesListView: seriesListView
    }

    StartupSnapshotController {
        id: emptySnapshotController
        startupControllerRef: emptyStartupController
        rootObject: emptyRootState
        libraryModelRef: emptyModelRef
        heroSeriesControllerRef: heroSeriesController
        windowDisplayControllerRef: emptyWindowDisplayController
        seriesListModel: emptySeriesListModel
        seriesListView: emptySeriesListView
    }

    LibraryBrowseController {
        id: browse
        rootObject: rootState
        libraryModelRef: modelRef
        startupControllerRef: startupController
        navigationSurfaceControllerRef: navigationSurfaceController
        readerCoverControllerRef: readerCoverController
        heroSeriesControllerRef: heroSeriesController
        seriesListModelRef: seriesListModel
        mainLibraryPaneRef: mainLibraryPane
        issuesGridRefreshDebounceRef: issuesGridRefreshDebounce
    }

    Component.onCompleted: Qt.callLater(function() {
        try {
            runAll()
        } catch (e) {
            fail("Workstream 2 harness exception: " + String(e))
        }
    })
}
