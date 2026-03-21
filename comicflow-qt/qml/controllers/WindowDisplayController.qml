import QtQuick
import QtQuick.Window

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var startupControllerRef: null

    property int defaultWindowWidth: 1440
    property int defaultWindowHeight: 980
    property bool displayConstrainedWindow: false
    readonly property bool enableWindowResizeHandles: !displayConstrainedWindow
    readonly property int launchScreenAvailableWidth: Number(Screen.desktopAvailableWidth || 0)
    readonly property int launchScreenAvailableHeight: Number(Screen.desktopAvailableHeight || 0)

    property real windowedX: rootObject ? Number(rootObject.x || 0) : 0
    property real windowedY: rootObject ? Number(rootObject.y || 0) : 0
    property int windowedWidth: rootObject ? Number(rootObject.width || defaultWindowWidth) : defaultWindowWidth
    property int windowedHeight: rootObject ? Number(rootObject.height || defaultWindowHeight) : defaultWindowHeight
    property string deferredWindowStateToken: "windowed"
    property bool readerFullscreenWindowActive: false
    property string readerFullscreenRestoreStateToken: "windowed"
    property real readerFullscreenRestoreX: 0
    property real readerFullscreenRestoreY: 0
    property int readerFullscreenRestoreWidth: defaultWindowWidth
    property int readerFullscreenRestoreHeight: defaultWindowHeight

    function startupLog(message) {
        if (startupControllerRef && typeof startupControllerRef.startupLog === "function") {
            startupControllerRef.startupLog(message)
        }
    }

    function startupStep(stepName, details) {
        if (startupControllerRef && typeof startupControllerRef.startupStep === "function") {
            startupControllerRef.startupStep(stepName, details)
        }
    }

    function traceWindowState(tag, details) {
        if (startupControllerRef && typeof startupControllerRef.traceWindowState === "function") {
            startupControllerRef.traceWindowState(tag, details)
        }
    }

    function requestSnapshotSave() {
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
    }

    function shouldTrackWindowGeometry() {
        const root = rootObject
        if (!root) return false
        return root.visibility !== Window.Maximized
            && root.visibility !== Window.FullScreen
            && root.visibility !== Window.Minimized
    }

    function handleWindowXChanged() {
        const root = rootObject
        if (!root || !shouldTrackWindowGeometry()) return
        windowedX = root.x
        traceWindowState("x_changed")
        requestSnapshotSave()
    }

    function handleWindowYChanged() {
        const root = rootObject
        if (!root || !shouldTrackWindowGeometry()) return
        windowedY = root.y
        traceWindowState("y_changed")
        requestSnapshotSave()
    }

    function handleWindowWidthChanged() {
        const root = rootObject
        if (!root || !shouldTrackWindowGeometry()) return
        windowedWidth = root.width
        traceWindowState("width_changed")
        requestSnapshotSave()
    }

    function handleWindowHeightChanged() {
        const root = rootObject
        if (!root || !shouldTrackWindowGeometry()) return
        windowedHeight = root.height
        traceWindowState("height_changed")
        requestSnapshotSave()
    }

    function handleWindowVisibleChanged() {
        if (!rootObject) return
        traceWindowState("visible_changed")
    }

    function handleWindowVisibilityChanged() {
        const root = rootObject
        if (!root) return
        if (!shouldTrackWindowGeometry()) {
            traceWindowState("visibility_changed")
            return
        }
        windowedX = root.x
        windowedY = root.y
        windowedWidth = root.width
        windowedHeight = root.height
        traceWindowState("visibility_changed")
        requestSnapshotSave()
    }

    function currentWindowStateToken() {
        const root = rootObject
        if (!root) return "windowed"
        if (displayConstrainedWindow && root.visibility === Window.Maximized) {
            return "display_constrained_maximized"
        }
        if (root.visibility === Window.FullScreen) return "fullscreen"
        if (root.visibility === Window.Maximized) return "maximized"
        return "windowed"
    }

    function windowStateToken() {
        if (readerFullscreenWindowActive) {
            return String(readerFullscreenRestoreStateToken || "windowed")
        }
        return currentWindowStateToken()
    }

    function setReaderFullscreenMode(enabled) {
        const root = rootObject
        if (!root) return

        const nextValue = Boolean(enabled)
        if (nextValue === readerFullscreenWindowActive) return

        if (nextValue) {
            readerFullscreenRestoreStateToken = currentWindowStateToken()
            readerFullscreenRestoreX = Number(windowedX || root.x || 0)
            readerFullscreenRestoreY = Number(windowedY || root.y || 0)
            readerFullscreenRestoreWidth = Number(windowedWidth || root.width || defaultWindowWidth)
            readerFullscreenRestoreHeight = Number(windowedHeight || root.height || defaultWindowHeight)
            readerFullscreenWindowActive = true
            traceWindowState(
                "reader_fullscreen_enter",
                "restoreToken=" + readerFullscreenRestoreStateToken
                + " restoreX=" + String(Math.round(readerFullscreenRestoreX))
                + " restoreY=" + String(Math.round(readerFullscreenRestoreY))
                + " restoreW=" + String(Math.round(readerFullscreenRestoreWidth))
                + " restoreH=" + String(Math.round(readerFullscreenRestoreHeight))
            )
            root.showFullScreen()
            return
        }

        const restoreToken = String(readerFullscreenRestoreStateToken || "windowed")
        const restoreX = Number(readerFullscreenRestoreX || 0)
        const restoreY = Number(readerFullscreenRestoreY || 0)
        const restoreW = Number(readerFullscreenRestoreWidth || defaultWindowWidth)
        const restoreH = Number(readerFullscreenRestoreHeight || defaultWindowHeight)
        readerFullscreenWindowActive = false

        if (restoreToken === "fullscreen") {
            traceWindowState("reader_fullscreen_exit", "restoreToken=fullscreen")
            root.showFullScreen()
            return
        }

        if (restoreToken === "maximized" || restoreToken === "display_constrained_maximized") {
            traceWindowState("reader_fullscreen_exit", "restoreToken=" + restoreToken)
            root.showMaximized()
            return
        }

        const placement = placementForVisibleWindow(restoreX, restoreY, restoreW, restoreH)
        root.showNormal()
        root.width = placement.width
        root.height = placement.height
        root.x = placement.x
        root.y = placement.y
        windowedX = placement.x
        windowedY = placement.y
        windowedWidth = placement.width
        windowedHeight = placement.height
        traceWindowState(
            "reader_fullscreen_exit",
            "restoreToken=windowed"
            + " x=" + String(placement.x)
            + " y=" + String(placement.y)
            + " w=" + String(placement.width)
            + " h=" + String(placement.height)
        )
        requestSnapshotSave()
    }

    function preferredAvailableGeometry() {
        const root = rootObject
        const attachedWidth = launchScreenAvailableWidth
        const attachedHeight = launchScreenAvailableHeight
        if (attachedWidth > 0 && attachedHeight > 0) {
            return {
                x: 0,
                y: 0,
                width: attachedWidth,
                height: attachedHeight
            }
        }

        if (root && root.screen && root.screen.availableGeometry) {
            const rect = root.screen.availableGeometry
            return {
                x: Number(rect.x || 0),
                y: Number(rect.y || 0),
                width: Number(rect.width || 0),
                height: Number(rect.height || 0)
            }
        }

        const geometries = availableScreenGeometries()
        if (geometries.length > 0) {
            return geometries[0]
        }

        return {
            x: 0,
            y: 0,
            width: 0,
            height: 0
        }
    }

    function canFitDefaultWindowInRect(rect) {
        return Number(rect.width || 0) >= Number(defaultWindowWidth || 0)
            && Number(rect.height || 0) >= Number(defaultWindowHeight || 0)
    }

    function availableScreenGeometries() {
        const geometries = []
        const screens = (Qt.application && Qt.application.screens)
            ? Qt.application.screens
            : null
        const screenCount = screens && Number(screens.length || 0) > 0
            ? Number(screens.length || 0)
            : 0
        for (let i = 0; i < screenCount; i += 1) {
            const screen = screens[i]
            if (!screen || !screen.availableGeometry) continue
            const rect = screen.availableGeometry
            geometries.push({
                x: Number(rect.x || 0),
                y: Number(rect.y || 0),
                width: Number(rect.width || 0),
                height: Number(rect.height || 0)
            })
        }

        const root = rootObject
        if (geometries.length < 1 && root && root.screen && root.screen.availableGeometry) {
            const rect = root.screen.availableGeometry
            geometries.push({
                x: Number(rect.x || 0),
                y: Number(rect.y || 0),
                width: Number(rect.width || 0),
                height: Number(rect.height || 0)
            })
        }
        return geometries
    }

    function rectIntersectionArea(left, top, width, height, rect) {
        const x1 = Math.max(Number(left || 0), Number(rect.x || 0))
        const y1 = Math.max(Number(top || 0), Number(rect.y || 0))
        const x2 = Math.min(Number(left || 0) + Number(width || 0), Number(rect.x || 0) + Number(rect.width || 0))
        const y2 = Math.min(Number(top || 0) + Number(height || 0), Number(rect.y || 0) + Number(rect.height || 0))
        if (x2 <= x1 || y2 <= y1) return 0
        return (x2 - x1) * (y2 - y1)
    }

    function centeredPlacementInRect(rect, width, height) {
        const targetW = Math.max(1, Math.min(Number(width || 1), Number(rect.width || 1)))
        const targetH = Math.max(1, Math.min(Number(height || 1), Number(rect.height || 1)))
        return {
            x: Math.round(Number(rect.x || 0) + (Number(rect.width || 0) - targetW) / 2),
            y: Math.round(Number(rect.y || 0) + (Number(rect.height || 0) - targetH) / 2),
            width: Math.round(targetW),
            height: Math.round(targetH)
        }
    }

    function placementForVisibleWindow(savedX, savedY, savedW, savedH) {
        const root = rootObject
        if (!root) {
            return {
                x: Math.round(savedX),
                y: Math.round(savedY),
                width: Math.round(savedW),
                height: Math.round(savedH),
                fallback: false
            }
        }

        const screens = availableScreenGeometries()
        if (screens.length < 1) {
            return {
                x: Math.round(savedX),
                y: Math.round(savedY),
                width: Math.round(savedW),
                height: Math.round(savedH),
                fallback: false
            }
        }

        let bestRect = screens[0]
        let bestArea = -1
        for (let i = 0; i < screens.length; i += 1) {
            const rect = screens[i]
            const area = rectIntersectionArea(savedX, savedY, savedW, savedH, rect)
            if (area > bestArea) {
                bestArea = area
                bestRect = rect
            }
        }

        const minVisibleArea = Math.max(22500, Math.round(savedW * savedH * 0.12))
        if (bestArea >= minVisibleArea) {
            const clampedW = Math.max(root.minimumWidth, Math.min(Math.round(savedW), Math.round(bestRect.width)))
            const clampedH = Math.max(root.minimumHeight, Math.min(Math.round(savedH), Math.round(bestRect.height)))
            const minX = Math.round(bestRect.x)
            const minY = Math.round(bestRect.y)
            const maxX = Math.round(bestRect.x + bestRect.width - clampedW)
            const maxY = Math.round(bestRect.y + bestRect.height - clampedH)
            return {
                x: Math.max(minX, Math.min(Math.round(savedX), maxX)),
                y: Math.max(minY, Math.min(Math.round(savedY), maxY)),
                width: clampedW,
                height: clampedH,
                fallback: false
            }
        }

        const centered = centeredPlacementInRect(bestRect, savedW, savedH)
        centered.fallback = true
        return centered
    }

    function stampWindowState(snapshotObject) {
        const root = rootObject
        const target = snapshotObject && typeof snapshotObject === "object" ? snapshotObject : {}
        if (!root) return target
        target.windowState = windowStateToken()
        target.windowX = Number(windowedX || 0)
        target.windowY = Number(windowedY || 0)
        target.windowWidth = Number(windowedWidth || root.width)
        target.windowHeight = Number(windowedHeight || root.height)
        return target
    }

    function applyWindowSnapshot(parsed) {
        const root = rootObject
        if (!root) return
        const token = String(parsed.windowState || "windowed")
        const launchRect = preferredAvailableGeometry()
        const fitsDefaultWindow = canFitDefaultWindowInRect(launchRect)
        displayConstrainedWindow = !fitsDefaultWindow
        deferredWindowStateToken = token
        const savedX = Number(parsed.windowX)
        const savedY = Number(parsed.windowY)
        const savedW = Number(parsed.windowWidth)
        const savedH = Number(parsed.windowHeight)
        startupLog(
            "applyWindowSnapshot token=" + token
            + " x=" + String(savedX)
            + " y=" + String(savedY)
            + " w=" + String(savedW)
            + " h=" + String(savedH)
        )
        startupLog(
            "applyWindowSnapshot displayConstraint="
            + String(displayConstrainedWindow)
            + " availableW=" + String(Math.round(Number(launchRect.width || 0)))
            + " availableH=" + String(Math.round(Number(launchRect.height || 0)))
        )
        traceWindowState(
            "apply_window_snapshot_begin",
            "token=" + token
            + " savedX=" + String(savedX)
            + " savedY=" + String(savedY)
            + " savedW=" + String(savedW)
            + " savedH=" + String(savedH)
        )

        if (displayConstrainedWindow) {
            deferredWindowStateToken = "display_constrained_maximized"
            traceWindowState("apply_window_snapshot_deferred", "token=display_constrained_maximized")
            return
        }

        if (token === "windowed" || token === "display_constrained_maximized") {
            deferredWindowStateToken = "windowed"
            const targetW = Math.max(root.minimumWidth, Number(defaultWindowWidth || root.width))
            const targetH = Math.max(root.minimumHeight, Number(defaultWindowHeight || root.height))
            const hasSavedPosition = Number.isFinite(savedX) && Number.isFinite(savedY)
            const targetX = hasSavedPosition ? Math.floor(savedX) : root.x
            const targetY = hasSavedPosition ? Math.floor(savedY) : root.y
            const placement = hasSavedPosition
                ? placementForVisibleWindow(targetX, targetY, targetW, targetH)
                : centeredPlacementInRect(launchRect, targetW, targetH)
            if (placement.fallback) {
                startupLog(
                    "applyWindowSnapshot offscreen_fallback"
                    + " x=" + String(targetX)
                    + " y=" + String(targetY)
                    + " w=" + String(targetW)
                    + " h=" + String(targetH)
                    + " -> x=" + String(placement.x)
                    + " y=" + String(placement.y)
                )
            }
            root.width = placement.width
            root.height = placement.height
            root.x = placement.x
            root.y = placement.y
            windowedX = placement.x
            windowedY = placement.y
            windowedWidth = placement.width
            windowedHeight = placement.height
            traceWindowState("apply_window_snapshot_applied", "token=windowed")
            return
        }

        traceWindowState("apply_window_snapshot_deferred", "token=" + token)
    }

    function applyDeferredWindowState() {
        const root = rootObject
        if (!root) return
        traceWindowState("apply_deferred_window_state_begin", "token=" + deferredWindowStateToken)

        if (deferredWindowStateToken === "display_constrained_maximized") {
            startupStep("apply_deferred_window_state", "token=display_constrained_maximized")
            root.showMaximized()
            traceWindowState("show_requested", "token=display_constrained_maximized")
            return
        }

        if (deferredWindowStateToken === "fullscreen") {
            startupStep("apply_deferred_window_state", "token=fullscreen")
            root.showFullScreen()
            traceWindowState("show_requested", "token=fullscreen")
            return
        }

        if (deferredWindowStateToken === "maximized") {
            startupStep("apply_deferred_window_state", "token=maximized")
            root.showMaximized()
            traceWindowState("show_requested", "token=maximized")
            return
        }

        startupStep("apply_deferred_window_state", "token=windowed")
        root.show()
        traceWindowState("show_requested", "token=windowed")
    }
}
