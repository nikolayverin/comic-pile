import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../controllers"
import "ReaderPopupUtils.js" as ReaderPopupUtils

Popup {
    id: root

    UiTokens { id: uiTokens }
    ThemeColors { id: themeColors }
    PopupStyle { id: popupStyle }
    PopupMenuStyle { id: pageListMenuStyle }

    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose

    property real hostWidth: 0
    property real hostHeight: 0
    property string uiFontFamily: Qt.application.font.family
    property string issueTitle: ""
    property string imageSource: ""
    property var displayPages: []
    property string errorText: ""
    property bool loading: false
    property int pageIndex: 0
    property int pageCount: 0
    property bool canGoPreviousPage: false
    property bool canGoNextPage: false
    property bool mangaModeEnabled: false
    property bool canGoPreviousIssue: false
    property bool canGoNextIssue: false
    property bool bookmarkActive: false
    property int bookmarkPageIndex: -1
    property string readingViewMode: "one_page"
    property bool fullscreenMode: false
    property bool lightThemeEnabled: false
    property bool favoriteActive: false
    property bool actionNotificationsEnabled: true
    property bool inputSuspended: false
    property string magnifierSizePreset: "Medium"
    property alias magnifierModeEnabled: popupStateController.magnifierModeEnabled
    property alias magnifierOverlayVisible: popupStateController.magnifierOverlayVisible
    property alias magnifierCursorVisible: popupStateController.magnifierCursorVisible
    property alias magnifierSource: popupStateController.magnifierSource
    property alias magnifierSourceClipRect: popupStateController.magnifierSourceClipRect
    property alias magnifierOverlayX: popupStateController.magnifierOverlayX
    property alias magnifierOverlayY: popupStateController.magnifierOverlayY
    property alias magnifierCursorX: popupStateController.magnifierCursorX
    property alias magnifierCursorY: popupStateController.magnifierCursorY

    readonly property int outerMargin: fullscreenMode ? 0 : uiTokens.readerOuterMargin
    readonly property int panelRadius: fullscreenMode ? 0 : uiTokens.readerPanelRadius
    readonly property int toolbarHeight: uiTokens.readerToolbarHeight
    readonly property int footerBandHeight: uiTokens.readerFooterBandHeight
    readonly property int titleBlockWidth: uiTokens.readerTitleBlockWidth
    readonly property int titleFontPx: 13
    readonly property int issueArrowButtonSize: uiTokens.readerIssueArrowButtonSize
    readonly property int toolButtonWidth: uiTokens.readerToolButtonWidth
    readonly property int toolButtonHeight: uiTokens.readerToolButtonHeight
    readonly property int toolButtonRadius: uiTokens.readerToolButtonRadius
    readonly property int toolButtonSpacing: uiTokens.readerToolButtonSpacing
    readonly property int closeButtonSize: uiTokens.readerCloseButtonSize
    readonly property int closeIconSize: uiTokens.readerCloseIconSize
    readonly property int toolbarIconSize: uiTokens.readerToolbarIconSize
    readonly property int mangaButtonWidth: uiTokens.readerMangaButtonWidth
    readonly property int mangaButtonHeight: uiTokens.readerMangaButtonHeight
    readonly property int mangaIconWidth: uiTokens.readerMangaIconWidth
    readonly property int mangaIconHeight: uiTokens.readerMangaIconHeight
    readonly property real toolbarIconLeftEdgeInButton: (toolButtonWidth - toolbarIconSize) / 2
    readonly property real toolbarIconRightEdgeInButton: (toolButtonWidth + toolbarIconSize) / 2
    readonly property real mangaIconLeftEdgeInButton: (mangaButtonWidth - mangaIconWidth) / 2
    readonly property real mangaIconRightEdgeInButton: (mangaButtonWidth + mangaIconWidth) / 2
    readonly property int toolbarDeleteLeftInset: uiTokens.readerToolbarOuterActionInset
    readonly property int toolbarHotkeysLeftInset: toolbarDeleteLeftInset + toolbarIconSize + uiTokens.readerToolButtonWideSpacing
    readonly property int toolbarSettingsLeftInset: toolbarHotkeysLeftInset + toolbarIconSize + uiTokens.readerToolButtonSpacing
    readonly property int toolbarThemeLeftInset: toolbarSettingsLeftInset + toolbarIconSize + uiTokens.readerToolButtonSpacing
    readonly property int toolbarCopyRightInset: uiTokens.readerToolbarOuterActionInset
    readonly property int toolbarFavoritesRightInset: toolbarCopyRightInset + toolbarIconSize + uiTokens.readerToolButtonWideSpacing
    readonly property int toolbarBookmarkRightInset: toolbarFavoritesRightInset + toolbarIconSize + uiTokens.readerToolButtonSpacing
    readonly property int toolbarMagnifierRightInset: toolbarBookmarkRightInset + toolbarIconSize + uiTokens.readerToolButtonWideSpacing
    readonly property int toolbarFullScreenRightInset: toolbarMagnifierRightInset + toolbarIconSize + uiTokens.readerToolButtonSpacing
    readonly property int toolbarTwoPageRightInset: toolbarFullScreenRightInset + toolbarIconSize + uiTokens.readerToolButtonSpacing
    readonly property int toolbarOnePageRightInset: toolbarTwoPageRightInset + toolbarIconSize + uiTokens.readerToolButtonSpacing
    readonly property int toolbarMangaRightInset: toolbarOnePageRightInset + toolbarIconSize + uiTokens.readerToolButtonWideSpacing
    readonly property int sideButtonWidth: uiTokens.readerSideButtonWidth
    readonly property int sideButtonHeight: uiTokens.readerSideButtonHeight
    readonly property int sideButtonOffset: uiTokens.readerSideButtonOffset
    readonly property int sideButtonImageGap: uiTokens.readerSideButtonImageGap
    readonly property int sideButtonHoverRadius: uiTokens.readerSideButtonHoverRadius
    readonly property int counterMinWidth: uiTokens.readerCounterMinWidth
    readonly property int counterHeight: uiTokens.readerCounterHeight
    readonly property int counterBottomMargin: uiTokens.readerCounterBottomMargin
    readonly property int counterHorizontalPadding: uiTokens.readerCounterHorizontalPadding
    readonly property int readFromStartGap: uiTokens.readerFooterActionGap
    readonly property int readFromStartHorizontalPadding: uiTokens.readerFooterActionHorizontalPadding
    readonly property int listWidth: uiTokens.readerPageListWidth
    readonly property int listHeight: uiTokens.readerPageListHeight
    readonly property int listBodyHeight: uiTokens.readerPageListBodyHeight
    readonly property int listNotchWidth: uiTokens.readerPageListNotchWidth
    readonly property int listNotchHeight: uiTokens.readerPageListNotchHeight
    readonly property int listRadius: uiTokens.readerPageListRadius
    readonly property int listRowHoverWidth: 64
    readonly property int listRowHoverHeight: 18
    readonly property int listFontPx: uiTokens.readerPageListFontPx
    readonly property int listScrollGutterWidth: uiTokens.readerPageListScrollGutterWidth
    readonly property int listScrollThumbWidth: uiTokens.readerPageListScrollThumbWidth
    readonly property int listScrollThumbMinHeight: uiTokens.readerPageListScrollThumbMinHeight
    readonly property int listScrollThumbInset: uiTokens.readerPageListScrollThumbInset
    readonly property int pageListBottomImageGap: uiTokens.readerPageListBottomImageGap
    readonly property int pageListFadeDurationMs: uiTokens.readerPageListFadeDurationMs
    readonly property int bookmarkDecorationWidth: uiTokens.readerBookmarkDecorationWidth
    readonly property int bookmarkDecorationHeight: uiTokens.readerBookmarkDecorationHeight
    readonly property int bookmarkDecorationRightEdgeOffset: uiTokens.readerBookmarkDecorationRightEdgeOffset
    readonly property int bookmarkDecorationTopOffset: uiTokens.readerBookmarkDecorationTopOffset
    readonly property int magnifierBlockSize: {
        const preset = String(magnifierSizePreset || "Medium")
        if (preset === "Small") return uiTokens.readerMagnifierBlockSmall
        if (preset === "Large") return uiTokens.readerMagnifierBlockLarge
        return uiTokens.readerMagnifierBlockMedium
    }
    readonly property int magnifierBlockGap: uiTokens.readerMagnifierBlockGap
    readonly property int magnifierCursorSize: uiTokens.readerMagnifierCursorSize
    readonly property real magnifierZoomFactor: 2.4
    readonly property bool keyboardInputEnabled: root.visible && !root.inputSuspended
    readonly property var readerThemeDark: ({
        panelColor: themeColors.readerDarkPanelColor,
        chromeColor: themeColors.readerDarkChromeColor,
        textColor: themeColors.readerDarkTextColor,
        hoverFieldColor: themeColors.readerDarkHoverFieldColor,
        mutedTextColor: themeColors.readerDarkMutedTextColor,
        disabledColor: themeColors.readerDarkDisabledColor,
        errorColor: themeColors.readerDarkErrorColor,
        pageListFillColor: themeColors.readerDarkPageListFillColor,
        toolbarToggleActiveColor: themeColors.readerDarkToolbarToggleActiveColor,
        readingModeActiveColor: themeColors.readerDarkReadingModeActiveColor
    })
    readonly property var readerThemeLight: ({
        panelColor: themeColors.readerLightPanelColor,
        chromeColor: themeColors.readerLightChromeColor,
        textColor: themeColors.readerLightTextColor,
        hoverFieldColor: themeColors.readerLightHoverFieldColor,
        mutedTextColor: themeColors.readerLightMutedTextColor,
        disabledColor: themeColors.readerLightDisabledColor,
        errorColor: themeColors.readerLightErrorColor,
        pageListFillColor: themeColors.readerLightPageListFillColor,
        toolbarToggleActiveColor: themeColors.readerLightToolbarToggleActiveColor,
        readingModeActiveColor: themeColors.readerLightReadingModeActiveColor
    })
    readonly property var readerTheme: lightThemeEnabled ? readerThemeLight : readerThemeDark
    readonly property color panelColor: readerTheme.panelColor
    readonly property color chromeColor: readerTheme.chromeColor
    readonly property color textColor: readerTheme.textColor
    readonly property color hoverFieldColor: readerTheme.hoverFieldColor
    readonly property color mutedTextColor: readerTheme.mutedTextColor
    readonly property color disabledColor: readerTheme.disabledColor
    readonly property color errorColor: readerTheme.errorColor
    readonly property color pageListFillColor: readerTheme.pageListFillColor
    readonly property color toolbarToggleActiveColor: readerTheme.toolbarToggleActiveColor
    readonly property color readingModeActiveColor: readerTheme.readingModeActiveColor
    readonly property color actionToastTextColor: themeColors.textPrimary
    readonly property color pageListMenuFillColor: root.lightThemeEnabled
        ? root.pageListFillColor
        : pageListMenuStyle.backgroundColor
    readonly property color pageListMenuBorderColor: root.lightThemeEnabled
        ? root.panelColor
        : pageListMenuStyle.borderColor
    readonly property color pageListMenuHoverColor: root.lightThemeEnabled
        ? root.panelColor
        : pageListMenuStyle.hoverColor
    readonly property color pageListMenuScrollThumbColor: pageListMenuStyle.scrollThumbColor
    readonly property int pageAreaLeft: sideButtonOffset + sideButtonWidth + sideButtonImageGap
    readonly property int pageAreaRightInset: sideButtonOffset + sideButtonWidth + sideButtonImageGap
    readonly property int pageAreaTop: toolbarHeight
    readonly property int pageAreaBottomInset: footerBandHeight
    readonly property int actionToastRightMargin: 14 + Math.round((closeButtonSize - closeIconSize) / 2)
    readonly property string pageCounterText: ReaderPopupUtils.pageCounterText(pageCount, pageIndex, displayPages)
    readonly property var pageListMenuItems: ReaderPopupUtils.pageListMenuItems(pageCount, pageIndex)
    readonly property bool hasDisplayContent: ReaderPopupUtils.hasDisplayContent(displayPages, imageSource)
    property alias pageListVisible: popupStateController.pageListVisible
    property alias shortcutsPopupVisible: popupStateController.shortcutsPopupVisible
    property alias shortcutEntries: popupStateController.shortcutEntries

    signal dismissRequested()
    signal previousPageRequested()
    signal nextPageRequested()
    signal previousIssueRequested()
    signal nextIssueRequested()
    signal readingViewModeChangeRequested(string mode)
    signal bookmarkRequested()
    signal bookmarkJumpRequested()
    signal favoriteRequested()
    signal deletePageRequested(int pageIndex)
    signal mangaModeToggleRequested()
    signal settingsRequested()
    signal copyImageRequested()
    signal markAsReadRequested()
    signal readFromStartRequested()
    signal fullscreenToggleRequested()
    signal pageSelected(int pageIndex)
    signal themeToggleRequested()

    ReaderPopupStateController {
        id: popupStateController
        popupRoot: root
        pageViewportRef: pageViewport
        magnifierAreaRef: pageViewportMagnifierArea
    }

    popupType: Popup.Item
    x: outerMargin
    y: outerMargin
    width: Math.max(1, hostWidth - (outerMargin * 2))
    height: Math.max(1, hostHeight - (outerMargin * 2))

    function reject() {
        close()
    }

    function toggleFavorite() {
        favoriteRequested()
    }

    function toggleReadingViewMode() {
        popupStateController.toggleReadingViewMode()
    }

    function hideMagnifierOverlay() {
        popupStateController.hideMagnifierOverlay()
    }

    function toggleMagnifierMode() {
        popupStateController.toggleMagnifierMode()
        if (!actionNotificationsEnabled) return
        showActionToast(
            popupStateController.magnifierModeEnabled
                ? "Magnifier is enabled"
                : "Magnifier is disabled"
        )
    }

    function toggleFullscreenMode() {
        popupStateController.toggleFullscreenMode()
    }

    function dismissPageList() {
        if (pageListVisible) {
            pageListVisible = false
        }
    }

    function hideActionToast() {
        actionToastAnimation.stop()
        actionToast.opacity = 0
        actionToast.text = ""
    }

    function showActionToast(messageText) {
        const text = String(messageText || "").trim()
        if (!actionNotificationsEnabled || text.length < 1 || !root.visible) return
        actionToast.text = text
        actionToastAnimation.restart()
    }

    component HoverButton: Item {
        id: button

        property bool enabled: true
        property bool hovered: buttonMouse.containsMouse
        property bool active: false
        property bool showBackgroundWhenIdle: false
        property color backgroundColor: root.chromeColor
        property int cornerRadius: 6
        property color foregroundColor: button.enabled ? root.textColor : root.disabledColor
        default property alias contentData: buttonContent.data

        signal clicked()

        opacity: button.enabled ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: button.cornerRadius
            color: button.backgroundColor
            visible: button.showBackgroundWhenIdle || button.active || button.hovered
        }

        Item {
            id: buttonContent
            anchors.fill: parent
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                root.dismissPageList()
                button.clicked()
            }
        }
    }

    component PopupIconButton: ToolButton {
        id: button

        property bool activeState: false
        property bool clickEnabled: true
        property bool showActiveBackground: false
        property color activeIconColor: root.textColor
        property color idleIconColor: root.textColor
        property color unavailableIconColor: root.disabledColor
        property color hoverBackgroundColor: root.hoverFieldColor
        property real hoverCornerRadius: root.toolButtonRadius
        property bool mirrorIcon: false

        width: root.toolButtonWidth
        height: root.toolButtonHeight
        padding: 0
        hoverEnabled: true
        enabled: clickEnabled
        opacity: (clickEnabled || activeState) ? 1 : 0.45
        display: AbstractButton.IconOnly
        icon.width: root.toolbarIconSize
        icon.height: root.toolbarIconSize
        icon.color: activeState
            ? activeIconColor
            : (clickEnabled ? idleIconColor : unavailableIconColor)
        transform: Scale {
            origin.x: button.width / 2
            origin.y: button.height / 2
            xScale: button.mirrorIcon ? -1 : 1
        }

        background: Rectangle {
            anchors.fill: parent
            radius: button.hoverCornerRadius
            color: button.hoverBackgroundColor
            visible: button.hovered || (button.showActiveBackground && button.activeState)
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse
            cursorShape: button.clickEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        onPressedChanged: {
            if (pressed) {
                root.dismissPageList()
            }
        }
    }

    component ToolbarIconButton: PopupIconButton {
        width: root.toolButtonWidth
        height: root.toolButtonHeight
        hoverCornerRadius: root.toolButtonRadius
        icon.width: root.toolbarIconSize
        icon.height: root.toolbarIconSize
    }

    component BookmarkIcon: Canvas {
        property color strokeColor: root.textColor
        property color fillColor: "transparent"
        property real strokeWidth: 1.8

        contextType: "2d"
        onStrokeColorChanged: requestPaint()
        onFillColorChanged: requestPaint()
        onStrokeWidthChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = strokeWidth
            ctx.strokeStyle = strokeColor
            ctx.fillStyle = fillColor
            ctx.beginPath()
            ctx.moveTo(width * 0.22, height * 0.08)
            ctx.lineTo(width * 0.78, height * 0.08)
            ctx.lineTo(width * 0.78, height * 0.92)
            ctx.lineTo(width * 0.5, height * 0.72)
            ctx.lineTo(width * 0.22, height * 0.92)
            ctx.closePath()
            if (fillColor !== "transparent") {
                ctx.fill()
            }
            ctx.stroke()
        }
    }

    component CopyIcon: Canvas {
        property color strokeColor: root.textColor
        property real strokeWidth: 1.7

        contextType: "2d"
        onStrokeColorChanged: requestPaint()
        onStrokeWidthChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = strokeWidth
            ctx.strokeStyle = strokeColor

            function roundedRect(x, y, w, h, r) {
                ctx.beginPath()
                ctx.moveTo(x + r, y)
                ctx.lineTo(x + w - r, y)
                ctx.quadraticCurveTo(x + w, y, x + w, y + r)
                ctx.lineTo(x + w, y + h - r)
                ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
                ctx.lineTo(x + r, y + h)
                ctx.quadraticCurveTo(x, y + h, x, y + h - r)
                ctx.lineTo(x, y + r)
                ctx.quadraticCurveTo(x, y, x + r, y)
                ctx.closePath()
            }

            roundedRect(width * 0.34, height * 0.24, width * 0.5, height * 0.56, 2)
            ctx.stroke()
            roundedRect(width * 0.14, height * 0.04, width * 0.5, height * 0.56, 2)
            ctx.stroke()
        }
    }

    component CloseIcon: Canvas {
        property color strokeColor: root.textColor
        property real strokeWidth: 2

        contextType: "2d"
        onStrokeColorChanged: requestPaint()
        onStrokeWidthChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = strokeWidth
            ctx.strokeStyle = strokeColor
            ctx.beginPath()
            ctx.moveTo(width * 0.2, height * 0.2)
            ctx.lineTo(width * 0.8, height * 0.8)
            ctx.moveTo(width * 0.8, height * 0.2)
            ctx.lineTo(width * 0.2, height * 0.8)
            ctx.stroke()
        }
    }

    component InfoIcon: Canvas {
        property color fillColor: root.textColor

        contextType: "2d"
        onFillColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = fillColor

            const stemWidth = Math.max(2, width * 0.18)
            const stemHeight = height * 0.48
            const stemX = (width - stemWidth) / 2
            const stemY = height * 0.34
            const stemRadius = stemWidth / 2

            ctx.beginPath()
            ctx.moveTo(stemX + stemRadius, stemY)
            ctx.lineTo(stemX + stemWidth - stemRadius, stemY)
            ctx.quadraticCurveTo(stemX + stemWidth, stemY, stemX + stemWidth, stemY + stemRadius)
            ctx.lineTo(stemX + stemWidth, stemY + stemHeight - stemRadius)
            ctx.quadraticCurveTo(stemX + stemWidth, stemY + stemHeight, stemX + stemWidth - stemRadius, stemY + stemHeight)
            ctx.lineTo(stemX + stemRadius, stemY + stemHeight)
            ctx.quadraticCurveTo(stemX, stemY + stemHeight, stemX, stemY + stemHeight - stemRadius)
            ctx.lineTo(stemX, stemY + stemRadius)
            ctx.quadraticCurveTo(stemX, stemY, stemX + stemRadius, stemY)
            ctx.closePath()
            ctx.fill()

            const dotRadius = Math.max(1.5, width * 0.14)
            ctx.beginPath()
            ctx.arc(width / 2, height * 0.18, dotRadius, 0, Math.PI * 2)
            ctx.closePath()
            ctx.fill()
        }
    }

    component PageListNotch: Canvas {
        property color fillColor: root.pageListFillColor
        property color borderColor: "transparent"
        property int borderWidth: 0

        contextType: "2d"
        onFillColorChanged: requestPaint()
        onBorderColorChanged: requestPaint()
        onBorderWidthChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = fillColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width / 2, height)
            ctx.lineTo(width, 0)
            ctx.closePath()
            ctx.fill()
            if (borderWidth > 0 && borderColor !== "transparent") {
                ctx.beginPath()
                ctx.moveTo(0.5, 0.5)
                ctx.lineTo(width / 2, height - 0.5)
                ctx.lineTo(width - 0.5, 0.5)
                ctx.strokeStyle = borderColor
                ctx.lineWidth = borderWidth
                ctx.stroke()
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled
        onActivated: popupStateController.dismissWithEscape()
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible
            && (root.mangaModeEnabled ? root.canGoNextPage : root.canGoPreviousPage)
        onActivated: {
            if (root.mangaModeEnabled) {
                root.nextPageRequested()
                return
            }
            root.previousPageRequested()
        }
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible
            && (root.mangaModeEnabled ? root.canGoPreviousPage : root.canGoNextPage)
        onActivated: {
            if (root.mangaModeEnabled) {
                root.previousPageRequested()
                return
            }
            root.nextPageRequested()
        }
    }

    Shortcut {
        sequence: "PgUp"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible && root.canGoPreviousPage
        onActivated: root.previousPageRequested()
    }

    Shortcut {
        sequence: "PgDown"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible && root.canGoNextPage
        onActivated: root.nextPageRequested()
    }

    Shortcut {
        sequence: "A"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible && root.canGoPreviousIssue
        onActivated: root.previousIssueRequested()
    }

    Shortcut {
        sequence: "D"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible && root.canGoNextIssue
        onActivated: root.nextIssueRequested()
    }

    Shortcut {
        sequence: "B"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible && root.pageCount > 0
        onActivated: root.bookmarkRequested()
    }

    Shortcut {
        sequence: "F"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible
        onActivated: root.toggleFavorite()
    }

    Shortcut {
        sequence: "P"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible
        onActivated: root.toggleReadingViewMode()
    }

    Shortcut {
        sequence: "Z"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible
        onActivated: root.toggleMagnifierMode()
    }

    Shortcut {
        sequence: "S"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible && !root.shortcutsPopupVisible
        onActivated: root.toggleFullscreenMode()
    }

    Shortcut {
        sequence: "Ctrl+C"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled
            && !root.pageListVisible
            && !root.shortcutsPopupVisible
            && root.readingViewMode === "one_page"
            && root.imageSource.length > 0
        onActivated: root.copyImageRequested()
    }

    Shortcut {
        sequence: "M"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled
            && !root.pageListVisible
            && !root.shortcutsPopupVisible
            && root.pageCount > 0
        onActivated: root.markAsReadRequested()
    }

    Shortcut {
        sequence: "I"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled && !root.pageListVisible
        onActivated: popupStateController.toggleShortcutsPopup()
    }

    Shortcut {
        sequence: "1"
        context: Qt.ApplicationShortcut
        enabled: root.keyboardInputEnabled
            && !root.pageListVisible
            && !root.shortcutsPopupVisible
            && root.pageCount > 0
            && root.pageIndex > 0
        onActivated: root.readFromStartRequested()
    }

    Text {
        id: actionToast
        visible: opacity > 0
        opacity: 0
        z: 20
        anchors.right: parent.right
        anchors.rightMargin: root.actionToastRightMargin
        anchors.verticalCenter: markAsReadButton.verticalCenter

        text: ""
        color: root.actionToastTextColor
        font.family: root.uiFontFamily
        font.pixelSize: uiTokens.readerActionToastTextPx
        font.bold: true
    }

    SequentialAnimation {
        id: actionToastAnimation
        running: false

        NumberAnimation {
            target: actionToast
            property: "opacity"
            from: 0
            to: 0.82
            duration: 400
            easing.type: Easing.InOutQuad
        }
        PauseAnimation {
            duration: 1200
        }
        NumberAnimation {
            target: actionToast
            property: "opacity"
            from: 0.82
            to: 0
            duration: 400
            easing.type: Easing.InOutQuad
        }
    }

    onVisibleChanged: {
        if (!visible) {
            hideActionToast()
        }
    }

    onActionNotificationsEnabledChanged: {
        if (!actionNotificationsEnabled) {
            hideActionToast()
        }
    }

    Overlay.modal: Rectangle {
        color: popupStyle.overlayColor
    }

    background: Rectangle {
        radius: root.panelRadius
        color: root.panelColor
    }

    contentItem: Item {
        width: root.width
        height: root.height
        clip: false

        TapHandler {
            enabled: root.pageListVisible && root.pageCount > 0
            onTapped: function(eventPoint) {
                const pointX = Number(eventPoint.position.x || 0)
                const pointY = Number(eventPoint.position.y || 0)
                const insidePopup = pointX >= pageListPopup.x
                    && pointX <= (pageListPopup.x + pageListPopup.width)
                    && pointY >= pageListPopup.y
                    && pointY <= (pageListPopup.y + pageListPopup.height)
                if (!insidePopup) {
                    root.pageListVisible = false
                }
            }
        }

        Item {
            id: toolbar
            x: 0
            y: 0
            width: parent.width
            height: root.toolbarHeight

            Item {
                width: root.titleBlockWidth
                height: Math.max(root.toolButtonHeight, root.issueArrowButtonSize)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                PopupIconButton {
                    width: root.issueArrowButtonSize
                    height: root.issueArrowButtonSize
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    z: 1
                    visible: root.canGoPreviousIssue
                    clickEnabled: root.canGoPreviousIssue
                    hoverBackgroundColor: root.hoverFieldColor
                    hoverCornerRadius: root.toolButtonRadius
                    mirrorIcon: true
                    icon.width: uiTokens.readerIssueArrowIconWidth
                    icon.height: uiTokens.readerIssueArrowIconHeight
                    icon.source: uiTokens.readerIssueArrow
                    onClicked: root.previousIssueRequested()
                }

                PopupIconButton {
                    width: root.issueArrowButtonSize
                    height: root.issueArrowButtonSize
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    z: 1
                    visible: root.canGoNextIssue
                    clickEnabled: root.canGoNextIssue
                    hoverBackgroundColor: root.hoverFieldColor
                    hoverCornerRadius: root.toolButtonRadius
                    icon.width: uiTokens.readerIssueArrowIconWidth
                    icon.height: uiTokens.readerIssueArrowIconHeight
                    icon.source: uiTokens.readerIssueArrow
                    onClicked: root.nextIssueRequested()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.issueArrowButtonSize + 8
                    anchors.right: parent.right
                    anchors.rightMargin: root.issueArrowButtonSize + 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.issueTitle
                    color: root.textColor
                    font.family: root.uiFontFamily
                    font.pixelSize: root.titleFontPx
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            ToolbarIconButton {
                id: deletePageButton
                x: root.toolbarDeleteLeftInset - root.toolbarIconLeftEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                visible: root.readingViewMode !== "two_page"
                clickEnabled: root.pageCount > 1
                icon.source: uiTokens.readerDeletePageIcon
                onClicked: root.deletePageRequested(root.pageIndex)
            }

            ToolbarIconButton {
                id: settingsButton
                x: root.toolbarSettingsLeftInset - root.toolbarIconLeftEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                icon.source: uiTokens.readerSettingsIcon
                onClicked: root.settingsRequested()
            }

            ToolbarIconButton {
                id: themeToggleButton
                x: root.toolbarThemeLeftInset - root.toolbarIconLeftEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                icon.source: root.lightThemeEnabled
                    ? uiTokens.readerThemeSunIcon
                    : uiTokens.readerThemeMoonIcon
                onClicked: {
                    root.lightThemeEnabled = !root.lightThemeEnabled
                    root.themeToggleRequested()
                }
            }

            PopupIconButton {
                id: mangaModeButton
                width: root.mangaButtonWidth
                height: root.mangaButtonHeight
                x: parent.width - root.toolbarMangaRightInset - root.mangaIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                clickEnabled: true
                activeState: root.mangaModeEnabled
                activeIconColor: root.readingModeActiveColor
                idleIconColor: root.textColor
                unavailableIconColor: root.textColor
                icon.width: root.mangaIconWidth
                icon.height: root.mangaIconHeight
                icon.source: uiTokens.readerMangaIcon
                onClicked: root.mangaModeToggleRequested()
            }

            ToolbarIconButton {
                id: onePageModeButton
                x: parent.width - root.toolbarOnePageRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                clickEnabled: root.readingViewMode !== "one_page"
                activeState: root.readingViewMode === "one_page"
                activeIconColor: root.readingModeActiveColor
                icon.source: uiTokens.readerOnePageIcon
                onClicked: root.readingViewModeChangeRequested("one_page")
            }

            ToolbarIconButton {
                id: twoPageModeButton
                x: parent.width - root.toolbarTwoPageRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                clickEnabled: root.readingViewMode !== "two_page"
                activeState: root.readingViewMode === "two_page"
                activeIconColor: root.readingModeActiveColor
                icon.source: uiTokens.readerTwoPageIcon
                onClicked: root.readingViewModeChangeRequested("two_page")
            }

            ToolbarIconButton {
                id: fullScreenButton
                x: parent.width - root.toolbarFullScreenRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                activeState: root.fullscreenMode
                activeIconColor: root.readingModeActiveColor
                icon.source: uiTokens.readerFullScreenIcon
                onClicked: root.toggleFullscreenMode()
            }

            ToolbarIconButton {
                id: bookmarkButton
                x: parent.width - root.toolbarBookmarkRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                clickEnabled: root.pageCount > 0
                activeState: root.bookmarkActive
                activeIconColor: root.toolbarToggleActiveColor
                icon.source: uiTokens.readerBookmarkIcon
                onClicked: root.bookmarkRequested()
            }

            ToolbarIconButton {
                id: magnifierButton
                x: parent.width - root.toolbarMagnifierRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                activeState: root.magnifierModeEnabled
                activeIconColor: root.readingModeActiveColor
                icon.source: uiTokens.searchIcon
                onClicked: root.toggleMagnifierMode()
            }

            ToolbarIconButton {
                id: favoriteButton
                x: parent.width - root.toolbarFavoritesRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                activeState: root.favoriteActive
                activeIconColor: root.toolbarToggleActiveColor
                icon.source: uiTokens.readerFavoritesIcon
                onClicked: root.toggleFavorite()
            }

            ToolbarIconButton {
                id: copyButton
                x: parent.width - root.toolbarCopyRightInset - root.toolbarIconRightEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                clickEnabled: root.readingViewMode === "one_page" && root.imageSource.length > 0
                icon.source: uiTokens.readerCopyIcon
                onClicked: root.copyImageRequested()
            }

            ToolbarIconButton {
                id: infoButton
                x: root.toolbarHotkeysLeftInset - root.toolbarIconLeftEdgeInButton
                anchors.verticalCenter: parent.verticalCenter
                activeState: root.shortcutsPopupVisible
                showActiveBackground: true
                icon.source: uiTokens.popupInfoIcon
                onClicked: popupStateController.toggleShortcutsPopup()
            }

            HoverButton {
                width: root.closeButtonSize
                height: root.closeButtonSize
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                cornerRadius: width / 2
                backgroundColor: root.hoverFieldColor
                onClicked: root.dismissRequested()

                CloseIcon {
                    width: root.closeIconSize
                    height: root.closeIconSize
                    anchors.centerIn: parent
                    strokeColor: parent.parent.foregroundColor
                }
            }
        }

        ReaderShortcutsPopup {
            visible: root.shortcutsPopupVisible
            entries: root.shortcutEntries
            uiFontFamily: root.uiFontFamily
            panelColor: root.panelColor
            textColor: root.textColor
            hoverFieldColor: root.hoverFieldColor
            popupRadius: popupStyle.popupRadius
            closeButtonSize: popupStyle.closeButtonSize
            closeGlyphSize: popupStyle.closeGlyphSize
            closeTopMargin: popupStyle.closeTopMargin
            closeRightMargin: popupStyle.closeRightMargin
            onDismissRequested: popupStateController.shortcutsPopupVisible = false
        }

        Item {
            id: pageViewport
            x: root.pageAreaLeft
            y: root.pageAreaTop
            width: parent.width - root.pageAreaLeft - root.pageAreaRightInset
            height: parent.height - root.pageAreaTop - root.pageAreaBottomInset
            clip: true

            readonly property bool showsTwoPageSpread: root.readingViewMode === "two_page"
                && Array.isArray(root.displayPages)
                && root.displayPages.length > 1
            readonly property real displayedContentHeight: showsTwoPageSpread
                ? Number(twoPageDisplayGroup.height || 0)
                : Number(pageViewportImage.paintedHeight || 0)

            function clampValue(value, minimum, maximum) {
                return Math.max(minimum, Math.min(maximum, value))
            }

            function buildMagnifierTarget(displayX, displayY, displayWidth, displayHeight, source, sourceWidth, sourceHeight, localX, localY) {
                if (displayWidth <= 0 || displayHeight <= 0) return null
                if (sourceWidth <= 0 || sourceHeight <= 0) return null
                if (String(source || "").length === 0) return null
                if (localX < displayX || localX > displayX + displayWidth) return null
                if (localY < displayY || localY > displayY + displayHeight) return null

                return {
                    imageSource: String(source || ""),
                    sourceWidth: Number(sourceWidth || 0),
                    sourceHeight: Number(sourceHeight || 0),
                    displayX: Number(displayX || 0),
                    displayY: Number(displayY || 0),
                    displayWidth: Number(displayWidth || 0),
                    displayHeight: Number(displayHeight || 0)
                }
            }

            function buildMagnifierTargetForImage(imageItem, pageData, localX, localY) {
                const topLeft = imageItem.mapToItem(pageViewport, 0, 0)
                return buildMagnifierTarget(
                    Number(topLeft.x || 0),
                    Number(topLeft.y || 0),
                    Number(imageItem.width || 0),
                    Number(imageItem.height || 0),
                    String((pageData || {}).imageSource || ""),
                    Math.max(Number((pageData || {}).width || 0), Number(imageItem.sourceSize.width || 0)),
                    Math.max(Number((pageData || {}).height || 0), Number(imageItem.sourceSize.height || 0)),
                    localX,
                    localY
                )
            }

            function resolveMagnifierTarget(localX, localY) {
                if (pageViewport.showsTwoPageSpread) {
                    const leftTarget = buildMagnifierTargetForImage(
                        leftPageImage,
                        twoPageDisplayGroup.leftPage,
                        localX,
                        localY
                    )
                    if (leftTarget) return leftTarget

                    return buildMagnifierTargetForImage(
                        rightPageImage,
                        twoPageDisplayGroup.rightPage,
                        localX,
                        localY
                    )
                }

                const singlePage = Array.isArray(root.displayPages) ? (root.displayPages[0] || {}) : ({})
                const singleWidth = Number(pageViewportImage.paintedWidth || 0)
                const singleHeight = Number(pageViewportImage.paintedHeight || 0)
                const singleX = Math.round((pageViewport.width - singleWidth) / 2)
                const singleY = Math.round((pageViewport.height - singleHeight) / 2)

                return buildMagnifierTarget(
                    singleX,
                    singleY,
                    singleWidth,
                    singleHeight,
                    root.imageSource,
                    Math.max(Number(singlePage.width || 0), Number(pageViewportImage.sourceSize.width || 0)),
                    Math.max(Number(singlePage.height || 0), Number(pageViewportImage.sourceSize.height || 0)),
                    localX,
                    localY
                )
            }

            function updateMagnifier(localX, localY, pressed) {
                const target = root.magnifierModeEnabled
                    ? resolveMagnifierTarget(localX, localY)
                    : null

                root.magnifierCursorX = localX
                root.magnifierCursorY = localY
                root.magnifierCursorVisible = !!target

                if (!pressed || !target) {
                    root.hideMagnifierOverlay()
                    return
                }

                const sourcePerDisplayX = target.sourceWidth / target.displayWidth
                const sourcePerDisplayY = target.sourceHeight / target.displayHeight
                const clipWidth = clampValue(
                    Math.round((root.magnifierBlockSize / root.magnifierZoomFactor) * sourcePerDisplayX),
                    1,
                    Math.round(target.sourceWidth)
                )
                const clipHeight = clampValue(
                    Math.round((root.magnifierBlockSize / root.magnifierZoomFactor) * sourcePerDisplayY),
                    1,
                    Math.round(target.sourceHeight)
                )
                const relativeX = clampValue(
                    (localX - target.displayX) / target.displayWidth,
                    0,
                    1
                )
                const relativeY = clampValue(
                    (localY - target.displayY) / target.displayHeight,
                    0,
                    1
                )
                const centerX = relativeX * target.sourceWidth
                const centerY = relativeY * target.sourceHeight
                const clipX = clampValue(
                    Math.round(centerX - clipWidth / 2),
                    0,
                    Math.max(0, Math.round(target.sourceWidth) - clipWidth)
                )
                const clipY = clampValue(
                    Math.round(centerY - clipHeight / 2),
                    0,
                    Math.max(0, Math.round(target.sourceHeight) - clipHeight)
                )

                let overlayX = Math.round(localX - root.magnifierBlockSize - root.magnifierBlockGap)
                let overlayY = Math.round(localY - root.magnifierBlockSize - root.magnifierBlockGap)

                if (overlayX < 0) {
                    overlayX = Math.round(localX + root.magnifierBlockGap)
                }
                if (overlayY < 0) {
                    overlayY = Math.round(localY + root.magnifierBlockGap)
                }

                overlayX = clampValue(
                    overlayX,
                    0,
                    Math.max(0, pageViewport.width - root.magnifierBlockSize)
                )
                overlayY = clampValue(
                    overlayY,
                    0,
                    Math.max(0, pageViewport.height - root.magnifierBlockSize)
                )

                root.magnifierSource = target.imageSource
                root.magnifierSourceClipRect = Qt.rect(clipX, clipY, clipWidth, clipHeight)
                root.magnifierOverlayX = overlayX
                root.magnifierOverlayY = overlayY
                root.magnifierOverlayVisible = true
            }

            Image {
                id: pageViewportImage
                anchors.fill: parent
                source: root.imageSource
                asynchronous: true
                cache: false
                smooth: true
                fillMode: Image.PreserveAspectFit
                visible: !pageViewport.showsTwoPageSpread
            }

            Item {
                id: twoPageDisplayGroup
                visible: pageViewport.showsTwoPageSpread
                anchors.centerIn: parent

                readonly property var leftPage: Array.isArray(root.displayPages) ? (root.displayPages[0] || {}) : ({})
                readonly property var rightPage: Array.isArray(root.displayPages) ? (root.displayPages[1] || {}) : ({})
                readonly property real leftSourceWidth: Math.max(
                    Number(leftPage.width || 0),
                    Number(leftPageImage.sourceSize.width || 0)
                )
                readonly property real leftSourceHeight: Math.max(
                    Number(leftPage.height || 0),
                    Number(leftPageImage.sourceSize.height || 0)
                )
                readonly property real rightSourceWidth: Math.max(
                    Number(rightPage.width || 0),
                    Number(rightPageImage.sourceSize.width || 0)
                )
                readonly property real rightSourceHeight: Math.max(
                    Number(rightPage.height || 0),
                    Number(rightPageImage.sourceSize.height || 0)
                )
                readonly property real naturalGroupWidth: leftSourceWidth + rightSourceWidth
                readonly property real naturalGroupHeight: Math.max(leftSourceHeight, rightSourceHeight)
                readonly property real displayScale: {
                    if (naturalGroupWidth <= 0 || naturalGroupHeight <= 0) return 0
                    return Math.min(
                        pageViewport.width / naturalGroupWidth,
                        pageViewport.height / naturalGroupHeight
                    )
                }

                width: Math.max(0, Math.round(naturalGroupWidth * displayScale))
                height: Math.max(0, Math.round(naturalGroupHeight * displayScale))

                Image {
                    id: leftPageImage
                    x: 0
                    y: Math.round((parent.height - height) / 2)
                    width: Math.max(0, Math.round(twoPageDisplayGroup.leftSourceWidth * twoPageDisplayGroup.displayScale))
                    height: Math.max(0, Math.round(twoPageDisplayGroup.leftSourceHeight * twoPageDisplayGroup.displayScale))
                    source: String((twoPageDisplayGroup.leftPage || {}).imageSource || "")
                    asynchronous: true
                    cache: false
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }

                Image {
                    id: rightPageImage
                    x: leftPageImage.width
                    y: Math.round((parent.height - height) / 2)
                    width: Math.max(0, Math.round(twoPageDisplayGroup.rightSourceWidth * twoPageDisplayGroup.displayScale))
                    height: Math.max(0, Math.round(twoPageDisplayGroup.rightSourceHeight * twoPageDisplayGroup.displayScale))
                    source: String((twoPageDisplayGroup.rightPage || {}).imageSource || "")
                    asynchronous: true
                    cache: false
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }
            }

            MouseArea {
                id: pageViewportMagnifierArea
                anchors.fill: parent
                z: 4
                enabled: root.magnifierModeEnabled
                hoverEnabled: enabled
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: root.magnifierModeEnabled && root.magnifierCursorVisible
                    ? Qt.BlankCursor
                    : Qt.ArrowCursor
                onEntered: pageViewport.updateMagnifier(mouseX, mouseY, pressed)
                onPressed: function(mouse) {
                    pageViewport.updateMagnifier(mouse.x, mouse.y, true)
                }
                onReleased: function(mouse) {
                    pageViewport.updateMagnifier(mouse.x, mouse.y, false)
                }
                onCanceled: {
                    root.hideMagnifierOverlay()
                }
                onPositionChanged: function(mouse) {
                    pageViewport.updateMagnifier(mouse.x, mouse.y, pressed)
                }
                onExited: {
                    root.magnifierCursorVisible = false
                    root.hideMagnifierOverlay()
                }
            }

            Image {
                id: magnifierCursorShadowIcon
                visible: root.magnifierModeEnabled && root.magnifierCursorVisible
                x: Math.round(root.magnifierCursorX - width * 0.24)
                y: Math.round(root.magnifierCursorY - height * 0.2) + 1
                width: root.magnifierCursorSize
                height: root.magnifierCursorSize
                z: 5
                source: uiTokens.readerMagnifierCursorShadowIcon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Image {
                id: magnifierCursorIcon
                visible: root.magnifierModeEnabled && root.magnifierCursorVisible
                x: Math.round(root.magnifierCursorX - width * 0.24)
                y: Math.round(root.magnifierCursorY - height * 0.2)
                width: root.magnifierCursorSize
                height: root.magnifierCursorSize
                z: 6
                source: uiTokens.searchIcon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Item {
                id: magnifierOverlay
                visible: root.magnifierOverlayVisible
                x: root.magnifierOverlayX
                y: root.magnifierOverlayY
                width: root.magnifierBlockSize
                height: root.magnifierBlockSize
                z: 30

                Rectangle {
                    x: -1
                    y: -1
                    width: parent.width + 2
                    height: parent.height + 2
                    radius: 25
                    color: "transparent"
                    border.width: 1
                    border.color: "#000000"
                }

                Rectangle {
                    id: magnifierOverlayContent
                    anchors.fill: parent
                    radius: 24
                    color: root.panelColor

                    Canvas {
                        id: magnifierCanvas
                        anchors.fill: parent
                        antialiasing: true
                        renderStrategy: Canvas.Threaded

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        Connections {
                            target: root

                            function onMagnifierSourceChanged() {
                                if (String(root.magnifierSource || "").length > 0) {
                                    magnifierCanvas.loadImage(root.magnifierSource)
                                }
                                magnifierCanvas.requestPaint()
                            }

                            function onMagnifierSourceClipRectChanged() {
                                magnifierCanvas.requestPaint()
                            }
                        }

                        onImageLoaded: function() {
                            requestPaint()
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            const clipRect = root.magnifierSourceClipRect
                            const radius = 24

                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)

                            ctx.save()
                            ctx.beginPath()
                            ctx.moveTo(radius, 0)
                            ctx.lineTo(width - radius, 0)
                            ctx.quadraticCurveTo(width, 0, width, radius)
                            ctx.lineTo(width, height - radius)
                            ctx.quadraticCurveTo(width, height, width - radius, height)
                            ctx.lineTo(radius, height)
                            ctx.quadraticCurveTo(0, height, 0, height - radius)
                            ctx.lineTo(0, radius)
                            ctx.quadraticCurveTo(0, 0, radius, 0)
                            ctx.closePath()
                            ctx.clip()

                            ctx.fillStyle = root.panelColor
                            ctx.fillRect(0, 0, width, height)

                            if (String(root.magnifierSource || "").length > 0
                                    && clipRect.width > 0
                                    && clipRect.height > 0
                                    && isImageLoaded(root.magnifierSource)) {
                                ctx.drawImage(
                                    root.magnifierSource,
                                    clipRect.x,
                                    clipRect.y,
                                    clipRect.width,
                                    clipRect.height,
                                    0,
                                    0,
                                    width,
                                    height
                                )
                            }

                            ctx.restore()
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 3
                        border.color: "#4DFFFFFF"
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.loading && !root.hasDisplayContent
                text: "Loading..."
                color: root.textColor
                font.family: root.uiFontFamily
                font.pixelSize: root.listFontPx
            }

        }

        Item {
            id: readerBookmarkDecoration
            visible: root.bookmarkActive
                && root.bookmarkPageIndex >= 0
                && root.bookmarkPageIndex < root.pageCount
                && bookmarkVisibleHeight > 0
            width: root.bookmarkDecorationWidth
            height: bookmarkVisibleHeight
            x: Math.round((parent.width / 2) - root.bookmarkDecorationRightEdgeOffset - width)
            y: root.bookmarkDecorationTopOffset
            z: 7
            clip: true

            readonly property bool onCurrentDisplay: {
                const targetPageIndex = Number(root.bookmarkPageIndex)
                if (targetPageIndex < 0) return false

                const pages = Array.isArray(root.displayPages) ? root.displayPages : []
                for (let i = 0; i < pages.length; i += 1) {
                    const page = pages[i] || {}
                    if (Number(page.pageIndex) === targetPageIndex) {
                        return true
                    }
                }

                return Number(root.pageIndex) === targetPageIndex
            }

            readonly property int bookmarkVisibleHeight: {
                if (onCurrentDisplay) {
                    return root.bookmarkDecorationHeight
                }

                const displayedHeight = Math.max(0, Number(pageViewport.displayedContentHeight || 0))
                const topInset = displayedHeight > 0
                    ? Math.round((pageViewport.height - displayedHeight) / 2)
                    : 0
                const clipBottom = pageViewport.y + topInset
                return Math.max(
                    0,
                    Math.min(
                        root.bookmarkDecorationHeight,
                        Math.round(clipBottom - root.bookmarkDecorationTopOffset)
                    )
                )
            }

            Image {
                width: root.bookmarkDecorationWidth
                height: root.bookmarkDecorationHeight
                source: uiTokens.readerBookmarkDecoration
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: !readerBookmarkDecoration.onCurrentDisplay
                hoverEnabled: enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.bookmarkJumpRequested()
            }
        }

        PopupIconButton {
            id: previousPageButton
            width: root.sideButtonWidth
            height: root.sideButtonHeight
            x: root.sideButtonOffset
            y: Math.round((parent.height - height) / 2)
            hoverCornerRadius: root.sideButtonHoverRadius
            clickEnabled: root.mangaModeEnabled ? root.canGoNextPage : root.canGoPreviousPage
            hoverBackgroundColor: root.hoverFieldColor
            mirrorIcon: true
            icon.width: uiTokens.readerPageArrowIconWidth
            icon.height: uiTokens.readerPageArrowIconHeight
            icon.source: uiTokens.readerPageArrow
            onClicked: {
                if (root.mangaModeEnabled) {
                    root.nextPageRequested()
                    return
                }
                root.previousPageRequested()
            }
        }

        PopupIconButton {
            id: nextPageButton
            width: root.sideButtonWidth
            height: root.sideButtonHeight
            x: parent.width - root.sideButtonOffset - width
            y: Math.round((parent.height - height) / 2)
            hoverCornerRadius: root.sideButtonHoverRadius
            clickEnabled: root.mangaModeEnabled ? root.canGoPreviousPage : root.canGoNextPage
            hoverBackgroundColor: root.hoverFieldColor
            icon.width: uiTokens.readerPageArrowIconWidth
            icon.height: uiTokens.readerPageArrowIconHeight
            icon.source: uiTokens.readerPageArrow
            onClicked: {
                if (root.mangaModeEnabled) {
                    root.previousPageRequested()
                    return
                }
                root.nextPageRequested()
            }
        }

        Item {
            id: readFromStartButton
            visible: root.pageCount > 0
            width: Math.max(
                Math.ceil(readFromStartTextMetrics.advanceWidth) + (root.readFromStartHorizontalPadding * 2),
                root.counterMinWidth
            )
            height: root.counterHeight
            anchors.right: pageCounterButton.left
            anchors.rightMargin: root.readFromStartGap
            anchors.verticalCenter: pageCounterButton.verticalCenter

            HoverButton {
                id: readFromStartHoverButton
                anchors.fill: parent
                enabled: root.pageCount > 0 && root.pageIndex > 0
                cornerRadius: height / 2
                backgroundColor: root.hoverFieldColor
                onClicked: root.readFromStartRequested()

                Text {
                    anchors.centerIn: parent
                    text: "Read from start"
                    color: readFromStartHoverButton.foregroundColor
                    font.family: root.uiFontFamily
                    font.pixelSize: uiTokens.readerFooterActionTextPx
                    font.bold: true
                }
            }

            TextMetrics {
                id: readFromStartTextMetrics
                text: "Read from start"
                font.family: root.uiFontFamily
                font.pixelSize: uiTokens.readerFooterActionTextPx
                font.bold: true
            }
        }

        Item {
            id: markAsReadButton
            visible: root.pageCount > 0
            width: Math.max(
                Math.ceil(markAsReadTextMetrics.advanceWidth) + (root.readFromStartHorizontalPadding * 2),
                root.counterMinWidth
            )
            height: root.counterHeight
            anchors.left: pageCounterButton.right
            anchors.leftMargin: root.readFromStartGap
            anchors.verticalCenter: pageCounterButton.verticalCenter

            HoverButton {
                id: markAsReadHoverButton
                anchors.fill: parent
                enabled: root.pageCount > 0
                cornerRadius: height / 2
                backgroundColor: root.hoverFieldColor
                onClicked: root.markAsReadRequested()

                Text {
                    anchors.centerIn: parent
                    text: "Mark as read"
                    color: markAsReadHoverButton.foregroundColor
                    font.family: root.uiFontFamily
                    font.pixelSize: uiTokens.readerFooterActionTextPx
                    font.bold: true
                }
            }

            TextMetrics {
                id: markAsReadTextMetrics
                text: "Mark as read"
                font.family: root.uiFontFamily
                font.pixelSize: uiTokens.readerFooterActionTextPx
                font.bold: true
            }
        }

        Item {
            id: pageCounterButton
            visible: root.pageCount > 0
            width: Math.max(
                root.counterMinWidth,
                Math.ceil(pageCounterTextMetrics.advanceWidth) + (root.counterHorizontalPadding * 2)
            )
            height: root.counterHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.counterBottomMargin

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.hoverFieldColor
                opacity: pageCounterMouse.containsMouse || root.pageListVisible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: uiTokens.readerCounterFadeDurationMs }
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.pageCounterText
                color: root.textColor
                font.family: root.uiFontFamily
                font.pixelSize: uiTokens.readerCounterTextPx
                font.bold: true
            }

            TextMetrics {
                id: pageCounterTextMetrics
                text: root.pageCounterText
                font.family: root.uiFontFamily
                font.pixelSize: uiTokens.readerCounterTextPx
                font.bold: true
            }

            MouseArea {
                id: pageCounterMouse
                anchors.fill: parent
                enabled: root.pageCount > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: popupStateController.togglePageList()
            }
        }

        Item {
            id: pageListPopup
            visible: (root.pageListVisible && root.pageCount > 0) || opacity > 0
            opacity: (root.pageListVisible && root.pageCount > 0) ? 1 : 0
            width: root.listWidth
            height: root.listHeight
            anchors.horizontalCenter: pageCounterButton.horizontalCenter
            y: {
                const displayedHeight = Math.max(0, Number(pageViewport.displayedContentHeight || 0))
                const imageBottom = displayedHeight > 0
                    ? pageViewport.y + Math.round((pageViewport.height - displayedHeight) / 2) + displayedHeight
                    : pageViewport.y + pageViewport.height
                return Math.round(imageBottom - root.pageListBottomImageGap - height)
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.pageListFadeDurationMs
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: pageListBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.listBodyHeight
                radius: root.listRadius
                color: root.pageListMenuFillColor
                border.width: 1
                border.color: root.pageListMenuBorderColor
            }

            Rectangle {
                id: pageListMaskShape
                anchors.fill: pageListBody
                anchors.margins: 1
                radius: Math.max(0, root.listRadius - 1)
                color: "white"
            }

            ShaderEffectSource {
                id: pageListMaskSource
                anchors.fill: pageListMaskShape
                sourceItem: pageListMaskShape
                hideSource: true
                live: true
                visible: false
            }

            PopupMenuListView {
                id: pageListView
                anchors.left: pageListBody.left
                anchors.right: pageListBody.right
                anchors.top: pageListBody.top
                anchors.bottom: pageListBody.bottom
                anchors.margins: 1
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.listFontPx
                hoverColor: root.pageListMenuHoverColor
                textColor: root.textColor
                disabledTextColor: root.disabledColor
                rowHeight: pageListMenuStyle.rowHeight
                bodyRadius: root.listRadius
                centerText: true
                reserveScrollGutter: true
                scrollGutterWidth: root.listScrollGutterWidth
                scrollThumbWidth: root.listScrollThumbWidth
                scrollThumbMinHeight: root.listScrollThumbMinHeight
                scrollThumbInset: root.listScrollThumbInset
                scrollThumbColor: root.pageListMenuScrollThumbColor
                hoverFadeDurationMs: root.pageListFadeDurationMs
                menuItems: root.pageListMenuItems
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: pageListMaskSource
                    autoPaddingEnabled: false
                }

                onItemTriggered: function(index, item) {
                    const targetPageIndex = Number((item || {}).pageIndex || 0)
                    root.pageSelected(targetPageIndex)
                    root.pageListVisible = false
                }
            }

            PageListNotch {
                width: root.listNotchWidth
                height: root.listNotchHeight
                anchors.horizontalCenter: pageListBody.horizontalCenter
                anchors.top: pageListBody.bottom
                fillColor: root.pageListMenuFillColor
                borderColor: root.pageListMenuBorderColor
                borderWidth: 1
            }

            Rectangle {
                width: root.listNotchWidth + 2
                height: 2
                anchors.horizontalCenter: pageListBody.horizontalCenter
                anchors.top: pageListBody.bottom
                anchors.topMargin: -1
                color: root.pageListMenuFillColor
            }
        }
    }

    onPageListVisibleChanged: {
        if (pageListVisible && pageCount > 0) {
            Qt.callLater(function() {
                pageListView.positionViewAtIndex(pageIndex, ListView.Center)
            })
        }
    }

    onPageCountChanged: if (pageCount < 1) pageListVisible = false
}
