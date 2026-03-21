import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    property string headline: ""
    property string reasonText: ""
    property string detailsText: ""
    property string systemText: ""
    property string primaryPath: ""
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : popupStyle.deleteErrorMinHeight

    signal retryRequested()
    signal openFolderRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: dialog.headline.length > 0 ? dialog.headline : "Couldn't Remove File"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: Math.max(styleTokens.deleteErrorWidth, deleteErrorFooter.requiredDialogWidth)
    height: Math.min(
        availableDialogHeight,
        Math.max(styleTokens.deleteErrorMinHeight, deleteErrorLayout.implicitHeight)
    )

    onCloseRequested: close()

    PopupBodyColumn {
        id: deleteErrorLayout
        popupStyle: styleTokens
        spacing: styleTokens.dialogContentSpacing

        PopupInfoBlock {
            Layout.fillWidth: true
            popupStyle: styleTokens
            visible: dialog.reasonText.length > 0 || dialog.detailsText.length > 0 || dialog.systemText.length > 0

            Label {
                visible: dialog.reasonText.length > 0
                text: dialog.reasonText
                color: styleTokens.textColor
                font.pixelSize: styleTokens.dialogBodyFontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                visible: dialog.detailsText.length > 0
                text: dialog.detailsText
                color: styleTokens.hintTextColor
                font.pixelSize: styleTokens.dialogHintFontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                visible: dialog.systemText.length > 0
                text: "System: " + dialog.systemText
                color: styleTokens.subtleTextColor
                font.pixelSize: styleTokens.dialogHintFontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        PopupFooterRow {
            id: deleteErrorFooter
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
                text: "Retry"
                onClicked: {
                    dialog.retryRequested()
                }
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
                text: "Open folder"
                enabled: dialog.primaryPath.length > 0
                onClicked: {
                    dialog.openFolderRequested()
                }
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
                text: "Close"
                onClicked: dialog.close()
            }
        }
    }
}
