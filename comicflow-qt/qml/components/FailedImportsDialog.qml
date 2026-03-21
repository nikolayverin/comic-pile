import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PopupDialogWindow {
    id: dialog

    property var itemsModel: null
    property bool actionsEnabled: true
    readonly property int itemCount: itemsModel && typeof itemsModel.count === "number"
        ? itemsModel.count
        : 0
    property int reviewTotalCount: 0
    readonly property var currentItem: itemCount > 0 && itemsModel && typeof itemsModel.get === "function"
        ? itemsModel.get(0)
        : null
    readonly property string currentPath: currentItem ? String(currentItem.path || "") : ""
    readonly property string currentFileName: currentItem ? String(currentItem.fileName || "") : ""
    readonly property string currentError: currentItem ? String(currentItem.error || "") : ""
    readonly property int currentPosition: itemCount > 0 && reviewTotalCount > 0
        ? Math.min(reviewTotalCount, Math.max(1, reviewTotalCount - itemCount + 1))
        : 0
    readonly property string currentCounterText: currentPosition > 0 && reviewTotalCount > 0
        ? (String(currentPosition) + " / " + String(reviewTotalCount))
        : ""
    readonly property int availableDialogWidth: hostWidth > 0
        ? Math.max(0, hostWidth - 80)
        : styleTokens.failedImportsMaxWidth
    readonly property int contentLineWidth: styleTokens.failedImportsTextReserveWidth
        + (currentCounterText.length > 0
            ? styleTokens.dialogInlineMetricGap + styleTokens.failedImportsCounterReserveWidth
            : 0)
    readonly property int bodyPreferredWidth: Math.max(
        styleTokens.failedImportsHintReserveWidth,
        contentLineWidth
    )
    readonly property int titlePreferredWidth: failedImportsTitleMetrics.advanceWidth
        + styleTokens.closeButtonSize
        + styleTokens.closeRightMargin
        + styleTokens.dialogSideMargin
        + 24
    readonly property int preferredDialogWidth: Math.max(
        failedImportsFooter.requiredDialogWidth,
        bodyPreferredWidth + (styleTokens.dialogSideMargin * 2),
        titlePreferredWidth
    )

    signal retryRequested(int index)
    signal skipRequested(int index)
    signal skipAllRequested()
    signal pathOpenRequested(string path)

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: "Import Errors"
    showCloseButton: false
    closePolicy: Popup.NoAutoClose
    width: Math.min(availableDialogWidth, Math.min(styleTokens.failedImportsMaxWidth, preferredDialogWidth))
    height: Math.max(styleTokens.confirmDialogMinHeight, failedImportsBody.implicitHeight)

    onCloseRequested: close()
    onVisibleChanged: {
        if (visible) {
            reviewTotalCount = itemCount
        }
    }

    PopupBodyColumn {
        id: failedImportsBody
        popupStyle: styleTokens
        spacing: styleTokens.dialogContentSpacing

        TextMetrics {
            id: failedImportsTitleMetrics
            font.pixelSize: styleTokens.dialogTitleFontSize
            text: dialog.title
        }

        Label {
            text: "These archives were not imported. Review reason and retry after fixing."
            color: styleTokens.hintTextColor
            font.pixelSize: styleTokens.dialogHintFontSize
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        PopupInfoBlock {
            Layout.fillWidth: true
            popupStyle: styleTokens

            PopupErrorText {
                visible: currentError.length > 0
                text: currentError
                popupStyle: styleTokens
                Layout.fillWidth: true
            }

            RowLayout {
                visible: currentFileName.length > 0 || currentCounterText.length > 0
                Layout.fillWidth: true
                spacing: styleTokens.dialogInlineMetricGap

                Text {
                    text: currentFileName
                    color: styleTokens.textColor
                    font.pixelSize: styleTokens.dialogBodyFontSize
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                }

                Text {
                    visible: currentCounterText.length > 0
                    text: currentCounterText
                    color: styleTokens.textColor
                    font.pixelSize: styleTokens.dialogBodyFontSize
                    horizontalAlignment: Text.AlignRight
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Label {
                visible: currentPath.length > 0
                text: currentPath
                color: styleTokens.subtleTextColor
                font.pixelSize: styleTokens.dialogHintFontSize
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                Layout.fillWidth: true
                font.underline: pathMouseArea.containsMouse

                MouseArea {
                    id: pathMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: dialog.pathOpenRequested(dialog.currentPath)
                }
            }
        }

        PopupFooterRow {
            id: failedImportsFooter
            Layout.fillWidth: true
            horizontalPadding: styleTokens.footerSideMargin

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
                enabled: dialog.actionsEnabled && itemCount > 0
                onClicked: dialog.retryRequested(0)
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
                text: "Skip"
                enabled: dialog.actionsEnabled && itemCount > 0
                onClicked: dialog.skipRequested(0)
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
                text: "Skip all"
                enabled: dialog.actionsEnabled && itemCount > 0
                onClicked: dialog.skipAllRequested()
            }
        }
    }
}
