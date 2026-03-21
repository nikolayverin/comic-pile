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
    property bool attentionActive: false
    property color attentionColor: themeColors.dialogAttentionColor
    default property alias bodyData: shell.bodyData
    property alias bodyHost: shell.bodyHost

    signal closeRequested()

    x: Math.round((hostWidth - width) / 2)
    y: Math.round((hostHeight - height) / 2)

    PopupStyle {
        id: popupStyleFallback
    }

    Overlay.modal: Rectangle {
        color: root.popupStyle.overlayColor
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
        onCloseRequested: root.closeRequested()
    }
}
