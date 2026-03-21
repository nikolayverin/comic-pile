import QtQuick

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
    property bool pageListVisible: false
    property bool shortcutsPopupVisible: false
    property var shortcutEntries: [
        { "action": "Previous page", "keysText": "Left Arrow\nPage Up" },
        { "action": "Next page", "keysText": "Right Arrow\nPage Down" },
        { "action": "Previous issue", "keysText": "A" },
        { "action": "Next issue", "keysText": "D" },
        { "action": "Toggle bookmark", "keysText": "B" },
        { "action": "Toggle favorite", "keysText": "F" },
        { "action": "Switch reading mode", "keysText": "P" },
        { "action": "Toggle full screen", "keysText": "S" },
        { "action": "Toggle magnifier", "keysText": "Z" },
        { "action": "Copy one page", "keysText": "Ctrl+C" },
        { "action": "Mark as read", "keysText": "M" },
        { "action": "Toggle hotkeys", "keysText": "I" },
        { "action": "Read from start", "keysText": "1" },
        { "action": "Close reader", "keysText": "Esc" }
    ]

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
    }

    function handlePopupClosed() {
        pageListVisible = false
        shortcutsPopupVisible = false
        magnifierModeEnabled = false
    }

    onMagnifierModeEnabledChanged: refreshMagnifierState()

    Connections {
        target: popupRoot

        function onDisplayPagesChanged() { controller.refreshMagnifierState() }
        function onImageSourceChanged() { controller.refreshMagnifierState() }
        function onReadingViewModeChanged() { controller.refreshMagnifierState() }

        function onVisibleChanged() {
            if (!popupRoot.visible) {
                controller.magnifierModeEnabled = false
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
