import QtQuick
import QtQuick.Controls
import "SettingsCatalog.js" as SettingsCatalog
import "AppText.js" as AppText

Item {
    id: root

    property var dialogRef: null
    property var popupStyleTokensRef: null
    property var themeColorsRef: null

    signal chooseLibraryBackgroundImageRequested()
    signal libraryBackgroundImageModeRequested(string mode)

    readonly property string backgroundSource: String(
        dialogRef
            ? dialogRef.settingValue(
                "appearance_library_background",
                SettingsCatalog.defaultAppearanceLibraryBackground
            )
            : SettingsCatalog.defaultAppearanceLibraryBackground
    )
    readonly property string solidColor: String(
        dialogRef
            ? dialogRef.settingValue(
                "appearance_library_background_solid_color",
                SettingsCatalog.defaultAppearanceLibraryBackgroundSolidColor
            )
            : SettingsCatalog.defaultAppearanceLibraryBackgroundSolidColor
    )
    readonly property string texturePreset: String(
        dialogRef
            ? dialogRef.settingValue(
                "appearance_library_background_texture",
                SettingsCatalog.defaultAppearanceLibraryBackgroundTexture
            )
            : SettingsCatalog.defaultAppearanceLibraryBackgroundTexture
    )
    readonly property string customImagePath: String(
        dialogRef
            ? dialogRef.settingValue(
                "appearance_library_background_custom_image_path",
                SettingsCatalog.defaultAppearanceLibraryBackgroundCustomImagePath
            )
            : SettingsCatalog.defaultAppearanceLibraryBackgroundCustomImagePath
    )
    readonly property string customImageMode: String(
        dialogRef
            ? dialogRef.settingValue(
                "appearance_library_background_image_mode",
                SettingsCatalog.defaultAppearanceLibraryBackgroundImageMode
            )
            : SettingsCatalog.defaultAppearanceLibraryBackgroundImageMode
    )
    readonly property string customTileSize: String(
        dialogRef
            ? dialogRef.settingValue(
                "appearance_library_background_tile_size",
                SettingsCatalog.defaultAppearanceLibraryBackgroundTileSize
            )
            : SettingsCatalog.defaultAppearanceLibraryBackgroundTileSize
    )
    readonly property int tilePixelSize: backgroundTilePixelSize(customTileSize)
    readonly property bool hasCustomImage: customImagePath.length > 0
    readonly property bool customModeIsTile: customImageMode === "Tile"
    readonly property int backgroundSourceIndex: backgroundSourceOptionIndex(backgroundSource)
    readonly property real backgroundCardWidth: backgroundSourceCards.width > 0
        ? backgroundSourceCards.width / Math.max(1, SettingsCatalog.appearanceBackgroundSourceOptions.length)
        : 139
    readonly property real contextPointerCenterX: {
        const center = (backgroundSourceIndex * backgroundCardWidth) + (backgroundCardWidth / 2)
        const minCenter = 13
        const maxCenter = 543
        return Math.max(minCenter, Math.min(maxCenter, center))
    }
    readonly property int optionsTop: contextPanel.y + contextPanel.height + Number(dialogRef ? dialogRef.appearanceOptionsGap : 12)

    function settingValue(valueKey, fallbackValue) {
        return dialogRef && typeof dialogRef.settingValue === "function"
            ? dialogRef.settingValue(valueKey, fallbackValue)
            : fallbackValue
    }

    function setSettingValue(valueKey, nextValue) {
        if (dialogRef && typeof dialogRef.setSettingValue === "function") {
            dialogRef.setSettingValue(valueKey, nextValue)
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

    function backgroundSourceOptionIndex(modeKey) {
        const key = String(modeKey || "").trim()
        const options = Array.isArray(SettingsCatalog.appearanceBackgroundSourceOptions)
            ? SettingsCatalog.appearanceBackgroundSourceOptions
            : []
        for (let i = 0; i < options.length; i += 1) {
            const entry = options[i] || {}
            if (String(entry.key || "") === key) {
                return i
            }
        }
        return 0
    }

    function backgroundTilePixelSize(tileSizeLabel) {
        const label = String(tileSizeLabel || "").trim()
        if (label === "512x512px") return 512
        if (label === "256x256px") return 256
        return 64
    }

    Text {
        id: libraryBackgroundLabel
        x: 0
        y: 0
        text: AppText.settingsAppearanceCoverGridBackground
        color: popupStyleTokensRef ? popupStyleTokensRef.textColor : "white"
        font.family: Qt.application.font.family
        font.pixelSize: dialogRef ? dialogRef.optionTextSize : 11
    }

    Row {
        id: backgroundSourceCards
        x: 0
        y: libraryBackgroundLabel.y + libraryBackgroundLabel.implicitHeight + 10
        spacing: 0

        Repeater {
            model: SettingsCatalog.appearanceBackgroundSourceOptions

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
                        || String(parent.modelData.key || "") === root.backgroundSource
                    title: parent.modeKey === "Custom image" ? AppText.settingsAppearanceCustomShort : String(parent.modelData.label || "")
                    selected: String(parent.modelData.key || "") === root.backgroundSource
                    bodyColor: themeColorsRef ? themeColorsRef.settingsBackgroundChoiceBodyColor : "#333333"
                    cornerRadius: 6
                    onClicked: root.setSettingValue("appearance_library_background", parent.modeKey)
                    previewAlwaysContent: [
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: themeColorsRef ? themeColorsRef.settingsPreviewDefaultColor : "#444444"
                            clip: true
                            antialiasing: true
                            visible: modeKey === "Default"

                            Rectangle {
                                anchors.top: parent.top
                                width: parent.width
                                height: Math.round(parent.height * 0.52)
                                color: themeColorsRef ? themeColorsRef.settingsPreviewDefaultTopColor : "#555555"
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
                            color: root.solidColor
                            clip: true
                            antialiasing: true
                            visible: modeKey === "Solid"
                        },
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: SettingsCatalog.appearanceTextureUsesDefaultBase(root.texturePreset)
                                ? (themeColorsRef ? themeColorsRef.settingsPreviewDefaultColor : "#444444")
                                : (themeColorsRef ? themeColorsRef.settingsPreviewTextureColor : "#555555")
                            clip: true
                            antialiasing: true
                            visible: modeKey === "Texture"

                            Image {
                                anchors.fill: parent
                                source: SettingsCatalog.appearanceTextureSource(root.texturePreset)
                                fillMode: Image.Tile
                                sourceSize.width: SettingsCatalog.appearanceTextureTilePixelSize(root.texturePreset)
                                sourceSize.height: SettingsCatalog.appearanceTextureTilePixelSize(root.texturePreset)
                                smooth: true
                                opacity: 1.0
                            }
                        },
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: themeColorsRef ? themeColorsRef.settingsPreviewCustomColor : "#666666"
                            clip: true
                            antialiasing: true
                            visible: modeKey === "Custom image"

                            Image {
                                visible: root.hasCustomImage
                                anchors.fill: parent
                                source: root.localFileSource(root.customImagePath)
                                fillMode: root.customImageMode === "Fit"
                                    ? Image.PreserveAspectFit
                                    : root.customImageMode === "Stretch"
                                        ? Image.Stretch
                                        : root.customImageMode === "Tile"
                                            ? Image.Tile
                                            : Image.PreserveAspectCrop
                                sourceSize: root.customModeIsTile
                                    ? Qt.size(root.tilePixelSize, root.tilePixelSize)
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
        y: backgroundSourceCards.y + backgroundSourceCards.height + Number(dialogRef ? dialogRef.appearanceContextGap : 12)
        width: 556
        height: bodyY + bodyHeight
        visible: true

        readonly property int arrowWidth: 14
        readonly property int arrowHeight: 7
        readonly property int bodyHeight: 48
        readonly property int bodyY: arrowHeight
        readonly property int bodyRadius: 6
        readonly property color bodyColor: themeColorsRef ? themeColorsRef.settingsContextPanelBodyColor : "#2d2d2d"
        readonly property color shadowColor: themeColorsRef ? themeColorsRef.settingsContextPanelShadowColor : "#22000000"

        Canvas {
            x: Math.round(root.contextPointerCenterX - (contextPanel.arrowWidth / 2))
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
            x: 0
            y: contextPanel.bodyY + 1
            width: contextPanel.width
            height: contextPanel.bodyHeight
            radius: contextPanel.bodyRadius
            color: contextPanel.shadowColor
            antialiasing: true
        }

        Canvas {
            x: Math.round(root.contextPointerCenterX - (contextPanel.arrowWidth / 2))
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
            visible: root.backgroundSource === "Default"

            Text {
                anchors.centerIn: parent
                text: AppText.settingsAppearanceUseBuiltInBackground
                color: popupStyleTokensRef ? popupStyleTokensRef.textColor : "white"
                font.family: Qt.application.font.family
                font.pixelSize: 11
            }
        }

        Item {
            id: solidPanelContent
            anchors.fill: contextPanelBody
            visible: root.backgroundSource === "Solid"
            readonly property int swatchCount: Math.max(
                1,
                Number(SettingsCatalog.appearanceSolidColorOptions.length || 0)
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
                model: SettingsCatalog.appearanceSolidColorOptions

                delegate: Item {
                    required property int index
                    required property var modelData

                    readonly property string swatchColor: String(modelData || "")
                    readonly property bool selected: swatchColor.toLowerCase()
                        === root.solidColor.toLowerCase()
                    readonly property bool hovered: solidSwatchMouseArea.containsMouse

                    x: solidPanelContent.sideInset
                        + index * (solidPanelContent.swatchSize + solidPanelContent.swatchGap)
                    y: Math.round((solidPanelContent.height - solidPanelContent.swatchSize) / 2)
                    width: solidPanelContent.swatchSize
                    height: solidPanelContent.swatchSize

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: popupStyleTokensRef ? popupStyleTokensRef.fieldFillColor : "#2d2d2d"
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
                        border.color: themeColorsRef ? themeColorsRef.settingsBackgroundChoiceBorderColor : "#ffffff"
                    }

                    MouseArea {
                        id: solidSwatchMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setSettingValue(
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
            visible: root.backgroundSource === "Texture"
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
                    model: SettingsCatalog.appearanceTextureOptions

                    delegate: Item {
                        required property var modelData

                        readonly property string textureKey: String(modelData.key || "")
                        readonly property string textureSource: String(modelData.source || "")
                        readonly property bool useDefaultBase: Boolean(modelData.previewUseDefaultBase)
                        readonly property int textureTileSize: Number(modelData.tileSize || 64)
                        readonly property bool selected: textureKey === root.texturePreset
                        readonly property bool hovered: textureTileMouseArea.containsMouse

                        width: texturePanelContent.tileSize
                        height: texturePanelContent.tileSize

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: popupStyleTokensRef ? popupStyleTokensRef.fieldFillColor : "#2d2d2d"
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 1
                            radius: 4
                            color: parent.parent.useDefaultBase
                                ? (themeColorsRef ? themeColorsRef.settingsPreviewDefaultColor : "#444444")
                                : (themeColorsRef ? themeColorsRef.settingsPreviewTextureColor : "#555555")
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: parent.parent.textureSource
                                fillMode: Image.Tile
                                sourceSize.width: parent.parent.textureTileSize
                                sourceSize.height: parent.parent.textureTileSize
                                smooth: true
                                opacity: 1.0
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: "transparent"
                            border.width: selected || hovered ? 1 : 0
                            border.color: themeColorsRef ? themeColorsRef.settingsBackgroundChoiceBorderColor : "#ffffff"
                        }

                        MouseArea {
                            id: textureTileMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setSettingValue(
                                "appearance_library_background_texture",
                                parent.textureKey
                            )
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: contextPanelBody
            anchors.margins: 8
            visible: root.backgroundSource === "Custom image"

            SettingsSegmentedChoice {
                id: customImageModeChoice
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                options: SettingsCatalog.appearanceBackgroundImageModeOptions
                currentText: root.customImageMode
                onActivated: function(index, text) {
                    root.libraryBackgroundImageModeRequested(text)
                }
            }

            SettingsSegmentedChoice {
                id: customTileSizeChoice
                visible: root.customImageMode === "Tile"
                readonly property real leftEdge: customImageModeChoice.x + customImageModeChoice.width
                readonly property real rightEdge: chooseCustomBackgroundButton.x
                readonly property real availableWidth: Math.max(0, rightEdge - leftEdge)
                x: leftEdge + Math.round(Math.max(0, availableWidth - width) / 2)
                anchors.verticalCenter: parent.verticalCenter
                options: SettingsCatalog.appearanceBackgroundTileSizeOptions
                currentText: root.customTileSize
                onActivated: function(index, text) {
                    root.setSettingValue("appearance_library_background_tile_size", text)
                }
            }

            PopupActionButton {
                id: chooseCustomBackgroundButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.hasCustomImage ? AppText.commonChange : AppText.commonUpload
                textPixelSize: 13
                cornerRadius: Math.round(height / 2)
                minimumWidth: 92
                idleColor: popupStyleTokensRef ? popupStyleTokensRef.footerButtonIdleColor : "#2d2d2d"
                hoverColor: popupStyleTokensRef ? popupStyleTokensRef.footerButtonHoverColor : "#3a3a3a"
                textColor: popupStyleTokensRef ? popupStyleTokensRef.textColor : "white"
                hoverEdgeColor: dialogRef ? dialogRef.actionHoverEdgeColor : "#ffffff"
                pressedEffectEnabled: true
                pressedColor: dialogRef ? dialogRef.actionPressedColor : "#1d1d1d"
                pressedEdgeColor: dialogRef ? dialogRef.actionPressedEdgeColor : "#ffffff"
                onClicked: root.chooseLibraryBackgroundImageRequested()
            }
        }
    }

    Item {
        x: 0
        y: root.optionsTop
        width: parent.width
        height: dialogRef ? dialogRef.optionRowPitch : 34

        Text {
            x: 0
            y: Math.round((parent.height - implicitHeight) / 2)
            text: AppText.settingsAppearanceGridDensity
            color: popupStyleTokensRef ? popupStyleTokensRef.textColor : "white"
            font.family: Qt.application.font.family
            font.pixelSize: dialogRef ? dialogRef.optionTextSize : 11
        }

        SettingsSegmentedChoice {
            anchors.right: parent.right
            anchors.rightMargin: dialogRef ? dialogRef.optionControlRightMargin : 30
            anchors.verticalCenter: parent.verticalCenter
            options: SettingsCatalog.appearanceGridDensityOptions
            currentText: String(root.settingValue("appearance_grid_density", "Default"))
            onActivated: function(index, text) {
                root.setSettingValue("appearance_grid_density", text)
            }
        }
    }

    Item {
        x: 0
        y: root.optionsTop + (dialogRef ? dialogRef.optionRowPitch : 34)
        width: parent.width
        height: dialogRef ? dialogRef.optionRowPitch : 34

        Text {
            x: 0
            y: Math.round((parent.height - implicitHeight) / 2)
            text: AppText.settingsAppearanceShowHeroBlock
            color: popupStyleTokensRef ? popupStyleTokensRef.textColor : "white"
            font.family: Qt.application.font.family
            font.pixelSize: dialogRef ? dialogRef.optionTextSize : 11
        }

        SettingsSwitch {
            anchors.right: parent.right
            anchors.rightMargin: dialogRef ? dialogRef.optionControlRightMargin : 30
            anchors.verticalCenter: parent.verticalCenter
            checked: Boolean(root.settingValue("appearance_show_hero_block", true))
            onToggled: function(checked) {
                root.setSettingValue("appearance_show_hero_block", checked)
            }
        }
    }

    Item {
        x: 0
        y: root.optionsTop + ((dialogRef ? dialogRef.optionRowPitch : 34) * 2)
        width: parent.width
        height: dialogRef ? dialogRef.optionRowPitch : 34

        Text {
            x: 0
            y: Math.round((parent.height - implicitHeight) / 2)
            text: AppText.settingsAppearanceShowBookmarkRibbon
            color: popupStyleTokensRef ? popupStyleTokensRef.textColor : "white"
            font.family: Qt.application.font.family
            font.pixelSize: dialogRef ? dialogRef.optionTextSize : 11
        }

        SettingsSwitch {
            anchors.right: parent.right
            anchors.rightMargin: dialogRef ? dialogRef.optionControlRightMargin : 30
            anchors.verticalCenter: parent.verticalCenter
            checked: Boolean(root.settingValue("reader_show_bookmark_ribbon_on_grid_covers", false))
            onToggled: function(checked) {
                root.setSettingValue("reader_show_bookmark_ribbon_on_grid_covers", checked)
            }
        }
    }
}
