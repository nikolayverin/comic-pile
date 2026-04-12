import QtQuick
import QtQuick.Window

Item {
    id: telemetry
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var windowDisplayControllerRef: null
    property var seriesListModelRef: null
    property bool startupVisuallyStableLogged: false
    property bool startupWindowStateRestored: false
    property real startupLastLogAtMs: 0

    function startupLoggingEnabled() {
        const root = rootObject
        if (root && root.startupDebugLogsEnabled) return true
        return Boolean(
            libraryModelRef
                && typeof libraryModelRef.startupTextLogsEnabled === "function"
                && libraryModelRef.startupTextLogsEnabled()
        )
    }

    function startupLog(message) {
        const root = rootObject
        if (!root || !libraryModelRef || !startupLoggingEnabled()) return
        const now = Date.now()
        const elapsed = root.startupStartedAtMs > 0
            ? Math.max(0, Math.round(now - root.startupStartedAtMs))
            : 0
        const delta = startupLastLogAtMs > 0
            ? Math.max(0, Math.round(now - startupLastLogAtMs))
            : elapsed
        startupLastLogAtMs = now
        const line = "[startup][" + String(elapsed) + "ms][+" + String(delta) + "ms] " + String(message || "")
        console.log(line)
        libraryModelRef.appendStartupDebugLog(line)
    }

    function startupStep(stepName, details) {
        let message = "step=" + String(stepName || "")
        const detailsText = String(details || "").trim()
        if (detailsText.length > 0) {
            message += " " + detailsText
        }
        startupLog(message)
    }

    function trackingLog(message) {
        const root = rootObject
        if (!root || !libraryModelRef || !startupLoggingEnabled()) return
        const startedAtMs = Number(root.launchStartedAtMs || 0)
        const elapsedMs = startedAtMs > 0
            ? Math.max(0, Math.round(Date.now() - startedAtMs))
            : 0
        const line = "[window][" + String(elapsedMs) + "ms] " + String(message || "")
        console.log(line)
        libraryModelRef.appendStartupLog(line)
    }

    function logWindowTrackingState(tag) {
        const root = rootObject
        if (!root) return
        const trackedX = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedX || 0) : Number(root.x || 0)
        const trackedY = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedY || 0) : Number(root.y || 0)
        const trackedW = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedWidth || root.width || 0) : Number(root.width || 0)
        const trackedH = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedHeight || root.height || 0) : Number(root.height || 0)
        const token = windowDisplayControllerRef && typeof windowDisplayControllerRef.windowStateToken === "function"
            ? String(windowDisplayControllerRef.windowStateToken() || "")
            : ""
        const message =
            "windowTracking[" + String(tag || "") + "]"
            + " liveX=" + String(Math.round(Number(root.x || 0)))
            + " liveY=" + String(Math.round(Number(root.y || 0)))
            + " liveW=" + String(Math.round(Number(root.width || 0)))
            + " liveH=" + String(Math.round(Number(root.height || 0)))
            + " trackedX=" + String(Math.round(trackedX))
            + " trackedY=" + String(Math.round(trackedY))
            + " trackedW=" + String(Math.round(trackedW))
            + " trackedH=" + String(Math.round(trackedH))
            + " token=" + token
            + " restored=" + String(startupWindowStateRestored)
        startupLog(message)
        trackingLog(message)
    }

    function launchLog(message) {
        const root = rootObject
        if (!root || !libraryModelRef || !startupLoggingEnabled()) return
        const startedAtMs = Number(root.launchStartedAtMs || 0)
        const elapsedMs = startedAtMs > 0
            ? Math.max(0, Math.round(Date.now() - startedAtMs))
            : 0
        const line = "[launch][" + String(elapsedMs) + "ms] " + String(message || "")
        console.log(line)
        libraryModelRef.appendStartupLog(line)
    }

    function windowVisibilityLabel(visibilityValue) {
        if (visibilityValue === Window.Windowed) return "windowed"
        if (visibilityValue === Window.Maximized) return "maximized"
        if (visibilityValue === Window.FullScreen) return "fullscreen"
        if (visibilityValue === Window.Minimized) return "minimized"
        if (visibilityValue === Window.Hidden) return "hidden"
        if (visibilityValue === Window.AutomaticVisibility) return "automatic"
        return String(visibilityValue)
    }

    function shouldTraceWindowState() {
        const root = rootObject
        if (!root || !libraryModelRef) return false
        return !startupVisuallyStableLogged
    }

    function traceWindowState(tag, details) {
        const root = rootObject
        if (!root || !shouldTraceWindowState()) return

        let message = "window_trace tag=" + String(tag || "")
        const detailsText = String(details || "").trim()
        if (detailsText.length > 0) {
            message += " " + detailsText
        }
        message += " visible=" + String(root.visible)
        message += " visibility=" + windowVisibilityLabel(root.visibility)
        message += " x=" + String(Math.round(Number(root.x || 0)))
        message += " y=" + String(Math.round(Number(root.y || 0)))
        message += " w=" + String(Math.round(Number(root.width || 0)))
        message += " h=" + String(Math.round(Number(root.height || 0)))
        const windowedX = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedX || 0) : Number(root.x || 0)
        const windowedY = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedY || 0) : Number(root.y || 0)
        const windowedW = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedWidth || 0) : Number(root.width || 0)
        const windowedH = windowDisplayControllerRef ? Number(windowDisplayControllerRef.windowedHeight || 0) : Number(root.height || 0)
        message += " windowedX=" + String(Math.round(windowedX))
        message += " windowedY=" + String(Math.round(windowedY))
        message += " windowedW=" + String(Math.round(windowedW))
        message += " windowedH=" + String(Math.round(windowedH))
        launchLog(message)
    }

    function logStartupUiState(tag) {
        const root = rootObject
        if (!root) return
        startupLog(
            "ui_state " + String(tag || "")
            + " seriesCount=" + String(seriesListModelRef ? seriesListModelRef.count : 0)
            + " issuesCount=" + String((root.issuesGridData || []).length)
            + " selectedSeriesKey=" + String(root.selectedSeriesKey)
            + " libraryStateVisible=" + String(root.libraryStateVisible())
            + " hydrationInProgress=" + String(root.startupHydrationInProgress)
            + " reconcileCompleted=" + String(root.startupReconcileCompleted)
            + " visible=" + String(root.visible)
        )
    }
}
