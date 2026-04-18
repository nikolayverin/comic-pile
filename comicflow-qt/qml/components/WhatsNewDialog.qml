import QtQuick
import QtQuick.Controls

PopupDialogWindow {
    id: dialog

    signal updateDetailsRequested()

    ThemeColors { id: themeColors }
    PopupStyle { id: styleTokens }

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
    readonly property var noteEntries: bundledEntriesRaw && bundledEntriesRaw.length > 0
        ? bundledEntriesRaw
        : [fallbackEntry]
    readonly property int clampedSelectedIndex: Math.max(0, Math.min(selectedIndex, noteEntries.length - 1))
    readonly property var selectedEntry: noteEntries.length > 0 ? noteEntries[clampedSelectedIndex] : fallbackEntry
    readonly property string selectedEntryLabel: {
        const label = String((selectedEntry || {}).label || "").trim()
        return label.length > 0 ? label : "Patch notes"
    }
    readonly property string selectedEntryNotes: {
        const text = String((selectedEntry || {}).notes || "").trim()
        return text.length > 0 ? text : "No bundled release notes are available for this build."
    }

    readonly property int sidebarWidth: 252
    readonly property int menuTop: 52
    readonly property int menuLeft: 12
    readonly property int menuAreaWidth: sidebarWidth - menuLeft - 16
    readonly property int menuItemHeight: 42
    readonly property int menuItemRadius: 8
    readonly property int menuTextSize: 13
    readonly property int menuTextGlobalX: 24
    readonly property int titleToMenuGap: 25
    readonly property int contentInsetFromSidebar: 30
    readonly property int sectionTitleTop: 20
    readonly property int contentTopSafeArea: styleTokens.closeTopMargin
        + styleTokens.closeButtonSize
        + 12
    readonly property int sectionTitleSize: 28
    readonly property int bodyTextSize: 13
    readonly property real bodyLineHeight: 1.28
    readonly property int baseHostWidth: 1440
    readonly property int baseHostHeight: 980
    readonly property int baseDialogWidth: 1024
    readonly property int baseDialogHeight: 820
    readonly property int minimumDialogWidth: 620
    readonly property int minimumDialogHeight: 520
    readonly property int horizontalMargin: hostWidth >= 1800 ? 60 : 36
    readonly property int verticalMargin: hostHeight >= 1100 ? 56 : 36

    property int selectedIndex: 0
    property bool contentThumbDragActive: false

    popupStyle: styleTokens
    debugName: "whats-new-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: ""
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: {
        if (hostWidth <= 0) return baseDialogWidth
        const availableWidth = Math.max(420, Math.floor(hostWidth - horizontalMargin * 2))
        return Math.min(baseDialogWidth, availableWidth)
    }
    height: {
        if (hostHeight <= 0) return baseDialogHeight
        const availableHeight = Math.max(260, Math.floor(hostHeight - verticalMargin * 2))
        const scaledHeight = Math.round(baseDialogHeight * (hostHeight / baseHostHeight))
        return Math.max(minimumDialogHeight, Math.min(scaledHeight, availableHeight))
    }

    onOpened: selectedIndex = 0
    onCloseRequested: close()
    onNoteEntriesChanged: {
        if (!noteEntries || noteEntries.length < 1) {
            selectedIndex = 0
            return
        }
        selectedIndex = Math.max(0, Math.min(selectedIndex, noteEntries.length - 1))
    }

    Item {
        anchors.fill: parent

        Rectangle {
            x: 0
            y: 1
            width: dialog.sidebarWidth
            height: parent.height - 2
            color: "#1d1d1d"
            border.width: 1
            border.color: "#2b2b2b"
        }

        Text {
            id: menuTitle
            x: dialog.menuTextGlobalX
            y: dialog.menuTop - dialog.titleToMenuGap - implicitHeight
            text: "What's new"
            color: styleTokens.textColor
            font.family: Qt.application.font.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        ListView {
            id: sidebarFlick
            x: dialog.menuLeft
            y: dialog.menuTop
            width: dialog.menuAreaWidth
            height: parent.height - dialog.menuTop - 16
            model: dialog.noteEntries
            spacing: 8
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: noteRow
                required property int index
                required property var modelData

                width: sidebarFlick.width
                height: dialog.menuItemHeight

                readonly property bool selected: dialog.clampedSelectedIndex === index
                readonly property string labelText: {
                    const label = String((modelData || {}).label || "").trim()
                    return label.length > 0 ? label : "Patch notes"
                }

                InsetEdgeSurface {
                    anchors.fill: parent
                    cornerRadius: dialog.menuItemRadius
                    visible: noteMouseArea.containsMouse || noteMouseArea.pressed || noteRow.selected
                    fillColor: noteMouseArea.pressed ? themeColors.settingsSidebarPressedColor
                        : noteRow.selected ? themeColors.settingsSidebarSelectedColor
                        : themeColors.settingsSidebarHoverColor
                    edgeColor: noteRow.selected ? themeColors.settingsSidebarSelectedEdgeColor
                        : themeColors.settingsSidebarHoverEdgeColor
                    fillOffsetY: noteMouseArea.pressed ? -1 : 0
                }

                Text {
                    x: dialog.menuTextGlobalX - dialog.menuLeft
                    y: Math.round((parent.height - implicitHeight) / 2) + (noteMouseArea.pressed ? 1 : 0)
                    width: parent.width - x - 16
                    text: noteRow.labelText
                    color: noteRow.selected || noteMouseArea.containsMouse
                        ? styleTokens.textColor
                        : themeColors.settingsSidebarIdleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.menuTextSize
                    font.weight: noteRow.selected ? Font.DemiBold : Font.Normal
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: noteMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialog.selectedIndex = index
                }
            }
        }

        VerticalScrollThumb {
            anchors.top: sidebarFlick.top
            anchors.bottom: sidebarFlick.bottom
            anchors.right: sidebarFlick.right
            width: 8
            visible: sidebarFlick.contentHeight > sidebarFlick.height
            flickable: sidebarFlick
            thumbWidth: 8
            thumbInset: 0
            thumbColor: "#111111"
        }

        Item {
            id: contentPane
            x: dialog.sidebarWidth + dialog.contentInsetFromSidebar
            width: parent.width - x - styleTokens.dialogSideMargin
            height: parent.height

            Flickable {
                id: contentFlick
                x: 0
                y: Math.max(dialog.sectionTitleTop, dialog.contentTopSafeArea)
                width: parent.width
                height: parent.height - y - 16
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                interactive: !dialog.contentThumbDragActive && contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentColumn
                    width: Math.max(320, contentFlick.width - 18)
                    spacing: 18

                    Text {
                        width: parent.width
                        text: dialog.selectedEntryLabel
                        color: styleTokens.textColor
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.sectionTitleSize
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: themeColors.lineSidebarRight
                        opacity: 0.7
                    }

                    Text {
                        width: parent.width
                        text: dialog.selectedEntryNotes
                        color: styleTokens.textColor
                        textFormat: Text.MarkdownText
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.bodyTextSize
                        wrapMode: Text.WordWrap
                        lineHeight: dialog.bodyLineHeight
                        lineHeightMode: Text.ProportionalHeight
                    }

                    Item {
                        visible: dialog.hasKnownUpdateAvailable
                        width: parent.width
                        height: updateLink.implicitHeight

                        Text {
                            id: updateLink
                            text: "View available update"
                            color: "#78b7ff"
                            font.family: Qt.application.font.family
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.NoWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dialog.updateDetailsRequested()
                        }
                    }

                    Item {
                        width: parent.width
                        height: Math.max(0, contentFlick.height - 120)
                    }
                }
            }

            VerticalScrollThumb {
                anchors.top: contentFlick.top
                anchors.bottom: contentFlick.bottom
                anchors.right: parent.right
                width: 8
                visible: contentFlick.contentHeight > contentFlick.height
                flickable: contentFlick
                thumbWidth: 8
                thumbInset: 0
                thumbColor: "#111111"
                onDragStarted: dialog.contentThumbDragActive = true
                onDragEnded: dialog.contentThumbDragActive = false
            }
        }
    }
}
