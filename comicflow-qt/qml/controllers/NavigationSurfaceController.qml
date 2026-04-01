import QtQuick
import "../components/AppText.js" as AppText
import "../components/AppErrorMapper.js" as AppErrorMapper

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var popupControllerRef: null
    property var appSettingsRef: null
    property var issuesFlick: null
    property var readingContinuationControllerRef: null

    property bool issueOrderDescending: false
    property var pendingIssueTarget: null
    property int pendingIssueResolveAttempts: 0
    readonly property bool continueReadingAvailable: readingContinuationControllerRef
        ? Boolean(readingContinuationControllerRef.continueReadingAvailable)
        : false

    readonly property string issueOrderButtonText: issueOrderDescending ? "9 \u2192 1" : "1 \u2192 9"

    function listCopy(items) {
        const copy = []
        const count = items && typeof items.length === "number"
            ? Math.max(0, Number(items.length))
            : 0
        for (let i = 0; i < count; i += 1) {
            copy.push(items[i])
        }
        return copy
    }

    function applyIssueOrder(items) {
        const orderedItems = listCopy(items)
        if (issueOrderDescending) {
            orderedItems.reverse()
        }
        return orderedItems
    }

    function showNavigationMessage(title, message) {
        if (!popupControllerRef || typeof popupControllerRef.showMappedActionResult !== "function") {
            return
        }
        popupControllerRef.showMappedActionResult(
            AppErrorMapper.navigationResult(
                String(title || AppText.popupActionErrorTitle).trim(),
                String(message || "").trim()
            )
        )
    }

    function resolveContinueReadingTarget() {
        return readingContinuationControllerRef
            && typeof readingContinuationControllerRef.resolveContinueReadingTarget === "function"
            ? (readingContinuationControllerRef.resolveContinueReadingTarget() || ({ ok: false, message: AppText.navigationNoActiveReadingSession }))
            : ({ ok: false, message: AppText.navigationNoActiveReadingSession })
    }

    function clearSeriesViewFilters() {
        const root = rootObject
        if (!root) return
        if (typeof root.applySelectedSeriesContext === "function") {
            const context = root.selectedSeriesContext || ({})
            root.applySelectedSeriesContext(
                String(context.seriesKey || ""),
                String(context.seriesTitle || ""),
                "__all__",
                AppText.libraryAllVolumes
            )
        } else {
            root.selectedVolumeKey = "__all__"
            root.selectedVolumeTitle = AppText.libraryAllVolumes
        }
        root.libraryReadStatusFilter = "all"
        root.librarySearchText = ""
    }

    function resolveSeriesIndex(seriesKey) {
        const root = rootObject
        if (!root || typeof root.indexForSeriesKey !== "function") {
            return -1
        }
        return Number(root.indexForSeriesKey(seriesKey) || -1)
    }

    function issueIndexInGrid(comicId) {
        const root = rootObject
        if (!root) return -1
        const items = root.issuesGridData || []
        const count = items && typeof items.length === "number"
            ? Math.max(0, Number(items.length))
            : 0
        for (let i = 0; i < count; i += 1) {
            const item = items[i] || {}
            if (Number(item.id || 0) === Number(comicId || 0)) {
                return i
            }
        }
        return -1
    }

    function finishPendingIssueTarget() {
        pendingIssueTarget = null
        pendingIssueResolveAttempts = 0
        pendingIssueResolveTimer.stop()
    }

    function revealIssueTargetInGrid(target) {
        const root = rootObject
        if (!root || !target) return false

        const targetComicId = Number(target.comicId || 0)
        const targetIndex = issueIndexInGrid(targetComicId)
        if (targetIndex < 0) {
            return false
        }

        if (typeof root.clearSelection === "function") {
            root.clearSelection()
        }
        if (typeof root.setSelected === "function") {
            root.setSelected(targetComicId, true)
        }
        if (typeof root.setGridScrollToTop === "function") {
            root.setGridScrollToTop()
        }
        if (issuesFlick && typeof issuesFlick.positionViewAtIndex === "function") {
            issuesFlick.positionViewAtIndex(targetIndex, GridView.Beginning)
        }

        const openReaderAfterReveal = Boolean(target.openReader)
        const displayTitle = String(target.displayTitle || target.title || "").trim()
        finishPendingIssueTarget()

        if (openReaderAfterReveal && typeof root.openReader === "function") {
            Qt.callLater(function() {
                root.openReader(targetComicId, displayTitle)
            })
        }
        return true
    }

    function tryResolvePendingIssueTarget() {
        if (!pendingIssueTarget) {
            finishPendingIssueTarget()
            return true
        }

        const root = rootObject
        if (!root) {
            finishPendingIssueTarget()
            return true
        }

        const targetSeriesKey = String(pendingIssueTarget.seriesKey || "").trim()
        const selectedContext = root.selectedSeriesContext || ({})
        if (targetSeriesKey.length > 0
                && String(selectedContext.seriesKey || "").trim() !== targetSeriesKey) {
            return false
        }

        if (revealIssueTargetInGrid(pendingIssueTarget)) {
            return true
        }

        pendingIssueResolveAttempts -= 1
        if (pendingIssueResolveAttempts > 0) {
            return false
        }

        const title = String(pendingIssueTarget.failureTitle || AppText.popupActionErrorTitle).trim()
        const message = String(
            pendingIssueTarget.failureMessage
                || AppText.navigationRevealIssueUnavailable
        ).trim()
        finishPendingIssueTarget()
        showNavigationMessage(title, message)
        return true
    }

    function queueIssueTargetReveal(target) {
        pendingIssueTarget = target || null
        pendingIssueResolveAttempts = 12
        pendingIssueResolveTimer.restart()
        tryResolvePendingIssueTarget()
    }

    function openIssueTarget(target, failureTitle, failureMessage) {
        const root = rootObject
        if (!root) return

        const comicId = Number((target || {}).comicId || 0)
        const seriesKey = String((target || {}).seriesKey || "").trim()
        if (comicId < 1 || seriesKey.length < 1) {
            showNavigationMessage(
                String(failureTitle || AppText.popupActionErrorTitle),
                String((target || {}).message || failureMessage || AppText.navigationIssueUnavailable)
            )
            return
        }

        clearSeriesViewFilters()
        const seriesTitle = String((target || {}).seriesTitle || "").trim()
        if (typeof root.selectSeries === "function") {
            root.selectSeries(seriesKey, seriesTitle, resolveSeriesIndex(seriesKey))
        }

        queueIssueTargetReveal({
            comicId: comicId,
            seriesKey: seriesKey,
            displayTitle: String((target || {}).displayTitle || "").trim(),
            openReader: true,
            failureTitle: String(failureTitle || AppText.popupActionErrorTitle),
            failureMessage: String(
                failureMessage
                    || AppText.navigationRevealIssueUnavailable
            )
        })
    }

    function continueReading() {
        if (!libraryModelRef) return

        const target = resolveContinueReadingTarget() || ({})
        if (!Boolean(target.ok)) {
            showNavigationMessage(
                AppText.navigationContinueReadingTitle,
                String(target.message || AppText.navigationNoActiveReadingSession)
            )
            return
        }

        openIssueTarget(
            target,
            AppText.navigationContinueReadingTitle,
            AppText.navigationContinueRevealFailure
        )
    }

    function nextUnread() {
        if (!libraryModelRef) return

        const continueTarget = resolveContinueReadingTarget() || ({})
        if (!Boolean(continueTarget.ok)) {
            showNavigationMessage(
                AppText.navigationNextUnreadTitle,
                String(continueTarget.message || AppText.navigationNoActiveReadingSession)
            )
            return
        }

        const target = readingContinuationControllerRef
            && typeof readingContinuationControllerRef.nextUnreadTarget === "function"
            ? (readingContinuationControllerRef.nextUnreadTarget() || ({}))
            : ({})
        if (!Boolean(target.ok)) {
            showNavigationMessage(
                AppText.navigationNextUnreadTitle,
                String(target.message || AppText.navigationNoNextUnread)
            )
            return
        }

        openIssueTarget(
            target,
            AppText.navigationNextUnreadTitle,
            AppText.navigationNextUnreadRevealFailure
        )
    }

    function toggleSeriesInfo() {
        if (!appSettingsRef) return
        appSettingsRef.appearanceShowHeroBlock = !Boolean(appSettingsRef.appearanceShowHeroBlock)
    }

    function toggleIssueOrder() {
        const root = rootObject
        issueOrderDescending = !issueOrderDescending
        if (!root) return
        if (typeof root.refreshIssuesGridData === "function") {
            root.refreshIssuesGridData(false)
            return
        }
        root.issuesGridData = applyIssueOrder(root.issuesGridData)
    }

    Timer {
        id: pendingIssueResolveTimer
        interval: 40
        repeat: true
        running: false
        onTriggered: {
            if (controller.tryResolvePendingIssueTarget()) {
                stop()
            }
        }
    }

    Connections {
        target: rootObject

        function onIssuesGridDataChanged() {
            controller.tryResolvePendingIssueTarget()
        }

        function onSelectedSeriesKeyChanged() {
            controller.tryResolvePendingIssueTarget()
        }
    }
}
