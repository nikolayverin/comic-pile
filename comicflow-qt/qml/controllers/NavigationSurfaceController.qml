import QtQuick
import "../components/AppText.js" as AppText
import "../components/AppErrorMapper.js" as AppErrorMapper
import "../components/ReadingTarget.js" as ReadingTarget

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

    function traceContinueReading(message) {
        const root = rootObject
        if (root && typeof root.runtimeDebugLog === "function") {
            root.runtimeDebugLog("continue-reading", String(message || ""))
            return
        }
        if (!libraryModelRef || typeof libraryModelRef.appendStartupDebugLog !== "function") {
            return
        }
        libraryModelRef.appendStartupDebugLog("[continue-reading] " + String(message || ""))
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
            ? ReadingTarget.normalize(
                readingContinuationControllerRef.resolveContinueReadingTarget() || ({}),
                AppText.navigationNoActiveReadingSession
            )
            : ReadingTarget.invalidTarget(AppText.navigationNoActiveReadingSession)
    }

    function clearSeriesViewFilters() {
        const root = rootObject
        if (!root) return
        if (typeof root.applySelectedSeriesContext === "function") {
            const context = typeof root.currentSelectedSeriesContext === "function"
                ? root.currentSelectedSeriesContext()
                : (root.selectedSeriesContext || ({}))
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

    function openPendingIssueTargetDirectly(target) {
        const root = rootObject
        if (!root || !target) return false
        traceContinueReading(
            "open direct"
            + " comicId=" + String(target.comicId || -1)
            + " seriesKey=" + String(target.seriesKey || "")
            + " startPageIndex=" + String(target.startPageIndex || 0)
        )
        if (typeof root.openReaderTarget === "function") {
            root.openReaderTarget(target)
            return true
        }
        if (typeof root.openReader === "function") {
            root.openReader(
                Number(target.comicId || 0),
                String(target.displayTitle || target.title || "")
            )
            return true
        }
        return false
    }

    function revealIssueTargetInGrid(target) {
        const root = rootObject
        if (!root || !target) return false

        const targetComicId = Number(target.comicId || 0)
        const targetIndex = issueIndexInGrid(targetComicId)
        traceContinueReading(
            "reveal in grid"
            + " comicId=" + String(targetComicId)
            + " targetIndex=" + String(targetIndex)
            + " gridCount=" + String((root.issuesGridData || []).length || 0)
        )
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
                if (typeof root.openReaderTarget === "function") {
                    root.openReaderTarget(target)
                    return
                }
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
        const selectedContext = typeof root.currentSelectedSeriesContext === "function"
            ? root.currentSelectedSeriesContext()
            : (root.selectedSeriesContext || ({}))
        traceContinueReading(
            "resolve pending"
            + " comicId=" + String(pendingIssueTarget.comicId || -1)
            + " targetSeriesKey=" + targetSeriesKey
            + " selectedSeriesKey=" + String(selectedContext.seriesKey || "")
            + " attempts=" + String(pendingIssueResolveAttempts)
        )
        if (targetSeriesKey.length > 0
                && String(selectedContext.seriesKey || "").trim() !== targetSeriesKey) {
            pendingIssueResolveAttempts -= 1
            if (pendingIssueResolveAttempts > 0) {
                return false
            }
            if (Boolean(pendingIssueTarget.openReader) && openPendingIssueTargetDirectly(pendingIssueTarget)) {
                finishPendingIssueTarget()
                return true
            }
            return false
        }

        if (revealIssueTargetInGrid(pendingIssueTarget)) {
            return true
        }

        pendingIssueResolveAttempts -= 1
        if (pendingIssueResolveAttempts > 0) {
            return false
        }

        if (Boolean(pendingIssueTarget.openReader) && openPendingIssueTargetDirectly(pendingIssueTarget)) {
            finishPendingIssueTarget()
            return true
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
        pendingIssueTarget = target
            ? Object.assign(
                {},
                ReadingTarget.normalize(target, AppText.navigationRevealIssueUnavailable),
                {
                    openReader: Boolean(target.openReader),
                    failureTitle: String(target.failureTitle || AppText.popupActionErrorTitle),
                    failureMessage: String(target.failureMessage || AppText.navigationRevealIssueUnavailable)
                }
            )
            : null
        pendingIssueResolveAttempts = 12
        traceContinueReading(
            "queue reveal"
            + " comicId=" + String((pendingIssueTarget || {}).comicId || -1)
            + " seriesKey=" + String((pendingIssueTarget || {}).seriesKey || "")
            + " startPageIndex=" + String((pendingIssueTarget || {}).startPageIndex || 0)
        )
        pendingIssueResolveTimer.restart()
        tryResolvePendingIssueTarget()
    }

    function openIssueTarget(target, failureTitle, failureMessage) {
        const root = rootObject
        if (!root) return

        const normalizedTarget = ReadingTarget.normalize(
            target || ({}),
            failureMessage || AppText.navigationIssueUnavailable
        )
        const comicId = Number(normalizedTarget.comicId || 0)
        const seriesKey = String(normalizedTarget.seriesKey || "").trim()
        traceContinueReading(
            "open issue target"
            + " ok=" + String(Boolean(normalizedTarget.ok))
            + " comicId=" + String(comicId)
            + " seriesKey=" + seriesKey
            + " startPageIndex=" + String(normalizedTarget.startPageIndex || 0)
            + " currentPage=" + String(normalizedTarget.currentPage || 0)
            + " bookmarkPage=" + String(normalizedTarget.bookmarkPage || 0)
        )
        if (!Boolean(normalizedTarget.ok)) {
            showNavigationMessage(
                String(failureTitle || AppText.popupActionErrorTitle),
                String(normalizedTarget.message || failureMessage || AppText.navigationIssueUnavailable)
            )
            return
        }

        clearSeriesViewFilters()
        const seriesTitle = String(normalizedTarget.seriesTitle || "").trim()
        if (typeof root.selectSeries === "function") {
            root.selectSeries(seriesKey, seriesTitle, resolveSeriesIndex(seriesKey))
        }

        queueIssueTargetReveal({
            ok: true,
            comicId: normalizedTarget.comicId,
            anchorComicId: normalizedTarget.anchorComicId,
            seriesKey: normalizedTarget.seriesKey,
            seriesTitle: normalizedTarget.seriesTitle,
            displayTitle: normalizedTarget.displayTitle,
            title: normalizedTarget.title,
            startPageIndex: normalizedTarget.startPageIndex,
            currentPage: normalizedTarget.currentPage,
            bookmarkPage: normalizedTarget.bookmarkPage,
            hasBookmark: normalizedTarget.hasBookmark,
            hasProgress: normalizedTarget.hasProgress,
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
        traceContinueReading(
            "button continue"
            + " ok=" + String(Boolean(target.ok))
            + " comicId=" + String(target.comicId || -1)
            + " seriesKey=" + String(target.seriesKey || "")
            + " startPageIndex=" + String(target.startPageIndex || 0)
        )
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
            ? ReadingTarget.normalize(
                readingContinuationControllerRef.nextUnreadTarget() || ({}),
                AppText.navigationNoNextUnread
            )
            : ReadingTarget.invalidTarget(AppText.navigationNoNextUnread)
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
