import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "components/PublisherCatalog.js" as PublisherCatalog
import "controllers"

ApplicationWindow {
    id: root
    width: windowDisplayController.defaultWindowWidth
    height: windowDisplayController.defaultWindowHeight
    minimumWidth: windowDisplayController.displayConstrainedWindow ? 1 : windowDisplayController.defaultWindowWidth
    minimumHeight: windowDisplayController.displayConstrainedWindow ? 1 : windowDisplayController.defaultWindowHeight
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint
    title: uiTokens.appWindowTitle
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

    readonly property string libraryBackgroundMode: String(appSettingsController.appearanceLibraryBackground || "Default")
    readonly property color libraryBackgroundSolidColor: appSettingsController.appearanceLibraryBackgroundSolidColor
    readonly property string libraryBackgroundTexturePreset: String(
        appSettingsController.appearanceLibraryBackgroundTexture || "Dots"
    )
    readonly property string libraryBackgroundCustomImagePath: String(
        appSettingsController.appearanceLibraryBackgroundCustomImagePath || ""
    )
    readonly property string libraryBackgroundCustomImageMode: String(
        appSettingsController.appearanceLibraryBackgroundImageMode || "Fill"
    )
    readonly property string libraryBackgroundCustomImageSource: String(
        startupController.toLocalFileUrl(libraryBackgroundCustomImagePath) || ""
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
    readonly property string libraryTextureSource: libraryBackgroundTexturePreset === "Noise"
        ? uiTokens.sidebarNoiseTexture
        : uiTokens.gridTile
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
    property int motionFastMs: 120
    property int motionBaseMs: 180
    property int motionSlowMs: 260
    property real shadowSoftOpacity: 0.28
    property real shadowHeavyOpacity: 0.45

    property var selectedIds: ({})
    property var editingComic: null
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
    property string editingSeriesKey: ""
    property var editingSeriesKeys: []
    property string editingSeriesTitle: ""
    property string editingSeriesDialogMode: "single"
    property var pendingSeriesMetadataSuggestion: ({})
    property var pendingIssueMetadataSuggestion: ({})
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
    readonly property var seriesMetaDialog: mainDialogHost.seriesMetaDialogRef
    readonly property var settingsDialog: mainDialogHost.settingsDialogRef
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
    property string readerViewMode: "one_page"
    property string readerSeriesKey: ""
    readonly property int readerIssueIndexInSeries: readerSessionController.issueIndexInSeries
    readonly property int readerIssueCountInSeries: readerSessionController.issueCountInSeries
    readonly property bool readerHasPreviousIssue: readerIssueIndexInSeries > 0
    readonly property bool readerHasNextIssue: readerIssueIndexInSeries >= 0
        && readerIssueIndexInSeries + 1 < readerIssueCountInSeries
    readonly property bool readerCanGoPreviousPage: readerSessionController.canGoPreviousPage
    readonly property bool readerCanGoNextPage: readerSessionController.canGoNextPage
    property string selectedSeriesKey: ""
    property string selectedSeriesTitle: ""
    property var selectedSeriesKeys: ({})
    property int seriesSelectionAnchorIndex: -1
    property string selectedVolumeKey: "__all__"
    property string selectedVolumeTitle: "All volumes"
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
    property string sidebarSearchText: ""
    property string sidebarQuickFilterKey: ""
    property var lastImportSessionComicIds: []
    property int quickFilterLastImportCount: 0
    property int quickFilterFavoritesCount: 0
    property int quickFilterBookmarksCount: 0
    readonly property var activeIssuesFlick: (typeof mainLibraryPane !== "undefined" && mainLibraryPane)
        ? mainLibraryPane.activeIssuesFlick
        : null
    property string librarySearchText: ""
    property string libraryReadStatusFilter: "all"
    property bool gridSplitScrollRestorePending: false
    property real pendingGridSplitScrollValue: 0
    property bool libraryLoading: false
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
        seriesHeaderDialogRef: seriesHeaderDialog
        deleteConfirmDialogRef: deleteConfirmDialog
        deleteErrorDialogRef: deleteErrorDialog
    }

    property string sevenZipConfiguredPath: ""
    property string sevenZipEffectivePath: ""
    property alias criticalPopupAttentionTarget: popupController.criticalPopupAttentionTarget
    property color criticalPopupAttentionColor: themeColors.dialogAttentionColor
    property alias importInProgress: importController.importInProgress
    readonly property bool anyManagedModalPopupVisible: popupController.anyManagedModalPopupVisible
    readonly property bool anyCriticalPopupVisible: popupController.anyCriticalPopupVisible
    property alias importTotal: importController.importTotal
    property alias importProcessed: importController.importProcessed
    property alias importTotalBytes: importController.importTotalBytes
    property alias importProcessedBytes: importController.importProcessedBytes
    property alias importImportedCount: importController.importImportedCount
    property alias importErrorCount: importController.importErrorCount
    property alias importCancelRequested: importController.importCancelRequested
    property alias importCurrentPath: importController.importCurrentPath
    property alias importCurrentFileName: importController.importCurrentFileName
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

    function issuesGridMatchesSelectedSeries() {
        const selectedTitle = String(selectedSeriesTitle || "").trim()
        if (selectedTitle.length < 1 || issuesGridData.length < 1) return false
        const gridTitle = displaySeriesTitleForIssue(issuesGridData[0])
        return gridTitle.length > 0 && gridTitle === selectedTitle
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
            popupController.showActionResult(String(emptyMessage || "No supported comic sources found for import."), true)
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

    function reloadLibraryFromSettings() {
        libraryModel.reload()
    }

    function openSettingsDialog(sectionKey) {
        const requested = String(sectionKey || "").trim()
        settingsDialog.requestedSection = requested
        popupController.openExclusivePopup(settingsDialog)
    }

    function presentLibraryLoadError(messageText) {
        const message = String(messageText || "").trim()
        if (message.length < 1) return
        popupController.actionResultTitle = "Library load failed"
        popupController.showActionResultWithAction(
            message,
            "Check the library data location in Settings and try reloading the library.",
            "Open Settings",
            "open_library_data_settings"
        )
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
            popupController.showActionResult(
                String((result || {}).error || "Failed to schedule the new library data location."),
                true
            )
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
            popupController.showActionResult("Series folder is unavailable.", true)
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
        popupController.showActionResult("No folder is available for " + label + ".", true)
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
        sevenZipConfiguredPath = String(libraryModel.configuredSevenZipExecutablePath() || "")
        sevenZipEffectivePath = String(libraryModel.effectiveSevenZipExecutablePath() || "")
    }

    function chooseSevenZipPathFromSettings() {
        const initialPath = String(sevenZipConfiguredPath || sevenZipEffectivePath || "")
        const selectedPath = String(libraryModel.browseArchiveFile(initialPath) || "")
        if (selectedPath.length < 1) return

        const applyError = String(libraryModel.setSevenZipExecutablePath(selectedPath) || "").trim()
        if (applyError.length > 0) {
            popupController.showActionResult(applyError, true)
            return
        }

        refreshCbrSupportState()
        startupController.requestSnapshotSave()
    }

    function verifySevenZipFromSettings() {
        refreshCbrSupportState()
    }

    function chooseLibraryBackgroundImageFromSettings() {
        const currentPath = String(
            appSettingsController.settingValue("appearance_library_background_custom_image_path", "") || ""
        )
        const selectedPath = String(libraryModel.browseImageFile(currentPath) || "")
        if (selectedPath.length < 1) return

        const limitBytes = libraryBackgroundCustomImageMode === "Tile"
            ? libraryBackgroundTileImageMaxBytes
            : libraryBackgroundImageMaxBytes
        const sizeBytes = fileSizeBytes(selectedPath)
        if (sizeBytes > limitBytes) {
            const label = libraryBackgroundCustomImageMode === "Tile" ? "1 MB" : "8 MB"
            popupController.showActionResult(
                "Selected background image is too large. Limit for this mode is " + label + ".",
                true
            )
            return
        }

        appSettingsController.setSettingValue("appearance_library_background_custom_image_path", selectedPath)
        appSettingsController.setSettingValue("appearance_library_background", "Custom image")
    }

    function setLibraryBackgroundImageModeFromSettings(nextMode) {
        const mode = String(nextMode || "").trim()
        if (mode.length < 1) return
        if (mode === "Tile") {
            const currentPath = String(
                appSettingsController.settingValue("appearance_library_background_custom_image_path", "") || ""
            )
            if (currentPath.length > 0) {
                const sizeBytes = fileSizeBytes(currentPath)
                if (sizeBytes > libraryBackgroundTileImageMaxBytes) {
                    popupController.showActionResult(
                        "Tile mode supports background images up to 1 MB.",
                        true
                    )
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

    function quickAddFilesForSeries(seriesTitle) {
        if (importInProgress) return
        const selected = libraryModel.browseArchiveFiles("")
        if (!selected || selected.length < 1) return
        const overrideSeries = String(seriesTitle || "").trim()
        if (overrideSeries.length > 0) {
            startImportFromSourcePaths(
                selected,
                { seriesOverride: overrideSeries, importIntent: "series_add" },
                "No Supported Archives Found in Selected Files."
            )
            return
        }
        startImportFromSourcePaths(
            selected,
            { importIntent: "global_add" },
            "No Supported Archives Found in Selected Files."
        )
    }

    function replaceIssueArchive(comicId) {
        if (comicId < 1) return
        if (importInProgress) {
            popupController.showActionResult("Import is already running. Wait for completion.", true)
            return
        }

        const loaded = libraryModel.loadComicMetadata(comicId)
        if (loaded && loaded.error) {
            return
        }

        const currentFilePath = String((loaded || {}).filePath || "")
        const selectedPath = libraryModel.browseArchiveFile(currentFilePath)
        if (selectedPath.length < 1) return

        const unsupportedReason = String(libraryModel.importArchiveUnsupportedReason(selectedPath) || "")
        if (unsupportedReason.length > 0) {
            popupController.showActionResult(unsupportedReason, true)
            return
        }

        const result = libraryModel.replaceComicFileFromSourceEx(
            comicId,
            selectedPath,
            "archive",
            "",
            ({})
        )
        if (!Boolean((result || {}).ok)) {
            const replaceError = String((result || {}).error || "Replace failed.")
            if (isSilentReplaceStateError(replaceError)) {
                return
            }
            popupController.showActionResult(replaceError, true)
            return
        }

        heroSeriesController.resolveHeroMediaForSelectedSeries()
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
            selectedSeriesKey = ""
            selectedSeriesTitle = ""
            selectedSeriesKeys = ({})
            seriesSelectionAnchorIndex = -1
            selectedVolumeKey = "__all__"
            selectedVolumeTitle = "All volumes"
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
        selectedSeriesTitle = String((firstItem && firstItem.seriesTitle) || "")
        selectedSeriesKey = String((firstItem && firstItem.seriesKey) || "")
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

    function refreshQuickFilterCounts() {
        quickFilterLastImportCount = libraryModel.quickFilterIssueCount("last_import", lastImportSessionComicIds)
        quickFilterFavoritesCount = libraryModel.quickFilterIssueCount("favorites", lastImportSessionComicIds)
        quickFilterBookmarksCount = libraryModel.quickFilterIssueCount("bookmarks", lastImportSessionComicIds)
    }

    function sidebarQuickFilterCount(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return quickFilterLastImportCount
        if (key === "favorites") return quickFilterFavoritesCount
        if (key === "bookmarks") return quickFilterBookmarksCount
        return 0
    }

    function quickFilterTitleText(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return "Last imported issues"
        if (key === "favorites") return "Favorite issues"
        if (key === "bookmarks") return "Bookmarked issues"
        return ""
    }

    function quickFilterEmptyText(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return "No recent import yet"
        if (key === "favorites") return "No favorite issues yet"
        if (key === "bookmarks") return "No bookmarked issues yet"
        return ""
    }

    function quickFilterTitleIconSource(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key === "last_import") return uiTokens.quickFilterTitleLastImportIcon
        if (key === "favorites") return uiTokens.quickFilterTitleFavoriteIcon
        if (key === "bookmarks") return uiTokens.quickFilterTitleBookmarkIcon
        return ""
    }

    function isQuickFilterModeActive() {
        return String(sidebarQuickFilterKey || "").trim().length > 0
    }

    function resetLastImportSession() {
        lastImportSessionComicIds = []
        refreshQuickFilterCounts()
        if (String(sidebarQuickFilterKey || "") === "last_import") {
            setGridScrollToTop()
            scheduleIssuesGridRefresh(true)
        }
        startupController.requestSnapshotSave()
    }

    function rememberLastImportComicId(comicId) {
        const normalizedComicId = Number(comicId || 0)
        if (normalizedComicId < 1) return

        const nextIds = []
        nextIds.push(normalizedComicId)
        const existingIds = Array.isArray(lastImportSessionComicIds) ? lastImportSessionComicIds : []
        for (let i = 0; i < existingIds.length; i += 1) {
            const existingId = Number(existingIds[i] || 0)
            if (existingId < 1 || existingId === normalizedComicId) continue
            nextIds.push(existingId)
        }
        lastImportSessionComicIds = nextIds
        refreshQuickFilterCounts()
        if (String(sidebarQuickFilterKey || "") === "last_import") {
            scheduleIssuesGridRefresh(true)
        }
        startupController.requestSnapshotSave()
    }

    function selectSidebarQuickFilter(filterKey) {
        const key = String(filterKey || "").trim().toLowerCase()
        if (key.length < 1) return
        sidebarQuickFilterKey = key
        clearSelection()
        setGridScrollToTop()
        if (typeof mainLibraryPane !== "undefined") {
            mainLibraryPane.heroCollapseOffset = 0
        }
        scheduleIssuesGridRefresh(true)
        startupController.requestSnapshotSave()
    }

    function refreshSeriesList() {
        const groups = libraryModel.seriesGroups().slice(0)
        if (
            startupSnapshotApplied
                && startupHydrationInProgress
                && groups.length < 1
                && seriesListModel.count > 0
        ) {
            startupController.startupLog("refreshSeriesList keep snapshot: live groups empty during hydration")
            return
        }
        groups.sort(function(a, b) {
            const left = String(a.seriesTitle || "").toLowerCase()
            const right = String(b.seriesTitle || "").toLowerCase()
            if (left < right) return -1
            if (left > right) return 1
            return 0
        })

        const searchNeedle = String(sidebarSearchText || "").trim().toLowerCase()
        seriesListModel.clear()
        for (let i = 0; i < groups.length; i += 1) {
            const item = groups[i]
            const title = String(item.seriesTitle || "")
            if (searchNeedle.length > 0 && title.toLowerCase().indexOf(searchNeedle) < 0) {
                continue
            }
            seriesListModel.append({
                seriesKey: String(item.seriesKey || ""),
                seriesTitle: title,
                count: Number(item.count || 0)
            })
        }

        libraryLoading = false

        if (applyConfiguredLaunchViewAfterRefreshIfNeeded()) {
            return
        }

        if (seriesListModel.count < 1) {
            clearImportSeriesFocusState()
            selectedSeriesKey = ""
            selectedSeriesTitle = ""
            selectedSeriesKeys = ({})
            seriesSelectionAnchorIndex = -1
            selectedVolumeKey = "__all__"
            selectedVolumeTitle = "All volumes"
            volumeListModel.clear()
            heroSeriesController.resolveHeroMediaForSelectedSeries()
            heroSeriesController.refreshSeriesData()
            refreshQuickFilterCounts()
            return
        }

        if (applyPendingImportedSeriesFocus()) {
            heroSeriesController.resolveHeroMediaForSelectedSeries()
            heroSeriesController.refreshSeriesData()
            refreshQuickFilterCounts()
            return
        }

        const preservedSelection = {}
        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i)
            const key = String(item.seriesKey || "")
            if (selectedSeriesKeys[key] === true) {
                preservedSelection[key] = true
            }
        }
        selectedSeriesKeys = preservedSelection

        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i)
            if (item.seriesKey === selectedSeriesKey) {
                selectedSeriesTitle = item.seriesTitle
                if (!isSeriesSelected(selectedSeriesKey)) {
                    const next = Object.assign({}, selectedSeriesKeys)
                    next[String(selectedSeriesKey)] = true
                    selectedSeriesKeys = next
                }
                seriesSelectionAnchorIndex = i
                refreshVolumeList()
                heroSeriesController.resolveHeroMediaForSelectedSeries()
                heroSeriesController.refreshSeriesData()
                refreshQuickFilterCounts()
                return
            }
        }

        selectedSeriesTitle = seriesListModel.get(0).seriesTitle
        selectedSeriesKey = seriesListModel.get(0).seriesKey
        const nextSelection = {}
        nextSelection[String(selectedSeriesKey)] = true
        selectedSeriesKeys = nextSelection
        seriesSelectionAnchorIndex = 0
        refreshVolumeList()
        heroSeriesController.resolveHeroMediaForSelectedSeries()
        heroSeriesController.refreshSeriesData()
        refreshQuickFilterCounts()
    }

    function applyVolumeSelectionByIndex(index) {
        if (index < 0 || index >= volumeListModel.count) {
            selectedVolumeKey = "__all__"
            selectedVolumeTitle = "All volumes"
            return
        }
        const item = volumeListModel.get(index)
        selectedVolumeKey = String(item.volumeKey || "__all__")
        selectedVolumeTitle = String(item.volumeTitle || "All volumes")
    }

    function refreshVolumeList() {
        const previousKey = selectedVolumeKey
        const groups = selectedSeriesKey.length > 0
            ? libraryModel.volumeGroupsForSeries(selectedSeriesKey)
            : []

        volumeListModel.clear()

        let totalCount = 0
        for (let i = 0; i < groups.length; i += 1) {
            totalCount += Number(groups[i].count || 0)
        }

        volumeListModel.append({
            volumeKey: "__all__",
            volumeTitle: "All volumes",
            count: totalCount,
            displayLabel: "All volumes (" + totalCount + ")"
        })

        let restoredIndex = 0
        for (let i = 0; i < groups.length; i += 1) {
            const item = groups[i]
            const volumeKey = String(item.volumeKey || "")
            const volumeTitle = String(item.volumeTitle || "No Volume")
            const count = Number(item.count || 0)
            volumeListModel.append({
                volumeKey: volumeKey,
                volumeTitle: volumeTitle,
                count: count,
                displayLabel: volumeTitle + " (" + count + ")"
            })
            if (volumeKey === previousKey) {
                restoredIndex = i + 1
            }
        }

        applyVolumeSelectionByIndex(restoredIndex)
    }

    function refreshIssuesGridData(preserveSplitScroll) {
        const shouldPreserveSplitScroll = preserveSplitScroll === true
        const preservedSplitScroll = shouldPreserveSplitScroll && typeof mainLibraryPane !== "undefined" && mainLibraryPane
            ? Number(mainLibraryPane.currentSplitScroll || 0)
            : 0

        if (isQuickFilterModeActive()) {
            refreshQuickFilterGridData(shouldPreserveSplitScroll, preservedSplitScroll)
            return
        }

        refreshSeriesGridData(shouldPreserveSplitScroll, preservedSplitScroll)
    }

    function refreshQuickFilterGridData(shouldPreserveSplitScroll, preservedSplitScroll) {
        const activeQuickFilterKey = String(sidebarQuickFilterKey || "").trim().toLowerCase()
        issuesGridData = libraryModel.issuesForQuickFilter(activeQuickFilterKey, lastImportSessionComicIds)
        primeVisibleIssueCoverSourcesFromCache()
        if (startupReconcileCompleted || !startupSnapshotApplied) {
            warmVisibleIssueThumbnails()
        } else {
            startupController.startupLog("defer warmVisibleIssueThumbnails until first reconcile")
        }
        refreshQuickFilterCounts()
        if (shouldPreserveSplitScroll) {
            scheduleGridSplitScrollRestore(preservedSplitScroll)
        }
    }

    function refreshSeriesGridData(shouldPreserveSplitScroll, preservedSplitScroll) {
        if (selectedSeriesKey.length < 1) {
            if (startupSnapshotApplied && startupHydrationInProgress && issuesGridData.length > 0) {
                startupController.startupLog("refreshIssuesGridData keep snapshot: selectedSeriesKey empty during hydration")
                return
            }
            issuesGridData = []
            return
        }

        const liveIssues = libraryModel.issuesForSeries(
            selectedSeriesKey,
            selectedVolumeKey,
            libraryReadStatusFilter,
            librarySearchText
        )
        if (
            startupSnapshotApplied
                && !startupHydrationInProgress
                && liveIssues.length < 1
                && selectedVolumeKey === "__all__"
                && String(librarySearchText || "").trim().length < 1
                && String(libraryReadStatusFilter || "all") === "all"
                && !startupSnapshotLiveReloadRequested
        ) {
            startupSnapshotLiveReloadRequested = true
            startupController.startupLog("refreshIssuesGridData request live reload for key=" + String(selectedSeriesKey))
            libraryModel.reload()
        }
        if (startupSnapshotApplied && startupHydrationInProgress) {
            if (liveIssues.length < 1 && issuesGridData.length > 0) {
                startupController.startupLog("refreshIssuesGridData keep snapshot: live issues empty during hydration")
            } else if (startupController.issueListsEquivalentByIdAndOrder(issuesGridData, liveIssues)) {
                startupController.startupLog("refreshIssuesGridData keep snapshot: live issues equivalent during hydration")
            } else {
                issuesGridData = liveIssues
            }
        } else {
            issuesGridData = liveIssues
        }
        primeVisibleIssueCoverSourcesFromCache()
        if (startupReconcileCompleted || !startupSnapshotApplied) {
            warmVisibleIssueThumbnails()
        } else {
            startupController.startupLog("defer warmVisibleIssueThumbnails until first reconcile")
        }

        if (shouldPreserveSplitScroll) {
            scheduleGridSplitScrollRestore(preservedSplitScroll)
        }
        refreshQuickFilterCounts()
    }

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

    function scheduleIssuesGridRefresh(immediate, preserveSplitScroll) {
        if (immediate === true) {
            issuesGridRefreshDebounce.stop()
            refreshIssuesGridData(preserveSplitScroll)
            return
        }
        issuesGridRefreshDebounce.restart()
    }

    function isSeriesSelected(seriesKey) {
        return selectedSeriesKeys[String(seriesKey || "")] === true
    }

    function selectedSeriesCount() {
        return Object.keys(selectedSeriesKeys).length
    }

    function selectedSeriesIssueCount() {
        let total = 0
        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i)
            const key = String(item.seriesKey || "")
            if (selectedSeriesKeys[key] === true) {
                total += Number(item.count || 0)
            }
        }
        return total
    }

    function indexForSeriesKey(seriesKey) {
        const key = String(seriesKey || "")
        if (key.length < 1) return -1
        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i)
            if (String(item.seriesKey || "") === key) return i
        }
        return -1
    }

    function applySeriesSelectionRange(fromIndex, toIndex) {
        if (seriesListModel.count < 1) return
        const start = Math.max(0, Math.min(fromIndex, toIndex))
        const end = Math.min(seriesListModel.count - 1, Math.max(fromIndex, toIndex))
        const next = {}
        for (let i = start; i <= end; i += 1) {
            const item = seriesListModel.get(i)
            const key = String(item.seriesKey || "")
            if (key.length > 0) next[key] = true
        }
        selectedSeriesKeys = next
    }

    function selectSeries(seriesKey, seriesTitle, indexValue) {
        seriesMenuDismissToken += 1
        const key = String(seriesKey || "")
        const title = String(seriesTitle || "")
        const sameSeries = key.length > 0 && key === String(selectedSeriesKey || "")
        const hadQuickFilter = String(sidebarQuickFilterKey || "").trim().length > 0
        if (hadQuickFilter) {
            sidebarQuickFilterKey = ""
        }
        selectedSeriesTitle = title
        selectedSeriesKey = key

        const next = {}
        if (key.length > 0) next[key] = true
        selectedSeriesKeys = next
        if (typeof indexValue === "number" && indexValue >= 0) {
            seriesSelectionAnchorIndex = Math.floor(indexValue)
        } else {
            seriesSelectionAnchorIndex = indexForSeriesKey(key)
        }

        if (sameSeries) {
            clearSelection()
            setGridScrollToTop()
            if (typeof mainLibraryPane !== "undefined") {
                mainLibraryPane.heroCollapseOffset = 0
            }
            if (hadQuickFilter) {
                scheduleIssuesGridRefresh(true)
            }
            return
        }

        refreshVolumeList()
        clearSelection()
        setGridScrollToTop()
        if (typeof mainLibraryPane !== "undefined") {
            mainLibraryPane.heroCollapseOffset = 0
        }
    }

    function selectSeriesWithModifiers(seriesKey, seriesTitle, itemIndex, modifiers) {
        const key = String(seriesKey || "")
        const title = String(seriesTitle || "")
        const index = Number(itemIndex || 0)
        const shiftPressed = (Number(modifiers || 0) & Qt.ShiftModifier) !== 0

        if (shiftPressed && selectedSeriesCount() > 0) {
            const anchor = seriesSelectionAnchorIndex >= 0 ? seriesSelectionAnchorIndex : indexForSeriesKey(selectedSeriesKey)
            if (anchor >= 0) {
                applySeriesSelectionRange(anchor, index)
            } else {
                const next = {}
                if (key.length > 0) next[key] = true
                selectedSeriesKeys = next
            }
            selectedSeriesTitle = title
            selectedSeriesKey = key
            if (String(sidebarQuickFilterKey || "").trim().length > 0) {
                sidebarQuickFilterKey = ""
            }
            refreshVolumeList()
            clearSelection()
            setGridScrollToTop()
            if (typeof mainLibraryPane !== "undefined") {
                mainLibraryPane.heroCollapseOffset = 0
            }
            return
        }

        selectSeries(key, title, index)
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

    function openMetadataEditor(comic) {
        let loaded = libraryModel.loadComicMetadata(comic.id)
        if (loaded && loaded.error) {
            libraryModel.reload()
            loaded = libraryModel.loadComicMetadata(comic.id)
        }
        if (loaded && loaded.error) {
            editingComic = null
            return
        }

        editingComic = comic
        const values = loaded || comic || {}
        popupController.closeAllManagedPopups(metadataDialog)
        metadataDialog.openForState(values)
    }

    function saveMetadata(draftState) {
        if (!editingComic) {
            metadataDialog.errorText = "Nothing selected."
            return false
        }

        const draft = draftState || metadataDialog.currentState()
        const result = libraryModel.updateComicMetadata(
            editingComic.id,
            draft
        )
        if (result.length > 0) {
            metadataDialog.errorText = result
            return false
        }

        metadataDialog.errorText = ""
        metadataDialog.markSaved(draft)
        return true
    }

    function buildIssueMetadataSuggestion(draftState) {
        if (!editingComic) return null
        const draft = draftState || metadataDialog.currentState()
        const suggestion = libraryModel.issueMetadataSuggestion(draft, Number(editingComic.id || 0)) || {}
        return Object.keys(suggestion).length > 0 ? suggestion : null
    }

    function applyIssueMetadataSuggestionPatch(patch) {
        if (!patch || typeof patch !== "object") return
        const nextState = metadataDialog.currentState()
        const keys = Object.keys(patch)
        for (let i = 0; i < keys.length; i += 1) {
            const key = String(keys[i] || "")
            if (key.length < 1) continue
            if (String(nextState[key] || "").trim().length > 0) continue
            nextState[key] = patch[key]
        }
        metadataDialog.applyState(nextState)
    }

    function requestApplyIssueMetadataEdit(draftState) {
        const draft = draftState || metadataDialog.currentState()
        const suggestion = buildIssueMetadataSuggestion(draft)
        if (suggestion) {
            pendingIssueMetadataSuggestion = suggestion
            const suggestionSeriesLabel = String(suggestion.displayTitle || draft.series || "this series")
            const suggestionIssueLabel = String(suggestion.issueNumber || draft.issueNumber || "")
            issueMetadataAutofillConfirmDialog.messageText =
                "Saved issue info was found for issue #" + suggestionIssueLabel + " in \"" + suggestionSeriesLabel + "\".\n\n"
                + "Fill the remaining issue fields automatically before saving?"
            issueMetadataAutofillConfirmDialog.open()
            return
        }

        pendingIssueMetadataSuggestion = ({})
        if (saveMetadata(draft)) {
            metadataDialog.close()
        }
    }

    function acceptIssueMetadataSuggestion() {
        const suggestion = pendingIssueMetadataSuggestion || ({})
        pendingIssueMetadataSuggestion = ({})
        if (issueMetadataAutofillConfirmDialog.visible) {
            issueMetadataAutofillConfirmDialog.close()
        }
        applyIssueMetadataSuggestionPatch(suggestion.patch || {})
        if (saveMetadata(metadataDialog.currentState())) {
            metadataDialog.close()
        }
    }

    function skipIssueMetadataSuggestion() {
        pendingIssueMetadataSuggestion = ({})
        if (issueMetadataAutofillConfirmDialog.visible) {
            issueMetadataAutofillConfirmDialog.close()
        }
        if (saveMetadata(metadataDialog.currentState())) {
            metadataDialog.close()
        }
    }

    function resetMetadataEditor() {
        if (!editingComic) return
        metadataDialog.resetToInitial()
    }

    function openReader(comicId, title) {
        readerSessionController.openReader(comicId, title)
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
            popupController.actionResultTitle = "Couldn't delete page"
            popupController.showActionResultWithAction(errorText, "", "", "")
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

    function seriesMetaMonthNameFromNumber(monthNumber) {
        const value = Number(monthNumber || 0)
        if (value < 1 || value > 12) return ""
        return String(seriesMetaMonthOptions[value - 1] || "")
    }

    function seriesMetaMonthNumberFromName(monthName) {
        const name = String(monthName || "").trim()
        if (name.length < 1) return ""
        const idx = seriesMetaMonthOptions.indexOf(name)
        if (idx >= 0) return String(idx + 1)
        return ""
    }

    function openSeriesMetadataDialog(seriesKey, seriesTitle, focusField, mode) {
        const key = String(seriesKey || selectedSeriesKey || "").trim()
        if (key.length < 1) {
            popupController.showActionResult("Select a series first.", true)
            return
        }

        const selectedKeys = Object.keys(selectedSeriesKeys).filter(function(k) {
            return selectedSeriesKeys[k] === true
        })
        const multiSelected = selectedKeys.length > 1 && selectedKeys.indexOf(key) >= 0
        const targetKeys = multiSelected ? selectedKeys : [key]
        const requestedMode = String(mode || "").trim().toLowerCase()
        const effectiveMode = multiSelected
            ? (requestedMode === "merge" ? "merge" : "bulk")
            : "single"
        editingSeriesKey = key
        editingSeriesKeys = targetKeys
        editingSeriesDialogMode = effectiveMode
        if (multiSelected) {
            editingSeriesTitle = String(targetKeys.length) + " series selected"
        } else {
            editingSeriesTitle = String(seriesTitle || selectedSeriesTitle || "").trim()
            if (editingSeriesTitle.length < 1) {
                editingSeriesTitle = String(libraryModel.groupTitleForKey(key) || "")
            }
        }

        const rows = libraryModel.issuesForSeries(key, "__all__", "all", "")
        const storedSeriesMetadata = multiSelected ? {} : (libraryModel.seriesMetadataForKey(key) || {})
        let seedSeries = ""
        let seedVolume = String(storedSeriesMetadata.volume || "").trim()
        let seedSeriesTitle = String(storedSeriesMetadata.seriesTitle || "").trim()
        let seedYear = String(storedSeriesMetadata.year || "").trim()
        let seedGenres = String(storedSeriesMetadata.genres || "").trim()
        let seedMonthName = seriesMetaMonthNameFromNumber(storedSeriesMetadata.month)
        let seedPublisher = String(storedSeriesMetadata.publisher || "").trim()
        let seedAgeRating = String(storedSeriesMetadata.ageRating || "").trim()
        const rowCount = Number(rows && rows.length ? rows.length : 0)
        if (rowCount > 0) {
            const firstRow = rows[0] || {}
            seedSeries = normalizeSeriesNameForSave(String(firstRow.series || "").trim(), String(firstRow.volume || "").trim())
            if (seedVolume.length < 1) {
                seedVolume = String(firstRow.volume || "").trim()
            }
            if (seedMonthName.length < 1) {
                seedMonthName = seriesMetaMonthNameFromNumber(firstRow.month)
            }
            if (seedAgeRating.length < 1) {
                seedAgeRating = String(firstRow.ageRating || "").trim()
            }
            let minYear = 0
            const publisherCounts = ({})
            const publisherLabel = ({})
            const genreSeedSeen = ({})
            const genreSeedList = []
            for (let i = 0; i < rows.length; i += 1) {
                const row = rows[i] || {}
                const y = Number(row.year || 0)
                if (y > 0 && (minYear < 1 || y < minYear)) minYear = y

                const p = displayPublisherName(row.publisher)
                if (p.length > 0) {
                    const pk = PublisherCatalog.normalizePublisherKey(p)
                    publisherCounts[pk] = Number(publisherCounts[pk] || 0) + 1
                    if (!publisherLabel[pk]) publisherLabel[pk] = p
                }

                if (seedGenres.length < 1) {
                    const rowGenres = heroSeriesController.splitGenres(row.genres)
                    for (let g = 0; g < rowGenres.length; g += 1) {
                        const token = rowGenres[g]
                        const tokenKey = token.toLowerCase()
                        if (genreSeedSeen[tokenKey] === true) continue
                        genreSeedSeen[tokenKey] = true
                        genreSeedList.push(token)
                    }
                }
            }
            if (seedYear.length < 1 && minYear > 0) seedYear = String(minYear)
            if (seedGenres.length < 1 && genreSeedList.length > 0) seedGenres = genreSeedList.join(" / ")
            let topPublisher = ""
            let topCount = -1
            const pKeys = Object.keys(publisherCounts)
            for (let p = 0; p < pKeys.length; p += 1) {
                const pk = pKeys[p]
                const cnt = Number(publisherCounts[pk] || 0)
                if (cnt > topCount) {
                    topCount = cnt
                    topPublisher = String(publisherLabel[pk] || "")
                }
            }
            if (seedPublisher.length < 1) {
                seedPublisher = topPublisher
            }
        }

        seriesMetaDialog.prepareDropdownState(seedYear, seedAgeRating, seedGenres, seedPublisher)

        seriesMetaSeriesField.text = seedSeries.length > 0
            ? seedSeries
            : normalizeSeriesNameForSave(String(editingSeriesTitle || ""), "")
        seriesMetaSummaryField.text = multiSelected ? "" : String(storedSeriesMetadata.summary || "")
        seriesMetaYearField.text = seedYear
        seriesMetaTitleField.text = seedSeriesTitle
        seriesMetaVolumeField.text = seedVolume.length > 0
            ? seedVolume
            : ""
        seriesMetaGenresField.text = seedGenres
        seriesMetaPublisherField.text = seedPublisher
        seriesMetaMonthCombo.editText = seedMonthName
        seriesMetaAgeRatingCombo.editText = seedAgeRating
        if (seriesMetaSummaryField.text === "-") seriesMetaSummaryField.text = ""
        if (seriesMetaYearField.text === "-") seriesMetaYearField.text = ""
        if (seriesMetaVolumeField.text === "Multiple" || seriesMetaVolumeField.text === "-") seriesMetaVolumeField.text = ""
        if (seriesMetaGenresField.text === "-") seriesMetaGenresField.text = ""
        if (seriesMetaPublisherField.text === "-") seriesMetaPublisherField.text = ""
        startupController.startupLog(
            "seriesDialog open key=" + key
            + " mode=" + effectiveMode
            + " multi=" + String(multiSelected)
            + " targetKeys=" + String(targetKeys.length)
            + " rows=" + String(rowCount)
            + " seedSeries=\"" + String(seriesMetaSeriesField.text || "") + "\""
            + " seedSeriesTitle=\"" + String(seriesMetaTitleField.text || "") + "\""
            + " seedVolume=\"" + String(seriesMetaVolumeField.text || "") + "\""
            + " seedGenres=\"" + String(seriesMetaGenresField.text || "") + "\""
            + " seedPublisher=\"" + String(seriesMetaPublisherField.text || "") + "\""
            + " seedYear=\"" + String(seriesMetaYearField.text || "") + "\""
            + " seedMonth=\"" + String(seriesMetaMonthCombo.currentText || "") + "\""
            + " seedAge=\"" + String(seriesMetaAgeRatingCombo.currentText || "") + "\""
            + " seedSummaryLen=" + String(String(seriesMetaSummaryField.text || "").length)
        )
        seriesMetaDialog.pendingFocusField = String(focusField || "").trim()
        seriesMetaDialog.errorText = ""
        popupController.openExclusivePopup(seriesMetaDialog)
    }

    function openSeriesMergeDialog(seriesKey, seriesTitle) {
        openSeriesMetadataDialog(seriesKey, seriesTitle, "series", "merge")
    }

    function buildSeriesMetadataSuggestion() {
        const currentKey = String(editingSeriesKey || "").trim()
        if (currentKey.length < 1) return null
        if (Array.isArray(editingSeriesKeys) && editingSeriesKeys.length > 1) return null

        const seriesRawValue = String(seriesMetaSeriesField.text || "").trim()
        const volumeValue = String(seriesMetaVolumeField.text || "").trim()
        const seriesValue = normalizeSeriesNameForSave(seriesRawValue, volumeValue)
        const suggestion = libraryModel.seriesMetadataSuggestion({
            series: seriesValue,
            seriesTitle: String(seriesMetaTitleField.text || "").trim(),
            summary: String(seriesMetaSummaryField.text || "").trim(),
            year: String(seriesMetaYearField.text || "").trim(),
            month: seriesMetaMonthNumberFromName(seriesMetaMonthCombo.currentText),
            genres: String(seriesMetaGenresField.text || "").trim(),
            volume: volumeValue,
            publisher: String(seriesMetaPublisherField.text || "").trim(),
            ageRating: String(seriesMetaAgeRatingCombo.currentText || "").trim()
        }, currentKey) || {}
        return Object.keys(suggestion).length > 0 ? suggestion : null
    }

    function applySeriesMetadataSuggestionPatch(patch) {
        const values = patch || {}
        if (Object.prototype.hasOwnProperty.call(values, "seriesTitle")
                && String(seriesMetaTitleField.text || "").trim().length < 1) {
            seriesMetaTitleField.text = String(values.seriesTitle || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "summary")
                && String(seriesMetaSummaryField.text || "").trim().length < 1) {
            seriesMetaSummaryField.text = String(values.summary || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "year")
                && String(seriesMetaYearField.text || "").trim().length < 1) {
            seriesMetaYearField.text = String(values.year || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "month")
                && String(seriesMetaMonthCombo.currentText || "").trim().length < 1) {
            seriesMetaMonthCombo.editText = seriesMetaMonthNameFromNumber(values.month)
        }
        if (Object.prototype.hasOwnProperty.call(values, "genres")
                && String(seriesMetaGenresField.text || "").trim().length < 1) {
            seriesMetaGenresField.text = String(values.genres || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "volume")
                && String(seriesMetaVolumeField.text || "").trim().length < 1) {
            seriesMetaVolumeField.text = String(values.volume || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "publisher")
                && String(seriesMetaPublisherField.text || "").trim().length < 1) {
            seriesMetaPublisherField.text = String(values.publisher || "").trim()
        }
        if (Object.prototype.hasOwnProperty.call(values, "ageRating")
                && String(seriesMetaAgeRatingCombo.currentText || "").trim().length < 1) {
            seriesMetaAgeRatingCombo.editText = String(values.ageRating || "").trim()
        }
    }

    function requestApplySeriesMetadataEdit() {
        const suggestion = buildSeriesMetadataSuggestion()
        if (suggestion) {
            pendingSeriesMetadataSuggestion = suggestion
            const suggestionLabel = String(suggestion.displayTitle || seriesMetaSeriesField.text || "this series")
            seriesMetadataAutofillConfirmDialog.messageText =
                "Saved series info was found for \"" + suggestionLabel + "\".\n\n"
                + "Fill the remaining series fields automatically before saving?"
            seriesMetadataAutofillConfirmDialog.open()
            return
        }

        pendingSeriesMetadataSuggestion = ({})
        if (applySeriesMetadataEdit()) {
            seriesMetaDialog.close()
        }
    }

    function acceptSeriesMetadataSuggestion() {
        const suggestion = pendingSeriesMetadataSuggestion || ({})
        pendingSeriesMetadataSuggestion = ({})
        if (seriesMetadataAutofillConfirmDialog.visible) {
            seriesMetadataAutofillConfirmDialog.close()
        }
        applySeriesMetadataSuggestionPatch(suggestion.patch || {})
        if (applySeriesMetadataEdit()) {
            seriesMetaDialog.close()
        }
    }

    function skipSeriesMetadataSuggestion() {
        pendingSeriesMetadataSuggestion = ({})
        if (seriesMetadataAutofillConfirmDialog.visible) {
            seriesMetadataAutofillConfirmDialog.close()
        }
        if (applySeriesMetadataEdit()) {
            seriesMetaDialog.close()
        }
    }

    function findSeriesKeyForIssueId(issueId, fallbackKey) {
        const targetId = Number(issueId || 0)
        const fallback = String(fallbackKey || "").trim()
        if (targetId < 1) return fallback

        const groups = libraryModel.seriesGroups()
        for (let i = 0; i < groups.length; i += 1) {
            const group = groups[i] || {}
            const groupKey = String(group.seriesKey || "").trim()
            if (groupKey.length < 1) continue
            const rows = libraryModel.issuesForSeries(groupKey, "__all__", "all", "")
            for (let j = 0; j < rows.length; j += 1) {
                const id = Number((rows[j] || {}).id || 0)
                if (id === targetId) {
                    return groupKey
                }
            }
        }
        return fallback
    }

    function applySeriesMetadataEdit() {
        const keys = Array.isArray(editingSeriesKeys) && editingSeriesKeys.length > 0
            ? editingSeriesKeys.slice(0)
            : [String(editingSeriesKey || "").trim()]
        const normalizedKeys = keys
            .map(function(k) { return String(k || "").trim() })
            .filter(function(k) { return k.length > 0 })
        if (normalizedKeys.length < 1) {
            seriesMetaDialog.errorText = "Series context is missing."
            return false
        }

        const key = normalizedKeys[0]
        const multiSelection = normalizedKeys.length > 1
        const editMode = String(editingSeriesDialogMode || "").trim().toLowerCase()
        const mergeMode = editMode === "merge" && multiSelection
        const bulkMode = editMode === "bulk" && multiSelection
        const ids = []
        const leadIssueByKey = ({})
        for (let k = 0; k < normalizedKeys.length; k += 1) {
            const seriesKey = normalizedKeys[k]
            const issues = libraryModel.issuesForSeries(seriesKey, "__all__", "all", "")
            for (let i = 0; i < issues.length; i += 1) {
                const id = Number((issues[i] || {}).id || 0)
                if (id > 0) {
                    ids.push(id)
                    if (!leadIssueByKey[seriesKey]) {
                        leadIssueByKey[seriesKey] = id
                    }
                }
            }
        }

        if (ids.length < 1) {
            seriesMetaDialog.errorText = "No issues found for selected series."
            return false
        }
        const dedupMap = ({})
        const dedupIds = []
        for (let i = 0; i < ids.length; i += 1) {
            const id = Number(ids[i] || 0)
            if (id < 1 || dedupMap[id] === true) continue
            dedupMap[id] = true
            dedupIds.push(id)
        }

        const seriesRawValue = String(seriesMetaSeriesField.text || "").trim()
        const volumeValue = String(seriesMetaVolumeField.text || "").trim()
        const seriesValue = mergeMode
            ? String(seriesRawValue || "").trim()
            : normalizeSeriesNameForSave(seriesRawValue, volumeValue)
        const seriesTitleValue = String(seriesMetaTitleField.text || "").trim()
        const summaryValue = String(seriesMetaSummaryField.text || "").trim()
        const yearValue = String(seriesMetaYearField.text || "").trim()
        const monthValue = seriesMetaMonthNumberFromName(seriesMetaMonthCombo.currentText)
        const genresValue = String(seriesMetaGenresField.text || "").trim()
        const publisherValue = String(seriesMetaPublisherField.text || "").trim()
        const resolvedPublisherValue = displayPublisherName(publisherValue)
        const ageRatingValue = String(seriesMetaAgeRatingCombo.currentText || "").trim()
        startupController.startupLog(
            "seriesDialog save key=" + key
            + " keys=" + String(normalizedKeys.length)
            + " ids=" + String(dedupIds.length)
            + " mode=" + editMode
            + " multi=" + String(multiSelection)
            + " series=\"" + seriesValue + "\""
            + " seriesTitle=\"" + seriesTitleValue + "\""
            + " volume=\"" + volumeValue + "\""
            + " genres=\"" + genresValue + "\""
            + " publisher=\"" + publisherValue + "\""
            + " year=\"" + yearValue + "\""
            + " month=\"" + monthValue + "\""
            + " ageRating=\"" + ageRatingValue + "\""
            + " summaryLen=" + String(summaryValue.length)
        )

        const values = {}
        const applyMap = {}
        if (mergeMode) {
            if (seriesValue.length < 1) {
                seriesMetaDialog.errorText = "Enter a series name to merge into."
                return false
            }
            values.series = seriesValue
            applyMap.series = true
        } else if (bulkMode) {
            if (monthValue.length > 0) {
                values.month = monthValue
                applyMap.month = true
            }
            if (publisherValue.length > 0) {
                values.publisher = publisherValue
                applyMap.publisher = true
            }
            if (ageRatingValue.length > 0) {
                values.ageRating = ageRatingValue
                applyMap.ageRating = true
            }
            if (Object.keys(applyMap).length < 1
                    && summaryValue.length < 1
                    && seriesTitleValue.length < 1
                    && yearValue.length < 1
                    && genresValue.length < 1) {
                seriesMetaDialog.errorText = "Enter at least one field for bulk edit."
                return false
            }
        } else {
            values.series = seriesValue
            values.month = monthValue
            values.volume = volumeValue
            values.publisher = publisherValue
            values.ageRating = ageRatingValue

            applyMap.series = true
            applyMap.month = true
            applyMap.volume = true
            applyMap.publisher = true
            applyMap.ageRating = true
        }

        const result = libraryModel.bulkUpdateMetadata(dedupIds, values, applyMap)
        if (result.length > 0) {
            startupController.startupLog("seriesDialog bulkUpdate error: " + result)
            seriesMetaDialog.errorText = result
            return false
        }

        if (!multiSelection) {
            const verifyId = Number(dedupIds[0] || 0)
            const verify = libraryModel.loadComicMetadata(verifyId)
            if (verify && verify.error) {
                startupController.startupLog("seriesDialog verify error: " + String(verify.error || "unknown"))
                seriesMetaDialog.errorText = String(verify.error || "Save verification failed.")
                return false
            }

            const mismatched =
                String(verify.series || "").trim() !== seriesValue
                || String(verify.volume || "").trim() !== volumeValue
                || String(verify.publisher || "").trim() !== publisherValue
                || String(verify.ageRating || "").trim() !== ageRatingValue
                || Number(verify.month || 0) !== Number(monthValue || 0)
            if (mismatched) {
                startupController.startupLog(
                    "seriesDialog verify mismatch"
                    + " verifySeries=\"" + String(verify.series || "") + "\""
                    + " verifyVolume=\"" + String(verify.volume || "") + "\""
                    + " verifyPublisher=\"" + String(verify.publisher || "") + "\""
                    + " verifyYear=\"" + String(verify.year || "") + "\""
                    + " verifyMonth=\"" + String(verify.month || "") + "\""
                    + " verifyAgeRating=\"" + String(verify.ageRating || "") + "\""
                )
                seriesMetaDialog.errorText = "Metadata save verification mismatch. Please retry."
                scheduleModelReconcile(true)
                return false
            }

            const resolvedSeriesKey = findSeriesKeyForIssueId(verifyId, key)
            const resolvedSeriesTitle = String(libraryModel.groupTitleForKey(resolvedSeriesKey) || "").trim()
            const targetSeriesKey = String(resolvedSeriesKey || key).trim()
            const sourceSeriesMetadata = libraryModel.seriesMetadataForKey(key) || {}
            const seriesMetaSaveResult = libraryModel.setSeriesMetadataForKey(targetSeriesKey, {
                seriesTitle: seriesTitleValue,
                summary: summaryValue,
                year: yearValue,
                month: monthValue,
                genres: genresValue,
                volume: volumeValue,
                publisher: resolvedPublisherValue,
                ageRating: ageRatingValue
            })
            if (seriesMetaSaveResult.length > 0) {
                startupController.startupLog("seriesDialog series metadata save error: " + seriesMetaSaveResult)
                seriesMetaDialog.errorText = seriesMetaSaveResult
                return false
            }
            if (targetSeriesKey !== key) {
                const preserveHeaderError = heroSeriesController.preserveHeaderOverridesIfNeeded(targetSeriesKey, sourceSeriesMetadata)
                if (preserveHeaderError.length > 0) {
                    seriesMetaDialog.errorText = preserveHeaderError
                    return false
                }
                libraryModel.removeSeriesMetadataForKey(key)
            }
            startupController.startupLog("seriesDialog save success targetKey=" + targetSeriesKey)
            seriesMetaDialog.errorText = ""
            editingSeriesKey = ""
            editingSeriesKeys = []
            editingSeriesTitle = ""

            refreshSeriesList()
            const effectiveSeriesKey = String(resolvedSeriesKey || key).trim()
            if (effectiveSeriesKey.length > 0) {
                selectedSeriesTitle = resolvedSeriesTitle.length > 0
                    ? resolvedSeriesTitle
                    : String(libraryModel.groupTitleForKey(effectiveSeriesKey) || selectedSeriesTitle)
                selectedSeriesKey = effectiveSeriesKey
                const selection = {}
                selection[effectiveSeriesKey] = true
                selectedSeriesKeys = selection
                seriesSelectionAnchorIndex = indexForSeriesKey(effectiveSeriesKey)
                refreshVolumeList()
                heroSeriesController.resolveHeroMediaForSelectedSeries()
                heroSeriesController.applyDraftSeriesData(
                    String(selectedSeriesTitle || seriesValue || "-"),
                    summaryValue.length > 0 ? summaryValue : "-",
                    yearValue.length > 0 ? yearValue : "-",
                    volumeValue.length > 0 ? volumeValue : "-",
                    resolvedPublisherValue.length > 0 ? resolvedPublisherValue : "-",
                    genresValue.length > 0 ? genresValue : "-"
                )
                heroSeriesController.refreshSeriesData()
                refreshIssuesGridData()
            } else {
                scheduleModelReconcile(true)
            }
            startupController.requestSnapshotSave()
            return true
        }

        if (mergeMode) {
            const primaryLeadId = Number(leadIssueByKey[key] || 0)
            const primaryTargetSeriesKey = primaryLeadId > 0
                ? String(findSeriesKeyForIssueId(primaryLeadId, key) || key).trim()
                : key
            const primarySourceMetadata = libraryModel.seriesMetadataForKey(key) || {}
            if (primaryTargetSeriesKey !== key) {
                const preserveHeaderError = heroSeriesController.preserveHeaderOverridesIfNeeded(
                    primaryTargetSeriesKey,
                    primarySourceMetadata
                )
                if (preserveHeaderError.length > 0) {
                    seriesMetaDialog.errorText = preserveHeaderError
                    return false
                }
                const primarySeriesMetaSaveResult = libraryModel.setSeriesMetadataForKey(primaryTargetSeriesKey, {
                    seriesTitle: String(primarySourceMetadata.seriesTitle || "").trim(),
                    summary: String(primarySourceMetadata.summary || "").trim(),
                    year: String(primarySourceMetadata.year || "").trim(),
                    month: String(primarySourceMetadata.month || "").trim(),
                    genres: String(primarySourceMetadata.genres || "").trim(),
                    volume: String(primarySourceMetadata.volume || "").trim(),
                    publisher: String(primarySourceMetadata.publisher || "").trim(),
                    ageRating: String(primarySourceMetadata.ageRating || "").trim()
                })
                if (primarySeriesMetaSaveResult.length > 0) {
                    startupController.startupLog("seriesDialog merge metadata save error: " + primarySeriesMetaSaveResult)
                    seriesMetaDialog.errorText = primarySeriesMetaSaveResult
                    return false
                }
            }
            for (let i = 0; i < normalizedKeys.length; i += 1) {
                const sourceKey = normalizedKeys[i]
                if (sourceKey === primaryTargetSeriesKey) continue
                libraryModel.removeSeriesMetadataForKey(sourceKey)
            }
        } else if (summaryValue.length > 0
                || seriesTitleValue.length > 0
                || yearValue.length > 0
                || genresValue.length > 0) {
            for (let i = 0; i < normalizedKeys.length; i += 1) {
                const sourceKey = normalizedKeys[i]
                const leadId = Number(leadIssueByKey[sourceKey] || 0)
                const resolvedKey = leadId > 0 ? findSeriesKeyForIssueId(leadId, sourceKey) : sourceKey
                const targetSeriesKey = String(resolvedKey || sourceKey).trim()
                const sourceSeriesMetadata = libraryModel.seriesMetadataForKey(sourceKey) || {}
                const nextSeriesTitle = seriesTitleValue.length > 0
                    ? seriesTitleValue
                    : String(sourceSeriesMetadata.seriesTitle || "").trim()
                const nextSummary = summaryValue.length > 0
                    ? summaryValue
                    : String(sourceSeriesMetadata.summary || "").trim()
                const nextSeriesYear = yearValue.length > 0
                    ? yearValue
                    : String(sourceSeriesMetadata.year || "").trim()
                const nextSeriesMonth = monthValue.length > 0
                    ? monthValue
                    : String(sourceSeriesMetadata.month || "").trim()
                const nextSeriesGenres = genresValue.length > 0
                    ? genresValue
                    : String(sourceSeriesMetadata.genres || "").trim()
                const nextSeriesVolume = volumeValue.length > 0
                    ? volumeValue
                    : String(sourceSeriesMetadata.volume || "").trim()
                const nextSeriesPublisher = resolvedPublisherValue.length > 0
                    ? resolvedPublisherValue
                    : String(sourceSeriesMetadata.publisher || "").trim()
                const nextSeriesAgeRating = ageRatingValue.length > 0
                    ? ageRatingValue
                    : String(sourceSeriesMetadata.ageRating || "").trim()
                const seriesMetaValues = {}
                if (nextSeriesTitle.length > 0) seriesMetaValues.seriesTitle = nextSeriesTitle
                if (nextSummary.length > 0) seriesMetaValues.summary = nextSummary
                if (nextSeriesYear.length > 0) seriesMetaValues.year = nextSeriesYear
                if (nextSeriesMonth.length > 0) seriesMetaValues.month = nextSeriesMonth
                if (nextSeriesGenres.length > 0) seriesMetaValues.genres = nextSeriesGenres
                if (!bulkMode && nextSeriesVolume.length > 0) seriesMetaValues.volume = nextSeriesVolume
                if (nextSeriesPublisher.length > 0) seriesMetaValues.publisher = nextSeriesPublisher
                if (nextSeriesAgeRating.length > 0) seriesMetaValues.ageRating = nextSeriesAgeRating
                const seriesMetaSaveResult = libraryModel.setSeriesMetadataForKey(targetSeriesKey, seriesMetaValues)
                if (seriesMetaSaveResult.length > 0) {
                    startupController.startupLog("seriesDialog series metadata save error: " + seriesMetaSaveResult)
                    seriesMetaDialog.errorText = seriesMetaSaveResult
                    return false
                }
                if (targetSeriesKey !== sourceKey) {
                    const preserveHeaderError = heroSeriesController.preserveHeaderOverridesIfNeeded(targetSeriesKey, sourceSeriesMetadata)
                    if (preserveHeaderError.length > 0) {
                        seriesMetaDialog.errorText = preserveHeaderError
                        return false
                    }
                    libraryModel.removeSeriesMetadataForKey(sourceKey)
                }
            }
        }
        startupController.startupLog("seriesDialog bulk save success mode=" + editMode + " keys=" + String(normalizedKeys.length))

        seriesMetaDialog.errorText = ""
        editingSeriesKey = ""
        editingSeriesKeys = []
        editingSeriesTitle = ""
        editingSeriesDialogMode = "single"
        scheduleModelReconcile(true)
        startupController.requestSnapshotSave()
        return true
    }

    function dismissGridOverlayMenusForScroll() {
        gridOverlayMenusSuppressed = true
        gridOverlayMenuResumeTimer.restart()
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

    Component.onCompleted: startupController.handleComponentCompleted()

    onClosing: function(close) {
        if (popupController.blockCloseAndHighlightCriticalPopup(close)) {
            return
        }
        startupController.handleClosing(close)
    }

    onSelectedSeriesKeyChanged: {
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return
        heroSeriesController.resolveHeroMediaForSelectedSeries()
        heroSeriesController.refreshSeriesData()
        scheduleIssuesGridRefresh(true)
        startupController.requestSnapshotSave()
    }

    onSelectedVolumeKeyChanged: {
        if (restoringStartupSnapshot || suspendSelectionDrivenRefresh) return
        heroSeriesController.refreshSeriesData()
        scheduleIssuesGridRefresh(true)
        startupController.requestSnapshotSave()
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
        enabled: root.startupPrimaryContentVisible

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
            centerLabel: uiTokens.appTitle
            onAddFilesRequested: root.quickAddFilesFromDialog()
            onAddFolderRequested: root.quickAddFolderFromDialog()
            onAddIssueRequested: root.quickAddFilesFromDialog()
            onSettingsRequested: root.openSettingsDialog("")
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.startupDbHealthWarningVisible ? 34 : 0
            visible: root.startupDbHealthWarningVisible
            color: root.dbHealthBannerBg

            Label {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
                color: root.dbHealthBannerText
                text: root.startupDbHealthWarningMessage
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

        }

    }

    WindowResizeHandles {
        anchors.fill: parent
        hostWindow: root
        enabledWhenWindowed: windowDisplayController.enableWindowResizeHandles
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
}






