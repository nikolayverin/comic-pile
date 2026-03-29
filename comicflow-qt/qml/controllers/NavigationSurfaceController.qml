import QtQuick

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

    property bool issueOrderDescending: false
    property var pendingIssueTarget: null
    property int pendingIssueResolveAttempts: 0
    property bool continueReadingAvailable: false

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
        if (!popupControllerRef || typeof popupControllerRef.showActionResult !== "function") {
            return
        }
        popupControllerRef.showActionResult(String(message || "").trim(), true)
        popupControllerRef.actionResultTitle = String(title || "Action Error").trim()
    }

    function resolveContinueReadingTarget() {
        if (!libraryModelRef) {
            return ({ ok: false, message: "No active reading session is available yet." })
        }

        const root = rootObject
        const rememberedComicId = root ? Number(root.continueReadingComicId || -1) : -1
        const rememberedSeriesKey = root
            ? String(root.continueReadingSeriesKey || "").trim()
            : ""
        if (rememberedComicId > 0 && typeof libraryModelRef.navigationTargetForComic === "function") {
            const rememberedTarget = libraryModelRef.navigationTargetForComic(rememberedComicId) || ({})
            if (Boolean(rememberedTarget.ok)) {
                const resolvedSeriesKey = String(rememberedTarget.seriesKey || "").trim()
                if (root
                        && resolvedSeriesKey.length > 0
                        && resolvedSeriesKey !== rememberedSeriesKey
                        && typeof root.rememberContinueReadingTarget === "function") {
                    root.rememberContinueReadingTarget(
                        Number(rememberedTarget.comicId || rememberedComicId),
                        resolvedSeriesKey,
                        String(rememberedTarget.displayTitle || rememberedTarget.title || "").trim()
                    )
                }
                return rememberedTarget
            }
            return {
                ok: false,
                message: "The last reading issue is no longer available."
            }
        }

        return {
            ok: false,
            message: "No active reading session is available yet."
        }
    }

    function refreshContinueReadingAvailability() {
        const target = resolveContinueReadingTarget() || ({})
        continueReadingAvailable = Boolean(target.ok)
    }

    function loadPersistedContinueReadingTarget() {
        const root = rootObject
        if (!root || !libraryModelRef || typeof libraryModelRef.readContinueReadingState !== "function") {
            refreshContinueReadingAvailability()
            return
        }

        const persistedState = libraryModelRef.readContinueReadingState() || ({})
        if (typeof root.rememberContinueReadingTarget === "function") {
            root.rememberContinueReadingTarget(
                Number(persistedState.comicId || -1),
                String(persistedState.seriesKey || ""),
                "",
                false
            )
        }
        refreshContinueReadingAvailability()
    }

    function clearSeriesViewFilters() {
        const root = rootObject
        if (!root) return
        root.selectedVolumeKey = "__all__"
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
        if (targetSeriesKey.length > 0
                && String(root.selectedSeriesKey || "").trim() !== targetSeriesKey) {
            return false
        }

        if (revealIssueTargetInGrid(pendingIssueTarget)) {
            return true
        }

        pendingIssueResolveAttempts -= 1
        if (pendingIssueResolveAttempts > 0) {
            return false
        }

        const title = String(pendingIssueTarget.failureTitle || "Action Error").trim()
        const message = String(
            pendingIssueTarget.failureMessage
                || "The requested issue could not be revealed in the library view."
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
                String(failureTitle || "Action Error"),
                String((target || {}).message || failureMessage || "The requested issue is unavailable.")
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
            failureTitle: String(failureTitle || "Action Error"),
            failureMessage: String(
                failureMessage
                    || "The requested issue could not be revealed in the library view."
            )
        })
    }

    function continueReading() {
        if (!libraryModelRef) return

        const target = resolveContinueReadingTarget() || ({})
        if (!Boolean(target.ok)) {
            showNavigationMessage(
                "Continue reading",
                String(target.message || "No active reading session is available yet.")
            )
            return
        }

        openIssueTarget(
            target,
            "Continue reading",
            "The saved reading target could not be opened from the library view."
        )
    }

    function nextUnread() {
        if (!libraryModelRef) return

        const continueTarget = resolveContinueReadingTarget() || ({})
        if (!Boolean(continueTarget.ok)) {
            showNavigationMessage(
                "Next unread",
                String(continueTarget.message || "No active reading session is available yet.")
            )
            return
        }

        const target = libraryModelRef.nextUnreadTarget(
            String(continueTarget.seriesKey || "").trim(),
            Number(continueTarget.comicId || -1)
        ) || ({})
        if (!Boolean(target.ok)) {
            showNavigationMessage(
                "Next unread",
                String(target.message || "No next unread issue is queued right now.")
            )
            return
        }

        openIssueTarget(
            target,
            "Next unread",
            "The next unread issue could not be opened from the library view."
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

        function onContinueReadingComicIdChanged() {
            controller.refreshContinueReadingAvailability()
        }

        function onIssuesGridDataChanged() {
            controller.tryResolvePendingIssueTarget()
        }

        function onSelectedSeriesKeyChanged() {
            controller.tryResolvePendingIssueTarget()
        }
    }

    Connections {
        target: libraryModelRef

        function onStatusChanged() {
            controller.refreshContinueReadingAvailability()
        }
    }

    Component.onCompleted: loadPersistedContinueReadingTarget()
}
