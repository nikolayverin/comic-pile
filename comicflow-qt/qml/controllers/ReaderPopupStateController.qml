import QtQuick
import "../components/AppText.js" as AppText

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var popupRoot: null
    property var pageViewportRef: null
    property var magnifierAreaRef: null
    property bool magnifierModeEnabled: false
    property bool magnifierOverlayVisible: false
    property bool magnifierCursorVisible: false
    property string magnifierSource: ""
    property rect magnifierSourceClipRect: Qt.rect(0, 0, 0, 0)
    property real magnifierOverlayX: 0
    property real magnifierOverlayY: 0
    property real magnifierCursorX: 0
    property real magnifierCursorY: 0
    property bool pageZoomActive: false
    property bool pageZoomPinned: false
    property real pageZoomPanX: 0
    property real pageZoomPanY: 0
    property bool pageListVisible: false
    property bool shortcutsPopupVisible: false
    readonly property string textLanguage: popupRoot ? String(popupRoot.textLanguage || AppText.fallbackLanguageCode) : AppText.fallbackLanguageCode
    readonly property var shortcutEntries: [
        { "action": localizedText("readerShortcutPreviousPage"), "keysText": "Left Arrow\nPage Up" },
        { "action": localizedText("readerShortcutNextPage"), "keysText": "Right Arrow\nPage Down" },
        { "action": localizedText("readerShortcutPreviousIssue"), "keysText": "A" },
        { "action": localizedText("readerShortcutNextIssue"), "keysText": "D" },
        { "action": localizedText("readerShortcutToggleBookmark"), "keysText": "B" },
        { "action": localizedText("readerShortcutToggleFavorite"), "keysText": "F" },
        { "action": localizedText("readerShortcutSwitchReadingMode"), "keysText": "P" },
        { "action": localizedText("readerShortcutToggleFullScreen"), "keysText": "S" },
        { "action": localizedText("readerShortcutToggleZoomTool"), "keysText": "Z" },
        { "action": localizedText("readerShortcutTogglePageZoom"), "keysText": "Space" },
        { "action": localizedText("readerShortcutCopyOnePage"), "keysText": "Ctrl+C" },
        { "action": localizedText("readerMarkAsRead"), "keysText": "M" },
        { "action": localizedText("readerShortcutToggleHotkeys"), "keysText": "I" },
        { "action": localizedText("readerReadFromStart"), "keysText": "1" },
        { "action": localizedText("readerShortcutCloseReader"), "keysText": "Esc" }
    ]

    function localizedText(key) {
        return AppText.t(key, textLanguage)
    }

    function toggleReadingViewMode() {
        if (!popupRoot) return
        popupRoot.readingViewModeChangeRequested(
            String(popupRoot.readingViewMode || "one_page") === "one_page"
                ? "two_page"
                : "one_page"
        )
    }

    function hideMagnifierOverlay() {
        magnifierOverlayVisible = false
        magnifierSource = ""
        magnifierSourceClipRect = Qt.rect(0, 0, 0, 0)
    }

    function refreshMagnifierState() {
        if (!magnifierModeEnabled) {
            magnifierCursorVisible = false
            hideMagnifierOverlay()
            return
        }

        if (magnifierAreaRef && magnifierAreaRef.containsMouse && pageViewportRef) {
            pageViewportRef.updateMagnifier(
                magnifierAreaRef.mouseX,
                magnifierAreaRef.mouseY,
                magnifierAreaRef.pressed
            )
            return
        }

        magnifierCursorVisible = false
        hideMagnifierOverlay()
    }

    function toggleMagnifierMode() {
        magnifierModeEnabled = !magnifierModeEnabled
        if (!magnifierModeEnabled && !pageZoomPinned) {
            resetPageZoom()
        }
    }

    function setPageZoomPan(x, y) {
        pageZoomPanX = Number(x || 0)
        pageZoomPanY = Number(y || 0)
    }

    function activatePageZoom(pinned) {
        pageZoomActive = true
        pageZoomPinned = Boolean(pinned)
    }

    function endTemporaryPageZoom() {
        if (!pageZoomPinned) {
            resetPageZoom()
        }
    }

    function resetPageZoom() {
        pageZoomActive = false
        pageZoomPinned = false
        pageZoomPanX = 0
        pageZoomPanY = 0
    }

    function toggleFullscreenMode() {
        if (popupRoot) {
            popupRoot.fullscreenToggleRequested()
        }
    }

    function toggleShortcutsPopup() {
        pageListVisible = false
        shortcutsPopupVisible = !shortcutsPopupVisible
    }

    function togglePageList() {
        shortcutsPopupVisible = false
        pageListVisible = !pageListVisible
    }

    function dismissWithEscape() {
        if (shortcutsPopupVisible) {
            shortcutsPopupVisible = false
        } else if (pageListVisible) {
            pageListVisible = false
        } else if (popupRoot) {
            popupRoot.dismissRequested()
        }
    }

    function resetForNextIssue() {
        pageListVisible = false
        shortcutsPopupVisible = false
        resetPageZoom()
    }

    function handlePopupClosed() {
        pageListVisible = false
        shortcutsPopupVisible = false
        magnifierModeEnabled = false
        resetPageZoom()
    }

    onMagnifierModeEnabledChanged: refreshMagnifierState()

    Connections {
        target: popupRoot

        function onDisplayPagesChanged() {
            controller.resetPageZoom()
            controller.refreshMagnifierState()
        }
        function onImageSourceChanged() {
            controller.resetPageZoom()
            controller.refreshMagnifierState()
        }
        function onReadingViewModeChanged() {
            controller.resetPageZoom()
            controller.refreshMagnifierState()
        }
        function onPageIndexChanged() { controller.resetPageZoom() }

        function onVisibleChanged() {
            if (!popupRoot.visible) {
                controller.magnifierModeEnabled = false
                controller.resetPageZoom()
            }
        }

        function onIssueTitleChanged() {
            controller.resetForNextIssue()
        }

        function onPageCountChanged() {
            if (Number(popupRoot.pageCount || 0) < 1) {
                controller.pageListVisible = false
            }
        }

        function onClosed() {
            controller.handlePopupClosed()
        }
    }
}
