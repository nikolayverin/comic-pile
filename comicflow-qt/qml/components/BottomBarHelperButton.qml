import QtQuick

Item {
    id: root

    property string text: ""
    property string fontFamily: Qt.application.font.family
    property bool pressed: buttonMouseArea.pressed
    property bool hovered: buttonMouseArea.containsMouse

    implicitWidth: Math.ceil(buttonText.implicitWidth) + 20
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    signal clicked()

    Rectangle {
        x: -1
        y: -1
        width: parent.width + 2
        height: parent.height + 2
        radius: 5
        color: "#000000"
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.pressed
            ? "#1b1b1b"
            : root.hovered
                ? "#2a2a2a"
                : "transparent"
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: root.pressed
                    ? "#1b1b1b"
                    : root.hovered
                        ? "#2a2a2a"
                        : "#2c2c2c"
            }
            GradientStop {
                position: 1.0
                color: root.pressed
                    ? "#1b1b1b"
                    : root.hovered
                        ? "#2a2a2a"
                        : "#1b1b1b"
            }
        }
    }

    Canvas {
        id: bottomButtonInnerEdge
        anchors.fill: parent
        antialiasing: true
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            const w = Math.max(1, width)
            const h = Math.max(1, height)
            const radius = 4

            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            if (root.pressed) {
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(radius, 0)
                ctx.lineTo(w - radius, 0)
                ctx.quadraticCurveTo(w, 0, w, radius)
                ctx.lineTo(w, h - radius)
                ctx.quadraticCurveTo(w, h, w - radius, h)
                ctx.lineTo(radius, h)
                ctx.quadraticCurveTo(0, h, 0, h - radius)
                ctx.lineTo(0, radius)
                ctx.quadraticCurveTo(0, 0, radius, 0)
                ctx.closePath()
                ctx.clip()

                const insetTop = 0
                const fadeDepth = 8
                const pressedGradient = ctx.createLinearGradient(0, insetTop, 0, insetTop + fadeDepth)
                pressedGradient.addColorStop(0.0, "rgba(0, 0, 0, 0.72)")
                pressedGradient.addColorStop(0.35, "rgba(0, 0, 0, 0.42)")
                pressedGradient.addColorStop(1.0, "rgba(0, 0, 0, 0.0)")
                ctx.fillStyle = pressedGradient
                ctx.fillRect(0, insetTop, w, fadeDepth + 2)
                ctx.restore()
            } else {
                const px = 0.5
                ctx.beginPath()
                ctx.moveTo(radius, px)
                ctx.lineTo(w - radius, px)
                ctx.quadraticCurveTo(w - px, px, w - px, radius)
                ctx.strokeStyle = "#555555"
                ctx.lineWidth = 1
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.stroke()
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Item {
        anchors.centerIn: parent
        width: Math.max(buttonShadow.implicitWidth, buttonText.implicitWidth)
        height: Math.max(buttonShadow.implicitHeight, buttonText.implicitHeight + 1)

        Text {
            id: buttonShadow
            z: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            y: -1
            text: root.text
            color: "#000000"
            font.family: root.fontFamily
            font.pixelSize: 12
        }

        Text {
            id: buttonText
            z: 1
            anchors.centerIn: parent
            text: root.text
            color: "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressed: bottomButtonInnerEdge.requestPaint()
        onReleased: bottomButtonInnerEdge.requestPaint()
        onCanceled: bottomButtonInnerEdge.requestPaint()
    }
}
