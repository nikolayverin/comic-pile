import QtQuick
import QtQuick.Controls

Item {
    id: root

    ThemeColors { id: themeColors }
    UiTokens { id: uiTokens }

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
    implicitHeight: uiTokens.sidebarRowHeight

    Rectangle {
        id: hoverRect
        width: uiTokens.sidebarRowWidth
        height: uiTokens.sidebarRowHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: uiTokens.sidebarRowRadius
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
            anchors.leftMargin: uiTokens.sidebarRowIconLeftMargin
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth > 0 ? implicitWidth : uiTokens.sidebarQuickFilterIconSize
            height: implicitHeight > 0 ? implicitHeight : uiTokens.sidebarQuickFilterIconSize
            source: (rowMouseArea.containsMouse || root.selected)
                ? root.activeIconSource
                : root.idleIconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Label {
            id: filterLabel
            anchors.left: parent.left
            anchors.leftMargin: uiTokens.sidebarRowLabelLeftMargin
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
            anchors.rightMargin: uiTokens.sidebarRowCountRightMargin
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
