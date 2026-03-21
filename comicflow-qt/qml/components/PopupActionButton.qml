import QtQuick

Item {
    id: root

    Typography { id: typography }
    ThemeColors { id: themeColors }

    property alias text: label.text
    property bool enabled: true
    property int textPixelSize: typography.uiBasePx
    property color textColor: themeColors.textPrimary
    property color idleColor: themeColors.popupFillColor
    property color hoverColor: themeColors.uiActionHoverBackground
    property color idleEdgeColor: themeColors.lineTopbarBottom
    property color hoverEdgeColor: themeColors.popupPrimaryActionHoverEdgeColor
    property bool pressedEffectEnabled: false
    property color pressedColor: themeColors.popupActionPressedColor
    property color pressedEdgeColor: themeColors.popupActionPressedEdgeColor
    property int cornerRadius: Math.round(height / 2)
    property int edgeOffsetPx: 1
    property int horizontalPadding: 18
    property int minimumWidth: 76

    signal clicked()

    height: 24
    implicitWidth: Math.max(minimumWidth, Math.ceil(labelMetrics.advanceWidth) + (horizontalPadding * 2))
    implicitHeight: height
    opacity: enabled ? 1.0 : 0.45

    TextMetrics {
        id: labelMetrics
        font.pixelSize: root.textPixelSize
        text: root.text
    }

    InsetEdgeSurface {
        id: buttonSurface
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        fillColor: actionMouseArea.pressed && root.pressedEffectEnabled
            ? root.pressedColor
            : actionMouseArea.containsMouse
                ? root.hoverColor
                : root.idleColor
        edgeColor: actionMouseArea.pressed && root.pressedEffectEnabled
            ? root.pressedEdgeColor
            : actionMouseArea.containsMouse
                ? root.hoverEdgeColor
                : root.idleEdgeColor
        fillOffsetY: actionMouseArea.pressed && root.pressedEffectEnabled
            ? root.edgeOffsetPx
            : actionMouseArea.containsMouse
                ? root.edgeOffsetPx
                : -root.edgeOffsetPx
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: root.textColor
        font.pixelSize: root.textPixelSize
    }

    MouseArea {
        id: actionMouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
