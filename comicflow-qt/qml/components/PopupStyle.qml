import QtQuick

QtObject {
    readonly property QtObject typography: Typography {}
    readonly property QtObject themeColors: ThemeColors {}

    readonly property int issueMetadataWidth: 910
    readonly property int issueMetadataHeight: 708
    readonly property int seriesMetadataWidth: 930
    readonly property int seriesMetadataHeight: 392
    readonly property int seriesHeaderWidth: 930
    readonly property int seriesHeaderHeight: 390

    readonly property int popupRadius: 18
    readonly property color overlayColor: themeColors.overlayColor
    readonly property color popupFillColor: themeColors.popupFillColor
    readonly property color edgeLineColor: themeColors.edgeLineColor

    readonly property color textColor: themeColors.textPrimary
    readonly property color fieldFillColor: themeColors.fieldFillColor
    readonly property color hintTextColor: themeColors.hintTextColor
    readonly property color subtleTextColor: themeColors.subtleTextColor
    readonly property color errorTextColor: themeColors.errorTextColor
    readonly property color sectionBorderColor: themeColors.sectionBorderColor
    readonly property color comboIndicatorColor: themeColors.comboIndicatorColor

    readonly property int fieldHeight: 24
    readonly property int fieldRadius: 12
    readonly property int fieldPadX: 12
    readonly property int areaPadY: 10
    readonly property int contentWidth: 872
    readonly property int leftFieldWidth: 370
    readonly property int smallFieldWidth: 110
    readonly property int rightFieldWidth: 234
    readonly property int fieldGap: 16

    readonly property int closeButtonSize: 24
    readonly property int closeGlyphSize: typography.closeGlyphPx
    readonly property int closeTopMargin: 8
    readonly property int closeRightMargin: 8
    readonly property color closeHoverBgColor: themeColors.closeHoverBgColor

    readonly property int copyIconSize: 10
    readonly property int copyIconTopOffset: 4
    readonly property int copyIconRightInset: 12
    readonly property color copyIconIdleColor: themeColors.copyIconIdleColor
    readonly property color copyIconHoverColor: themeColors.copyIconHoverColor

    readonly property int footerButtonHeight: 20
    readonly property int footerButtonRadius: 10
    readonly property int footerButtonTextSize: typography.uiBasePx
    readonly property int footerButtonHorizontalPadding: 18
    readonly property int footerButtonMinWidth: 76
    readonly property int footerButtonSpacing: 6
    readonly property int footerBottomMargin: 16
    readonly property int footerSideMargin: 24
    readonly property color footerButtonIdleColor: themeColors.footerButtonIdleColor
    readonly property color footerButtonHoverColor: themeColors.footerButtonHoverColor

    readonly property int actionResultWidth: 520
    readonly property int confirmDialogMinHeight: 138
    readonly property int actionResultMinHeight: confirmDialogMinHeight
    readonly property int importConflictWidth: 760
    readonly property int importConflictMinHeight: confirmDialogMinHeight
    readonly property int seriesDeleteWidth: 348
    readonly property int seriesDeleteHeight: 138
    readonly property int deleteConfirmWidth: 420
    readonly property int deleteConfirmMinHeight: confirmDialogMinHeight
    readonly property int deleteErrorWidth: 460
    readonly property int deleteErrorMinHeight: confirmDialogMinHeight
    readonly property int failedImportsMaxWidth: 900
    readonly property int failedImportsHintReserveWidth: 420
    readonly property int failedImportsTextReserveWidth: 360
    readonly property int failedImportsCounterReserveWidth: 44
    readonly property int importProgressWidth: 454
    readonly property color importProgressBarColor: themeColors.importProgressBarColor

    readonly property int dialogHeaderTopMargin: 16
    readonly property int dialogBodyTopMargin: formSectionTop
    readonly property int dialogSideMargin: 24
    readonly property int dialogBottomMargin: 16
    readonly property int dialogBodySpacing: 14
    readonly property int dialogPlainTextSpacing: 14
    readonly property int dialogInfoBlockSpacing: 8
    readonly property int dialogContentSpacing: 16
    readonly property int dialogControlRowSpacing: 8
    readonly property int dialogInlineMetricGap: 12
    readonly property int dialogCardRadius: 12
    readonly property int dialogCardPadding: 10
    readonly property int dialogCardRowSpacing: 8
    readonly property int formSectionTop: 42
    readonly property int formSectionToLabelGap: 24
    readonly property int formLabelToFieldGap: 21
    readonly property int formFieldBlockGap: 40
    readonly property int formFooterTopGap: 16
    readonly property int seriesMetadataSummaryHeight: 112
    readonly property int importProgressRightInfoWidth: 72
    readonly property int importProgressBarHeight: 10
    readonly property int dialogTitleFontSize: typography.dialogTitlePx
    readonly property int dialogBodyFontSize: typography.dialogBodyPx
    readonly property int dialogBodyEmphasisFontSize: typography.dialogBodyEmphasisPx
    readonly property int dialogHintFontSize: typography.dialogHintPx
    readonly property int errorTextFontSize: typography.uiBasePx
}
