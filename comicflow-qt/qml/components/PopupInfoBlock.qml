import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var popupStyle: null
    property real spacing: popupStyle ? popupStyle.dialogInfoBlockSpacing : 8
    default property alias contentData: infoColumn.data

    implicitWidth: infoColumn.implicitWidth
    implicitHeight: infoColumn.implicitHeight

    ColumnLayout {
        id: infoColumn
        anchors.fill: parent
        spacing: root.spacing
    }
}
