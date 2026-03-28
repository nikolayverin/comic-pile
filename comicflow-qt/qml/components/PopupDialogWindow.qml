import QtQuick
import QtQuick.Controls

Popup {
    id: root

    ThemeColors { id: themeColors }

    modal: true
    focus: true
    padding: 0

    property real hostWidth: 0
    property real hostHeight: 0
    property var popupStyle: popupStyleFallback
    property string title: ""
    property bool showCloseButton: true
    property real titleTopMargin: -1
    property bool attentionActive: false
    property color attentionColor: themeColors.dialogAttentionColor
    property int fadeDurationMs: 150
    default property alias bodyData: shell.bodyData
    property alias bodyHost: shell.bodyHost

    signal closeRequested()

    x: Math.round((hostWidth - width) / 2)
    y: Math.round((hostHeight - height) / 2)

    PopupStyle {
        id: popupStyleFallback
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: root.fadeDurationMs
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: root.fadeDurationMs
            easing.type: Easing.OutCubic
        }
    }

    Overlay.modal: Rectangle {
        color: root.popupStyle.overlayColor

        MouseArea {
            anchors.fill: parent
            onClicked: {
                const closeOnOutside = Boolean(root.closePolicy & Popup.CloseOnPressOutside)
                    || Boolean(root.closePolicy & Popup.CloseOnPressOutsideParent)
                if (closeOnOutside) {
                    root.closeRequested()
                }
            }
        }
    }

    background: PopupSurface {
        cornerRadius: root.popupStyle.popupRadius
        fillColor: root.popupStyle.popupFillColor
        edgeColor: root.popupStyle.edgeLineColor
        attentionPulseActive: root.attentionActive
        attentionColor: root.attentionColor
    }

    contentItem: PopupDialogShell {
        id: shell
        popupStyle: root.popupStyle
        title: root.title
        showCloseButton: root.showCloseButton
        titleTopMargin: root.titleTopMargin
        onCloseRequested: root.closeRequested()
    }
}
