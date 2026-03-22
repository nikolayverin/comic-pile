import QtQuick
import QtQuick.Controls

Item {
    id: startupLayer
    anchors.fill: parent

    property var rootObject: null
    property var startupControllerRef: null
    property var uiTokensRef: null

    readonly property var root: rootObject
    readonly property var startupController: startupControllerRef
    readonly property var uiTokens: uiTokensRef

    PopupStyle { id: startupInventoryOverlayStyle }

    Image {
        id: startupPreviewLayer
        anchors.fill: parent
        z: 10000
        source: root.startupPreviewSource
        asynchronous: false
        cache: false
        smooth: true
        fillMode: Image.Stretch
        visible: root.showStartupPreview && status === Image.Ready && !root.startupPrimaryContentVisible
        onStatusChanged: {
            if (
                status === Image.Error
                    && root.showStartupPreview
                    && !root.startupPreviewTriedFallback
                    && root.startupPreviewFallbackPath.length > 0
            ) {
                root.startupPreviewTriedFallback = true
                root.startupPreviewSource = startupController.toLocalFileUrl(root.startupPreviewFallbackPath)
                    + "?v=" + String(Date.now())
                startupController.startupLog("preview fallback to jpg")
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 9999
        visible: !root.startupPrimaryContentVisible && !startupPreviewLayer.visible
        color: root.bgApp
    }

    Rectangle {
        anchors.fill: parent
        z: 11000
        visible: root.startupInventoryRebuildInProgress
        color: startupInventoryOverlayStyle.overlayColor

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onPressed: function(mouse) { mouse.accepted = true }
            onClicked: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
        }

        Text {
            id: startupInventoryOverlayText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -28
            text: uiTokens.inventoryRebuildStatus
            color: root.textPrimary
            font.family: root.uiFontFamily
            font.pixelSize: root.fontPxUiBase
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
        }

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: startupInventoryOverlayText.bottom
            anchors.topMargin: 42
            running: parent.visible
            visible: parent.visible
            width: 28
            height: 28
        }
    }
}
