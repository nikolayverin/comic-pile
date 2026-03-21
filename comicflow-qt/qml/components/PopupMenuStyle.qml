import QtQuick

QtObject {
    readonly property QtObject typography: Typography {}
    readonly property QtObject themeColors: ThemeColors {}

    readonly property string uiFontFamily: Qt.application.font.family
    readonly property int uiFontPixelSize: typography.uiBasePx

    readonly property color backgroundColor: themeColors.backgroundColor
    readonly property color borderColor: themeColors.borderColor
    readonly property color hoverColor: themeColors.hoverColor
    readonly property color textColor: themeColors.textColor
    readonly property color disabledTextColor: themeColors.disabledTextColor
    readonly property int borderWidth: 1

    readonly property int rowHeight: 24
    readonly property int bodyRadius: 12
    readonly property int textHorizontalPadding: 14
    readonly property int contentHorizontalPadding: 6
    readonly property int scrollGutterWidth: 12
    readonly property int scrollThumbWidth: 8
    readonly property int scrollThumbMinHeight: 36
    readonly property color scrollThumbColor: themeColors.scrollThumbColor
    readonly property int scrollThumbInset: 4
    readonly property int arrowWidth: 20
    readonly property int arrowHeight: 10
    readonly property int verticalOffset: 6
    readonly property int revealOffsetYHidden: -6
}
