import QtQuick
import QtCore

Item {
    id: controller

    visible: false
    width: 0
    height: 0

    readonly property string defaultGeneralDefaultReadingMode: "Remember last state"
    readonly property bool defaultGeneralOpenReaderFullscreenByDefault: false
    readonly property string defaultGeneralAfterImport: "Focus imported series"
    readonly property string defaultGeneralDefaultViewAfterLaunch: "Remember last state"
    readonly property bool defaultReaderRestorePreviousWindowPosition: false
    readonly property bool defaultReaderRememberLastReaderMode: false
    readonly property string defaultReaderDefaultReadingMode: "1 page"
    readonly property string defaultReaderMagnifierSize: "Medium"
    readonly property string defaultReaderPageEdgeBehavior: "Stop at boundary"
    readonly property bool defaultReaderShowBookmarkRibbonOnGridCovers: false
    readonly property bool defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage: false
    readonly property bool defaultImportDoubleClickArchiveIntoLibrary: false
    readonly property bool defaultImportTreatImageFoldersAsIssues: false
    readonly property string defaultAppearanceLibraryBackground: "Default"
    readonly property string defaultAppearanceGridDensity: "Default"
    readonly property bool defaultAppearanceShowHeroBlock: true
    readonly property string defaultAppearanceLibraryBackgroundSolidColor: "#8A8A8A"
    readonly property string defaultAppearanceLibraryBackgroundTexture: "Dots"
    readonly property string defaultAppearanceLibraryBackgroundCustomImagePath: ""
    readonly property string defaultAppearanceLibraryBackgroundImageMode: "Fill"
    readonly property string defaultAppearanceLibraryBackgroundTileSize: "64x64px"
    readonly property bool defaultSafetyConfirmBeforeDeletingFiles: true
    readonly property bool defaultSafetyConfirmBeforeDeletingSeries: true
    readonly property bool defaultSafetyConfirmBeforeReplace: true
    readonly property string defaultSafetyMarkAsReadBehavior: "Open next issue"

    function normalizeChoice(value, allowedValues, fallbackValue) {
        const normalizedValue = String(value || "").trim()
        const source = Array.isArray(allowedValues) ? allowedValues : []
        for (let i = 0; i < source.length; i += 1) {
            const allowed = String(source[i] || "")
            if (allowed === normalizedValue) {
                return allowed
            }
        }
        return String(fallbackValue || "")
    }

    function normalizeBoolean(value, fallbackValue) {
        if (typeof value === "boolean") return value
        return Boolean(fallbackValue)
    }

    function normalizeGeneralDefaultReadingMode(value) {
        return normalizeChoice(
            value,
            ["1 page", "2 pages", "Remember last state"],
            defaultGeneralDefaultReadingMode
        )
    }

    function normalizeGeneralAfterImport(value) {
        const normalized = String(value || "").trim()
        if (normalized === "Open Last Import") {
            return "Open last import"
        }
        return normalizeChoice(
            normalized,
            ["Focus imported series", "Open last import", "Do nothing"],
            defaultGeneralAfterImport
        )
    }

    function normalizeGeneralDefaultViewAfterLaunch(value) {
        const normalized = String(value || "").trim()
        if (normalized === "Last Import") {
            return "Last import"
        }
        return normalizeChoice(
            normalized,
            ["First series in library", "Last import", "Remember last state"],
            defaultGeneralDefaultViewAfterLaunch
        )
    }

    function normalizeReaderDefaultReadingMode(value) {
        return normalizeChoice(
            value,
            ["1 page", "2 pages"],
            defaultReaderDefaultReadingMode
        )
    }

    function normalizeReaderMagnifierSize(value) {
        return normalizeChoice(
            value,
            ["Small", "Medium", "Large"],
            defaultReaderMagnifierSize
        )
    }

    function normalizeReaderPageEdgeBehavior(value) {
        return normalizeChoice(
            value,
            ["Continue", "Stop at boundary"],
            defaultReaderPageEdgeBehavior
        )
    }

    function normalizeAppearanceLibraryBackground(value) {
        return normalizeChoice(
            value,
            ["Default", "Solid", "Texture", "Custom image"],
            defaultAppearanceLibraryBackground
        )
    }

    function normalizeAppearanceGridDensity(value) {
        return normalizeChoice(
            value,
            ["Compact", "Default", "Comfortable"],
            defaultAppearanceGridDensity
        )
    }

    function normalizeAppearanceLibraryBackgroundSolidColor(value) {
        return normalizeChoice(
            value,
            [
                "#EA0600", "#F17300", "#F0D200", "#86E600", "#29DC57",
                "#18C7D8", "#1D68D9", "#4821BE", "#C7188D", "#4B392F",
                "#000000", "#1F1F1F", "#4A4A4A", "#8A8A8A", "#C3C3C3"
            ],
            defaultAppearanceLibraryBackgroundSolidColor
        )
    }

    function normalizeAppearanceLibraryBackgroundTexture(value) {
        return normalizeChoice(
            value,
            ["Dots", "Noise"],
            defaultAppearanceLibraryBackgroundTexture
        )
    }

    function normalizeAppearanceLibraryBackgroundCustomImagePath(value) {
        return String(value || "").trim()
    }

    function normalizeAppearanceLibraryBackgroundImageMode(value) {
        return normalizeChoice(
            value,
            ["Fit", "Fill", "Stretch", "Tile"],
            defaultAppearanceLibraryBackgroundImageMode
        )
    }

    function normalizeAppearanceLibraryBackgroundTileSize(value) {
        return normalizeChoice(
            value,
            ["64x64px", "256x256px", "512x512px"],
            defaultAppearanceLibraryBackgroundTileSize
        )
    }

    function normalizeSafetyMarkAsReadBehavior(value) {
        return normalizeChoice(
            value,
            ["Open next issue", "Stay on current issue", "Close reader on last issue"],
            defaultSafetyMarkAsReadBehavior
        )
    }

    function normalizedReaderViewMode(currentMode) {
        const mode = normalizeGeneralDefaultReadingMode(generalDefaultReadingMode)
        if (mode === "1 page") return "one_page"
        if (mode === "2 pages") return "two_page"
        return String(currentMode || "one_page") === "two_page" ? "two_page" : "one_page"
    }

    function shouldOpenReaderFullscreen() {
        return Boolean(generalOpenReaderFullscreenByDefault)
    }

    function settingValue(valueKey, fallbackValue) {
        const key = String(valueKey || "")
        if (key === "general_default_reading_mode") {
            return normalizeGeneralDefaultReadingMode(generalDefaultReadingMode)
        }
        if (key === "general_after_import") {
            return normalizeGeneralAfterImport(generalAfterImport)
        }
        if (key === "general_default_view_after_launch") {
            return normalizeGeneralDefaultViewAfterLaunch(generalDefaultViewAfterLaunch)
        }
        if (key === "general_open_reader_fullscreen_by_default") {
            return normalizeBoolean(generalOpenReaderFullscreenByDefault, fallbackValue)
        }
        if (key === "reader_restore_previous_window_position") {
            return normalizeBoolean(readerRestorePreviousWindowPosition, fallbackValue)
        }
        if (key === "reader_remember_last_reader_mode") {
            return normalizeBoolean(readerRememberLastReaderMode, fallbackValue)
        }
        if (key === "reader_default_reading_mode") {
            return normalizeReaderDefaultReadingMode(readerDefaultReadingMode)
        }
        if (key === "reader_magnifier_size") {
            return normalizeReaderMagnifierSize(readerMagnifierSize)
        }
        if (key === "reader_page_edge_behavior") {
            return normalizeReaderPageEdgeBehavior(readerPageEdgeBehavior)
        }
        if (key === "reader_show_bookmark_ribbon_on_grid_covers") {
            return normalizeBoolean(readerShowBookmarkRibbonOnGridCovers, fallbackValue)
        }
        if (key === "reader_auto_open_bookmarked_page_instead_of_last_page") {
            return normalizeBoolean(readerAutoOpenBookmarkedPageInsteadOfLastPage, fallbackValue)
        }
        if (key === "import_double_click_archive_into_library") {
            return normalizeBoolean(importDoubleClickArchiveIntoLibrary, fallbackValue)
        }
        if (key === "import_treat_image_folders_as_issues") {
            return normalizeBoolean(importTreatImageFoldersAsIssues, fallbackValue)
        }
        if (key === "appearance_library_background") {
            return normalizeAppearanceLibraryBackground(appearanceLibraryBackground)
        }
        if (key === "appearance_grid_density") {
            return normalizeAppearanceGridDensity(appearanceGridDensity)
        }
        if (key === "appearance_show_hero_block") {
            return normalizeBoolean(appearanceShowHeroBlock, fallbackValue)
        }
        if (key === "appearance_library_background_solid_color") {
            return normalizeAppearanceLibraryBackgroundSolidColor(appearanceLibraryBackgroundSolidColor)
        }
        if (key === "appearance_library_background_texture") {
            return normalizeAppearanceLibraryBackgroundTexture(appearanceLibraryBackgroundTexture)
        }
        if (key === "appearance_library_background_custom_image_path") {
            return normalizeAppearanceLibraryBackgroundCustomImagePath(appearanceLibraryBackgroundCustomImagePath)
        }
        if (key === "appearance_library_background_image_mode") {
            return normalizeAppearanceLibraryBackgroundImageMode(appearanceLibraryBackgroundImageMode)
        }
        if (key === "appearance_library_background_tile_size") {
            return normalizeAppearanceLibraryBackgroundTileSize(appearanceLibraryBackgroundTileSize)
        }
        if (key === "safety_confirm_before_deleting_files") {
            return normalizeBoolean(safetyConfirmBeforeDeletingFiles, fallbackValue)
        }
        if (key === "safety_confirm_before_deleting_series") {
            return normalizeBoolean(safetyConfirmBeforeDeletingSeries, fallbackValue)
        }
        if (key === "safety_confirm_before_replace") {
            return normalizeBoolean(safetyConfirmBeforeReplace, fallbackValue)
        }
        if (key === "safety_mark_as_read_behavior") {
            return normalizeSafetyMarkAsReadBehavior(safetyMarkAsReadBehavior)
        }
        return fallbackValue
    }

    function setSettingValue(valueKey, nextValue) {
        const key = String(valueKey || "")
        if (key === "general_default_reading_mode") {
            generalDefaultReadingMode = normalizeGeneralDefaultReadingMode(nextValue)
            return
        }
        if (key === "general_after_import") {
            generalAfterImport = normalizeGeneralAfterImport(nextValue)
            return
        }
        if (key === "general_default_view_after_launch") {
            generalDefaultViewAfterLaunch = normalizeGeneralDefaultViewAfterLaunch(nextValue)
            return
        }
        if (key === "general_open_reader_fullscreen_by_default") {
            generalOpenReaderFullscreenByDefault = normalizeBoolean(nextValue, defaultGeneralOpenReaderFullscreenByDefault)
            return
        }
        if (key === "reader_restore_previous_window_position") {
            readerRestorePreviousWindowPosition = normalizeBoolean(nextValue, defaultReaderRestorePreviousWindowPosition)
            return
        }
        if (key === "reader_remember_last_reader_mode") {
            readerRememberLastReaderMode = normalizeBoolean(nextValue, defaultReaderRememberLastReaderMode)
            return
        }
        if (key === "reader_default_reading_mode") {
            readerDefaultReadingMode = normalizeReaderDefaultReadingMode(nextValue)
            return
        }
        if (key === "reader_magnifier_size") {
            readerMagnifierSize = normalizeReaderMagnifierSize(nextValue)
            return
        }
        if (key === "reader_page_edge_behavior") {
            readerPageEdgeBehavior = normalizeReaderPageEdgeBehavior(nextValue)
            return
        }
        if (key === "reader_show_bookmark_ribbon_on_grid_covers") {
            readerShowBookmarkRibbonOnGridCovers = normalizeBoolean(nextValue, defaultReaderShowBookmarkRibbonOnGridCovers)
            return
        }
        if (key === "reader_auto_open_bookmarked_page_instead_of_last_page") {
            readerAutoOpenBookmarkedPageInsteadOfLastPage = normalizeBoolean(
                nextValue,
                defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
            )
            return
        }
        if (key === "import_double_click_archive_into_library") {
            importDoubleClickArchiveIntoLibrary = normalizeBoolean(
                nextValue,
                defaultImportDoubleClickArchiveIntoLibrary
            )
            return
        }
        if (key === "import_treat_image_folders_as_issues") {
            importTreatImageFoldersAsIssues = normalizeBoolean(
                nextValue,
                defaultImportTreatImageFoldersAsIssues
            )
            return
        }
        if (key === "appearance_library_background") {
            appearanceLibraryBackground = normalizeAppearanceLibraryBackground(nextValue)
            return
        }
        if (key === "appearance_grid_density") {
            appearanceGridDensity = normalizeAppearanceGridDensity(nextValue)
            return
        }
        if (key === "appearance_show_hero_block") {
            appearanceShowHeroBlock = normalizeBoolean(nextValue, defaultAppearanceShowHeroBlock)
            return
        }
        if (key === "appearance_library_background_solid_color") {
            appearanceLibraryBackgroundSolidColor = normalizeAppearanceLibraryBackgroundSolidColor(nextValue)
            return
        }
        if (key === "appearance_library_background_texture") {
            appearanceLibraryBackgroundTexture = normalizeAppearanceLibraryBackgroundTexture(nextValue)
            return
        }
        if (key === "appearance_library_background_custom_image_path") {
            appearanceLibraryBackgroundCustomImagePath = normalizeAppearanceLibraryBackgroundCustomImagePath(nextValue)
            return
        }
        if (key === "appearance_library_background_image_mode") {
            appearanceLibraryBackgroundImageMode = normalizeAppearanceLibraryBackgroundImageMode(nextValue)
            return
        }
        if (key === "appearance_library_background_tile_size") {
            appearanceLibraryBackgroundTileSize = normalizeAppearanceLibraryBackgroundTileSize(nextValue)
            return
        }
        if (key === "safety_confirm_before_deleting_files") {
            safetyConfirmBeforeDeletingFiles = normalizeBoolean(
                nextValue,
                defaultSafetyConfirmBeforeDeletingFiles
            )
            return
        }
        if (key === "safety_confirm_before_deleting_series") {
            safetyConfirmBeforeDeletingSeries = normalizeBoolean(
                nextValue,
                defaultSafetyConfirmBeforeDeletingSeries
            )
            return
        }
        if (key === "safety_confirm_before_replace") {
            safetyConfirmBeforeReplace = normalizeBoolean(
                nextValue,
                defaultSafetyConfirmBeforeReplace
            )
            return
        }
        if (key === "safety_mark_as_read_behavior") {
            safetyMarkAsReadBehavior = normalizeSafetyMarkAsReadBehavior(nextValue)
        }
    }

    Settings {
        id: settingsStore
        category: "AppSettings"
        property string generalDefaultReadingMode: controller.defaultGeneralDefaultReadingMode
        property bool generalOpenReaderFullscreenByDefault: controller.defaultGeneralOpenReaderFullscreenByDefault
        property string generalAfterImport: controller.defaultGeneralAfterImport
        property string generalDefaultViewAfterLaunch: controller.defaultGeneralDefaultViewAfterLaunch
        property bool readerRestorePreviousWindowPosition: controller.defaultReaderRestorePreviousWindowPosition
        property bool readerRememberLastReaderMode: controller.defaultReaderRememberLastReaderMode
        property string readerDefaultReadingMode: controller.defaultReaderDefaultReadingMode
        property string readerMagnifierSize: controller.defaultReaderMagnifierSize
        property string readerPageEdgeBehavior: controller.defaultReaderPageEdgeBehavior
        property bool readerShowBookmarkRibbonOnGridCovers: controller.defaultReaderShowBookmarkRibbonOnGridCovers
        property bool readerAutoOpenBookmarkedPageInsteadOfLastPage: controller.defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
        property bool importDoubleClickArchiveIntoLibrary: controller.defaultImportDoubleClickArchiveIntoLibrary
        property bool importTreatImageFoldersAsIssues: controller.defaultImportTreatImageFoldersAsIssues
        property string appearanceLibraryBackground: controller.defaultAppearanceLibraryBackground
        property string appearanceGridDensity: controller.defaultAppearanceGridDensity
        property bool appearanceShowHeroBlock: controller.defaultAppearanceShowHeroBlock
        property string appearanceLibraryBackgroundSolidColor: controller.defaultAppearanceLibraryBackgroundSolidColor
        property string appearanceLibraryBackgroundTexture: controller.defaultAppearanceLibraryBackgroundTexture
        property string appearanceLibraryBackgroundCustomImagePath: controller.defaultAppearanceLibraryBackgroundCustomImagePath
        property string appearanceLibraryBackgroundImageMode: controller.defaultAppearanceLibraryBackgroundImageMode
        property string appearanceLibraryBackgroundTileSize: controller.defaultAppearanceLibraryBackgroundTileSize
        property bool safetyConfirmBeforeDeletingFiles: controller.defaultSafetyConfirmBeforeDeletingFiles
        property bool safetyConfirmBeforeDeletingSeries: controller.defaultSafetyConfirmBeforeDeletingSeries
        property bool safetyConfirmBeforeReplace: controller.defaultSafetyConfirmBeforeReplace
        property string safetyMarkAsReadBehavior: controller.defaultSafetyMarkAsReadBehavior
    }

    property string generalDefaultReadingMode: normalizeGeneralDefaultReadingMode(settingsStore.generalDefaultReadingMode)
    property bool generalOpenReaderFullscreenByDefault: normalizeBoolean(
        settingsStore.generalOpenReaderFullscreenByDefault,
        defaultGeneralOpenReaderFullscreenByDefault
    )
    property string generalAfterImport: normalizeGeneralAfterImport(settingsStore.generalAfterImport)
    property string generalDefaultViewAfterLaunch: normalizeGeneralDefaultViewAfterLaunch(
        settingsStore.generalDefaultViewAfterLaunch
    )
    property bool readerRestorePreviousWindowPosition: normalizeBoolean(
        settingsStore.readerRestorePreviousWindowPosition,
        defaultReaderRestorePreviousWindowPosition
    )
    property bool readerRememberLastReaderMode: normalizeBoolean(
        settingsStore.readerRememberLastReaderMode,
        defaultReaderRememberLastReaderMode
    )
    property string readerDefaultReadingMode: normalizeReaderDefaultReadingMode(
        settingsStore.readerDefaultReadingMode
    )
    property string readerMagnifierSize: normalizeReaderMagnifierSize(
        settingsStore.readerMagnifierSize
    )
    property string readerPageEdgeBehavior: normalizeReaderPageEdgeBehavior(
        settingsStore.readerPageEdgeBehavior
    )
    property bool readerShowBookmarkRibbonOnGridCovers: normalizeBoolean(
        settingsStore.readerShowBookmarkRibbonOnGridCovers,
        defaultReaderShowBookmarkRibbonOnGridCovers
    )
    property bool readerAutoOpenBookmarkedPageInsteadOfLastPage: normalizeBoolean(
        settingsStore.readerAutoOpenBookmarkedPageInsteadOfLastPage,
        defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
    )
    property bool importDoubleClickArchiveIntoLibrary: normalizeBoolean(
        settingsStore.importDoubleClickArchiveIntoLibrary,
        defaultImportDoubleClickArchiveIntoLibrary
    )
    property bool importTreatImageFoldersAsIssues: normalizeBoolean(
        settingsStore.importTreatImageFoldersAsIssues,
        defaultImportTreatImageFoldersAsIssues
    )
    property string appearanceLibraryBackground: normalizeAppearanceLibraryBackground(
        settingsStore.appearanceLibraryBackground
    )
    property string appearanceGridDensity: normalizeAppearanceGridDensity(
        settingsStore.appearanceGridDensity
    )
    property bool appearanceShowHeroBlock: normalizeBoolean(
        settingsStore.appearanceShowHeroBlock,
        defaultAppearanceShowHeroBlock
    )
    property string appearanceLibraryBackgroundSolidColor: normalizeAppearanceLibraryBackgroundSolidColor(
        settingsStore.appearanceLibraryBackgroundSolidColor
    )
    property string appearanceLibraryBackgroundTexture: normalizeAppearanceLibraryBackgroundTexture(
        settingsStore.appearanceLibraryBackgroundTexture
    )
    property string appearanceLibraryBackgroundCustomImagePath: normalizeAppearanceLibraryBackgroundCustomImagePath(
        settingsStore.appearanceLibraryBackgroundCustomImagePath
    )
    property string appearanceLibraryBackgroundImageMode: normalizeAppearanceLibraryBackgroundImageMode(
        settingsStore.appearanceLibraryBackgroundImageMode
    )
    property string appearanceLibraryBackgroundTileSize: normalizeAppearanceLibraryBackgroundTileSize(
        settingsStore.appearanceLibraryBackgroundTileSize
    )
    property bool safetyConfirmBeforeDeletingFiles: normalizeBoolean(
        settingsStore.safetyConfirmBeforeDeletingFiles,
        defaultSafetyConfirmBeforeDeletingFiles
    )
    property bool safetyConfirmBeforeDeletingSeries: normalizeBoolean(
        settingsStore.safetyConfirmBeforeDeletingSeries,
        defaultSafetyConfirmBeforeDeletingSeries
    )
    property bool safetyConfirmBeforeReplace: normalizeBoolean(
        settingsStore.safetyConfirmBeforeReplace,
        defaultSafetyConfirmBeforeReplace
    )
    property string safetyMarkAsReadBehavior: normalizeSafetyMarkAsReadBehavior(
        settingsStore.safetyMarkAsReadBehavior
    )

    onGeneralDefaultReadingModeChanged: {
        const normalized = normalizeGeneralDefaultReadingMode(generalDefaultReadingMode)
        if (generalDefaultReadingMode !== normalized) {
            generalDefaultReadingMode = normalized
            return
        }
        if (settingsStore.generalDefaultReadingMode !== normalized) {
            settingsStore.generalDefaultReadingMode = normalized
        }
    }

    onGeneralOpenReaderFullscreenByDefaultChanged: {
        const normalized = normalizeBoolean(
            generalOpenReaderFullscreenByDefault,
            defaultGeneralOpenReaderFullscreenByDefault
        )
        if (generalOpenReaderFullscreenByDefault !== normalized) {
            generalOpenReaderFullscreenByDefault = normalized
            return
        }
        if (settingsStore.generalOpenReaderFullscreenByDefault !== normalized) {
            settingsStore.generalOpenReaderFullscreenByDefault = normalized
        }
    }

    onGeneralAfterImportChanged: {
        const normalized = normalizeGeneralAfterImport(generalAfterImport)
        if (generalAfterImport !== normalized) {
            generalAfterImport = normalized
            return
        }
        if (settingsStore.generalAfterImport !== normalized) {
            settingsStore.generalAfterImport = normalized
        }
    }

    onGeneralDefaultViewAfterLaunchChanged: {
        const normalized = normalizeGeneralDefaultViewAfterLaunch(generalDefaultViewAfterLaunch)
        if (generalDefaultViewAfterLaunch !== normalized) {
            generalDefaultViewAfterLaunch = normalized
            return
        }
        if (settingsStore.generalDefaultViewAfterLaunch !== normalized) {
            settingsStore.generalDefaultViewAfterLaunch = normalized
        }
    }

    onReaderRestorePreviousWindowPositionChanged: {
        const normalized = normalizeBoolean(
            readerRestorePreviousWindowPosition,
            defaultReaderRestorePreviousWindowPosition
        )
        if (readerRestorePreviousWindowPosition !== normalized) {
            readerRestorePreviousWindowPosition = normalized
            return
        }
        if (settingsStore.readerRestorePreviousWindowPosition !== normalized) {
            settingsStore.readerRestorePreviousWindowPosition = normalized
        }
    }

    onReaderRememberLastReaderModeChanged: {
        const normalized = normalizeBoolean(
            readerRememberLastReaderMode,
            defaultReaderRememberLastReaderMode
        )
        if (readerRememberLastReaderMode !== normalized) {
            readerRememberLastReaderMode = normalized
            return
        }
        if (settingsStore.readerRememberLastReaderMode !== normalized) {
            settingsStore.readerRememberLastReaderMode = normalized
        }
    }

    onReaderDefaultReadingModeChanged: {
        const normalized = normalizeReaderDefaultReadingMode(readerDefaultReadingMode)
        if (readerDefaultReadingMode !== normalized) {
            readerDefaultReadingMode = normalized
            return
        }
        if (settingsStore.readerDefaultReadingMode !== normalized) {
            settingsStore.readerDefaultReadingMode = normalized
        }
    }

    onReaderMagnifierSizeChanged: {
        const normalized = normalizeReaderMagnifierSize(readerMagnifierSize)
        if (readerMagnifierSize !== normalized) {
            readerMagnifierSize = normalized
            return
        }
        if (settingsStore.readerMagnifierSize !== normalized) {
            settingsStore.readerMagnifierSize = normalized
        }
    }

    onReaderPageEdgeBehaviorChanged: {
        const normalized = normalizeReaderPageEdgeBehavior(readerPageEdgeBehavior)
        if (readerPageEdgeBehavior !== normalized) {
            readerPageEdgeBehavior = normalized
            return
        }
        if (settingsStore.readerPageEdgeBehavior !== normalized) {
            settingsStore.readerPageEdgeBehavior = normalized
        }
    }

    onReaderShowBookmarkRibbonOnGridCoversChanged: {
        const normalized = normalizeBoolean(
            readerShowBookmarkRibbonOnGridCovers,
            defaultReaderShowBookmarkRibbonOnGridCovers
        )
        if (readerShowBookmarkRibbonOnGridCovers !== normalized) {
            readerShowBookmarkRibbonOnGridCovers = normalized
            return
        }
        if (settingsStore.readerShowBookmarkRibbonOnGridCovers !== normalized) {
            settingsStore.readerShowBookmarkRibbonOnGridCovers = normalized
        }
    }

    onReaderAutoOpenBookmarkedPageInsteadOfLastPageChanged: {
        const normalized = normalizeBoolean(
            readerAutoOpenBookmarkedPageInsteadOfLastPage,
            defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
        )
        if (readerAutoOpenBookmarkedPageInsteadOfLastPage !== normalized) {
            readerAutoOpenBookmarkedPageInsteadOfLastPage = normalized
            return
        }
        if (settingsStore.readerAutoOpenBookmarkedPageInsteadOfLastPage !== normalized) {
            settingsStore.readerAutoOpenBookmarkedPageInsteadOfLastPage = normalized
        }
    }

    onImportDoubleClickArchiveIntoLibraryChanged: {
        const normalized = normalizeBoolean(
            importDoubleClickArchiveIntoLibrary,
            defaultImportDoubleClickArchiveIntoLibrary
        )
        if (importDoubleClickArchiveIntoLibrary !== normalized) {
            importDoubleClickArchiveIntoLibrary = normalized
            return
        }
        if (settingsStore.importDoubleClickArchiveIntoLibrary !== normalized) {
            settingsStore.importDoubleClickArchiveIntoLibrary = normalized
        }
    }

    onImportTreatImageFoldersAsIssuesChanged: {
        const normalized = normalizeBoolean(
            importTreatImageFoldersAsIssues,
            defaultImportTreatImageFoldersAsIssues
        )
        if (importTreatImageFoldersAsIssues !== normalized) {
            importTreatImageFoldersAsIssues = normalized
            return
        }
        if (settingsStore.importTreatImageFoldersAsIssues !== normalized) {
            settingsStore.importTreatImageFoldersAsIssues = normalized
        }
    }

    onAppearanceLibraryBackgroundChanged: {
        const normalized = normalizeAppearanceLibraryBackground(appearanceLibraryBackground)
        if (appearanceLibraryBackground !== normalized) {
            appearanceLibraryBackground = normalized
            return
        }
        if (settingsStore.appearanceLibraryBackground !== normalized) {
            settingsStore.appearanceLibraryBackground = normalized
        }
    }

    onAppearanceGridDensityChanged: {
        const normalized = normalizeAppearanceGridDensity(appearanceGridDensity)
        if (appearanceGridDensity !== normalized) {
            appearanceGridDensity = normalized
            return
        }
        if (settingsStore.appearanceGridDensity !== normalized) {
            settingsStore.appearanceGridDensity = normalized
        }
    }

    onAppearanceShowHeroBlockChanged: {
        const normalized = normalizeBoolean(
            appearanceShowHeroBlock,
            defaultAppearanceShowHeroBlock
        )
        if (appearanceShowHeroBlock !== normalized) {
            appearanceShowHeroBlock = normalized
            return
        }
        if (settingsStore.appearanceShowHeroBlock !== normalized) {
            settingsStore.appearanceShowHeroBlock = normalized
        }
    }

    onAppearanceLibraryBackgroundSolidColorChanged: {
        const normalized = normalizeAppearanceLibraryBackgroundSolidColor(appearanceLibraryBackgroundSolidColor)
        if (appearanceLibraryBackgroundSolidColor !== normalized) {
            appearanceLibraryBackgroundSolidColor = normalized
            return
        }
        if (settingsStore.appearanceLibraryBackgroundSolidColor !== normalized) {
            settingsStore.appearanceLibraryBackgroundSolidColor = normalized
        }
    }

    onAppearanceLibraryBackgroundTextureChanged: {
        const normalized = normalizeAppearanceLibraryBackgroundTexture(appearanceLibraryBackgroundTexture)
        if (appearanceLibraryBackgroundTexture !== normalized) {
            appearanceLibraryBackgroundTexture = normalized
            return
        }
        if (settingsStore.appearanceLibraryBackgroundTexture !== normalized) {
            settingsStore.appearanceLibraryBackgroundTexture = normalized
        }
    }

    onAppearanceLibraryBackgroundCustomImagePathChanged: {
        const normalized = normalizeAppearanceLibraryBackgroundCustomImagePath(
            appearanceLibraryBackgroundCustomImagePath
        )
        if (appearanceLibraryBackgroundCustomImagePath !== normalized) {
            appearanceLibraryBackgroundCustomImagePath = normalized
            return
        }
        if (settingsStore.appearanceLibraryBackgroundCustomImagePath !== normalized) {
            settingsStore.appearanceLibraryBackgroundCustomImagePath = normalized
        }
    }

    onAppearanceLibraryBackgroundImageModeChanged: {
        const normalized = normalizeAppearanceLibraryBackgroundImageMode(appearanceLibraryBackgroundImageMode)
        if (appearanceLibraryBackgroundImageMode !== normalized) {
            appearanceLibraryBackgroundImageMode = normalized
            return
        }
        if (settingsStore.appearanceLibraryBackgroundImageMode !== normalized) {
            settingsStore.appearanceLibraryBackgroundImageMode = normalized
        }
    }

    onAppearanceLibraryBackgroundTileSizeChanged: {
        const normalized = normalizeAppearanceLibraryBackgroundTileSize(appearanceLibraryBackgroundTileSize)
        if (appearanceLibraryBackgroundTileSize !== normalized) {
            appearanceLibraryBackgroundTileSize = normalized
            return
        }
        if (settingsStore.appearanceLibraryBackgroundTileSize !== normalized) {
            settingsStore.appearanceLibraryBackgroundTileSize = normalized
        }
    }

    onSafetyConfirmBeforeDeletingFilesChanged: {
        const normalized = normalizeBoolean(
            safetyConfirmBeforeDeletingFiles,
            defaultSafetyConfirmBeforeDeletingFiles
        )
        if (safetyConfirmBeforeDeletingFiles !== normalized) {
            safetyConfirmBeforeDeletingFiles = normalized
            return
        }
        if (settingsStore.safetyConfirmBeforeDeletingFiles !== normalized) {
            settingsStore.safetyConfirmBeforeDeletingFiles = normalized
        }
    }

    onSafetyConfirmBeforeDeletingSeriesChanged: {
        const normalized = normalizeBoolean(
            safetyConfirmBeforeDeletingSeries,
            defaultSafetyConfirmBeforeDeletingSeries
        )
        if (safetyConfirmBeforeDeletingSeries !== normalized) {
            safetyConfirmBeforeDeletingSeries = normalized
            return
        }
        if (settingsStore.safetyConfirmBeforeDeletingSeries !== normalized) {
            settingsStore.safetyConfirmBeforeDeletingSeries = normalized
        }
    }

    onSafetyConfirmBeforeReplaceChanged: {
        const normalized = normalizeBoolean(
            safetyConfirmBeforeReplace,
            defaultSafetyConfirmBeforeReplace
        )
        if (safetyConfirmBeforeReplace !== normalized) {
            safetyConfirmBeforeReplace = normalized
            return
        }
        if (settingsStore.safetyConfirmBeforeReplace !== normalized) {
            settingsStore.safetyConfirmBeforeReplace = normalized
        }
    }

    onSafetyMarkAsReadBehaviorChanged: {
        const normalized = normalizeSafetyMarkAsReadBehavior(safetyMarkAsReadBehavior)
        if (safetyMarkAsReadBehavior !== normalized) {
            safetyMarkAsReadBehavior = normalized
            return
        }
        if (settingsStore.safetyMarkAsReadBehavior !== normalized) {
            settingsStore.safetyMarkAsReadBehavior = normalized
        }
    }
}
