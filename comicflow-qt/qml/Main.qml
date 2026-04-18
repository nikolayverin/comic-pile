import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "components/AppText.js" as AppText
import "components/PublisherCatalog.js" as PublisherCatalog
import "components/SettingsCatalog.js" as SettingsCatalog
import "components/AppErrorMapper.js" as AppErrorMapper
import "components/SeriesContext.js" as SeriesContext
import "controllers"

ApplicationWindow {
    id: root
    width: windowDisplayController.defaultWindowWidth
    height: windowDisplayController.defaultWindowHeight
    minimumWidth: windowDisplayController.displayConstrainedWindow ? 1 : windowDisplayController.defaultWindowWidth
    minimumHeight: windowDisplayController.displayConstrainedWindow ? 1 : windowDisplayController.defaultWindowHeight
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint
    title: root.windowTitleLabel
    color: root.bgApp

    property string uiFontFamily: interFont.status === FontLoader.Ready ? interFont.name : "Inter"
    font.family: root.uiFontFamily
    font.pointSize: root.fontPtBase
    palette.windowText: root.textPrimary
    palette.buttonText: root.textPrimary
    palette.text: root.textPrimary
    palette.placeholderText: root.searchPlaceholder
    palette.window: root.bgContent
    palette.base: root.paletteBase
    palette.button: root.paletteButton
    palette.mid: root.paletteMid
    palette.dark: root.paletteDark
    palette.highlight: root.paletteHighlight

    FontLoader {
        id: interFont
        source: uiTokens.interFontPath
    }

    UiTokens { id: uiTokens }
    Typography { id: uiTypography }
    ThemeColors { id: themeColors }
    PopupStyle { id: popupStyleTokens }
    AppSettingsController { id: appSettingsController }
    MainStartupState {
        id: startupState
        launchStartedAtMs: Number(appLaunchStartedAtMs || 0)
    }

    readonly property bool fastDevBuild: Boolean(appIsFastDevBuild)
    readonly property string buildIterationLabel: String(appBuildIteration || "").trim()
    readonly property string devBuildBadgeText: fastDevBuild && buildIterationLabel.length > 0
        ? "DEV " + buildIterationLabel
        : ""
    readonly property string topBarCenterLabel: devBuildBadgeText.length > 0
        ? (uiTokens.appTitle + "  " + devBuildBadgeText)
        : uiTokens.appTitle
    readonly property string windowTitleLabel: devBuildBadgeText.length > 0
        ? (uiTokens.appWindowTitle + " [" + devBuildBadgeText + "]")
        : uiTokens.appWindowTitle

    readonly property string libraryBackgroundMode: String(appSettingsController.appearanceLibraryBackground || "Default")
    readonly property color libraryBackgroundSolidColor: appSettingsController.appearanceLibraryBackgroundSolidColor
    readonly property string libraryBackgroundTexturePreset: String(
        appSettingsController.appearanceLibraryBackgroundTexture
            || SettingsCatalog.defaultAppearanceLibraryBackgroundTexture
    )
    readonly property string libraryBackgroundCustomImageStoredPath: String(
        appSettingsController.appearanceLibraryBackgroundCustomImagePath || ""
    )
    readonly property string libraryBackgroundCustomImageResolvedPath: String(
        resolveLibraryBackgroundStoredPath(libraryBackgroundCustomImageStoredPath) || ""
    )
    readonly property string libraryBackgroundCustomImageMode: String(
        appSettingsController.appearanceLibraryBackgroundImageMode || "Fill"
    )
    readonly property string libraryBackgroundCustomImageSource: String(
        startupController.toLocalFileUrl(libraryBackgroundCustomImageResolvedPath) || ""
    )
    readonly property string libraryBackgroundTileSizeLabel: String(
        appSettingsController.appearanceLibraryBackgroundTileSize || "64x64px"
    )
    readonly property int libraryBackgroundTilePixelSize: libraryBackgroundTileSizeLabel === "512x512px"
        ? 512
        : libraryBackgroundTileSizeLabel === "256x256px"
            ? 256
            : 64
    readonly property bool libraryShowHeroBlock: Boolean(appSettingsController.appearanceShowHeroBlock)
    readonly property string libraryGridDensity: String(appSettingsController.appearanceGridDensity || "Default")
    readonly property bool readerShowBookmarkRibbonOnGridCovers: Boolean(
        appSettingsController.readerShowBookmarkRibbonOnGridCovers
    )
    readonly property string libraryTextureSource: SettingsCatalog.appearanceTextureSource(
        libraryBackgroundTexturePreset
    )
    readonly property int libraryTextureTilePixelSize: SettingsCatalog.appearanceTextureTilePixelSize(
        libraryBackgroundTexturePreset
    )
    readonly property int libraryBackgroundImageMaxBytes: 8 * 1024 * 1024
    readonly property int libraryBackgroundTileImageMaxBytes: 1 * 1024 * 1024

    property color bgApp: themeColors.bgApp
    property color bgSidebarStart: themeColors.bgSidebarStart
    property color bgSidebarEnd: themeColors.bgSidebarEnd
    property color bgTopbarStart: themeColors.bgTopbarStart
    property color bgTopbarEnd: themeColors.bgTopbarEnd
    property color bgBottombarStart: themeColors.bgBottombarStart
    property color bgBottombarEnd: themeColors.bgBottombarEnd
    property color bgContent: themeColors.bgContent
    property color bgHeroBase: themeColors.bgHeroBase
    property color textPrimary: themeColors.textPrimary
    property color textMuted: themeColors.textMuted
    property color lineTopbarBottom: themeColors.lineTopbarBottom
    property color lineSidebarRight: themeColors.lineSidebarRight
    property color lineBottombarTop: themeColors.lineBottombarTop
    property color searchPlaceholder: themeColors.searchPlaceholder
    property color paletteBase: themeColors.paletteBase
    property color paletteButton: themeColors.paletteButton
    property color paletteMid: themeColors.paletteMid
    property color paletteDark: themeColors.paletteDark
    property color paletteHighlight: themeColors.paletteHighlight
    property color cardBg: themeColors.cardBg
    property color cardHoverOverlay: themeColors.cardHoverOverlay
    property color cardSelectedOverlay: themeColors.cardSelectedOverlay
    property color dangerColor: themeColors.dangerColor
    property color gridEdgeColor: themeColors.gridEdgeColor
    property color uiTextShadow: themeColors.uiTextShadow
    property color uiMenuBackground: themeColors.uiMenuBackground
    property color uiMenuHoverBackground: themeColors.uiMenuHoverBackground
    property color uiMenuText: themeColors.uiMenuText
    property color uiMenuTextDisabled: themeColors.uiMenuTextDisabled
    property color uiMenuIdleText: themeColors.uiMenuIdleText
    property color uiWindowControlCloseHover: themeColors.uiWindowControlCloseHover
    property color uiActionHoverBackground: themeColors.uiActionHoverBackground
    property color topBarInnerShadowColor: "#555555"
    property color bottomBarInnerShadowColor: "#000000"
    property color sidebarRowHoverColor: themeColors.sidebarRowHoverColor
    property color loadErrorBannerBg: themeColors.loadErrorBannerBg
    property color loadErrorBannerText: themeColors.loadErrorBannerText
    property color dbHealthBannerBg: themeColors.dbHealthBannerBg
    property color dbHealthBannerText: themeColors.dbHealthBannerText
    property color dropZoneTextColor: themeColors.dropZoneTextColor
    property color heroCoverPlaceholderColor: themeColors.heroCoverPlaceholderColor
    property color readerViewportBgColor: themeColors.readerViewportBgColor
    property color readerViewportBorderColor: themeColors.readerViewportBorderColor
    property color readerOverlayBorderColor: themeColors.readerOverlayBorderColor
    property color readerLoadingChipBgColor: themeColors.readerLoadingChipBgColor
    property color readerProgressChipBgColor: themeColors.readerProgressChipBgColor
    property real gridTileOpacity: 0.72
    property int fontUiPrimary: uiTypography.uiBasePx
    property int fontUiMuted: uiTypography.uiMutedPx
    property int fontUiSmall: uiTypography.uiSmallPx
    property int fontUiHeading: uiTypography.uiHeadingPx
    property int fontPtBase: uiTypography.uiBasePt
    property int fontPxUiBase: uiTypography.uiBasePx
    property int fontPxDropTitle: uiTypography.dropTitlePx
    property int fontPxDropSubtitle: uiTypography.dropSubtitlePx
    property int sidebarGradientHeight: 760
    property int heroBlockHeight: 360
    property int gridNotchWidth: 54
    property int gridNotchDepth: 26
    property int spaceXs: 4
    property int spaceSm: 8
    property int spaceMd: 12
    property int spaceLg: 16
    property int radiusSm: 6
    property int radiusMd: 10
    property int radiusLg: 18
    property int windowCornerRadius: 14
    property int motionFastMs: 120
    property int motionBaseMs: 180
    property int motionSlowMs: 260
    property real shadowSoftOpacity: 0.28
    property real shadowHeavyOpacity: 0.45

    property var selectedIds: ({})
    property alias actionResultMessage: popupController.actionResultMessage
    property alias pendingDeleteId: deleteController.pendingDeleteId
    property alias deleteErrorHeadline: deleteController.deleteErrorHeadline
    property alias deleteErrorReasonText: deleteController.deleteErrorReasonText
    property alias deleteErrorDetailsText: deleteController.deleteErrorDetailsText
    property alias deleteErrorSystemText: deleteController.deleteErrorSystemText
    property alias deleteErrorRawText: deleteController.deleteErrorRawText
    property alias deleteErrorPrimaryPath: deleteController.deleteErrorPrimaryPath
    property alias deleteErrorFailedPaths: deleteController.deleteErrorFailedPaths
    property alias deleteRetryMode: deleteController.deleteRetryMode
    property alias deleteRetryComicId: deleteController.deleteRetryComicId
    property alias deleteRetrySeriesKeys: deleteController.deleteRetrySeriesKeys
    property alias deleteRetryInProgress: deleteController.deleteRetryInProgress
    property alias deleteRetryStatusText: deleteController.deleteRetryStatusText
    property alias editingComic: metadataDialogController.editingComic
    property alias editingSeriesKey: metadataDialogController.editingSeriesKey
    property alias editingSeriesKeys: metadataDialogController.editingSeriesKeys
    property alias editingSeriesTitle: metadataDialogController.editingSeriesTitle
    property alias editingSeriesDialogMode: metadataDialogController.editingSeriesDialogMode
    property alias pendingSeriesMetadataSuggestion: metadataDialogController.pendingSeriesMetadataSuggestion
    property alias pendingIssueMetadataSuggestion: metadataDialogController.pendingIssueMetadataSuggestion
    readonly property var importModalOverlay: mainDialogHost.importModalOverlayRef
    readonly property var importConflictDialog: mainDialogHost.importConflictDialogRef
    readonly property var seriesDeleteConfirmDialog: mainDialogHost.seriesDeleteConfirmDialogRef
    readonly property var failedImportsDialog: mainDialogHost.failedImportsDialogRef
    readonly property var metadataDialog: mainDialogHost.metadataDialogRef
    readonly property var readerDialog: mainDialogHost.readerDialogRef
    readonly property var actionResultDialog: mainDialogHost.actionResultDialogRef
    readonly property var issueMetadataAutofillConfirmDialog: mainDialogHost.issueMetadataAutofillConfirmDialogRef
    readonly property var seriesMetadataAutofillConfirmDialog: mainDialogHost.seriesMetadataAutofillConfirmDialogRef
    readonly property var readerDeletePageConfirmDialog: mainDialogHost.readerDeletePageConfirmDialogRef
    readonly property var replaceSourceChoiceDialog: mainDialogHost.replaceSourceChoiceDialogRef
    readonly property var seriesMetaDialog: mainDialogHost.seriesMetaDialogRef
    readonly property var settingsDialog: mainDialogHost.settingsDialogRef
    readonly property var helpDialog: mainDialogHost.helpDialogRef
    readonly property var aboutDialog: mainDialogHost.aboutDialogRef
    readonly property var updateAvailableDialog: mainDialogHost.updateAvailableDialogRef
    readonly property var whatsNewDialog: mainDialogHost.whatsNewDialogRef
    property string startupDeferredUpdatePromptVersion: ""
    readonly property var seriesHeaderDialog: mainDialogHost.seriesHeaderDialogRef
    readonly property var deleteConfirmDialog: mainDialogHost.deleteConfirmDialogRef
    readonly property var deleteErrorDialog: mainDialogHost.deleteErrorDialogRef
    readonly property var seriesMetaSeriesField: mainDialogHost.seriesMetaSeriesField
    readonly property var seriesMetaTitleField: mainDialogHost.seriesMetaTitleField
    readonly property var seriesMetaVolumeField: mainDialogHost.seriesMetaVolumeField
    readonly property var seriesMetaGenresField: mainDialogHost.seriesMetaGenresField
    readonly property var seriesMetaPublisherField: mainDialogHost.seriesMetaPublisherField
    readonly property var seriesMetaYearField: mainDialogHost.seriesMetaYearField
    readonly property var seriesMetaMonthCombo: mainDialogHost.seriesMetaMonthCombo
    readonly property var seriesMetaAgeRatingCombo: mainDialogHost.seriesMetaAgeRatingCombo
    readonly property var seriesMetaSummaryField: mainDialogHost.seriesMetaSummaryField
    property var readStatusOptions: ["unread", "in_progress", "read"]
    property var seriesMetaMonthOptions: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    property var seriesMetaAgeRatingOptions: ["All ages", "6+", "12+", "13+", "15+", "16+", "18+"]
    property int readerComicId: -1
    property string readerTitle: ""
    property int readerPageIndex: 0
    property int readerPageCount: 0
    property string readerImageSource: ""
    property var readerDisplayPages: []
    property string readerError: ""
    property bool readerLoading: false
    property bool readerFinalizing: false
    property int readerSessionRequestId: -1
    property int readerPageRequestId: -1
    property var readerPrefetchRequestIds: ({})
    property bool readerUiFullscreen: false
    property bool readerBookmarkActive: false
    property int readerBookmarkPageIndex: -1
    property int readerBookmarkComicId: -1
    property bool readerFavoriteActive: false
    property int pendingDeleteReaderPageComicId: -1
    property int pendingDeleteReaderPageIndex: -1
    property int pendingReplaceArchiveComicId: -1
    property string pendingReplaceArchiveSourcePath: ""
    property string pendingReplaceArchiveSourceType: "archive"
    property bool replaceArchiveOperationActive: false
    property string replaceArchiveOperationStatusText: "Replacing issue source..."
    property string readerViewMode: "one_page"
    property bool readerMangaModeEnabled: false
    property bool readerMangaSpreadOffsetEnabled: false
    property string readerSeriesKey: ""
    readonly property int readerIssueIndexInSeries: readerSessionController.issueIndexInSeries
    readonly property int readerIssueCountInSeries: readerSessionController.issueCountInSeries
    readonly property bool readerHasPreviousIssue: readerIssueIndexInSeries > 0
    readonly property bool readerHasNextIssue: readerIssueIndexInSeries >= 0
        && readerIssueIndexInSeries + 1 < readerIssueCountInSeries
    readonly property bool readerCanGoPreviousPage: readerSessionController.canGoPreviousPage
    readonly property bool readerCanGoNextPage: readerSessionController.canGoNextPage
    property alias selectedSeriesKey: libraryBrowseController.selectedSeriesKey
    property alias selectedSeriesTitle: libraryBrowseController.selectedSeriesTitle
    readonly property var selectedSeriesContext: libraryBrowseController.selectedSeriesContext
    property alias selectedSeriesKeys: seriesSelectionController.selectedSeriesKeys
    property alias seriesSelectionAnchorIndex: seriesSelectionController.seriesSelectionAnchorIndex
    property alias selectedVolumeKey: libraryBrowseController.selectedVolumeKey
    property alias selectedVolumeTitle: libraryBrowseController.selectedVolumeTitle
    property alias continueReadingComicId: readingContinuationController.continueReadingComicId
    property alias continueReadingSeriesKey: readingContinuationController.continueReadingSeriesKey
    property alias pendingSeriesKey: deleteController.pendingSeriesKey
    property alias pendingSeriesTitle: deleteController.pendingSeriesTitle
    property alias pendingSeriesKeys: deleteController.pendingSeriesKeys
    property alias pendingSeriesIssueCount: deleteController.pendingSeriesIssueCount
    property int sidebarWidth: 320
    property int topBarHeight: 70
    property int footerHeight: 56
    property int sidebarSeriesFadeHeight: 128
    property int sidebarSeriesBottomSafeOffset: 24
    property int sidebarSeriesListBottomGap: 16
    property var coverByComicId: ({})
    property int heroCoverComicId: -1
    property string heroAutoCoverSource: ""
    property var heroAutoCoverStateBySeriesKey: ({})
    property string heroBackgroundSource: ""
    property string heroCustomCoverSource: ""
    property string heroCustomBackgroundSource: ""
    property string heroBackgroundSeriesKey: ""
    property int heroBackgroundRequestId: -1
    property var heroSeriesData: ({
        seriesTitle: "",
        summary: "-",
        year: "-",
        volume: "-",
        publisher: "-",
        genres: "-",
        logoSource: ""
    })
    property bool addFilesDropActive: false
    property alias sidebarSearchText: libraryBrowseController.sidebarSearchText
    property alias sidebarQuickFilterKey: libraryBrowseController.sidebarQuickFilterKey
    property alias lastImportSessionComicIds: libraryBrowseController.lastImportSessionComicIds
    property alias quickFilterLastImportCount: libraryBrowseController.quickFilterLastImportCount
    property alias quickFilterFavoritesCount: libraryBrowseController.quickFilterFavoritesCount
    property alias quickFilterBookmarksCount: libraryBrowseController.quickFilterBookmarksCount
    readonly property var activeIssuesFlick: (typeof mainLibraryPane !== "undefined" && mainLibraryPane)
        ? mainLibraryPane.activeIssuesFlick
        : null
    property alias librarySearchText: libraryBrowseController.librarySearchText
    property alias libraryReadStatusFilter: libraryBrowseController.libraryReadStatusFilter
    property bool gridSplitScrollRestorePending: false
    property real pendingGridSplitScrollValue: 0
    property alias libraryLoading: libraryBrowseController.libraryLoading
    property bool cbrBackendAvailable: false
    property string cbrBackendMissingMessage: ""
    property string libraryDataRootPath: String(libraryModel.dataRoot || "")
    property string libraryFolderPath: childPath(libraryDataRootPath, "Library")
    property string libraryRuntimeFolderPath: childPath(libraryDataRootPath, ".runtime")
    property string pendingLibraryDataRelocationPath: String(libraryModel.pendingDataRootRelocationPath() || "")
    property var importSeriesKeysBeforeBatch: ({})
    property bool importFocusNewSeriesAfterReload: false
    property string pendingImportPostReloadAction: ""
    property bool pendingConfiguredLaunchViewApply: true
    property string lastPresentedLibraryLoadError: ""
    property bool libraryBackgroundImageMigrationInProgress: false
    property bool firstRunOnboardingActive: false
    property int firstRunOnboardingStep: 1
    readonly property int firstRunSidebarHighlightX: Math.round((root.sidebarWidth - root.firstRunDropZoneHighlightWidth) / 2)
    readonly property int firstRunStep1HighlightY: Math.round(
        root.height
        - root.footerHeight
        - root.firstRunDropZoneBottomMargin
        - ((root.firstRunDropZoneHeight - root.firstRunDropZoneStep1HighlightHeight) / 2)
        - root.firstRunDropZoneStep1HighlightHeight
    )
    readonly property int firstRunStep2HighlightHeightAdaptive: Math.max(0, firstRunStep1HighlightY - root.topBarHeight)
    readonly property int firstRunDropZoneWidth: 274
    readonly property int firstRunDropZoneHeight: 173
    readonly property int firstRunDropZoneBottomMargin: 19
    readonly property int firstRunDropZoneHighlightWidth: 318
    readonly property int firstRunDropZoneStep1HighlightHeight: 212
    readonly property int firstRunDropZoneStep2HighlightHeight: 654
    readonly property int firstRunStep3HighlightWidth: 1122
    readonly property int firstRunStep3HighlightHeight: 362
    readonly property int firstRunStep3BubbleOffsetFromHeroTop: 362
    readonly property int firstRunStep4HighlightWidth: 1122
    readonly property int firstRunStep4HighlightHeight: 494
    readonly property int firstRunStep5BubbleLeftMargin: 65
    readonly property int firstRunStep5BubbleTopMargin: 84
    readonly property int firstRunStep5TopBubbleOffsetX: -324
    readonly property int firstRunStep5BottomBubbleBottomGap: -2
    readonly property int firstRunStep5NavOffsetXFromBubbleLeft: 243
    readonly property int firstRunStep5NavBottomInsetFromBubbleBottom: 59
    readonly property int firstRunStep5NavLift: 106
    readonly property int firstRunStep5CloseOffsetXFromBubbleLeft: 771
    readonly property int firstRunStep5CloseBottomInsetFromBubbleBottom: 384
    readonly property int firstRunDropZoneHighlightRadius: 20

    StartupController {
        id: startupController
        rootObject: root
        libraryModelRef: libraryModel
        heroSeriesControllerRef: heroSeriesController
        windowDisplayControllerRef: windowDisplayController
        appContentLayout: appContentLayout
        seriesListModel: seriesListModel
        seriesListView: mainSidebar.seriesListViewRef
        issuesFlick: root.activeIssuesFlick
    }

    WindowDisplayController {
        id: windowDisplayController
        rootObject: root
        startupControllerRef: startupController
    }

    ReaderCoverController {
        id: readerCoverController
        rootObject: root
        libraryModelRef: libraryModel
        popupControllerRef: popupController
        readerDialog: root.readerDialog
        appSettingsRef: appSettingsController
        issuesFlick: root.activeIssuesFlick
    }

    ReaderSessionController {
        id: readerSessionController
        rootObject: root
        readerCoverControllerRef: readerCoverController
    }

    HeroSeriesController {
        id: heroSeriesController
        rootObject: root
        libraryModelRef: libraryModel
        readerCoverControllerRef: readerCoverController
        startupControllerRef: startupController
        uiTokensRef: uiTokens
    }

    ImportController {
        id: importController
        rootObject: root
        libraryModelRef: libraryModel
        popupControllerRef: popupController
        importConflictDialogRef: importConflictDialog
        failedImportsDialogRef: failedImportsDialog
        failedImportItemsModelRef: failedImportItemsModel
    }

    DeleteController {
        id: deleteController
        rootObject: root
        libraryModelRef: libraryModel
        popupControllerRef: popupController
        seriesListModelRef: seriesListModel
        appSettingsRef: appSettingsController
        deleteConfirmDialogRef: deleteConfirmDialog
        deleteErrorDialogRef: deleteErrorDialog
        seriesDeleteConfirmDialogRef: seriesDeleteConfirmDialog
    }

    SeriesHeaderController {
        id: seriesHeaderController
        rootObject: root
        libraryModelRef: libraryModel
        heroSeriesControllerRef: heroSeriesController
        popupControllerRef: popupController
        startupControllerRef: startupController
        seriesHeaderDialogRef: seriesHeaderDialog
    }

    ReadingContinuationController {
        id: readingContinuationController
        rootObject: root
        libraryModelRef: libraryModel
    }

    LibraryBrowseController {
        id: libraryBrowseController
        rootObject: root
        libraryModelRef: libraryModel
        startupControllerRef: startupController
        navigationSurfaceControllerRef: navigationSurfaceController
        readerCoverControllerRef: readerCoverController
        heroSeriesControllerRef: heroSeriesController
        uiTokensRef: uiTokens
        seriesListModelRef: seriesListModel
        volumeListModelRef: volumeListModel
        mainLibraryPaneRef: mainLibraryPane
        issuesGridRefreshDebounceRef: issuesGridRefreshDebounce
    }

    SeriesSelectionController {
        id: seriesSelectionController
        rootObject: root
        seriesListModelRef: seriesListModel
        mainLibraryPaneRef: mainLibraryPane
    }

    MetadataDialogController {
        id: metadataDialogController
        rootObject: root
        libraryModelRef: libraryModel
        popupControllerRef: popupController
        startupControllerRef: startupController
        heroSeriesControllerRef: heroSeriesController
    }

    PopupController {
        id: popupController
        rootObject: root
        importControllerRef: importController
        deleteControllerRef: deleteController
        importModalOverlayRef: importModalOverlay
        importConflictDialogRef: importConflictDialog
        seriesDeleteConfirmDialogRef: seriesDeleteConfirmDialog
        failedImportsDialogRef: failedImportsDialog
        metadataDialogRef: metadataDialog
        readerDialogRef: readerDialog
        actionResultDialogRef: actionResultDialog
        seriesMetaDialogRef: seriesMetaDialog
        settingsDialogRef: settingsDialog
        helpDialogRef: helpDialog
        aboutDialogRef: aboutDialog
        updateAvailableDialogRef: updateAvailableDialog
        whatsNewDialogRef: whatsNewDialog
        replaceSourceChoiceDialogRef: replaceSourceChoiceDialog
        seriesHeaderDialogRef: seriesHeaderDialog
        deleteConfirmDialogRef: deleteConfirmDialog
        deleteErrorDialogRef: deleteErrorDialog
    }

    NavigationSurfaceController {
        id: navigationSurfaceController
        rootObject: root
        libraryModelRef: libraryModel
        popupControllerRef: popupController
        issuesFlick: root.activeIssuesFlick
        readingContinuationControllerRef: readingContinuationController
    }

    property string sevenZipConfiguredPath: ""
    property string sevenZipEffectivePath: ""
    property alias criticalPopupAttentionTarget: popupController.criticalPopupAttentionTarget
    property color criticalPopupAttentionColor: themeColors.dialogAttentionColor
    property alias importInProgress: importController.importInProgress
    readonly property bool anyManagedModalPopupVisible: popupController.anyManagedModalPopupVisible
    readonly property bool anyCriticalPopupVisible: popupController.anyCriticalPopupVisible
    readonly property bool backgroundModalLockActive: anyManagedModalPopupVisible
    readonly property bool backgroundUiInteractive: !backgroundModalLockActive
    property alias importTotal: importController.importTotal
    property alias importProcessed: importController.importProcessed
    property alias importTotalBytes: importController.importTotalBytes
    property alias importProcessedBytes: importController.importProcessedBytes
    property alias importImportedCount: importController.importImportedCount
    property alias importErrorCount: importController.importErrorCount
    property alias importCancelRequested: importController.importCancelRequested
    property alias importLifecycleState: importController.importLifecycleState
    property alias importCurrentPath: importController.importCurrentPath
    property alias importCurrentFileName: importController.importCurrentFileName
    readonly property bool importCleanupActive: importController.importCleanupActive
    property alias importCleanupTotalCount: importController.importCleanupTotalCount
    property alias importCleanupProcessedCount: importController.importCleanupProcessedCount
    property alias importCleanupCurrentFileName: importController.importCleanupCurrentFileName
    property alias importPausedForConflict: importController.importPausedForConflict
    property alias importConflictContext: importController.importConflictContext
    property alias importConflictNextContext: importController.importConflictNextContext
    property alias importConflictExistingLabel: importController.importConflictExistingLabel
    property alias importConflictIncomingLabel: importController.importConflictIncomingLabel
    property alias importConflictNextExistingLabel: importController.importConflictNextExistingLabel
    property alias importConflictNextIncomingLabel: importController.importConflictNextIncomingLabel
    property alias importConflictBatchAction: importController.importConflictBatchAction
    property alias importConflictBatchDuplicateCount: importController.importConflictBatchDuplicateCount
    property alias importConflictOperationActive: importController.importConflictOperationActive
    property alias importConflictPendingAction: importController.importConflictPendingAction
    property alias importConflictProgressCurrentFileName: importController.importConflictProgressCurrentFileName
    property alias importConflictProgressProcessedCount: importController.importConflictProgressProcessedCount
    property alias importConflictProgressTotalCount: importController.importConflictProgressTotalCount
    readonly property real importConflictProgressFraction: importController.importConflictProgressFraction
    property int seriesMenuDismissToken: 0
    property alias importQueue: importController.importQueue
    property alias lastFailedImportPaths: importController.lastFailedImportPaths
    property alias lastFailedImportErrors: importController.lastFailedImportErrors
    property bool gridOverlayMenusSuppressed: false
    property int gridOverlayMenuPostScrollDelayMs: 180
    property var issuesGridData: []
    property alias startupLoadDelayMs: startupState.startupLoadDelayMs
    property alias startupInitialReconcileSettleDelayMs: startupState.startupInitialReconcileSettleDelayMs
    property alias startupPrimaryContentRevealDelayMs: startupState.startupPrimaryContentRevealDelayMs
    property alias startupInventoryCheckDelayMs: startupState.startupInventoryCheckDelayMs
    property alias startupHydrationRetryDelayMs: startupState.startupHydrationRetryDelayMs
    property alias startupHydrationMaxDeferredAttempts: startupState.startupHydrationMaxDeferredAttempts
    property alias restoringStartupSnapshot: startupState.restoringStartupSnapshot
    property alias startupSnapshotApplied: startupState.startupSnapshotApplied
    property alias startupSnapshotSeriesContentY: startupState.startupSnapshotSeriesContentY
    property alias startupSnapshotIssuesContentY: startupState.startupSnapshotIssuesContentY
    property alias startupSnapshotVersion: startupState.startupSnapshotVersion
    property alias startupSnapshotMaxSeries: startupState.startupSnapshotMaxSeries
    property alias startupSnapshotMaxIssues: startupState.startupSnapshotMaxIssues
    property alias startupSnapshotLiveReloadRequested: startupState.startupSnapshotLiveReloadRequested
    property bool suspendSidebarSearchRefresh: false
    property bool modelReconcilePending: false
    property bool suspendSelectionDrivenRefresh: false
    property bool selectionDrivenRefreshQueued: false
    property string settledSelectionSeriesKey: ""
    property string settledSelectionSeriesTitle: ""
    property string settledSelectionVolumeKey: "__all__"
    property string settledSelectionVolumeTitle: AppText.libraryAllVolumes
    property alias startupReconcileCompleted: startupState.startupReconcileCompleted
    property alias startupHydrationInProgress: startupState.startupHydrationInProgress
    property alias startupAwaitingFirstModelSignal: startupState.startupAwaitingFirstModelSignal
    property alias startupHydrationAttemptCount: startupState.startupHydrationAttemptCount
    property alias startupDebugLogsEnabled: startupState.startupDebugLogsEnabled
    property alias startupStartedAtMs: startupState.startupStartedAtMs
    property alias launchStartedAtMs: startupState.launchStartedAtMs
    property alias startupFirstStatusSignalReceived: startupState.startupFirstStatusSignalReceived
    property alias startupResultLogged: startupState.startupResultLogged
    property alias startupFirstFrameSource: startupState.startupFirstFrameSource
    property alias startupInventorySignature: startupState.startupInventorySignature
    property alias startupPendingInventorySignature: startupState.startupPendingInventorySignature
    property alias startupInventoryCheckRequestId: startupState.startupInventoryCheckRequestId
    property alias startupInventoryCheckInProgress: startupState.startupInventoryCheckInProgress
    property alias startupInventoryRebuildInProgress: startupState.startupInventoryRebuildInProgress
    property var pendingReaderProgressSaveByComicId: ({})
    property var pendingReaderProgressSaveOrder: []
    property int readerProgressSaveRetryDelayMs: 180
    property alias startupColdRenderLoggedFlags: startupState.startupColdRenderLoggedFlags
    property alias startupPreviewPath: startupState.startupPreviewPath
    property alias startupPreviewPrimaryPath: startupState.startupPreviewPrimaryPath
    property alias startupPreviewFallbackPath: startupState.startupPreviewFallbackPath
    property alias startupPreviewSource: startupState.startupPreviewSource
    property alias startupPreviewTriedFallback: startupState.startupPreviewTriedFallback
    property alias startupPreviewMaxLongSide: startupState.startupPreviewMaxLongSide
    property alias startupPreviewOverlayEnabled: startupState.startupPreviewOverlayEnabled
    property alias showStartupPreview: startupState.showStartupPreview
    property alias startupPrimaryContentReady: startupState.startupPrimaryContentReady
    readonly property bool startupPrimaryContentVisible: startupState.startupPrimaryContentVisible
    property alias startupClosingAfterPreview: startupState.startupClosingAfterPreview
    property alias startupCloseSeq: startupState.startupCloseSeq
    property alias startupCloseRequestedAtMs: startupState.startupCloseRequestedAtMs
    property alias startupDbHealthWarningVisible: startupState.startupDbHealthWarningVisible
    property alias startupDbHealthWarningMessage: startupState.startupDbHealthWarningMessage
    property alias startupDbHealthWarningCode: startupState.startupDbHealthWarningCode
    property alias startupDbHealthRequestId: startupState.startupDbHealthRequestId

    component PointerButton: Button {
        hoverEnabled: true
        HoverHandler {
            acceptedDevices: PointerDevice.Mouse
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    onXChanged: windowDisplayController.handleWindowXChanged()

    onYChanged: windowDisplayController.handleWindowYChanged()

    onWidthChanged: windowDisplayController.handleWindowWidthChanged()

    onHeightChanged: windowDisplayController.handleWindowHeightChanged()

    onVisibleChanged: windowDisplayController.handleWindowVisibleChanged()

    onVisibilityChanged: windowDisplayController.handleWindowVisibilityChanged()

    function setReaderWindowFullscreen(enabled) {
        const nextValue = Boolean(enabled)
        windowDisplayController.setReaderFullscreenMode(nextValue)
        readerUiFullscreen = nextValue
    }

    function markStartupColdRenderOnce(key, details) {
        const token = String(key || "").trim()
        if (token.length < 1) return
        const flags = Object.assign({}, startupColdRenderLoggedFlags)
        if (flags[token] === true) return
        flags[token] = true
        startupColdRenderLoggedFlags = flags
        let message = "COLD_RENDER_" + token.toUpperCase()
        const detailsText = String(details || "").trim()
        if (detailsText.length > 0) {
            message += " " + detailsText
        }
        startupController.startupLog(message)
    }

    function runtimeDebugLog(category, message) {
        const tag = String(category || "").trim()
        const text = String(message || "").trim()
        if (tag.length < 1 || text.length < 1) return
        const startupTextLogsEnabled = libraryModel
            && typeof libraryModel.startupTextLogsEnabled === "function"
            && libraryModel.startupTextLogsEnabled()
        if (!startupDebugLogsEnabled && !startupTextLogsEnabled) return
        if (!libraryModel || typeof libraryModel.appendStartupDebugLog !== "function") return
        libraryModel.appendStartupDebugLog("[" + tag + "] " + text)
    }

    function isSelected(id) {
        return selectedIds[String(id)] === true
    }

    function setSelected(id, checked) {
        const key = String(id)
        const next = Object.assign({}, selectedIds)
        if (checked) {
            next[key] = true
        } else {
            delete next[key]
        }
        selectedIds = next
    }

    function clearSelection() {
        selectedIds = ({})
    }

    function rememberContinueReadingTarget(comicId, seriesKey, displayTitle, persistState) {
        readingContinuationController.rememberContinueReadingTarget(
            comicId,
            seriesKey,
            displayTitle,
            persistState
        )
    }

    function coverSourceForComic(comicId) {
        return readerCoverController.coverSourceForComic(comicId)
    }

    function setCoverSource(comicId, source) {
        readerCoverController.setCoverSource(comicId, source)
    }

    function maxNormalizedGridScrollValue() {
        if (!activeIssuesFlick) return 0
        const topMargin = Number(activeIssuesFlick.topMargin || 0)
        const bottomMargin = Number(activeIssuesFlick.bottomMargin || 0)
        return Math.max(
            0,
            Number(activeIssuesFlick.contentHeight || 0) + topMargin + bottomMargin - Number(activeIssuesFlick.height || 0)
        )
    }

    function normalizedGridScrollValue() {
        if (!activeIssuesFlick) return 0
        const topMargin = Number(activeIssuesFlick.topMargin || 0)
        return Math.max(0, Number(activeIssuesFlick.contentY || 0) + topMargin)
    }

    function setNormalizedGridScrollValue(value) {
        if (!activeIssuesFlick) return
        const topMargin = Number(activeIssuesFlick.topMargin || 0)
        const maxValue = maxNormalizedGridScrollValue()
        const clamped = Math.max(0, Math.min(maxValue, Number(value || 0)))
        activeIssuesFlick.contentY = -topMargin + clamped
    }

    function setGridScrollToTop() {
        setNormalizedGridScrollValue(0)
    }

    function scheduleGridSplitScrollRestore(value) {
        pendingGridSplitScrollValue = Math.max(0, Number(value || 0))
        gridSplitScrollRestorePending = true
        gridSplitScrollRestoreTimer.restart()
    }

    function applyPendingGridSplitScrollRestore() {
        if (!gridSplitScrollRestorePending) return
        gridSplitScrollRestorePending = false
        if (typeof mainLibraryPane === "undefined" || !mainLibraryPane) return
        mainLibraryPane.setAbsoluteSplitScroll(pendingGridSplitScrollValue)
    }

    function requestIssueThumbnail(comicId) {
        readerCoverController.requestIssueThumbnail(comicId)
    }

    function displayPublisherName(publisherName) {
        return PublisherCatalog.displayPublisherName(publisherName)
    }

    function normalizeSeriesNameForSave(seriesText, volumeText) {
        const rawSeries = String(seriesText || "").trim()
        const rawVolume = String(volumeText || "").trim()
        if (rawSeries.length < 1 || rawVolume.length < 1) return rawSeries

        const escapedVolume = rawVolume.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        const suffixPattern = new RegExp("\\s*-?\\s*vol\\.?\\s*" + escapedVolume + "\\s*$", "i")
        const normalized = rawSeries.replace(suffixPattern, "").trim()
        return normalized.length > 0 ? normalized : rawSeries
    }

    function displaySeriesTitleForIssue(issue) {
        const row = issue || {}
        const series = String(row.series || "").trim()
        const volume = String(row.volume || "").trim()
        if (series.length < 1) return ""
        if (volume.length < 1) return series
        return series + " - Vol. " + volume
    }

    function currentSelectedSeriesContext() {
        return SeriesContext.selectedContext(
            selectedSeriesKey,
            selectedSeriesTitle,
            selectedVolumeKey,
            selectedVolumeTitle,
            AppText.libraryAllVolumes
        )
    }

    function issuesGridMatchesSelectedSeries() {
        const context = currentSelectedSeriesContext()
        const selectedTitle = String(context.seriesTitle || "").trim()
        if (selectedTitle.length < 1 || issuesGridData.length < 1) return false
        const gridTitle = displaySeriesTitleForIssue(issuesGridData[0])
        return gridTitle.length > 0 && gridTitle === selectedTitle
    }

    function applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle) {
        if (!libraryBrowseController
                || typeof libraryBrowseController.applySelectedSeriesContext !== "function") {
            return
        }
        libraryBrowseController.applySelectedSeriesContext(seriesKey, seriesTitle, volumeKey, volumeTitle)
    }

    function settleSelectionDrivenRefresh() {
        selectionDrivenRefreshQueued = false
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return

        const context = currentSelectedSeriesContext()
        const seriesKey = String(context.seriesKey || "")
        const seriesTitle = String(context.seriesTitle || "")
        const volumeKey = String(context.volumeKey || "__all__")
        const volumeTitle = String(context.volumeTitle || AppText.libraryAllVolumes)
        const seriesKeyChanged = seriesKey !== settledSelectionSeriesKey
        const seriesTitleChanged = seriesTitle !== settledSelectionSeriesTitle
        const volumeKeyChanged = volumeKey !== settledSelectionVolumeKey
        const volumeTitleChanged = volumeTitle !== settledSelectionVolumeTitle

        if (!seriesKeyChanged && !seriesTitleChanged && !volumeKeyChanged && !volumeTitleChanged) {
            return
        }

        settledSelectionSeriesKey = seriesKey
        settledSelectionSeriesTitle = seriesTitle
        settledSelectionVolumeKey = volumeKey
        settledSelectionVolumeTitle = volumeTitle

        if (seriesKeyChanged) {
            heroSeriesController.resolveHeroMediaForSelectedSeries(true)
        }
        heroSeriesController.refreshSeriesData()
        if (seriesKeyChanged || volumeKeyChanged) {
            scheduleIssuesGridRefresh(true)
        }
        startupController.requestSnapshotSave()
    }

    function scheduleSelectionDrivenRefresh() {
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return
        if (selectionDrivenRefreshQueued) return
        selectionDrivenRefreshQueued = true
        Qt.callLater(function() {
            settleSelectionDrivenRefresh()
        })
    }


    function fileNameFromPath(pathValue) {
        const normalized = String(pathValue || "").replace(/\\/g, "/")
        if (normalized.length < 1) return ""
        const parts = normalized.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : normalized
    }

    function fileSizeBytes(pathValue) {
        const normalized = normalizeImportPath(pathValue)
        if (normalized.length < 1) return 0
        const value = Number(libraryModel.fileSizeBytes(normalized))
        if (!isFinite(value) || value <= 0) return 0
        return Math.floor(value)
    }

    function normalizeImportPath(rawPath) {
        const input = String(rawPath || "").trim()
        if (input.length < 1) return ""

        let normalized = input
        if (normalized.startsWith("file:///")) {
            normalized = normalized.substring("file:///".length)
        } else if (normalized.startsWith("file://")) {
            normalized = normalized.substring("file://".length)
        }

        try {
            normalized = decodeURIComponent(normalized)
        } catch (e) {
            // keep original if URL decoding fails on malformed input
        }
        if (/^[A-Za-z]:\//.test(normalized)) {
            return normalized.replace(/\//g, "\\")
        }
        if (normalized.startsWith("/")) {
            return normalized.substring(1).replace(/\//g, "\\")
        }
        return normalized.replace(/\//g, "\\")
    }

    function resolveImportSourceEntries(paths) {
        const normalizedSources = []
        if (!paths || paths.length < 1) return normalizedSources

        for (let i = 0; i < paths.length; i += 1) {
            let rawPath = paths[i]
            if (rawPath && typeof rawPath === "object") {
                rawPath = rawPath.path
            }
            const normalized = normalizeImportPath(rawPath)
            if (normalized.length < 1) continue
            normalizedSources.push(normalized)
        }

        if (normalizedSources.length < 1) return []
        return libraryModel.expandImportSources(normalizedSources, true)
    }

    function startImportFromSourcePaths(paths, options, emptyMessage) {
        const resolvedEntries = resolveImportSourceEntries(paths)
        if (!resolvedEntries || resolvedEntries.length < 1) {
            popupController.showActionResult(String(emptyMessage || AppText.sidebarDropNoSupportedSources), true)
            return false
        }
        return importController.importSourceEntries(resolvedEntries, options || {})
    }

    function parentFolderPath(pathValue) {
        const normalized = normalizeImportPath(pathValue)
        if (normalized.length < 1) return ""
        const slashPath = normalized.replace(/\\/g, "/")
        const idx = slashPath.lastIndexOf("/")
        if (idx < 0) return ""
        return slashPath.substring(0, idx).replace(/\//g, "\\")
    }

    function openFolderForPath(pathValue) {
        const folderPath = parentFolderPath(pathValue)
        if (folderPath.length < 1) return false
        const url = startupController.toLocalFileUrl(folderPath)
        if (url.length < 1) return false
        Qt.openUrlExternally(url)
        return true
    }

    function openExactFolderPath(pathValue) {
        const normalized = normalizeImportPath(pathValue)
        if (normalized.length < 1) return false
        const url = startupController.toLocalFileUrl(normalized)
        if (url.length < 1) return false
        Qt.openUrlExternally(url)
        return true
    }

    function childPath(basePath, childName) {
        const base = String(basePath || "").trim()
        const child = String(childName || "").trim()
        if (base.length < 1) return ""
        if (child.length < 1) return base
        return base.replace(/[\\\/]+$/, "") + "\\" + child
    }

    function looksLikeAbsoluteLocalPath(pathValue) {
        const normalized = String(pathValue || "").trim().replace(/\//g, "\\")
        return /^[A-Za-z]:\\/.test(normalized) || normalized.startsWith("\\\\")
    }

    function resolveLibraryBackgroundStoredPath(pathValue) {
        const storedPath = String(pathValue || "").trim()
        if (storedPath.length < 1) return ""
        if (libraryModel && typeof libraryModel.resolveStoredPathAgainstDataRoot === "function") {
            return String(libraryModel.resolveStoredPathAgainstDataRoot(storedPath) || "")
        }
        return storedPath
    }

    function storeLibraryBackgroundImageSelection(sourcePath, showErrorPopup) {
        const candidatePath = String(sourcePath || "").trim()
        if (candidatePath.length < 1) return ""

        if (!libraryModel || typeof libraryModel.storeLibraryBackgroundImage !== "function") {
            if (showErrorPopup) {
                showSettingsError("Failed to save custom background image.")
            }
            return ""
        }

        const result = libraryModel.storeLibraryBackgroundImage(candidatePath) || {}
        if (!Boolean(result.ok)) {
            if (showErrorPopup) {
                showSettingsError(String(result.error || "Failed to save custom background image."))
            }
            return ""
        }

        return String(result.storedPath || "")
    }

    function migrateLibraryBackgroundImageSettingIfNeeded() {
        if (libraryBackgroundImageMigrationInProgress) return

        const storedPath = String(libraryBackgroundCustomImageStoredPath || "").trim()
        if (!looksLikeAbsoluteLocalPath(storedPath)) return

        const resolvedPath = String(libraryBackgroundCustomImageResolvedPath || "").trim()
        if (resolvedPath.length < 1) return

        libraryBackgroundImageMigrationInProgress = true
        const migratedStoredPath = storeLibraryBackgroundImageSelection(resolvedPath, false)
        libraryBackgroundImageMigrationInProgress = false

        if (migratedStoredPath.length > 0 && migratedStoredPath !== storedPath) {
            appSettingsController.setSettingValue(
                "appearance_library_background_custom_image_path",
                migratedStoredPath
            )
        }
    }

    onLibraryBackgroundCustomImageStoredPathChanged: migrateLibraryBackgroundImageSettingIfNeeded()

    function reloadLibraryFromSettings() {
        libraryModel.reload()
    }

    function openSettingsDialog(sectionKey, preserveReaderPopup) {
        const requested = String(sectionKey || "").trim()
        settingsDialog.requestedSection = requested
        settingsDialog.selectedSection = requested.length > 0 ? requested : "general"
        if (Boolean(preserveReaderPopup) && readerDialog && readerDialog.visible) {
            if (!settingsDialog.visible) {
                settingsDialog.open()
            }
            return
        }
        popupController.openExclusivePopup(settingsDialog)
    }

    function openHelpDialog(sectionKey) {
        const requested = String(sectionKey || "").trim()
        helpDialog.requestedSection = requested
        popupController.openExclusivePopup(helpDialog)
    }

    function openAboutDialog() {
        popupController.openExclusivePopup(aboutDialog)
    }

    function openUpdateAvailableDialog(asDeferredPrompt, deferredPromptVersion) {
        const deferredPrompt = Boolean(asDeferredPrompt)
        const deferredVersionText = String(deferredPromptVersion || "").trim()
        if (updateAvailableDialog) {
            updateAvailableDialog.autoPromptActive = deferredPrompt
            updateAvailableDialog.autoPromptVersion = deferredPrompt ? deferredVersionText : ""
        }
        popupController.openExclusivePopup(updateAvailableDialog)
    }

    function openWhatsNewDialog() {
        popupController.openExclusivePopup(whatsNewDialog)
    }

    function readyForDeferredUpdatePrompt() {
        if (!startupPrimaryContentVisible) return false
        if (startupHydrationInProgress) return false
        if (!startupReconcileCompleted) return false
        if (firstRunOnboardingActive) return false
        if (importInProgress) return false
        if (anyManagedModalPopupVisible) return false
        return true
    }

    function scheduleDeferredUpdatePromptCheck() {
        deferredUpdatePromptTimer.restart()
    }

    function tryPresentDeferredUpdatePrompt() {
        const startupVersion = String(startupDeferredUpdatePromptVersion || "").trim()
        if (startupVersion.length < 1) return
        if (!readyForDeferredUpdatePrompt()) return
        if (typeof releaseCheckService === "undefined" || !releaseCheckService) {
            startupDeferredUpdatePromptVersion = ""
            return
        }
        const pendingVersion = String(releaseCheckService.pendingUpdatePromptVersion || "").trim()
        if (pendingVersion.length < 1 || pendingVersion !== startupVersion || !releaseCheckService.shouldShowPendingUpdatePrompt()) {
            startupDeferredUpdatePromptVersion = ""
            return
        }
        startupDeferredUpdatePromptVersion = ""
        releaseCheckService.clearPendingUpdatePrompt()
        openUpdateAvailableDialog(true, pendingVersion)
    }

    function launchOnboarding(manualLaunch) {
        dismissBackgroundTransientUi()
        firstRunOnboardingStep = 1
        firstRunOnboardingActive = true
        if (!appSettingsController.onboardingCompleted) {
            appSettingsController.onboardingCompleted = true
        }
    }

    function closeOnboarding() {
        firstRunOnboardingActive = false
        firstRunOnboardingStep = 1
    }

    function showSettingsActionResultPayload(payload) {
        if (settingsDialog && settingsDialog.visible) {
            popupController.showMappedActionResultAbovePopup(payload, settingsDialog)
            return
        }
        popupController.showMappedActionResult(payload)
    }

    function showSettingsError(messageText, detailsText, buttonText, actionKey, filePath, titleOverride) {
        showSettingsActionResultPayload(AppErrorMapper.defaultActionResultPayload(
            String(messageText || ""),
            String(titleOverride || AppText.popupActionErrorTitle),
            String(detailsText || ""),
            String(buttonText || ""),
            String(actionKey || ""),
            String(filePath || "")
        ))
    }

    function presentLibraryLoadError(messageText) {
        const message = String(messageText || "").trim()
        if (message.length < 1) return
        showSettingsActionResultPayload(AppErrorMapper.libraryLoadFailure(message))
    }

    function scheduleLibraryDataRelocationFromSettings() {
        const initialPath = String(
            pendingLibraryDataRelocationPath
            || libraryDataRootPath
            || ""
        )
        const selectedPath = String(libraryModel.browseDataRootFolder(initialPath) || "")
        if (selectedPath.length < 1) return

        const result = libraryModel.scheduleDataRootRelocation(selectedPath)
        if (!Boolean((result || {}).ok)) {
            showSettingsError(String((result || {}).error || AppText.mainFailedScheduleLibraryLocation))
            return
        }

        pendingLibraryDataRelocationPath = String((result || {}).pendingPath || selectedPath || "")
    }

    function isSilentReplaceStateError(messageText) {
        const text = String(messageText || "").trim()
        return text === "Invalid issue id."
            || text === "Replace failed: existing archive path is missing."
            || text === "Replace failed: existing archive filename is missing."
    }

    function queueSilentReaderProgressSave(comicId, pageValue, refreshAfterSuccess) {
        const normalizedComicId = Number(comicId || 0)
        if (normalizedComicId < 1) return

        const key = String(normalizedComicId)
        const nextEntries = Object.assign({}, pendingReaderProgressSaveByComicId || {})
        nextEntries[key] = {
            comicId: normalizedComicId,
            pageValue: Number(pageValue || 0),
            attemptsRemaining: 5,
            refreshAfterSuccess: Boolean(refreshAfterSuccess)
                || Boolean((pendingReaderProgressSaveByComicId || {})[key]
                    && pendingReaderProgressSaveByComicId[key].refreshAfterSuccess)
        }
        pendingReaderProgressSaveByComicId = nextEntries

        const nextOrder = Array.isArray(pendingReaderProgressSaveOrder)
            ? pendingReaderProgressSaveOrder.slice(0)
            : []
        if (nextOrder.indexOf(key) < 0) {
            nextOrder.push(key)
            pendingReaderProgressSaveOrder = nextOrder
        }

        if (!readerProgressSaveRetryTimer.running) {
            readerProgressSaveRetryTimer.start()
        }
    }

    function processQueuedReaderProgressSave() {
        const order = Array.isArray(pendingReaderProgressSaveOrder)
            ? pendingReaderProgressSaveOrder.slice(0)
            : []
        if (order.length < 1) return

        const key = String(order[0] || "")
        const entries = Object.assign({}, pendingReaderProgressSaveByComicId || {})
        const entry = entries[key]
        if (!entry) {
            order.shift()
            pendingReaderProgressSaveOrder = order
            if (order.length > 0) readerProgressSaveRetryTimer.start()
            return
        }

        const saveError = String(libraryModel.saveReaderProgress(entry.comicId, entry.pageValue) || "")
        if (saveError.length < 1) {
            delete entries[key]
            order.shift()
            pendingReaderProgressSaveByComicId = entries
            pendingReaderProgressSaveOrder = order
            if (Boolean(entry.refreshAfterSuccess)) {
                scheduleIssuesGridRefresh(true, true)
            }
            if (order.length > 0) readerProgressSaveRetryTimer.start()
            return
        }

        const attemptsRemaining = Math.max(0, Number(entry.attemptsRemaining || 0) - 1)
        if (attemptsRemaining > 0) {
            entries[key] = {
                comicId: entry.comicId,
                pageValue: entry.pageValue,
                attemptsRemaining: attemptsRemaining,
                refreshAfterSuccess: Boolean(entry.refreshAfterSuccess)
            }
            order.push(order.shift())
            pendingReaderProgressSaveByComicId = entries
            pendingReaderProgressSaveOrder = order
            readerProgressSaveRetryTimer.start()
            return
        }

        delete entries[key]
        order.shift()
        pendingReaderProgressSaveByComicId = entries
        pendingReaderProgressSaveOrder = order
        if (order.length > 0) readerProgressSaveRetryTimer.start()
    }

    function openSeriesFolder(seriesKey, seriesName) {
        const normalizedSeriesKey = String(seriesKey || "").trim()
        if (normalizedSeriesKey.length < 1) {
            popupController.showActionResult(AppText.mainSeriesFolderUnavailable, true)
            return
        }

        const issues = libraryModel.issuesForSeries(normalizedSeriesKey, "__all__", "all", "")
        for (let i = 0; i < issues.length; i += 1) {
            const issue = issues[i] || {}
            const comicId = Number(issue.id || 0)
            if (comicId < 1) continue

            const metadata = libraryModel.loadComicMetadata(comicId)
            const filePath = String((metadata || {}).filePath || "").trim()
            if (filePath.length < 1) continue

            if (openFolderForPath(filePath)) return
        }

        const resolvedSeriesName = String(seriesName || "").trim()
        const label = resolvedSeriesName.length > 0 ? resolvedSeriesName : "this series"
        popupController.showActionResult(AppText.noFolderAvailableMessage(label), true)
    }

    function cloneVariantMap(sourceValues) {
        const out = {}
        if (!sourceValues || typeof sourceValues !== "object") return out
        const keys = Object.keys(sourceValues)
        for (let i = 0; i < keys.length; i += 1) {
            const key = String(keys[i] || "")
            if (key.length < 1) continue
            out[key] = sourceValues[key]
        }
        return out
    }

    function archiveUnsupportedReason(pathValue) {
        return String(libraryModel.importArchiveUnsupportedReason(String(pathValue || "")) || "")
    }

    function importErrorMatchesAny(lowerText, patterns) {
        const haystack = String(lowerText || "").trim().toLowerCase()
        if (haystack.length < 1 || !Array.isArray(patterns)) return false
        for (let i = 0; i < patterns.length; i += 1) {
            const pattern = String(patterns[i] || "").trim().toLowerCase()
            if (pattern.length > 0 && haystack.indexOf(pattern) >= 0) {
                return true
            }
        }
        return false
    }

    function classifyImportError(pathValue, rawErrorText, rawErrorCode) {
        const raw = String(rawErrorText || "").trim()
        const lower = raw.toLowerCase()
        const code = String(rawErrorCode || "").trim().toLowerCase()
        const timedOutCodes = [
            "timeout",
            "timed_out"
        ]
        const accessCodes = [
            "file_not_found",
            "library_dir_create_failed",
            "series_dir_create_failed",
            "temp_dir_create_failed"
        ]
        const unreadableCodes = [
            "archive_normalize_failed"
        ]
        const timedOutPatterns = [
            "timed out",
            "timeout"
        ]
        const accessPatterns = [
            "archive file not found",
            "archive not found",
            "file not found",
            "source path no longer resolves",
            "no longer resolves to a single importable item",
            "failed to copy archive",
            "failed to move extracted page",
            "failed to create library folder",
            "failed to create target directory",
            "failed to create temporary directory",
            "failed to create output directory",
            "failed to create temp extraction folder",
            "failed to create target folder",
            "access is denied",
            "permission denied",
            "is denied",
            "locked"
        ]
        const unreadablePatterns = [
            "archive normalize failed",
            "process failed",
            "exited with code",
            "invalid .cbz archive",
            "archive conversion produced an invalid .cbz archive",
            "cannot be normalized to .cbz",
            "archive is invalid",
            "corrupt",
            "unreadable",
            "no image pages found in archive"
        ]

        let reason = "Unknown error"

        if (importErrorMatchesAny(code, timedOutCodes) || importErrorMatchesAny(lower, timedOutPatterns)) {
            reason = "Import timed out"
        } else if (importErrorMatchesAny(code, accessCodes) || importErrorMatchesAny(lower, accessPatterns)) {
            reason = "Access denied or file locked"
        } else if (importErrorMatchesAny(code, unreadableCodes) || importErrorMatchesAny(lower, unreadablePatterns)) {
            reason = "Corrupted or unreadable archive"
        }

        return {
            reason: reason
        }
    }

    function escapeRichText(textValue) {
        return String(textValue || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }

    function popupBodyStrongText(textValue, pixelSize) {
        const fontSize = Math.max(1, Number(pixelSize || 13))
        return "<span style=\"font-size:" + String(fontSize) + "px; font-weight:700;\">"
            + escapeRichText(textValue)
            + "</span>"
    }

    function seriesDeleteQuestionText(emphasisPixelSize) {
        const emphasisSize = Math.max(1, Number(emphasisPixelSize || 13))
        if (pendingSeriesKeys.length > 1) {
            return "Delete files for " + String(pendingSeriesKeys.length)
                + " series (" + String(pendingSeriesIssueCount) + " issues) from disk?"
        }
        return "Delete files for series "
            + popupBodyStrongText(pendingSeriesTitle, emphasisSize)
            + " from disk?"
    }

    function refreshCbrSupportState() {
        cbrBackendAvailable = libraryModel.isCbrBackendAvailable()
        cbrBackendMissingMessage = libraryModel.cbrBackendMissingMessage()
        const configuredPath = String(libraryModel.configuredSevenZipExecutablePath() || "")
        const effectivePath = String(libraryModel.effectiveSevenZipExecutablePath() || "")
        sevenZipEffectivePath = effectivePath
        sevenZipConfiguredPath = configuredPath.length > 0 ? configuredPath : effectivePath
    }

    function chooseSevenZipPathFromSettings() {
        const initialPath = String(sevenZipConfiguredPath || sevenZipEffectivePath || "")
        const selectedPath = String(libraryModel.browseArchiveFile(initialPath) || "")
        if (selectedPath.length < 1) return

        const applyError = String(libraryModel.setSevenZipExecutablePath(selectedPath) || "").trim()
        if (applyError.length > 0) {
            showSettingsError(applyError)
            return
        }

        refreshCbrSupportState()
        startupController.requestSnapshotSave()
    }

    function verifySevenZipFromSettings() {
        refreshCbrSupportState()
    }

    function checkStorageAccessFromSettings() {
        const result = libraryModel.checkStorageAccess()
        const ok = Boolean((result || {}).ok)
        settingsDialog.storageAccessCheckState = ok ? "success" : "failure"
        settingsDialog.storageAccessResultText = String(
            (result || {}).statusText || (ok ? "All good" : "Needs attention")
        )
        settingsDialog.storageAccessHintText = ok
            ? ""
            : String((result || {}).hintText || "")
    }

    function resetSettingsToDefaults() {
        if (appSettingsController && typeof appSettingsController.resetAllSettingsToDefaults === "function") {
            appSettingsController.resetAllSettingsToDefaults()
        }
        refreshCbrSupportState()
        startupController.requestSnapshotSave()
    }

    function chooseLibraryBackgroundImageFromSettings() {
        const currentPath = String(libraryBackgroundCustomImageResolvedPath || "")
        const selectedPath = String(libraryModel.browseImageFile(currentPath) || "")
        if (selectedPath.length < 1) return

        const limitBytes = libraryBackgroundCustomImageMode === "Tile"
            ? libraryBackgroundTileImageMaxBytes
            : libraryBackgroundImageMaxBytes
        const sizeBytes = fileSizeBytes(selectedPath)
        if (sizeBytes > limitBytes) {
            const label = libraryBackgroundCustomImageMode === "Tile" ? "1 MB" : "8 MB"
            showSettingsError(AppText.backgroundImageTooLargeMessage(label))
            return
        }

        const storedPath = storeLibraryBackgroundImageSelection(selectedPath, true)
        if (storedPath.length < 1) return

        appSettingsController.setSettingValue("appearance_library_background_custom_image_path", storedPath)
        appSettingsController.setSettingValue("appearance_library_background", "Custom image")
    }

    function setLibraryBackgroundImageModeFromSettings(nextMode) {
        const mode = String(nextMode || "").trim()
        if (mode.length < 1) return
        if (mode === "Tile") {
            const currentPath = String(libraryBackgroundCustomImageResolvedPath || "")
            if (currentPath.length > 0) {
                const sizeBytes = fileSizeBytes(currentPath)
                if (sizeBytes > libraryBackgroundTileImageMaxBytes) {
                    showSettingsError(AppText.mainTileModeImageLimit)
                    return
                }
            }
        }
        appSettingsController.setSettingValue("appearance_library_background_image_mode", mode)
    }

    function quickAddFilesFromDialog() {
        if (importInProgress) return
        const selected = libraryModel.browseArchiveFiles("")
        if (!selected || selected.length < 1) return
        startImportFromSourcePaths(
            selected,
            { importIntent: "global_add" },
            "No Supported Archives Found in Selected Files."
        )
    }

    function quickAddFilesForSeries(seriesKey) {
        if (importInProgress) return
        const selected = libraryModel.browseArchiveFiles("")
        if (!selected || selected.length < 1) return
        const importContext = libraryModel && typeof libraryModel.seriesAddIssueContext === "function"
            ? (libraryModel.seriesAddIssueContext(String(seriesKey || "").trim()) || ({}))
            : (libraryModel && typeof libraryModel.seriesImportContext === "function"
                ? (libraryModel.seriesImportContext(String(seriesKey || "").trim()) || ({}))
                : ({}))
        const targetSeries = String(importContext.series || "").trim()
        const targetVolume = String(importContext.volume || "").trim()
        const targetPublisher = String(importContext.publisher || "").trim()
        const targetYear = String(importContext.year || "").trim()
        const targetMonth = String(importContext.month || "").trim()
        const targetAgeRating = String(importContext.ageRating || "").trim()
        const importValues = {
            series: targetSeries,
            volume: targetVolume
        }
        if (targetPublisher.length > 0) {
            importValues.publisher = targetPublisher
        }
        if (targetYear.length > 0) {
            importValues.year = targetYear
        }
        if (targetMonth.length > 0) {
            importValues.month = targetMonth
        }
        if (targetAgeRating.length > 0) {
            importValues.ageRating = targetAgeRating
        }
        if (targetSeries.length > 0) {
            startImportFromSourcePaths(
                selected,
                {
                    seriesOverride: targetSeries,
                    importIntent: "series_add",
                    values: importValues
                },
                "No Supported Archives Found in Selected Files."
            )
            return
        }
        popupController.showActionResult(AppText.metadataSeriesContextMissing, true)
    }

    function performReplaceIssueArchive(comicId, selectedPath, sourceType) {
        const normalizedComicId = Number(comicId || 0)
        const normalizedPath = String(selectedPath || "").trim()
        const normalizedSourceType = String(sourceType || "archive").trim().toLowerCase() || "archive"
        if (normalizedComicId < 1 || normalizedPath.length < 1) return false

        const result = libraryModel.replaceComicFileFromSourceEx(
            normalizedComicId,
            normalizedPath,
            normalizedSourceType,
            "",
            ({})
        )
        if (!Boolean((result || {}).ok)) {
            const replaceError = String((result || {}).error || "Replace failed.")
            if (isSilentReplaceStateError(replaceError)) {
                return false
            }
            popupController.showActionResult(replaceError, true)
            return false
        }

        heroSeriesController.resolveHeroMediaForSelectedSeries()
        return true
    }

    function cancelReplaceIssueArchiveConfirmation() {
        if (replaceArchiveOperationActive) {
            return
        }
        pendingReplaceArchiveComicId = -1
        pendingReplaceArchiveSourcePath = ""
        pendingReplaceArchiveSourceType = "archive"
        if (replaceSourceChoiceDialog && replaceSourceChoiceDialog.visible) {
            replaceSourceChoiceDialog.close()
        }
    }

    function queueReplaceIssueArchive(comicId, selectedPath, sourceType) {
        if (replaceArchiveOperationActive) {
            return false
        }
        const normalizedComicId = Number(comicId || 0)
        const normalizedPath = String(selectedPath || "").trim()
        const normalizedSourceType = String(sourceType || "archive").trim().toLowerCase() || "archive"
        if (normalizedComicId < 1 || normalizedPath.length < 1) {
            return false
        }
        pendingReplaceArchiveComicId = normalizedComicId
        pendingReplaceArchiveSourcePath = normalizedPath
        pendingReplaceArchiveSourceType = normalizedSourceType
        replaceArchiveOperationStatusText = normalizedSourceType === "image_folder"
            ? "Replacing from image folder..."
            : "Replacing archive..."
        replaceArchiveOperationActive = true
        replaceArchiveActionTimer.start()
        return true
    }

    function chooseReplaceIssueArchiveSource(comicId, sourceType) {
        const normalizedComicId = Number(comicId || 0)
        const normalizedSourceType = String(sourceType || "archive").trim().toLowerCase() || "archive"
        if (normalizedComicId < 1) return
        if (replaceSourceChoiceDialog && replaceSourceChoiceDialog.visible) {
            replaceSourceChoiceDialog.close()
        }

        const loaded = libraryModel.loadComicMetadata(normalizedComicId)
        if (loaded && loaded.error) {
            return
        }

        const currentFilePath = String((loaded || {}).filePath || "")
        const selectedPath = normalizedSourceType === "image_folder"
            ? String(libraryModel.browseArchiveFolder(currentFilePath) || "")
            : String(libraryModel.browseArchiveFile(currentFilePath) || "")
        if (selectedPath.length < 1) return

        if (normalizedSourceType === "archive") {
            const unsupportedReason = String(libraryModel.importArchiveUnsupportedReason(selectedPath) || "")
            if (unsupportedReason.length > 0) {
                popupController.showActionResult(unsupportedReason, true)
                return
            }
        }

        queueReplaceIssueArchive(normalizedComicId, selectedPath, normalizedSourceType)
    }

    function replaceIssueArchive(comicId) {
        if (comicId < 1) return
        if (importInProgress) {
            popupController.showActionResult(AppText.importAlreadyRunning, true)
            return
        }

        const loaded = libraryModel.loadComicMetadata(comicId)
        if (loaded && loaded.error) {
            return
        }

        pendingReplaceArchiveComicId = Number(comicId || -1)
        pendingReplaceArchiveSourcePath = ""
        pendingReplaceArchiveSourceType = "archive"
        if (replaceSourceChoiceDialog && !replaceSourceChoiceDialog.visible) {
            popupController.openExclusivePopup(replaceSourceChoiceDialog)
        }
    }

    Timer {
        id: replaceArchiveActionTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: {
            const comicId = Number(root.pendingReplaceArchiveComicId || 0)
            const selectedPath = String(root.pendingReplaceArchiveSourcePath || "")
            const sourceType = String(root.pendingReplaceArchiveSourceType || "archive")

            if (comicId < 1 || selectedPath.length < 1) {
                root.replaceArchiveOperationActive = false
                root.pendingReplaceArchiveComicId = -1
                root.pendingReplaceArchiveSourcePath = ""
                root.pendingReplaceArchiveSourceType = "archive"
                return
            }

            root.performReplaceIssueArchive(comicId, selectedPath, sourceType)
            root.replaceArchiveOperationActive = false
            root.pendingReplaceArchiveComicId = -1
            root.pendingReplaceArchiveSourcePath = ""
            root.pendingReplaceArchiveSourceType = "archive"
        }
    }

    function quickAddFolderFromDialog() {
        if (importInProgress) return
        const selectedFolder = String(libraryModel.browseArchiveFolder("") || "")
        if (selectedFolder.length < 1) return
        startImportFromSourcePaths(
            [selectedFolder],
            { importIntent: "global_add" },
            "No Supported Comic Sources Found in Selected Folder."
        )
    }

    function captureImportSeriesFocusBaseline() {
        const groups = libraryModel.seriesGroups()
        const snapshot = {}
        for (let i = 0; i < groups.length; i += 1) {
            const key = String(((groups[i] || {}).seriesKey) || "").trim()
            if (key.length > 0) snapshot[key] = true
        }
        importSeriesKeysBeforeBatch = snapshot
        importFocusNewSeriesAfterReload = false
        pendingImportPostReloadAction = ""
    }

    function requestImportNewSeriesFocusAfterReload() {
        const preference = String(appSettingsController.generalAfterImport || "Focus imported series")
        if (preference === "Open last import") {
            pendingImportPostReloadAction = "last_import"
            importFocusNewSeriesAfterReload = false
            return
        }
        if (preference === "Do nothing") {
            pendingImportPostReloadAction = "none"
            importFocusNewSeriesAfterReload = false
            return
        }
        pendingImportPostReloadAction = "focus_series"
        importFocusNewSeriesAfterReload = true
    }

    function requestImportCurrentSeriesRefreshAfterReload() {
        pendingImportPostReloadAction = "refresh_current_series"
        importFocusNewSeriesAfterReload = false
    }

    function clearImportSeriesFocusState() {
        importSeriesKeysBeforeBatch = ({})
        importFocusNewSeriesAfterReload = false
        pendingImportPostReloadAction = ""
    }

    function applyConfiguredLaunchViewCore(modeLabel) {
        const mode = String(modeLabel || "Remember last state")
        const lastImportCount = libraryModel.quickFilterIssueCount("last_import", lastImportSessionComicIds)

        if (mode === "Last import" && lastImportCount > 0) {
            sidebarQuickFilterKey = "last_import"
            applySelectedSeriesContext("", "", "__all__", AppText.libraryAllVolumes)
            selectedSeriesKeys = ({})
            seriesSelectionAnchorIndex = -1
            volumeListModel.clear()
            clearSelection()
            setGridScrollToTop()
            refreshIssuesGridData(false)
            heroSeriesController.resolveHeroMediaForSelectedSeries()
            heroSeriesController.refreshSeriesData()
            refreshQuickFilterCounts()
            return true
        }

        if (seriesListModel.count < 1) {
            return false
        }

        const firstItem = seriesListModel.get(0)
        sidebarQuickFilterKey = ""
        applySelectedSeriesContext(
            String((firstItem && firstItem.seriesKey) || ""),
            String((firstItem && firstItem.seriesTitle) || ""),
            "__all__",
            AppText.libraryAllVolumes
        )
        const nextSelection = {}
        if (selectedSeriesKey.length > 0) {
            nextSelection[selectedSeriesKey] = true
        }
        selectedSeriesKeys = nextSelection
        seriesSelectionAnchorIndex = 0
        refreshVolumeList()
        clearSelection()
        setGridScrollToTop()
        refreshIssuesGridData(false)
        heroSeriesController.resolveHeroMediaForSelectedSeries()
        heroSeriesController.refreshSeriesData()
        refreshQuickFilterCounts()
        return true
    }

    function applyConfiguredLaunchViewDuringStartupRestore() {
        const mode = String(appSettingsController.generalDefaultViewAfterLaunch || "Remember last state")
        if (mode === "Remember last state") {
            pendingConfiguredLaunchViewApply = false
            return false
        }
        const applied = applyConfiguredLaunchViewCore(mode)
        if (applied) {
            pendingConfiguredLaunchViewApply = false
        }
        return applied
    }

    function applyConfiguredLaunchViewAfterRefreshIfNeeded() {
        if (!pendingConfiguredLaunchViewApply) return false
        const mode = String(appSettingsController.generalDefaultViewAfterLaunch || "Remember last state")
        if (mode === "Remember last state") {
            pendingConfiguredLaunchViewApply = false
            return false
        }
        const applied = applyConfiguredLaunchViewCore(mode)
        if (applied) {
            pendingConfiguredLaunchViewApply = false
        }
        return applied
    }

    function applyPendingImportedSeriesFocus() {
        if (pendingImportPostReloadAction === "last_import") {
            clearImportSeriesFocusState()
            selectSidebarQuickFilter("last_import")
            return true
        }
        if (pendingImportPostReloadAction === "none") {
            clearImportSeriesFocusState()
            return false
        }
        if (pendingImportPostReloadAction === "refresh_current_series") {
            clearImportSeriesFocusState()
            postImportCurrentSeriesRefreshTimer.restart()
            return false
        }
        if (!importFocusNewSeriesAfterReload) return false

        const baseline = importSeriesKeysBeforeBatch || ({})
        const newSeriesItems = []
        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i)
            const key = String((item && item.seriesKey) || "").trim()
            if (key.length < 1 || baseline[key] === true) continue
            newSeriesItems.push({
                seriesKey: key,
                seriesTitle: String((item && item.seriesTitle) || ""),
                index: i
            })
        }

        clearImportSeriesFocusState()
        if (newSeriesItems.length !== 1) return false

        const target = newSeriesItems[0]
        selectSeries(target.seriesKey, target.seriesTitle, target.index)
        return true
    }

    function refreshQuickFilterCounts() { libraryBrowseController.refreshQuickFilterCounts() }

    function sidebarQuickFilterCount(filterKey) { return libraryBrowseController.sidebarQuickFilterCount(filterKey) }

    function quickFilterTitleText(filterKey) { return libraryBrowseController.quickFilterTitleText(filterKey) }

    function quickFilterEmptyText(filterKey) { return libraryBrowseController.quickFilterEmptyText(filterKey) }

    function quickFilterTitleIconSource(filterKey) { return libraryBrowseController.quickFilterTitleIconSource(filterKey) }

    function isQuickFilterModeActive() { return libraryBrowseController.isQuickFilterModeActive() }

    function resetLastImportSession() { libraryBrowseController.resetLastImportSession() }

    function rememberLastImportComicId(comicId) { libraryBrowseController.rememberLastImportComicId(comicId) }

    function selectSidebarQuickFilter(filterKey) { libraryBrowseController.selectSidebarQuickFilter(filterKey) }

    function refreshSeriesList() { libraryBrowseController.refreshSeriesList() }

    function applyVolumeSelectionByIndex(index) { libraryBrowseController.applyVolumeSelectionByIndex(index) }

    function refreshVolumeList() { libraryBrowseController.refreshVolumeList() }

    function refreshIssuesGridData(preserveSplitScroll) { libraryBrowseController.refreshIssuesGridData(preserveSplitScroll) }

    function reconcileFromModel() {
        startupController.reconcileFromModel()
    }

    function scheduleModelReconcile(immediate) {
        startupController.scheduleModelReconcile(immediate)
    }

    function visibleIssueRange(totalCount) {
        return readerCoverController.visibleIssueRange(totalCount)
    }

    function primeVisibleIssueCoverSourcesFromCache() {
        readerCoverController.primeVisibleIssueCoverSourcesFromCache()
    }

    function warmVisibleIssueThumbnails() {
        readerCoverController.warmVisibleIssueThumbnails()
    }

    function prefetchReaderNeighborPage(pageIndex) {
        readerCoverController.prefetchReaderNeighborPage(pageIndex)
    }

    function prefetchReaderNeighbors(centerPageIndex) {
        readerCoverController.prefetchReaderNeighbors(centerPageIndex)
    }

    function scheduleIssuesGridRefresh(immediate, preserveSplitScroll) { libraryBrowseController.scheduleIssuesGridRefresh(immediate, preserveSplitScroll) }

    function isSeriesSelected(seriesKey) { return seriesSelectionController.isSeriesSelected(seriesKey) }

    function selectedSeriesCount() { return seriesSelectionController.selectedSeriesCount() }

    function selectedSeriesIssueCount() { return seriesSelectionController.selectedSeriesIssueCount() }

    function indexForSeriesKey(seriesKey) { return seriesSelectionController.indexForSeriesKey(seriesKey) }

    function applySeriesSelectionRange(fromIndex, toIndex) { seriesSelectionController.applySeriesSelectionRange(fromIndex, toIndex) }

    function selectSeries(seriesKey, seriesTitle, indexValue) { seriesSelectionController.selectSeries(seriesKey, seriesTitle, indexValue) }

    function selectSeriesWithModifiers(seriesKey, seriesTitle, itemIndex, modifiers) {
        seriesSelectionController.selectSeriesWithModifiers(seriesKey, seriesTitle, itemIndex, modifiers)
    }

    function hasTextInputFocus() {
        const item = root.activeFocusItem
        if (!item) return false
        try {
            if (item.echoMode !== undefined) return true
            if (item.cursorPosition !== undefined && item.text !== undefined) return true
        } catch (e) {
            return false
        }
        return false
    }

    function libraryStateVisible() {
        if (startupHydrationInProgress) return false
        if (libraryModel.lastError.length > 0) return true
        if (!startupReconcileCompleted) return false
        if (seriesListModel.count < 1) return true
        if (selectedSeriesKey.length < 1) return true
        return false
    }

    function openMetadataEditor(comic) { metadataDialogController.openMetadataEditor(comic) }

    function saveMetadata(draftState) { return metadataDialogController.saveMetadata(draftState) }

    function buildIssueMetadataSuggestion(draftState) { return metadataDialogController.buildIssueMetadataSuggestion(draftState) }

    function applyIssueMetadataSuggestionPatch(patch) { metadataDialogController.applyIssueMetadataSuggestionPatch(patch) }

    function requestApplyIssueMetadataEdit(draftState) { metadataDialogController.requestApplyIssueMetadataEdit(draftState) }

    function acceptIssueMetadataSuggestion() { metadataDialogController.acceptIssueMetadataSuggestion() }

    function skipIssueMetadataSuggestion() { metadataDialogController.skipIssueMetadataSuggestion() }

    function resetMetadataEditor() { metadataDialogController.resetMetadataEditor() }

    function openReader(comicId, title) {
        readerSessionController.openReader(comicId, title)
    }

    function openReaderTarget(target) {
        readerSessionController.openReaderTarget(target)
    }

    function loadReaderPage(pageIndex) {
        readerSessionController.loadReaderPage(pageIndex)
    }

    function restartReaderFromBeginning() {
        readerSessionController.restartFromBeginning()
    }

    function setReaderViewMode(mode) {
        readerSessionController.setReaderViewMode(mode)
    }

    function persistReaderProgress(showErrorDialog) {
        return readerSessionController.persistReaderProgress(showErrorDialog)
    }

    function finalizeReaderSession(showErrorDialog) {
        readerSessionController.finalizeReaderSession(showErrorDialog)
    }

    function closeReader() {
        readerSessionController.closeReader()
    }

    function nextReaderPage() {
        readerSessionController.nextReaderPage()
    }

    function previousReaderPage() {
        readerSessionController.previousReaderPage()
    }

    function previousReaderIssue() {
        readerSessionController.previousReaderIssue()
    }

    function nextReaderIssue() {
        readerSessionController.nextReaderIssue()
    }

    function copyCurrentReaderImage() {
        return readerSessionController.copyCurrentReaderImage()
    }

    function requestDeleteReaderPageConfirmation(comicId, pageIndex) {
        const normalizedComicId = Number(comicId || 0)
        const normalizedPageIndex = Number(pageIndex)
        if (normalizedComicId < 1 || normalizedPageIndex < 0) return false
        pendingDeleteReaderPageComicId = normalizedComicId
        pendingDeleteReaderPageIndex = normalizedPageIndex
        if (!Boolean(appSettingsController.safetyConfirmBeforeDeletingPage)) {
            return confirmDeleteReaderPage()
        }
        if (readerDeletePageConfirmDialog && !readerDeletePageConfirmDialog.visible) {
            readerDeletePageConfirmDialog.open()
        }
        return true
    }

    function cancelDeleteReaderPageConfirmation() {
        pendingDeleteReaderPageComicId = -1
        pendingDeleteReaderPageIndex = -1
        if (readerDeletePageConfirmDialog && readerDeletePageConfirmDialog.visible) {
            readerDeletePageConfirmDialog.close()
        }
    }

    function confirmDeleteReaderPage() {
        const comicId = Number(pendingDeleteReaderPageComicId || 0)
        const pageIndex = Number(pendingDeleteReaderPageIndex)
        cancelDeleteReaderPageConfirmation()
        if (comicId < 1 || pageIndex < 0) return false

        const result = libraryModel.deleteReaderPageFromArchive(comicId, pageIndex) || ({})
        const errorText = String(result.error || "").trim()
        if (errorText.length > 0) {
            popupController.showMappedActionResult(AppErrorMapper.deleteReaderPageFailure(errorText))
            return false
        }

        if (readerComicId === comicId) {
            readerCoverController.refreshReaderAfterDeletedPage(result)
        }
        return true
    }

    function markCurrentReaderIssueReadAndAdvance() {
        readerSessionController.markCurrentReaderIssueReadAndAdvance()
    }

    function toggleReaderBookmark() {
        readerSessionController.toggleReaderBookmark()
    }

    function jumpToReaderBookmark() {
        readerSessionController.jumpToReaderBookmark()
    }

    function seriesMetaMonthNameFromNumber(monthNumber) { return metadataDialogController.seriesMetaMonthNameFromNumber(monthNumber) }

    function seriesMetaMonthNumberFromName(monthName) { return metadataDialogController.seriesMetaMonthNumberFromName(monthName) }

    function openSeriesMetadataDialog(seriesKey, seriesTitle, focusField, mode) {
        metadataDialogController.openSeriesMetadataDialog(seriesKey, seriesTitle, focusField, mode)
    }

    function openSeriesMergeDialog(seriesKey, seriesTitle) { metadataDialogController.openSeriesMergeDialog(seriesKey, seriesTitle) }

    function buildSeriesMetadataSuggestion() { return metadataDialogController.buildSeriesMetadataSuggestion() }

    function applySeriesMetadataSuggestionPatch(patch) { metadataDialogController.applySeriesMetadataSuggestionPatch(patch) }

    function requestApplySeriesMetadataEdit() { metadataDialogController.requestApplySeriesMetadataEdit() }

    function acceptSeriesMetadataSuggestion() { metadataDialogController.acceptSeriesMetadataSuggestion() }

    function skipSeriesMetadataSuggestion() { metadataDialogController.skipSeriesMetadataSuggestion() }

    function findSeriesKeyForIssueId(issueId, fallbackKey) { return metadataDialogController.findSeriesKeyForIssueId(issueId, fallbackKey) }

    function applySeriesMetadataEdit() { return metadataDialogController.applySeriesMetadataEdit() }

    function dismissGridOverlayMenusForScroll() {
        gridOverlayMenusSuppressed = true
        gridOverlayMenuResumeTimer.restart()
    }

    function dismissBackgroundTransientUi() {
        if (typeof topBarMenu !== "undefined" && topBarMenu
            && typeof topBarMenu.dismissOpenMenus === "function") {
            topBarMenu.dismissOpenMenus()
        }
        seriesMenuDismissToken += 1
    }

    onBackgroundModalLockActiveChanged: {
        if (backgroundModalLockActive) {
            dismissBackgroundTransientUi()
        }
    }

    function markIssueUnread(comicId) {
        if (comicId < 1) return
        const preservedSplitScroll = typeof mainLibraryPane !== "undefined" && mainLibraryPane
            ? Number(mainLibraryPane.currentSplitScroll || 0)
            : 0

        const nextItems = []
        for (let i = 0; i < issuesGridData.length; i += 1) {
            const item = issuesGridData[i]
            const id = Number(item && item.id ? item.id : 0)
            if (id !== comicId) {
                nextItems.push(item)
                continue
            }

            if (libraryReadStatusFilter === "read") {
                continue
            }

            const nextItem = Object.assign({}, item, {
                readStatus: "unread",
                currentPage: 0
            })
            nextItems.push(nextItem)
        }
        issuesGridData = nextItems
        scheduleGridSplitScrollRestore(preservedSplitScroll)

        const result = libraryModel.saveReaderProgress(comicId, 0)
        if (result.length > 0) {
            queueSilentReaderProgressSave(comicId, 0, false)
            return
        }
    }

    Timer {
        id: issuesGridRefreshDebounce
        interval: 120
        repeat: false
        running: false
        onTriggered: root.refreshIssuesGridData()
    }

    Timer {
        id: gridSplitScrollRestoreTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: root.applyPendingGridSplitScrollRestore()
    }

    Timer {
        id: readerProgressSaveRetryTimer
        interval: root.readerProgressSaveRetryDelayMs
        repeat: false
        running: false
        onTriggered: root.processQueuedReaderProgressSave()
    }

    Timer {
        id: deferredUpdatePromptTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: root.tryPresentDeferredUpdatePrompt()
    }

    Component.onCompleted: {
        migrateLibraryBackgroundImageSettingIfNeeded()
        startupDeferredUpdatePromptVersion = typeof releaseCheckService !== "undefined" && releaseCheckService
            ? String(releaseCheckService.pendingUpdatePromptVersion || "").trim()
            : ""
        startupController.handleComponentCompleted()
        if (typeof releaseCheckService !== "undefined" && releaseCheckService) {
            releaseCheckService.checkLatestReleaseIfDue()
        }
        scheduleDeferredUpdatePromptCheck()
        if (!appSettingsController.onboardingCompleted) {
            launchOnboarding(false)
        }
    }

    onClosing: function(close) {
        if (popupController.blockCloseAndHighlightCriticalPopup(close)) {
            return
        }
        startupController.handleClosing(close)
    }

    onSelectedSeriesKeyChanged: {
        scheduleSelectionDrivenRefresh()
    }

    onSelectedSeriesTitleChanged: {
        scheduleSelectionDrivenRefresh()
    }

    onStartupPrimaryContentVisibleChanged: scheduleDeferredUpdatePromptCheck()
    onStartupHydrationInProgressChanged: scheduleDeferredUpdatePromptCheck()
    onStartupReconcileCompletedChanged: scheduleDeferredUpdatePromptCheck()
    onAnyManagedModalPopupVisibleChanged: scheduleDeferredUpdatePromptCheck()
    onFirstRunOnboardingActiveChanged: scheduleDeferredUpdatePromptCheck()
    onImportInProgressChanged: scheduleDeferredUpdatePromptCheck()

    onSelectedVolumeKeyChanged: {
        scheduleSelectionDrivenRefresh()
    }

    onSelectedVolumeTitleChanged: {
        scheduleSelectionDrivenRefresh()
    }

    onLibraryReadStatusFilterChanged: {
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return
        scheduleIssuesGridRefresh(false)
        startupController.requestSnapshotSave()
    }

    onLibrarySearchTextChanged: {
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return
        scheduleIssuesGridRefresh(false)
        startupController.requestSnapshotSave()
    }

    onSidebarQuickFilterKeyChanged: {
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return
        startupController.requestSnapshotSave()
    }

    onLastImportSessionComicIdsChanged: {
        if (restoringStartupSnapshot) return
        refreshQuickFilterCounts()
        startupController.requestSnapshotSave()
    }

    onHeroCoverComicIdChanged: {
        runtimeDebugLog(
            "hero-cover",
            "root heroCoverComicId changed"
            + " selectedSeriesKey=" + String(selectedSeriesKey || "")
            + " heroCoverComicId=" + String(Number(heroCoverComicId || -1))
        )
    }

    onHeroAutoCoverSourceChanged: {
        const normalized = String(heroAutoCoverSource || "").trim().replace(/[?#].*$/, "")
        const slashPath = normalized.replace(/\\/g, "/")
        const parts = slashPath.length > 0 ? slashPath.split("/") : []
        const token = parts.length > 0 ? parts[parts.length - 1] : "<empty>"
        runtimeDebugLog(
            "hero-cover",
            "root heroAutoCoverSource changed"
            + " selectedSeriesKey=" + String(selectedSeriesKey || "")
            + " heroCoverComicId=" + String(Number(heroCoverComicId || -1))
            + " source=" + token
        )
    }

    onHeroCustomCoverSourceChanged: {
        const normalized = String(heroCustomCoverSource || "").trim().replace(/[?#].*$/, "")
        const slashPath = normalized.replace(/\\/g, "/")
        const parts = slashPath.length > 0 ? slashPath.split("/") : []
        const token = parts.length > 0 ? parts[parts.length - 1] : "<empty>"
        runtimeDebugLog(
            "hero-cover",
            "root heroCustomCoverSource changed"
            + " selectedSeriesKey=" + String(selectedSeriesKey || "")
            + " source=" + token
        )
    }

    onIssuesGridDataChanged: {
        if (restoringStartupSnapshot) return
        startupController.requestSnapshotSave()
    }

    ListModel {
        id: seriesListModel
    }

    ListModel {
        id: volumeListModel
    }

    ListModel {
        id: failedImportItemsModel
    }

    MainStartupLayer {
        id: mainStartupLayer
        rootObject: root
        startupControllerRef: startupController
        uiTokensRef: uiTokens
    }

    ColumnLayout {
        id: appContentLayout
        anchors.fill: parent
        spacing: 0
        opacity: root.startupPrimaryContentVisible ? 1.0 : 0.0
        enabled: root.startupPrimaryContentVisible && root.backgroundUiInteractive

        Behavior on opacity {
            NumberAnimation {
                duration: root.motionSlowMs
                easing.type: Easing.OutCubic
            }
        }

        TopBarMenu {
            id: topBarMenu
            Layout.fillWidth: true
            Layout.preferredHeight: root.topBarHeight
            topColor: root.bgTopbarStart
            bottomColor: root.bgTopbarEnd
            dividerColor: root.lineTopbarBottom
            textColor: root.textPrimary
            mutedTextColor: root.textMuted
            textShadowColor: root.uiTextShadow
            topEdgeColor: root.topBarInnerShadowColor
            menuTextIdleColor: root.uiMenuIdleText
            menuTextActiveColor: root.textPrimary
            menuPopupBackgroundColor: root.uiMenuBackground
            menuPopupHoverColor: root.uiMenuHoverBackground
            menuPopupTextColor: root.uiMenuText
            menuPopupDisabledTextColor: root.uiMenuTextDisabled
            windowControlIdleColor: root.uiMenuIdleText
            windowControlActiveColor: root.textPrimary
            windowControlCloseHoverColor: root.uiWindowControlCloseHover
            uiFontFamily: root.uiFontFamily
            uiFontPixelSize: root.fontPxUiBase
            importInProgress: root.importInProgress
            isFullscreen: root.visibility === Window.FullScreen
            windowMaximized: root.visibility === Window.Maximized
            hostWindow: root
            showWindowControls: root.visibility !== Window.FullScreen
            windowResizeEnabled: !windowDisplayController.displayConstrainedWindow
            windowControlRightMargin: 8
            windowControlTopMargin: 8
            windowControlButtonWidth: 24
            windowControlButtonHeight: 16
            windowControlSpacing: 0
            helperButtonsLeftMargin: root.sidebarWidth + 8
              helperButtonsBottomMargin: 8
              helperButtonsSpacing: 8
              continueReadingEnabled: navigationSurfaceController.continueReadingAvailable
              whatsNewAvailable: true
              centerLabel: root.topBarCenterLabel
              windowCornerRadius: root.windowCornerRadius
              onContinueReadingRequested: navigationSurfaceController.continueReading()
              onNextUnreadRequested: navigationSurfaceController.nextUnread()
            onAddFilesRequested: root.quickAddFilesFromDialog()
            onAddFolderRequested: root.quickAddFolderFromDialog()
              onAddIssueRequested: root.quickAddFilesFromDialog()
              onSettingsRequested: root.openSettingsDialog("")
              onWhatsNewRequested: root.openWhatsNewDialog()
              onHelpRequested: root.openHelpDialog("")
              onQuickTourRequested: root.launchOnboarding(true)
              onAboutRequested: root.openAboutDialog()
            onRefreshRequested: libraryModel.reload()
            onExitRequested: root.close()
            onToggleFullscreenRequested: {
                root.visibility = root.visibility === Window.FullScreen
                    ? Window.Windowed
                    : Window.FullScreen
            }
            onMinimizeRequested: root.showMinimized()
            onMaximizeRestoreRequested: {
                if (windowDisplayController.displayConstrainedWindow) {
                    return
                }
                if (root.visibility === Window.Maximized) {
                    root.showNormal()
                } else {
                    root.showMaximized()
                }
            }
            onCloseRequested: root.close()
            Component.onCompleted: {
                root.markStartupColdRenderOnce("topbar", "height=" + String(height))
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            MainSidebar {
                id: mainSidebar
                rootObject: root
                libraryModelRef: libraryModel
                popupControllerRef: popupController
                deleteControllerRef: deleteController
                startupControllerRef: startupController
                uiTokensRef: uiTokens
                seriesListModelRef: seriesListModel
            }

            MainLibraryPane {
                id: mainLibraryPane
                rootObject: root
                uiTokensRef: uiTokens
                heroSeriesControllerRef: heroSeriesController
                startupControllerRef: startupController
                seriesHeaderControllerRef: seriesHeaderController
                deleteControllerRef: deleteController
                metadataDialogRef: metadataDialog
            }
        }

        Rectangle {
            id: bottomBar
            Layout.fillWidth: true
            Layout.preferredHeight: root.footerHeight
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.bgBottombarStart }
                GradientStop { position: 1.0; color: root.bgBottombarEnd }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: root.lineBottombarTop
            }

            Canvas {
                id: bottomInnerShadow
                visible: root.visibility !== Window.Maximized
                    && root.visibility !== Window.FullScreen
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(2, root.windowCornerRadius + 1)
                antialiasing: true
                contextType: "2d"
                z: 2

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()

                    const w = Math.max(1, width)
                    const h = Math.max(1, height)
                    const px = 0.5
                    const r = Math.max(0, Math.min(root.windowCornerRadius, (w - 1) / 2, h - 1))
                    const fadeWidth = Math.max(1, Math.min(r + 2, w * 0.04))
                    const fadeStop = Math.max(0.001, Math.min(0.49, fadeWidth / w))

                    const grad = ctx.createLinearGradient(0, 0, w, 0)
                    grad.addColorStop(0.0, "transparent")
                    grad.addColorStop(fadeStop, root.bottomBarInnerShadowColor)
                    grad.addColorStop(1.0 - fadeStop, root.bottomBarInnerShadowColor)
                    grad.addColorStop(1.0, "transparent")

                    ctx.strokeStyle = grad
                    ctx.lineWidth = 1
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"

                    ctx.beginPath()
                    ctx.moveTo(px, h - r - px)
                    ctx.quadraticCurveTo(px, h - px, r + px, h - px)
                    ctx.lineTo(w - r - px, h - px)
                    ctx.quadraticCurveTo(w - px, h - px, w - px, h - r - px)
                    ctx.stroke()
                }

                onVisibleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }

            BottomBarHelperButton {
                x: root.sidebarWidth + 14
                y: 14
                text: navigationSurfaceController.issueOrderButtonText
                fontFamily: root.uiFontFamily
                onClicked: navigationSurfaceController.toggleIssueOrder()
            }

            BottomBarGridDensityControl {
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                uiFontFamily: root.uiFontFamily
                options: SettingsCatalog.appearanceGridDensityOptions
                currentText: String(appSettingsController.appearanceGridDensity || "Default")
                onActivated: function(index, text) {
                    appSettingsController.setSettingValue("appearance_grid_density", text)
                }
            }

        }

    }

    WindowResizeHandles {
        anchors.fill: parent
        hostWindow: root
        enabledWhenWindowed: windowDisplayController.enableWindowResizeHandles
            && root.backgroundUiInteractive
        edgeSize: 4
        cornerSize: 10
        z: 1000
    }

    MainDialogHost {
        id: mainDialogHost
        rootObject: root
        popupStyleTokensRef: popupStyleTokens
        appSettingsControllerRef: appSettingsController
        importControllerRef: importController
        popupControllerRef: popupController
        deleteControllerRef: deleteController
        readerSessionControllerRef: readerSessionController
        heroSeriesControllerRef: heroSeriesController
        startupControllerRef: startupController
        seriesHeaderControllerRef: seriesHeaderController
        libraryModelRef: libraryModel
        failedImportItemsModelRef: failedImportItemsModel
    }

    Item {
        id: firstRunOnboardingOverlay
        anchors.fill: parent
        visible: root.firstRunOnboardingActive
        z: 3000
        focus: visible
        Keys.priority: Keys.BeforeItem

        onVisibleChanged: {
            if (visible) {
                forceActiveFocus()
            }
        }

        Keys.onLeftPressed: function(event) {
            if (root.firstRunOnboardingStep === 5)
                root.firstRunOnboardingStep = 4
            else if (root.firstRunOnboardingStep === 4)
                root.firstRunOnboardingStep = 3
            else if (root.firstRunOnboardingStep === 3)
                root.firstRunOnboardingStep = 2
            else if (root.firstRunOnboardingStep === 2)
                root.firstRunOnboardingStep = 1
            event.accepted = true
        }

        Keys.onRightPressed: function(event) {
            if (root.firstRunOnboardingStep === 1)
                root.firstRunOnboardingStep = 2
            else if (root.firstRunOnboardingStep === 2)
                root.firstRunOnboardingStep = 3
            else if (root.firstRunOnboardingStep === 3)
                root.firstRunOnboardingStep = 4
            else if (root.firstRunOnboardingStep === 4)
                root.firstRunOnboardingStep = 5
            event.accepted = true
        }

        Keys.onEscapePressed: function(event) {
            root.closeOnboarding()
            event.accepted = true
        }

        Canvas {
            id: firstRunOverlayCanvas
            anchors.fill: parent
            contextType: "2d"
            visible: root.firstRunOnboardingStep !== 5

            function cutRoundedRect(ctx, x, y, w, h, r) {
                const radius = Math.max(0, Math.min(r, w / 2, h / 2))
                ctx.beginPath()
                ctx.moveTo(x + radius, y)
                ctx.lineTo(x + w - radius, y)
                ctx.quadraticCurveTo(x + w, y, x + w, y + radius)
                ctx.lineTo(x + w, y + h - radius)
                ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h)
                ctx.lineTo(x + radius, y + h)
                ctx.quadraticCurveTo(x, y + h, x, y + h - radius)
                ctx.lineTo(x, y + radius)
                ctx.quadraticCurveTo(x, y, x + radius, y)
                ctx.closePath()
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                ctx.fillStyle = popupStyleTokens.overlayColor
                ctx.fillRect(0, 0, width, height)

                ctx.save()
                ctx.globalCompositeOperation = "destination-out"
                firstRunOverlayCanvas.cutRoundedRect(
                    ctx,
                    Math.round(primaryHighlight.x),
                    Math.round(primaryHighlight.y),
                    Math.round(primaryHighlight.width),
                    Math.round(primaryHighlight.height),
                    Math.max(0, Math.round(primaryHighlight.radius))
                )
                if (secondaryHighlight.visible) {
                    firstRunOverlayCanvas.cutRoundedRect(
                        ctx,
                        Math.round(secondaryHighlight.x),
                        Math.round(secondaryHighlight.y),
                        Math.round(secondaryHighlight.width),
                        Math.round(secondaryHighlight.height),
                        Math.max(0, Math.round(secondaryHighlight.radius))
                    )
                }
                ctx.fill()
                ctx.restore()
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        Rectangle {
            visible: root.firstRunOnboardingStep === 5
            x: 0
            y: root.topBarHeight
            width: root.width
            height: Math.max(0, root.height - root.topBarHeight - root.footerHeight)
            color: popupStyleTokens.overlayColor
            z: 0
        }

        Rectangle {
            id: primaryHighlight
            x: root.firstRunOnboardingStep === 3
                ? Math.round(mainLibraryPane.mapToItem(firstRunOnboardingOverlay, 0, 0).x)
                : root.firstRunOnboardingStep === 4
                    ? Math.round(mainLibraryPane.mapToItem(firstRunOnboardingOverlay, 0, mainLibraryPane.onboardingGridViewportY).x)
                    : root.firstRunOnboardingStep === 5
                        ? 0
                    : root.firstRunSidebarHighlightX
            y: root.firstRunOnboardingStep === 1
                ? root.firstRunStep1HighlightY
                : root.firstRunOnboardingStep === 3
                    ? Math.round(mainLibraryPane.mapToItem(firstRunOnboardingOverlay, 0, 0).y)
                    : root.firstRunOnboardingStep === 4
                        ? Math.round(mainLibraryPane.mapToItem(firstRunOnboardingOverlay, 0, mainLibraryPane.onboardingGridViewportY).y)
                        : root.firstRunOnboardingStep === 5
                            ? 0
                        : root.topBarHeight
            width: root.firstRunOnboardingStep === 3
                ? Math.round(mainLibraryPane.width)
                : root.firstRunOnboardingStep === 4
                    ? Math.round(mainLibraryPane.width)
                    : root.firstRunOnboardingStep === 5
                        ? root.width
                    : root.firstRunDropZoneHighlightWidth
            height: root.firstRunOnboardingStep === 1
                ? root.firstRunDropZoneStep1HighlightHeight
                : root.firstRunOnboardingStep === 2
                    ? root.firstRunStep2HighlightHeightAdaptive
                    : root.firstRunOnboardingStep === 3
                        ? Math.round(mainLibraryPane.onboardingHeroHeight)
                    : root.firstRunOnboardingStep === 4
                        ? Math.round(mainLibraryPane.onboardingGridViewportHeight)
                    : root.firstRunOnboardingStep === 5
                        ? root.topBarHeight
                    : root.firstRunDropZoneStep2HighlightHeight
            radius: root.firstRunOnboardingStep === 5 ? root.windowCornerRadius : root.firstRunDropZoneHighlightRadius
            color: "transparent"
            border.width: 2
            border.color: "#FFFFFF"

            onXChanged: firstRunOverlayCanvas.requestPaint()
            onYChanged: firstRunOverlayCanvas.requestPaint()
            onWidthChanged: firstRunOverlayCanvas.requestPaint()
            onHeightChanged: firstRunOverlayCanvas.requestPaint()
            onRadiusChanged: firstRunOverlayCanvas.requestPaint()
        }

        Rectangle {
            id: secondaryHighlight
            visible: root.firstRunOnboardingStep === 5
            x: 0
            y: root.height - root.footerHeight
            width: root.width
            height: root.footerHeight
            radius: root.windowCornerRadius
            color: "transparent"
            border.width: 2
            border.color: "#FFFFFF"

            onVisibleChanged: firstRunOverlayCanvas.requestPaint()
            onXChanged: firstRunOverlayCanvas.requestPaint()
            onYChanged: firstRunOverlayCanvas.requestPaint()
            onWidthChanged: firstRunOverlayCanvas.requestPaint()
            onHeightChanged: firstRunOverlayCanvas.requestPaint()
            onRadiusChanged: firstRunOverlayCanvas.requestPaint()
        }

        Item {
            id: onboardingDropZoneContent
            x: Math.round((root.sidebarWidth - root.firstRunDropZoneWidth) / 2)
            y: Math.round(
                root.height
                - root.footerHeight
                - root.firstRunDropZoneBottomMargin
                - root.firstRunDropZoneHeight
            )
            width: root.firstRunDropZoneWidth
            height: root.firstRunDropZoneHeight
            visible: root.firstRunOnboardingStep === 1

            Image {
                width: 52
                height: 55
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                source: uiTokens.dropZoneWhiteIcon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                id: onboardingDropZoneTitle
                anchors.top: parent.top
                anchors.topMargin: 85
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: root.uiFontFamily
                font.pixelSize: root.fontPxDropTitle
                font.bold: true
                color: "#FFFFFF"
                text: AppText.sidebarDropZoneTitle
            }

            Column {
                anchors.top: onboardingDropZoneTitle.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    font.family: root.uiFontFamily
                    font.pixelSize: root.fontPxDropSubtitle
                    color: "#FFFFFF"
                    text: AppText.sidebarDropZoneSubtitleLineOne
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Text {
                        font.family: root.uiFontFamily
                        font.pixelSize: root.fontPxDropSubtitle
                        color: "#FFFFFF"
                        text: AppText.sidebarDropZoneSubtitleLineTwoPrefix
                    }

                    Text {
                        font.family: root.uiFontFamily
                        font.pixelSize: root.fontPxDropSubtitle
                        font.underline: true
                        color: "#FFFFFF"
                        text: AppText.sidebarDropZoneSubtitleLink
                    }
                }
            }
        }

        Image {
            id: onboardingStep1Bubble
            visible: root.firstRunOnboardingStep !== 5
            anchors.left: parent.left
            anchors.leftMargin: root.firstRunOnboardingStep === 1
                ? 334
                : root.firstRunOnboardingStep === 2
                    ? 336
                    : root.firstRunOnboardingStep === 3
                    ? Math.round(primaryHighlight.x + (primaryHighlight.width - width) / 2)
                        : root.firstRunOnboardingStep === 4
                            ? Math.round(primaryHighlight.x + (primaryHighlight.width - width) / 2)
                        : root.firstRunStep5BubbleLeftMargin
            anchors.top: parent.top
            anchors.topMargin: root.firstRunOnboardingStep === 1 ? (root.height - 146 - height)
                : root.firstRunOnboardingStep === 2 ? 172
                : root.firstRunOnboardingStep === 3
                    ? Math.round(primaryHighlight.y + root.firstRunStep3BubbleOffsetFromHeroTop)
                    : root.firstRunOnboardingStep === 4
                        ? Math.round(primaryHighlight.y - height)
                        : root.firstRunStep5BubbleTopMargin
            source: root.firstRunOnboardingStep === 1
                ? uiTokens.onboardingStep1Bubble
                : root.firstRunOnboardingStep === 2
                    ? uiTokens.onboardingStep2Bubble
                    : root.firstRunOnboardingStep === 3
                        ? uiTokens.onboardingStep3Bubble
                        : root.firstRunOnboardingStep === 4
                            ? uiTokens.onboardingStep4Bubble
                            : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Image {
            id: onboardingStep5TopBubble
            visible: root.firstRunOnboardingStep === 5
            x: Math.round(primaryHighlight.x + (primaryHighlight.width - width) / 2 + root.firstRunStep5TopBubbleOffsetX)
            y: Math.round(primaryHighlight.y + root.firstRunStep5BubbleTopMargin)
            source: uiTokens.onboardingStep5BubbleTop
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Image {
            id: onboardingStep5BottomBubble
            visible: root.firstRunOnboardingStep === 5
            x: Math.round(secondaryHighlight.x + (secondaryHighlight.width - width) / 2)
            y: Math.round(secondaryHighlight.y - root.firstRunStep5BottomBubbleBottomGap - height)
            source: uiTokens.onboardingStep5BubbleBottom
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Item {
            id: onboardingNavigationBlockFull
            width: 182
            height: 23
            x: onboardingStep1Bubble.x
                + (root.firstRunOnboardingStep === 2 ? 367
                    : root.firstRunOnboardingStep === 3 ? 603
                    : 671)
                - (width / 2)
            y: onboardingStep1Bubble.y
                + onboardingStep1Bubble.height
                - (root.firstRunOnboardingStep === 2 ? 125
                    : root.firstRunOnboardingStep === 3 ? 154
                    : 92)
                - (height / 2)
            visible: root.firstRunOnboardingStep === 2
                || root.firstRunOnboardingStep === 3
                || root.firstRunOnboardingStep === 4

            Item {
                id: onboardingBackButtonHitbox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 84
                height: 21

                Image {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: onboardingBackMouseArea.containsMouse ? -2 : 0
                    source: uiTokens.onboardingBackButton
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: onboardingBackMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.firstRunOnboardingStep === 5)
                            root.firstRunOnboardingStep = 4
                        else if (root.firstRunOnboardingStep === 4)
                            root.firstRunOnboardingStep = 3
                        else if (root.firstRunOnboardingStep === 3)
                            root.firstRunOnboardingStep = 2
                        else
                            root.firstRunOnboardingStep = 1
                    }
                }
            }

            Item {
                id: onboardingNextButtonHitbox
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 76
                height: 21

                Image {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: onboardingNextMouseArea.containsMouse ? -2 : 0
                    source: uiTokens.onboardingNextButton
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: onboardingNextMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.firstRunOnboardingStep === 2)
                            root.firstRunOnboardingStep = 3
                        else if (root.firstRunOnboardingStep === 3)
                            root.firstRunOnboardingStep = 4
                        else if (root.firstRunOnboardingStep === 4)
                            root.firstRunOnboardingStep = 5
                    }
                }
            }

            Image {
                id: onboardingFullMenuSlash
                x: 95 - (width / 2)
                y: height - 10 - (height / 2)
                source: uiTokens.onboardingSlash
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Item {
            id: onboardingNavigationBlockCompact
            width: 94
            height: 23
            x: onboardingStep1Bubble.x + 294 - (width / 2)
            y: onboardingStep1Bubble.y + onboardingStep1Bubble.height - 290 - (height / 2)
            visible: root.firstRunOnboardingStep === 1

            Image {
                id: onboardingCompactMenuSlash
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2
                source: uiTokens.onboardingSlash
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Item {
                id: onboardingCompactNextButtonHitbox
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 76
                height: 21

                Image {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: onboardingCompactNextMouseArea.containsMouse ? -2 : 0
                    source: uiTokens.onboardingNextButton
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: onboardingCompactNextMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.firstRunOnboardingStep = 2
                }
            }
        }

        Item {
            id: onboardingNavigationBlockFinal
            width: 182
            height: 23
            x: onboardingStep5BottomBubble.x + root.firstRunStep5NavOffsetXFromBubbleLeft - (width / 2)
            y: onboardingStep5BottomBubble.y
                + onboardingStep5BottomBubble.height
                - root.firstRunStep5NavBottomInsetFromBubbleBottom
                - root.firstRunStep5NavLift
                - (height / 2)
            visible: root.firstRunOnboardingStep === 5
            z: 20
            opacity: 1.0

            Item {
                id: onboardingFinalBackButtonHitbox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 84
                height: 21

                Image {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: onboardingFinalBackMouseArea.containsMouse ? -2 : 0
                    source: uiTokens.onboardingBackButton
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    z: 1
                }

                MouseArea {
                    id: onboardingFinalBackMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.firstRunOnboardingStep = 4
                }
            }

            Item {
                id: onboardingFinalCloseButtonHitbox
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 76
                height: 21

                Image {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: onboardingFinalCloseNavMouseArea.containsMouse ? -2 : 0
                    source: uiTokens.onboardingCloseNavButton
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    z: 1
                }

                MouseArea {
                    id: onboardingFinalCloseNavMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeOnboarding()
                }
            }

            Image {
                x: 95 - (width / 2)
                y: height - 10 - (height / 2)
                source: uiTokens.onboardingSlash
                fillMode: Image.PreserveAspectFit
                smooth: true
                z: 1
            }
        }

        Rectangle {
            id: onboardingCloseButton
            width: 32
            height: 32
            radius: 16
            color: onboardingCloseMouseArea.containsMouse ? "#303030" : "#000000"
            x: root.firstRunOnboardingStep === 5
                ? onboardingStep5BottomBubble.x + root.firstRunStep5CloseOffsetXFromBubbleLeft
                : onboardingStep1Bubble.x
                    + (root.firstRunOnboardingStep === 1 ? 487
                        : root.firstRunOnboardingStep === 2 ? 504
                        : root.firstRunOnboardingStep === 3 ? 749
                        : 856)
                - (width / 2)
            y: root.firstRunOnboardingStep === 5
                ? onboardingStep5BottomBubble.y
                    + onboardingStep5BottomBubble.height
                    - root.firstRunStep5CloseBottomInsetFromBubbleBottom
                : onboardingStep1Bubble.y
                    + onboardingStep1Bubble.height
                    - (root.firstRunOnboardingStep === 1 ? 584
                        : root.firstRunOnboardingStep === 2 ? 339
                        : root.firstRunOnboardingStep === 3 ? 367
                        : 364)
                - (height / 2)

            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 2
                radius: 1
                color: "#FFFFFF"
                rotation: 45
            }

            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 2
                radius: 1
                color: "#FFFFFF"
                rotation: -45
            }

            MouseArea {
                id: onboardingCloseMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeOnboarding()
            }
        }
    }

    Connections {
        target: libraryModel

        function onSeriesHeroReady(requestId, seriesKey, imageSource, error) {
            seriesHeaderController.handleSeriesHeroReady(requestId, seriesKey, imageSource, error)
        }

        function onStatusChanged() {
            const liveError = String(libraryModel.lastError || "").trim()
            if (liveError.length > 0) {
                if (root.lastPresentedLibraryLoadError !== liveError) {
                    root.lastPresentedLibraryLoadError = liveError
                    root.presentLibraryLoadError(liveError)
                }
                return
            }
            root.lastPresentedLibraryLoadError = ""
        }
    }

    Timer {
        id: gridOverlayMenuResumeTimer
        interval: root.gridOverlayMenuPostScrollDelayMs
        repeat: false
        onTriggered: root.gridOverlayMenusSuppressed = false
    }

    Timer {
        id: postImportCurrentSeriesRefreshTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (!root.selectedSeriesContext || !root.selectedSeriesContext.hasSeries) return
            root.refreshIssuesGridData(true)
            root.primeVisibleIssueCoverSourcesFromCache()
            root.warmVisibleIssueThumbnails()
            heroSeriesController.resolveHeroMediaForSelectedSeries()
        }
    }
}






