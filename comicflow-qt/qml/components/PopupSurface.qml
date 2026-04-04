import QtQuick

Rectangle {
    id: root

    ThemeColors { id: themeColors }

    property int cornerRadius: 18
    property color fillColor: themeColors.popupFillColor
    property color edgeColor: themeColors.edgeLineColor
    property real edgeFadeFraction: 0.04
    property bool attentionPulseActive: false
    property color attentionColor: themeColors.dialogAttentionColor
    property int attentionBorderWidth: 3
    property int attentionGlowSize: 64
    property real attentionGlowExponentMin: 1.45
    property real attentionGlowExponentMax: 2.9
    property real attentionGlowAnimatedExponent: attentionGlowExponentMin
    property bool surfaceShadowActive: false
    property color surfaceShadowColor: "#000000"
    property int surfaceShadowSize: 44
    property int surfaceShadowOffsetY: 6
    property real surfaceShadowOpacity: 0.60

    radius: cornerRadius
    color: fillColor

    Canvas {
        id: surfaceShadow
        visible: root.surfaceShadowActive
        anchors.fill: parent
        anchors.margins: -root.surfaceShadowSize
        anchors.topMargin: -root.surfaceShadowSize
        anchors.bottomMargin: -(root.surfaceShadowSize + root.surfaceShadowOffsetY)
        z: -3
        antialiasing: true
        contextType: "2d"

        function drawRoundedRect(ctx, x, y, w, h, r) {
            const radius = Math.max(0, Math.min(r, w / 2, h / 2))
            ctx.beginPath()
            ctx.moveTo(x + radius, y)
            ctx.lineTo(x + w - radius, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + radius)
            ctx.lineTo(x + w, y + h - radius)
            ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h)
            ctx.lineTo(x + radius, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - radius)
            ctx.lineTo(x, y + radius)
            ctx.quadraticCurveTo(x, y, x + radius, y)
            ctx.closePath()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const step = 4
            const x = root.surfaceShadowSize
            const y = root.surfaceShadowSize + root.surfaceShadowOffsetY
            const w = Math.max(1, root.width)
            const h = Math.max(1, root.height)
            const r = root.cornerRadius

            for (let d = root.surfaceShadowSize; d > 0; d -= step) {
                const t = 1 - (d / root.surfaceShadowSize)
                const alpha = root.surfaceShadowOpacity * 0.36 * Math.pow(t, 1.55)
                ctx.fillStyle = Qt.rgba(
                    root.surfaceShadowColor.r,
                    root.surfaceShadowColor.g,
                    root.surfaceShadowColor.b,
                    alpha
                )
                surfaceShadow.drawRoundedRect(ctx, x - d, y - d, w + d * 2, h + d * 2, r + d)
                ctx.fill()
            }

            ctx.save()
            ctx.globalCompositeOperation = "destination-out"
            surfaceShadow.drawRoundedRect(ctx, x, y, w, h, r)
            ctx.fill()
            ctx.restore()
        }

        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Canvas {
        id: attentionGlow
        visible: root.attentionPulseActive
        anchors.fill: parent
        anchors.margins: -(root.attentionGlowSize + root.attentionBorderWidth)
        z: -2
        antialiasing: true
        contextType: "2d"

        function drawRoundedRect(ctx, x, y, w, h, r) {
            const radius = Math.max(0, Math.min(r, w / 2, h / 2))
            ctx.beginPath()
            ctx.moveTo(x + radius, y)
            ctx.lineTo(x + w - radius, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + radius)
            ctx.lineTo(x + w, y + h - radius)
            ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h)
            ctx.lineTo(x + radius, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - radius)
            ctx.lineTo(x, y + radius)
            ctx.quadraticCurveTo(x, y, x + radius, y)
            ctx.closePath()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const step = 4
            const x = root.attentionGlowSize
            const y = root.attentionGlowSize
            const w = Math.max(1, root.width + root.attentionBorderWidth * 2)
            const h = Math.max(1, root.height + root.attentionBorderWidth * 2)
            const r = root.cornerRadius + root.attentionBorderWidth

            for (let d = root.attentionGlowSize; d > 0; d -= step) {
                const t = 1 - (d / root.attentionGlowSize)
                ctx.fillStyle = Qt.rgba(
                    root.attentionColor.r,
                    root.attentionColor.g,
                    root.attentionColor.b,
                    0.03 * Math.pow(t, root.attentionGlowAnimatedExponent)
                )
                attentionGlow.drawRoundedRect(ctx, x - d, y - d, w + d * 2, h + d * 2, r + d)
                ctx.fill()
            }

            ctx.save()
            ctx.globalCompositeOperation = "destination-out"
            attentionGlow.drawRoundedRect(ctx, x, y, w, h, r)
            ctx.fill()
            ctx.restore()
        }

        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    SequentialAnimation on attentionGlowAnimatedExponent {
        running: root.attentionPulseActive
        loops: Animation.Infinite
        NumberAnimation {
            from: root.attentionGlowExponentMin
            to: root.attentionGlowExponentMax
            duration: 900
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            from: root.attentionGlowExponentMax
            to: root.attentionGlowExponentMin
            duration: 900
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        visible: root.attentionPulseActive
        anchors.fill: parent
        anchors.margins: -root.attentionBorderWidth
        z: -1
        radius: root.cornerRadius + root.attentionBorderWidth
        color: "transparent"
        border.width: root.attentionBorderWidth
        border.color: root.attentionColor
    }

    // Draw only the popup's top edge inside bounds so it is never clipped by Popup.
    // Rounded corners are preserved with a slight fade near both ends.
    Canvas {
        id: topEdge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(2, root.cornerRadius + 1)
        antialiasing: true
        contextType: "2d"
        z: 1

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const w = Math.max(1, width)
            const h = Math.max(1, height)
            const px = 0.5
            const r = Math.max(0, Math.min(root.cornerRadius, (w - 1) / 2, h - 1))
            const fadeWidth = Math.max(1, Math.min(r + 2, w * root.edgeFadeFraction))
            const fadeStop = Math.max(0.001, Math.min(0.49, fadeWidth / w))

            const grad = ctx.createLinearGradient(0, 0, w, 0)
            grad.addColorStop(0.0, "transparent")
            grad.addColorStop(fadeStop, root.edgeColor)
            grad.addColorStop(1.0 - fadeStop, root.edgeColor)
            grad.addColorStop(1.0, "transparent")

            ctx.strokeStyle = grad
            ctx.lineWidth = 1
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.moveTo(px, r + px)
            ctx.quadraticCurveTo(px, px, r + px, px)
            ctx.lineTo(w - r - px, px)
            ctx.quadraticCurveTo(w - px, px, w - px, r + px)
            ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onCornerRadiusChanged: {
        topEdge.requestPaint()
        surfaceShadow.requestPaint()
    }
    onEdgeColorChanged: topEdge.requestPaint()
    onEdgeFadeFractionChanged: topEdge.requestPaint()
    onAttentionColorChanged: attentionGlow.requestPaint()
    onAttentionGlowSizeChanged: attentionGlow.requestPaint()
    onAttentionBorderWidthChanged: attentionGlow.requestPaint()
    onAttentionGlowAnimatedExponentChanged: attentionGlow.requestPaint()
    onSurfaceShadowActiveChanged: surfaceShadow.requestPaint()
    onSurfaceShadowColorChanged: surfaceShadow.requestPaint()
    onSurfaceShadowSizeChanged: surfaceShadow.requestPaint()
    onSurfaceShadowOffsetYChanged: surfaceShadow.requestPaint()
    onSurfaceShadowOpacityChanged: surfaceShadow.requestPaint()
}
