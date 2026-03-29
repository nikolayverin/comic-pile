import QtQuick

Item {
    id: root

    property var options: []
    property string currentText: ""
    property string uiFontFamily: Qt.application.font.family

    readonly property int horizontalTextPadding: 12
    readonly property int outerInset: 2
    readonly property int buttonHeight: 20
    readonly property int trackHeight: buttonHeight + (outerInset * 2)
    readonly property int buttonRadius: Math.round(buttonHeight / 2)
    readonly property int trackRadius: Math.round(trackHeight / 2)
    readonly property var normalizedOptions: buildNormalizedOptions()
    readonly property var segmentWidths: buildSegmentWidths()
    readonly property int resolvedCurrentIndex: resolveCurrentIndex()
    readonly property int totalButtonsWidth: sumSegmentWidths()

    implicitWidth: totalButtonsWidth + (outerInset * 2)
    implicitHeight: trackHeight + 1
    width: implicitWidth
    height: implicitHeight

    signal activated(int index, string text)

    function buildNormalizedOptions() {
        const source = options
        if (!source) return []
        if (Array.isArray(source)) {
            return source.map(function(item) { return String(item || "") })
        }
        if (typeof source.length === "number") {
            const normalized = []
            for (let i = 0; i < source.length; i += 1) {
                normalized.push(String(source[i] || ""))
            }
            return normalized
        }
        return []
    }

    function buildSegmentWidths() {
        const widths = []
        const source = normalizedOptions
        for (let i = 0; i < source.length; i += 1) {
            widthMeasure.text = String(source[i] || "")
            widths.push(Math.ceil(widthMeasure.width) + (horizontalTextPadding * 2))
        }
        return widths
    }

    function sumSegmentWidths() {
        let total = 0
        const source = segmentWidths
        for (let i = 0; i < source.length; i += 1) {
            total += Number(source[i] || 0)
        }
        return total
    }

    function segmentXAt(index) {
        let x = outerInset
        for (let i = 0; i < index; i += 1) {
            x += Number(segmentWidths[i] || 0)
        }
        return x
    }

    function indexOfCurrentText() {
        const target = String(currentText || "")
        const source = normalizedOptions
        for (let i = 0; i < source.length; i += 1) {
            if (String(source[i] || "") === target) {
                return i
            }
        }
        return -1
    }

    function resolveCurrentIndex() {
        return indexOfCurrentText()
    }

    Rectangle {
        x: 0
        y: 1
        width: root.totalButtonsWidth + (root.outerInset * 2)
        height: root.trackHeight
        radius: root.trackRadius
        color: "#000000"
    }

    Rectangle {
        id: trackBody
        x: 0
        y: 0
        width: root.totalButtonsWidth + (root.outerInset * 2)
        height: root.trackHeight
        radius: root.trackRadius
        color: "#111111"
    }

    Canvas {
        id: trackInnerShadow
        anchors.fill: trackBody
        antialiasing: true
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            const w = Math.max(1, width)
            const h = Math.max(1, height)
            const radius = root.trackRadius

            ctx.reset()
            ctx.clearRect(0, 0, w, h)
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

            const fadeDepth = 8
            const pressedGradient = ctx.createLinearGradient(0, 0, 0, fadeDepth)
            pressedGradient.addColorStop(0.0, "rgba(0, 0, 0, 0.72)")
            pressedGradient.addColorStop(0.35, "rgba(0, 0, 0, 0.42)")
            pressedGradient.addColorStop(1.0, "rgba(0, 0, 0, 0.0)")
            ctx.fillStyle = pressedGradient
            ctx.fillRect(0, 0, w, fadeDepth + 2)
            ctx.restore()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Rectangle {
        id: selectedSegment
        x: root.resolvedCurrentIndex >= 0 ? root.segmentXAt(root.resolvedCurrentIndex) : root.outerInset
        y: root.outerInset
        width: root.resolvedCurrentIndex >= 0
            ? Number(root.segmentWidths[root.resolvedCurrentIndex] || 0)
            : 0
        height: root.buttonHeight
        radius: root.buttonRadius
        visible: width > 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#1e1e1e" }
            GradientStop { position: 1.0; color: "#1c1c1c" }
        }

        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.InOutCubic
            }
        }
    }

    Canvas {
        anchors.fill: selectedSegment
        visible: selectedSegment.visible
        antialiasing: true
        contextType: "2d"

        onPaint: {
            const ctx = getContext("2d")
            const w = Math.max(1, width)
            const h = Math.max(1, height)
            const radius = root.buttonRadius

            ctx.reset()
            ctx.clearRect(0, 0, w, h)
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

            ctx.fillStyle = "#2f2f2f"
            ctx.fillRect(0, 0, w, 1)
            ctx.fillStyle = "#000000"
            ctx.fillRect(0, h - 1, w, 1)
            ctx.restore()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
    }

    Repeater {
        model: root.normalizedOptions

        delegate: Item {
            required property int index
            required property string modelData

            x: root.segmentXAt(index)
            y: root.outerInset
            width: Number(root.segmentWidths[index] || 0)
            height: root.buttonHeight

            readonly property bool selected: index === root.resolvedCurrentIndex

            Text {
                anchors.centerIn: parent
                text: parent.modelData
                color: parent.selected || segmentMouseArea.containsMouse ? "#ffffff" : "#808080"
                font.family: root.uiFontFamily
                font.pixelSize: 12

                Behavior on color {
                    ColorAnimation {
                        duration: 110
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            MouseArea {
                id: segmentMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(index, parent.modelData)
            }
        }
    }

    TextMetrics {
        id: widthMeasure
        font.family: root.uiFontFamily
        font.pixelSize: 12
    }
}
