import QtQuick

Item {
    id: root

    property var targetItem: null
    property int cornerRadius: 12
    property color lineColor: "#878787"
    property string edge: "bottom" // "top" | "bottom"
    property bool forceVisible: false

    readonly property bool focusActive: {
        const t = targetItem
        if (!t) return false
        return t.activeFocus === true || t.visualFocus === true || t.focus === true
    }

    visible: forceVisible || focusActive
    z: -1
    x: targetItem ? Number(targetItem.x || 0) : 0
    y: targetItem
        ? (edge === "top"
            ? Number(targetItem.y || 0) - 1
            : Number(targetItem.y || 0) + 1)
        : 0
    width: targetItem ? Number(targetItem.width || 0) : 0
    height: targetItem ? Number(targetItem.height || 0) : 0

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: root.lineColor
    }

    Connections {
        target: root.targetItem
        ignoreUnknownSignals: true
        function onActiveFocusChanged() {}
        function onVisualFocusChanged() {}
        function onFocusChanged() {}
    }
}
