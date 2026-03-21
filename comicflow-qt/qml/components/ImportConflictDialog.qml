import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }

    property string titleText: "Issue Already Exists"
    property string messageText: "This archive matches an existing issue in your library. Choose what to do:"
    property string secondaryActionText: "Keep current"
    property string primaryActionText: "Replace"
    property string incomingLabel: ""
    property string existingLabel: ""
    property string nextIncomingLabel: ""
    property string nextExistingLabel: ""
    property bool showBatchActions: false
    property bool progressActive: false
    property string progressCurrentFileName: ""
    property int progressTotalCount: 0
    property int progressProcessedCount: 0
    property real progressFraction: 0
    property var criticalAttentionTarget: null
    property color criticalAttentionColor: themeColors.dialogAttentionColor
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : popupStyle.importConflictMinHeight

    signal secondaryRequested()
    signal primaryRequested()
    signal skipAllRequested()
    signal replaceAllRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: dialog.titleText
    showCloseButton: false
    closePolicy: Popup.NoAutoClose
    width: Math.max(styleTokens.importConflictWidth, importConflictFooter.requiredDialogWidth)
    height: Math.min(
        availableDialogHeight,
        Math.max(styleTokens.importConflictMinHeight, importConflictLayout.implicitHeight)
    )
    attentionActive: criticalAttentionTarget === dialog && dialog.visible
    attentionColor: criticalAttentionColor

    onCloseRequested: close()

    PopupBodyColumn {
        id: importConflictLayout
        popupStyle: styleTokens
        spacing: styleTokens.dialogContentSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: styleTokens.dialogPlainTextSpacing

            Label {
                text: dialog.messageText
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: styleTokens.textColor
                font.pixelSize: styleTokens.dialogHintFontSize
            }

            PopupInfoBlock {
                Layout.fillWidth: true
                popupStyle: styleTokens
                visible: dialog.incomingLabel.length > 0 || dialog.existingLabel.length > 0

                Text {
                    visible: dialog.incomingLabel.length > 0
                    text: "<font color=\"" + styleTokens.hintTextColor + "\">Incoming archive:</font> "
                        + "<font color=\"" + styleTokens.textColor + "\">"
                        + dialog.incomingLabel
                        + "</font>"
                    textFormat: Text.RichText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    font.pixelSize: styleTokens.dialogBodyFontSize
                    Layout.fillWidth: true
                }

                Text {
                    visible: dialog.existingLabel.length > 0
                    text: "<font color=\"" + styleTokens.hintTextColor + "\">Existing record:</font> "
                        + "<font color=\"" + styleTokens.textColor + "\">"
                        + dialog.existingLabel
                        + "</font>"
                    textFormat: Text.RichText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    font.pixelSize: styleTokens.dialogBodyFontSize
                    Layout.fillWidth: true
                }
            }

            PopupGhostBlock {
                Layout.fillWidth: true
                spacing: 0
                fadeColor: styleTokens.popupFillColor
                visible: dialog.showBatchActions
                    && (dialog.nextIncomingLabel.length > 0 || dialog.nextExistingLabel.length > 0)

                PopupInfoBlock {
                    Layout.fillWidth: true
                    popupStyle: styleTokens

                    Text {
                        visible: dialog.nextIncomingLabel.length > 0
                        text: "<font color=\"" + styleTokens.hintTextColor + "\">Incoming archive:</font> "
                            + "<font color=\"" + styleTokens.textColor + "\">"
                            + dialog.nextIncomingLabel
                            + "</font>"
                        textFormat: Text.RichText
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        font.pixelSize: styleTokens.dialogBodyFontSize
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: dialog.nextExistingLabel.length > 0
                        text: "<font color=\"" + styleTokens.hintTextColor + "\">Existing record:</font> "
                            + "<font color=\"" + styleTokens.textColor + "\">"
                            + dialog.nextExistingLabel
                            + "</font>"
                        textFormat: Text.RichText
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        font.pixelSize: styleTokens.dialogBodyFontSize
                        Layout.fillWidth: true
                    }
                }
            }

            PopupProgressBlock {
                Layout.fillWidth: true
                popupStyle: styleTokens
                reserveSpace: false
                showTitle: false
                showFileRow: false
                active: dialog.progressActive
                currentFileName: dialog.progressCurrentFileName
                totalCount: dialog.progressTotalCount
                processedCount: dialog.progressProcessedCount
                progressFraction: dialog.progressFraction
            }
        }

        PopupFooterRow {
            id: importConflictFooter
            Layout.fillWidth: true
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
                text: dialog.secondaryActionText
                enabled: !dialog.progressActive
                onClicked: dialog.secondaryRequested()
            }

            PopupActionButton {
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: dialog.primaryActionText
                enabled: !dialog.progressActive
                onClicked: dialog.primaryRequested()
            }

            PopupActionButton {
                visible: dialog.showBatchActions
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Skip all"
                enabled: !dialog.progressActive
                onClicked: dialog.skipAllRequested()
            }

            PopupActionButton {
                visible: dialog.showBatchActions
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: "Replace all"
                enabled: !dialog.progressActive
                onClicked: dialog.replaceAllRequested()
            }
        }
    }
}
