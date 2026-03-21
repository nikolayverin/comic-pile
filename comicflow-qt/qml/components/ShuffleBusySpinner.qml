import QtQuick

Item {
    id: spinner

    property bool running: false
    property int phase: 0

    width: 48
    height: 48

    Timer {
        id: phaseTimer
        interval: 80
        repeat: true
        running: spinner.running
        onTriggered: {
            spinner.phase = (spinner.phase + 1) % 12
            spinnerCanvas.requestPaint()
        }
    }

    Canvas {
        id: spinnerCanvas
        anchors.fill: parent
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const cx = width / 2
            const cy = height / 2
            const innerRadius = 10.5
            const outerRadius = 19.5

            for (let i = 0; i < 12; i += 1) {
                const distance = (i - spinner.phase + 12) % 12
                const alpha = Math.max(0.28, 1.0 - (distance * 0.1))
                const angle = (i * Math.PI) / 6.0
                const sinValue = Math.sin(angle)
                const cosValue = Math.cos(angle)

                ctx.beginPath()
                ctx.lineWidth = 3.2
                ctx.lineCap = "round"
                ctx.strokeStyle = "rgba(255,255,255," + alpha + ")"
                ctx.moveTo(
                    cx + (sinValue * innerRadius),
                    cy - (cosValue * innerRadius)
                )
                ctx.lineTo(
                    cx + (sinValue * outerRadius),
                    cy - (cosValue * outerRadius)
                )
                ctx.stroke()
            }
        }
    }

    onRunningChanged: spinnerCanvas.requestPaint()
    onPhaseChanged: spinnerCanvas.requestPaint()
    Component.onCompleted: spinnerCanvas.requestPaint()
}
