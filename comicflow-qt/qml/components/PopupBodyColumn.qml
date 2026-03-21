import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var popupStyle: null
    property real topMargin: popupStyle ? popupStyle.dialogBodyTopMargin : 42
    property real bottomMargin: popupStyle ? popupStyle.dialogBottomMargin : 16
    property real sideMargin: popupStyle ? popupStyle.dialogSideMargin : 24
    property real spacing: popupStyle ? popupStyle.dialogBodySpacing : 14
    default property alias contentData: bodyColumn.data
    property alias layout: bodyColumn
    implicitWidth: bodyColumn.implicitWidth + (sideMargin * 2)
    implicitHeight: bodyColumn.implicitHeight + topMargin + bottomMargin

    anchors.fill: parent

    ColumnLayout {
        id: bodyColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.sideMargin
        anchors.rightMargin: root.sideMargin
        anchors.topMargin: root.topMargin
        anchors.bottomMargin: root.bottomMargin
        spacing: root.spacing
    }
}
