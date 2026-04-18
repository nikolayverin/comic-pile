import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    signal installRequested()

    readonly property var downloadRef: (typeof releaseDownloadService !== "undefined") ? releaseDownloadService : null
    readonly property bool downloadActive: Boolean(downloadRef) && Boolean(downloadRef.downloadActive)
    readonly property bool downloadProgressKnown: Boolean(downloadRef) && Boolean(downloadRef.downloadProgressKnown)
    readonly property real downloadProgressFraction: Number(downloadRef && downloadRef.downloadProgressFraction || 0)
    readonly property string downloadStatusText: String(downloadRef && downloadRef.statusText || "").trim()
    readonly property string downloadErrorText: String(downloadRef && downloadRef.lastError || "").trim()
    readonly property string downloadedFilePath: String(downloadRef && downloadRef.downloadedFilePath || "").trim()
    readonly property string currentAssetNameText: {
        const runtimeName = String(downloadRef && downloadRef.currentAssetName || "").trim()
        if (runtimeName.length > 0) {
            return runtimeName
        }
        return String(assetNameText || "").trim()
    }
    readonly property bool installReady: dialog.downloadedFilePath.length > 0 && !dialog.downloadActive
    readonly property int progressCounterValue: Math.max(0, Math.min(100, Math.round(dialog.downloadProgressFraction * 100)))
    readonly property bool downloadFailed: dialog.downloadErrorText.length > 0
    readonly property bool progressBlockActive: dialog.downloadActive
        || dialog.installReady
        || dialog.downloadFailed
    readonly property string reservedAlertMessageText: "The update download timed out before it could finish."
    readonly property int minimumDialogHeight: 232
    readonly property int maximumDialogHeight: 520
    readonly property int availableDialogHeight: hostHeight > 0
        ? Math.min(maximumDialogHeight, hostHeight - 80)
        : maximumDialogHeight
    property string assetNameText: ""

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "update-download-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: "Downloading update"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 560
    height: Math.min(availableDialogHeight, Math.max(minimumDialogHeight, downloadBody.implicitHeight))

    onCloseRequested: {
        if (dialog.downloadRef && dialog.downloadActive) {
            dialog.downloadRef.cancelDownload()
        }
        close()
    }

    PopupBodyColumn {
        id: downloadBody
        popupStyle: styleTokens
        spacing: 4

        PopupProgressBlock {
            Layout.fillWidth: true
            popupStyle: styleTokens
            active: dialog.progressBlockActive
            reserveSpace: true
            titleText: "Current file"
            currentFileName: dialog.currentAssetNameText
            showFileCounter: false
            percentOnlyStatus: true
            totalCount: dialog.progressBlockActive && (dialog.downloadProgressKnown || dialog.downloadFailed) ? 100 : 0
            processedCount: dialog.installReady
                ? 100
                : (dialog.progressBlockActive && dialog.downloadProgressKnown ? dialog.progressCounterValue : 0)
            progressFraction: dialog.downloadProgressFraction
            statusTextOverride: ""
            forceIndeterminate: dialog.downloadActive && !dialog.downloadProgressKnown
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: reservedDownloadAlert.implicitHeight

            PopupInlineErrorMessage {
                id: downloadAlert
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: dialog.downloadErrorText.length > 0
                headline: "Download failed"
                message: dialog.downloadErrorText
                textColor: styleTokens.textColor
            }

            PopupInlineErrorMessage {
                id: reservedDownloadAlert
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: true
                opacity: 0
                enabled: false
                headline: "Download failed"
                message: dialog.downloadErrorText.length > 0
                    ? dialog.downloadErrorText
                    : dialog.reservedAlertMessageText
                textColor: styleTokens.textColor
            }
        }

        PopupFooterRow {
            Layout.fillWidth: true
            Layout.topMargin: 4
            horizontalPadding: styleTokens.footerSideMargin
            spacing: styleTokens.footerButtonSpacing

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Cancel"
                onClicked: dialog.closeRequested()
            }

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: 148
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: "#84db3f"
                hoverColor: "#459b00"
                idleEdgeColor: "#1e4400"
                hoverEdgeColor: "#e2ff40"
                textColor: "#000000"
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Install update"
                enabled: dialog.installReady
                onClicked: dialog.installRequested()
            }
        }
    }
}
