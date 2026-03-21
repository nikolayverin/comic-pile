import QtQuick

QtObject {
    // Current dark-theme token source.
    // Values are copied from the live UI as-is and are not a redesign.

    readonly property string themeMode: "dark"

    readonly property QtObject surface: QtObject {
        readonly property color app: "#000000"
        readonly property color sidebarStart: "#292929"
        readonly property color sidebarEnd: "#191919"
        readonly property color topbarStart: "#303030"
        readonly property color topbarEnd: "#191919"
        readonly property color topbarEdge: "#0c0c0c"
        readonly property color bottombarStart: "#212121"
        readonly property color bottombarEnd: "#191919"
        readonly property color content: "#191919"
        readonly property color hero: "#0e0e0e"
        readonly property color card: "#222222"
        readonly property color menu: "#0b0b0b"
        readonly property color popup: "#252525"
        readonly property color field: "#000000"
        readonly property color readerViewport: "#0f0f0f"
        readonly property color heroCoverPlaceholder: "#080808"
        readonly property color footerButtonIdle: "#1c1c1c"
        readonly property color hoverAction: "#2e2e2e"
        readonly property color errorBanner: "#3c1515"
        readonly property color warningBanner: "#3b2b12"
        readonly property color statusChip: "#1b1b1b"
        readonly property color settingsPreviewCard: "#434343"
        readonly property color settingsSidebarPanel: "#1c1c1c"
        readonly property color settingsPreviewDefault: "#151515"
        readonly property color settingsPreviewDefaultTop: "#121212"
        readonly property color settingsPreviewTexture: "#191919"
        readonly property color settingsPreviewCustom: "#111111"
        readonly property color paletteBase: "#222222"
        readonly property color paletteButton: "#2a2a2a"
        readonly property color paletteMid: "#3a3a3a"
        readonly property color paletteDark: "#161616"
    }

    readonly property QtObject text: QtObject {
        readonly property color primary: "#ffffff"
        readonly property color muted: "#6c6a6a"
        readonly property color placeholder: "#707070"
        readonly property color menuPrimary: "#f2f2f2"
        readonly property color menuDisabled: "#7a7a7a"
        readonly property color menuIdle: "#949494"
        readonly property color hint: "#b0b0b0"
        readonly property color subtle: "#9a9a9a"
        readonly property color error: "#fe0024"
        readonly property color loadErrorBanner: "#fca5a5"
        readonly property color dbHealthBanner: "#fcd34d"
        readonly property color dropZone: "#8b8b8b"
        readonly property color comboIndicator: "#ffffff"
        readonly property color copyHover: "#ffffff"
        readonly property color statusChip: "#d4d4d4"
        readonly property color onLight: "#000000"
        readonly property color settingsSidebarIdle: "#f1f1f1"
        readonly property color popupStatusDetail: "#9f9f9f"
    }

    readonly property QtObject border: QtObject {
        readonly property color topbarBottom: "#000000"
        readonly property color sidebarRight: "#2f2f2f"
        readonly property color bottombarTop: "#2f2f2f"
        readonly property color gridEdge: "#2a2a2a"
        readonly property color readerViewport: "#2f2f2f"
        readonly property color readerOverlay: "#353535"
        readonly property color popupEdge: "#878787"
        readonly property color popupSection: "#404040"
        readonly property color menu: "#7d7d7d"
        readonly property color statusChip: "#4a4a4a"
        readonly property color actionHoverEdge: "#525252"
        readonly property color popupActionHoverEdge: "#747474"
    }

    readonly property QtObject state: QtObject {
        readonly property color cardHoverOverlay: "#22ffffff"
        readonly property color cardSelectedOverlay: "#1accff5e"
        readonly property color menuHoverFill: "#252525"
        readonly property color popupCloseHoverFill: "#000000"
        readonly property color footerButtonHoverFill: "#000000"
        readonly property color sidebarRowHoverFill: "#80000000"
        readonly property color sidebarSeriesHoverFill: "#1f000000"
        readonly property color copyIdle: "#777777"
        readonly property color settingsSidebarHoverFill: "#111111"
        readonly property color settingsSidebarSelectedFill: "#000000"
        readonly property color settingsSidebarPressedFill: "#080808"
        readonly property color actionPressedFill: "#101010"
    }

    readonly property QtObject accent: QtObject {
        readonly property color danger: "#b91c1c"
        readonly property color importProgress: "#77d632"
        readonly property color attention: "#b3fe03"
        readonly property color closeHover: "#ff1800"
        readonly property color paletteHighlight: "#496175"
        readonly property color success: "#7ed957"
        readonly property color failure: "#ff3131"
    }

    readonly property QtObject scrim: QtObject {
        readonly property color overlay: "#B3000000"
        readonly property color readerLoadingChip: "#88000000"
        readonly property color readerProgressChip: "#99000000"
    }

    readonly property QtObject shadow: QtObject {
        readonly property color text: "#000000"
    }

    readonly property QtObject control: QtObject {
        readonly property color switchOffKnob: "#252525"
        readonly property color switchOnKnob: "#ccc9c4"
        readonly property color segmentedSelectedFill: "#ccc9c4"
        readonly property color radioSelectedDot: "#ccc9c4"
    }

    // Compatibility aliases for the existing shell palette in Main.qml
    readonly property color bgApp: surface.app
    readonly property color bgSidebarStart: surface.sidebarStart
    readonly property color bgSidebarEnd: surface.sidebarEnd
    readonly property color bgTopbarStart: surface.topbarStart
    readonly property color bgTopbarEnd: surface.topbarEnd
    readonly property color bgBottombarStart: surface.bottombarStart
    readonly property color bgBottombarEnd: surface.bottombarEnd
    readonly property color bgContent: surface.content
    readonly property color bgHeroBase: surface.hero
    readonly property color textPrimary: text.primary
    readonly property color textMuted: text.muted
    readonly property color searchPlaceholder: text.placeholder
    readonly property color paletteBase: surface.paletteBase
    readonly property color paletteButton: surface.paletteButton
    readonly property color paletteMid: surface.paletteMid
    readonly property color paletteDark: surface.paletteDark
    readonly property color paletteHighlight: accent.paletteHighlight
    readonly property color lineTopbarBottom: border.topbarBottom
    readonly property color lineSidebarRight: border.sidebarRight
    readonly property color lineBottombarTop: border.bottombarTop
    readonly property color cardBg: surface.card
    readonly property color cardHoverOverlay: state.cardHoverOverlay
    readonly property color cardSelectedOverlay: state.cardSelectedOverlay
    readonly property color dangerColor: accent.danger
    readonly property color gridEdgeColor: border.gridEdge
    readonly property color uiTextShadow: shadow.text
    readonly property color uiMenuBackground: surface.menu
    readonly property color uiMenuHoverBackground: state.menuHoverFill
    readonly property color uiMenuText: text.menuPrimary
    readonly property color uiMenuTextDisabled: text.menuDisabled
    readonly property color uiMenuIdleText: text.menuIdle
    readonly property color uiWindowControlCloseHover: accent.closeHover
    readonly property color uiActionHoverBackground: surface.hoverAction
    readonly property color sidebarRowHoverColor: state.sidebarRowHoverFill
    readonly property color sidebarSeriesHoverColor: state.sidebarSeriesHoverFill
    readonly property color sidebarQuickFilterHoverColor: state.sidebarRowHoverFill
    readonly property color loadErrorBannerBg: surface.errorBanner
    readonly property color loadErrorBannerText: text.loadErrorBanner
    readonly property color dbHealthBannerBg: surface.warningBanner
    readonly property color dbHealthBannerText: text.dbHealthBanner
    readonly property color dropZoneTextColor: text.dropZone
    readonly property color heroCoverPlaceholderColor: surface.heroCoverPlaceholder
    readonly property color readerViewportBgColor: surface.readerViewport
    readonly property color readerViewportBorderColor: border.readerViewport
    readonly property color readerOverlayBorderColor: border.readerOverlay
    readonly property color readerLoadingChipBgColor: scrim.readerLoadingChip
    readonly property color readerProgressChipBgColor: scrim.readerProgressChip
    readonly property color topbarTopEdgeColor: surface.topbarEdge
    readonly property color topbarWindowControlIdleColor: text.menuIdle
    readonly property color topbarWindowControlActiveColor: text.primary
    readonly property color topbarStatusChipTextColor: text.statusChip
    readonly property color topbarStatusChipBorderColor: border.statusChip
    readonly property color topbarStatusChipFillColor: surface.statusChip

    // Compatibility aliases for popup/menu token packs
    readonly property color overlayColor: scrim.overlay
    readonly property color popupFillColor: surface.popup
    readonly property color edgeLineColor: border.popupEdge
    readonly property color fieldFillColor: surface.field
    readonly property color hintTextColor: text.hint
    readonly property color subtleTextColor: text.subtle
    readonly property color errorTextColor: text.error
    readonly property color sectionBorderColor: border.popupSection
    readonly property color comboIndicatorColor: text.comboIndicator
    readonly property color closeHoverBgColor: state.popupCloseHoverFill
    readonly property color copyIconIdleColor: state.copyIdle
    readonly property color copyIconHoverColor: text.copyHover
    readonly property color footerButtonIdleColor: surface.footerButtonIdle
    readonly property color footerButtonHoverColor: state.footerButtonHoverFill
    readonly property color importProgressBarColor: accent.importProgress
    readonly property color backgroundColor: surface.menu
    readonly property color borderColor: border.menu
    readonly property color hoverColor: state.menuHoverFill
    readonly property color textColor: text.menuPrimary
    readonly property color disabledTextColor: text.menuDisabled
    readonly property color scrollThumbColor: text.primary
    readonly property color settingsChoiceTextColor: text.primary
    readonly property color settingsChoiceFillColor: surface.field
    readonly property color settingsCheckboxFillColor: surface.field
    readonly property color settingsCheckboxCheckColor: text.primary
    readonly property color settingsSwitchTrackColor: surface.field
    readonly property color settingsSwitchOffKnobColor: control.switchOffKnob
    readonly property color settingsSwitchOnKnobColor: control.switchOnKnob
    readonly property color settingsSegmentedTrackColor: surface.field
    readonly property color settingsSegmentedSelectedFillColor: control.segmentedSelectedFill
    readonly property color settingsSegmentedSelectedTextColor: text.onLight
    readonly property color settingsSegmentedIdleTextColor: text.primary
    readonly property color settingsRadioTextColor: text.primary
    readonly property color settingsRadioIndicatorColor: surface.field
    readonly property color settingsRadioSelectedDotColor: control.radioSelectedDot
    readonly property color settingsBackgroundChoiceBodyColor: surface.settingsPreviewCard
    readonly property color settingsBackgroundChoiceBorderColor: border.menu
    readonly property color settingsSidebarHoverColor: state.settingsSidebarHoverFill
    readonly property color settingsSidebarSelectedColor: state.settingsSidebarSelectedFill
    readonly property color settingsSidebarPressedColor: state.settingsSidebarPressedFill
    readonly property color settingsSidebarHoverEdgeColor: border.gridEdge
    readonly property color settingsSidebarSelectedEdgeColor: border.topbarBottom
    readonly property color settingsSidebarPanelColor: surface.settingsSidebarPanel
    readonly property color settingsSidebarIdleTextColor: text.settingsSidebarIdle
    readonly property color settingsContextPanelBodyColor: surface.settingsPreviewCard
    readonly property color settingsContextPanelShadowColor: shadow.text
    readonly property color settingsPreviewDefaultColor: surface.settingsPreviewDefault
    readonly property color settingsPreviewDefaultTopColor: surface.settingsPreviewDefaultTop
    readonly property color settingsPreviewTextureColor: surface.settingsPreviewTexture
    readonly property color settingsPreviewCustomColor: surface.settingsPreviewCustom
    readonly property color popupActionHoverEdgeColor: border.actionHoverEdge
    readonly property color popupPrimaryActionHoverEdgeColor: border.popupActionHoverEdge
    readonly property color popupActionPressedColor: state.actionPressedFill
    readonly property color popupActionPressedEdgeColor: border.topbarBottom
    readonly property color dialogAttentionColor: accent.attention
    readonly property color popupStatusDetailTextColor: text.popupStatusDetail
    readonly property color popupSuccessColor: accent.success
    readonly property color popupFailureColor: accent.failure
}
