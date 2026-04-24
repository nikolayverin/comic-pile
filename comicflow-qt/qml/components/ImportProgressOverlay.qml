import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "AppSharedUtils.js" as AppSharedUtils

Item {
    id: root

    ThemeColors { id: themeColors }

    anchors.fill: parent

    property bool active: false
    property bool blockedByModalPopup: false
    property var criticalAttentionTarget: null
    property color criticalAttentionColor: themeColors.dialogAttentionColor
    property string currentFileName: ""
    property var importQueue: []
    property int totalCount: 0
    property int processedCount: 0
    property double totalBytes: 0
    property double processedBytes: 0
    property bool cancelPending: false
    property bool cleanupActive: false
    property int cleanupTotalCount: 0
    property int cleanupProcessedCount: 0
    property string cleanupCurrentFileName: ""
    property alias dialogItem: importProgressDialog
    readonly property bool presented: active && !blockedByModalPopup
    readonly property int fadeDurationMs: 150

    signal cancelRequested()
    signal hidden()

    function queueEntryPath(entry) {
        if (!entry) return ""
        if (typeof entry === "string") return String(entry || "")
        if (typeof entry === "object") return String(entry.path || "")
        return ""
    }

    function fileNameFromPath(pathValue) {
        return AppSharedUtils.fileNameFromPath(pathValue)
    }

    visible: presented || opacity > 0
    opacity: presented ? 1 : 0
    z: 980

    onVisibleChanged: {
        if (!visible) {
            hidden()
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.fadeDurationMs
            easing.type: Easing.OutCubic
        }
    }

    readonly property real progressFraction: {
        if (totalBytes > 0) {
            return Math.max(0, Math.min(1, processedBytes / totalBytes))
        }
        if (totalCount > 0) {
            return Math.max(0, Math.min(1, processedCount / totalCount))
        }
        return 0
    }
    readonly property int progressPercent: Math.round(progressFraction * 100)
    readonly property int processedCounterValue: totalCount > 0
        ? Math.max(0, Math.min(totalCount, processedCount))
        : 0
    readonly property string fileCounterText: String(processedCounterValue) + " / " + String(Math.max(0, totalCount))
    readonly property bool cancelFlowActive: cancelPending || cleanupActive
    readonly property real cleanupProgressFraction: cleanupTotalCount > 0
        ? Math.max(0, Math.min(1, cleanupProcessedCount / cleanupTotalCount))
        : 0
    readonly property int rightInfoWidth: popupStyle.importProgressRightInfoWidth
    readonly property string queuedPreviewFileName: {
        if (!importQueue || importQueue.length < 1) return ""
        return fileNameFromPath(queueEntryPath(importQueue[0]))
    }
    readonly property string dialogTitle: cancelFlowActive ? "Cancelling Import" : "Import In Progress"
    readonly property string progressTitleText: cleanupActive ? "Cleanup progress" : "Current file"
    readonly property string effectiveCurrentFileName: cleanupActive
        ? (cleanupCurrentFileName.length > 0 ? cleanupCurrentFileName : "Cleaning up imported items...")
        : (cancelPending
            ? (currentFileName.length > 0 ? currentFileName : "Waiting for a safe stop...")
            : (currentFileName.length > 0
                ? currentFileName
                : (queuedPreviewFileName.length > 0
                    ? queuedPreviewFileName
                    : (importQueue.length > 0 ? "Preparing import..." : "Finalizing..."))))
    readonly property int effectiveTotalCount: cleanupActive ? Math.max(0, cleanupTotalCount) : totalCount
    readonly property int effectiveProcessedCount: cleanupActive
        ? Math.max(0, Math.min(cleanupTotalCount, cleanupProcessedCount))
        : processedCounterValue
    readonly property real effectiveProgressFraction: cleanupActive ? cleanupProgressFraction : progressFraction
    readonly property string progressStatusText: cleanupActive
        ? "Cleaning up..."
        : (cancelPending ? "Cancelling..." : "")
    readonly property bool progressForceIndeterminate: cancelPending && !cleanupActive

    PopupStyle {
        id: popupStyle
    }

    Rectangle {
        anchors.fill: parent
        color: popupStyle.overlayColor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        enabled: root.presented
        onClicked: function(mouse) {
            const insideDialog = mouse.x >= importProgressDialog.x
                && mouse.x <= (importProgressDialog.x + importProgressDialog.width)
                && mouse.y >= importProgressDialog.y
                && mouse.y <= (importProgressDialog.y + importProgressDialog.height)
            if (!insideDialog && !root.cancelFlowActive) {
                root.cancelRequested()
            }
            mouse.accepted = true
        }
        onPressed: function(mouse) { mouse.accepted = true }
        onReleased: function(mouse) { mouse.accepted = true }
        onWheel: function(wheel) { wheel.accepted = true }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.presented && !root.cancelFlowActive
        onActivated: root.cancelRequested()
    }

    Item {
        id: importProgressDialog
        width: Math.max(popupStyle.importProgressWidth, importProgressFooter.requiredDialogWidth)
        readonly property int availableDialogHeight: root.height > 0
            ? root.height - 80
            : popupStyle.confirmDialogMinHeight
        height: Math.min(
            availableDialogHeight,
            Math.max(popupStyle.confirmDialogMinHeight, importProgressBody.implicitHeight)
        )
        anchors.centerIn: parent

        PopupSurface {
            anchors.fill: parent
            cornerRadius: popupStyle.popupRadius
            fillColor: popupStyle.popupFillColor
            edgeColor: popupStyle.edgeLineColor
            attentionPulseActive: root.criticalAttentionTarget === importProgressDialog && root.active
            attentionColor: root.criticalAttentionColor
        }

        PopupDialogShell {
            anchors.fill: parent
            popupStyle: popupStyle
            title: root.dialogTitle
            onCloseRequested: {
                if (!root.cancelFlowActive) {
                    root.cancelRequested()
                }
            }

            PopupBodyColumn {
                id: importProgressBody
                popupStyle: popupStyle
                spacing: popupStyle.dialogPlainTextSpacing

                PopupProgressBlock {
                    Layout.fillWidth: true
                    popupStyle: popupStyle
                    active: true
                    reserveSpace: true
                    titleText: root.progressTitleText
                    currentFileName: root.effectiveCurrentFileName
                    totalCount: root.effectiveTotalCount
                    processedCount: root.effectiveProcessedCount
                    progressFraction: root.effectiveProgressFraction
                    statusTextOverride: root.progressStatusText
                    forceIndeterminate: root.progressForceIndeterminate
                }

                PopupFooterRow {
                    id: importProgressFooter
                    Layout.fillWidth: true
                    horizontalPadding: popupStyle.footerSideMargin
                    spacing: popupStyle.footerButtonSpacing

                    PopupActionButton {
                        height: popupStyle.footerButtonHeight
                        minimumWidth: popupStyle.footerButtonMinWidth
                        horizontalPadding: popupStyle.footerButtonHorizontalPadding
                        cornerRadius: popupStyle.footerButtonRadius
                        idleColor: popupStyle.footerButtonIdleColor
                        hoverColor: popupStyle.footerButtonHoverColor
                        textColor: popupStyle.textColor
                        textPixelSize: popupStyle.footerButtonTextSize
                        text: root.cleanupActive ? "Cleaning up..." : (root.cancelPending ? "Cancelling..." : "Cancel")
                        enabled: !root.cancelFlowActive
                        onClicked: root.cancelRequested()
                    }
                }
            }
        }
    }
}
