import QtQuick
import QtQuick.Controls
import QtQml.Models
import "../controllers"
import "../components"

Item {
    id: harness

    signal finished(bool success, string details)

    property bool completed: false
    property bool success: false
    property string details: ""

    readonly property var modelRef: (typeof workstreamModel !== "undefined") ? workstreamModel : null
    readonly property var seed: (typeof workstreamSeed !== "undefined") ? workstreamSeed : ({})

    function fail(message) {
        if (completed) return
        completed = true
        success = false
        details = String(message || "Unknown Workstream 1 smoke failure.")
        finished(false, details)
    }

    function pass() {
        if (completed) return
        completed = true
        success = true
        details = "Workstream 1 contract smoke passed."
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
            if (a[i] !== b[i]) return false
        }
        return true
    }

    function gridComicIds() {
        const out = []
        const items = Array.isArray(rootState.issuesGridData) ? rootState.issuesGridData : []
        for (let i = 0; i < items.length; i += 1) {
            out.push(Number((items[i] || {}).id || 0))
        }
        return out
    }

    function issueFromGrid(comicId) {
        const items = Array.isArray(rootState.issuesGridData) ? rootState.issuesGridData : []
        const normalizedComicId = Number(comicId || 0)
        for (let i = 0; i < items.length; i += 1) {
            const item = items[i] || {}
            if (Number(item.id || 0) === normalizedComicId) {
                return item
            }
        }
        return null
    }

    function seriesTitleForKey(seriesKey) {
        const key = String(seriesKey || "")
        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i) || {}
            if (String(item.seriesKey || "") === key) {
                return String(item.seriesTitle || "")
            }
        }
        return ""
    }

    function createSettingsProbe() {
        return settingsProbeComponent.createObject(harness)
    }

    function runLibraryNavigationSmoke() {
        browse.refreshSeriesList()
        if (!assertCondition(seriesListModel.count >= 2, "Library navigation smoke: expected at least two series.")) return false

        const alphaTitle = seriesTitleForKey(seed.alphaSeriesKey)
        const betaTitle = seriesTitleForKey(seed.betaSeriesKey)
        if (!assertCondition(alphaTitle.length > 0, "Library navigation smoke: Alpha series missing from Library.")) return false
        if (!assertCondition(betaTitle.length > 0, "Library navigation smoke: Beta series missing from Library.")) return false

        rootState.selectSeries(seed.alphaSeriesKey, alphaTitle, rootState.indexForSeriesKey(seed.alphaSeriesKey))
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Library navigation smoke: Alpha series did not become selected.")) return false
        if (!assertCondition(rootState.issuesGridData.length === 2, "Library navigation smoke: Alpha series grid did not show two issues.")) return false
        if (!assertCondition(gridComicIds().indexOf(Number(seed.alphaIssue1Id || 0)) >= 0, "Library navigation smoke: Alpha issue #1 missing from Issues.")) return false
        if (!assertCondition(gridComicIds().indexOf(Number(seed.alphaIssue2Id || 0)) >= 0, "Library navigation smoke: Alpha issue #2 missing from Issues.")) return false

        const alphaTarget = modelRef.navigationTargetForComic(Number(seed.alphaIssue1Id || 0)) || ({})
        navigation.openIssueTarget(alphaTarget, "Continue reading", "Issue unavailable")
        if (!assertCondition(Number((rootState.lastOpenedTarget || {}).comicId || 0) === Number(seed.alphaIssue1Id || 0), "Library navigation smoke: opening a visible issue did not target the expected comic.")) return false
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Library navigation smoke: opening an issue drifted the selected series.")) return false

        rootState.selectSeries(seed.betaSeriesKey, betaTitle, rootState.indexForSeriesKey(seed.betaSeriesKey))
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.betaSeriesKey || ""), "Library navigation smoke: Beta series did not become selected.")) return false
        if (!assertCondition(rootState.issuesGridData.length === 1, "Library navigation smoke: Beta series grid did not collapse to one issue.")) return false
        if (!assertCondition(Number((rootState.issuesGridData[0] || {}).id || 0) === Number(seed.betaIssue1Id || 0), "Library navigation smoke: Beta grid shows the wrong issue.")) return false
        return true
    }

    function runReaderOpenCloseSmoke() {
        const preservedSeriesKey = String(rootState.selectedSeriesKey || "")
        const preservedIssueIds = gridComicIds()
        popupController.openExclusivePopup(readerPopup)
        if (!assertCondition(readerPopup.visible === true, "Reader open/close smoke: reader popup did not open.")) return false

        popupController.requestPopupDismiss(readerPopup)
        if (!assertCondition(readerPopup.visible === false, "Reader open/close smoke: reader popup did not close.")) return false
        if (!assertCondition(rootState.selectedSeriesKey === preservedSeriesKey, "Reader open/close smoke: closing reader changed the selected series.")) return false
        if (!assertCondition(arrayEquals(gridComicIds(), preservedIssueIds), "Reader open/close smoke: closing reader changed the visible Issues content.")) return false
        return true
    }

    function runMetadataSaveUiSmoke() {
        const alphaTitle = seriesTitleForKey(seed.alphaSeriesKey)
        rootState.selectSeries(seed.alphaSeriesKey, alphaTitle, rootState.indexForSeriesKey(seed.alphaSeriesKey))

        const issueEditError = String(modelRef.updateComicMetadata(Number(seed.alphaIssue1Id || 0), {
            title: "Alpha Issue 001 Edited"
        }) || "")
        if (!assertCondition(issueEditError.length < 1, "Metadata save UI smoke: issue edit failed.")) return false

        modelRef.reload()
        browse.refreshIssuesGridData(true)
        const editedIssue = issueFromGrid(seed.alphaIssue1Id)
        if (!assertCondition(editedIssue !== null, "Metadata save UI smoke: edited issue disappeared from Issues.")) return false
        if (!assertCondition(String((editedIssue || {}).title || "") === "Alpha Issue 001 Edited", "Metadata save UI smoke: issue title did not refresh in Issues.")) return false
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Metadata save UI smoke: issue edit changed the selected series.")) return false

        const seriesEditError = String(modelRef.setSeriesMetadataForKey(String(seed.alphaSeriesKey || ""), {
            seriesTitle: "Alpha Series Edited"
        }) || "")
        if (!assertCondition(seriesEditError.length < 1, "Metadata save UI smoke: series edit failed.")) return false

        modelRef.reload()
        browse.refreshSeriesList()
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Metadata save UI smoke: series edit changed the selected series key.")) return false
        if (!assertCondition(rootState.selectedSeriesTitle === "Alpha Series Edited", "Metadata save UI smoke: selected series title did not refresh after save.")) return false
        if (!assertCondition(seriesTitleForKey(seed.alphaSeriesKey) === "Alpha Series Edited", "Metadata save UI smoke: Library list did not refresh edited series title.")) return false
        return true
    }

    function runSettingsBehaviorSmoke() {
        settingsPrimary.generalDefaultViewAfterLaunch = "Last Import"
        settingsPrimary.appearanceGridDensity = "Comfortable"
        settingsPrimary.readerRememberLastReaderMode = false
        settingsPrimary.readerDefaultReadingMode = "2 pages"
        settingsPrimary.readerMagnifierSize = "Large"

        const probe = createSettingsProbe()
        if (!assertCondition(!!probe, "Settings behavior smoke: failed to create settings probe.")) return false

        const ok = assertCondition(probe.generalDefaultViewAfterLaunch === "Last import", "Settings behavior smoke: alias normalization for launch view did not persist.")
            && assertCondition(probe.appearanceGridDensity === "Comfortable", "Settings behavior smoke: grid density did not persist to a fresh controller.")
            && assertCondition(probe.readerDefaultReadingMode === "2 pages", "Settings behavior smoke: reader default mode did not persist to a fresh controller.")
            && assertCondition(probe.readerMagnifierSize === "Large", "Settings behavior smoke: magnifier size did not persist to a fresh controller.")
            && assertCondition(probe.normalizedReaderViewMode("one_page") === "two_page", "Settings behavior smoke: persisted reader mode did not drive the expected live reader mode helper.")
        probe.destroy()
        return ok
    }

    function runPopupContractChecks() {
        dismissiblePopup.visible = true
        dismissiblePopup.dismissCount = 0
        popupController.handleManagedOutsideClick()
        if (!assertCondition(dismissiblePopup.dismissCount === 1 && dismissiblePopup.visible === false, "Popup contract checks: dismissible popup did not close from outside click.")) return false
        if (!assertCondition(dismissibleCloseBehavior.closeOnEscape === true && dismissibleCloseBehavior.closeOnOutside === true, "Popup contract checks: dismissible popup close policy no longer allows Escape/outside close.")) return false

        blockingPopup.visible = true
        blockingPopup.dismissCount = 0
        blockingPopup.focusCount = 0
        popupController.handleManagedOutsideClick()
        if (!assertCondition(blockingPopup.dismissCount === 0 && blockingPopup.focusCount === 1, "Popup contract checks: blocking popup stopped demanding explicit action on outside click.")) return false
        if (!assertCondition(blockingCloseBehavior.closeOnEscape === false && blockingCloseBehavior.closeOnOutside === false, "Popup contract checks: blocking popup close policy unexpectedly allows passive dismissal.")) return false

        const closeEvent = { accepted: true }
        if (!assertCondition(popupController.blockCloseAndHighlightCriticalPopup(closeEvent) === true, "Popup contract checks: critical close block did not activate.")) return false
        if (!assertCondition(closeEvent.accepted === false, "Popup contract checks: critical close block did not reject window close.")) return false
        if (!assertCondition(popupController.criticalPopupAttentionTarget === blockingPopup, "Popup contract checks: critical popup attention target was not assigned.")) return false

        blockingPopup.visible = false
        popupController.clearCriticalPopupAttention(blockingPopup)
        return true
    }

    function runNavigationHelperControlsChecks() {
        const alphaTitle = seriesTitleForKey(seed.alphaSeriesKey)
        rootState.selectSeries(seed.alphaSeriesKey, alphaTitle, rootState.indexForSeriesKey(seed.alphaSeriesKey))

        const continueTarget = reading.resolveContinueReadingTarget() || ({})
        if (!assertCondition(Boolean(continueTarget.ok), "Navigation helper controls: continue-reading target is unexpectedly missing.")) return false

        rootState.lastOpenedTarget = null
        navigation.continueReading()
        if (!assertCondition(Number((rootState.lastOpenedTarget || {}).comicId || 0) === Number(seed.alphaIssue1Id || 0), "Navigation helper controls: Continue reading opened the wrong issue.")) return false

        rootState.lastOpenedTarget = null
        navigation.nextUnread()
        if (!assertCondition(Number((rootState.lastOpenedTarget || {}).comicId || 0) === Number(seed.alphaIssue2Id || 0), "Navigation helper controls: Next unread opened the wrong issue.")) return false

        browse.refreshIssuesGridData(true)
        const beforeToggle = gridComicIds()
        navigation.toggleIssueOrder()
        const afterFirstToggle = gridComicIds()
        navigation.toggleIssueOrder()
        const afterSecondToggle = gridComicIds()
        if (!assertCondition(beforeToggle.length === afterFirstToggle.length && beforeToggle.length > 1, "Navigation helper controls: issue order test did not have enough visible issues.")) return false
        if (!assertCondition(beforeToggle[0] === afterFirstToggle[afterFirstToggle.length - 1], "Navigation helper controls: issue-order helper did not reverse the visible order.")) return false
        if (!assertCondition(arrayEquals(beforeToggle, afterSecondToggle), "Navigation helper controls: second issue-order toggle did not restore the original order.")) return false
        return true
    }

    function runSettingsVsLiveStateChecks() {
        settingsPrimary.readerShowBookmarkRibbonOnGridCovers = false
        settingsPrimary.appearanceGridDensity = "Compact"

        const probe = createSettingsProbe()
        if (!assertCondition(!!probe, "Settings vs live state checks: failed to create settings probe.")) return false

        const ok = assertCondition(probe.readerShowBookmarkRibbonOnGridCovers === false, "Settings vs live state checks: bookmark-ribbon state did not propagate through shared settings.")
            && assertCondition(probe.appearanceGridDensity === "Compact", "Settings vs live state checks: grid-density state did not propagate through shared settings.")
            && assertCondition(settingsPrimary.settingValue("appearance_grid_density", "") === "Compact", "Settings vs live state checks: controller helper no longer reflects the live grid-density state.")
            && assertCondition(settingsPrimary.settingValue("reader_show_bookmark_ribbon_on_grid_covers", true) === false, "Settings vs live state checks: controller helper no longer reflects the live bookmark-ribbon state.")
        probe.destroy()
        return ok
    }

    function runLibraryViewContractChecks() {
        const alphaTitle = seriesTitleForKey(seed.alphaSeriesKey)
        rootState.selectSeries(seed.alphaSeriesKey, alphaTitle, rootState.indexForSeriesKey(seed.alphaSeriesKey))

        modelRef.setSortMode("series_issue")
        browse.refreshIssuesGridData(true)
        const defaultOrder = gridComicIds()
        if (!assertCondition(defaultOrder.length >= 2, "Library view contract checks: expected at least two issues for sort verification.")) return false

        const sortError = String(modelRef.setSortMode("year_desc") || "")
        if (!assertCondition(sortError.length < 1, "Library view contract checks: year-desc sort mode was rejected.")) return false
        browse.refreshIssuesGridData(true)
        const yearOrder = gridComicIds()
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Library view contract checks: sort mode changed the selected series.")) return false
        if (!assertCondition(yearOrder[0] === Number(seed.alphaIssue2Id || 0), "Library view contract checks: year-desc sort did not move the newer issue first.")) return false

        settingsPrimary.appearanceGridDensity = "Default"
        const beforeDensity = gridComicIds()
        settingsPrimary.appearanceGridDensity = "Compact"
        browse.refreshIssuesGridData(true)
        const afterDensity = gridComicIds()
        if (!assertCondition(arrayEquals(beforeDensity, afterDensity), "Library view contract checks: grid-density change mutated the visible issue order.")) return false
        if (!assertCondition(rootState.selectedSeriesKey === String(seed.alphaSeriesKey || ""), "Library view contract checks: grid-density change drifted the selected series.")) return false
        return true
    }

    function runAll() {
        if (!assertCondition(!!modelRef, "Workstream 1 smoke: library model context is missing.")) return
        if (!assertCondition(Number(seed.alphaIssue1Id || 0) > 0, "Workstream 1 smoke: seed data is incomplete.")) return

        if (!runLibraryNavigationSmoke()) return
        if (!runReaderOpenCloseSmoke()) return
        if (!runMetadataSaveUiSmoke()) return
        if (!runSettingsBehaviorSmoke()) return
        if (!runPopupContractChecks()) return
        if (!runNavigationHelperControlsChecks()) return
        if (!runSettingsVsLiveStateChecks()) return
        if (!runLibraryViewContractChecks()) return

        pass()
    }

    QtObject {
        id: startupController

        function issueListsEquivalentByIdAndOrder(leftList, rightList) {
            const left = Array.isArray(leftList) ? leftList : []
            const right = Array.isArray(rightList) ? rightList : []
            if (left.length !== right.length) return false
            for (let i = 0; i < left.length; i += 1) {
                if (Number((left[i] || {}).id || 0) !== Number((right[i] || {}).id || 0)) {
                    return false
                }
            }
            return true
        }

        function requestSnapshotSave() {}
        function startupLog() {}
        function startupStep() {}
        function markStartupInteractive() {}
        function logStartupUiState() {}
    }

    QtObject {
        id: heroSeriesController
        function resolveHeroMediaForSelectedSeries() {}
        function refreshSeriesData() {}
    }

    QtObject {
        id: readerCoverController
        function clearCoverSourcesForComicIds() {}
    }

    QtObject {
        id: issuesGridRefreshDebounce
        function stop() {}
        function restart() {
            browse.refreshIssuesGridData(false)
        }
    }

    QtObject {
        id: issuesFlick
        property int lastPositionedIndex: -1
        function positionViewAtIndex(index, mode) {
            lastPositionedIndex = Number(index || -1)
        }
    }

    QtObject {
        id: mainLibraryPane
        property real heroCollapseOffset: 0
        property real currentSplitScroll: 0
    }

    ListModel {
        id: seriesListModel
    }

    ListModel {
        id: volumeListModel
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
        property string sidebarSearchText: ""
        property string librarySearchText: ""
        property string libraryReadStatusFilter: "all"
        property bool libraryLoading: false
        property bool startupSnapshotApplied: false
        property bool startupHydrationInProgress: false
        property bool startupReconcileCompleted: true
        property bool startupSnapshotLiveReloadRequested: false
        property int seriesMenuDismissToken: 0
        property var issuesGridData: []
        property var lastImportSessionComicIds: []
        property int clearSelectionCount: 0
        property int gridScrollToTopCount: 0
        property int readerOpenCount: 0
        property int selectedComicId: -1
        property var lastOpenedTarget: null
        property int lastOpenedComicId: -1
        property string lastOpenedTitle: ""
        property real lastSplitScrollRestore: 0

        function runtimeDebugLog() {}

        function applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle) {
            browse.applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle)
        }

        function currentSelectedSeriesContext() {
            return browse.currentSelectedSeriesContext()
        }

        function clearSelection() {
            clearSelectionCount += 1
            selectedComicId = -1
        }

        function setSelected(comicId, selected) {
            if (selected === true) {
                selectedComicId = Number(comicId || -1)
            }
        }

        function setGridScrollToTop() {
            gridScrollToTopCount += 1
        }

        function primeVisibleIssueCoverSourcesFromCache() {}
        function warmVisibleIssueThumbnails() {}
        function clearImportSeriesFocusState() {}
        function applyPendingImportedSeriesFocus() { return false }
        function applyConfiguredLaunchViewAfterRefreshIfNeeded() { return false }

        function scheduleGridSplitScrollRestore(value) {
            lastSplitScrollRestore = Number(value || 0)
        }

        function coverSourceForComic(comicId) {
            return ""
        }

        function refreshVolumeList() {
            browse.refreshVolumeList()
        }

        function refreshIssuesGridData(preserveSplitScroll) {
            browse.refreshIssuesGridData(preserveSplitScroll)
        }

        function scheduleIssuesGridRefresh(immediate, preserveSplitScroll) {
            browse.scheduleIssuesGridRefresh(immediate, preserveSplitScroll)
        }

        function indexForSeriesKey(seriesKey) {
            return seriesSelection.indexForSeriesKey(seriesKey)
        }

        function selectSeries(seriesKey, seriesTitle, indexValue) {
            seriesSelection.selectSeries(seriesKey, seriesTitle, indexValue)
            browse.refreshIssuesGridData(true)
        }

        function isSeriesSelected(seriesKey) {
            return seriesSelection.isSeriesSelected(seriesKey)
        }

        function openReaderTarget(target) {
            lastOpenedTarget = target
            readerOpenCount += 1
        }

        function openReader(comicId, title) {
            lastOpenedComicId = Number(comicId || -1)
            lastOpenedTitle = String(title || "")
            readerOpenCount += 1
        }
    }

    AppSettingsController {
        id: settingsPrimary
    }

    Component {
        id: settingsProbeComponent
        AppSettingsController {}
    }

    ReadingContinuationController {
        id: reading
        rootObject: rootState
        libraryModelRef: harness.modelRef
    }

    PopupController {
        id: popupController
        rootObject: rootState
        importConflictDialogRef: blockingPopup
        readerDialogRef: readerPopup
        actionResultDialogRef: dismissiblePopup
    }

    NavigationSurfaceController {
        id: navigation
        rootObject: rootState
        libraryModelRef: harness.modelRef
        popupControllerRef: popupController
        issuesFlick: issuesFlick
        readingContinuationControllerRef: reading
    }

    LibraryBrowseController {
        id: browse
        rootObject: rootState
        libraryModelRef: harness.modelRef
        startupControllerRef: startupController
        navigationSurfaceControllerRef: navigation
        readerCoverControllerRef: readerCoverController
        heroSeriesControllerRef: heroSeriesController
        seriesListModelRef: seriesListModel
        volumeListModelRef: volumeListModel
        mainLibraryPaneRef: mainLibraryPane
        issuesGridRefreshDebounceRef: issuesGridRefreshDebounce
    }

    SeriesSelectionController {
        id: seriesSelection
        rootObject: rootState
        seriesListModelRef: seriesListModel
        mainLibraryPaneRef: mainLibraryPane
    }

    QtObject {
        id: dismissiblePopup
        property bool visible: false
        property int closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
        property string debugName: "dismissible-popup"
        property int dismissCount: 0
        property int focusCount: 0

        function close() {
            dismissCount += 1
            visible = false
        }

        function forceActiveFocus() {
            focusCount += 1
        }
    }

    QtObject {
        id: blockingPopup
        property bool visible: false
        property int closePolicy: Popup.NoAutoClose
        property string debugName: "blocking-popup"
        property int dismissCount: 0
        property int focusCount: 0

        function close() {
            dismissCount += 1
            visible = false
        }

        function forceActiveFocus() {
            focusCount += 1
        }
    }

    QtObject {
        id: readerPopup
        property bool visible: false
        property int closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
        property string debugName: "reader-popup"
        property int dismissCount: 0

        function open() {
            visible = true
        }

        function close() {
            dismissCount += 1
            visible = false
        }
    }

    PopupCloseBehavior {
        id: dismissibleCloseBehavior
        closePolicy: dismissiblePopup.closePolicy
    }

    PopupCloseBehavior {
        id: blockingCloseBehavior
        closePolicy: blockingPopup.closePolicy
    }

    Component.onCompleted: Qt.callLater(runAll)
}
