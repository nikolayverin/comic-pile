import QtQuick
import QtQuick.Controls
import "MetadataTextUtils.js" as MetadataTextUtils
import "PublisherCatalog.js" as PublisherCatalog
import "AppText.js" as AppText

Popup {
    id: seriesMetaDialog

    ThemeColors { id: themeColors }
    PopupCloseBehavior {
        id: closeBehavior
        closePolicy: seriesMetaDialog.closePolicy
    }

    modal: false
    focus: true
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    x: Math.round((hostWidth - width) / 2)
    y: Math.round((hostHeight - height) / 2)
    width: popupStyle.seriesMetadataWidth
    height: popupStyle.seriesMetadataHeight
    padding: 0

    property real hostWidth: 0
    property real hostHeight: 0
    property color dangerColor: themeColors.dangerColor
    property string dialogMode: "single"
    property var yearOptions: []
    property var monthOptions: []
    property var ageRatingOptions: []
    property var effectiveAgeRatingOptions: []
    property var publisherOptions: PublisherCatalog.majorPublisherNames()
    property var effectivePublisherOptions: []
    property var genreOptions: [
        "Action",
        "Adventure",
        "Comedy",
        "Crime",
        "Drama",
        "Fantasy",
        "Horror",
        "Mystery",
        "Romance",
        "Sci-Fi",
        "Slice of Life",
        "Superhero",
        "Suspense",
        "Thriller",
        "War",
        "Western"
    ]
    property var effectiveGenreOptions: []
    property string errorText: ""
    property string previewErrorText: ""
    property string pendingFocusField: ""
    property string textLanguage: AppText.fallbackLanguageCode
    readonly property bool bulkMode: dialogMode === "bulk"
    readonly property bool mergeMode: dialogMode === "merge"
    readonly property bool volumeEditable: !bulkMode && !mergeMode
    readonly property string inlineErrorText: errorText.length > 0 ? errorText : previewErrorText
    readonly property bool dropdownPopupVisible: seriesMetaGenresField.popupVisible
        || seriesMetaPublisherField.popupVisible
        || seriesMetaYearField.popupVisible
        || seriesMetaMonthCombo.popupVisible
        || seriesMetaAgeRatingCombo.popupVisible

    property alias seriesField: seriesMetaSeriesField
    property alias titleField: seriesMetaTitleField
    property alias volumeField: seriesMetaVolumeField
    property alias publisherField: seriesMetaPublisherField
    property alias yearField: seriesMetaYearField
    property alias monthCombo: seriesMetaMonthCombo
    property alias ageRatingCombo: seriesMetaAgeRatingCombo
    property alias genresField: seriesMetaGenresField
    property alias summaryField: seriesMetaSummaryField

    signal saveRequested()
    signal cancelRequested()

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: seriesMetaDialog.visible && !seriesMetaDialog.dropdownPopupVisible
        onActivated: seriesMetaDialog.cancelRequested()
    }

    PopupStyle { id: popupStyle }

    background: PopupSurface {
        cornerRadius: popupStyle.popupRadius
        fillColor: popupStyle.popupFillColor
        edgeColor: popupStyle.edgeLineColor
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
        } else if (mode === "sentence") {
            normalized = MetadataTextUtils.normalizeSentenceText(source)
        }
        if (String(control.text || "") !== normalized) {
            control.text = normalized
        }
    }

    function normalizeYearField() {
        const normalizedYear = MetadataTextUtils.normalizeYearText(seriesMetaYearField.editText || seriesMetaYearField.currentText)
        yearOptions = buildYearOptions(normalizedYear)
        seriesMetaYearField.currentIndex = yearOptions.indexOf(normalizedYear)
        seriesMetaYearField.editText = normalizedYear
    }

    function normalizeMonthComboValue() {
        const normalizedMonth = MetadataTextUtils.normalizeMonthName(
            seriesMetaMonthCombo.editText || seriesMetaMonthCombo.currentText,
            monthOptions
        )
        const monthIdx = monthOptions.indexOf(normalizedMonth)
        seriesMetaMonthCombo.currentIndex = monthIdx
        seriesMetaMonthCombo.editText = normalizedMonth
    }

    function normalizeAgeRatingComboValue() {
        const normalizedAge = MetadataTextUtils.normalizeChoiceText(
            seriesMetaAgeRatingCombo.editText || seriesMetaAgeRatingCombo.currentText,
            ageRatingOptions
        )
        effectiveAgeRatingOptions = buildAgeRatingOptions(normalizedAge)
        seriesMetaAgeRatingCombo.currentIndex = effectiveAgeRatingOptions.indexOf(normalizedAge)
        seriesMetaAgeRatingCombo.editText = normalizedAge
    }

    function normalizePublisherComboValue() {
        const normalizedPublisher = resolvePublisherText(
            seriesMetaPublisherField.editText || seriesMetaPublisherField.currentText
        )
        effectivePublisherOptions = buildPublisherOptions(normalizedPublisher)
        seriesMetaPublisherField.currentIndex = effectivePublisherOptions.indexOf(normalizedPublisher)
        seriesMetaPublisherField.editText = normalizedPublisher
    }

    function normalizeGenreComboValue() {
        const normalizedGenre = MetadataTextUtils.normalizeChoiceText(
            seriesMetaGenresField.editText || seriesMetaGenresField.currentText,
            genreOptions
        )
        effectiveGenreOptions = buildGenreOptions(normalizedGenre)
        seriesMetaGenresField.currentIndex = effectiveGenreOptions.indexOf(normalizedGenre)
        seriesMetaGenresField.editText = normalizedGenre
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
        const list = Array.isArray(ageRatingOptions) ? ageRatingOptions.slice(0) : []
        const normalizedCurrent = String(currentAgeRating || "").trim()
        if (normalizedCurrent.length > 0 && list.indexOf(normalizedCurrent) < 0) {
            list.unshift(normalizedCurrent)
        }
        return list
    }

    function buildPublisherOptions(currentPublisher) {
        const list = Array.isArray(publisherOptions) ? publisherOptions.slice(0) : []
        const normalizedCurrent = resolvePublisherText(currentPublisher)
        if (normalizedCurrent.length > 0 && list.indexOf(normalizedCurrent) < 0) {
            list.unshift(normalizedCurrent)
        }
        return list
    }

    function buildGenreOptions(currentGenre) {
        const list = Array.isArray(genreOptions) ? genreOptions.slice(0) : []
        const normalizedCurrent = String(currentGenre || "").trim()
        if (normalizedCurrent.length > 0 && list.indexOf(normalizedCurrent) < 0) {
            list.unshift(normalizedCurrent)
        }
        return list
    }

    function resolvePublisherText(value) {
        const matchedText = MetadataTextUtils.normalizeChoiceText(value, publisherOptions)
        const canonicalText = String(PublisherCatalog.canonicalPublisherName(matchedText) || "").trim()
        if (canonicalText.length > 0) return canonicalText
        return MetadataTextUtils.normalizeTitleText(matchedText)
    }

    function prepareDropdownState(yearText, ageText, genreText, publisherText) {
        yearOptions = buildYearOptions(yearText)
        effectiveAgeRatingOptions = buildAgeRatingOptions(ageText)
        effectivePublisherOptions = buildPublisherOptions(publisherText)
        effectiveGenreOptions = buildGenreOptions(genreText)
    }

    function labelColor(active) {
        return active ? popupStyle.textColor : popupStyle.subtleTextColor
    }

    function fieldTextColor(active) {
        return active ? popupStyle.textColor : popupStyle.subtleTextColor
    }

    function fieldOpacity(active) {
        return active ? 1.0 : 0.58
    }

    function localizedText(key) {
        return AppText.t(key, seriesMetaDialog.textLanguage)
    }

    function focusTextInput(control) {
        if (!control || typeof control.forceActiveFocus !== "function") return
        control.forceActiveFocus()
        if (typeof control.cursorPosition === "number") {
            control.cursorPosition = String(control.text || "").length
        } else if (typeof control.selectAll === "function") {
            control.selectAll()
        }
    }

    function applyRequestedFocus() {
        const fieldKey = String(pendingFocusField || "").trim().toLowerCase()
        if (fieldKey.length < 1) return

        Qt.callLater(function() {
            if (!seriesMetaDialog.visible) return
            if (fieldKey === "summary") {
                focusTextInput(seriesMetaSummaryField)
            } else if (fieldKey === "year") {
                if (typeof seriesMetaYearField.focusInput === "function") {
                    seriesMetaYearField.focusInput()
                }
            } else if (fieldKey === "volume") {
                focusTextInput(seriesMetaVolumeField)
            } else if (fieldKey === "publisher") {
                if (typeof seriesMetaPublisherField.focusInput === "function") {
                    seriesMetaPublisherField.focusInput()
                }
            } else if (fieldKey === "genres") {
                if (typeof seriesMetaGenresField.focusInput === "function") {
                    seriesMetaGenresField.focusInput()
                }
            } else if (fieldKey === "series") {
                focusTextInput(seriesMetaSeriesField)
            } else if (fieldKey === "series_title") {
                focusTextInput(seriesMetaTitleField)
            } else if (fieldKey === "month") {
                if (typeof seriesMetaMonthCombo.focusInput === "function") {
                    seriesMetaMonthCombo.focusInput()
                }
            } else if (fieldKey === "age_rating") {
                if (typeof seriesMetaAgeRatingCombo.focusInput === "function") {
                    seriesMetaAgeRatingCombo.focusInput()
                }
            }
        })
    }

    onOpened: applyRequestedFocus()

    contentItem: PopupDialogShell {
        id: shell
        popupStyle: popupStyle
        title: seriesMetaDialog.mergeMode
            ? seriesMetaDialog.localizedText("seriesMetaTitleMerge")
            : (seriesMetaDialog.bulkMode
                ? seriesMetaDialog.localizedText("seriesMetaTitleBulk")
                : seriesMetaDialog.localizedText("seriesMetaTitleSingle"))
        onCloseRequested: seriesMetaDialog.cancelRequested()

        PopupContentGeometry {
            id: seriesMetaGeometry
            containerWidth: shell.bodyHost.width
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
        readonly property int labelInsetX: fieldPadX

        readonly property int contentWidth: seriesMetaGeometry.contentWidth
        readonly property int generalX: seriesMetaGeometry.leftX
        readonly property int rightColX: seriesMetaGeometry.col1X
        readonly property int rightCol2X: seriesMetaGeometry.col2X
        readonly property int rightCol3X: seriesMetaGeometry.col3X
        readonly property int summaryWidth: contentWidth

        readonly property int yGeneral: popupStyle.formSectionTop
        readonly property int ySeriesLabel: yGeneral + popupStyle.formSectionToLabelGap
        readonly property int ySeriesField: ySeriesLabel + popupStyle.formLabelToFieldGap
        readonly property int yTitleLabel: ySeriesField + popupStyle.formFieldBlockGap
        readonly property int yTitleField: yTitleLabel + popupStyle.formLabelToFieldGap
        readonly property int ySummaryLabel: yTitleField + popupStyle.formFieldBlockGap
        readonly property int ySummaryField: ySummaryLabel + popupStyle.formLabelToFieldGap
        readonly property int yButtons: ySummaryField + popupStyle.seriesMetadataSummaryHeight + popupStyle.formFooterTopGap

        Label {
            x: shell.generalX + shell.labelInsetX
            y: shell.yGeneral
            text: seriesMetaDialog.localizedText("seriesMetaSectionGeneral")
            color: popupStyle.textColor
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        Label {
            x: shell.generalX + shell.labelInsetX
            y: shell.ySeriesLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelSeries")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.bulkMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        PopupCopyButton {
            x: shell.generalX + popupStyle.leftFieldWidth - popupStyle.copyIconRightInset - width
            y: shell.ySeriesLabel + popupStyle.copyIconTopOffset
            popupStyle: popupStyle
            enabled: !seriesMetaDialog.bulkMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.bulkMode)
            onClicked: seriesMetaDialog.copyControlText(seriesMetaSeriesField)
        }

        PopupTextField {
            id: seriesMetaSeriesField
            x: shell.generalX
            y: shell.ySeriesField
            width: popupStyle.leftFieldWidth
            height: shell.fieldHeight
            leftPadding: shell.fieldPadX
            rightPadding: shell.fieldPadX
            font.pixelSize: popupStyle.dialogBodyFontSize
            color: seriesMetaDialog.fieldTextColor(!seriesMetaDialog.bulkMode)
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: ""
            clip: true
            cornerRadius: shell.fieldRadius
            fillColor: popupStyle.fieldFillColor
            enabled: !seriesMetaDialog.bulkMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.bulkMode)
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeTextControl(seriesMetaSeriesField, "preserveCase")
        }

        Label {
            x: shell.rightColX + shell.labelInsetX
            y: shell.ySeriesLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelVolume")
            color: seriesMetaDialog.labelColor(seriesMetaDialog.volumeEditable)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        PopupTextField {
            id: seriesMetaVolumeField
            x: shell.rightColX
            y: shell.ySeriesField
            width: popupStyle.smallFieldWidth
            height: shell.fieldHeight
            leftPadding: shell.fieldPadX
            rightPadding: shell.fieldPadX
            font.pixelSize: popupStyle.dialogBodyFontSize
            color: seriesMetaDialog.fieldTextColor(seriesMetaDialog.volumeEditable)
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: ""
            clip: true
            cornerRadius: shell.fieldRadius
            fillColor: popupStyle.fieldFillColor
            enabled: seriesMetaDialog.volumeEditable
            opacity: seriesMetaDialog.fieldOpacity(seriesMetaDialog.volumeEditable)
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeTextControl(seriesMetaVolumeField, "preserveCase")
        }

        Label {
            x: shell.rightCol2X + shell.labelInsetX
            y: shell.ySeriesLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelGenres")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        MetadataDropdownField {
            id: seriesMetaGenresField
            x: shell.rightCol2X
            y: shell.ySeriesField
            width: popupStyle.smallFieldWidth
            height: shell.fieldHeight
            fieldPadX: shell.fieldPadX
            fieldFontPixelSize: popupStyle.dialogBodyFontSize
            indicatorHitBoxSize: 24
            model: seriesMetaDialog.effectiveGenreOptions
            popupMaxBodyHeight: Math.max(popupMinBodyHeight, popupRowHeight * seriesMetaDialog.effectiveGenreOptions.length)
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onTextChanged: seriesMetaDialog.errorText = ""
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeGenreComboValue()
            onAccepted: seriesMetaDialog.normalizeGenreComboValue()
        }

        Label {
            x: shell.rightCol3X + shell.labelInsetX
            y: shell.ySeriesLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelPublisher")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        PopupCopyButton {
            x: shell.rightCol3X + popupStyle.rightFieldWidth - popupStyle.copyIconRightInset - width
            y: shell.ySeriesLabel + popupStyle.copyIconTopOffset
            popupStyle: popupStyle
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onClicked: seriesMetaDialog.copyControlText(seriesMetaPublisherField)
        }

        MetadataDropdownField {
            id: seriesMetaPublisherField
            x: shell.rightCol3X
            y: shell.ySeriesField
            width: popupStyle.rightFieldWidth
            height: shell.fieldHeight
            fieldPadX: shell.fieldPadX
            fieldFontPixelSize: popupStyle.dialogBodyFontSize
            indicatorHitBoxSize: 24
            model: seriesMetaDialog.effectivePublisherOptions
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onTextChanged: seriesMetaDialog.errorText = ""
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizePublisherComboValue()
            onAccepted: seriesMetaDialog.normalizePublisherComboValue()
        }

        Label {
            x: shell.generalX + shell.labelInsetX
            y: shell.yTitleLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelSeriesTitle")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        PopupCopyButton {
            x: shell.generalX + popupStyle.leftFieldWidth - popupStyle.copyIconRightInset - width
            y: shell.yTitleLabel + popupStyle.copyIconTopOffset
            popupStyle: popupStyle
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onClicked: seriesMetaDialog.copyControlText(seriesMetaTitleField)
        }

        PopupTextField {
            id: seriesMetaTitleField
            x: shell.generalX
            y: shell.yTitleField
            width: popupStyle.leftFieldWidth
            height: shell.fieldHeight
            leftPadding: shell.fieldPadX
            rightPadding: shell.fieldPadX
            font.pixelSize: popupStyle.dialogBodyFontSize
            color: seriesMetaDialog.fieldTextColor(!seriesMetaDialog.mergeMode)
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: ""
            clip: true
            cornerRadius: shell.fieldRadius
            fillColor: popupStyle.fieldFillColor
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeTextControl(seriesMetaTitleField, "preserveCase")
        }

        Label {
            x: shell.rightColX + shell.labelInsetX
            y: shell.yTitleLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelYear")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        MetadataDropdownField {
            id: seriesMetaYearField
            x: shell.rightColX
            y: shell.yTitleField
            width: popupStyle.smallFieldWidth
            height: shell.fieldHeight
            fieldPadX: shell.fieldPadX
            fieldFontPixelSize: popupStyle.dialogBodyFontSize
            indicatorHitBoxSize: 24
            model: seriesMetaDialog.yearOptions
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: 9999 }
            maximumLength: 4
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onTextChanged: seriesMetaDialog.errorText = ""
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeYearField()
            onAccepted: seriesMetaDialog.normalizeYearField()
        }

        Label {
            x: shell.rightCol2X + shell.labelInsetX
            y: shell.yTitleLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelMonth")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        MetadataDropdownField {
            id: seriesMetaMonthCombo
            x: shell.rightCol2X
            y: shell.yTitleField
            width: popupStyle.smallFieldWidth
            height: shell.fieldHeight
            fieldPadX: shell.fieldPadX
            fieldFontPixelSize: popupStyle.dialogBodyFontSize
            indicatorHitBoxSize: 24
            model: seriesMetaDialog.monthOptions
            popupMaxBodyHeight: Math.max(popupMinBodyHeight, popupRowHeight * seriesMetaDialog.monthOptions.length)
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onTextChanged: seriesMetaDialog.errorText = ""
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeMonthComboValue()
            onAccepted: seriesMetaDialog.normalizeMonthComboValue()
        }

        Label {
            x: shell.rightCol3X + shell.labelInsetX
            y: shell.yTitleLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelAgeRating")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        MetadataDropdownField {
            id: seriesMetaAgeRatingCombo
            x: shell.rightCol3X
            y: shell.yTitleField
            width: popupStyle.rightFieldWidth
            height: shell.fieldHeight
            fieldPadX: shell.fieldPadX
            fieldFontPixelSize: popupStyle.dialogBodyFontSize
            indicatorHitBoxSize: 24
            model: seriesMetaDialog.effectiveAgeRatingOptions
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onTextChanged: seriesMetaDialog.errorText = ""
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeAgeRatingComboValue()
            onAccepted: seriesMetaDialog.normalizeAgeRatingComboValue()
        }

        Label {
            x: shell.generalX + shell.labelInsetX
            y: shell.ySummaryLabel
            text: seriesMetaDialog.localizedText("seriesMetaLabelSummary")
            color: seriesMetaDialog.labelColor(!seriesMetaDialog.mergeMode)
            font.pixelSize: popupStyle.dialogHintFontSize
        }

        PopupCopyButton {
            x: shell.generalX + shell.summaryWidth - popupStyle.copyIconRightInset - width
            y: shell.ySummaryLabel + popupStyle.copyIconTopOffset
            popupStyle: popupStyle
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onClicked: seriesMetaDialog.copyControlText(seriesMetaSummaryField)
        }

        PopupTextArea {
            id: seriesMetaSummaryField
            x: shell.generalX
            y: shell.ySummaryField
            width: shell.summaryWidth
            height: popupStyle.seriesMetadataSummaryHeight
            leftPadding: shell.fieldPadX
            rightPadding: shell.fieldPadX
            topPadding: shell.areaPadY
            bottomPadding: shell.areaPadY
            font.pixelSize: popupStyle.dialogBodyFontSize
            color: seriesMetaDialog.fieldTextColor(!seriesMetaDialog.mergeMode)
            wrapMode: TextEdit.Wrap
            placeholderText: ""
            clip: true
            cornerRadius: shell.fieldRadius
            fillColor: popupStyle.fieldFillColor
            enabled: !seriesMetaDialog.mergeMode
            opacity: seriesMetaDialog.fieldOpacity(!seriesMetaDialog.mergeMode)
            onActiveFocusChanged: if (!activeFocus) seriesMetaDialog.normalizeTextControl(seriesMetaSummaryField, "sentence")
        }

        FocusEdgeLine { targetItem: seriesMetaSeriesField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaVolumeField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaGenresField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaPublisherField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaTitleField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaYearField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaMonthCombo; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaAgeRatingCombo; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }
        FocusEdgeLine { targetItem: seriesMetaSummaryField; cornerRadius: shell.fieldRadius; lineColor: popupStyle.edgeLineColor; edge: "bottom" }

        PopupInlineErrorMessage {
            visible: seriesMetaDialog.inlineErrorText.length > 0
            headline: seriesMetaDialog.localizedText("seriesMetaInlineErrorHeadline")
            message: seriesMetaDialog.inlineErrorText
            textColor: popupStyle.textColor
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: shell.generalX + shell.labelInsetX
            anchors.rightMargin: popupStyle.footerSideMargin
            anchors.bottom: seriesMetaFooter.top
            anchors.bottomMargin: 10
        }

        PopupFooterRow {
            id: seriesMetaFooter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: popupStyle.footerBottomMargin
            horizontalPadding: popupStyle.footerSideMargin
            spacing: popupStyle.footerButtonSpacing

            PopupActionButton {
                height: popupStyle.footerButtonHeight
                minimumWidth: popupStyle.footerButtonMinWidth
                horizontalPadding: popupStyle.footerButtonHorizontalPadding
                cornerRadius: popupStyle.footerButtonRadius
                idleColor: popupStyle.footerButtonIdleColor
                hoverColor: popupStyle.footerButtonHoverColor
                textColor: popupStyle.textColor
                textPixelSize: popupStyle.footerButtonTextSize
                text: seriesMetaDialog.mergeMode
                    ? seriesMetaDialog.localizedText("seriesMetaButtonMerge")
                    : seriesMetaDialog.localizedText("seriesMetaButtonSave")
                onClicked: seriesMetaDialog.saveRequested()
            }

            PopupActionButton {
                height: popupStyle.footerButtonHeight
                minimumWidth: popupStyle.footerButtonMinWidth
                horizontalPadding: popupStyle.footerButtonHorizontalPadding
                cornerRadius: popupStyle.footerButtonRadius
                idleColor: popupStyle.footerButtonIdleColor
                hoverColor: popupStyle.footerButtonHoverColor
                textColor: popupStyle.textColor
                textPixelSize: popupStyle.footerButtonTextSize
                text: seriesMetaDialog.localizedText("commonCancel")
                onClicked: seriesMetaDialog.cancelRequested()
            }

        }
    }
}


