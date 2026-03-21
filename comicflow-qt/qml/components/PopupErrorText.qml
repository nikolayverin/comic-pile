import QtQuick
import QtQuick.Controls

Label {
    id: root

    ThemeColors { id: themeColors }

    property var popupStyle: null

    color: popupStyle ? popupStyle.errorTextColor : themeColors.errorTextColor
    font.pixelSize: popupStyle ? popupStyle.errorTextFontSize : 13
    wrapMode: Text.WordWrap
}
