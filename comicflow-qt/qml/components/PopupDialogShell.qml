import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent

    ThemeColors { id: themeColors }

    property var popupStyle: null
    property string title: ""
    property bool showCloseButton: true
    default property alias bodyData: bodyHost.data
    property alias bodyHost: bodyHost

    signal closeRequested()

    Label {
        text: root.title
        color: root.popupStyle ? root.popupStyle.textColor : themeColors.textPrimary
        font.pixelSize: root.popupStyle ? root.popupStyle.dialogTitleFontSize : 18
        anchors.top: parent.top
        anchors.topMargin: root.popupStyle ? root.popupStyle.dialogHeaderTopMargin : 16
        anchors.horizontalCenter: parent.horizontalCenter
    }

    PopupCloseButton {
        visible: root.showCloseButton
        width: root.popupStyle ? root.popupStyle.closeButtonSize : 24
        height: root.popupStyle ? root.popupStyle.closeButtonSize : 24
        glyphPixelSize: root.popupStyle ? root.popupStyle.closeGlyphSize : 12
        glyphColor: root.popupStyle ? root.popupStyle.textColor : themeColors.textPrimary
        hoverBackgroundColor: root.popupStyle ? root.popupStyle.closeHoverBgColor : themeColors.closeHoverBgColor
        anchors.top: parent.top
        anchors.topMargin: root.popupStyle ? root.popupStyle.closeTopMargin : 8
        anchors.right: parent.right
        anchors.rightMargin: root.popupStyle ? root.popupStyle.closeRightMargin : 8
        onClicked: root.closeRequested()
    }

    Item {
        id: bodyHost
        anchors.fill: parent
    }
}
