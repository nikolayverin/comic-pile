import QtQuick

Item {
    id: root

    ThemeColors { id: themeColors }

    property bool checked: false
    property color trackColor: themeColors.settingsSwitchTrackColor
    property color offKnobColor: themeColors.settingsSwitchOffKnobColor
    property color onKnobColor: themeColors.settingsSwitchOnKnobColor
    readonly property int trackWidth: 38
    readonly property int trackHeight: 20
    readonly property int knobSize: 14
    readonly property int edgeInset: 3
    readonly property int knobTravel: trackWidth - knobSize - (edgeInset * 2)

    signal toggled(bool checked)

    width: trackWidth
    height: trackHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        width: root.knobSize
        height: root.knobSize
        radius: width / 2
        color: root.checked ? root.onKnobColor : root.offKnobColor
        y: root.edgeInset
        x: root.edgeInset + (root.checked ? root.knobTravel : 0)

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
