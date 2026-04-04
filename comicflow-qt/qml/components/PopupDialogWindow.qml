import QtQuick
import QtQuick.Controls

Popup {
    id: root

    ThemeColors { id: themeColors }
    PopupCloseBehavior {
        id: closeBehavior
        closePolicy: root.closePolicy
    }

    parent: Overlay.overlay
    modal: false
    focus: true
    padding: 0
    z: popupStackLayer

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
    property bool surfaceShadowActive: true
    property bool escapeShortcutEnabled: true
    property int popupStackLayer: 0
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

    function requestPopupDismiss(reason) {
        const dismissReason = String(reason || "dismiss")
        root.tracePopup("dismiss requested reason=" + dismissReason)
        root.closeRequested()
        Qt.callLater(function() {
            if (!root.visible) return
            root.tracePopup("dismiss kept popup visible -> restore focus")
            if (typeof root.forceActiveFocus === "function") {
                root.forceActiveFocus()
            }
        })
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
        enabled: root.visible && root.escapeShortcutEnabled && closeBehavior.closeOnEscape
        onActivated: {
            root.tracePopup("escape shortcut")
            root.requestPopupDismiss("escape")
        }
    }

    background: PopupSurface {
        cornerRadius: root.popupStyle.popupRadius
        fillColor: root.popupStyle.popupFillColor
        edgeColor: root.popupStyle.edgeLineColor
        attentionPulseActive: root.attentionActive
        attentionColor: root.attentionColor
        surfaceShadowActive: root.surfaceShadowActive
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
