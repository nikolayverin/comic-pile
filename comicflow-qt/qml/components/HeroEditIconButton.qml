import QtQuick

Item {
    id: root
    UiTokens { id: uiTokens }

    property int iconSize: 16
    property string idleSource: uiTokens.pencilLineGrayIcon
    property string hoverSource: uiTokens.pencilLineWhiteIcon

    signal clicked()

    width: iconSize
    height: iconSize

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: buttonMouseArea.containsMouse ? root.hoverSource : root.idleSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
    }

    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
