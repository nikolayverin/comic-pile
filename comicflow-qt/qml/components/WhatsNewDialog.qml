import QtQuick
import QtQuick.Controls

PopupDialogWindow {
    id: dialog

    signal updateDetailsRequested()

    readonly property var updatesRef: (typeof releaseCheckService !== "undefined") ? releaseCheckService : null
    readonly property bool hasKnownUpdateAvailable: Boolean(updatesRef)
        && Boolean(updatesRef.hasReleaseInfo)
        && Boolean(updatesRef.latestVersionIsNewer)
    readonly property var bundledEntriesRaw: (typeof appBundledWhatsNewEntries !== "undefined")
        ? appBundledWhatsNewEntries
        : []
    readonly property var fallbackEntry: ({
        entryKey: "current",
        version: String(appVersion || "").trim(),
        label: String(appVersion || "").trim().length > 0
            ? "Patch v" + String(appVersion || "").trim()
            : "Patch notes",
        notes: String(appBundledWhatsNewText || "").trim().length > 0
            ? String(appBundledWhatsNewText || "").trim()
            : "No bundled release notes are available for this build.",
        current: true
    })
    readonly property var noteEntries: {
        if (bundledEntriesRaw && bundledEntriesRaw.length > 0) {
            return bundledEntriesRaw
        }
        return [fallbackEntry]
    }
    readonly property int clampedSelectedIndex: Math.max(0, Math.min(selectedIndex, noteEntries.length - 1))
    readonly property var selectedEntry: noteEntries.length > 0 ? noteEntries[clampedSelectedIndex] : fallbackEntry
    readonly property string selectedEntryLabel: String((selectedEntry || {}).label || "").trim()
    readonly property string selectedEntryNotes: {
        const text = String((selectedEntry || {}).notes || "").trim()
        return text.length > 0 ? text : "No bundled release notes are available for this build."
    }
    readonly property int minimumDialogHeight: 300
    readonly property int maximumDialogHeight: 800
    readonly property int availableDialogHeight: hostHeight > 0
        ? Math.min(maximumDialogHeight, hostHeight - 80)
        : maximumDialogHeight
    readonly property int sidebarWidth: 176
    readonly property int footerZoneHeight: styleTokens.footerButtonHeight
        + styleTokens.formFooterTopGap
        + styleTokens.footerBottomMargin
    readonly property int notesViewportMaxHeight: 700
    readonly property int notesViewportPreferredHeight: Math.min(
        dialog.notesViewportMaxHeight,
        Math.max(180, notesContent.implicitHeight)
    )
    readonly property int contentImplicitHeight: styleTokens.dialogBodyTopMargin
        + bodyLayout.implicitHeight
        + dialog.footerZoneHeight
        + styleTokens.dialogBottomMargin

    property int selectedIndex: 0

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "whats-new-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: "What's new"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 760
    height: Math.min(
        availableDialogHeight,
        Math.max(minimumDialogHeight, contentImplicitHeight)
    )

    onCloseRequested: close()
    onNoteEntriesChanged: {
        if (!noteEntries || noteEntries.length < 1) {
            selectedIndex = 0
            return
        }
        selectedIndex = Math.max(0, Math.min(selectedIndex, noteEntries.length - 1))
    }
    onOpened: selectedIndex = 0

    Item {
        anchors.fill: parent

        Item {
            id: contentArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: footerArea.top
            anchors.leftMargin: styleTokens.dialogSideMargin
            anchors.rightMargin: styleTokens.dialogSideMargin
            anchors.topMargin: styleTokens.dialogBodyTopMargin
            anchors.bottomMargin: styleTokens.formFooterTopGap

            Row {
                id: bodyLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 18
                implicitHeight: Math.max(sidebarBlock.implicitHeight, notesBlock.implicitHeight)

                Item {
                    id: sidebarBlock
                    width: dialog.sidebarWidth
                    implicitHeight: Math.max(180, versionList.contentHeight)

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "#1d1d1d"
                        border.width: 1
                        border.color: "#2c2c2c"
                    }

                    ListView {
                        id: versionList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        spacing: 4
                        model: dialog.noteEntries
                        currentIndex: dialog.clampedSelectedIndex
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            required property int index
                            required property var modelData
                            width: versionList.width
                            height: 42

                            readonly property bool current: Boolean((modelData || {}).current)
                            readonly property bool selected: dialog.clampedSelectedIndex === index
                            readonly property string labelText: String((modelData || {}).label || "").trim()

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: parent.selected ? "#2d2d2d" : "transparent"
                                border.width: parent.selected ? 1 : 0
                                border.color: parent.selected ? "#4a4a4a" : "transparent"
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: labelText
                                color: selected ? "#ffffff" : "#cfcfcf"
                                font.family: Qt.application.font.family
                                font.pixelSize: styleTokens.dialogBodyFontSize
                                font.weight: current ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialog.selectedIndex = index
                            }
                        }

                        VerticalScrollThumb {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: 8
                            visible: versionList.contentHeight > versionList.height
                            flickable: versionList
                            thumbWidth: 8
                            thumbInset: 0
                            thumbColor: "#111111"
                        }
                    }
                }

                Item {
                    id: notesBlock
                    width: bodyLayout.width - sidebarBlock.width - bodyLayout.spacing
                    implicitHeight: Math.max(notesHeader.implicitHeight + styleTokens.dialogContentSpacing + dialog.notesViewportPreferredHeight, 180)

                    Item {
                        id: notesHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        implicitHeight: Math.max(whatsNewHeader.implicitHeight, selectedPatchLabel.implicitHeight)

                        Text {
                            id: whatsNewHeader
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.right: selectedPatchLabel.left
                            anchors.rightMargin: 16
                            text: "What's new"
                            color: styleTokens.textColor
                            font.family: Qt.application.font.family
                            font.pixelSize: styleTokens.dialogBodyEmphasisFontSize
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            id: selectedPatchLabel
                            anchors.top: parent.top
                            anchors.right: parent.right
                            visible: dialog.selectedEntryLabel.length > 0
                            text: dialog.selectedEntryLabel
                            color: styleTokens.textColor
                            font.family: Qt.application.font.family
                            font.pixelSize: styleTokens.dialogBodyEmphasisFontSize
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: notesHeader.bottom
                        anchors.topMargin: styleTokens.dialogContentSpacing
                        anchors.bottom: parent.bottom

                        Flickable {
                            id: notesFlick
                            anchors.fill: parent
                            anchors.rightMargin: 10
                            clip: true
                            contentWidth: width
                            contentHeight: notesContent.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height

                            Text {
                                id: notesContent
                                width: notesFlick.width
                                text: dialog.selectedEntryNotes
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
                            visible: notesFlick.contentHeight > notesFlick.height
                            flickable: notesFlick
                            thumbWidth: 8
                            thumbInset: 0
                            thumbColor: "#111111"
                        }
                    }
                }
            }
        }

        Item {
            id: footerArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: styleTokens.dialogSideMargin
            anchors.rightMargin: styleTokens.dialogSideMargin
            anchors.bottomMargin: styleTokens.dialogBottomMargin
            height: dialog.footerZoneHeight

            PopupFooterRow {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                horizontalPadding: styleTokens.footerSideMargin
                spacing: styleTokens.footerButtonSpacing

                PopupActionButton {
                    visible: dialog.hasKnownUpdateAvailable
                    height: styleTokens.footerButtonHeight
                    minimumWidth: 168
                    horizontalPadding: styleTokens.footerButtonHorizontalPadding
                    cornerRadius: styleTokens.footerButtonRadius
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: styleTokens.textColor
                    textPixelSize: styleTokens.footerButtonTextSize
                    text: "View available update"
                    onClicked: dialog.updateDetailsRequested()
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
}
