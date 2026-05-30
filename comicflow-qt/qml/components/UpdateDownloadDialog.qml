import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "AppText.js" as AppText

PopupDialogWindow {
    id: dialog

    signal installRequested()

    property string textLanguage: AppText.fallbackLanguageCode
    readonly property var downloadRef: (typeof releaseDownloadService !== "undefined") ? releaseDownloadService : null
    readonly property bool downloadActive: Boolean(downloadRef) && Boolean(downloadRef.downloadActive)
    readonly property bool downloadProgressKnown: Boolean(downloadRef) && Boolean(downloadRef.downloadProgressKnown)
    readonly property real downloadProgressFraction: Number(downloadRef && downloadRef.downloadProgressFraction || 0)
    readonly property real effectiveProgressFraction: dialog.installReady ? 1.0 : dialog.downloadProgressFraction
    readonly property real downloadedBytes: Number(downloadRef && downloadRef.downloadedBytes || 0)
    readonly property real downloadTotalBytes: Number(downloadRef && downloadRef.downloadTotalBytes || 0)
    readonly property string downloadStatusText: String(downloadRef && downloadRef.statusText || "").trim()
    readonly property string downloadErrorText: String(downloadRef && downloadRef.lastError || "").trim()
    readonly property string downloadedFilePath: String(downloadRef && downloadRef.downloadedFilePath || "").trim()
    readonly property string currentAssetNameText: {
        const runtimeName = String(downloadRef && downloadRef.currentAssetName || "").trim()
        if (runtimeName.length > 0) {
            return runtimeName
        }
        const pendingName = String(assetNameText || "").trim()
        if (pendingName.length > 0) {
            return pendingName
        }
        return AppText.t("updateDownloadPreparingFile", dialog.textLanguage)
    }
    readonly property bool installReady: dialog.downloadedFilePath.length > 0 && !dialog.downloadActive
    readonly property int progressCounterValue: Math.max(0, Math.min(100, Math.round(dialog.downloadProgressFraction * 100)))
    readonly property bool downloadFailed: dialog.downloadErrorText.length > 0
    readonly property bool progressBlockActive: dialog.downloadActive
        || dialog.installReady
        || dialog.downloadFailed
    readonly property bool passiveDismissBlocked: dialog.downloadActive
    readonly property string progressTitleText: dialog.installReady
        ? AppText.t("updateDownloadReadyTitle", dialog.textLanguage)
        : AppText.t("updateDownloadProgressTitle", dialog.textLanguage)
    readonly property string contextText: dialog.installReady
        ? AppText.t("updateDownloadReadyContext", dialog.textLanguage)
        : AppText.t("updateDownloadContext", dialog.textLanguage)
    readonly property string progressStatusText: dialog.installReady
        ? "100%"
        : (dialog.downloadProgressKnown ? (String(dialog.progressCounterValue) + "%") : "")
    readonly property string downloadDetailText: {
        if (dialog.installReady) {
            return AppText.t("updateDownloadReadyMessage", dialog.textLanguage)
        }
        if (dialog.downloadProgressKnown && dialog.downloadTotalBytes > 0) {
            return AppText.tf("updateDownloadSizeKnown", {
                downloaded: dialog.formatByteCount(dialog.downloadedBytes),
                total: dialog.formatByteCount(dialog.downloadTotalBytes)
            }, dialog.textLanguage)
        }
        if (dialog.downloadedBytes > 0) {
            return AppText.tf("updateDownloadSizeUnknown", {
                downloaded: dialog.formatByteCount(dialog.downloadedBytes)
            }, dialog.textLanguage)
        }
        return ""
    }
    readonly property string reservedAlertMessageText: AppText.t("updateDownloadTimedOut", dialog.textLanguage)
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
    title: AppText.t("updateDownloadTitle", dialog.textLanguage)
    showCloseButton: !dialog.passiveDismissBlocked
    closePolicy: dialog.passiveDismissBlocked
        ? Popup.NoAutoClose
        : (Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent)
    width: 560
    height: Math.min(availableDialogHeight, Math.max(minimumDialogHeight, downloadBody.implicitHeight))

    function formatByteCount(bytes) {
        const normalizedBytes = Math.max(0, Number(bytes || 0))
        if (normalizedBytes >= 1024 * 1024) {
            return (normalizedBytes / (1024 * 1024)).toFixed(1) + " MB"
        }
        if (normalizedBytes >= 1024) {
            return Math.round(normalizedBytes / 1024) + " KB"
        }
        return Math.round(normalizedBytes) + " B"
    }

    function cancelDownloadAndClose() {
        if (dialog.downloadRef && dialog.downloadActive) {
            dialog.downloadRef.cancelDownload()
        }
        close()
    }

    onCloseRequested: {
        if (dialog.passiveDismissBlocked) {
            if (typeof dialog.forceActiveFocus === "function") {
                dialog.forceActiveFocus()
            }
            return
        }
        close()
    }

    PopupBodyColumn {
        id: downloadBody
        popupStyle: styleTokens
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: dialog.contextText
            color: styleTokens.subtleTextColor
            font.family: Qt.application.font.family
            font.pixelSize: styleTokens.dialogBodyFontSize
            wrapMode: Text.WordWrap
            lineHeight: 1.2
            lineHeightMode: Text.ProportionalHeight
        }

        PopupProgressBlock {
            Layout.fillWidth: true
            popupStyle: styleTokens
            active: dialog.progressBlockActive
            reserveSpace: true
            titleText: dialog.progressTitleText
            currentFileName: dialog.currentAssetNameText
            showFileCounter: false
            percentOnlyStatus: true
            totalCount: dialog.installReady
                ? 100
                : (dialog.progressBlockActive && (dialog.downloadProgressKnown || dialog.downloadFailed) ? 100 : 0)
            processedCount: dialog.installReady
                ? 100
                : (dialog.progressBlockActive && dialog.downloadProgressKnown ? dialog.progressCounterValue : 0)
            progressFraction: dialog.effectiveProgressFraction
            statusTextOverride: dialog.progressStatusText
            forceIndeterminate: dialog.downloadActive && !dialog.downloadProgressKnown
        }

        Text {
            Layout.fillWidth: true
            visible: dialog.downloadDetailText.length > 0
            text: dialog.downloadDetailText
            color: styleTokens.subtleTextColor
            font.family: Qt.application.font.family
            font.pixelSize: styleTokens.dialogHintFontSize
            wrapMode: Text.WordWrap
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
                headline: AppText.t("updateDownloadFailed", dialog.textLanguage)
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
                headline: AppText.t("updateDownloadFailed", dialog.textLanguage)
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
                text: AppText.t("commonCancel", dialog.textLanguage)
                onClicked: dialog.cancelDownloadAndClose()
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
                text: AppText.t("updateDownloadInstall", dialog.textLanguage)
                enabled: dialog.installReady
                onClicked: dialog.installRequested()
            }
        }
    }
}
