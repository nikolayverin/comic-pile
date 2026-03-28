import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }

    property string messageText: ""
    property int messageTextFormat: Text.PlainText
    property int messageHorizontalAlignment: Text.AlignHCenter
    property int dialogWidth: 420
    property int minimumDialogHeight: popupStyle ? popupStyle.confirmDialogMinHeight : 138
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : minimumDialogHeight
    property bool busy: false
    property string busyText: ""
    property string primaryButtonText: "OK"
    property string secondaryButtonText: "Cancel"
    property var criticalAttentionTarget: null
    property color criticalAttentionColor: themeColors.dialogAttentionColor

    signal primaryRequested()
    signal secondaryRequested()

    closePolicy: Popup.NoAutoClose
    width: Math.max(dialogWidth, confirmFooter.requiredDialogWidth)
    height: Math.min(
        availableDialogHeight,
        Math.max(minimumDialogHeight, confirmLayout.implicitHeight)
    )
    attentionActive: criticalAttentionTarget === dialog && dialog.visible
    attentionColor: criticalAttentionColor

    onCloseRequested: {
        if (!dialog.busy) {
            secondaryRequested()
        }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        enabled: dialog.visible && !dialog.busy
        onActivated: dialog.secondaryRequested()
    }

    PopupBodyColumn {
        id: confirmLayout
        popupStyle: dialog.popupStyle
        spacing: dialog.popupStyle ? dialog.popupStyle.dialogContentSpacing : 16

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: dialog.messageText
            textFormat: dialog.messageTextFormat
            wrapMode: Text.WordWrap
            horizontalAlignment: dialog.messageHorizontalAlignment
            verticalAlignment: Text.AlignVCenter
            color: dialog.popupStyle ? dialog.popupStyle.textColor : themeColors.textPrimary
            font.pixelSize: dialog.popupStyle ? dialog.popupStyle.dialogBodyFontSize : 13
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: dialog.busy
            spacing: 10

            BusyIndicator {
                running: dialog.busy
                visible: dialog.busy
                implicitWidth: 20
                implicitHeight: 20
            }

            Text {
                text: dialog.busyText.length > 0 ? dialog.busyText : "Working..."
                color: dialog.popupStyle ? dialog.popupStyle.subtleTextColor : themeColors.subtleTextColor
                font.pixelSize: dialog.popupStyle ? dialog.popupStyle.dialogBodyFontSize : 13
                wrapMode: Text.WordWrap
            }
        }

        PopupFooterRow {
            id: confirmFooter
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
                text: dialog.secondaryButtonText
                enabled: !dialog.busy
                onClicked: dialog.secondaryRequested()
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
                text: dialog.primaryButtonText
                enabled: !dialog.busy
                onClicked: dialog.primaryRequested()
            }
        }
    }
}

