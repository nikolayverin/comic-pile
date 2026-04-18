import QtQuick
import QtQuick.Controls

PopupDialogWindow {
    id: dialog

    readonly property string whatsNewText: String(appBundledWhatsNewText || "").trim()
    readonly property int minimumDialogHeight: 240
    readonly property int maximumDialogHeight: 800
    readonly property int availableDialogHeight: hostHeight > 0
        ? Math.min(maximumDialogHeight, hostHeight - 80)
        : maximumDialogHeight
    readonly property int notesViewportMaxHeight: 700
    readonly property int notesViewportPreferredHeight: Math.min(
        dialog.notesViewportMaxHeight,
        Math.max(120, whatsNewContent.implicitHeight)
    )
    readonly property int contentImplicitHeight: styleTokens.dialogBodyTopMargin
        + whatsNewHeader.implicitHeight
        + styleTokens.dialogContentSpacing
        + dialog.notesViewportPreferredHeight
        + styleTokens.dialogBottomMargin

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "whats-new-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: "What's new"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 560
    height: Math.min(
        availableDialogHeight,
        Math.max(minimumDialogHeight, contentImplicitHeight)
    )

    onCloseRequested: close()

    Item {
        anchors.fill: parent

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: styleTokens.dialogSideMargin
            anchors.rightMargin: styleTokens.dialogSideMargin
            anchors.topMargin: styleTokens.dialogBodyTopMargin
            anchors.bottomMargin: styleTokens.dialogBottomMargin

            Text {
                id: whatsNewHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: "What's new"
                color: styleTokens.textColor
                font.family: Qt.application.font.family
                font.pixelSize: styleTokens.dialogBodyEmphasisFontSize
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: whatsNewHeader.bottom
                anchors.topMargin: styleTokens.dialogContentSpacing
                anchors.bottom: parent.bottom

                Flickable {
                    id: whatsNewFlick
                    anchors.fill: parent
                    anchors.rightMargin: 10
                    clip: true
                    contentWidth: width
                    contentHeight: whatsNewContent.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Text {
                        id: whatsNewContent
                        width: whatsNewFlick.width
                        text: dialog.whatsNewText.length > 0
                            ? dialog.whatsNewText
                            : "No bundled release notes are available for this build."
                        color: styleTokens.textColor
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
                    visible: whatsNewFlick.contentHeight > whatsNewFlick.height
                    flickable: whatsNewFlick
                    thumbWidth: 8
                    thumbInset: 0
                    thumbColor: "#111111"
                }
            }
        }
    }
}
