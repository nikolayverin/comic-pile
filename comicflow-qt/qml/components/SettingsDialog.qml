import QtQuick
import QtQuick.Controls
import "SettingsCatalog.js" as SettingsCatalog
import "AppText.js" as AppText

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }

    property var settingsController: null
    property var libraryModelRef: null
    property string libraryBackgroundCustomImageResolvedPath: ""
    property string sevenZipConfiguredPath: ""
    property string sevenZipDisplayPath: ""
    property bool sevenZipAvailable: false
    property string sevenZipStatusMessage: ""
    property string libraryDataRootPath: ""
    property string libraryDataPendingMovePath: ""
    property string libraryFolderPath: ""
    property string libraryRuntimeFolderPath: ""
    property string storageAccessCheckState: "idle"
    property string storageAccessResultText: ""
    property string storageAccessHintText: ""
    property string sevenZipVerifyState: "idle"
    property string sevenZipVerifyInlineMessage: ""
    property bool sevenZipVerifyPendingSuccess: false
    property string sevenZipVerifyPendingMessage: ""
    property string resetSettingsState: "idle"
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
    readonly property int appearanceOptionsGap: 12
    readonly property var settingsSections: SettingsCatalog.settingsSections
    readonly property var sectionOptionRows: SettingsCatalog.sectionOptionRows

    PopupStyle {
        id: styleTokens
    }

    popupStyle: styleTokens
    debugName: "settings-dialog"
    debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
    title: ""
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: 820
    height: 345

    onOpened: {
        const requested = String(requestedSection || "").trim()
        selectedSection = requested.length > 0 ? requested : "general"
        storageAccessCheckState = "idle"
        storageAccessResultText = ""
        storageAccessHintText = ""
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
    signal checkStorageAccessRequested()
    signal reloadLibraryRequested()
    signal resetSettingsRequested()

    function conciseSevenZipVerifyMessage() {
        const rawText = String(dialog.sevenZipStatusMessage || "").trim()
        if (rawText.length < 1) {
            return AppText.settingsSevenZipUnavailable
        }
        if (rawText.toLowerCase().indexOf("missing") >= 0) {
            return AppText.settingsSevenZipUnavailable
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

    Timer {
        id: resetSettingsFinalizeTimer
        interval: 260
        repeat: false
        onTriggered: {
            dialog.resetSettingsState = "success"
            resetSettingsResetTimer.restart()
        }
    }

    Timer {
        id: resetSettingsResetTimer
        interval: 1400
        repeat: false
        onTriggered: dialog.resetSettingsState = "idle"
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
            text: AppText.popupSettingsTitle
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
                id: generalResetBlock
                visible: dialog.selectedSection === "general"
                x: 0
                y: optionListColumn.y + optionListColumn.height + 8
                width: parent.width
                height: 54

                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width - dialog.optionControlRightMargin
                    height: 1
                    color: styleTokens.sectionBorderColor
                    opacity: 0.55
                }

                PopupActionButton {
                    id: resetSettingsButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: 14
                    text: AppText.commonReset
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    enabled: dialog.resetSettingsState === "idle"
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: dialog.resetSettingsState === "idle"
                        ? styleTokens.textColor
                        : styleTokens.subtleTextColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    onClicked: {
                        resetSettingsFinalizeTimer.stop()
                        resetSettingsResetTimer.stop()
                        dialog.resetSettingsState = "running"
                        dialog.resetSettingsRequested()
                        resetSettingsFinalizeTimer.restart()
                    }
                }

                Item {
                    id: resetSettingsStatusIndicator
                    anchors.right: resetSettingsButton.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: resetSettingsButton.verticalCenter
                    width: visible ? 24 : 0
                    height: 24
                    visible: dialog.resetSettingsState !== "idle"

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: styleTokens.footerButtonIdleColor
                    }

                    ShuffleBusySpinner {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        running: dialog.resetSettingsState === "running"
                        visible: running
                    }

                    Canvas {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: dialog.resetSettingsState === "success"
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
                }

                Text {
                    x: 0
                    y: resetSettingsButton.y + Math.round((resetSettingsButton.height - implicitHeight) / 2)
                    text: AppText.settingsResetToDefault
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }
            }

            SettingsAppearanceSection {
                id: appearanceContent
                dialogRef: dialog
                libraryModelRef: dialog.libraryModelRef
                popupStyleTokensRef: styleTokens
                themeColorsRef: themeColors
                visible: dialog.selectedSection === "appearance"
                x: 0
                y: dialog.optionListTop
                width: parent.width
                height: parent.height - y
                onChooseLibraryBackgroundImageRequested: dialog.chooseLibraryBackgroundImageRequested()
                onLibraryBackgroundImageModeRequested: function(mode) {
                    dialog.libraryBackgroundImageModeRequested(mode)
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
                    text: AppText.commonChoose
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
                    text: AppText.settingsSevenZipPath
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
                    text: AppText.settingsVerifySevenZip
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
                    text: AppText.commonCheck
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
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 16
                    x: 0
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    text: AppText.settingsSupportedArchiveFormats
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 16
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
                    y: verifySevenZipButton.y + verifySevenZipButton.height + 8
                    width: parent.width - dialog.optionControlRightMargin
                    height: 1
                    color: styleTokens.sectionBorderColor
                    opacity: 0.55
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 16 + 24
                    x: 0
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    text: AppText.settingsSupportedImageFormats
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 16 + 24
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
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 16 + 48
                    x: 0
                    y: infoTop + Math.round((14 - implicitHeight) / 2)
                    text: AppText.settingsSupportedDocumentFormats
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                }

                Text {
                    readonly property real infoTop: verifySevenZipButton.y + verifySevenZipButton.height + 16 + 48
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
                readonly property bool storageAccessHintVisible: dialog.storageAccessCheckState === "failure"
                    && String(dialog.storageAccessHintText || "").trim().length > 0
                readonly property int storageAccessDividerY: dialog.optionRowPitch * 4
                    + (storageAccessHintVisible ? 28 : 10)
                readonly property int relocationBlockTop: storageAccessDividerY + 4

                PopupActionButton {
                    id: openDataFolderButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: Math.round((dialog.optionRowPitch - height) / 2)
                    text: AppText.commonOpen
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
                    text: AppText.settingsLibraryDataLocation
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
                    text: AppText.commonOpen
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
                    text: AppText.settingsLibraryFolder
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
                    text: AppText.commonOpen
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
                    text: AppText.settingsRuntimeFolder
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

                PopupActionButton {
                    id: checkStorageAccessButton
                    anchors.right: parent.right
                    anchors.rightMargin: dialog.optionControlRightMargin
                    y: dialog.optionRowPitch * 3
                        + Math.round((dialog.optionRowPitch - height) / 2)
                    text: AppText.commonCheck
                    textPixelSize: 13
                    cornerRadius: Math.round(height / 2)
                    minimumWidth: 92
                    enabled: dialog.storageAccessCheckState !== "running"
                    idleColor: styleTokens.footerButtonIdleColor
                    hoverColor: styleTokens.footerButtonHoverColor
                    textColor: dialog.storageAccessCheckState === "running"
                        ? styleTokens.subtleTextColor
                        : styleTokens.textColor
                    hoverEdgeColor: dialog.actionHoverEdgeColor
                    pressedEffectEnabled: true
                    pressedColor: dialog.actionPressedColor
                    pressedEdgeColor: dialog.actionPressedEdgeColor
                    onClicked: {
                        dialog.storageAccessCheckState = "running"
                        dialog.storageAccessResultText = AppText.settingsChecking
                        dialog.storageAccessHintText = ""
                        dialog.checkStorageAccessRequested()
                    }
                }

                Item {
                    id: storageAccessStatusIndicator
                    anchors.right: checkStorageAccessButton.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: checkStorageAccessButton.verticalCenter
                    width: visible ? 24 : 0
                    height: 24
                    visible: dialog.storageAccessCheckState !== "idle"

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: styleTokens.footerButtonIdleColor
                    }

                    ShuffleBusySpinner {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        running: dialog.storageAccessCheckState === "running"
                        visible: running
                    }

                    Canvas {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: dialog.storageAccessCheckState === "success"
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
                        visible: dialog.storageAccessCheckState === "failure"
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

                Text {
                    x: 0
                    y: dialog.optionRowPitch * 3
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    text: AppText.settingsCheckStorageAccess
                    color: styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: dialog.optionTextSize
                }

                Text {
                    visible: String(dialog.storageAccessResultText || "").trim().length > 0
                    anchors.right: storageAccessStatusIndicator.left
                    anchors.rightMargin: 10
                    y: dialog.optionRowPitch * 3
                        + Math.round((dialog.optionRowPitch - implicitHeight) / 2)
                    width: 150
                    text: dialog.storageAccessResultText
                    color: dialog.storageAccessCheckState === "running"
                        ? styleTokens.subtleTextColor
                        : styleTokens.textColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    visible: libraryDataContent.storageAccessHintVisible
                    x: 0
                    y: dialog.optionRowPitch * 4 + 4
                    width: parent.width - dialog.optionControlRightMargin
                    text: dialog.storageAccessHintText
                    color: styleTokens.subtleTextColor
                    font.family: Qt.application.font.family
                    font.pixelSize: 11
                    lineHeight: 1.15
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    x: 0
                    y: libraryDataContent.storageAccessDividerY
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
                    text: libraryDataContent.hasPendingMove ? AppText.commonChange : AppText.commonChoose
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
                    text: AppText.settingsMoveLibraryData
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
                        : AppText.settingsNoDestinationSelected
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
                    text: AppText.settingsScheduledAfterRestart
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
                    text: AppText.settingsRelocationHint
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

