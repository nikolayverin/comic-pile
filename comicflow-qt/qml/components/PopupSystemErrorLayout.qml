import QtQuick

Item {
    id: root

    property var popupStyle: null
    property real sideInset: 86
    property real contentWidth: 120
    property real iconSize: 30
    property real blockSpacing: 18
    property string iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-alert-triangle.svg"
    property bool iconVisible: true
    default property alias contentData: textColumn.data

    implicitWidth: (sideInset * 2) + contentWidth
    implicitHeight: Math.max(iconVisible ? iconSize : 0, textColumn.implicitHeight)

    Image {
        visible: root.iconVisible
        x: Math.round((root.sideInset - width) / 2)
        anchors.top: textColumn.top
        source: root.iconSource
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        width: root.iconSize
        height: root.iconSize
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Column {
        id: textColumn
        x: root.sideInset
        width: root.contentWidth
        spacing: root.blockSpacing
    }
}
