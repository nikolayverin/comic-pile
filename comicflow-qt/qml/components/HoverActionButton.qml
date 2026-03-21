import QtQuick

Rectangle {
    id: root

    Typography { id: typography }
    ThemeColors { id: themeColors }

    property string textLabel: ""
    property color textColor: themeColors.textPrimary
    property color hoverColor: themeColors.uiActionHoverBackground
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: typography.uiBasePx
    property int horizontalPadding: 12
    property bool hoverUiEnabled: true
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: clickArea.pressed
    readonly property bool interactionActive: root.hovered || root.pressed

    signal clicked()

    implicitWidth: Math.ceil(labelText.implicitWidth) + root.horizontalPadding * 2
    radius: Math.round(height / 2)
    color: root.hovered ? root.hoverColor : "transparent"

    HoverHandler {
        id: hoverHandler
        enabled: root.hoverUiEnabled
        acceptedDevices: PointerDevice.Mouse
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: root.textLabel
        color: root.textColor
        font.family: root.uiFontFamily
        font.pixelSize: root.uiFontPixelSize
        font.weight: Font.Normal
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: root.hoverUiEnabled
        hoverEnabled: false
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
