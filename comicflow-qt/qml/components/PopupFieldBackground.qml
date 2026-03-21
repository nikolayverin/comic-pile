import QtQuick

Rectangle {
    id: root

    ThemeColors { id: themeColors }

    property int cornerRadius: 12
    property color fillColor: themeColors.fieldFillColor
    property color borderColor: "transparent"
    property real borderWidth: 1

    radius: cornerRadius
    color: fillColor
    border.color: borderColor
    border.width: borderWidth
}
