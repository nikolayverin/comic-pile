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
    property bool draggingThumb: false
    property real dragStartMouseY: 0
    property real dragStartContentY: 0
    property real dragPointerOffsetY: 0

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
    signal dragEnded()
    signal positionRequested(real ratio)

    function clampRatio(value) {
        return Math.max(0, Math.min(1, Number(value || 0)))
    }

    function thumbTop() {
        return thumbInset + Math.max(0, innerTrackHeight - resolvedThumbHeight) * resolvedPositionRatio
    }

    function thumbBottom() {
        return thumbTop() + resolvedThumbHeight
    }

    function dragThumbToPointer(localY) {
        const availableTravel = Math.max(0, innerTrackHeight - resolvedThumbHeight)
        if (availableTravel <= 0) {
            return
        }
        const desiredThumbTop = Math.max(
            0,
            Math.min(
                availableTravel,
                (localY - thumbInset) - dragPointerOffsetY
            )
        )
        const ratio = availableTravel > 0 ? clampRatio(desiredThumbTop / availableTravel) : 0
        if (flickable) {
            const maxContentY = Math.max(0, Number(flickable.contentHeight || 0) - Number(flickable.height || 0))
            if (maxContentY <= 0) {
                return
            }
            const desiredContentY = ratio * maxContentY
            flickable.contentY = Math.round(Math.max(0, Math.min(maxContentY, desiredContentY)))
            return
        }
        root.positionRequested(ratio)
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
            mouse.accepted = true
            const thumbTopY = root.thumbTop()
            const thumbBottomY = root.thumbBottom()
            root.draggingThumb = mouse.y >= thumbTopY && mouse.y <= thumbBottomY
            if (!root.draggingThumb) {
                return
            }
            root.dragStarted()
            root.dragStartMouseY = mouse.y
            root.dragPointerOffsetY = mouse.y - thumbTopY
            root.dragStartContentY = root.flickable
                ? Number(root.flickable.contentY || 0)
                : 0
        }
        onPositionChanged: function(mouse) {
            mouse.accepted = true
            if (pressed && root.draggingThumb) {
                root.dragThumbToPointer(mouse.y)
            }
        }
        onReleased: {
            if (root.draggingThumb) {
                root.dragEnded()
            }
            root.draggingThumb = false
            root.dragStartMouseY = 0
            root.dragStartContentY = 0
            root.dragPointerOffsetY = 0
        }
        onCanceled: {
            if (root.draggingThumb) {
                root.dragEnded()
            }
            root.draggingThumb = false
            root.dragStartMouseY = 0
            root.dragStartContentY = 0
            root.dragPointerOffsetY = 0
        }
    }
}
