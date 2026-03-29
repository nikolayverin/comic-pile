import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "AppText.js" as AppText

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
    readonly property int textColumnMinWidth: 120
    readonly property int textColumnMaxWidth: 420
    readonly property int footerTopGap: 16
    readonly property int availableDialogWidth: hostWidth > 0
        ? Math.max(0, hostWidth - 80)
        : 592
    readonly property int currentFileLineWidth: currentFileNameMetrics.advanceWidth
        + (currentCounterText.length > 0
            ? styleTokens.dialogInlineMetricGap + currentCounterMetrics.advanceWidth
            : 0)
    readonly property int contentTextWidth: Math.max(
        textColumnMinWidth,
        Math.min(
            textColumnMaxWidth,
            Math.max(
                failedImportsIntroMetrics.advanceWidth,
                failedImportsErrorMetrics.advanceWidth,
                currentFileLineWidth,
                currentPathMetrics.advanceWidth
            )
        )
    )
    readonly property int titlePreferredWidth: failedImportsTitleMetrics.advanceWidth
        + 48
    readonly property int preferredDialogWidth: Math.max(
        failedImportsFooter.requiredDialogWidth,
        failedImportsContent.implicitWidth,
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
    titleTopMargin: 12
    title: AppText.popupImportErrorsTitle
    showCloseButton: false
    closePolicy: Popup.NoAutoClose
    width: Math.min(availableDialogWidth, preferredDialogWidth)
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
        topMargin: styleTokens.dialogBodyTopMargin
        bottomMargin: styleTokens.dialogBottomMargin
        sideMargin: 0
        spacing: 0

        TextMetrics {
            id: failedImportsTitleMetrics
            font.pixelSize: styleTokens.dialogTitleFontSize
            text: dialog.title
        }

        PopupSystemErrorLayout {
            id: failedImportsContent
            Layout.alignment: Qt.AlignHCenter
            popupStyle: styleTokens
            contentWidth: dialog.contentTextWidth
            iconSize: 30
            blockSpacing: 18

            Text {
                text: AppText.popupImportErrorsIntro
                color: styleTokens.subtleTextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }

            Text {
                visible: currentError.length > 0
                text: currentError
                color: styleTokens.errorTextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
            }

            Row {
                visible: currentFileName.length > 0 || currentCounterText.length > 0
                width: parent.width
                spacing: styleTokens.dialogInlineMetricGap

                Text {
                    text: currentFileName
                    color: styleTokens.textColor
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    width: parent.width - (currentCounterText.length > 0
                        ? currentCounter.width + styleTokens.dialogInlineMetricGap
                        : 0)
                }

                Text {
                    id: currentCounter
                    visible: currentCounterText.length > 0
                    text: currentCounterText
                    color: styleTokens.textColor
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                }
            }

            Text {
                visible: currentPath.length > 0
                text: currentPath
                color: styleTokens.subtleTextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignLeft
                width: parent.width
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

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: dialog.footerTopGap
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
                text: AppText.commonRetry
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
                text: AppText.commonSkip
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
                text: AppText.commonSkipAll
                enabled: dialog.actionsEnabled && itemCount > 0
                onClicked: dialog.skipAllRequested()
            }
        }

        TextMetrics {
            id: failedImportsIntroMetrics
            font.pixelSize: 12
            text: AppText.popupImportErrorsIntro
        }

        TextMetrics {
            id: failedImportsErrorMetrics
            font.pixelSize: 12
            text: currentError
        }

        TextMetrics {
            id: currentFileNameMetrics
            font.pixelSize: 12
            text: currentFileName
        }

        TextMetrics {
            id: currentCounterMetrics
            font.pixelSize: 12
            text: currentCounterText
        }

        TextMetrics {
            id: currentPathMetrics
            font.pixelSize: 12
            text: currentPath
        }
    }
}
