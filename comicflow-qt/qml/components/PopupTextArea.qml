import QtQuick
import QtQuick.Controls

FocusScope {
    id: root

    ThemeColors { id: themeColors }

    property alias text: area.text
    property alias color: area.color
    property alias font: area.font
    property alias placeholderText: area.placeholderText
    property alias leftPadding: area.leftPadding
    property alias rightPadding: area.rightPadding
    property alias topPadding: area.topPadding
    property alias bottomPadding: area.bottomPadding
    property alias wrapMode: area.wrapMode
    property alias clip: area.clip
    property int cornerRadius: 12
    property color fillColor: themeColors.fieldFillColor

    implicitWidth: area.implicitWidth
    implicitHeight: area.implicitHeight

    function selectAll() { area.selectAll() }
    function copy() { area.copy() }
    function deselect() { area.deselect() }
    function forceActiveFocus(reason) { area.forceActiveFocus(reason) }

    PopupFieldBackground {
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        fillColor: root.fillColor
    }

    TextArea {
        id: area
        anchors.fill: parent
        background: null
        selectByMouse: true
    }
}
