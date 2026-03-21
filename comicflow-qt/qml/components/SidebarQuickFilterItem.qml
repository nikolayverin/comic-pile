import QtQuick
import QtQuick.Controls

Item {
    id: root

    ThemeColors { id: themeColors }

    property string filterKey: ""
    property string title: ""
    property int issueCount: 0
    property int sidebarWidth: 320
    property bool selected: false
    property string idleIconSource: ""
    property string activeIconSource: ""
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: 13
    property color textColor: themeColors.textPrimary
    property color hoverColor: themeColors.sidebarQuickFilterHoverColor

    signal clicked()

    width: sidebarWidth
    implicitHeight: 24

    Rectangle {
        id: hoverRect
        width: 268
        height: 24
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: 3
        color: (rowMouseArea.containsMouse || root.selected) ? root.hoverColor : "transparent"

        MouseArea {
            id: rowMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        Image {
            id: filterIcon
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth > 0 ? implicitWidth : 16
            height: implicitHeight > 0 ? implicitHeight : 16
            source: (rowMouseArea.containsMouse || root.selected)
                ? root.activeIconSource
                : root.idleIconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Label {
            id: filterLabel
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(10, countLabel.x - x - 8)
            text: root.title
            color: root.textColor
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
            elide: Text.ElideRight
        }

        Label {
            id: countLabel
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.issueCount)
            color: root.textColor
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
            visible: rowMouseArea.containsMouse || root.selected
        }
    }
}
