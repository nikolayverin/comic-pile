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
    readonly property int startupFadeDurationMs: 180

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
        opacity: root.startupPrimaryContentVisible ? 0 : 1
        visible: root.showStartupPreview
            && status === Image.Ready
            && (!root.startupPrimaryContentVisible || opacity > 0)
        Behavior on opacity {
            NumberAnimation {
                duration: startupLayer.startupFadeDurationMs
                easing.type: Easing.OutCubic
            }
        }
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
        id: startupFallbackLayer
        anchors.fill: parent
        z: 9999
        opacity: root.startupPrimaryContentVisible ? 0 : 1
        visible: !startupPreviewLayer.visible
            && (!root.startupPrimaryContentVisible || opacity > 0)
        color: root.bgApp

        Behavior on opacity {
            NumberAnimation {
                duration: startupLayer.startupFadeDurationMs
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: startupInventoryOverlay
        anchors.fill: parent
        z: 11000
        opacity: root.startupInventoryRebuildInProgress ? 1 : 0
        visible: root.startupInventoryRebuildInProgress || opacity > 0
        color: startupInventoryOverlayStyle.overlayColor

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            enabled: startupInventoryOverlay.opacity > 0
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
            running: startupInventoryOverlay.opacity > 0
            visible: startupInventoryOverlay.opacity > 0
            width: 28
            height: 28
        }
    }
}
