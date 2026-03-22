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
    property var pendingSeriesMetadataSuggestion: ({})
    property var pendingIssueMetadataSuggestion: ({})
    readonly property var seriesMetaSeriesField: seriesMetaDialog.seriesField
    readonly property var seriesMetaTitleField: seriesMetaDialog.titleField
    readonly property var seriesMetaVolumeField: seriesMetaDialog.volumeField
    readonly property var seriesMetaGenresField: seriesMetaDialog.genresField
    readonly property var seriesMetaPublisherField: seriesMetaDialog.publisherField
    readonly property var seriesMetaYearField: seriesMetaDialog.yearField
    readonly property var seriesMetaMonthCombo: seriesMetaDialog.monthCombo
    readonly property var seriesMetaAgeRatingCombo: seriesMetaDialog.ageRatingCombo
    readonly property var seriesMetaSummaryField: seriesMetaDialog.summaryField
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
    readonly property var activeIssuesFlick: (typeof rightPane !== "undefined" && rightPane)
        ? rightPane.activeIssuesFlick
        : null
    property string librarySearchText: ""
    property string libraryReadStatusFilter: "all"
    property bool gridSplitScrollRestorePending: false
    property real pendingGridSplitScrollValue: 0
    property bool libraryLoading: false
    property bool cbrBackendAvailable: false
    property string cbrBackendMissingMessage: ""
    property string pendingLibraryDataRelocationPath: String(libraryFacade.pendingDataRootRelocationPath() || "")
    property var importSeriesKeysBeforeBatch: ({})
    property bool importFocusNewSeriesAfterReload: false
    property string pendingImportPostReloadAction: ""
    property bool pendingConfiguredLaunchViewApply: true
    StartupController {
        id: startupController
        rootObject: root
        libraryModelRef: libraryModel
        heroSeriesControllerRef: heroSeriesController
        windowDisplayControllerRef: windowDisplayController
        appContentLayout: appContentLayout
        seriesListModel: seriesListModel
        seriesListView: seriesListView
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
        libraryFacadeRef: libraryFacade
        popupControllerRef: popupController
        readerDialog: readerDialog
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
        libraryFacadeRef: libraryFacade
        readerCoverControllerRef: readerCoverController
        startupControllerRef: startupController
        uiTokensRef: uiTokens
    }

    LibraryFacade {
        id: libraryFacade
        libraryModelRef: libraryModel
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
        libraryFacadeRef: libraryFacade
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
        comicVineApiKeyDialogRef: comicVineApiKeyDialog
    }

    property string sevenZipConfiguredPath: ""
    property string sevenZipEffectivePath: ""
    property alias criticalPopupAttentionTarget: popupController.criticalPopupAttentionTarget
    property color criticalPopupAttentionColor: "#b3fe03"
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
    property int startupLoadDelayMs: 16
    property int startupInitialReconcileSettleDelayMs: 48
    property int startupPrimaryContentRevealDelayMs: startupInitialReconcileSettleDelayMs
    property int startupInventoryCheckDelayMs: 5000
    property int startupHydrationRetryDelayMs: 100
    property int startupHydrationMaxDeferredAttempts: 20
    property bool restoringStartupSnapshot: false
    property bool startupSnapshotApplied: false
    property real startupSnapshotSeriesContentY: 0
    property real startupSnapshotIssuesContentY: 0
    property int startupSnapshotVersion: 1
    property int startupSnapshotMaxSeries: 160
    property int startupSnapshotMaxIssues: 24
    property bool startupSnapshotLiveReloadRequested: false
    property bool suspendSidebarSearchRefresh: false
    property bool modelReconcilePending: false
    property bool suspendSelectionDrivenRefresh: false
    property bool startupReconcileCompleted: false
    property bool startupHydrationInProgress: true
    property bool startupAwaitingFirstModelSignal: true
    property int startupHydrationAttemptCount: 0
    property bool startupDebugLogsEnabled: false
    property real startupStartedAtMs: 0
    property double launchStartedAtMs: Number(appLaunchStartedAtMs || 0)
    property bool startupFirstStatusSignalReceived: false
    property bool startupResultLogged: false
    property string startupFirstFrameSource: "unknown"
    property var startupInventorySignature: ({})
    property var startupPendingInventorySignature: ({})
    property int startupInventoryCheckRequestId: 0
    property bool startupInventoryCheckInProgress: false
    property bool startupInventoryRebuildInProgress: false
    property var pendingReaderProgressSaveByComicId: ({})
    property var pendingReaderProgressSaveOrder: []
    property int readerProgressSaveRetryDelayMs: 180
    property var startupColdRenderLoggedFlags: ({
        topbar: false,
        hero: false,
        grid: false,
        firstCard: false,
        firstCover: false
    })
    property string startupPreviewPath: ""
    property string startupPreviewPrimaryPath: ""
    property string startupPreviewFallbackPath: ""
    property string startupPreviewSource: ""
    property bool startupPreviewTriedFallback: false
    property int startupPreviewMaxLongSide: 1920
    property bool startupPreviewOverlayEnabled: false
    property bool showStartupPreview: false
    property bool startupPrimaryContentReady: false
    readonly property bool startupPrimaryContentVisible: startupPrimaryContentReady
    property bool startupClosingAfterPreview: false
    property int startupCloseSeq: 0
    property real startupCloseRequestedAtMs: 0
    property bool startupDbHealthWarningVisible: false
    property string startupDbHealthWarningMessage: ""
    property string startupDbHealthWarningCode: ""
    property int startupDbHealthRequestId: 0

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
        if (typeof rightPane === "undefined" || !rightPane) return
        rightPane.setAbsoluteSplitScroll(pendingGridSplitScrollValue)
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
        const value = Number(libraryFacade.fileSizeBytes(normalized))
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
        return libraryFacade.expandImportSources(normalizedSources, true)
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
        libraryFacade.reload()
    }

    function scheduleLibraryDataRelocationFromSettings() {
        const initialPath = String(
            pendingLibraryDataRelocationPath
            || libraryModel.dataRoot
            || ""
        )
        const selectedPath = String(libraryFacade.browseDataRootFolder(initialPath) || "")
        if (selectedPath.length < 1) return

        const result = libraryFacade.scheduleDataRootRelocation(selectedPath)
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

        const saveError = String(libraryFacade.saveReaderProgress(entry.comicId, entry.pageValue) || "")
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

        const issues = libraryFacade.issuesForSeries(normalizedSeriesKey, "__all__", "all", "")
        for (let i = 0; i < issues.length; i += 1) {
            const issue = issues[i] || {}
            const comicId = Number(issue.id || 0)
            if (comicId < 1) continue

            const metadata = libraryFacade.loadComicMetadata(comicId)
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
        return String(libraryFacade.importArchiveUnsupportedReason(String(pathValue || "")) || "")
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
        cbrBackendAvailable = libraryFacade.isCbrBackendAvailable()
        cbrBackendMissingMessage = libraryFacade.cbrBackendMissingMessage()
        sevenZipConfiguredPath = String(libraryFacade.configuredSevenZipExecutablePath() || "")
        sevenZipEffectivePath = String(libraryFacade.effectiveSevenZipExecutablePath() || "")
    }

    function chooseSevenZipPathFromSettings() {
        const initialPath = String(sevenZipConfiguredPath || sevenZipEffectivePath || "")
        const selectedPath = String(libraryFacade.browseArchiveFile(initialPath) || "")
        if (selectedPath.length < 1) return

        const applyError = String(libraryFacade.setSevenZipExecutablePath(selectedPath) || "").trim()
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
        const selectedPath = String(libraryFacade.browseImageFile(currentPath) || "")
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
        const selected = libraryFacade.browseArchiveFiles("")
        if (!selected || selected.length < 1) return
        startImportFromSourcePaths(
            selected,
            { importIntent: "global_add" },
            "No Supported Archives Found in Selected Files."
        )
    }

    function quickAddFilesForSeries(seriesTitle) {
        if (importInProgress) return
        const selected = libraryFacade.browseArchiveFiles("")
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

        const loaded = libraryFacade.loadComicMetadata(comicId)
        if (loaded && loaded.error) {
            return
        }

        const currentFilePath = String((loaded || {}).filePath || "")
        const selectedPath = libraryFacade.browseArchiveFile(currentFilePath)
        if (selectedPath.length < 1) return

        const unsupportedReason = String(libraryFacade.importArchiveUnsupportedReason(selectedPath) || "")
        if (unsupportedReason.length > 0) {
            popupController.showActionResult(unsupportedReason, true)
            return
        }

        const result = libraryFacade.replaceComicFileFromSourceEx(
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
        const selectedFolder = String(libraryFacade.browseArchiveFolder("") || "")
        if (selectedFolder.length < 1) return
        startImportFromSourcePaths(
            [selectedFolder],
            { importIntent: "global_add" },
            "No Supported Comic Sources Found in Selected Folder."
        )
    }

    function captureImportSeriesFocusBaseline() {
        const groups = libraryFacade.seriesGroups()
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
        const lastImportCount = libraryFacade.quickFilterIssueCount("last_import", lastImportSessionComicIds)

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
        quickFilterLastImportCount = libraryFacade.quickFilterIssueCount("last_import", lastImportSessionComicIds)
        quickFilterFavoritesCount = libraryFacade.quickFilterIssueCount("favorites", lastImportSessionComicIds)
        quickFilterBookmarksCount = libraryFacade.quickFilterIssueCount("bookmarks", lastImportSessionComicIds)
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
        if (key === "favorites") return uiTokens.quickFilterTitleFavoritIcon
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
        if (typeof rightPane !== "undefined") {
            rightPane.heroCollapseOffset = 0
        }
        scheduleIssuesGridRefresh(true)
        startupController.requestSnapshotSave()
    }

    function refreshSeriesList() {
        const groups = libraryFacade.seriesGroups().slice(0)
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
            ? libraryFacade.volumeGroupsForSeries(selectedSeriesKey)
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
        const preservedSplitScroll = shouldPreserveSplitScroll && typeof rightPane !== "undefined" && rightPane
            ? Number(rightPane.currentSplitScroll || 0)
            : 0

        if (isQuickFilterModeActive()) {
            refreshQuickFilterGridData(shouldPreserveSplitScroll, preservedSplitScroll)
            return
        }

        refreshSeriesGridData(shouldPreserveSplitScroll, preservedSplitScroll)
    }

    function refreshQuickFilterGridData(shouldPreserveSplitScroll, preservedSplitScroll) {
        const activeQuickFilterKey = String(sidebarQuickFilterKey || "").trim().toLowerCase()
        issuesGridData = libraryFacade.issuesForQuickFilter(activeQuickFilterKey, lastImportSessionComicIds)
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

        const liveIssues = libraryFacade.issuesForSeries(
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
            libraryFacade.reload()
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
            if (typeof rightPane !== "undefined") {
                rightPane.heroCollapseOffset = 0
            }
            if (hadQuickFilter) {
                scheduleIssuesGridRefresh(true)
            }
            return
        }

        refreshVolumeList()
        clearSelection()
        setGridScrollToTop()
        if (typeof rightPane !== "undefined") {
            rightPane.heroCollapseOffset = 0
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
            if (typeof rightPane !== "undefined") {
                rightPane.heroCollapseOffset = 0
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
        if (libraryFacade.lastError.length > 0) return true
        if (!startupReconcileCompleted) return false
        if (seriesListModel.count < 1) return true
        if (selectedSeriesKey.length < 1) return true
        return false
    }

    function openMetadataEditor(comic) {
        let loaded = libraryFacade.loadComicMetadata(comic.id)
        if (loaded && loaded.error) {
            libraryFacade.reload()
            loaded = libraryFacade.loadComicMetadata(comic.id)
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
        const result = libraryFacade.updateComicMetadata(
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
        const suggestion = libraryFacade.issueMetadataSuggestion(draft, Number(editingComic.id || 0)) || {}
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

    function openSeriesMetadataDialog(seriesKey, seriesTitle, focusField) {
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
        editingSeriesKey = key
        editingSeriesKeys = targetKeys
        if (multiSelected) {
            editingSeriesTitle = String(targetKeys.length) + " series selected"
        } else {
            editingSeriesTitle = String(seriesTitle || selectedSeriesTitle || "").trim()
            if (editingSeriesTitle.length < 1) {
                editingSeriesTitle = String(libraryFacade.groupTitleForKey(key) || "")
            }
        }

        const rows = libraryFacade.issuesForSeries(key, "__all__", "all", "")
        const storedSeriesMetadata = multiSelected ? {} : (libraryFacade.seriesMetadataForKey(key) || {})
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

    function buildSeriesMetadataSuggestion() {
        const currentKey = String(editingSeriesKey || "").trim()
        if (currentKey.length < 1) return null
        if (Array.isArray(editingSeriesKeys) && editingSeriesKeys.length > 1) return null

        const volumeValue = String(seriesMetaVolumeField.text || "").trim()
        const seriesRawValue = String(seriesMetaSeriesField.text || "").trim()
        const seriesValue = normalizeSeriesNameForSave(seriesRawValue, volumeValue)
        const suggestion = libraryFacade.seriesMetadataSuggestion({
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

        const groups = libraryFacade.seriesGroups()
        for (let i = 0; i < groups.length; i += 1) {
            const group = groups[i] || {}
            const groupKey = String(group.seriesKey || "").trim()
            if (groupKey.length < 1) continue
            const rows = libraryFacade.issuesForSeries(groupKey, "__all__", "all", "")
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
        const multiMode = normalizedKeys.length > 1
        const ids = []
        const leadIssueByKey = ({})
        for (let k = 0; k < normalizedKeys.length; k += 1) {
            const seriesKey = normalizedKeys[k]
            const issues = libraryFacade.issuesForSeries(seriesKey, "__all__", "all", "")
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

        const volumeValue = String(seriesMetaVolumeField.text || "").trim()
        const seriesRawValue = String(seriesMetaSeriesField.text || "").trim()
        const seriesValue = normalizeSeriesNameForSave(seriesRawValue, volumeValue)
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
            + " multi=" + String(multiMode)
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
        if (multiMode) {
            if (seriesRawValue.length > 0) {
                values.series = seriesValue
                applyMap.series = true
            }
            if (monthValue.length > 0) {
                values.month = monthValue
                applyMap.month = true
            }
            if (volumeValue.length > 0) {
                values.volume = volumeValue
                applyMap.volume = true
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

        const result = libraryFacade.bulkUpdateMetadata(dedupIds, values, applyMap)
        if (result.length > 0) {
            startupController.startupLog("seriesDialog bulkUpdate error: " + result)
            seriesMetaDialog.errorText = result
            return false
        }

        if (!multiMode) {
            const verifyId = Number(dedupIds[0] || 0)
            const verify = libraryFacade.loadComicMetadata(verifyId)
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
            const resolvedSeriesTitle = String(libraryFacade.groupTitleForKey(resolvedSeriesKey) || "").trim()
            const targetSeriesKey = String(resolvedSeriesKey || key).trim()
            const sourceSeriesMetadata = libraryFacade.seriesMetadataForKey(key) || {}
            const seriesMetaSaveResult = libraryFacade.setSeriesMetadataForKey(targetSeriesKey, {
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
                libraryFacade.removeSeriesMetadataForKey(key)
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
                    : String(libraryFacade.groupTitleForKey(effectiveSeriesKey) || selectedSeriesTitle)
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

        if (summaryValue.length > 0
                || seriesTitleValue.length > 0
                || applyMap.series === true
                || yearValue.length > 0
                || genresValue.length > 0) {
            for (let i = 0; i < normalizedKeys.length; i += 1) {
                const sourceKey = normalizedKeys[i]
                const leadId = Number(leadIssueByKey[sourceKey] || 0)
                const resolvedKey = leadId > 0 ? findSeriesKeyForIssueId(leadId, sourceKey) : sourceKey
                const targetSeriesKey = String(resolvedKey || sourceKey).trim()
                const sourceSeriesMetadata = libraryFacade.seriesMetadataForKey(sourceKey) || {}
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
                if (nextSeriesVolume.length > 0) seriesMetaValues.volume = nextSeriesVolume
                if (nextSeriesPublisher.length > 0) seriesMetaValues.publisher = nextSeriesPublisher
                if (nextSeriesAgeRating.length > 0) seriesMetaValues.ageRating = nextSeriesAgeRating
                const seriesMetaSaveResult = libraryFacade.setSeriesMetadataForKey(targetSeriesKey, seriesMetaValues)
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
                    libraryFacade.removeSeriesMetadataForKey(sourceKey)
                }
            }
        }
        startupController.startupLog("seriesDialog bulk save success keys=" + String(normalizedKeys.length))

        seriesMetaDialog.errorText = ""
        editingSeriesKey = ""
        editingSeriesKeys = []
        editingSeriesTitle = ""
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
        const preservedSplitScroll = typeof rightPane !== "undefined" && rightPane
            ? Number(rightPane.currentSplitScroll || 0)
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

        const result = libraryFacade.saveReaderProgress(comicId, 0)
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

    Image {
        id: startupPreviewLayer
        anchors.fill: parent
        z: 10000
        source: root.startupPreviewSource
        asynchronous: false
        cache: false
        smooth: true
        fillMode: Image.Stretch
        visible: root.showStartupPreview && status === Image.Ready && !root.startupPrimaryContentVisible
        onStatusChanged: {
            if (
                status === Image.Error
                    && root.showStartupPreview
                    && !root.startupPreviewTriedFallback
                    && root.startupPreviewFallbackPath.length > 0
            ) {
                root.startupPreviewTriedFallback = true
                root.startupPreviewSource = startupController.toLocalFileUrl(root.startupPreviewFallbackPath) + "?v=" + String(Date.now())
                startupController.startupLog("preview fallback to jpg")
            }
        }
    }

    Rectangle {
        id: startupMaskLayer
        anchors.fill: parent
        z: 9999
        visible: !root.startupPrimaryContentVisible && !startupPreviewLayer.visible
        color: root.bgApp
    }

    PopupStyle { id: startupInventoryOverlayStyle }

    Rectangle {
        id: startupInventoryOverlay
        anchors.fill: parent
        z: 11000
        visible: root.startupInventoryRebuildInProgress
        color: startupInventoryOverlayStyle.overlayColor

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onPressed: function(mouse) { mouse.accepted = true }
            onClicked: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
        }

        Text {
            id: startupInventoryOverlayText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -28
            text: uiTokens.inventoryRebuildStatus
            color: root.textPrimary
            font.family: root.uiFontFamily
            font.pixelSize: root.fontPxUiBase
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
        }

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: startupInventoryOverlayText.bottom
            anchors.topMargin: 42
            running: startupInventoryOverlay.visible
            visible: startupInventoryOverlay.visible
            width: 28
            height: 28
        }
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
            onSettingsRequested: popupController.openExclusivePopup(settingsDialog)
            onRefreshRequested: libraryFacade.reload()
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
            Layout.preferredHeight: libraryFacade.lastError.length > 0 ? 30 : 0
            visible: libraryFacade.lastError.length > 0
            color: root.loadErrorBannerBg

            Label {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
                color: root.loadErrorBannerText
                text: "Load error: " + libraryFacade.lastError
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

            Rectangle {
                Layout.preferredWidth: root.sidebarWidth
                Layout.minimumWidth: root.sidebarWidth
                Layout.maximumWidth: root.sidebarWidth
                Layout.fillHeight: true
                color: root.bgSidebarEnd

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    clip: true

                    Canvas {
                        id: sidebarBackgroundCanvas
                        anchors.fill: parent
                        contextType: "2d"

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)

                            const gradientWidth = width * 1.8
                            const gradientHeight = height * 1.8

                            ctx.save()
                            ctx.translate(width / 2, height / 2)
                            ctx.rotate(-12 * Math.PI / 180)

                            const gradient = ctx.createLinearGradient(0, -gradientHeight / 2, 0, gradientHeight / 2)
                            gradient.addColorStop(0.0, root.bgSidebarStart)
                            gradient.addColorStop(1.0, root.bgSidebarEnd)
                            ctx.fillStyle = gradient
                            ctx.fillRect(-gradientWidth / 2, -gradientHeight / 2, gradientWidth, gradientHeight)
                            ctx.restore()

                            if (sidebarNoiseTexture.status !== Image.Ready)
                                return

                            ctx.save()
                            ctx.globalAlpha = 0.05
                            ctx.globalCompositeOperation = "qt-multiply"
                            ctx.fillStyle = ctx.createPattern(sidebarNoiseTexture, "repeat")
                            ctx.fillRect(0, 0, width, height)
                            ctx.restore()
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                    }

                    Image {
                        id: sidebarNoiseTexture
                        source: uiTokens.sidebarNoiseTexture
                        visible: false
                        smooth: false
                        onStatusChanged: {
                            if (status === Image.Ready)
                                sidebarBackgroundCanvas.requestPaint()
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 1
                    color: root.lineSidebarRight
                }

                Item {
                    anchors.fill: parent

                    Item {
                        id: sidebarSearchShell
                        x: (parent.width - width) / 2
                        y: 20
                        width: 268
                        height: 29

                        Image {
                            anchors.fill: parent
                            source: uiTokens.searchShellFrame
                            fillMode: Image.Stretch
                            smooth: true
                        }

                        Image {
                            id: sidebarSearchIcon
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            source: uiTokens.searchIcon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            opacity: (sidebarSearchField.hovered || sidebarSearchField.activeFocus) ? 1.0 : 0.5
                        }

                        TextField {
                            id: sidebarSearchField
                            anchors.fill: parent
                            leftPadding: 34
                            rightPadding: 12
                            topPadding: 8
                            bottomPadding: 0
                            hoverEnabled: true
                            font.pixelSize: root.fontPxUiBase
                            placeholderText: uiTokens.searchPlaceholder
                            text: root.sidebarSearchText
                            color: root.textPrimary
                            placeholderTextColor: root.searchPlaceholder
                            background: null
                            onTextChanged: {
                                root.sidebarSearchText = text
                                startupController.requestSnapshotSave()
                                if (root.suspendSidebarSearchRefresh) return
                                root.refreshSeriesList()
                            }
                        }
                    }

                    Column {
                        id: sidebarQuickFiltersColumn
                        x: 0
                        y: 68
                        width: parent.width
                        spacing: 6

                        SidebarQuickFilterItem {
                            title: "Last import"
                            issueCount: root.sidebarQuickFilterCount("last_import")
                            selected: root.sidebarQuickFilterKey === "last_import"
                            sidebarWidth: root.sidebarWidth
                            uiFontFamily: root.uiFontFamily
                            uiFontPixelSize: root.fontPxUiBase
                            textColor: root.textPrimary
                            hoverColor: root.sidebarRowHoverColor
                            idleIconSource: uiTokens.sidebarLastImportIdleIcon
                            activeIconSource: uiTokens.sidebarLastImportHoverIcon
                            onClicked: root.selectSidebarQuickFilter("last_import")
                        }

                        SidebarQuickFilterItem {
                            title: "Favorites"
                            issueCount: root.sidebarQuickFilterCount("favorites")
                            selected: root.sidebarQuickFilterKey === "favorites"
                            sidebarWidth: root.sidebarWidth
                            uiFontFamily: root.uiFontFamily
                            uiFontPixelSize: root.fontPxUiBase
                            textColor: root.textPrimary
                            hoverColor: root.sidebarRowHoverColor
                            idleIconSource: uiTokens.sidebarFavoritsIdleIcon
                            activeIconSource: uiTokens.sidebarFavoritsHoverIcon
                            onClicked: root.selectSidebarQuickFilter("favorites")
                        }

                        SidebarQuickFilterItem {
                            title: "Bookmarks"
                            issueCount: root.sidebarQuickFilterCount("bookmarks")
                            selected: root.sidebarQuickFilterKey === "bookmarks"
                            sidebarWidth: root.sidebarWidth
                            uiFontFamily: root.uiFontFamily
                            uiFontPixelSize: root.fontPxUiBase
                            textColor: root.textPrimary
                            hoverColor: root.sidebarRowHoverColor
                            idleIconSource: uiTokens.sidebarBookmarksIdleIcon
                            activeIconSource: uiTokens.sidebarBookmarksHoverIcon
                            onClicked: root.selectSidebarQuickFilter("bookmarks")
                        }
                    }

                    Item {
                        id: librarySectionLabel
                        x: 22
                        y: sidebarQuickFiltersColumn.y + sidebarQuickFiltersColumn.height + 19
                        width: 90
                        height: 14

                        Text {
                            x: 0
                            y: 2
                            text: "Library"
                            color: "#000000"
                            font.family: root.uiFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }

                        Text {
                            x: 0
                            y: 0
                            text: "Library"
                            color: root.textPrimary
                            font.family: root.uiFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                    }

                    ListView {
                        id: seriesListView
                        x: 0
                        y: librarySectionLabel.y + librarySectionLabel.height + 19
                        width: parent.width
                        height: Math.max(120, addFilesDropPanel.y - root.sidebarSeriesListBottomGap - y)
                        spacing: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        readonly property real effectiveFadeHeight: Math.max(24, Math.min(root.sidebarSeriesFadeHeight, height * 0.28))
                        model: seriesListModel
                        footer: Item {
                            width: seriesListView.width
                            height: Math.round(seriesListView.effectiveFadeHeight + root.sidebarSeriesBottomSafeOffset)
                        }
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                            visible: false
                            interactive: false
                            width: 0
                            height: 0
                        }
                        ScrollIndicator.vertical: ScrollIndicator {
                            visible: false
                            active: false
                            width: 0
                            height: 0
                        }

                        delegate: SidebarSeriesItem {
                            width: root.sidebarWidth
                            sidebarWidth: root.sidebarWidth
                            itemIndex: index
                            dismissToken: root.seriesMenuDismissToken
                            seriesKey: String(model.seriesKey || "")
                            seriesName: String(model.seriesTitle || "")
                            seriesIssueCount: Number(model.count || 0)
                            selected: String(root.sidebarQuickFilterKey || "").trim().length < 1
                                && root.isSeriesSelected(seriesKey)
                            importInProgress: root.importInProgress
                            menuDeleteOnly: root.selectedSeriesCount() > 1 && root.isSeriesSelected(seriesKey)
                            menuBulkEditMode: root.selectedSeriesCount() > 1 && root.isSeriesSelected(seriesKey)
                            menuDeleteLabel: (root.selectedSeriesCount() > 1 && root.isSeriesSelected(seriesKey))
                                ? "Delete selected"
                                : "Delete files"
                            uiFontFamily: root.uiFontFamily
                            uiFontPixelSize: root.fontPxUiBase
                            textColor: root.textPrimary
                            hoverColor: root.sidebarRowHoverColor
                            menuPopupBackgroundColor: root.uiMenuBackground
                            menuPopupHoverColor: root.uiMenuHoverBackground
                            menuPopupTextColor: root.uiMenuText
                            menuPopupDisabledTextColor: root.uiMenuTextDisabled
                            opacity: {
                                const fadeHeight = Math.max(1, seriesListView.effectiveFadeHeight)
                                const fadeStart = seriesListView.height - fadeHeight
                                const topInViewport = y - seriesListView.contentY
                                const centerInViewport = topInViewport + (height / 2)
                                if (centerInViewport <= fadeStart) return 1.0
                                if (centerInViewport >= seriesListView.height) return 0.0
                                const ratio = (centerInViewport - fadeStart) / fadeHeight
                                return Math.max(0.0, 1.0 - ratio)
                            }

                            onSeriesSelectionRequested: function(modifiers) { root.selectSeriesWithModifiers(seriesKey, seriesName, itemIndex, modifiers) }
                            onDismissMenusRequested: root.seriesMenuDismissToken += 1
                            onAddFilesRequested: root.quickAddFilesFromDialog()
                            onAddIssueRequested: root.quickAddFilesForSeries(seriesName)
                            onEditSeriesRequested: root.openSeriesMetadataDialog(seriesKey, seriesName)
                            onShowFolderRequested: root.openSeriesFolder(seriesKey, seriesName)
                            onClearSelectionRequested: root.clearSelection()
                            onRefreshRequested: libraryFacade.reload()
                            onDeleteSeriesRequested: deleteController.requestSeriesDelete(seriesKey, seriesName)
                        }

                    }

                    Item {
                        id: seriesScrollLayer
                        x: parent.width - width - 8
                        y: seriesListView.y
                        width: 8
                        height: seriesListView.height
                        visible: seriesListView.contentHeight > seriesListView.height
                        z: 2

                        function setScrollFromPointer(localY) {
                            const maxContentY = Math.max(0, seriesListView.contentHeight - seriesListView.height)
                            if (maxContentY <= 0) return
                            const knobHeight = seriesScrollKnob.height
                            const trackHeight = Math.max(1, seriesScrollLayer.height - knobHeight)
                            const unclamped = localY - knobHeight / 2
                            const clamped = Math.max(0, Math.min(trackHeight, unclamped))
                            const ratio = clamped / trackHeight
                            seriesListView.contentY = ratio * maxContentY
                        }

                        Rectangle {
                            id: seriesScrollKnob
                            width: 8
                            radius: width / 2
                            color: root.bgSidebarEnd
                            antialiasing: true
                            height: Math.max(36, Math.round(seriesScrollLayer.height * Math.min(1, seriesListView.visibleArea.heightRatio)))
                            y: {
                                const maxY = Math.max(0, seriesScrollLayer.height - height)
                                const visibleRatio = Math.max(0, Math.min(1, seriesListView.visibleArea.heightRatio))
                                const yPosition = Math.max(0, Math.min(1, seriesListView.visibleArea.yPosition))
                                const maxVisiblePosition = Math.max(0, 1 - visibleRatio)
                                const normalized = maxVisiblePosition > 0
                                    ? Math.max(0, Math.min(1, yPosition / maxVisiblePosition))
                                    : 0
                                return Math.round(maxY * normalized)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                seriesScrollLayer.setScrollFromPointer(mouse.y)
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) seriesScrollLayer.setScrollFromPointer(mouse.y)
                            }
                        }
                    }

                    Item {
                        id: addFilesDropPanel
                        width: 274
                        height: 173
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 19

                        Item {
                            id: addFilesDropHighlight
                            anchors.fill: parent
                            opacity: (dropZoneMouseArea.containsMouse || root.addFilesDropActive) ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: root.motionBaseMs
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            Canvas {
                                id: dropHighlightCanvas
                                anchors.fill: parent
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    const cx = width / 2
                                    const cy = height / 2
                                    const radius = Math.max(width, height) * 0.62
                                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius)
                                    g.addColorStop(0.0, "rgba(58,62,68,0.36)")
                                    g.addColorStop(0.68, "rgba(58,62,68,0.16)")
                                    g.addColorStop(1.0, "rgba(58,62,68,0.00)")
                                    ctx.fillStyle = g
                                    ctx.fillRect(0, 0, width, height)
                                }
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: uiTokens.dropZoneBorder
                            fillMode: Image.Stretch
                            smooth: true
                        }

                        Image {
                            id: addFilesDropIcon
                            width: 52
                            height: 55
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: uiTokens.dropZoneIcon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            id: dropZoneTitle
                            anchors.top: addFilesDropIcon.bottom
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 28
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily
                            font.pixelSize: root.fontPxDropTitle
                            font.bold: true
                            color: root.dropZoneTextColor
                            z: 1
                            text: "Drop archives here to add\nissues to library"
                        }

                        Text {
                            id: dropZoneTitleShadow
                            anchors.top: dropZoneTitle.top
                            anchors.topMargin: 1
                            anchors.horizontalCenter: dropZoneTitle.horizontalCenter
                            width: dropZoneTitle.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily
                            font.pixelSize: root.fontPxDropTitle
                            font.bold: true
                            color: root.uiTextShadow
                            text: dropZoneTitle.text
                            z: 0
                        }

                        Text {
                            id: dropZoneSubtitle
                            anchors.top: dropZoneTitle.bottom
                            anchors.topMargin: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 28
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily
                            font.pixelSize: root.fontPxDropSubtitle
                            color: root.dropZoneTextColor
                            z: 1
                            text: "Supports any archive files"
                        }

                        Text {
                            anchors.top: dropZoneSubtitle.top
                            anchors.topMargin: 1
                            anchors.horizontalCenter: dropZoneSubtitle.horizontalCenter
                            width: dropZoneSubtitle.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.family: root.uiFontFamily
                            font.pixelSize: root.fontPxDropSubtitle
                            color: root.uiTextShadow
                            text: dropZoneSubtitle.text
                            z: 0
                        }

                        MouseArea {
                            id: dropZoneMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.importInProgress
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.quickAddFilesFromDialog()
                        }

                        DropArea {
                            anchors.fill: parent
                            enabled: !root.importInProgress

                            onEntered: root.addFilesDropActive = true
                            onExited: root.addFilesDropActive = false
                            onDropped: function(drop) {
                                root.addFilesDropActive = false
                                const urls = drop.urls || []
                                const paths = []
                                for (let i = 0; i < urls.length; i += 1) {
                                    const rawPath = String(urls[i] || "").trim()
                                    if (rawPath.length > 0) {
                                        paths.push(rawPath)
                                    }
                                }
                                if (paths.length < 1) {
                                    popupController.showActionResult("Drop Contains No Local Files.", true)
                                    return
                                }
                                if (root.startImportFromSourcePaths(
                                            paths,
                                            { importIntent: "global_add" },
                                            "Drop Contains No Supported Comic Sources."
                                        )) {
                                    drop.acceptProposedAction()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.bgContent
                clip: true

                Item {
                    id: rightPane
                    anchors.fill: parent

                    Item {
                        id: libraryBackgroundLayer
                        anchors.fill: parent
                        z: -1

                        Rectangle {
                            anchors.fill: parent
                            color: root.libraryBackgroundMode === "Solid"
                                ? root.libraryBackgroundSolidColor
                                : root.bgContent
                        }

                        Image {
                            id: gridTileBackground
                            anchors.fill: parent
                            visible: root.libraryBackgroundMode === "Default"
                                || (root.libraryBackgroundMode === "Texture"
                                    && root.libraryBackgroundTexturePreset === "Dots")
                                || (root.libraryBackgroundMode === "Custom image"
                                    && root.libraryBackgroundCustomImageSource.length < 1)
                            source: uiTokens.gridTile
                            fillMode: Image.Tile
                            smooth: false
                            opacity: root.libraryBackgroundMode === "Default" ? root.gridTileOpacity : 0.86
                        }

                        Image {
                            anchors.fill: parent
                            visible: root.libraryBackgroundMode === "Texture"
                                && root.libraryBackgroundTexturePreset === "Noise"
                            source: root.libraryTextureSource
                            fillMode: Image.Tile
                            smooth: false
                            opacity: 0.92
                        }

                        Image {
                            anchors.fill: parent
                            visible: root.libraryBackgroundMode === "Custom image"
                                && root.libraryBackgroundCustomImageSource.length > 0
                            source: root.libraryBackgroundCustomImageSource
                            fillMode: root.libraryBackgroundCustomImageMode === "Fit"
                                ? Image.PreserveAspectFit
                                : root.libraryBackgroundCustomImageMode === "Stretch"
                                    ? Image.Stretch
                                    : root.libraryBackgroundCustomImageMode === "Tile"
                                        ? Image.Tile
                                        : Image.PreserveAspectCrop
                            sourceSize: root.libraryBackgroundCustomImageMode === "Tile"
                                ? Qt.size(root.libraryBackgroundTilePixelSize, root.libraryBackgroundTilePixelSize)
                                : Qt.size(0, 0)
                            smooth: root.libraryBackgroundCustomImageMode !== "Tile"
                            asynchronous: true
                            cache: true
                        }
                    }

                    readonly property bool quickFilterMode: root.isQuickFilterModeActive()
                    readonly property string contentMode: quickFilterMode ? "quick_filter" : "series"
                    readonly property bool heroSectionVisible: !quickFilterMode && root.libraryShowHeroBlock
                    readonly property real activeGridTopMargin: quickFilterMode
                        ? quickFilterChrome.height
                        : heroLayoutHeight
                    readonly property int activeGridSafeTop: quickFilterMode
                        ? 0
                        : (heroSectionVisible ? 26 : 0)
                    readonly property string activeEmptyStateText: quickFilterMode
                        ? root.quickFilterEmptyText(root.sidebarQuickFilterKey)
                        : ""
                    readonly property bool activeEmptyStateVisible: quickFilterMode
                        && Number(root.issuesGridData.length || 0) < 1
                    readonly property real heroMinHeight: 0
                    readonly property real heroLayoutHeight: heroSectionVisible
                        ? Math.max(0, root.heroBlockHeight - heroCollapseOffset)
                        : 0
                    readonly property real heroVisualHeight: heroSectionVisible
                        ? Math.max(heroLayoutHeight, manualHeroRevealHeight)
                        : 0
                    readonly property real heroCollapseRange: heroSectionVisible
                        ? Math.max(0, root.heroBlockHeight - heroMinHeight)
                        : 0
                    readonly property bool heroCollapsed: heroSectionVisible
                        && heroCollapseOffset >= heroCollapseRange - 0.5
                    readonly property real heroCollapseProgress: heroCollapseRange > 0
                        ? Math.max(0, Math.min(1, heroCollapseOffset / heroCollapseRange))
                        : 0
                    readonly property real notchOpacity: (!heroSectionVisible || !hasIssueOverflow || !heroCollapsed)
                        ? 1.0
                        : 0.0
                    readonly property bool showInfoVisible: heroSectionVisible && hasIssueOverflow && heroCollapsed
                    readonly property var activeIssuesFlick: issuesFlick
                    readonly property real maxGridScrollRange: Math.max(
                        0,
                        Number(activeIssuesFlick ? activeIssuesFlick.contentHeight : 0)
                            + Number(activeIssuesFlick ? activeIssuesFlick.topMargin : 0)
                            + Number(activeIssuesFlick ? activeIssuesFlick.bottomMargin : 0)
                            - Number(activeIssuesFlick ? activeIssuesFlick.height : 0)
                    )
                    readonly property bool hasIssueOverflow: maxGridScrollRange > 0.5
                    readonly property real totalSplitScrollRange: hasIssueOverflow ? (heroCollapseRange + maxGridScrollRange) : 0
                    readonly property real currentSplitScroll: heroCollapseOffset + root.normalizedGridScrollValue()
                    property real heroCollapseOffset: 0
                    property bool scrollSyncInProgress: false
                    property real smoothScrollValue: 0
                    property real smoothScrollTarget: 0
                    property bool smoothScrollActive: false
                    property bool smoothScrollApplying: false
                    property real manualHeroRevealHeight: 0
                    readonly property bool manualHeroRevealActive: manualHeroRevealHeight > 0.5

                    onWidthChanged: scheduleResolvedOverflowSync()
                    onHeightChanged: scheduleResolvedOverflowSync()
                    onQuickFilterModeChanged: {
                        heroCollapseAnimation.stop()
                        manualHeroRevealAnimation.stop()
                        stopSmoothScroll()
                        heroCollapseOffset = 0
                        manualHeroRevealHeight = 0
                    }
                    onHeroSectionVisibleChanged: {
                        heroCollapseAnimation.stop()
                        manualHeroRevealAnimation.stop()
                        stopSmoothScroll()
                        heroCollapseOffset = 0
                        manualHeroRevealHeight = 0
                        scheduleResolvedOverflowSync()
                    }

                    function syncHeroWithResolvedOverflow() {
                        if (!hasIssueOverflow && (heroCollapseOffset > 0 || root.normalizedGridScrollValue() > 0)) {
                            const wasSync = scrollSyncInProgress
                            scrollSyncInProgress = true
                            heroCollapseOffset = 0
                            root.setGridScrollToTop()
                            scrollSyncInProgress = wasSync
                            stopSmoothScroll()
                        }
                    }

                    function scheduleResolvedOverflowSync() {
                        resolvedOverflowSyncTimer.restart()
                    }

                    onMaxGridScrollRangeChanged: scheduleResolvedOverflowSync()

                    function clampSplitScroll(value) {
                        return Math.max(0, Math.min(totalSplitScrollRange, Number(value || 0)))
                    }

                    function stopSmoothScroll() {
                        smoothScrollAnimation.stop()
                        smoothScrollTarget = currentSplitScroll
                        smoothScrollActive = false
                    }

                    function animateManualHeroReveal(targetHeight) {
                        const clamped = Math.max(0, Math.min(root.heroBlockHeight, Number(targetHeight || 0)))
                        manualHeroRevealAnimation.stop()
                        manualHeroRevealAnimation.to = clamped
                        manualHeroRevealAnimation.start()
                    }

                    function animateHeroTo(targetOffset) {
                        stopSmoothScroll()
                        const clamped = Math.max(0, Math.min(heroCollapseRange, Number(targetOffset || 0)))
                        heroCollapseAnimation.stop()
                        heroCollapseAnimation.to = clamped
                        heroCollapseAnimation.start()
                    }

                    function toggleHeroPanel() {
                        if (manualHeroRevealActive) {
                            animateManualHeroReveal(0)
                            return
                        }
                        if (heroCollapsed) {
                            animateManualHeroReveal(root.heroBlockHeight)
                            return
                        }
                        animateHeroTo(heroCollapseRange)
                    }

                    function setAbsoluteSplitScroll(targetValue) {
                        const clamped = clampSplitScroll(targetValue)
                        if (Math.abs(clamped - currentSplitScroll) > 0.1) {
                            root.dismissGridOverlayMenusForScroll()
                        }
                        heroCollapseAnimation.stop()
                        const wasSync = scrollSyncInProgress
                        scrollSyncInProgress = true
                        if (clamped <= heroCollapseRange) {
                            heroCollapseOffset = clamped
                            root.setGridScrollToTop()
                        } else {
                            heroCollapseOffset = heroCollapseRange
                            root.setNormalizedGridScrollValue(Math.min(maxGridScrollRange, clamped - heroCollapseRange))
                        }
                        scrollSyncInProgress = wasSync
                    }

                    function animateSplitScrollTo(targetValue) {
                        const clamped = clampSplitScroll(targetValue)
                        if (!hasIssueOverflow) {
                            setAbsoluteSplitScroll(clamped)
                            return
                        }
                        smoothScrollTarget = clamped
                        smoothScrollAnimation.stop()
                        smoothScrollApplying = true
                        smoothScrollValue = currentSplitScroll
                        smoothScrollApplying = false
                        smoothScrollAnimation.from = smoothScrollValue
                        smoothScrollAnimation.to = smoothScrollTarget
                        smoothScrollActive = true
                        smoothScrollAnimation.start()
                    }

                    function applySplitScroll(deltaPixels) {
                        const delta = Number(deltaPixels || 0)
                        if (Math.abs(delta) < 0.1) return
                        root.dismissGridOverlayMenusForScroll()
                        if (manualHeroRevealActive && delta < 0) {
                            manualHeroRevealAnimation.stop()
                            manualHeroRevealHeight = 0
                        }
                        const base = smoothScrollActive ? smoothScrollTarget : currentSplitScroll
                        animateSplitScrollTo(base + delta)
                    }

                    NumberAnimation {
                        id: heroCollapseAnimation
                        target: rightPane
                        property: "heroCollapseOffset"
                        duration: root.motionBaseMs
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        id: manualHeroRevealAnimation
                        target: rightPane
                        property: "manualHeroRevealHeight"
                        duration: root.motionBaseMs
                        easing.type: Easing.InOutQuad
                    }

                    onSmoothScrollValueChanged: {
                        if (smoothScrollApplying) return
                        setAbsoluteSplitScroll(smoothScrollValue)
                    }

                    NumberAnimation {
                        id: smoothScrollAnimation
                        target: rightPane
                        property: "smoothScrollValue"
                        duration: root.motionSlowMs
                        easing.type: Easing.InOutCubic
                        onStopped: {
                            rightPane.smoothScrollActive = false
                            rightPane.setAbsoluteSplitScroll(rightPane.smoothScrollTarget)
                        }
                    }

                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(wheelEvent) {
                            const pxDelta = wheelEvent.pixelDelta.y !== 0
                                ? -wheelEvent.pixelDelta.y
                                : (-wheelEvent.angleDelta.y / 120.0) * 36.0
                            rightPane.applySplitScroll(pxDelta)
                            wheelEvent.accepted = true
                        }
                    }

                    Timer {
                        id: resolvedOverflowSyncTimer
                        interval: 0
                        repeat: false
                        running: false
                        onTriggered: rightPane.syncHeroWithResolvedOverflow()
                    }

                    Item {
                        id: heroLayoutSpacer
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: rightPane.heroLayoutHeight
                        visible: rightPane.heroSectionVisible
                    }

                    Rectangle {
                        id: heroBlock
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: rightPane.heroVisualHeight
                        color: root.bgHeroBase
                        clip: true
                        visible: rightPane.heroSectionVisible
                        z: 2
                        readonly property bool editIconsVisible: heroBlockHover.hovered
                        Component.onCompleted: {
                            root.markStartupColdRenderOnce("hero", "height=" + String(height))
                        }

                        HoverHandler {
                            id: heroBlockHover
                        }

                        Item {
                            anchors.fill: parent
                            clip: true
                            visible: root.selectedSeriesKey.length > 0 && heroSeriesController.currentHeroBackgroundSource().length > 0

                            Image {
                                id: heroBackgroundImage
                                readonly property real resolvedSourceWidth: Math.max(3000, Number(sourceSize.width || 0))
                                readonly property real resolvedSourceHeight: Math.max(1000, Number(sourceSize.height || 0))
                                // Keep extra vertical bleed so the notch under hero can sample image pixels
                                // instead of falling back to solid hero color at default window width.
                                readonly property real notchBleedHeight: (root.gridNotchDepth * 2) + 2
                                readonly property real fillScale: Math.max(
                                    parent.width / resolvedSourceWidth,
                                    (parent.height + notchBleedHeight) / resolvedSourceHeight
                                )
                                x: Math.round((parent.width - width) / 2)
                                y: Math.round((parent.height - height) / 2)
                                width: Math.ceil(resolvedSourceWidth * fillScale)
                                height: Math.ceil(resolvedSourceHeight * fillScale)
                                source: heroSeriesController.currentHeroBackgroundSource()
                                asynchronous: true
                                cache: true
                                smooth: true
                                opacity: 0.08
                            }
                        }

                        BorderImage {
                            anchors.fill: parent
                            source: uiTokens.heroSlice
                            horizontalTileMode: BorderImage.Stretch
                            verticalTileMode: BorderImage.Stretch
                            border.left: 25
                            border.right: 25
                            border.top: 27
                            border.bottom: 17
                            smooth: true
                        }

                        Item {
                            id: heroSeriesCoverLayer
                            x: 25
                            y: 19
                            width: 172
                            height: 256
                            visible: root.selectedSeriesKey.length > 0

                            Item {
                                id: heroSeriesCoverImageShell
                                x: 0
                                y: 0
                                width: 158
                                height: 243
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: root.heroCoverPlaceholderColor
                                }

                                Image {
                                    anchors.fill: parent
                                    source: heroSeriesController.currentHeroCoverSource()
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                }
                            }

                            Image {
                                x: 0
                                y: 0
                                width: 172
                                height: 256
                                source: uiTokens.coverShading
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Item {
                                x: heroSeriesCoverImageShell.x + heroSeriesCoverImageShell.width - width - 6
                                y: heroSeriesCoverImageShell.y + heroSeriesCoverImageShell.height - height - 6
                                width: 28
                                height: 28
                                visible: heroBlock.editIconsVisible
                                z: 10

                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: coverEditMouseArea.containsMouse
                                        ? uiTokens.pencilLineWhiteIcon
                                        : uiTokens.pencilLineGrayIcon
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                }

                                MouseArea {
                                    id: coverEditMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: startupController.launchLog("series_header_cover_icon_pressed key=" + String(root.selectedSeriesKey || ""))
                                    onClicked: {
                                        startupController.launchLog("series_header_cover_icon_clicked key=" + String(root.selectedSeriesKey || ""))
                                        seriesHeaderController.openDialog(root.selectedSeriesKey)
                                    }
                                }
                            }
                        }

                        Item {
                            id: heroPublisherLogoArea
                            width: 162
                            height: 162
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 32
                            z: 0
                            visible: root.selectedSeriesKey.length > 0
                                && String(root.heroSeriesData.logoSource || "").length > 0

                            readonly property var logoLayout: PublisherCatalog.logoLayoutForPublisher(
                                String(root.heroSeriesData.publisher || "")
                            )
                            readonly property int logoMaxWidth: Math.max(1, Number((logoLayout || {}).maxWidth || 56))
                            readonly property int logoMaxHeight: Math.max(1, Number((logoLayout || {}).maxHeight || 44))

                            Item {
                                id: heroPublisherLogoContent
                                anchors.top: parent.top
                                anchors.topMargin: 0
                                anchors.right: parent.right
                                anchors.rightMargin: 0
                                width: heroPublisherLogoArea.logoMaxWidth
                                height: heroPublisherLogoArea.logoMaxHeight
                                readonly property real sourceAspectRatio: logoMetricsImage.status === Image.Ready
                                    && logoMetricsImage.implicitWidth > 0
                                    && logoMetricsImage.implicitHeight > 0
                                    ? logoMetricsImage.implicitWidth / logoMetricsImage.implicitHeight
                                    : 1.0
                                readonly property real fittedWidth: {
                                    const ratio = Math.max(0.001, sourceAspectRatio)
                                    return Math.min(width, height * ratio)
                                }
                                readonly property real fittedHeight: {
                                    const ratio = Math.max(0.001, sourceAspectRatio)
                                    return Math.min(height, width / ratio)
                                }

                                Image {
                                    id: logoMetricsImage
                                    visible: false
                                    source: String(root.heroSeriesData.logoSource || "")
                                }

                                Image {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 1
                                    anchors.rightMargin: 1
                                    width: heroPublisherLogoContent.fittedWidth
                                    height: heroPublisherLogoContent.fittedHeight
                                    source: String(root.heroSeriesData.logoSource || "")
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    opacity: 0.35
                                }

                                Image {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    width: heroPublisherLogoContent.fittedWidth
                                    height: heroPublisherLogoContent.fittedHeight
                                    source: String(root.heroSeriesData.logoSource || "")
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }
                        }

                        Item {
                            id: heroTextLayer
                            x: heroSeriesCoverLayer.x + heroSeriesCoverLayer.width + 36
                            y: 24
                            width: {
                                const rightLimit = heroBlock.width - 138
                                return Math.max(0, rightLimit - x)
                            }
                            height: Math.max(0, heroBlock.height - y - 16)
                            z: 2
                            visible: root.selectedSeriesKey.length > 0

                            Text {
                                id: heroSeriesLabel
                                x: 0
                                y: 0
                                width: parent.width
                                text: "Series:"
                                color: root.textMuted
                                font.family: root.uiFontFamily
                                font.pixelSize: root.fontUiMuted
                                font.weight: Font.Normal
                            }

                            Text {
                                id: heroSeriesTitleText
                                x: 0
                                y: heroSeriesLabel.y + heroSeriesLabel.implicitHeight + 14
                                width: parent.width
                                text: String(root.heroSeriesData.seriesTitle || root.selectedSeriesTitle || "")
                                color: root.textPrimary
                                font.family: root.uiFontFamily
                                font.pixelSize: root.fontUiHeading
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                            }

                            Text {
                                id: heroSummaryLabel
                                x: 0
                                y: heroSeriesTitleText.y + heroSeriesTitleText.implicitHeight + 24
                                width: parent.width
                                text: "Summary:"
                                color: root.textMuted
                                font.family: root.uiFontFamily
                                font.pixelSize: root.fontUiMuted
                                font.weight: Font.Normal
                            }

                            Text {
                                id: heroSummaryText
                                x: 0
                                y: heroSummaryLabel.y + heroSummaryLabel.implicitHeight + 14
                                width: parent.width
                                height: implicitHeight
                                text: String(root.heroSeriesData.summary || "-")
                                color: root.textPrimary
                                font.family: root.uiFontFamily
                                font.pixelSize: root.fontUiPrimary
                                font.weight: Font.Normal
                                wrapMode: Text.WordWrap
                                maximumLineCount: 7
                                elide: Text.ElideRight
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 17
                                visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.summary)
                            }

                            HeroEditIconButton {
                                x: 0
                                y: heroSummaryLabel.y + heroSummaryLabel.implicitHeight + 14
                                visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.summary)
                                onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "summary")
                            }

                            Item {
                                id: heroMetaGrid
                                x: 0
                                y: heroSummaryText.y + heroSummaryText.height + 24
                                width: parent.width
                                height: heroMetaGrid.singleRowLayout ? 24 : 56

                                property bool singleRowLayout: width >= heroMetaGrid.singleRowRequiredWidth
                                property int labelWidth: 54
                                property int valueWidth: 160
                                property int columnGap: 6
                                property int rowGap: 24
                                property int col2LabelX: labelWidth + columnGap + valueWidth + columnGap
                                property int col2ValueX: col2LabelX + labelWidth + columnGap
                                property int pairBlockWidth: labelWidth + columnGap + valueWidth
                                property int singleRowRequiredWidth: pairBlockWidth * 4 + columnGap * 3
                                property int pairLabelWidth: labelWidth
                                property int pairValueWidth: valueWidth
                                property int pair1LabelX: 0
                                property int pair1ValueX: pair1LabelX + labelWidth + columnGap
                                property int pair2LabelX: col2LabelX
                                property int pair2ValueX: pair2LabelX + pairLabelWidth + columnGap
                                property int pair3LabelX: singleRowLayout ? (pairBlockWidth + columnGap) * 2 : 0
                                property int pair3ValueX: pair3LabelX + pairLabelWidth + columnGap
                                property int pair4LabelX: singleRowLayout ? (pairBlockWidth + columnGap) * 3 : col2LabelX
                                property int pair4ValueX: pair4LabelX + pairLabelWidth + columnGap
                                property int topRowY: 0
                                property int bottomRowY: singleRowLayout ? 0 : 24

                                Text {
                                    x: heroMetaGrid.pair1LabelX
                                    y: heroMetaGrid.topRowY
                                    width: heroMetaGrid.pairLabelWidth
                                    text: "Year:"
                                    color: root.textMuted
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiMuted
                                }

                                Text {
                                    id: heroYearValueText
                                    x: heroMetaGrid.pair1ValueX
                                    y: heroMetaGrid.topRowY
                                    width: heroMetaGrid.pairValueWidth
                                    text: String(root.heroSeriesData.year || "-")
                                    color: root.textPrimary
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiPrimary
                                    elide: Text.ElideRight
                                    visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.year)
                                }

                                HeroEditIconButton {
                                    x: heroMetaGrid.pair1ValueX
                                    y: heroMetaGrid.topRowY
                                    visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.year)
                                    onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "year")
                                }

                                Text {
                                    x: heroMetaGrid.pair2LabelX
                                    y: heroMetaGrid.topRowY
                                    width: heroMetaGrid.pairLabelWidth
                                    text: "Volume:"
                                    color: root.textMuted
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiMuted
                                }

                                Text {
                                    id: heroVolumeValueText
                                    x: heroMetaGrid.pair2ValueX
                                    y: heroMetaGrid.topRowY
                                    width: heroMetaGrid.pairValueWidth
                                    text: String(root.heroSeriesData.volume || "-")
                                    color: root.textPrimary
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiPrimary
                                    elide: Text.ElideRight
                                    visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.volume)
                                }

                                HeroEditIconButton {
                                    x: heroMetaGrid.pair2ValueX
                                    y: heroMetaGrid.topRowY
                                    visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.volume)
                                    onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "volume")
                                }

                                Text {
                                    x: heroMetaGrid.pair3LabelX
                                    y: heroMetaGrid.bottomRowY
                                    width: heroMetaGrid.pairLabelWidth
                                    text: "Publisher:"
                                    color: root.textMuted
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiMuted
                                }

                                Text {
                                    id: heroPublisherValueText
                                    x: heroMetaGrid.pair3ValueX
                                    y: heroMetaGrid.bottomRowY
                                    width: heroMetaGrid.pairValueWidth
                                    text: String(root.heroSeriesData.publisher || "-")
                                    color: root.textPrimary
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiPrimary
                                    elide: Text.ElideRight
                                    visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.publisher)
                                }

                                HeroEditIconButton {
                                    x: heroMetaGrid.pair3ValueX
                                    y: heroMetaGrid.bottomRowY
                                    visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.publisher)
                                    onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "publisher")
                                }

                                Text {
                                    x: heroMetaGrid.pair4LabelX
                                    y: heroMetaGrid.bottomRowY
                                    width: heroMetaGrid.pairLabelWidth
                                    text: "Genres:"
                                    color: root.textMuted
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiMuted
                                }

                                Text {
                                    id: heroGenresValueText
                                    x: heroMetaGrid.pair4ValueX
                                    y: heroMetaGrid.bottomRowY
                                    width: heroMetaGrid.pairValueWidth
                                    text: String(root.heroSeriesData.genres || "-")
                                    color: root.textPrimary
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontUiPrimary
                                    elide: Text.ElideRight
                                    visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.genres)
                                }

                                HeroEditIconButton {
                                    x: heroMetaGrid.pair4ValueX
                                    y: heroMetaGrid.bottomRowY
                                    visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.genres)
                                    onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "genres")
                                }
                            }
                        }
                    }

                    Item {
                        id: quickFilterChrome
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: visible ? 87 : 0
                        visible: rightPane.quickFilterMode

                        Item {
                            x: 40
                            y: 30
                            width: Math.max(0, parent.width - 80)
                            height: 27

                            Image {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 27
                                height: 27
                                source: root.quickFilterTitleIconSource(root.sidebarQuickFilterKey)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 37
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.quickFilterTitleText(root.sidebarQuickFilterKey)
                                color: root.textPrimary
                                font.family: root.uiFontFamily
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Item {
                        id: gridViewport
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: rightPane.activeGridTopMargin
                        anchors.bottom: parent.bottom
                        clip: true

                        GridView {
                            id: issuesFlick
                            anchors.fill: parent
                            clip: false
                            interactive: false
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: 160
                            reuseItems: true
                            model: root.issuesGridData
                            z: 1
                            leftMargin: safeZoneLeft
                            rightMargin: safeZoneRight
                            topMargin: safeZoneTop
                            bottomMargin: safeZoneBottom
                            property int spacing: 0
                            property int cardHeight: root.libraryGridDensity === "Compact"
                                ? 312
                                : root.libraryGridDensity === "Comfortable"
                                    ? 344
                                    : 328
                            property int minCardWidth: root.libraryGridDensity === "Compact"
                                ? 196
                                : root.libraryGridDensity === "Comfortable"
                                    ? 220
                                    : 208
                            property int safeZoneLeft: 40
                            property int safeZoneRight: 40
                            property int safeZoneTop: rightPane.activeGridSafeTop
                            property int safeZoneBottom: 18
                            property int layoutWidth: Math.max(1, width - safeZoneLeft - safeZoneRight)
                            property int columns: Math.max(1, Math.floor((layoutWidth + spacing) / (minCardWidth + spacing)))
                            property int cardWidth: Math.max(minCardWidth, Math.floor((layoutWidth - ((columns - 1) * spacing)) / columns))

                            onWidthChanged: rightPane.scheduleResolvedOverflowSync()
                            onHeightChanged: rightPane.scheduleResolvedOverflowSync()
                            onContentHeightChanged: {
                                rightPane.scheduleResolvedOverflowSync()
                                if (root.gridSplitScrollRestorePending) {
                                    gridSplitScrollRestoreTimer.restart()
                                }
                            }

                            Component.onCompleted: {
                                root.setGridScrollToTop()
                                root.markStartupColdRenderOnce(
                                    "grid",
                                    "columns=" + String(columns)
                                    + " cardWidth=" + String(cardWidth)
                                    + " cardHeight=" + String(cardHeight)
                                )
                            }

                            cellWidth: cardWidth + spacing
                            cellHeight: cardHeight + spacing

                            delegate: Item {
                                readonly property var itemData: modelData || ({})

                                readonly property int comicId: Number(itemData.id || 0)
                                readonly property string series: String(itemData.series || "")
                                readonly property string volume: String(itemData.volume || "")
                                readonly property string title: String(itemData.title || "")
                                readonly property string issueNumber: String(itemData.issueNumber || "")
                                readonly property string publisher: String(itemData.publisher || "")
                                readonly property int year: Number(itemData.year || 0)
                                readonly property int month: Number(itemData.month || 0)
                                readonly property string writer: String(itemData.writer || "")
                                readonly property string penciller: String(itemData.penciller || "")
                                readonly property string inker: String(itemData.inker || "")
                                readonly property string colorist: String(itemData.colorist || "")
                                readonly property string letterer: String(itemData.letterer || "")
                                readonly property string coverArtist: String(itemData.coverArtist || "")
                                readonly property string editor: String(itemData.editor || "")
                                readonly property string storyArc: String(itemData.storyArc || "")
                                readonly property string summary: String(itemData.summary || "")
                                readonly property string characters: String(itemData.characters || "")
                                readonly property string genres: String(itemData.genres || "")
                                readonly property string ageRating: String(itemData.ageRating || "")
                                readonly property string readStatus: String(itemData.readStatus || "")
                                readonly property bool hasBookmark: Boolean(itemData.hasBookmark)
                                readonly property int currentPage: Number(itemData.currentPage || 0)
                                readonly property string filename: String(itemData.filename || "")
                                readonly property string coverSource: root.coverSourceForComic(comicId)
                                property bool coverRequested: false

                                width: issuesFlick.cardWidth
                                height: issuesFlick.cardHeight

                                function requestCover() {
                                    if (root.restoringStartupSnapshot || root.startupHydrationInProgress) return
                                    if (comicId < 1 || coverRequested) return
                                    if (root.coverSourceForComic(comicId).length > 0) {
                                        coverRequested = true
                                        return
                                    }
                                    coverRequested = true
                                    root.requestIssueThumbnail(comicId)
                                }

                                onVisibleChanged: requestCover()
                                onComicIdChanged: {
                                    coverRequested = false
                                    requestCover()
                                }
                                Component.onCompleted: requestCover()

                                IssueCard {
                                    anchors.fill: parent
                                    hoverUiEnabled: !metadataDialog.visible
                                    actionMenuSuppressed: root.gridOverlayMenusSuppressed
                                    uiFontFamily: root.uiFontFamily
                                    uiFontPixelSize: root.fontPxUiBase
                                    comicId: parent.comicId
                                    issueNumber: parent.issueNumber
                                    issueTitle: parent.title
                                    fallbackTitle: parent.filename
                                    coverSource: parent.coverSource
                                    hasBookmark: parent.hasBookmark
                                    readStatus: parent.readStatus
                                    selected: root.isSelected(parent.comicId)
                                    openingInProgress: root.readerLoading && Number(root.readerComicId || 0) === Number(parent.comicId || 0)
                                    openingOverlayColor: root.readerLoadingChipBgColor
                                    cardColor: root.cardBg
                                    textPrimary: root.textPrimary
                                    textMuted: root.textMuted
                                    textShadowColor: root.uiTextShadow
                                    actionMenuBackgroundColor: root.bgApp
                                    actionMenuHoverColor: root.uiActionHoverBackground
                                    actionMenuBoundsItem: rightPane
                                    hoverOverlayColor: root.cardHoverOverlay
                                    selectedOverlayColor: root.cardSelectedOverlay
                                    onStartupCardCreated: {
                                        root.markStartupColdRenderOnce(
                                            "firstCard",
                                            "comicId=" + String(parent.comicId)
                                            + " issue=" + String(parent.issueNumber)
                                        )
                                    }
                                    onStartupCoverReady: {
                                        root.markStartupColdRenderOnce(
                                            "firstCover",
                                            "comicId=" + String(parent.comicId)
                                            + " source=" + String(parent.coverSource)
                                        )
                                    }

                                    onReadRequested: root.openReader(parent.comicId, parent.title.length > 0 ? parent.title : parent.filename)
                                    onSelectionToggled: function(checked) { root.setSelected(parent.comicId, checked) }
                                    onToggleSelectedRequested: root.setSelected(parent.comicId, !root.isSelected(parent.comicId))
                                    onDeleteRequested: deleteController.requestDelete(parent.comicId)
                                    onMarkUnreadRequested: root.markIssueUnread(parent.comicId)
                                    onReplaceRequested: root.replaceIssueArchive(parent.comicId)
                                    onEditRequested: {
                                        root.openMetadataEditor({
                                            id: parent.comicId,
                                            series: parent.series,
                                            volume: parent.volume,
                                            title: parent.title,
                                            issueNumber: parent.issueNumber,
                                            publisher: parent.publisher,
                                            year: parent.year,
                                            month: parent.month,
                                            writer: parent.writer,
                                            penciller: parent.penciller,
                                            inker: parent.inker,
                                            colorist: parent.colorist,
                                            letterer: parent.letterer,
                                            coverArtist: parent.coverArtist,
                                            editor: parent.editor,
                                            storyArc: parent.storyArc,
                                            summary: parent.summary,
                                            characters: parent.characters,
                                            genres: parent.genres,
                                            ageRating: parent.ageRating,
                                            readStatus: parent.readStatus,
                                            currentPage: parent.currentPage
                                        })
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: rightPane.activeEmptyStateText
                            color: "#515151"
                            font.family: root.uiFontFamily
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            visible: rightPane.activeEmptyStateVisible
                            z: 3
                        }

                        Item {
                            id: gridShadowsOverlay
                            anchors.fill: parent
                            visible: true
                            z: 4

                            readonly property int edgeThickness: 21
                            readonly property int cornerWidth: 21
                            readonly property int cornerHeight: 155

                            Image {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: gridShadowsOverlay.cornerHeight
                                width: gridShadowsOverlay.edgeThickness
                                source: uiTokens.gridEdgeLeft
                                fillMode: Image.TileVertically
                                smooth: true
                            }

                            Image {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: gridShadowsOverlay.cornerHeight
                                width: gridShadowsOverlay.edgeThickness
                                source: uiTokens.gridEdgeRight
                                fillMode: Image.TileVertically
                                smooth: true
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: gridShadowsOverlay.cornerWidth
                                anchors.right: parent.right
                                anchors.rightMargin: gridShadowsOverlay.cornerWidth
                                anchors.bottom: parent.bottom
                                height: gridShadowsOverlay.cornerHeight
                                source: uiTokens.gridEdgeBottom
                                fillMode: Image.TileHorizontally
                                smooth: true
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                width: gridShadowsOverlay.cornerWidth
                                height: gridShadowsOverlay.cornerHeight
                                source: uiTokens.gridCornerBottomLeft
                                fillMode: Image.Stretch
                                smooth: true
                            }

                            Image {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: gridShadowsOverlay.cornerWidth
                                height: gridShadowsOverlay.cornerHeight
                                source: uiTokens.gridCornerBottomRight
                                fillMode: Image.Stretch
                                smooth: true
                            }
                        }

                        Item {
                            id: gridTopEdge
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: root.gridNotchDepth
                            visible: rightPane.heroSectionVisible && !rightPane.manualHeroRevealActive
                            z: 5

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: gridNotch.left
                                anchors.top: parent.top
                                height: 1
                                color: root.gridEdgeColor
                            }

                            Rectangle {
                                anchors.left: gridNotch.right
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 1
                                color: root.gridEdgeColor
                            }

                            Rectangle {
                                anchors.left: gridNotch.left
                                anchors.right: gridNotch.right
                                anchors.top: parent.top
                                height: 1
                                color: root.gridEdgeColor
                                opacity: 1.0 - rightPane.notchOpacity
                            }

                            Connections {
                                target: heroBackgroundImage

                                function onXChanged() { gridNotch.requestPaint() }
                                function onYChanged() { gridNotch.requestPaint() }
                                function onWidthChanged() { gridNotch.requestPaint() }
                                function onHeightChanged() { gridNotch.requestPaint() }
                                function onStatusChanged() { gridNotch.requestPaint() }
                                function onSourceChanged() { gridNotch.requestPaint() }
                            }

                            Canvas {
                                id: gridNotch
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                width: root.gridNotchWidth
                                height: root.gridNotchDepth
                                antialiasing: true
                                opacity: rightPane.notchOpacity
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onXChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()

                                    const heroImageReady = root.selectedSeriesKey.length > 0
                                        && heroSeriesController.currentHeroBackgroundSource().length > 0
                                        && heroBackgroundImage.status === Image.Ready

                                    ctx.beginPath()
                                    ctx.moveTo(0, 0)
                                    ctx.lineTo(width * 0.5, height)
                                    ctx.lineTo(width, 0)
                                    ctx.lineTo(width, -1)
                                    ctx.lineTo(0, -1)
                                    ctx.closePath()

                                    ctx.save()
                                    ctx.clip()
                                    ctx.fillStyle = root.bgHeroBase
                                    ctx.fillRect(0, 0, width, height)

                                    if (heroImageReady) {
                                        const drawX = heroBackgroundImage.x - x
                                        const drawY = heroBackgroundImage.y - heroBlock.height
                                        ctx.globalAlpha = Number(heroBackgroundImage.opacity || 0)
                                        ctx.drawImage(
                                            heroBackgroundImage,
                                            drawX,
                                            drawY,
                                            heroBackgroundImage.width,
                                            heroBackgroundImage.height
                                        )
                                        ctx.globalAlpha = 1.0
                                    }
                                    ctx.restore()

                                    ctx.strokeStyle = root.gridEdgeColor
                                    ctx.lineWidth = 1
                                    ctx.beginPath()
                                    ctx.moveTo(0, 0.5)
                                    ctx.lineTo(width * 0.5, height - 0.5)
                                    ctx.lineTo(width, 0.5)
                                    ctx.stroke()
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: rightPane.showInfoVisible
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: rightPane.toggleHeroPanel()
                                }
                            }

                            Image {
                                id: notchShadowOverlay
                                anchors.fill: gridNotch
                                source: uiTokens.gridNotch
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                opacity: rightPane.notchOpacity
                            }

                            Item {
                                id: showInfoPill
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                width: 76
                                height: 20
                                z: 7
                                visible: rightPane.showInfoVisible

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: root.bgApp
                                }

                                Rectangle {
                                    width: 72
                                    height: 16
                                    anchors.centerIn: parent
                                    radius: 8
                                    color: root.uiActionHoverBackground
                                    visible: showInfoHoverArea.containsMouse
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Show info"
                                    color: root.textPrimary
                                    font.family: root.uiFontFamily
                                    font.pixelSize: root.fontPxUiBase
                                    font.weight: Font.Normal
                                }

                                MouseArea {
                                    id: showInfoHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rightPane.toggleHeroPanel()
                                }
                            }
                        }
                    }

                    Item {
                        id: rightScrollLayer
                        x: parent.width - width - 8
                        y: 0
                        width: 8
                        height: parent.height
                        visible: rightPane.hasIssueOverflow
                        z: 12

                        function setScrollFromPointer(localY) {
                            const range = Math.max(0, rightPane.totalSplitScrollRange)
                            if (range <= 0) return
                            root.dismissGridOverlayMenusForScroll()
                            const knobHeight = rightScrollKnob.height
                            const trackHeight = Math.max(1, rightScrollLayer.height - knobHeight)
                            const unclamped = localY - knobHeight / 2
                            const clamped = Math.max(0, Math.min(trackHeight, unclamped))
                            const ratio = clamped / trackHeight
                            rightPane.setAbsoluteSplitScroll(ratio * range)
                        }

                        Rectangle {
                            id: rightScrollKnob
                            width: 8
                            radius: width / 2
                            color: "#000000"
                            antialiasing: true
                            height: {
                                const range = rightPane.totalSplitScrollRange
                                const ratio = range > 0 ? (rightScrollLayer.height / (rightScrollLayer.height + range)) : 1
                                return Math.max(36, Math.round(rightScrollLayer.height * Math.min(1, ratio)))
                            }
                            y: {
                                const range = Math.max(0, rightPane.totalSplitScrollRange)
                                const maxY = Math.max(0, rightScrollLayer.height - height)
                                if (range <= 0 || maxY <= 0) return 0
                                const ratio = Math.max(0, Math.min(1, rightPane.currentSplitScroll / range))
                                return Math.round(maxY * ratio)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                rightPane.stopSmoothScroll()
                                rightScrollLayer.setScrollFromPointer(mouse.y)
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) rightScrollLayer.setScrollFromPointer(mouse.y)
                            }
                        }
                    }
                }
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

    ImportProgressOverlay {
        id: importModalOverlay
        active: root.importInProgress
        blockedByModalPopup: root.anyManagedModalPopupVisible
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        currentFileName: root.importCurrentFileName
        importQueue: root.importQueue
        totalCount: root.importTotal
        processedCount: root.importProcessed
        totalBytes: root.importTotalBytes
        processedBytes: root.importProcessedBytes
        cancelInProgress: root.importCancelRequested
        onCancelRequested: importController.cancelImportBatch()
        onHidden: popupController.clearCriticalPopupAttention(importModalOverlay.dialogItem)
    }

    ImportConflictDialog {
        id: importConflictDialog
        hostWidth: root.width
        hostHeight: root.height
        titleText: importController.importConflictDialogTitle(root.importConflictContext)
        messageText: importController.importConflictDialogMessage(root.importConflictContext)
        secondaryActionText: importController.importConflictDialogSecondaryLabel(root.importConflictContext)
        primaryActionText: importController.importConflictDialogPrimaryLabel(root.importConflictContext)
        incomingLabel: root.importConflictIncomingLabel
        existingLabel: root.importConflictExistingLabel
        nextIncomingLabel: root.importConflictNextIncomingLabel
        nextExistingLabel: root.importConflictNextExistingLabel
        showBatchActions: importController.importConflictSupportsBatchActions(root.importConflictContext)
            && root.importConflictBatchDuplicateCount > 1
        progressActive: root.importConflictOperationActive
        progressCurrentFileName: root.importConflictProgressCurrentFileName
        progressTotalCount: root.importConflictProgressTotalCount
        progressProcessedCount: root.importConflictProgressProcessedCount
        progressFraction: root.importConflictProgressFraction
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        onClosed: popupController.handleImportConflictClosed()
        onSecondaryRequested: importController.resolveImportConflict(importController.importConflictSecondaryAction(root.importConflictContext))
        onPrimaryRequested: importController.resolveImportConflict(importController.importConflictPrimaryAction(root.importConflictContext))
        onSkipAllRequested: importController.resolveImportConflict("skip_all")
        onReplaceAllRequested: importController.resolveImportConflict("replace_all")
    }

    SeriesDeleteConfirmDialog {
        id: seriesDeleteConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        questionText: root.seriesDeleteQuestionText(popupStyleTokens.dialogBodyEmphasisFontSize)
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        onClosed: popupController.handleSeriesDeleteDialogClosed()
        onCancelConfirmed: popupController.cancelSeriesDeleteDialog()
        onDeleteRequested: deleteController.performSeriesDelete()
    }

    FailedImportsDialog {
        id: failedImportsDialog
        hostWidth: root.width
        hostHeight: root.height
        itemsModel: failedImportItemsModel
        actionsEnabled: !root.importInProgress
        onRetryRequested: importController.retryFailedImportAt(index)
        onSkipRequested: importController.skipFailedImportAt(index)
        onSkipAllRequested: importController.skipAllFailedImports()
        onPathOpenRequested: function(path) {
            if (!root.openFolderForPath(path)) return
        }
    }

    IssueMetadataDialog {
        id: metadataDialog
        hostWidth: root.width
        hostHeight: root.height
        dangerColor: root.dangerColor
        onSaveRequested: function(draft) {
            root.requestApplyIssueMetadataEdit(draft)
        }
        onResetRequested: root.resetMetadataEditor()
        onClosed: {
            if (issueMetadataAutofillConfirmDialog.visible) {
                issueMetadataAutofillConfirmDialog.close()
            }
            root.pendingIssueMetadataSuggestion = ({})
            popupController.handleIssueMetadataDialogClosed()
        }
    }

    ReaderPopup {
        id: readerDialog
        hostWidth: root.width
        hostHeight: root.height
        uiFontFamily: root.uiFontFamily
        issueTitle: readerSessionController.issueTitle
        imageSource: readerSessionController.imageSource
        displayPages: readerSessionController.displayPages
        errorText: readerSessionController.errorText
        loading: readerSessionController.loading
        pageIndex: readerSessionController.pageIndex
        pageCount: readerSessionController.pageCount
        fullscreenMode: readerSessionController.fullscreenMode
        readingViewMode: readerSessionController.readingViewMode
        canGoPreviousPage: readerSessionController.canGoPreviousPage
        canGoNextPage: readerSessionController.canGoNextPage
        canGoPreviousIssue: readerSessionController.canGoPreviousIssue
        canGoNextIssue: readerSessionController.canGoNextIssue
        bookmarkActive: readerSessionController.bookmarkActive
        bookmarkPageIndex: readerSessionController.bookmarkPageIndex
        favoritsActive: readerSessionController.favoriteActive
        magnifierSizePreset: appSettingsController.readerMagnifierSize
        onDismissRequested: readerSessionController.closeReader()
        onPreviousPageRequested: readerSessionController.previousReaderPage()
        onNextPageRequested: readerSessionController.nextReaderPage()
        onPreviousIssueRequested: readerSessionController.previousReaderIssue()
        onNextIssueRequested: readerSessionController.nextReaderIssue()
        onReadingViewModeChangeRequested: function(mode) { readerSessionController.setReaderViewMode(mode) }
        onBookmarkRequested: readerSessionController.toggleReaderBookmark()
        onBookmarkJumpRequested: readerSessionController.jumpToReaderBookmark()
        onFavoriteRequested: readerSessionController.toggleReaderFavorite()
        onCopyImageRequested: readerSessionController.copyCurrentReaderImage()
        onMarkAsReadRequested: readerSessionController.markCurrentReaderIssueReadAndAdvance()
        onReadFromStartRequested: readerSessionController.restartFromBeginning()
        onFullscreenToggleRequested: readerSessionController.toggleFullscreenMode()
        onPageSelected: function(pageIndex) { readerSessionController.loadReaderPage(pageIndex) }
        onClosed: readerSessionController.handlePopupClosed()
    }

    ActionResultDialog {
        id: actionResultDialog
        hostWidth: root.width
        hostHeight: root.height
        dangerColor: root.dangerColor
        message: actionResultMessage
        detailsText: popupController.actionResultDetailsText
        secondaryActionText: popupController.actionResultSecondaryText
        secondaryActionVisible: popupController.actionResultSecondaryVisible
        onClosed: popupController.handleActionResultDialogClosed()
        onSecondaryRequested: popupController.triggerActionResultSecondary()
    }

    PopupConfirmDialog {
        id: issueMetadataAutofillConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        primaryButtonText: "Fill Fields"
        secondaryButtonText: "Keep Current"
        onPrimaryRequested: root.acceptIssueMetadataSuggestion()
        onSecondaryRequested: root.skipIssueMetadataSuggestion()
    }

    PopupConfirmDialog {
        id: seriesMetadataAutofillConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        primaryButtonText: "Fill Fields"
        secondaryButtonText: "Keep Current"
        onPrimaryRequested: root.acceptSeriesMetadataSuggestion()
        onSecondaryRequested: root.skipSeriesMetadataSuggestion()
    }

    SeriesMetadataDialog {
        id: seriesMetaDialog
        hostWidth: root.width
        hostHeight: root.height
        dangerColor: root.dangerColor
        monthOptions: root.seriesMetaMonthOptions
        ageRatingOptions: root.seriesMetaAgeRatingOptions
        onSaveRequested: root.requestApplySeriesMetadataEdit()
        onCancelRequested: popupController.closeSeriesMetadataDialog()
        onClosed: {
            if (seriesMetadataAutofillConfirmDialog.visible) {
                seriesMetadataAutofillConfirmDialog.close()
            }
            root.pendingSeriesMetadataSuggestion = ({})
            popupController.handleSeriesMetadataDialogClosed()
        }
    }

    SettingsDialog {
        id: settingsDialog
        hostWidth: root.width
        hostHeight: root.height
        settingsController: appSettingsController
        sevenZipConfiguredPath: root.sevenZipConfiguredPath
        sevenZipDisplayPath: root.sevenZipEffectivePath
        sevenZipAvailable: root.cbrBackendAvailable
        sevenZipStatusMessage: root.cbrBackendMissingMessage
        libraryDataRootPath: String(libraryModel.dataRoot || "")
        libraryDataPendingMovePath: root.pendingLibraryDataRelocationPath
        libraryFolderPath: root.childPath(String(libraryModel.dataRoot || ""), "Library")
        libraryRuntimeFolderPath: root.childPath(String(libraryModel.dataRoot || ""), ".runtime")
        onChooseSevenZipRequested: root.chooseSevenZipPathFromSettings()
        onVerifySevenZipRequested: root.verifySevenZipFromSettings()
        onChangeLibraryDataLocationRequested: root.scheduleLibraryDataRelocationFromSettings()
        onChooseLibraryBackgroundImageRequested: root.chooseLibraryBackgroundImageFromSettings()
        onLibraryBackgroundImageModeRequested: root.setLibraryBackgroundImageModeFromSettings(mode)
        onOpenLibraryDataFolderRequested: root.openExactFolderPath(String(libraryModel.dataRoot || ""))
        onOpenLibraryFolderRequested: root.openExactFolderPath(root.childPath(String(libraryModel.dataRoot || ""), "Library"))
        onOpenLibraryRuntimeFolderRequested: root.openExactFolderPath(root.childPath(String(libraryModel.dataRoot || ""), ".runtime"))
        onReloadLibraryRequested: root.reloadLibraryFromSettings()
    }

    SeriesHeaderDialog {
        id: seriesHeaderDialog
        hostWidth: root.width
        hostHeight: root.height
        shuffleBackgroundEnabled: seriesHeaderController.canShuffleBackground()
        shuffleBackgroundBusy: seriesHeaderController.dialogBackgroundShuffleRequestId !== -1
        coverPreviewSource: seriesHeaderController.dialogCoverPath.length > 0
            ? seriesHeaderController.dialogCoverPath
            : heroSeriesController.automaticHeroCoverSource()
        backgroundPreviewSource: seriesHeaderController.dialogBackgroundPath.length > 0
            ? seriesHeaderController.dialogBackgroundPath
            : heroSeriesController.automaticHeroBackgroundSource()
        onUploadCoverRequested: seriesHeaderController.selectCoverImage()
        onUploadBackgroundRequested: seriesHeaderController.selectBackgroundImage()
        onShuffleBackgroundRequested: seriesHeaderController.shuffleBackground()
        onSaveRequested: seriesHeaderController.saveDialogChanges()
        onResetRequested: seriesHeaderController.resetToDefaultPending()
        onCancelRequested: seriesHeaderDialog.close()
        onOpened: startupController.launchLog("series_header_dialog_opened")
        onClosed: seriesHeaderController.resetDialogState()
    }

    ComicVineApiKeyDialog {
        id: comicVineApiKeyDialog
        hostWidth: root.width
        hostHeight: root.height
        libraryModelRef: libraryModel
    }

    Connections {
        target: libraryModel

        function onSeriesHeroReady(requestId, seriesKey, imageSource, error) {
            seriesHeaderController.handleSeriesHeroReady(requestId, seriesKey, imageSource, error)
        }

        function onComicVineApiKeyValidationFinished(requestId, result) {
            comicVineApiKeyDialog.handleValidationResult(requestId, result)
        }
    }

    DeleteConfirmDialog {
        id: deleteConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        onClosed: popupController.handleDeleteConfirmDialogClosed()
        onDeleteRequested: deleteController.performDelete()
    }

    DeleteErrorDialog {
        id: deleteErrorDialog
        hostWidth: root.width
        hostHeight: root.height
        headline: deleteErrorHeadline
        reasonText: deleteErrorReasonText
        detailsText: deleteErrorDetailsText
        systemText: deleteErrorSystemText
        primaryPath: deleteErrorPrimaryPath
        onClosed: popupController.handleDeleteErrorDialogClosed()
        onRetryRequested: deleteController.retryDeleteFailure()
        onOpenFolderRequested: {
            if (!root.openFolderForPath(deleteErrorPrimaryPath)) return
        }
    }

    Timer {
        id: gridOverlayMenuResumeTimer
        interval: root.gridOverlayMenuPostScrollDelayMs
        repeat: false
        onTriggered: root.gridOverlayMenusSuppressed = false
    }
}




