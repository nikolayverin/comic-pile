import QtQuick

Item {
    id: root

    ThemeColors { id: themeColors }

    property bool checked: false
    property color fillColor: themeColors.settingsCheckboxFillColor
    property color checkColor: themeColors.settingsCheckboxCheckColor
    readonly property int boxSize: 20
    readonly property int glyphSize: 14

    signal toggled(bool checked)

    width: boxSize
    height: boxSize

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.fillColor
    }

    Canvas {
        anchors.centerIn: parent
        width: root.glyphSize
        height: root.glyphSize
        visible: root.checked
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = root.checkColor
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(width * 0.16, height * 0.54)
            ctx.lineTo(width * 0.42, height * 0.80)
            ctx.lineTo(width * 0.84, height * 0.20)
            ctx.stroke()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
