import QtQuick
import QtQuick.Controls
import "MetadataTextUtils.js" as MetadataTextUtils

Popup {
    id: metadataDialog
    ThemeColors { id: themeColors }
    modal: true
    focus: true
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    PopupStyle { id: popupStyle }
    x: Math.round((metadataDialog.hostWidth - width) / 2)
    y: Math.round((metadataDialog.hostHeight - height) / 2)
    width: popupStyle.issueMetadataWidth
    height: popupStyle.issueMetadataHeight
    padding: 0

    property real hostWidth: 0
    property real hostHeight: 0
    property color dangerColor: themeColors.dangerColor
    property bool metadataDirty: false
    property bool metadataApplyingState: false
    property string errorText: ""
    property var metadataInitialState: ({})
    property var metadataYearOptions: []
    property var metadataMonthOptions: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    property var metadataAgeRatingOptions: []
    property var metadataBaseAgeRatings: ["All ages", "6+", "12+", "13+", "15+", "16+", "18+"]
    readonly property bool dropdownPopupVisible: editYearCombo.popupVisible
        || editMonthCombo.popupVisible
        || editAgeRatingCombo.popupVisible

    signal saveRequested(var draft)
    signal resetRequested()

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: metadataDialog.visible && !metadataDialog.dropdownPopupVisible
        onActivated: metadataDialog.close()
    }

    function monthNameFromNumber(monthNumber) {
        const value = Number(monthNumber || 0)
        if (value < 1 || value > 12) return ""
        return metadataMonthOptions[value - 1]
    }

    function monthNumberFromName(monthName) {
        const name = String(monthName || "").trim()
        if (name.length < 1) return ""
        const idx = metadataMonthOptions.indexOf(name)
        if (idx >= 0) return String(idx + 1)
        const lower = name.toLowerCase()
        const matches = metadataMonthOptions.filter(function(item) {
            return String(item).toLowerCase().indexOf(lower) === 0
        })
        if (matches.length === 1) {
            return String(metadataMonthOptions.indexOf(matches[0]) + 1)
        }
        return ""
    }

    function buildYearOptions(currentYearText) {
        const list = []
        const now = new Date()
        const startYear = Number(now.getFullYear()) + 1
        const endYear = 1900
        for (let year = startYear; year >= endYear; year -= 1) {
            list.push(String(year))
        }
        const normalizedCurrent = String(currentYearText || "").trim()
        if (normalizedCurrent.length > 0 && list.indexOf(normalizedCurrent) < 0) {
            list.unshift(normalizedCurrent)
        }
        return list
    }

    function buildAgeRatingOptions(currentAgeRating) {
        const list = metadataBaseAgeRatings.slice(0)
        const normalized = String(currentAgeRating || "").trim()
        if (normalized.length > 0 && list.indexOf(normalized) < 0) {
            list.unshift(normalized)
        }
        return list
    }

    function filterOptions(options, filterText) {
        const base = Array.isArray(options) ? options : []
        const query = String(filterText || "").trim().toLowerCase()
        if (query.length < 1) return base
        return base.filter(function(item) {
            return String(item).toLowerCase().indexOf(query) === 0
        })
    }

    function copyControlText(control) {
        if (!control) return
        if (typeof control.selectAll !== "function" || typeof control.copy !== "function") return
        control.selectAll()
        control.copy()
        if (typeof control.deselect === "function") {
            control.deselect()
        }
    }

    function normalizeTextControl(control, mode) {
        if (!control) return
        const source = String(control.text || "")
        let normalized = source
        if (mode === "preserveCase") {
            normalized = MetadataTextUtils.normalizePreserveCaseText(source)
        } else if (mode === "title") {
            normalized = MetadataTextUtils.normalizeTitleText(source)
        } else if (mode === "nameList") {
            normalized = MetadataTextUtils.normalizeNameListText(source)
        } else if (mode === "sentence") {
            normalized = MetadataTextUtils.normalizeSentenceText(source)
        }
        if (String(control.text || "") !== normalized) {
            control.text = normalized
        }
        refreshDirtyState()
    }

    function normalizeYearComboValue() {
        const normalizedYear = MetadataTextUtils.normalizeYearText(editYearCombo.editText || editYearCombo.currentText)
        metadataYearOptions = buildYearOptions(normalizedYear)
        const yearIdx = metadataYearOptions.indexOf(normalizedYear)
        editYearCombo.currentIndex = yearIdx
        editYearCombo.editText = normalizedYear
        editYearCombo.filterText = ""
        refreshDirtyState()
    }

    function normalizeMonthComboValue() {
        const normalizedMonth = MetadataTextUtils.normalizeMonthName(
            editMonthCombo.editText || editMonthCombo.currentText,
            metadataMonthOptions
        )
        const monthIdx = metadataMonthOptions.indexOf(normalizedMonth)
        editMonthCombo.currentIndex = monthIdx
        editMonthCombo.editText = normalizedMonth
        editMonthCombo.filterText = ""
        refreshDirtyState()
    }

    function normalizeAgeRatingComboValue() {
        const normalizedAge = MetadataTextUtils.normalizeChoiceText(
            editAgeRatingCombo.editText || editAgeRatingCombo.currentText,
            metadataAgeRatingOptions
        )
        metadataAgeRatingOptions = buildAgeRatingOptions(normalizedAge)
        const ageIdx = metadataAgeRatingOptions.indexOf(normalizedAge)
        editAgeRatingCombo.currentIndex = ageIdx
        editAgeRatingCombo.editText = normalizedAge
        editAgeRatingCombo.filterText = ""
        refreshDirtyState()
    }

    function currentState() {
        return {
            series: String(editSeriesField.text || "").trim(),
            volume: String(editVolumeField.text || "").trim(),
            issueNumber: String(editIssueField.text || "").trim(),
            title: String(editTitleField.text || "").trim(),
            publisher: String(editPublisherField.text || "").trim(),
            year: String(editYearCombo.currentText || "").trim(),
            month: monthNumberFromName(String(editMonthCombo.currentText || "").trim()),
            ageRating: String(editAgeRatingCombo.currentText || "").trim(),
            writer: String(editWriterField.text || "").trim(),
            penciller: String(editPencillerField.text || "").trim(),
            inker: String(editInkerField.text || "").trim(),
            colorist: String(editColoristField.text || "").trim(),
            letterer: String(editLettererField.text || "").trim(),
            coverArtist: String(editCoverArtistField.text || "").trim(),
            editor: String(editEditorField.text || "").trim(),
            storyArc: String(editStoryArcField.text || "").trim(),
            characters: String(editCharactersField.text || "").trim()
        }
    }

    function refreshDirtyState() {
        if (metadataApplyingState) return
        metadataDirty = JSON.stringify(currentState()) !== JSON.stringify(metadataInitialState)
    }

    function applyState(state) {
        metadataApplyingState = true
        const safeState = state || {}
        const yearText = String(safeState.year || "").trim()
        const monthName = String(safeState.monthName || "").trim().length > 0
            ? String(safeState.monthName || "").trim()
            : monthNameFromNumber(safeState.month)
        const ageText = String(safeState.ageRating || "").trim()

        metadataYearOptions = buildYearOptions(yearText)
        metadataAgeRatingOptions = buildAgeRatingOptions(ageText)

        editSeriesField.text = String(safeState.series || "")
        editVolumeField.text = String(safeState.volume || "")
        editIssueField.text = String(safeState.issueNumber || "")
        editPublisherField.text = String(safeState.publisher || "")
        editTitleField.text = String(safeState.title || "")
        editWriterField.text = String(safeState.writer || "")
        editPencillerField.text = String(safeState.penciller || "")
        editInkerField.text = String(safeState.inker || "")
        editColoristField.text = String(safeState.colorist || "")
        editLettererField.text = String(safeState.letterer || "")
        editCoverArtistField.text = String(safeState.coverArtist || "")
        editEditorField.text = String(safeState.editor || "")
        editStoryArcField.text = String(safeState.storyArc || "")
        editCharactersField.text = String(safeState.characters || "")

        const yearIdx = metadataYearOptions.indexOf(yearText)
        editYearCombo.currentIndex = yearIdx
        editYearCombo.editText = yearText

        const monthIdx = metadataMonthOptions.indexOf(monthName)
        editMonthCombo.currentIndex = monthIdx
        editMonthCombo.editText = monthName

        const ageIdx = metadataAgeRatingOptions.indexOf(ageText)
        editAgeRatingCombo.currentIndex = ageIdx
        editAgeRatingCombo.editText = ageText

        metadataApplyingState = false
        refreshDirtyState()
    }

    function openForState(state) {
        errorText = ""
        applyState(state || {})
        metadataInitialState = currentState()
        metadataDirty = false
        open()
    }

    function markSaved(state) {
        metadataInitialState = state || currentState()
        metadataDirty = false
    }

    function resetToInitial() {
        applyState(metadataInitialState)
        errorText = ""
        metadataDirty = false
    }

    Overlay.modal: Rectangle {
        color: popupStyle.overlayColor
    }

    background: PopupSurface {
        cornerRadius: popupStyle.popupRadius
        fillColor: popupStyle.popupFillColor
        edgeColor: popupStyle.edgeLineColor
    }

    contentItem: PopupDialogShell {
        id: metadataShell
        popupStyle: popupStyle
        title: "Issue Metadata"
        onCloseRequested: metadataDialog.close()

        Item {
            id: metadataContent
            anchors.fill: parent

            PopupContentGeometry {
                id: metadataGeometry
                containerWidth: metadataContent.width
                contentWidth: popupStyle.contentWidth
                leftFieldWidth: popupStyle.leftFieldWidth
                smallFieldWidth: popupStyle.smallFieldWidth
                rightFieldWidth: popupStyle.rightFieldWidth
                fieldGap: popupStyle.fieldGap
            }

            readonly property int fieldHeight: popupStyle.fieldHeight
            readonly property int fieldRadius: popupStyle.fieldRadius
            readonly property int fieldPadX: popupStyle.fieldPadX
            readonly property int areaPadY: popupStyle.areaPadY
            readonly property int labelFontPx: popupStyle.dialogHintFontSize
            readonly property int fieldFontPx: popupStyle.dialogBodyFontSize
            readonly property int sectionLabelFontPx: popupStyle.dialogHintFontSize
            readonly property int labelInsetX: fieldPadX

            readonly property int contentWidth: metadataGeometry.contentWidth
            readonly property int generalX: metadataGeometry.leftX
            readonly property int rightColX: metadataGeometry.col1X
            readonly property int rightCol2X: metadataGeometry.col2X
            readonly property int rightCol3X: metadataGeometry.col3X
            readonly property int contentLeftX: generalX

            readonly property int creditsX: contentLeftX
            readonly property int creditsGap: metadataGeometry.fieldGap
            readonly property int creditsFieldWidth: metadataGeometry.creditsFieldWidth
            readonly property int creditsColStep: metadataGeometry.creditsColStep

            readonly property int storyX: contentLeftX
            readonly property int storyGap: metadataGeometry.fieldGap
            readonly property int storyFieldWidth: metadataGeometry.storyFieldWidth
            readonly property int storyColStep: metadataGeometry.storyColStep

            readonly property int yGeneral: 42
            readonly property int ySeriesLabel: 66
            readonly property int ySeriesField: 87
            readonly property int yTitleLabel: 127
            readonly property int yTitleField: 148
            readonly property int yCredits: 204
            readonly property int yWriterLabel: 228
            readonly property int yWriterField: 249
            readonly property int yLetterLabel: 345
            readonly property int yLetterField: 366
            readonly property int yStoryMeta: 478
            readonly property int yStoryLabel: 502
            readonly property int yStoryField: 523
            readonly property int yButtons: 671

            Label {
                x: metadataContent.generalX + metadataContent.labelInsetX
                y: metadataContent.yGeneral
                text: "General"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.sectionLabelFontPx
            }

            Label {
                x: metadataContent.generalX + metadataContent.labelInsetX
                y: metadataContent.ySeriesLabel
                text: "Series"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            PopupCopyButton {
                x: metadataContent.generalX + popupStyle.leftFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.ySeriesLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editSeriesField)
            }
            PopupTextField {
                id: editSeriesField
                x: metadataContent.generalX
                y: metadataContent.ySeriesField
                width: popupStyle.leftFieldWidth
                height: metadataContent.fieldHeight
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: ""
                clip: true
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editSeriesField, "preserveCase")
            }

            Label {
                x: metadataContent.rightColX + metadataContent.labelInsetX
                y: metadataContent.ySeriesLabel
                text: "Volume"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            PopupTextField {
                id: editVolumeField
                x: metadataContent.rightColX
                y: metadataContent.ySeriesField
                width: popupStyle.smallFieldWidth
                height: metadataContent.fieldHeight
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: ""
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 9999 }
                maximumLength: 4
                clip: true
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
                onTextChanged: metadataDialog.refreshDirtyState()
            }

            Label {
                x: metadataContent.rightCol2X + metadataContent.labelInsetX
                y: metadataContent.ySeriesLabel
                text: "Issue"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            PopupTextField {
                id: editIssueField
                x: metadataContent.rightCol2X
                y: metadataContent.ySeriesField
                width: popupStyle.smallFieldWidth
                height: metadataContent.fieldHeight
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editIssueField, "preserveCase")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label {
                x: metadataContent.rightCol3X + metadataContent.labelInsetX
                y: metadataContent.ySeriesLabel
                text: "Publisher"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            PopupCopyButton {
                x: metadataContent.rightCol3X + popupStyle.rightFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.ySeriesLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editPublisherField)
            }
            PopupTextField {
                id: editPublisherField
                x: metadataContent.rightCol3X
                y: metadataContent.ySeriesField
                width: popupStyle.rightFieldWidth
                height: metadataContent.fieldHeight
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: ""
                clip: true
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editPublisherField, "title")
            }

            Label {
                x: metadataContent.generalX + metadataContent.labelInsetX
                y: metadataContent.yTitleLabel
                text: "Title"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            PopupCopyButton {
                x: metadataContent.generalX + popupStyle.leftFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yTitleLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editTitleField)
            }
            PopupTextField {
                id: editTitleField
                x: metadataContent.generalX
                y: metadataContent.yTitleField
                width: popupStyle.leftFieldWidth
                height: metadataContent.fieldHeight
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editTitleField, "preserveCase")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label {
                x: metadataContent.rightColX + metadataContent.labelInsetX
                y: metadataContent.yTitleLabel
                text: "Year"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            MetadataDropdownField {
                id: editYearCombo
                x: metadataContent.rightColX
                y: metadataContent.yTitleField
                width: popupStyle.smallFieldWidth
                height: metadataContent.fieldHeight
                fieldPadX: metadataContent.fieldPadX
                fieldFontPixelSize: metadataContent.fieldFontPx
                indicatorHitBoxSize: 24
                model: metadataYearOptions
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 9999 }
                onCurrentTextChanged: metadataDialog.refreshDirtyState()
                onActivated: metadataDialog.refreshDirtyState()
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeYearComboValue()
                onAccepted: metadataDialog.normalizeYearComboValue()
            }

            Label {
                x: metadataContent.rightCol2X + metadataContent.labelInsetX
                y: metadataContent.yTitleLabel
                text: "Month"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            MetadataDropdownField {
                id: editMonthCombo
                x: metadataContent.rightCol2X
                y: metadataContent.yTitleField
                width: popupStyle.smallFieldWidth
                height: metadataContent.fieldHeight
                fieldPadX: metadataContent.fieldPadX
                fieldFontPixelSize: metadataContent.fieldFontPx
                indicatorHitBoxSize: 24
                model: metadataMonthOptions
                popupMaxBodyHeight: Math.max(popupMinBodyHeight, popupRowHeight * metadataMonthOptions.length)
                onCurrentTextChanged: metadataDialog.refreshDirtyState()
                onActivated: metadataDialog.refreshDirtyState()
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeMonthComboValue()
                onAccepted: metadataDialog.normalizeMonthComboValue()
            }

            Label {
                x: metadataContent.rightCol3X + metadataContent.labelInsetX
                y: metadataContent.yTitleLabel
                text: "Age rating"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.labelFontPx
            }
            MetadataDropdownField {
                id: editAgeRatingCombo
                x: metadataContent.rightCol3X
                y: metadataContent.yTitleField
                width: popupStyle.rightFieldWidth
                height: metadataContent.fieldHeight
                fieldPadX: metadataContent.fieldPadX
                fieldFontPixelSize: metadataContent.fieldFontPx
                indicatorHitBoxSize: 24
                model: metadataAgeRatingOptions
                onActivated: metadataDialog.refreshDirtyState()
                onCurrentTextChanged: metadataDialog.refreshDirtyState()
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeAgeRatingComboValue()
                onAccepted: metadataDialog.normalizeAgeRatingComboValue()
            }

            Label {
                x: metadataContent.creditsX + metadataContent.labelInsetX
                y: metadataContent.yCredits
                text: "Credits"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.sectionLabelFontPx
            }

            Label { x: metadataContent.creditsX + metadataContent.labelInsetX; y: metadataContent.yWriterLabel; text: "Writer/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yWriterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editWriterField)
            }
            PopupTextArea {
                id: editWriterField
                x: metadataContent.creditsX
                y: metadataContent.yWriterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editWriterField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.creditsX + metadataContent.creditsColStep + metadataContent.labelInsetX; y: metadataContent.yWriterLabel; text: "Penciller/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsColStep + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yWriterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editPencillerField)
            }
            PopupTextArea {
                id: editPencillerField
                x: metadataContent.creditsX + metadataContent.creditsColStep
                y: metadataContent.yWriterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editPencillerField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.creditsX + metadataContent.creditsColStep * 2 + metadataContent.labelInsetX; y: metadataContent.yWriterLabel; text: "Inker/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsColStep * 2 + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yWriterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editInkerField)
            }
            PopupTextArea {
                id: editInkerField
                x: metadataContent.creditsX + metadataContent.creditsColStep * 2
                y: metadataContent.yWriterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editInkerField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.creditsX + metadataContent.creditsColStep * 3 + metadataContent.labelInsetX; y: metadataContent.yWriterLabel; text: "Colorist/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsColStep * 3 + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yWriterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editColoristField)
            }
            PopupTextArea {
                id: editColoristField
                x: metadataContent.creditsX + metadataContent.creditsColStep * 3
                y: metadataContent.yWriterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editColoristField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.creditsX + metadataContent.labelInsetX; y: metadataContent.yLetterLabel; text: "Letter/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yLetterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editLettererField)
            }
            PopupTextArea {
                id: editLettererField
                x: metadataContent.creditsX
                y: metadataContent.yLetterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editLettererField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.creditsX + metadataContent.creditsColStep + metadataContent.labelInsetX; y: metadataContent.yLetterLabel; text: "Cover artist/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsColStep + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yLetterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editCoverArtistField)
            }
            PopupTextArea {
                id: editCoverArtistField
                x: metadataContent.creditsX + metadataContent.creditsColStep
                y: metadataContent.yLetterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editCoverArtistField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.creditsX + metadataContent.creditsColStep * 2 + metadataContent.labelInsetX; y: metadataContent.yLetterLabel; text: "Editor/s"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.creditsX + metadataContent.creditsColStep * 2 + metadataContent.creditsFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yLetterLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editEditorField)
            }
            PopupTextArea {
                id: editEditorField
                x: metadataContent.creditsX + metadataContent.creditsColStep * 2
                y: metadataContent.yLetterField
                width: metadataContent.creditsFieldWidth
                height: 80
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editEditorField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label {
                x: metadataContent.storyX + metadataContent.labelInsetX
                y: metadataContent.yStoryMeta
                text: "Story & meta"
                color: popupStyle.textColor
                font.pixelSize: metadataContent.sectionLabelFontPx
            }

            Label { x: metadataContent.storyX + metadataContent.labelInsetX; y: metadataContent.yStoryLabel; text: "Story arc"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.storyX + metadataContent.storyFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yStoryLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editStoryArcField)
            }
            PopupTextArea {
                id: editStoryArcField
                x: metadataContent.storyX
                y: metadataContent.yStoryField
                width: metadataContent.storyFieldWidth
                height: 132
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editStoryArcField, "title")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            Label { x: metadataContent.storyX + metadataContent.storyColStep + metadataContent.labelInsetX; y: metadataContent.yStoryLabel; text: "Characters"; color: popupStyle.textColor; font.pixelSize: metadataContent.labelFontPx }
            PopupCopyButton {
                x: metadataContent.storyX + metadataContent.storyColStep + metadataContent.storyFieldWidth - popupStyle.copyIconRightInset - popupStyle.copyIconSize
                y: metadataContent.yStoryLabel + popupStyle.copyIconTopOffset
                popupStyle: popupStyle
                onClicked: metadataDialog.copyControlText(editCharactersField)
            }
            PopupTextArea {
                id: editCharactersField
                x: metadataContent.storyX + metadataContent.storyColStep
                y: metadataContent.yStoryField
                width: metadataContent.storyFieldWidth
                height: 132
                leftPadding: metadataContent.fieldPadX
                rightPadding: metadataContent.fieldPadX
                topPadding: metadataContent.areaPadY
                bottomPadding: metadataContent.areaPadY
                font.pixelSize: metadataContent.fieldFontPx
                color: popupStyle.textColor
                wrapMode: TextEdit.Wrap
                placeholderText: ""
                clip: true
                onTextChanged: metadataDialog.refreshDirtyState()
                onActiveFocusChanged: if (!activeFocus) metadataDialog.normalizeTextControl(editCharactersField, "nameList")
                cornerRadius: metadataContent.fieldRadius
                fillColor: popupStyle.fieldFillColor
            }

            FocusEdgeLine { targetItem: editSeriesField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editVolumeField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editIssueField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editPublisherField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editTitleField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editYearCombo; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editMonthCombo; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editAgeRatingCombo; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editWriterField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editPencillerField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editInkerField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editColoristField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editLettererField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editCoverArtistField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editEditorField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editStoryArcField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
            FocusEdgeLine { targetItem: editCharactersField; cornerRadius: metadataContent.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }

            PopupInlineErrorMessage {
                visible: metadataDialog.errorText.length > 0
                headline: "Save failed"
                message: metadataDialog.errorText
                textColor: popupStyle.textColor
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: metadataContent.generalX + metadataContent.labelInsetX
                anchors.rightMargin: popupStyle.footerSideMargin
                anchors.bottom: metadataFooter.top
                anchors.bottomMargin: 10
            }

            PopupFooterRow {
                id: metadataFooter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: popupStyle.footerBottomMargin
                horizontalPadding: popupStyle.footerSideMargin
                spacing: popupStyle.footerButtonSpacing

                PopupActionButton {
                    id: metadataSaveButton
                    height: popupStyle.footerButtonHeight
                    minimumWidth: popupStyle.footerButtonMinWidth
                    horizontalPadding: popupStyle.footerButtonHorizontalPadding
                    cornerRadius: popupStyle.footerButtonRadius
                    idleColor: popupStyle.footerButtonIdleColor
                    hoverColor: popupStyle.footerButtonHoverColor
                    textColor: popupStyle.textColor
                    textPixelSize: popupStyle.footerButtonTextSize
                    text: "Save"
                    enabled: metadataDialog.metadataDirty
                    onClicked: metadataDialog.saveRequested(metadataDialog.currentState())
                }

                PopupActionButton {
                    id: metadataResetButton
                    height: popupStyle.footerButtonHeight
                    minimumWidth: popupStyle.footerButtonMinWidth
                    horizontalPadding: popupStyle.footerButtonHorizontalPadding
                    cornerRadius: popupStyle.footerButtonRadius
                    idleColor: popupStyle.footerButtonIdleColor
                    hoverColor: popupStyle.footerButtonHoverColor
                    textColor: popupStyle.textColor
                    textPixelSize: popupStyle.footerButtonTextSize
                    text: "Reset"
                    enabled: metadataDialog.metadataDirty
                    onClicked: metadataDialog.resetRequested()
                }

                PopupActionButton {
                    id: metadataCancelButton
                    height: popupStyle.footerButtonHeight
                    minimumWidth: popupStyle.footerButtonMinWidth
                    horizontalPadding: popupStyle.footerButtonHorizontalPadding
                    cornerRadius: popupStyle.footerButtonRadius
                    idleColor: popupStyle.footerButtonIdleColor
                    hoverColor: popupStyle.footerButtonHoverColor
                    textColor: popupStyle.textColor
                    textPixelSize: popupStyle.footerButtonTextSize
                    text: "Cancel"
                    onClicked: metadataDialog.close()
                }

            }

        }
    }
}







