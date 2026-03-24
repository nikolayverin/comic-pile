import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    property string dialogTitle: "Action Error"
    property string message: ""
    property string detailsText: ""
    property string secondaryActionText: ""
    property bool secondaryActionVisible: false
    readonly property int textColumnMinWidth: 120
    readonly property int textColumnMaxWidth: 420
    readonly property int footerTopGap: 16
    readonly property int contentTextWidth: Math.max(
        textColumnMinWidth,
        Math.min(
            textColumnMaxWidth,
            Math.max(
                dialog.message.length > 0 ? messageMeasure.advanceWidth : 0,
                dialog.detailsText.length > 0 ? detailsMeasure.advanceWidth : 0
            )
        )
    )
    readonly property int titlePreferredWidth: actionResultTitleMetrics.advanceWidth
        + 48
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : popupStyle.actionResultMinHeight

    signal secondaryRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    titleTopMargin: 12
    title: dialog.dialogTitle
    showCloseButton: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: Math.max(
        actionResultFooter.requiredDialogWidth,
        actionResultContent.implicitWidth,
        titlePreferredWidth
    )
    height: Math.min(
        availableDialogHeight,
        Math.max(styleTokens.actionResultMinHeight, actionResultLayout.implicitHeight)
    )

    onCloseRequested: close()

    PopupBodyColumn {
        id: actionResultLayout
        popupStyle: styleTokens
        topMargin: styleTokens.dialogBodyTopMargin
        bottomMargin: styleTokens.dialogBottomMargin
        sideMargin: 0
        spacing: 0

        TextMetrics {
            id: actionResultTitleMetrics
            font.pixelSize: styleTokens.dialogTitleFontSize
            text: dialog.title
        }

        PopupSystemErrorLayout {
            id: actionResultContent
            Layout.alignment: Qt.AlignHCenter
            visible: dialog.message.length > 0 || dialog.detailsText.length > 0
            popupStyle: styleTokens
            contentWidth: dialog.contentTextWidth
            iconSize: 30
            blockSpacing: 18

            Text {
                visible: dialog.message.length > 0
                text: dialog.message
                color: styleTokens.textColor
                font.family: Qt.application.font.family
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }

            Text {
                visible: dialog.detailsText.length > 0
                text: dialog.detailsText
                color: styleTokens.subtleTextColor
                font.family: Qt.application.font.family
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: dialog.footerTopGap
        }

        PopupFooterRow {
            id: actionResultFooter
            Layout.fillWidth: true
            horizontalPadding: styleTokens.footerSideMargin

            PopupActionButton {
                visible: dialog.secondaryActionVisible
                height: styleTokens.footerButtonHeight
                minimumWidth: styleTokens.footerButtonMinWidth
                horizontalPadding: styleTokens.footerButtonHorizontalPadding
                cornerRadius: styleTokens.footerButtonRadius
                idleColor: styleTokens.footerButtonIdleColor
                hoverColor: styleTokens.footerButtonHoverColor
                textColor: styleTokens.textColor
                textPixelSize: styleTokens.footerButtonTextSize
                text: dialog.secondaryActionText
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
                text: "OK"
                onClicked: dialog.close()
            }
        }

        TextMetrics {
            id: messageMeasure
            font.family: Qt.application.font.family
            font.pixelSize: 12
            text: dialog.message
        }

        TextMetrics {
            id: detailsMeasure
            font.family: Qt.application.font.family
            font.pixelSize: 12
            text: dialog.detailsText
        }
    }
}
