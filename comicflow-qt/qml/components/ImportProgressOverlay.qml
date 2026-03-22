import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property bool cancelInProgress: false
    property alias dialogItem: importProgressDialog

    signal cancelRequested()
    signal hidden()

    function queueEntryPath(entry) {
        if (!entry) return ""
        if (typeof entry === "string") return String(entry || "")
        if (typeof entry === "object") return String(entry.path || "")
        return ""
    }

    function fileNameFromPath(pathValue) {
        const normalized = String(pathValue || "").replace(/\\/g, "/").trim()
        if (normalized.length < 1) return ""
        const parts = normalized.split("/")
        return parts.length > 0 ? String(parts[parts.length - 1] || "") : normalized
    }

    visible: active && !blockedByModalPopup
    z: 980

    onVisibleChanged: {
        if (!visible) {
            hidden()
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
    readonly property int rightInfoWidth: popupStyle.importProgressRightInfoWidth
    readonly property string queuedPreviewFileName: {
        if (!importQueue || importQueue.length < 1) return ""
        return fileNameFromPath(queueEntryPath(importQueue[0]))
    }

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
        onClicked: function(mouse) {
            const insideDialog = mouse.x >= importProgressDialog.x
                && mouse.x <= (importProgressDialog.x + importProgressDialog.width)
                && mouse.y >= importProgressDialog.y
                && mouse.y <= (importProgressDialog.y + importProgressDialog.height)
            if (!insideDialog) {
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
        enabled: root.visible
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
            title: "Import In Progress"
            onCloseRequested: root.cancelRequested()

            PopupBodyColumn {
                id: importProgressBody
                popupStyle: popupStyle
                spacing: popupStyle.dialogPlainTextSpacing

                PopupProgressBlock {
                    Layout.fillWidth: true
                    popupStyle: popupStyle
                    active: true
                    reserveSpace: true
                    currentFileName: root.currentFileName.length > 0
                        ? root.currentFileName
                        : (root.queuedPreviewFileName.length > 0
                            ? root.queuedPreviewFileName
                            : (root.importQueue.length > 0 ? "Preparing import..." : "Finalizing..."))
                    totalCount: root.totalCount
                    processedCount: root.processedCounterValue
                    progressFraction: root.progressFraction
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
                        text: root.cancelInProgress ? "Cancelling..." : "Cancel"
                        enabled: !root.cancelInProgress
                        onClicked: root.cancelRequested()
                    }
                }
            }
        }
    }
}
