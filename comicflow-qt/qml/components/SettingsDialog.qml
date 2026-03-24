import QtQuick
import QtQuick.Controls
import "SettingsCatalog.js" as SettingsCatalog

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }

    property var settingsController: null
    property string sevenZipConfiguredPath: ""
    property string sevenZipDisplayPath: ""
    property bool sevenZipAvailable: false
    property string sevenZipStatusMessage: ""
    property string libraryDataRootPath: ""
    property string libraryDataPendingMovePath: ""
    property string libraryFolderPath: ""
    property string libraryRuntimeFolderPath: ""
    property string sevenZipVerifyState: "idle"
    property string sevenZipVerifyInlineMessage: ""
    property bool sevenZipVerifyPendingSuccess: false
    property string sevenZipVerifyPendingMessage: ""
    property string supportedArchiveFormatsSummary: "CBZ / ZIP / CBR / RAR / 7Z / CB7 / CBT / TAR"
    property string supportedImageFormatsSummary: "JPG / JPEG / PNG / BMP / WEBP"
    property string supportedDocumentFormatsSummary: "PDF / DJVU"
    property string selectedSection: "general"
    property string requestedSection: ""
    readonly property color sidebarHoverColor: themeColors.settingsSidebarHoverColor
    readonly property color sidebarSelectedColor: themeColors.settingsSidebarSelectedColor
    readonly property color sidebarPressedColor: themeColors.settingsSidebarPressedColor
    readonly property color sidebarHoverEdgeColor: themeColors.settingsSidebarHoverEdgeColor
    readonly property color sidebarSelectedEdgeColor: themeColors.settingsSidebarSelectedEdgeColor
    readonly property color actionHoverEdgeColor: themeColors.popupActionHoverEdgeColor
    readonly property color actionPressedColor: themeColors.popupActionPressedColor
    readonly property color actionPressedEdgeColor: themeColors.popupActionPressedEdgeColor
    readonly property int sidebarWidth: 190
    readonly property int menuTop: 52
    readonly property int menuLeft: 12
    readonly property int menuItemWidth: 158
    readonly property int menuItemHeight: 24
    readonly property int menuItemRadius: 6
    readonly property int menuItemSpacing: 10
    readonly property int menuTextSize: 13
    readonly property int menuIconSize: 14
    readonly property int menuIconLeftInset: 10
    readonly property int menuTextGlobalX: 54
    readonly property int titleToMenuGap: 25
    readonly property int contentInsetFromSidebar: 18
    readonly property int sectionTitleTop: 16
    readonly property int sectionTitleSize: 14
    readonly property int optionListTop: 50
    readonly property int optionTextSize: 11
    readonly property int optionRowPitch: menuItemHeight + menuItemSpacing
    readonly property int optionControlRightMargin: 30
    readonly property int importButtonGap: 14
    readonly property int importPrimaryLabelWidth: 160
    readonly property int importSecondaryValueX: 268
    readonly property int importFormatsValueX: 268
    readonly property int importDuplicateOptionX: 403
    readonly property int importFieldHeight: 24
    readonly property int importFieldRadius: 12
    readonly property int appearancePreviewCardGap: 10
    readonly property int appearancePreviewCardHeight: 82
    readonly property int appearanceContextGap: 12
    readonly property var appearanceBackgroundSourceOptions: SettingsCatalog.appearanceBackgroundSourceOptions
    readonly property var appearanceSolidColorOptions: SettingsCatalog.appearanceSolidColorOptions
    readonly property var appearanceTextureOptions: SettingsCatalog.appearanceTextureOptions
    readonly property var settingsSections: SettingsCatalog.settingsSections
    readonly property var sectionOptionRows: SettingsCatalog.sectionOptionRows

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    title: ""
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 820
    height: 360

    onOpened: {
        const requested = String(requestedSection || "").trim()
        selectedSection = requested.length > 0 ? requested : "general"
    }
    onCloseRequested: close()

    signal chooseSevenZipRequested()
    signal verifySevenZipRequested()
    signal changeLibraryDataLocationRequested()
    signal chooseLibraryBackgroundImageRequested()
    signal libraryBackgroundImageModeRequested(string mode)
    signal openLibraryDataFolderRequested()
    signal openLibraryFolderRequested()
    signal openLibraryRuntimeFolderRequested()
    signal reloadLibraryRequested()

    function conciseSevenZipVerifyMessage() {
        const rawText = String(dialog.sevenZipStatusMessage || "").trim()
        if (rawText.length < 1) {
            return "7-Zip is not available."
        }
        if (rawText.toLowerCase().indexOf("missing") >= 0) {
            return "7-Zip is not available."
        }
        return rawText
    }

    function selectedSectionLabel() {
        const key = String(selectedSection || "")
        const sections = Array.isArray(settingsSections) ? settingsSections : []
        for (let i = 0; i < sections.length; i += 1) {
            const entry = sections[i] || {}
            if (String(entry.key || "") === key) {
                return String(entry.label || "")
            }
        }
        return ""
    }

    function selectedOptionRows() {
        const groups = sectionOptionRows || ({})
        const key = String(selectedSection || "")
        const rows = groups[key]
        return Array.isArray(rows) ? rows : []
    }

    function settingValue(valueKey, fallbackValue) {
        if (settingsController && typeof settingsController.settingValue === "function") {
            return settingsController.settingValue(valueKey, fallbackValue)
        }
        const key = String(valueKey || "")
        if (key.length < 1) return String(fallbackValue || "")
        return String(fallbackValue || "")
    }

    function setSettingValue(valueKey, nextValue) {
        if (settingsController && typeof settingsController.setSettingValue === "function") {
            settingsController.setSettingValue(valueKey, nextValue)
        }
    }

    function localFileSource(pathValue) {
        const input = String(pathValue || "").trim()
        if (input.length < 1) return ""
        const normalized = input.replace(/\\/g, "/")
        if (/^[A-Za-z]:\//.test(normalized)) {
            return "file:///" + normalized
        }
        if (normalized.startsWith("/")) {
            return "file://" + normalized
        }
        return normalized
    }

    function appearanceTextureSource(textureKey) {
        const key = String(textureKey || "").trim()
        const options = Array.isArray(appearanceTextureOptions) ? appearanceTextureOptions : []
        for (let i = 0; i < options.length; i += 1) {
            const entry = options[i] || {}
            if (String(entry.key || "") === key) {
                return String(entry.source || "")
            }
        }
        return String((options[0] || {}).source || "")
    }

    function appearanceBackgroundSourceIndex(modeKey) {
        const key = String(modeKey || "").trim()
        const options = Array.isArray(appearanceBackgroundSourceOptions) ? appearanceBackgroundSourceOptions : []
        for (let i = 0; i < options.length; i += 1) {
            const entry = options[i] || {}
            if (String(entry.key || "") === key) {
                return i
            }
        }
        return 0
    }

    function appearanceBackgroundTilePixelSize(tileSizeLabel) {
        const label = String(tileSizeLabel || "").trim()
        if (label === "512x512px") return 512
        if (label === "256x256px") return 256
        return 64
    }

    function appearanceTexturePreviewOptions(slotCount) {
        const source = Array.isArray(appearanceTextureOptions) ? appearanceTextureOptions : []
        const targetCount = Math.max(0, Number(slotCount || 0))
        const preview = []
        if (source.length < 1 || targetCount < 1) {
            return preview
        }

        const occurrences = ({})
        for (let i = 0; i < targetCount; i += 1) {
            const entry = source[i % source.length] || {}
            const actualKey = String(entry.key || "")
            const occurrence = Number(occurrences[actualKey] || 0)
            occurrences[actualKey] = occurrence + 1
            preview.push({
                actualKey: actualKey,
                source: String(entry.source || ""),
                occurrence: occurrence
            })
        }
        return preview
    }

    Timer {
        id: sevenZipVerifyFinalizeTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (dialog.sevenZipVerifyPendingSuccess) {
                dialog.sevenZipVerifyState = "success"
                dialog.sevenZipVerifyInlineMessage = ""
            } else {
                dialog.sevenZipVerifyState = "failure"
                dialog.sevenZipVerifyInlineMessage = dialog.sevenZipVerifyPendingMessage
            }
            sevenZipVerifyResetTimer.restart()
        }
    }

    Timer {
        id: sevenZipVerifyResetTimer
        interval: 1400
        repeat: false
        onTriggered: dialog.sevenZipVerifyState = "idle"
    }

    Item {
        anchors.fill: parent

        Canvas {
            x: 1
            y: 1
            width: dialog.sidebarWidth
            height: parent.height - 2
            antialiasing: true
            contextType: "2d"

            onPaint: {
                const ctx = getContext("2d")
                const w = Math.max(1, width)
                const h = Math.max(1, height)
                const r = Math.max(0, Math.min(styleTokens.popupRadius - 1, w / 2, h / 2))

                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(r, 0)
                ctx.lineTo(w, 0)
                ctx.lineTo(w, h)
                ctx.lineTo(r, h)
                ctx.quadraticCurveTo(0, h, 0, h - r)
                ctx.lineTo(0, r)
                ctx.quadraticCurveTo(0, 0, r, 0)
                ctx.closePath()
                ctx.fillStyle = themeColors.settingsSidebarPanelColor
                ctx.fill()
            }
        }

        Image {
            id: settingsTitleIcon
            x: dialog.menuLeft + dialog.menuIconLeftInset
            y: settingsTitle.y + Math.round((settingsTitle.implicitHeight - height) / 2)
            width: dialog.menuIconSize
            height: dialog.menuIconSize
            source: "qrc:/qt/qml/ComicPile/assets/icons/icon-settings.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            id: settingsTitle
            x: dialog.menuTextGlobalX
            y: dialog.menuTop - dialog.titleToMenuGap - implicitHeight
            text: "Settings"
            color: styleTokens.textColor
            font.family: Qt.application.font.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Column {
            x: dialog.menuLeft
            y: dialog.menuTop
            spacing: dialog.menuItemSpacing

            Repeater {
                model: dialog.settingsSections

                delegate: Item {
                    required property var modelData

                    width: dialog.menuItemWidth
                    height: dialog.menuItemHeight

                    readonly property bool selected: dialog.selectedSection === String(modelData.key || "")
                    readonly property bool hovered: menuMouseArea.containsMouse
                    readonly property bool pressed: menuMouseArea.pressed

                    InsetEdgeSurface {
                        anchors.fill: parent
                        cornerRadius: dialog.menuItemRadius
                        visible: parent.selected || parent.hovered || parent.pressed
                        fillColor: parent.pressed
                            ? dialog.sidebarPressedColor
                            : parent.selected
                                ? dialog.sidebarSelectedColor
                                : dialog.sidebarHoverColor
                        edgeColor: parent.selected
                            ? dialog.sidebarSelectedEdgeColor
                            : dialog.sidebarHoverEdgeColor
                        fillOffsetY: parent.pressed ? -1 : 0
                    }

                    Image {
                        x: dialog.menuIconLeftInset
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: parent.pressed ? 1 : 0
                        width: dialog.menuIconSize
                        height: dialog.menuIconSize
                        source: String(parent.modelData.iconSource || "")
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        opacity: parent.selected || parent.hovered ? 1.0 : 0.92
                    }

                    Text {
                        x: dialog.menuTextGlobalX - dialog.menuLeft
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: parent.pressed ? 1 : 0
                        text: String(parent.modelData.label || "")
                        color: parent.selected || parent.hovered
                            ? styleTokens.textColor
                            : themeColors.settingsSidebarIdleTextColor
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.menuTextSize
                    }

                    MouseArea {
                        id: menuMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialog.selectedSection = String(parent.modelData.key || "")
                    }
                }
            }
        }

        Item {
            x: dialog.sidebarWidth + dialog.contentInsetFromSidebar
            y: 0
            width: parent.width - x - styleTokens.dialogSideMargin
            height: parent.height

            Text {
                x: 0
                y: dialog.sectionTitleTop
                text: dialog.selectedSectionLabel()
                color: styleTokens.textColor
                font.family: Qt.application.font.family
                font.pixelSize: dialog.sectionTitleSize
                font.weight: Font.DemiBold
            }

            Column {
                id: optionListColumn
                x: 0
                y: dialog.optionListTop
                width: parent.width
                spacing: 0
                visible: dialog.selectedSection !== "import_archives"
                    && dialog.selectedSection !== "library_data"
                    && dialog.selectedSection !== "appearance"

                Repeater {
                    model: dialog.selectedOptionRows()

                    delegate: Item {
                        required property var modelData

                        width: optionListColumn.width
                        readonly property bool isRadioGroup: String(modelData.controlType || "") === "radio"
                        height: isRadioGroup
                            ? Math.max(dialog.optionRowPitch, markAsReadRadioGroup.height)
                            : dialog.optionRowPitch

                        Text {
                            x: 0
                            y: parent.isRadioGroup
                                ? Math.round((markAsReadRadioGroup.indicatorSize - implicitHeight) / 2)
                                : Math.round((parent.height - implicitHeight) / 2)
                            text: String(modelData.label || "")
                            color: styleTokens.textColor
                            font.family: Qt.application.font.family
                            font.pixelSize: dialog.optionTextSize
                        }

                        SettingsChoiceDropdown {
                            visible: String(modelData.controlType || "") === "dropdown"
                            anchors.right: parent.right
                            anchors.rightMargin: dialog.optionControlRightMargin
                            anchors.verticalCenter: parent.verticalCenter
                            options: modelData.options || []
                            currentText: dialog.settingValue(modelData.valueKey, "")
                            onActivated: function(index, text) {
                                dialog.setSettingValue(modelData.valueKey, text)
                            }
                        }

                        SettingsCheckbox {
                            visible: String(modelData.controlType || "") === "checkbox"
                            anchors.right: parent.right
                            anchors.rightMargin: dialog.optionControlRightMargin
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Boolean(dialog.settingValue(modelData.valueKey, false))
                            onToggled: function(checked) {
                                dialog.setSettingValue(modelData.valueKey, checked)
                            }
                        }

                        SettingsSwitch {
                            visible: String(modelData.controlType || "") === "switch"
                            anchors.right: parent.right
                            anchors.rightMargin: dialog.optionControlRightMargin
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Boolean(dialog.settingValue(modelData.valueKey, false))
                            onToggled: function(checked) {
                                dialog.setSettingValue(modelData.valueKey, checked)
                            }
                        }

                        SettingsSegmentedChoice {
                            visible: String(modelData.controlType || "") === "segmented"
                            anchors.right: parent.right
                            anchors.rightMargin: dialog.optionControlRightMargin
                            anchors.verticalCenter: parent.verticalCenter
                            options: modelData.options || []
                            currentText: String(dialog.settingValue(modelData.valueKey, ""))
                            onActivated: function(index, text) {
                                dialog.setSettingValue(modelData.valueKey, text)
                            }
                        }

                        SettingsRadioGroup {
                            id: markAsReadRadioGroup
                            visible: String(modelData.controlType || "") === "radio"
                            anchors.right: parent.right
                            anchors.rightMargin: dialog.optionControlRightMargin
                            y: 0
                            options: modelData.options || []
                            currentText: String(dialog.settingValue(modelData.valueKey, ""))
                            onActivated: function(index, text) {
                                dialog.setSettingValue(modelData.valueKey, text)
                            }
                        }
                    }
                }
            }

            Item {
                id: appearanceContent
                visible: dialog.selectedSection === "appearance"
                x: 0
                y: dialog.optionListTop
                width: parent.width
                height: parent.height - y

                readonly property string backgroundSource: String(
                    dialog.settingValue(
                        "appearance_library_background",
                        SettingsCatalog.defaultAppearanceLibraryBackground
                    )
                )
                readonly property string solidColor: String(
                    dialog.settingValue(
                        "appearance_library_background_solid_color",
                        SettingsCatalog.defaultAppearanceLibraryBackgroundSolidColor
                    )
                )
                readonly property string texturePreset: String(
                    dialog.settingValue(
                        "appearance_library_background_texture",
                        SettingsCatalog.defaultAppearanceLibraryBackgroundTexture
                    )
                )
                readonly property string customImagePath: String(
                    dialog.settingValue(
                        "appearance_library_background_custom_image_path",
                        SettingsCatalog.defaultAppearanceLibraryBackgroundCustomImagePath
                    )
                )
                readonly property string customImageMode: String(
                    dialog.settingValue(
                        "appearance_library_background_image_mode",
                        SettingsCatalog.defaultAppearanceLibraryBackgroundImageMode
                    )
                )
                readonly property string customTileSize: String(
                    dialog.settingValue(
                        "appearance_library_background_tile_size",
                        SettingsCatalog.defaultAppearanceLibraryBackgroundTileSize
                    )
                )
                readonly property int tilePixelSize: dialog.appearanceBackgroundTilePixelSize(customTileSize)
                readonly property bool hasCustomImage: customImagePath.length > 0
                readonly property bool customModeIsTile: customImageMode === "Tile"
                readonly property int backgroundSourceIndex: dialog.appearanceBackgroundSourceIndex(backgroundSource)
                readonly property real backgroundCardWidth: backgroundSourceCards.width > 0
                    ? backgroundSourceCards.width / Math.max(1, dialog.appearanceBackgroundSourceOptions.length)
                    : 139
                readonly property real contextPointerCenterX: {
                    const center = (backgroundSourceIndex * backgroundCardWidth) + (backgroundCardWidth / 2)
                    const minCenter = 13
                    const maxCenter = 543
                    return Math.max(minCenter, Math.min(maxCenter, center))
                }
                readonly property int optionsTop: backgroundSourceCards.y + backgroundSourceCards.height + 14

                Text {
                    id: libraryBackgroundLabel
                    x: 0
                    y: 0
                    text: "Cover grid background"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                Row {
                    id: backgroundSourceCards
                    x: 0
                    y: libraryBackgroundLabel.y + libraryBackgroundLabel.implicitHeight + 10
                    spacing: 0

                    Repeater {
                        model: dialog.appearanceBackgroundSourceOptions

                        delegate: Item {
                            required property var modelData

                            width: 139
                            height: 72
                            readonly property string modeKey: String(modelData.key || "")

                            HoverHandler {
                                id: sourceSlotHover
                            }

                            SettingsBackgroundChoiceButton {
                                anchors.fill: parent
                                chromeVisible: sourceSlotHover.hovered
                                    || String(parent.modelData.key || "") === appearanceContent.backgroundSource
                                title: parent.modeKey === "Custom image" ? "Custom" : String(parent.modelData.label || "")
                                selected: String(parent.modelData.key || "") === appearanceContent.backgroundSource
                                bodyColor: themeColors.settingsBackgroundChoiceBodyColor
                                cornerRadius: 6
                                onClicked: dialog.setSettingValue("appearance_library_background", parent.modeKey)
                                previewAlwaysContent: [
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: themeColors.settingsPreviewDefaultColor
                                        clip: true
                                        antialiasing: true
                                        visible: modeKey === "Default"

                                        Rectangle {
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: Math.round(parent.height * 0.52)
                                            color: themeColors.settingsPreviewDefaultTopColor
                                        }

                                        Image {
                                            anchors.fill: parent
                                            source: "qrc:/qt/qml/ComicPile/assets/ui/grid-tile.png"
                                            fillMode: Image.Tile
                                            smooth: true
                                            opacity: 0.42
                                        }
                                    },
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: appearanceContent.solidColor
                                        clip: true
                                        antialiasing: true
                                        visible: modeKey === "Solid"
                                    },
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: themeColors.settingsPreviewTextureColor
                                        clip: true
                                        antialiasing: true
                                        visible: modeKey === "Texture"

                                        Image {
                                            anchors.fill: parent
                                            source: dialog.appearanceTextureSource(appearanceContent.texturePreset)
                                            fillMode: Image.Tile
                                            sourceSize.width: appearanceContent.tilePixelSize
                                            sourceSize.height: appearanceContent.tilePixelSize
                                            smooth: true
                                            opacity: 0.86
                                        }
                                    },
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: themeColors.settingsPreviewCustomColor
                                        clip: true
                                        antialiasing: true
                                        visible: modeKey === "Custom image"

                                        Image {
                                            visible: appearanceContent.hasCustomImage
                                            anchors.fill: parent
                                            source: dialog.localFileSource(appearanceContent.customImagePath)
                                            fillMode: appearanceContent.customImageMode === "Fit"
                                                ? Image.PreserveAspectFit
                                                : appearanceContent.customImageMode === "Stretch"
                                                    ? Image.Stretch
                                                    : appearanceContent.customImageMode === "Tile"
                                                    ? Image.Tile
                                                        : Image.PreserveAspectCrop
                                            sourceSize: appearanceContent.customModeIsTile
                                                ? Qt.size(appearanceContent.tilePixelSize, appearanceContent.tilePixelSize)
                                                : Qt.size(0, 0)
                                            smooth: true
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }

                Item {
                    id: contextPanel
                    x: 0
                    y: backgroundSourceCards.y + backgroundSourceCards.height + dialog.appearanceContextGap
                    width: 556
                    height: 55
                    visible: true

                    readonly property int arrowWidth: 14
                    readonly property int arrowHeight: 7
                    readonly property int bodyHeight: 48
                    readonly property int bodyY: arrowHeight
                    readonly property int bodyRadius: 6
                    readonly property color bodyColor: themeColors.settingsContextPanelBodyColor
                    readonly property color shadowColor: themeColors.settingsContextPanelShadowColor

                    Canvas {
                        x: Math.round(appearanceContent.contextPointerCenterX - (contextPanel.arrowWidth / 2))
                        y: 1
                        width: contextPanel.arrowWidth
                        height: contextPanel.arrowHeight
                        contextType: "2d"
                        antialiasing: true

                        onXChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.beginPath()
                            ctx.moveTo(0, height)
                            ctx.lineTo(width / 2, 0)
                            ctx.lineTo(width, height)
                            ctx.closePath()
                            ctx.fillStyle = contextPanel.shadowColor
                            ctx.fill()
                        }

                        Behavior on x {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }

                    Rectangle {
                        id: contextPanelShadow
                        x: 0
                        y: contextPanel.bodyY + 1
                        width: contextPanel.width
                        height: contextPanel.bodyHeight
                        radius: contextPanel.bodyRadius
                        color: contextPanel.shadowColor
                        antialiasing: true
                    }

                    Canvas {
                        x: Math.round(appearanceContent.contextPointerCenterX - (contextPanel.arrowWidth / 2))
                        y: 0
                        width: contextPanel.arrowWidth
                        height: contextPanel.arrowHeight
                        contextType: "2d"
                        antialiasing: true

                        onXChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.beginPath()
                            ctx.moveTo(0, height)
                            ctx.lineTo(width / 2, 0)
                            ctx.lineTo(width, height)
                            ctx.closePath()
                            ctx.fillStyle = contextPanel.bodyColor
                            ctx.fill()
                        }

                        Behavior on x {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }

                    Rectangle {
                        id: contextPanelBodySurface
                        x: 0
                        y: contextPanel.bodyY
                        width: contextPanel.width
                        height: contextPanel.bodyHeight
                        radius: contextPanel.bodyRadius
                        color: contextPanel.bodyColor
                        antialiasing: true
                    }

                    Item {
                        id: contextPanelBody
                        x: 0
                        y: contextPanel.bodyY
                        width: contextPanel.width
                        height: contextPanel.bodyHeight
                    }

                    Item {
                        anchors.fill: contextPanelBody
                        anchors.margins: 8
                        visible: appearanceContent.backgroundSource === "Default"

                        Text {
                            anchors.centerIn: parent
                            text: "Use a built-in cover grid background"
                            color: styleTokens.textColor
                            font.family: Qt.application.font.family
                            font.pixelSize: 11
                        }
                    }

                    Item {
                        id: solidPanelContent
                        anchors.fill: contextPanelBody
                        visible: appearanceContent.backgroundSource === "Solid"
                        readonly property int swatchCount: Math.max(
                            1,
                            Number(dialog.appearanceSolidColorOptions.length || 0)
                        )
                        readonly property int sideInset: 12
                        readonly property int swatchSize: 24
                        readonly property real swatchGap: swatchCount > 1
                            ? Math.max(
                                0,
                                (width - (sideInset * 2) - (swatchCount * swatchSize)) / (swatchCount - 1)
                            )
                            : 0

                        Repeater {
                            model: dialog.appearanceSolidColorOptions

                            delegate: Item {
                                required property int index
                                required property var modelData

                                readonly property string swatchColor: String(modelData || "")
                                readonly property bool selected: swatchColor.toLowerCase()
                                    === appearanceContent.solidColor.toLowerCase()
                                readonly property bool hovered: solidSwatchMouseArea.containsMouse

                                x: solidPanelContent.sideInset
                                    + index * (solidPanelContent.swatchSize + solidPanelContent.swatchGap)
                                y: Math.round((solidPanelContent.height - solidPanelContent.swatchSize) / 2)
                                width: solidPanelContent.swatchSize
                                height: solidPanelContent.swatchSize

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: styleTokens.fieldFillColor
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 1
                                    radius: width / 2
                                    color: parent.swatchColor
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: parent.selected || parent.hovered ? 1 : 0
                                    border.color: themeColors.settingsBackgroundChoiceBorderColor
                                }

                                MouseArea {
                                    id: solidSwatchMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dialog.setSettingValue(
                                        "appearance_library_background_solid_color",
                                        parent.swatchColor
                                    )
                                }
                            }
                        }
                    }

                    Item {
                        id: texturePanelContent
                        anchors.fill: contextPanelBody
                        visible: appearanceContent.backgroundSource === "Texture"
                        readonly property int sideInset: 12
                        readonly property int tileSize: 36
                        readonly property int minTileGap: 8
                        readonly property int previewSlotCount: Math.max(
                            1,
                            Math.floor(
                                (width - (sideInset * 2) + minTileGap) / (tileSize + minTileGap)
                            )
                        )
                        readonly property real tileGap: previewSlotCount > 1
                            ? Math.max(
                                0,
                                (width - (sideInset * 2) - (previewSlotCount * tileSize))
                                    / (previewSlotCount - 1)
                            )
                            : 0

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: texturePanelContent.sideInset
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: texturePanelContent.tileGap

                            Repeater {
                                model: dialog.appearanceTexturePreviewOptions(texturePanelContent.previewSlotCount)

                                delegate: Item {
                                    required property var modelData

                                    readonly property string textureKey: String(modelData.actualKey || "")
                                    readonly property string textureSource: String(modelData.source || "")
                                    readonly property int occurrence: Number(modelData.occurrence || 0)
                                    readonly property bool selected: textureKey === appearanceContent.texturePreset
                                        && occurrence === 0
                                    readonly property bool hovered: textureTileMouseArea.containsMouse

                                    width: texturePanelContent.tileSize
                                    height: texturePanelContent.tileSize

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: styleTokens.fieldFillColor
                                    }

                                    Rectangle {
                                        id: texturePreviewShadow
                                        anchors.fill: parent
                                        radius: 4
                                        color: styleTokens.fieldFillColor
                                    }

                                    Rectangle {
                                        id: texturePreview
                                        anchors.fill: parent
                                        anchors.topMargin: 1
                                        radius: 4
                                        color: textureKey === "Dots"
                                            ? themeColors.settingsPreviewDefaultColor
                                            : themeColors.settingsPreviewTextureColor
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: parent.parent.textureSource
                                            fillMode: Image.Tile
                                            smooth: true
                                            opacity: textureKey === "Dots" ? 0.42 : 0.86
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: "transparent"
                                        border.width: selected || hovered ? 1 : 0
                                        border.color: themeColors.settingsBackgroundChoiceBorderColor
                                    }

                                    MouseArea {
                                        id: textureTileMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialog.setSettingValue(
                                            "appearance_library_background_texture",
                                            parent.textureKey
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: customImagePanelContent
                        anchors.fill: contextPanelBody
                        anchors.margins: 8
                        visible: appearanceContent.backgroundSource === "Custom image"

                        SettingsSegmentedChoice {
                            id: customImageModeChoice
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["Fit", "Fill", "Stretch", "Tile"]
                            currentText: appearanceContent.customImageMode
                            onActivated: function(index, text) {
                                dialog.libraryBackgroundImageModeRequested(text)
                            }
                        }

                        SettingsSegmentedChoice {
                            id: customTileSizeChoice
                            visible: appearanceContent.customImageMode === "Tile"
                            readonly property real leftEdge: customImageModeChoice.x + customImageModeChoice.width
                            readonly property real rightEdge: chooseCustomBackgroundButton.x
                            readonly property real availableWidth: Math.max(0, rightEdge - leftEdge)
                            x: leftEdge + Math.round(Math.max(0, availableWidth - width) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["64x64px", "256x256px", "512x512px"]
                            currentText: appearanceContent.customTileSize
                            onActivated: function(index, text) {
                                dialog.setSettingValue("appearance_library_background_tile_size", text)
                            }
                        }

                        PopupActionButton {
                            id: chooseCustomBackgroundButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: appearanceContent.hasCustomImage ? "Change" : "Upload"
                            textPixelSize: 13
                            cornerRadius: Math.round(height / 2)
                            minimumWidth: 92
                            idleColor: styleTokens.footerButtonIdleColor
                            hoverColor: styleTokens.footerButtonHoverColor
                            textColor: styleTokens.textColor
                            hoverEdgeColor: dialog.actionHoverEdgeColor
                            pressedEffectEnabled: true
                            pressedColor: dialog.actionPressedColor
                            pressedEdgeColor: dialog.actionPressedEdgeColor
                            onClicked: dialog.chooseLibraryBackgroundImageRequested()
                        }
                    }
                }

                Item {
                    x: 0
                    y: appearanceContent.optionsTop
                    width: parent.width
                    height: dialog.optionRowPitch
                    visible: false

                    Text {
                        x: 0
                        y: Math.round((parent.height - implicitHeight) / 2)
                        text: "Tile size"
                        color: styleTokens.textColor
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.optionTextSize
                    }

                    SettingsSegmentedChoice {
                        anchors.right: parent.right
                        anchors.rightMargin: dialog.optionControlRightMargin
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["64x64px", "256x256px", "512x512px"]
                        currentText: appearanceContent.customTileSize
                        onActivated: function(index, text) {
                            dialog.setSettingValue("appearance_library_background_tile_size", text)
                        }
                    }
                }

                Item {
                    x: 0
                    y: appearanceContent.optionsTop + dialog.optionRowPitch
                    width: parent.width
                    height: dialog.optionRowPitch
                    visible: false

                    Text {
                        x: 0
                        y: Math.round((parent.height - implicitHeight) / 2)
                        text: "Grid density"
                        color: styleTokens.textColor
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.optionTextSize
                    }

                    SettingsSegmentedChoice {
                        anchors.right: parent.right
                        anchors.rightMargin: dialog.optionControlRightMargin
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["Compact", "Default", "Comfortable"]
                        currentText: String(dialog.settingValue("appearance_grid_density", "Default"))
                        onActivated: function(index, text) {
                            dialog.setSettingValue("appearance_grid_density", text)
                        }
                    }
                }

                Item {
                    x: 0
                    y: appearanceContent.optionsTop + (dialog.optionRowPitch * 2)
                    width: parent.width
                    height: dialog.optionRowPitch
                    visible: false

                    Text {
                        x: 0
                        y: Math.round((parent.height - implicitHeight) / 2)
                        text: "Show hero block"
                        color: styleTokens.textColor
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.optionTextSize
                    }

                    SettingsSwitch {
                        anchors.right: parent.right
                        anchors.rightMargin: dialog.optionControlRightMargin
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Boolean(dialog.settingValue("appearance_show_hero_block", true))
                        onToggled: function(checked) {
                            dialog.setSettingValue("appearance_show_hero_block", checked)
                        }
                    }
                }

            }

            Item {
                id: importArchivesContent
                visible: dialog.selectedSection === "import_archives"
                x: 0
                y: dialog.optionListTop
                width: parent.width
                height: parent.height - y

                PopupActionButton {
                    id: chooseSevenZipButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: Math.round((dialog.optionRowPitch - height) / 2)
                    text: "Choose"
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: styleTokens.textColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    onClicked: dialog.chooseSevenZipRequested()
                }

                Text {
                    x: 0
                    y: Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: "7-Zip path:"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                PopupFieldBackground {
                    x: dialog.importPrimaryLabelWidth
                    y: Math.round((dialog.optionRowPitch - dialog.importFieldHeight) / 2)
                    width: chooseSevenZipButton.x - dialog.importButtonGap - x
                    height: dialog.importFieldHeight
                    cornerRadius: dialog.importFieldRadius
                    fillColor: styleTokens.fieldFillColor
                }

                Text {
                    x: dialog.importPrimaryLabelWidth + 14
                    width: chooseSevenZipButton.x - dialog.importButtonGap - x - 14
                    y: Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: String(dialog.sevenZipDisplayPath || "").length > 0
                        ? dialog.sevenZipDisplayPath
                        : "Not configured"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }

                Text {
                    x: 0
                    y: dialog.optionRowPitch + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: "Verify 7-Zip"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                Item {
                    id: verifySevenZipStatusIndicator
                    anchors.right: verifySevenZipButton.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: verifySevenZipButton.verticalCenter
                    width: visible ? 24 : 0
                    height: 24
                    visible: dialog.sevenZipVerifyState !== "idle"

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: styleTokens.footerButtonIdleColor
                    }

                    ShuffleBusySpinner {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        running: dialog.sevenZipVerifyState === "running"
                        visible: running
                    }

                    Canvas {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: dialog.sevenZipVerifyState === "success"
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.beginPath()
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.lineWidth = 2.6
                            ctx.strokeStyle = themeColors.popupSuccessColor
                            ctx.moveTo(width * 0.18, height * 0.56)
                            ctx.lineTo(width * 0.42, height * 0.8)
                            ctx.lineTo(width * 0.84, height * 0.2)
                            ctx.stroke()
                        }
                    }

                    Canvas {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: dialog.sevenZipVerifyState === "failure"
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.beginPath()
                            ctx.lineCap = "round"
                            ctx.lineWidth = 2.8
                            ctx.strokeStyle = themeColors.popupFailureColor
                            ctx.moveTo(width * 0.5, height * 0.14)
                            ctx.lineTo(width * 0.5, height * 0.68)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.fillStyle = themeColors.popupFailureColor
                            ctx.arc(width * 0.5, height * 0.88, width * 0.08, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }

                PopupActionButton {
                    id: verifySevenZipButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: dialog.optionRowPitch + Math.round((dialog.optionRowPitch - height) / 2)
                    text: "Verify"
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    enabled: dialog.sevenZipVerifyState === "idle"
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: dialog.sevenZipVerifyState === "idle"
                        ? styleTokens.textColor
                        : styleTokens.subtleTextColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    onClicked: {
                        sevenZipVerifyFinalizeTimer.stop()
                        sevenZipVerifyResetTimer.stop()
                        dialog.sevenZipVerifyInlineMessage = ""
                        dialog.sevenZipVerifyState = "running"
                        dialog.verifySevenZipRequested()
                        dialog.sevenZipVerifyPendingSuccess = Boolean(dialog.sevenZipAvailable)
                        dialog.sevenZipVerifyPendingMessage = dialog.sevenZipVerifyPendingSuccess
                            ? ""
                            : dialog.conciseSevenZipVerifyMessage()
                        sevenZipVerifyFinalizeTimer.restart()
                    }
                }

                Text {
                    visible: String(dialog.sevenZipVerifyInlineMessage || "").trim().length > 0
                    x: 0
                    y: verifySevenZipButton.y + verifySevenZipButton.height + 4
                    width: parent.width - dialog.optionControlRightMargin
                    text: dialog.sevenZipVerifyInlineMessage
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 12
                    x: 0
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    text: "Supported archive formats:"
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 12
                    x: dialog.importFormatsValueX
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    width: parent.width - x - dialog.optionControlRightMargin
                    text: dialog.supportedArchiveFormatsSummary
                    color: styleTokens.hintTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Rectangle {
                    x: 0
                    y: verifySevenZipButton.y + verifySevenZipButton.height + 4
                    width: parent.width - dialog.optionControlRightMargin
                    height: 1
                    color: styleTokens.sectionBorderColor
                    opacity: 0.55
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 12 + 24
                    x: 0
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    text: "Supported image formats:"
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 12 + 24
                    x: dialog.importFormatsValueX
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    width: parent.width - x - dialog.optionControlRightMargin
                    text: dialog.supportedImageFormatsSummary
                    color: styleTokens.hintTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 12 + 48
                    x: 0
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    text: "Supported document formats:"
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 12 + 48
                    x: dialog.importFormatsValueX
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    width: parent.width - x - dialog.optionControlRightMargin
                    text: dialog.supportedDocumentFormatsSummary
                    color: styleTokens.hintTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }

            Item {
                id: libraryDataContent
                visible: dialog.selectedSection === "library_data"
                x: 0
                y: dialog.optionListTop
                width: parent.width
                height: parent.height - y
                readonly property bool hasPendingMove: String(dialog.libraryDataPendingMovePath || "").trim().length > 0
                readonly property int relocationBlockTop: dialog.optionRowPitch * 3 + 18

                PopupActionButton {
                    id: openDataFolderButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: Math.round((dialog.optionRowPitch - height) / 2)
                    text: "Open"
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: styleTokens.textColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    enabled: String(dialog.libraryDataRootPath || "").trim().length > 0
                    onClicked: dialog.openLibraryDataFolderRequested()
                }

                Text {
                    x: 0
                    y: Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: "Library data location:"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                PopupFieldBackground {
                    x: dialog.importPrimaryLabelWidth
                    y: Math.round((dialog.optionRowPitch - dialog.importFieldHeight) / 2)
                    width: openDataFolderButton.x - dialog.importButtonGap - x
                    height: dialog.importFieldHeight
                    cornerRadius: dialog.importFieldRadius
                    fillColor: styleTokens.fieldFillColor
                }

                Text {
                    x: dialog.importPrimaryLabelWidth + 14
                    width: openDataFolderButton.x - dialog.importButtonGap - x - 14
                    y: Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: String(dialog.libraryDataRootPath || "")
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }

                PopupActionButton {
                    id: openLibraryFolderButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: dialog.optionRowPitch
                        + Math.round((dialog.optionRowPitch - height) / 2)
                    text: "Open"
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: styleTokens.textColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    enabled: String(dialog.libraryFolderPath || "").trim().length > 0
                    onClicked: dialog.openLibraryFolderRequested()
                }

                Text {
                    x: 0
                    y: dialog.optionRowPitch
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: "Library folder:"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                PopupFieldBackground {
                    x: dialog.importPrimaryLabelWidth
                    y: dialog.optionRowPitch
                        + Math.round((dialog.optionRowPitch - dialog.importFieldHeight) / 2)
                    width: openLibraryFolderButton.x - dialog.importButtonGap - x
                    height: dialog.importFieldHeight
                    cornerRadius: dialog.importFieldRadius
                    fillColor: styleTokens.fieldFillColor
                }

                Text {
                    x: dialog.importPrimaryLabelWidth + 14
                    width: openLibraryFolderButton.x - dialog.importButtonGap - x - 14
                    y: dialog.optionRowPitch
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: String(dialog.libraryFolderPath || "")
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }

                PopupActionButton {
                    id: openRuntimeFolderButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: dialog.optionRowPitch * 2
                        + Math.round((dialog.optionRowPitch - height) / 2)
                    text: "Open"
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: styleTokens.textColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    enabled: String(dialog.libraryRuntimeFolderPath || "").trim().length > 0
                    onClicked: dialog.openLibraryRuntimeFolderRequested()
                }

                Text {
                    x: 0
                    y: dialog.optionRowPitch * 2
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: "Runtime folder:"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                PopupFieldBackground {
                    x: dialog.importPrimaryLabelWidth
                    y: dialog.optionRowPitch * 2
                        + Math.round((dialog.optionRowPitch - dialog.importFieldHeight) / 2)
                    width: openRuntimeFolderButton.x - dialog.importButtonGap - x
                    height: dialog.importFieldHeight
                    cornerRadius: dialog.importFieldRadius
                    fillColor: styleTokens.fieldFillColor
                }

                Text {
                    x: dialog.importPrimaryLabelWidth + 14
                    width: openRuntimeFolderButton.x - dialog.importButtonGap - x - 14
                    y: dialog.optionRowPitch * 2
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: String(dialog.libraryRuntimeFolderPath || "")
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    x: 0
                    y: dialog.optionRowPitch * 3 + 6
                    width: parent.width - dialog.optionControlRightMargin
                    height: 1
                    color: styleTokens.sectionBorderColor
                    opacity: 0.55
                }

                PopupActionButton {
                    id: changeDataLocationButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: libraryDataContent.relocationBlockTop
                        + Math.round((dialog.optionRowPitch - height) / 2)
                    text: libraryDataContent.hasPendingMove ? "Change" : "Choose"
                    textPixelSize: 13
                    cornerRadius: 10
                    minimumWidth: 92
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: styleTokens.textColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    onClicked: dialog.changeLibraryDataLocationRequested()
                }

                Text {
                    x: 0
                    y: libraryDataContent.relocationBlockTop
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: "Move library data:"
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                PopupFieldBackground {
                    x: dialog.importPrimaryLabelWidth
                    y: libraryDataContent.relocationBlockTop
                        + Math.round((dialog.optionRowPitch - dialog.importFieldHeight) / 2)
                    width: changeDataLocationButton.x - dialog.importButtonGap - x
                    height: dialog.importFieldHeight
                    cornerRadius: dialog.importFieldRadius
                    fillColor: styleTokens.fieldFillColor
                }

                Text {
                    x: dialog.importPrimaryLabelWidth + 14
                    width: changeDataLocationButton.x - dialog.importButtonGap - x - 14
                    y: libraryDataContent.relocationBlockTop
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: libraryDataContent.hasPendingMove
                        ? String(dialog.libraryDataPendingMovePath || "")
                        : "No destination selected"
                    color: libraryDataContent.hasPendingMove ? styleTokens.textColor : styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                }

                Text {
                    visible: libraryDataContent.hasPendingMove
                    x: dialog.importPrimaryLabelWidth
                    y: libraryDataContent.relocationBlockTop + dialog.optionRowPitch + 1
                    width: parent.width - x - dialog.optionControlRightMargin
                    text: "Scheduled after restart."
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    x: 0
                    y: libraryDataContent.relocationBlockTop
                        + dialog.optionRowPitch
                        + (libraryDataContent.hasPendingMove ? 17 : 9)
                    width: parent.width - dialog.optionControlRightMargin
                    text: "The transfer will run after you restart the app and may take time depending on library size. Choose an empty folder."
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    lineHeight: 1.15
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}

