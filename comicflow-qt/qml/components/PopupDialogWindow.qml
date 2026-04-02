import QtQuick
import QtQuick.Controls

Popup {
    id: root

    ThemeColors { id: themeColors }

    parent: Overlay.overlay
    modal: true
    focus: true
    padding: 0

    property real hostWidth: 0
    property real hostHeight: 0
    property var popupStyle: popupStyleFallback
    property var debugLogTarget: null
    property string title: ""
    property string debugName: ""
    property bool showCloseButton: true
    property real titleTopMargin: -1
    property bool attentionActive: false
    property color attentionColor: themeColors.dialogAttentionColor
    property int fadeDurationMs: 150
    default property alias bodyData: shell.bodyData
    property alias bodyHost: shell.bodyHost

    signal closeRequested()

    function popupDebugLabel() {
        const explicitName = String(debugName || "").trim()
        if (explicitName.length > 0) return explicitName
        const titleText = String(title || "").trim()
        if (titleText.length > 0) return titleText
        return "unnamed-popup"
    }

    function tracePopup(message) {
        const target = debugLogTarget
        if (target && typeof target.appendStartupDebugLog === "function") {
            target.appendStartupDebugLog(
                "[popup-layer] " + popupDebugLabel() + " " + String(message || "")
            )
        }
    }

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

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.visible && Boolean(root.closePolicy & Popup.CloseOnEscape)
        onActivated: {
            root.tracePopup("escape shortcut -> close")
            root.close()
        }
    }

    Overlay.modal: Rectangle {
        color: root.popupStyle.overlayColor

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
                const closeOnOutside = Boolean(root.closePolicy & Popup.CloseOnPressOutside)
                    || Boolean(root.closePolicy & Popup.CloseOnPressOutsideParent)
                root.tracePopup(
                    "overlay clicked"
                    + " closeOnOutside=" + String(closeOnOutside)
                    + " visible=" + String(root.visible)
                )
                if (closeOnOutside) {
                    root.tracePopup("outside click -> close")
                    root.close()
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

    onOpened: tracePopup("opened")
    onClosed: tracePopup("closed")
    onVisibleChanged: tracePopup("visible=" + String(visible))
    onCloseRequested: tracePopup("closeRequested signal")
}
