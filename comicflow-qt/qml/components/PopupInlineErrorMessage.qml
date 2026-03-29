import QtQuick
import "AppText.js" as AppText

Item {
    id: root

    property string headline: AppText.seriesMetaInlineErrorHeadline
    property string message: ""
    property color textColor: "#ffffff"
    property string iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-alert-triangle.svg"
    property int iconSize: 16
    property int headlinePixelSize: 12
    property int bodyPixelSize: 11
    property int spacing: 14
    property int textGap: 14

    visible: message.length > 0
    implicitHeight: visible ? Math.max(iconSize, textHost.implicitHeight) : 0

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Image {
            width: root.iconSize
            height: root.iconSize
            source: root.iconSource
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Item {
            id: textHost
            width: Math.max(0, root.width - (root.iconSize + root.spacing))
            implicitHeight: Math.max(headlineText.implicitHeight, bodyText.implicitHeight)

            Text {
                id: headlineText
                anchors.left: parent.left
                anchors.top: parent.top
                text: root.headline
                color: root.textColor
                font.family: Qt.application.font.family
                font.pixelSize: root.headlinePixelSize
                font.weight: Font.Bold
            }

            Text {
                id: bodyText
                anchors.left: headlineText.right
                anchors.leftMargin: root.textGap
                anchors.top: parent.top
                width: Math.max(0, parent.width - headlineText.implicitWidth - root.textGap)
                text: root.message
                color: root.textColor
                font.family: Qt.application.font.family
                font.pixelSize: root.bodyPixelSize
                wrapMode: Text.WordWrap
            }
        }
    }
}
