import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "AppText.js" as AppText

PopupDialogWindow {
    id: dialog

    signal downloadRequested()

    property string textLanguage: AppText.fallbackLanguageCode
    readonly property var updatesRef: (typeof releaseCheckService !== "undefined") ? releaseCheckService : null
    readonly property string latestVersionText: String(updatesRef && updatesRef.latestVersion || "").trim()
    readonly property string latestAssetNameText: String(updatesRef && updatesRef.latestAssetName || "").trim()
    readonly property string releaseNameText: String(updatesRef && updatesRef.latestReleaseName || "").trim()
    readonly property string updateDownloadUrl: String(updatesRef && updatesRef.latestAssetDownloadUrl || "").trim()
    readonly property string releaseNotesText: normalizedReleaseNotes(String(updatesRef && updatesRef.latestReleaseNotes || ""))
    property bool autoPromptActive: false
    property string autoPromptVersion: ""
    readonly property string releaseLabelText: {
        if (dialog.releaseNameText.length > 0) {
            return dialog.releaseNameText
        }
        if (dialog.latestVersionText.length > 0) {
            return AppText.tf("updateAvailablePatchLabel", { version: dialog.latestVersionText }, dialog.textLanguage)
        }
        return ""
    }
    readonly property int minimumDialogHeight: 240
    readonly property int maximumDialogHeight: 800
    readonly property int availableDialogHeight: hostHeight > 0
        ? Math.min(maximumDialogHeight, hostHeight - 80)
        : maximumDialogHeight
    readonly property int notesViewportMaxHeight: 700
    readonly property int footerZoneHeight: styleTokens.footerButtonHeight
        + styleTokens.formFooterTopGap
        + styleTokens.footerBottomMargin
    readonly property int notesViewportPreferredHeight: Math.min(
        dialog.notesViewportMaxHeight,
        Math.max(120, releaseNotesContent.implicitHeight)
    )
    readonly property int contentImplicitHeight: styleTokens.dialogBodyTopMargin
        + headerBlock.implicitHeight
        + styleTokens.dialogContentSpacing
        + dialog.notesViewportPreferredHeight
        + dialog.footerZoneHeight
        + styleTokens.dialogBottomMargin

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "update-available-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: AppText.t("updateAvailableTitle", dialog.textLanguage)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 560
    height: Math.min(
        availableDialogHeight,
        Math.max(minimumDialogHeight, contentImplicitHeight)
    )

    onCloseRequested: close()
    onClosed: {
        if (dialog.autoPromptActive && dialog.updatesRef) {
            const dismissedVersion = String(dialog.autoPromptVersion || dialog.latestVersionText || "").trim()
            if (dismissedVersion.length > 0) {
                dialog.updatesRef.markUpdateDismissed(dismissedVersion)
            }
        }
        dialog.autoPromptActive = false
        dialog.autoPromptVersion = ""
    }

    function openExternalLink(url) {
        const link = String(url || "").trim()
        if (link.length < 1) {
            return
        }
        Qt.openUrlExternally(link)
    }

    function normalizedReleaseNotes(notesText) {
        const normalized = String(notesText || "").replace(/\r\n/g, "\n").trim()
        if (normalized.length < 1) {
            return AppText.t("updateAvailableReleaseNotesFallback", dialog.textLanguage)
        }
        return normalized
    }

    Item {
        anchors.fill: parent

        Item {
            id: contentArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: footerArea.top
            anchors.leftMargin: styleTokens.dialogSideMargin
            anchors.rightMargin: styleTokens.dialogSideMargin
            anchors.topMargin: styleTokens.dialogBodyTopMargin
            anchors.bottomMargin: styleTokens.formFooterTopGap

            Item {
                id: headerBlock
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                implicitHeight: Math.max(whatsNewLabel.implicitHeight, releaseLabel.implicitHeight)

                Text {
                    id: whatsNewLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.right: releaseLabel.left
                    anchors.rightMargin: 16
                    text: AppText.t("topMenuWhatsNew", dialog.textLanguage)
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: styleTokens.dialogBodyEmphasisFontSize
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                Text {
                    id: releaseLabel
                    anchors.top: parent.top
                    anchors.right: parent.right
                    visible: dialog.releaseLabelText.length > 0
                    text: dialog.releaseLabelText
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: styleTokens.dialogBodyEmphasisFontSize
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                }
            }

            Item {
                id: notesViewportHost
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerBlock.bottom
                anchors.topMargin: styleTokens.dialogContentSpacing
                anchors.bottom: parent.bottom

                Flickable {
                    id: notesFlick
                    anchors.fill: parent
                    anchors.rightMargin: 10
                    clip: true
                    contentWidth: width
                    contentHeight: releaseNotesContent.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Text {
                        id: releaseNotesContent
                        width: notesFlick.width
                        text: dialog.releaseNotesText
                        color: styleTokens.textColor
                        textFormat: Text.MarkdownText
                        font.family: Qt.application.font.family
                        font.pixelSize: styleTokens.dialogBodyFontSize
                        wrapMode: Text.WordWrap
                        lineHeight: 1.24
                        lineHeightMode: Text.ProportionalHeight
                    }
                }

                VerticalScrollThumb {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 8
                    visible: notesFlick.contentHeight > notesFlick.height
                    flickable: notesFlick
                    thumbWidth: 8
                    thumbInset: 0
                    thumbColor: "#111111"
                }
            }
        }

        Item {
            id: footerArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: styleTokens.dialogSideMargin
            anchors.rightMargin: styleTokens.dialogSideMargin
            anchors.bottomMargin: styleTokens.dialogBottomMargin
            height: dialog.footerZoneHeight

            PopupFooterRow {
                id: footerButtons
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
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
                    text: AppText.t("updateAvailableLater", dialog.textLanguage)
                    onClicked: dialog.close()
                }

                PopupActionButton {
                    height: styleTokens.footerButtonHeight
                    minimumWidth: 132
                    horizontalPadding: styleTokens.footerButtonHorizontalPadding
                    cornerRadius: styleTokens.footerButtonRadius
                    idleColor: "#84db3f"
                    hoverColor: "#459b00"
                    idleEdgeColor: "#1e4400"
                    hoverEdgeColor: "#e2ff40"
                    textColor: "#000000"
                    textPixelSize: styleTokens.footerButtonTextSize
                    text: AppText.t("updateAvailableDownload", dialog.textLanguage)
                    enabled: dialog.updateDownloadUrl.length > 0
                    onClicked: dialog.downloadRequested()
                }
            }
        }
    }
}
