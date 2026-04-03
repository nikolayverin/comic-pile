import QtQuick
import QtQuick.Controls

Popup {
    id: root

    PopupMenuStyle { id: popupMenuStyle }

    property var menuItems: []
    property string uiFontFamily: popupMenuStyle.uiFontFamily
    property int uiFontPixelSize: popupMenuStyle.uiFontPixelSize
    property color backgroundColor: popupMenuStyle.backgroundColor
    property color borderColor: popupMenuStyle.borderColor
    property color hoverColor: popupMenuStyle.hoverColor
    property color textColor: popupMenuStyle.textColor
    property color disabledTextColor: popupMenuStyle.disabledTextColor
    property int borderWidth: popupMenuStyle.borderWidth
    property int rowHeight: popupMenuStyle.rowHeight
    property int contentHorizontalPadding: popupMenuStyle.contentHorizontalPadding
    property int bodyRadius: popupMenuStyle.bodyRadius
    property int minWidth: 0
    property int arrowWidth: popupMenuStyle.arrowWidth
    property int arrowHeight: popupMenuStyle.arrowHeight
    property int verticalOffset: popupMenuStyle.verticalOffset
    property real anchorY: 0
    property int revealOffsetYHidden: popupMenuStyle.revealOffsetYHidden
    property bool showArrow: true
    property bool centerText: false
    property bool closeOnFocusLoss: true
    property int minBodyHeight: 0
    property int maxBodyHeight: 0
    property real arrowCenterX: width / 2
    property int overlayMargin: 8
    property var placementOverlay: null
    property string placementMode: ""
    property real placementAnchorCenterX: 0
    property real placementAnchorLeftX: 0
    property real placementAnchorYValue: 0
    property var debugLogTarget: null
    property string debugName: ""

    readonly property int chromeHeight: showArrow ? arrowHeight : 0
    readonly property var visibleMenuItems: menuList.visibleMenuItems
    readonly property int visibleItemCount: menuList.visibleItemCount
    readonly property real computedTextWidth: menuList.computedTextWidth
    readonly property bool needsVerticalScrollGutter: maxBodyHeight > 0
        && menuList.contentHeight > resolvedBodyHeight + 0.5
    readonly property int resolvedBodyHeight: {
        const preferred = Math.ceil(menuList.contentHeight)
        const withMin = Math.max(minBodyHeight, preferred)
        if (maxBodyHeight > 0) return Math.min(maxBodyHeight, withMin)
        return withMin
    }
    readonly property real arrowSafeInset: showArrow
        ? bodyRadius + Math.ceil(arrowWidth / 2)
        : 0

    signal itemTriggered(int index, string action)

    modal: false
    focus: closeOnFocusLoss
    padding: 0
    closePolicy: Popup.CloseOnEscape
    width: Math.max(
        minWidth,
        Math.ceil(menuList.textBlockWidth + (needsVerticalScrollGutter ? popupMenuStyle.scrollGutterWidth : 0))
    )
    implicitHeight: chromeHeight + resolvedBodyHeight
    height: implicitHeight
    z: 10

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 110
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "y"
                from: root.anchorY + root.revealOffsetYHidden
                to: root.anchorY
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "y"
                from: root.y
                to: root.anchorY + root.revealOffsetYHidden
                duration: 110
                easing.type: Easing.OutCubic
            }
        }
    }

    onActiveFocusChanged: {
        if (closeOnFocusLoss && !activeFocus && visible) {
            traceMenuPopup("focus lost -> close")
            close()
        }
    }

    onVisibleChanged: {
        traceMenuPopup("visible=" + String(visible))
        if (visible) {
            Qt.callLater(function() {
                if (root.visible) {
                    applyStoredPlacement(false)
                }
            })
        }
    }

    onWidthChanged: {
        if (visible) {
            applyStoredPlacement(false)
        }
    }

    function openForItem(invokerItem) {
        if (!invokerItem) return
        const overlay = Overlay.overlay
        if (!overlay) return
        parent = overlay
        const point = invokerItem.mapToItem(overlay, invokerItem.width / 2, invokerItem.height)
        placementOverlay = overlay
        placementMode = "item"
        placementAnchorCenterX = point.x
        placementAnchorLeftX = point.x - (width / 2)
        placementAnchorYValue = point.y + verticalOffset
        applyStoredPlacement(true)
        open()
    }

    function openBelowItemLeftAligned(invokerItem, hostItem) {
        if (!invokerItem) return
        const overlay = Overlay.overlay
        if (!overlay) return
        parent = overlay
        const anchorPoint = invokerItem.mapToItem(overlay, 0, invokerItem.height)
        const anchorCenterPoint = invokerItem.mapToItem(overlay, invokerItem.width / 2, invokerItem.height)
        const hostBottom = hostItem ? hostItem.mapToItem(overlay, 0, hostItem.height).y : anchorPoint.y
        placementOverlay = overlay
        placementMode = "leftAligned"
        placementAnchorCenterX = anchorCenterPoint.x
        placementAnchorLeftX = anchorPoint.x
        placementAnchorYValue = hostBottom + (showArrow ? verticalOffset : -1)
        applyStoredPlacement(true)
        open()
    }

    function openBelowItemCentered(invokerItem, hostItem) {
        if (!invokerItem) return
        const overlay = Overlay.overlay
        if (!overlay) return
        parent = overlay
        const anchorCenterPoint = invokerItem.mapToItem(overlay, invokerItem.width / 2, invokerItem.height)
        const hostBottom = hostItem
            ? hostItem.mapToItem(overlay, 0, hostItem.height).y
            : anchorCenterPoint.y
        placementOverlay = overlay
        placementMode = "centered"
        placementAnchorCenterX = anchorCenterPoint.x
        placementAnchorLeftX = anchorCenterPoint.x - (width / 2)
        placementAnchorYValue = hostBottom + (showArrow ? verticalOffset : -1)
        applyStoredPlacement(true)
        open()
    }

    function applyStoredPlacement(preOpen) {
        const overlay = placementOverlay
        if (!overlay || placementMode.length < 1) return

        if (placementMode === "leftAligned") {
            x = clampPopupX(placementAnchorLeftX, overlay)
            syncArrowCenterX(placementAnchorCenterX)
        } else {
            x = clampPopupX(placementAnchorCenterX - (width / 2), overlay)
            syncArrowCenterX(placementAnchorCenterX)
        }

        anchorY = Math.round(placementAnchorYValue)
        y = preOpen ? anchorY + revealOffsetYHidden : anchorY
    }

    function clampPopupX(desiredX, overlay) {
        const minX = overlayMargin
        const maxX = Math.max(minX, Math.round(overlay.width - width - overlayMargin))
        return Math.max(minX, Math.min(maxX, Math.round(desiredX)))
    }

    function syncArrowCenterX(anchorSceneX) {
        if (!showArrow) {
            arrowCenterX = width / 2
            return
        }
        const localX = anchorSceneX - x
        const minX = arrowSafeInset
        const maxX = Math.max(minX, width - arrowSafeInset)
        arrowCenterX = Math.max(minX, Math.min(maxX, localX))
    }

    function popupDebugLabel() {
        const explicitName = String(debugName || "").trim()
        if (explicitName.length > 0) return explicitName
        const objectLabel = String(objectName || "").trim()
        if (objectLabel.length > 0) return objectLabel
        return "unnamed-context-menu"
    }

    function traceMenuPopup(message) {
        const target = debugLogTarget
        if (!target || typeof target.appendStartupDebugLog !== "function") return
        target.appendStartupDebugLog(
            "[popup-layer] " + popupDebugLabel() + " " + String(message || "")
        )
    }

    Item {
        id: outsideDismissLayer
        parent: root.visible ? root.parent : null
        x: 0
        y: 0
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        z: root.z - 1
        visible: root.visible && parent !== null

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) {
                mouse.accepted = true
                root.traceMenuPopup("outside press dismiss")
                root.close()
            }
        }
    }

    background: PopupMenuSurface {
        showArrow: root.showArrow
        bodyRadius: root.bodyRadius
        arrowWidth: root.arrowWidth
        arrowHeight: root.arrowHeight
        arrowCenterX: root.arrowCenterX
        fillColor: root.backgroundColor
        borderColor: root.borderColor
        borderWidth: root.borderWidth
    }

    contentItem: Item {
        anchors.fill: parent

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.chromeHeight + root.borderWidth
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.borderWidth
            anchors.rightMargin: root.borderWidth
            anchors.bottomMargin: root.borderWidth
            radius: Math.max(0, root.bodyRadius - root.borderWidth)
            color: "transparent"
            clip: true

            PopupMenuListView {
                id: menuList
                anchors.fill: parent
                menuItems: root.menuItems
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.uiFontPixelSize
                hoverColor: root.hoverColor
                textColor: root.textColor
                disabledTextColor: root.disabledTextColor
                rowHeight: root.rowHeight
                bodyRadius: root.bodyRadius
                textHorizontalPadding: popupMenuStyle.textHorizontalPadding
                contentHorizontalPadding: root.contentHorizontalPadding
                centerText: root.centerText
                reserveScrollGutter: root.needsVerticalScrollGutter
                scrollGutterWidth: popupMenuStyle.scrollGutterWidth
                scrollThumbWidth: popupMenuStyle.scrollThumbWidth
                scrollThumbMinHeight: popupMenuStyle.scrollThumbMinHeight
                scrollThumbColor: popupMenuStyle.scrollThumbColor

                onItemTriggered: function(index, item) {
                    const actionName = String((item || {}).action || "")
                    root.traceMenuPopup("item triggered action=" + actionName)
                    root.close()
                    root.itemTriggered(index, actionName)
                }
            }
        }
    }

    onOpened: traceMenuPopup("opened")
    onClosed: traceMenuPopup("closed")
}
