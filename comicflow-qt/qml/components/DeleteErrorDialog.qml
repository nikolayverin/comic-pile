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
    property bool retryActive: false
    property string retryStatusText: ""
    readonly property int textColumnMinWidth: 120
    readonly property int textColumnMaxWidth: 420
    readonly property int footerTopGap: 16
    readonly property int contentTextWidth: Math.max(
        textColumnMinWidth,
        Math.min(
            textColumnMaxWidth,
            Math.max(
                dialog.reasonText.length > 0 ? deleteReasonMetrics.advanceWidth : 0,
                dialog.detailsText.length > 0 ? deleteDetailsMetrics.advanceWidth : 0,
                dialog.systemText.length > 0 ? deleteSystemMetrics.advanceWidth : 0
            )
        )
    )
    readonly property int titlePreferredWidth: deleteErrorTitleMetrics.advanceWidth
        + styleTokens.closeButtonSize
        + styleTokens.closeRightMargin
        + styleTokens.dialogSideMargin
        + 24
    readonly property int availableDialogHeight: hostHeight > 0
        ? hostHeight - 80
        : popupStyle.deleteErrorMinHeight

    signal retryRequested()
    signal openFolderRequested()

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    titleTopMargin: 12
    title: dialog.headline.length > 0 ? dialog.headline : "Couldn't remove file"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: Math.max(
        deleteErrorFooter.requiredDialogWidth,
        deleteErrorContent.implicitWidth,
        titlePreferredWidth
    )
    height: Math.min(
        availableDialogHeight,
        Math.max(styleTokens.deleteErrorMinHeight, deleteErrorLayout.implicitHeight)
    )

    onCloseRequested: {
        if (!dialog.retryActive) {
            close()
        }
    }

    PopupBodyColumn {
        id: deleteErrorLayout
        popupStyle: styleTokens
        topMargin: styleTokens.dialogBodyTopMargin
        bottomMargin: styleTokens.dialogBottomMargin
        sideMargin: 0
        spacing: 0

        TextMetrics {
            id: deleteErrorTitleMetrics
            font.pixelSize: styleTokens.dialogTitleFontSize
            text: dialog.title
        }

        PopupSystemErrorLayout {
            id: deleteErrorContent
            Layout.alignment: Qt.AlignHCenter
            popupStyle: styleTokens
            contentWidth: dialog.contentTextWidth
            iconSize: 30
            blockSpacing: 18
            visible: dialog.reasonText.length > 0 || dialog.detailsText.length > 0 || dialog.systemText.length > 0

            Text {
                visible: dialog.reasonText.length > 0
                text: dialog.reasonText
                color: styleTokens.textColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }

            Text {
                visible: dialog.detailsText.length > 0
                text: dialog.detailsText
                color: styleTokens.subtleTextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }

            Text {
                visible: dialog.systemText.length > 0
                text: "System: " + dialog.systemText
                color: styleTokens.subtleTextColor
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

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: dialog.retryActive
            spacing: 10

            BusyIndicator {
                running: dialog.retryActive
                visible: dialog.retryActive
                implicitWidth: 20
                implicitHeight: 20
            }

            Text {
                text: dialog.retryStatusText.length > 0 ? dialog.retryStatusText : "Retrying delete..."
                color: styleTokens.subtleTextColor
                font.pixelSize: 12
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: dialog.retryActive ? 12 : 0
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
                text: dialog.retryActive ? "Retrying..." : "Retry"
                enabled: !dialog.retryActive
                onClicked: dialog.retryRequested()
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
                enabled: dialog.primaryPath.length > 0 && !dialog.retryActive
                onClicked: dialog.openFolderRequested()
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
                enabled: !dialog.retryActive
                onClicked: dialog.close()
            }
        }

        TextMetrics {
            id: deleteReasonMetrics
            font.pixelSize: 12
            text: dialog.reasonText
        }

        TextMetrics {
            id: deleteDetailsMetrics
            font.pixelSize: 12
            text: dialog.detailsText
        }

        TextMetrics {
            id: deleteSystemMetrics
            font.pixelSize: 12
            text: dialog.systemText.length > 0 ? ("System: " + dialog.systemText) : ""
        }
    }
}
