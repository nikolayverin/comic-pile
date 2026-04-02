import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    Typography { id: typography }
    UiTokens { id: uiTokens }
    ThemeColors { id: themeColors }
    PopupMenuStyle { id: popupMenuStyle }

    property color topColor: themeColors.bgTopbarStart
    property color bottomColor: themeColors.bgTopbarEnd
    property color dividerColor: themeColors.lineTopbarBottom
    property color topEdgeColor: themeColors.topbarTopEdgeColor
    property color textColor: themeColors.textPrimary
    property color mutedTextColor: themeColors.textMuted
    property color textShadowColor: themeColors.uiTextShadow
    property color menuTextIdleColor: themeColors.uiMenuIdleText
    property color menuTextActiveColor: themeColors.textPrimary
    property color menuPopupBackgroundColor: popupMenuStyle.backgroundColor
    property color menuPopupHoverColor: popupMenuStyle.hoverColor
    property color menuPopupTextColor: popupMenuStyle.textColor
    property color menuPopupDisabledTextColor: popupMenuStyle.disabledTextColor
    property color windowControlIdleColor: themeColors.topbarWindowControlIdleColor
    property color windowControlActiveColor: themeColors.topbarWindowControlActiveColor
    property color windowControlCloseHoverColor: themeColors.uiWindowControlCloseHover
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: typography.uiBasePx
    property bool importInProgress: false
    property string centerLabel: uiTokens.appTitle
    property bool isFullscreen: false

    property bool windowMaximized: false
    property bool windowResizeEnabled: true
    property var hostWindow: null
    property bool showWindowControls: true
    property int windowControlRightMargin: 8
    property int windowControlTopMargin: 8
    property int windowControlButtonWidth: 24
    property int windowControlButtonHeight: 16
    property int windowControlSpacing: 0
    property bool showStatusChip: false
    property string statusChipText: ""
    property color statusChipTextColor: themeColors.topbarStatusChipTextColor
    property color statusChipBorderColor: themeColors.topbarStatusChipBorderColor
    property color statusChipFillColor: themeColors.topbarStatusChipFillColor
    property int helperButtonsLeftMargin: 0
    property int helperButtonsBottomMargin: 8
    property int helperButtonsSpacing: 8
    property bool continueReadingEnabled: true
    property bool topMenuSessionActive: false
    property var activeTopMenuPopup: null
    property int windowCornerRadius: 14
    property real topEdgeFadeFraction: 0.04
    readonly property int windowControlClusterWidth: showWindowControls
        ? (windowControlButtonWidth * 3 + windowControlSpacing * 2)
        : 0

    signal addFilesRequested()
    signal addFolderRequested()
    signal addIssueRequested()
    signal refreshRequested()
    signal exitRequested()
    signal toggleFullscreenRequested()
    signal minimizeRequested()
    signal maximizeRestoreRequested()
    signal closeRequested()
    signal settingsRequested()
    signal aboutRequested()
    signal continueReadingRequested()
    signal nextUnreadRequested()
    signal seriesInfoRequested()
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: root.topColor }
        GradientStop { position: 1.0; color: root.bottomColor }
    }

    Canvas {
        id: topEdge
        visible: !root.windowMaximized && !root.isFullscreen
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(2, root.windowCornerRadius + 1)
        antialiasing: true
        contextType: "2d"
        z: 1

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w = Math.max(1, width)
            const h = Math.max(1, height)
            const px = 0.5
            const r = Math.max(0, Math.min(root.windowCornerRadius, (w - 1) / 2, h - 1))
            const fadeWidth = Math.max(1, Math.min(r + 2, w * root.topEdgeFadeFraction))
            const fadeStop = Math.max(0.001, Math.min(0.49, fadeWidth / w))

            const grad = ctx.createLinearGradient(0, 0, w, 0)
            grad.addColorStop(0.0, "transparent")
            grad.addColorStop(fadeStop, root.topEdgeColor)
            grad.addColorStop(1.0 - fadeStop, root.topEdgeColor)
            grad.addColorStop(1.0, "transparent")

            ctx.strokeStyle = grad
            ctx.lineWidth = 1
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.moveTo(px, r + px)
            ctx.quadraticCurveTo(px, px, r + px, px)
            ctx.lineTo(w - r - px, px)
            ctx.quadraticCurveTo(w - px, px, w - px, r + px)
            ctx.stroke()
        }

        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    MouseArea {
        z: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true
        onPressed: function(mouse) {
            if (mouse.button !== Qt.LeftButton) return
            if (!root.hostWindow) return
            if (!root.windowResizeEnabled && (root.windowMaximized || root.isFullscreen)) return
            root.hostWindow.startSystemMove()
        }
        onDoubleClicked: {
            if (!root.windowResizeEnabled) return
            root.maximizeRestoreRequested()
        }
    }

    component TopMenuTextButton: Item {
        id: topMenuButton
        property string labelText: ""
        property var menuPopup: null
        property bool triggerDirectAction: false
        readonly property bool menuOpen: topMenuButton.menuPopup
            && root.activeTopMenuPopup === topMenuButton.menuPopup
            && topMenuButton.menuPopup.visible
        readonly property bool active: menuOpen || hitArea.containsMouse || hitArea.pressed

        signal actionRequested()

        width: Math.ceil(mainText.implicitWidth)
        height: 16

        Text {
            id: shadowText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            y: topMenuButton.active ? 1 : -1
            text: topMenuButton.labelText
            color: root.textShadowColor
            font.pixelSize: root.uiFontPixelSize
            font.family: root.uiFontFamily
        }

        Text {
            id: mainText
            anchors.centerIn: parent
            text: topMenuButton.labelText
            color: topMenuButton.active ? root.menuTextActiveColor : root.menuTextIdleColor
            font.pixelSize: root.uiFontPixelSize
            font.family: root.uiFontFamily
        }

        MouseArea {
            id: hitArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (topMenuButton.triggerDirectAction) {
                    if (root.activeTopMenuPopup && root.activeTopMenuPopup.visible) {
                        root.activeTopMenuPopup.close()
                    }
                    root.activeTopMenuPopup = null
                    root.topMenuSessionActive = false
                    topMenuButton.actionRequested()
                    return
                }
                root.toggleTopMenuPopup(topMenuButton, topMenuButton.menuPopup)
            }
            onEntered: {
                if (topMenuButton.triggerDirectAction) return
                root.maybeSwitchTopMenuPopup(topMenuButton, topMenuButton.menuPopup)
            }
        }
    }

    component WindowControlButton: ToolButton {
        id: winBtn
        property string glyphType: "min"
        readonly property bool active: winBtn.enabled && (winBtn.hovered || winBtn.down)
        readonly property color frontColor: active
            ? (glyphType === "close" ? root.windowControlCloseHoverColor : root.windowControlActiveColor)
            : root.windowControlIdleColor

        width: root.windowControlButtonWidth
        height: root.windowControlButtonHeight
        opacity: winBtn.enabled ? 1 : 0.35
        hoverEnabled: true
        display: AbstractButton.IconOnly
        padding: 0

        icon.source: glyphType === "close"
            ? "qrc:/qt/qml/ComicPile/assets/icons/win-close.svg"
            : glyphType === "restore"
                ? "qrc:/qt/qml/ComicPile/assets/icons/win-restore.svg"
                : glyphType === "max"
                    ? "qrc:/qt/qml/ComicPile/assets/icons/win-max.svg"
                    : "qrc:/qt/qml/ComicPile/assets/icons/win-min.svg"
        icon.width: 12
        icon.height: 12
        icon.color: frontColor

        background: Item {}
    }

    Row {
        id: leftMenuRow
        z: 2
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 18

        TopMenuTextButton {
            id: fileTopMenuButton
            labelText: "File"
            menuPopup: fileMenuPopup
        }

        TopMenuTextButton {
            labelText: "Settings"
            triggerDirectAction: true
            onActionRequested: root.settingsRequested()
        }

        TopMenuTextButton {
            labelText: "Help"
            menuPopup: helpMenu
        }

    }

    Row {
        id: helperButtonsRow
        z: 2
        anchors.left: parent.left
        anchors.leftMargin: root.helperButtonsLeftMargin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.helperButtonsBottomMargin
        spacing: root.helperButtonsSpacing

        NavigationHelperButton {
            text: "Continue reading"
            fontFamily: root.uiFontFamily
            enabled: root.continueReadingEnabled
            onClicked: root.continueReadingRequested()
        }

        NavigationHelperButton {
            text: "Next unread"
            fontFamily: root.uiFontFamily
            onClicked: root.nextUnreadRequested()
        }

        NavigationHelperButton {
            text: "Show series Info"
            fontFamily: root.uiFontFamily
            onClicked: root.seriesInfoRequested()
        }
    }

    Item {
        id: centerTitleBlock
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.windowControlTopMargin
        width: Math.max(1, titleRow.implicitWidth)
        height: root.windowControlButtonHeight

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: 8

            Image {
                width: 16
                height: 16
                source: uiTokens.appTitleIcon
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: Math.max(1, titleText.implicitWidth)
                height: root.windowControlButtonHeight

                Text {
                    id: titleShadow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    y: 1
                    text: root.centerLabel
                    color: root.textShadowColor
                    font.pixelSize: root.uiFontPixelSize
                    font.family: root.uiFontFamily
                }

                Text {
                    id: titleText
                    anchors.centerIn: parent
                    text: root.centerLabel
                    color: root.menuTextActiveColor
                    font.pixelSize: root.uiFontPixelSize
                    font.family: root.uiFontFamily
                }
            }
        }
    }

    Item {
        id: windowControls
        visible: root.showWindowControls
        anchors.top: parent.top
        anchors.topMargin: root.windowControlTopMargin
        anchors.right: parent.right
        anchors.rightMargin: root.windowControlRightMargin
        width: root.windowControlClusterWidth
        height: root.windowControlButtonHeight
        z: 3

        Row {
            anchors.fill: parent
            spacing: root.windowControlSpacing

            WindowControlButton {
                glyphType: "min"
                onClicked: root.minimizeRequested()
            }

            WindowControlButton {
                glyphType: root.windowMaximized ? "restore" : "max"
                enabled: root.windowResizeEnabled
                onClicked: root.maximizeRestoreRequested()
            }

            WindowControlButton {
                glyphType: "close"
                onClicked: root.closeRequested()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.dividerColor
    }

    onTopEdgeColorChanged: topEdge.requestPaint()
    onWindowCornerRadiusChanged: topEdge.requestPaint()
    onTopEdgeFadeFractionChanged: topEdge.requestPaint()

    function openTopMenuPopup(anchorItem, popup) {
        if (!anchorItem || !popup) return
        const previousPopup = root.activeTopMenuPopup
        root.activeTopMenuPopup = popup
        root.topMenuSessionActive = true
        if (previousPopup && previousPopup !== popup && previousPopup.visible) {
            previousPopup.close()
        }
        if (typeof popup.openBelowItemCentered === "function") {
            popup.openBelowItemCentered(anchorItem, root)
            return
        }
        popup.openBelowItemLeftAligned(anchorItem, root)
    }

    function toggleTopMenuPopup(anchorItem, popup) {
        if (!anchorItem || !popup) return
        if (root.activeTopMenuPopup === popup && popup.visible) {
            root.activeTopMenuPopup = null
            root.topMenuSessionActive = false
            popup.close()
            return
        }
        openTopMenuPopup(anchorItem, popup)
    }

    function maybeSwitchTopMenuPopup(anchorItem, popup) {
        if (!root.topMenuSessionActive || !anchorItem || !popup) return
        if (root.activeTopMenuPopup === popup && popup.visible) return
        openTopMenuPopup(anchorItem, popup)
    }

    function handleTopMenuPopupVisibilityChanged(popup, visible) {
        if (!popup) return
        if (visible) {
            root.activeTopMenuPopup = popup
            root.topMenuSessionActive = true
            return
        }
        if (root.activeTopMenuPopup === popup) {
            root.activeTopMenuPopup = null
            root.topMenuSessionActive = false
        }
    }

    function dismissOpenMenus() {
        if (root.activeTopMenuPopup && root.activeTopMenuPopup.visible) {
            root.activeTopMenuPopup.close()
        }
        root.activeTopMenuPopup = null
        root.topMenuSessionActive = false
    }

    Rectangle {
        id: statusChip
        z: 3
        visible: (root.showStatusChip && root.statusChipText.length > 0) || opacity > 0
        opacity: (root.showStatusChip && root.statusChipText.length > 0) ? 1 : 0
        anchors.verticalCenter: centerTitleBlock.verticalCenter
        anchors.right: root.showWindowControls ? windowControls.left : parent.right
        anchors.rightMargin: 10
        color: root.statusChipFillColor
        border.width: 1
        border.color: root.statusChipBorderColor
        radius: 8
        width: Math.max(1, statusText.implicitWidth + 14)
        height: 18

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: statusText
            anchors.centerIn: parent
            text: root.statusChipText
            color: root.statusChipTextColor
            font.pixelSize: Math.max(10, root.uiFontPixelSize - 2)
            font.family: root.uiFontFamily
        }
    }

    ContextMenuPopup {
        id: fileMenuPopup
        parent: Overlay.overlay
        showArrow: true
        onVisibleChanged: root.handleTopMenuPopupVisibilityChanged(fileMenuPopup, visible)
        menuItems: [
            { text: "Add files", action: "add_files", enabled: !root.importInProgress },
            { text: "Add folder", action: "add_folder", enabled: !root.importInProgress },
            { text: "Exit", action: "exit" }
        ]
        onItemTriggered: function(index, action) {
            if (action === "add_files") {
                root.addFilesRequested()
            } else if (action === "add_folder") {
                root.addFolderRequested()
            } else if (action === "exit") {
                root.exitRequested()
            }
        }
    }

    ContextMenuPopup {
        id: helpMenu
        parent: Overlay.overlay
        showArrow: true
        onVisibleChanged: root.handleTopMenuPopupVisibilityChanged(helpMenu, visible)
        menuItems: [
            { text: "Help", action: "help", enabled: false },
            { text: "About", action: "about", enabled: true },
            { text: "What's new", action: "whats_new", enabled: false }
        ]
        onItemTriggered: function(index, action) {
            if (action === "about") {
                root.aboutRequested()
            }
        }
    }

}
