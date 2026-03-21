import QtQuick
import QtQuick.Controls

ToolButton {
    id: root
    UiTokens { id: uiTokens }
    ThemeColors { id: themeColors }

    property var popupStyle: null

    width: popupStyle ? popupStyle.copyIconSize : 10
    height: popupStyle ? popupStyle.copyIconSize : 10
    padding: 0
    z: 3
    hoverEnabled: true
    icon.source: uiTokens.copyIcon
    icon.width: width
    icon.height: height
    icon.color: hovered
        ? (popupStyle ? popupStyle.copyIconHoverColor : themeColors.copyIconHoverColor)
        : (popupStyle ? popupStyle.copyIconIdleColor : themeColors.copyIconIdleColor)
    background: Item {}

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse
        cursorShape: Qt.PointingHandCursor
    }
}
