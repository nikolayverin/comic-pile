import QtQuick

Item {
    id: root

    Typography { id: typography }
    ThemeColors { id: themeColors }

    property string glyph: "\u2715"
    property int glyphPixelSize: typography.closeGlyphPx
    property color glyphColor: themeColors.textPrimary
    property color hoverBackgroundColor: themeColors.closeHoverBgColor
    property bool circular: true

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: root.circular ? width / 2 : 0
        color: closeMouseArea.containsMouse ? root.hoverBackgroundColor : "transparent"
    }

    Text {
        anchors.fill: parent
        text: root.glyph
        color: root.glyphColor
        font.pixelSize: root.glyphPixelSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: closeMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
