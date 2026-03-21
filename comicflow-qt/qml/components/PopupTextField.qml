import QtQuick
import QtQuick.Controls

FocusScope {
    id: root

    ThemeColors { id: themeColors }

    property alias text: field.text
    property alias color: field.color
    property alias font: field.font
    property alias placeholderText: field.placeholderText
    property alias leftPadding: field.leftPadding
    property alias rightPadding: field.rightPadding
    property alias topPadding: field.topPadding
    property alias bottomPadding: field.bottomPadding
    property alias verticalAlignment: field.verticalAlignment
    property alias echoMode: field.echoMode
    property alias inputMethodHints: field.inputMethodHints
    property alias validator: field.validator
    property alias maximumLength: field.maximumLength
    property alias cursorPosition: field.cursorPosition
    property alias hoverEnabled: field.hoverEnabled
    property alias clip: field.clip
    property alias selectByMouse: field.selectByMouse
    property int cornerRadius: 12
    property color fillColor: themeColors.fieldFillColor

    signal accepted()

    implicitWidth: field.implicitWidth
    implicitHeight: field.implicitHeight

    function selectAll() { field.selectAll() }
    function copy() { field.copy() }
    function deselect() { field.deselect() }
    function forceActiveFocus(reason) { field.forceActiveFocus(reason) }

    PopupFieldBackground {
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        fillColor: root.fillColor
    }

    TextField {
        id: field
        anchors.fill: parent
        background: null

        onAccepted: root.accepted()
    }
}
