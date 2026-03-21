import QtQuick
import QtQuick.Window

Item {
    id: root

    required property Window hostWindow
    property int edgeSize: 4
    property int cornerSize: 10
    property bool enabledWhenWindowed: true

    anchors.fill: parent
    visible: enabledWhenWindowed && !!hostWindow && hostWindow.visibility === Window.Windowed

    function beginResize(edges) {
        if (!hostWindow) return
        if (hostWindow.visibility !== Window.Windowed) return
        hostWindow.startSystemResize(edges)
    }

    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.edgeSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeHorCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.LeftEdge)
        }
    }

    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.edgeSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeHorCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.RightEdge)
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.edgeSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeVerCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.TopEdge)
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.edgeSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeVerCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.BottomEdge)
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.cornerSize
        height: root.cornerSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.TopEdge | Qt.LeftEdge)
        }
    }

    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        width: root.cornerSize
        height: root.cornerSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeBDiagCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.TopEdge | Qt.RightEdge)
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.cornerSize
        height: root.cornerSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeBDiagCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.BottomEdge | Qt.LeftEdge)
        }
    }

    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.cornerSize
        height: root.cornerSize
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) root.beginResize(Qt.BottomEdge | Qt.RightEdge)
        }
    }
}
