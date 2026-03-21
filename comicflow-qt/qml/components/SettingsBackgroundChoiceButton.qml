import QtQuick

Item {
    id: root

    ThemeColors { id: themeColors }

    property string title: ""
    property bool selected: false
    property bool chromeVisible: true
    property color bodyColor: themeColors.settingsBackgroundChoiceBodyColor
    property color selectedBorderColor: themeColors.settingsBackgroundChoiceBorderColor
    property int cornerRadius: 6
    property alias previewAlwaysContent: previewAlwaysSlot.data
    property alias previewAlwaysFrame: previewAlwaysFrame
    property alias previewAlwaysSlotItem: previewAlwaysSlot

    signal clicked()

    width: 139
    height: 72

    readonly property bool hovered: buttonMouseArea.containsMouse

    Item {
        id: previewAlwaysFrame
        x: 6
        y: 6
        width: 127
        height: 40
        z: 2

        Rectangle {
            id: previewAlwaysSlot
            anchors.fill: parent
            radius: 4
            color: "transparent"
            clip: true
            antialiasing: true
        }

        Rectangle {
            visible: !root.selected && !root.hovered
            x: -1
            y: -1
            width: parent.width + 2
            height: parent.height + 2
            color: "transparent"
            antialiasing: true
            z: 2

            Image {
                anchors.fill: parent
                source: "qrc:/qt/qml/ComicPile/assets/ui/background-preview-inner-shadow.png"
                fillMode: Image.Stretch
                smooth: true
            }

            Canvas {
                anchors.fill: parent
                antialiasing: true
                contextType: "2d"

                onPaint: {
                    const ctx = getContext("2d")
                    const w = Math.max(1, width)
                    const h = Math.max(1, height)
                    const r = Math.max(0, Math.min(5, w / 2, h / 2))

                    ctx.reset()
                    ctx.clearRect(0, 0, w, h)
                    ctx.fillStyle = themeColors.popupFillColor
                    ctx.fillRect(0, 0, w, h)

                    ctx.save()
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath()
                    ctx.moveTo(r, 0)
                    ctx.lineTo(w - r, 0)
                    ctx.quadraticCurveTo(w, 0, w, r)
                    ctx.lineTo(w, h - r)
                    ctx.quadraticCurveTo(w, h, w - r, h)
                    ctx.lineTo(r, h)
                    ctx.quadraticCurveTo(0, h, 0, h - r)
                    ctx.lineTo(0, r)
                    ctx.quadraticCurveTo(0, 0, r, 0)
                    ctx.closePath()
                    ctx.fill()
                    ctx.restore()
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "transparent"
            border.width: (root.selected || root.hovered) ? 1 : 0
            border.color: root.selectedBorderColor
            antialiasing: true
            z: 3
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 50
        z: 3
        text: root.title
        color: themeColors.textPrimary
        font.family: Qt.application.font.family
        font.pixelSize: 11
    }

        Item {
            anchors.fill: parent
            visible: root.chromeVisible
            z: 1

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: root.cornerRadius
            color: themeColors.fieldFillColor
            opacity: 1.0
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: root.bodyColor
        }

    }

    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
