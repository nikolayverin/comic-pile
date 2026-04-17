import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }

    property int dialogWidth: 440
    property int minimumDialogHeight: popupStyle ? popupStyle.confirmDialogMinHeight : 152
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : minimumDialogHeight

    signal archiveRequested()
    signal imageFolderRequested()
    signal cancelRequested()

    debugName: "replace-source-choice-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: Math.max(dialogWidth, footer.requiredDialogWidth)
    height: Math.min(
        availableDialogHeight,
        Math.max(minimumDialogHeight, layout.implicitHeight)
    )

    onCloseRequested: cancelRequested()

    PopupBodyColumn {
        id: layout
        popupStyle: dialog.popupStyle
        spacing: dialog.popupStyle ? dialog.popupStyle.dialogContentSpacing : 16

        Text {
            Layout.fillWidth: true
            text: "Choose what you want to replace the issue with."
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: dialog.popupStyle ? dialog.popupStyle.textColor : themeColors.textPrimary
            font.pixelSize: dialog.popupStyle ? dialog.popupStyle.dialogBodyFontSize : 13
        }

        Text {
            Layout.fillWidth: true
            text: "You can replace it with another archive file or with a folder of ordered page images."
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: dialog.popupStyle ? dialog.popupStyle.subtleTextColor : themeColors.subtleTextColor
            font.pixelSize: dialog.popupStyle ? dialog.popupStyle.dialogBodyFontSize : 13
        }

        PopupFooterRow {
            id: footer
            Layout.fillWidth: true
            horizontalPadding: dialog.popupStyle ? dialog.popupStyle.footerSideMargin : 24
            spacing: dialog.popupStyle ? dialog.popupStyle.footerButtonSpacing : 6

            PopupActionButton {
                height: dialog.popupStyle ? dialog.popupStyle.footerButtonHeight : 20
                minimumWidth: dialog.popupStyle ? dialog.popupStyle.footerButtonMinWidth : 76
                horizontalPadding: dialog.popupStyle ? dialog.popupStyle.footerButtonHorizontalPadding : 18
                cornerRadius: dialog.popupStyle ? dialog.popupStyle.footerButtonRadius : 10
                idleColor: dialog.popupStyle ? dialog.popupStyle.footerButtonIdleColor : themeColors.footerButtonIdleColor
                hoverColor: dialog.popupStyle ? dialog.popupStyle.footerButtonHoverColor : themeColors.footerButtonHoverColor
                textColor: dialog.popupStyle ? dialog.popupStyle.textColor : themeColors.textPrimary
                textPixelSize: dialog.popupStyle ? dialog.popupStyle.footerButtonTextSize : 13
                text: "Image folder"
                onClicked: dialog.imageFolderRequested()
            }

            PopupActionButton {
                height: dialog.popupStyle ? dialog.popupStyle.footerButtonHeight : 20
                minimumWidth: dialog.popupStyle ? dialog.popupStyle.footerButtonMinWidth : 76
                horizontalPadding: dialog.popupStyle ? dialog.popupStyle.footerButtonHorizontalPadding : 18
                cornerRadius: dialog.popupStyle ? dialog.popupStyle.footerButtonRadius : 10
                idleColor: dialog.popupStyle ? dialog.popupStyle.footerButtonIdleColor : themeColors.footerButtonIdleColor
                hoverColor: dialog.popupStyle ? dialog.popupStyle.footerButtonHoverColor : themeColors.footerButtonHoverColor
                textColor: dialog.popupStyle ? dialog.popupStyle.textColor : themeColors.textPrimary
                textPixelSize: dialog.popupStyle ? dialog.popupStyle.footerButtonTextSize : 13
                text: "Archive file"
                onClicked: dialog.archiveRequested()
            }
        }
    }
}
