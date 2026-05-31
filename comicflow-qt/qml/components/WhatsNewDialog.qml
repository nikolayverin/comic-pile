import QtQuick
import QtQuick.Controls
import "AppText.js" as AppText

PopupDialogWindow {
    id: dialog

    signal updateDetailsRequested()

    ThemeColors { id: themeColors }
    PopupStyle { id: styleTokens }

    readonly property var updatesRef: (typeof releaseCheckService !== "undefined") ? releaseCheckService : null
    property string textLanguage: AppText.fallbackLanguageCode
    property bool updateActionsEnabled: true
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
            ? AppText.tf("updateAvailablePatchLabel", { version: String(appVersion || "").trim() }, dialog.textLanguage)
            : AppText.t("whatsNewPatchNotes", dialog.textLanguage),
        notes: String(appBundledWhatsNewText || "").trim().length > 0
            ? String(appBundledWhatsNewText || "").trim()
            : AppText.t("whatsNewNoBundledNotes", dialog.textLanguage),
        current: true
    })
    readonly property string normalizedTextLanguage: AppText.normalizedLanguageCode(textLanguage)
    readonly property var noteEntries: localizedNoteEntries()
    readonly property int clampedSelectedIndex: Math.max(0, Math.min(selectedIndex, noteEntries.length - 1))
    readonly property var selectedEntry: noteEntries.length > 0 ? noteEntries[clampedSelectedIndex] : fallbackEntry
    readonly property string selectedEntryLabel: entryDisplayLabel(selectedEntry)
    readonly property string selectedEntryNotes: {
        const text = String((selectedEntry || {}).notes || "").trim()
        return text.length > 0 ? text : AppText.t("whatsNewNoBundledNotes", dialog.textLanguage)
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

    function localizedText(textKey) {
        return AppText.t(textKey, textLanguage)
    }

    function entryDisplayLabel(entry) {
        const version = String((entry || {}).version || "").trim()
        if (version.length > 0) {
            return AppText.tf("updateAvailablePatchLabel", { version: version }, dialog.textLanguage)
        }
        const label = String((entry || {}).label || "").trim()
        return label.length > 0 ? label : AppText.t("whatsNewPatchNotes", dialog.textLanguage)
    }

    function localizedNoteEntries() {
        const rawEntries = bundledEntriesRaw && bundledEntriesRaw.length > 0
            ? bundledEntriesRaw
            : [fallbackEntry]
        const preferredLanguage = normalizedTextLanguage
        const fallbackLanguage = AppText.fallbackLanguageCode
        const keys = []
        const groupedEntries = ({})

        for (let i = 0; i < rawEntries.length; i += 1) {
            const entry = rawEntries[i] || {}
            const key = String(entry.entryKey || entry.version || entry.fileName || i)
            const language = AppText.normalizedLanguageCode(String(entry.language || fallbackLanguage))
            if (!groupedEntries[key]) {
                groupedEntries[key] = ({ first: entry, byLanguage: ({}) })
                keys.push(key)
            }
            if (!groupedEntries[key].byLanguage[language]) {
                groupedEntries[key].byLanguage[language] = entry
            }
        }

        const result = []
        for (let keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
            const group = groupedEntries[keys[keyIndex]] || {}
            const byLanguage = group.byLanguage || {}
            result.push(byLanguage[preferredLanguage] || byLanguage[fallbackLanguage] || group.first)
        }
        return result.length > 0 ? result : [fallbackEntry]
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
            text: dialog.localizedText("topMenuWhatsNew")
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
                    return dialog.entryDisplayLabel(modelData)
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
                        visible: dialog.hasKnownUpdateAvailable && dialog.updateActionsEnabled
                        width: parent.width
                        height: updateLink.implicitHeight

                        Text {
                            id: updateLink
                            text: dialog.localizedText("whatsNewViewAvailableUpdate")
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
