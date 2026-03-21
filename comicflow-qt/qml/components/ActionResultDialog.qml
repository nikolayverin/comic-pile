import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }

    property color dangerColor: themeColors.dangerColor
    property string message: ""
    property string detailsText: ""
    property string secondaryActionText: ""
    property bool secondaryActionVisible: false
    readonly property int alertIconSize: 32
    readonly property int alertBlockSpacing: 24
    readonly property int alertMaxTextWidth: 360
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : popupStyle.actionResultMinHeight

    signal secondaryRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: "Action Error"
    showCloseButton: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: Math.max(styleTokens.actionResultWidth, actionResultFooter.requiredDialogWidth)
    height: Math.min(
        availableDialogHeight,
        Math.max(styleTokens.actionResultMinHeight, actionResultLayout.implicitHeight)
    )

    onCloseRequested: close()

    PopupBodyColumn {
        id: actionResultLayout
        popupStyle: styleTokens
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: styleTokens.dialogContentSpacing
        }

        Item {
            id: alertBlock
            Layout.fillWidth: true
            visible: dialog.message.length > 0 || dialog.detailsText.length > 0
            readonly property int measuredTextWidth: Math.max(
                dialog.message.length > 0 ? messageMeasure.implicitWidth : 0,
                dialog.detailsText.length > 0 ? detailsMeasure.implicitWidth : 0
            )
            readonly property int textColumnWidth: Math.min(
                alertMaxTextWidth,
                Math.max(1, measuredTextWidth)
            )
            implicitHeight: Math.max(dialog.alertIconSize, textBlock.implicitHeight)

            Row {
                id: alertRow
                anchors.centerIn: parent
                spacing: dialog.alertBlockSpacing

                Image {
                    anchors.verticalCenter: textBlock.verticalCenter
                    source: "qrc:/qt/qml/ComicPile/assets/icons/icon-alert-triangle.svg"
                    sourceSize.width: dialog.alertIconSize
                    sourceSize.height: dialog.alertIconSize
                    width: dialog.alertIconSize
                    height: dialog.alertIconSize
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Column {
                    id: textBlock
                    width: alertBlock.textColumnWidth
                    spacing: 8

                    Text {
                        visible: dialog.message.length > 0
                        id: messageText
                        text: dialog.message
                        color: styleTokens.textColor
                        font.family: Qt.application.font.family
                        font.pixelSize: styleTokens.dialogBodyFontSize + 1
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Text {
                        visible: dialog.detailsText.length > 0
                        id: detailsTextItem
                        text: dialog.detailsText
                        color: styleTokens.subtleTextColor
                        font.family: Qt.application.font.family
                        font.pixelSize: styleTokens.dialogHintFontSize + 1
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                }
            }

            Text {
                id: messageMeasure
                visible: false
                text: dialog.message
                font.family: Qt.application.font.family
                font.pixelSize: styleTokens.dialogBodyFontSize + 1
                font.weight: Font.Medium
            }

            Text {
                id: detailsMeasure
                visible: false
                text: dialog.detailsText
                font.family: Qt.application.font.family
                font.pixelSize: styleTokens.dialogHintFontSize + 1
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: styleTokens.dialogContentSpacing
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
    }
}
