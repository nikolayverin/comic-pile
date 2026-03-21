import QtQuick

Item {
    id: root

    ThemeColors { id: themeColors }

    property bool showArrow: true
    property int bodyRadius: 12
    property int arrowWidth: 20
    property int arrowHeight: 10
    property real arrowCenterX: width / 2
    property color fillColor: themeColors.backgroundColor
    property color borderColor: themeColors.borderColor
    property int borderWidth: 1

    Rectangle {
        x: 0
        y: root.showArrow ? root.arrowHeight : 0
        width: root.width
        height: Math.max(0, root.height - (root.showArrow ? root.arrowHeight : 0))
        radius: root.bodyRadius
        color: root.fillColor
    }

    Canvas {
        visible: root.showArrow
        x: Math.round(Math.max(0, Math.min(root.width - width, root.arrowCenterX - (width / 2))))
        y: 0
        width: root.arrowWidth
        height: root.arrowHeight
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.beginPath()
            ctx.moveTo(0, height)
            ctx.lineTo(width / 2, 0)
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fillStyle = root.fillColor
            ctx.fill()
        }
    }

    Canvas {
        anchors.fill: parent
        visible: root.borderWidth > 0
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            const bodyTop = root.showArrow ? root.arrowHeight : 0
            const bodyBottom = height - 0.5
            const left = 0.5
            const right = width - 0.5
            const radius = Math.max(0, Math.min(root.bodyRadius, (width - 1) / 2, (height - bodyTop - 1) / 2))
            const arrowHalf = root.showArrow ? root.arrowWidth / 2 : 0
            const arrowLeft = Math.max(left + radius, Math.min(right - radius, root.arrowCenterX - arrowHalf))
            const arrowRight = Math.max(left + radius, Math.min(right - radius, root.arrowCenterX + arrowHalf))
            const arrowTipY = 0.5
            const topY = bodyTop + 0.5

            ctx.reset()
            ctx.beginPath()
            ctx.moveTo(left + radius, topY)
            if (root.showArrow) {
                ctx.lineTo(arrowLeft, topY)
                ctx.lineTo(root.arrowCenterX, arrowTipY)
                ctx.lineTo(arrowRight, topY)
            }
            ctx.lineTo(right - radius, topY)
            ctx.quadraticCurveTo(right, topY, right, topY + radius)
            ctx.lineTo(right, bodyBottom - radius)
            ctx.quadraticCurveTo(right, bodyBottom, right - radius, bodyBottom)
            ctx.lineTo(left + radius, bodyBottom)
            ctx.quadraticCurveTo(left, bodyBottom, left, bodyBottom - radius)
            ctx.lineTo(left, topY + radius)
            ctx.quadraticCurveTo(left, topY, left + radius, topY)
            ctx.strokeStyle = root.borderColor
            ctx.lineWidth = root.borderWidth
            ctx.stroke()
        }
    }
}
