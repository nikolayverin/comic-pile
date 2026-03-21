import QtQuick

Item {
    id: root

    property color fillColor: "#252525"
    property color edgeColor: "#000000"
    property int cornerRadius: 10
    property int fillOffsetX: 0
    property int fillOffsetY: -1
    property color borderColor: "transparent"
    property int borderWidth: 0

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.edgeColor
        clip: true
        antialiasing: true

        Rectangle {
            width: parent.width
            height: parent.height
            x: root.fillOffsetX
            y: root.fillOffsetY
            radius: root.cornerRadius
            color: root.fillColor
            antialiasing: true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: root.borderWidth
        border.color: root.borderColor
        antialiasing: true
        visible: root.borderWidth > 0
    }
}
