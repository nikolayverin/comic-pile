import QtQuick

Item {
    id: root

    property real spacing: 6
    property real horizontalPadding: 24
    readonly property real requiredDialogWidth: footerRow.implicitWidth + (horizontalPadding * 2)
    default property alias contentData: footerRow.data

    implicitWidth: footerRow.implicitWidth
    implicitHeight: footerRow.implicitHeight

    Row {
        id: footerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing
    }
}
