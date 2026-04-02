import QtQuick

Rectangle {
    id: root

    property color overlayColor: "transparent"

    signal outsideClicked()

    color: overlayColor

    MouseArea {
        anchors.fill: root
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPressed: function(mouse) {
            mouse.accepted = true
            root.outsideClicked()
        }
    }
}
