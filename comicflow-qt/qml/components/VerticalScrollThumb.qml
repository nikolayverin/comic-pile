import QtQuick

Item {
    id: root

    property var flickable: null
    property real visibleRatioOverride: 1
    property real positionRatioOverride: 0
    property int thumbWidth: 8
    property int thumbMinHeight: 36
    property int thumbInset: 0
    property color thumbColor: "white"
    property bool interactive: true

    readonly property real resolvedVisibleRatio: {
        if (flickable && flickable.visibleArea) {
            return clampRatio(flickable.visibleArea.heightRatio)
        }
        return clampRatio(visibleRatioOverride)
    }
    readonly property real resolvedPositionRatio: {
        if (flickable && flickable.visibleArea) {
            const visibleRatio = clampRatio(flickable.visibleArea.heightRatio)
            const yPosition = clampRatio(flickable.visibleArea.yPosition)
            const maxVisiblePosition = Math.max(0, 1 - visibleRatio)
            return maxVisiblePosition > 0
                ? clampRatio(yPosition / maxVisiblePosition)
                : 0
        }
        return clampRatio(positionRatioOverride)
    }
    readonly property real innerTrackHeight: Math.max(0, height - (thumbInset * 2))
    readonly property real resolvedThumbHeight: {
        if (innerTrackHeight <= 0) {
            return 0
        }
        const scaledHeight = Math.round(innerTrackHeight * resolvedVisibleRatio)
        return Math.min(innerTrackHeight, Math.max(thumbMinHeight, scaledHeight))
    }

    signal dragStarted()
    signal positionRequested(real ratio)

    function clampRatio(value) {
        return Math.max(0, Math.min(1, Number(value || 0)))
    }

    function requestPositionFromPointer(localY) {
        const thumbHeight = resolvedThumbHeight
        const availableTravel = Math.max(0, innerTrackHeight - thumbHeight)
        const unclamped = localY - thumbInset - (thumbHeight / 2)
        const clamped = Math.max(0, Math.min(availableTravel, unclamped))
        const ratio = availableTravel > 0
            ? (clamped / availableTravel)
            : 0

        if (flickable) {
            const maxContentY = Math.max(0, Number(flickable.contentHeight || 0) - Number(flickable.height || 0))
            if (maxContentY <= 0) {
                return
            }
            flickable.contentY = ratio * maxContentY
            return
        }

        positionRequested(ratio)
    }

    Rectangle {
        id: scrollThumb
        width: root.thumbWidth
        height: root.resolvedThumbHeight
        anchors.right: parent.right
        anchors.rightMargin: root.thumbInset
        y: root.thumbInset + Math.round(Math.max(0, root.innerTrackHeight - height) * root.resolvedPositionRatio)
        radius: width / 2
        color: root.thumbColor
        antialiasing: true
        visible: height > 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        enabled: root.interactive
        hoverEnabled: true
        preventStealing: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(mouse) {
            root.dragStarted()
            root.requestPositionFromPointer(mouse.y)
        }
        onPositionChanged: function(mouse) {
            if (pressed) {
                root.requestPositionFromPointer(mouse.y)
            }
        }
    }
}
