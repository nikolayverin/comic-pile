import QtQuick
import QtQuick.Controls
import "IssueNumberText.js" as IssueNumberText

Rectangle {
    id: root

    Typography { id: typography }
    UiTokens { id: uiTokens }
    ThemeColors { id: themeColors }

    property int comicId: -1
    property string issueNumber: ""
    property string issueTitle: ""
    property string fallbackTitle: ""
    property string coverSource: ""
    property bool hasBookmark: false
    property bool showBookmarkRibbon: true
    property string readStatus: "unread"
    property bool selected: false
    property color cardColor: themeColors.cardBg
    property color textPrimary: themeColors.textPrimary
    property color textMuted: themeColors.textMuted
    property color hoverOverlayColor: themeColors.cardHoverOverlay
    property color selectedOverlayColor: themeColors.cardSelectedOverlay
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: typography.uiBasePx
    property color textShadowColor: themeColors.uiTextShadow
    property color actionMenuBackgroundColor: themeColors.fieldFillColor
    property color actionMenuHoverColor: themeColors.uiActionHoverBackground
    property color openingOverlayColor: themeColors.readerLoadingChipBgColor
    property bool hoverUiEnabled: true
    property bool actionMenuSuppressed: false
    property int actionMenuHoldDelayMs: 0
    property Item actionMenuBoundsItem: null
    property bool actionMenuDismissed: false
    property bool openingInProgress: false
    property bool actionMenuInteractionRetained: false

    readonly property bool coverHovered: root.hoverUiEnabled && coverHoverHandler.hovered
    readonly property bool menuHovered: root.hoverUiEnabled
        && hoverActionBarLoader.item !== null
        && hoverActionBarLoader.item.pointerInteractionActive
    readonly property bool hoverRetained: root.hoverUiEnabled && actionMenuHoldTimer.running
    readonly property bool effectiveHover: root.hoverUiEnabled && (coverHovered || menuHovered || hoverRetained)
    readonly property bool hasReadyCover: root.coverSource.length > 0 && coverImage.status === Image.Ready
    readonly property bool coverHoverVisible: effectiveHover && root.readStatus !== "read" && hasReadyCover
    readonly property bool coverReadStateVisible: root.readStatus === "read" && hasReadyCover
    readonly property bool coverDefaultStateVisible: hasReadyCover
    readonly property bool openingOverlayVisible: root.openingInProgress
    readonly property int coverWidth: 170
    readonly property int coverHeight: 260
    readonly property int coverLiftOffset: effectiveHover ? -4 : 0
    readonly property int coverBaseX: Math.max(0, Math.round((root.width - coverWidth) / 2))
    readonly property int coverBaseY: Math.max(0, Math.round((root.height - coverHeight) / 2))
    readonly property int defaultOverlayX: coverSlot.x - 6
    readonly property int defaultOverlayY: coverSlot.y - 1
    readonly property int hoverGlowX: coverSlot.x - 87
    readonly property int hoverGlowY: coverSlot.y - 58
    readonly property int hoverOverlayX: coverSlot.x - 12
    readonly property int hoverOverlayY: coverSlot.y - 7
    readonly property int readOverlayX: coverSlot.x - 6
    readonly property int readOverlayY: coverSlot.y - 10
    readonly property int bookmarkOffsetLeft: 6
    readonly property int bookmarkOffsetTop: -3
    readonly property real cropWideThreshold: 0.85
    readonly property real sourceCoverRatio: {
        const w = Number(coverImage.sourceSize.width || 0)
        const h = Number(coverImage.sourceSize.height || 0)
        if (w <= 0 || h <= 0) return 0
        return w / h
    }
    readonly property bool shouldCropWideCover: sourceCoverRatio > cropWideThreshold
    readonly property string hoverCaptionText: {
        const num = IssueNumberText.formatDisplayIssueNumber(root.issueNumber)
        const title = String(root.issueTitle || "").trim()
        if (num.length > 0 && title.length > 0) return "#" + num + " " + title
        if (num.length > 0) return "#" + num
        if (title.length > 0) return title
        return ""
    }
    readonly property bool hoverCaptionVisible: effectiveHover && hoverCaptionText.length > 0
    readonly property bool actionMenuVisible: root.hoverUiEnabled
        && !root.actionMenuSuppressed
        && !root.actionMenuDismissed
        && (coverHovered || actionMenuInteractionRetained || hoverRetained)
    readonly property int hoverCaptionLineLimit: 2
    readonly property int actionMenuOffsetAboveCover: 14
    readonly property Item actionMenuOverlay: Overlay.overlay
    readonly property real actionMenuBoundsTopY: {
        if (!root.actionMenuOverlay || !root.actionMenuBoundsItem) return 0
        return root.actionMenuBoundsItem.mapToItem(root.actionMenuOverlay, 0, 0).y
    }

    signal readRequested()
    signal editRequested()
    signal replaceRequested()
    signal toggleSelectedRequested()
    signal selectionToggled(bool checked)
    signal deleteRequested()
    signal markUnreadRequested()
    signal startupCardCreated()
    signal startupCoverReady()

    radius: 0
    color: "transparent"
    border.width: 0

    Component.onCompleted: root.startupCardCreated()

    function refreshActionMenuHold() {
        if (!root.hoverUiEnabled || root.actionMenuSuppressed) {
            actionMenuHoldTimer.stop()
            root.actionMenuInteractionRetained = false
            root.actionMenuDismissed = false
            return
        }

        if (!root.coverHovered && !root.menuHovered && !actionMenuHoldTimer.running) {
            root.actionMenuInteractionRetained = false
            root.actionMenuDismissed = false
        }

        if (root.coverHovered || root.menuHovered) {
            actionMenuHoldTimer.stop()
            return
        }

        if (hoverActionBarLoader.active || actionMenuHoldTimer.running) {
            actionMenuHoldTimer.restart()
        }
    }

    Item {
        id: coverSlot
        width: root.coverWidth
        height: root.coverHeight
        x: root.coverBaseX
        y: root.coverBaseY + root.coverLiftOffset

        Behavior on y {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: coverImageHost
            anchors.fill: parent
            clip: true

            Image {
                id: coverImage
                anchors.fill: parent
                source: root.coverSource
                fillMode: root.shouldCropWideCover ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                asynchronous: true
                cache: true
                smooth: true
                onStatusChanged: {
                    if (status === Image.Ready && root.coverSource.length > 0) {
                        root.startupCoverReady()
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.openingOverlayVisible
                color: root.openingOverlayColor
                z: 20

                ShuffleBusySpinner {
                    id: openingIndicator
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -14
                    running: root.openingOverlayVisible
                    visible: root.openingOverlayVisible
                    width: 40
                    height: 40
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: openingIndicator.bottom
                    anchors.topMargin: 10
                    text: "Opening..."
                    color: root.textPrimary
                    font.family: root.uiFontFamily
                    font.pixelSize: Math.max(12, root.uiFontPixelSize)
                    font.weight: Font.Medium
                }
            }
        }
    }

    Image {
        id: coverHoverGlow
        visible: root.effectiveHover && root.hasReadyCover
        source: uiTokens.coverHoverGlow
        asynchronous: true
        cache: true
        smooth: true
        x: root.hoverGlowX
        y: root.hoverGlowY
        z: -1
    }

    Item {
        id: hoverCaptionLayer
        visible: root.hoverCaptionVisible
        x: coverSlot.x
        y: coverSlot.y + coverSlot.height + 12
        width: coverSlot.width
        clip: true
        z: 5
        readonly property int captionLineHeight: Math.max(1, Math.ceil(captionMetrics.height))
        readonly property int captionMaxHeight: captionLineHeight * root.hoverCaptionLineLimit

        FontMetrics {
            id: captionMetrics
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
        }

        Text {
            id: hoverCaptionShadow
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: hoverCaptionLayer.captionMaxHeight
            text: root.hoverCaptionText
            color: root.textShadowColor
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.hoverCaptionLineLimit
            elide: Text.ElideRight
            y: 1
        }

        Text {
            id: hoverCaptionMain
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: hoverCaptionLayer.captionMaxHeight
            text: root.hoverCaptionText
            color: root.textPrimary
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.hoverCaptionLineLimit
            elide: Text.ElideRight
        }

        height: hoverCaptionLayer.captionMaxHeight + 1
    }

    Loader {
        id: hoverActionBarLoader
        active: root.hoverUiEnabled
            && !root.actionMenuSuppressed
            && !root.actionMenuDismissed
            && (root.coverHovered || root.actionMenuInteractionRetained || root.hoverRetained)
        asynchronous: false
        sourceComponent: Component {
            HoverActionBar {
                parent: Overlay.overlay
                anchorItem: actionMenuAnchor
                presented: root.actionMenuVisible && parent !== null
                topBoundaryY: root.actionMenuBoundsTopY
                hideIfOutOfBounds: true
                backgroundColor: root.actionMenuBackgroundColor
                hoverColor: root.actionMenuHoverColor
                textColor: root.textPrimary
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.uiFontPixelSize
                hoverUiEnabled: root.hoverUiEnabled
                onEditRequested: {
                    root.dismissActionMenu()
                    Qt.callLater(function() {
                        root.editRequested()
                    })
                }
                onReplaceRequested: {
                    root.dismissActionMenu()
                    Qt.callLater(function() {
                        root.replaceRequested()
                    })
                }
                onDeleteRequested: {
                    root.dismissActionMenu()
                    Qt.callLater(function() {
                        root.deleteRequested()
                    })
                }
            }
        }
    }

    Item {
        id: actionMenuAnchor
        width: 1
        height: 1
        x: coverSlot.x + Math.round((coverSlot.width - width) / 2)
        y: coverSlot.y - root.actionMenuOffsetAboveCover
    }

    HoverHandler {
        id: coverHoverHandler
        acceptedDevices: PointerDevice.Mouse
        enabled: root.hoverUiEnabled
    }

    onCoverHoveredChanged: refreshActionMenuHold()
    onMenuHoveredChanged: {
        if (root.menuHovered) {
            root.actionMenuInteractionRetained = true
            refreshActionMenuHold()
            return
        }

        refreshActionMenuHold()
        root.actionMenuInteractionRetained = false
    }
    onActionMenuSuppressedChanged: refreshActionMenuHold()
    onHoverUiEnabledChanged: refreshActionMenuHold()

    function dismissActionMenu() {
        actionMenuHoldTimer.stop()
        root.actionMenuInteractionRetained = false
        root.actionMenuDismissed = true
    }

    Timer {
        id: actionMenuHoldTimer
        interval: root.actionMenuHoldDelayMs
        repeat: false
    }

    Image {
        id: coverDefaultOverlay
        visible: root.coverDefaultStateVisible
        source: uiTokens.coverDefault
        asynchronous: true
        cache: true
        smooth: true
        x: root.defaultOverlayX
        y: root.defaultOverlayY
        z: 2
    }

    Image {
        id: coverReadOverlay
        visible: root.coverReadStateVisible
        source: unreadHotspotArea.containsMouse
            ? uiTokens.coverReadCancel
            : uiTokens.coverRead
        asynchronous: true
        cache: true
        smooth: true
        x: root.readOverlayX
        y: root.readOverlayY
        z: 3
    }

    MouseArea {
        id: unreadHotspotArea
        visible: root.coverReadStateVisible
        enabled: root.hoverUiEnabled
        x: Math.round(coverReadOverlay.x + coverReadOverlay.width - width)
        y: Math.round(coverReadOverlay.y)
        width: 25
        height: 25
        z: 6
        hoverEnabled: root.hoverUiEnabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: function(mouse) {
            mouse.accepted = true
            root.markUnreadRequested()
        }
    }

    Image {
        id: coverHoverOverlay
        visible: root.coverHoverVisible
        source: uiTokens.coverHover
        asynchronous: true
        cache: true
        smooth: true
        x: root.hoverOverlayX
        y: root.hoverOverlayY
        z: 4
    }

    Image {
        id: coverBookmarkBadge
        visible: root.showBookmarkRibbon && root.hasBookmark && root.hasReadyCover && status === Image.Ready
        source: uiTokens.coverBookmark
        asynchronous: true
        cache: true
        smooth: true
        x: Math.round(coverSlot.x + root.bookmarkOffsetLeft)
        y: Math.round(coverSlot.y + root.bookmarkOffsetTop)
        z: 5
    }

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        z: 1
        enabled: root.hoverUiEnabled && !root.openingInProgress
        hoverEnabled: root.hoverUiEnabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.readRequested()
    }
}
