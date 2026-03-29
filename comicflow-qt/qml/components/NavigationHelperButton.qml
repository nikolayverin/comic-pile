import QtQuick

Item {
    id: root

    property string text: ""
    property string fontFamily: Qt.application.font.family
    property bool enabled: true
    property bool pressed: enabled && buttonMouseArea.pressed
    property bool hovered: enabled && buttonMouseArea.containsMouse

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
            ? "#1c1c1c"
            : root.hovered
                ? "#303030"
                : "transparent"
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: root.pressed
                    ? "#1c1c1c"
                    : root.hovered
                    ? "#303030"
                    : "#252525"
            }
            GradientStop {
                position: 1.0
                color: root.pressed
                    ? "#1c1c1c"
                    : root.hovered
                    ? "#303030"
                    : "#1c1c1c"
            }
        }
    }

    Canvas {
        id: topButtonInnerEdge
        anchors.fill: parent
        antialiasing: true
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            const w = Math.max(1, width)
            const h = Math.max(1, height)
            const radius = 4

            ctx.reset()
            ctx.clearRect(0, 0, w, h)
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
            color: root.enabled ? "#ffffff" : "#808080"
            font.family: root.fontFamily
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
        onPressed: topButtonInnerEdge.requestPaint()
        onReleased: topButtonInnerEdge.requestPaint()
        onCanceled: topButtonInnerEdge.requestPaint()
    }
}
