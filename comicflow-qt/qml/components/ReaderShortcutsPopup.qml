import QtQuick

Item {
    id: root

    property var entries: []
    property string uiFontFamily: Qt.application.font.family
    property color panelColor: "#000000"
    property color textColor: "#ffffff"
    property color hoverFieldColor: "#333333"
    property int popupRadius: 18
    property int closeButtonSize: 24
    property int closeGlyphSize: 12
    property int closeTopMargin: 10
    property int closeRightMargin: 10

    readonly property int cardWidth: 344
    readonly property int sidePadding: 30
    readonly property int topPadding: 18
    readonly property int bottomPadding: 26
    readonly property int titleFontPx: 13
    readonly property int titleToListGap: 40
    readonly property int rowSpacing: 14
    readonly property int actionColumnWidth: 132
    readonly property int separatorColumnWidth: 28
    readonly property int keysColumnWidth: 112
    readonly property int contentWidth: actionColumnWidth + separatorColumnWidth + keysColumnWidth

    signal dismissRequested()

    anchors.fill: parent
    z: 20

    component CloseIcon: Canvas {
        property color strokeColor: root.textColor
        property real strokeWidth: 2

        contextType: "2d"
        onStrokeColorChanged: requestPaint()
        onStrokeWidthChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = strokeWidth
            ctx.strokeStyle = strokeColor
            ctx.beginPath()
            ctx.moveTo(width * 0.2, height * 0.2)
            ctx.lineTo(width * 0.8, height * 0.8)
            ctx.moveTo(width * 0.8, height * 0.2)
            ctx.lineTo(width * 0.2, height * 0.8)
            ctx.stroke()
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.dismissRequested()
    }

    Rectangle {
        id: helpCard
        width: root.cardWidth
        height: root.topPadding
            + helpTitle.implicitHeight
            + root.titleToListGap
            + helpList.implicitHeight
            + root.bottomPadding
        anchors.centerIn: parent
        radius: root.popupRadius
        color: root.panelColor

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Item {
            id: closeButton
            width: root.closeButtonSize
            height: root.closeButtonSize
            anchors.top: parent.top
            anchors.topMargin: root.closeTopMargin
            anchors.right: parent.right
            anchors.rightMargin: root.closeRightMargin

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: closeMouse.containsMouse ? root.hoverFieldColor : "transparent"
            }

            CloseIcon {
                width: root.closeGlyphSize
                height: root.closeGlyphSize
                anchors.centerIn: parent
                strokeColor: root.textColor
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissRequested()
            }
        }

        Text {
            id: helpTitle
            anchors.top: parent.top
            anchors.topMargin: root.topPadding
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Hotkeys"
            color: root.textColor
            font.family: root.uiFontFamily
            font.pixelSize: root.titleFontPx
            font.bold: false
        }

        Column {
            id: helpList
            width: root.contentWidth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.topPadding + helpTitle.implicitHeight + root.titleToListGap
            spacing: root.rowSpacing

            Repeater {
                model: root.entries

                delegate: Item {
                    width: helpList.width
                    height: Math.max(actionText.implicitHeight, keysText.implicitHeight)

                    Text {
                        id: actionText
                        width: root.actionColumnWidth
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: modelData.action
                        color: root.textColor
                        font.family: root.uiFontFamily
                        font.pixelSize: 13
                        font.bold: false
                        horizontalAlignment: Text.AlignRight
                    }

                    Text {
                        id: separatorText
                        width: root.separatorColumnWidth
                        anchors.left: parent.left
                        anchors.leftMargin: root.actionColumnWidth
                        anchors.top: parent.top
                        text: "\u2014"
                        color: root.textColor
                        font.family: root.uiFontFamily
                        font.pixelSize: 13
                        font.bold: false
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        id: keysText
                        width: root.keysColumnWidth
                        anchors.left: parent.left
                        anchors.leftMargin: root.actionColumnWidth + root.separatorColumnWidth
                        anchors.top: parent.top
                        text: String(modelData.keysText || "")
                        color: root.textColor
                        font.family: root.uiFontFamily
                        font.pixelSize: 13
                        font.bold: false
                        lineHeight: 18
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }
        }
    }
}
