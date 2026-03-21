import QtQuick

Item {
    id: root

    Typography { id: typography }
    ThemeColors { id: themeColors }

    property Item anchorItem: null
    property color backgroundColor: themeColors.fieldFillColor
    property color hoverColor: themeColors.uiActionHoverBackground
    property color textColor: themeColors.textPrimary
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: typography.uiBasePx
    property bool hoverUiEnabled: true
    property bool presented: false
    property real topBoundaryY: 0
    property bool hideIfOutOfBounds: false
    readonly property bool interactionActive: root.presented
        && (menuHoverHandler.hovered || editButton.interactionActive || replaceButton.interactionActive || deleteButton.interactionActive)
    readonly property real anchorCenterX: {
        if (!root.parent || !root.anchorItem) return 0
        return root.anchorItem.mapToItem(root.parent, root.anchorItem.width / 2, 0).x
    }
    readonly property real anchorTopY: {
        if (!root.parent || !root.anchorItem) return 0
        return root.anchorItem.mapToItem(root.parent, root.anchorItem.width / 2, 0).y
    }

    signal editRequested()
    signal replaceRequested()
    signal deleteRequested()

    readonly property int bodyHorizontalPadding: 6
    readonly property int buttonHorizontalPadding: 12
    readonly property int bodyWidth: Math.ceil(actionRow.implicitWidth) + root.bodyHorizontalPadding * 2
    readonly property int bodyHeight: 30
    readonly property int buttonHeight: 24
    readonly property int buttonSpacing: 4
    readonly property int arrowWidth: 16
    readonly property int arrowHeight: 8
    readonly property real desiredY: Math.round(root.anchorTopY - root.height)
    readonly property bool fitsTopBoundary: desiredY >= root.topBoundaryY

    width: root.bodyWidth
    height: root.bodyHeight + root.arrowHeight
    visible: root.presented
        && root.parent !== null
        && root.anchorItem !== null
        && (!root.hideIfOutOfBounds || root.fitsTopBoundary)
    x: Math.round(root.anchorCenterX - (root.width / 2))
    y: Math.max(0, root.desiredY)
    z: 1000

    Rectangle {
        id: backgroundRect
        width: root.bodyWidth
        height: root.bodyHeight
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Math.round(height / 2)
        color: root.backgroundColor

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: root.buttonSpacing

            HoverActionButton {
                id: editButton
                height: root.buttonHeight
                horizontalPadding: root.buttonHorizontalPadding
                textLabel: "Edit"
                textColor: root.textColor
                hoverColor: root.hoverColor
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.uiFontPixelSize
                hoverUiEnabled: root.hoverUiEnabled
                onClicked: root.editRequested()
            }

            HoverActionButton {
                id: replaceButton
                height: root.buttonHeight
                horizontalPadding: root.buttonHorizontalPadding
                textLabel: "Replace"
                textColor: root.textColor
                hoverColor: root.hoverColor
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.uiFontPixelSize
                hoverUiEnabled: root.hoverUiEnabled
                onClicked: root.replaceRequested()
            }

            HoverActionButton {
                id: deleteButton
                height: root.buttonHeight
                horizontalPadding: root.buttonHorizontalPadding
                textLabel: "Delete"
                textColor: root.textColor
                hoverColor: root.hoverColor
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.uiFontPixelSize
                hoverUiEnabled: root.hoverUiEnabled
                onClicked: root.deleteRequested()
            }
        }
    }

    Canvas {
        id: menuArrow
        width: root.arrowWidth
        height: root.arrowHeight
        anchors.top: backgroundRect.bottom
        anchors.horizontalCenter: backgroundRect.horizontalCenter
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = root.backgroundColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fill()
        }
    }

    HoverHandler {
        id: menuHoverHandler
        enabled: root.hoverUiEnabled && root.presented
        acceptedDevices: PointerDevice.Mouse
    }
}
