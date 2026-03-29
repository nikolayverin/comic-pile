import QtQuick
import QtCore
import "../components/SettingsCatalog.js" as SettingsCatalog

Item {
    id: controller

    visible: false
    width: 0
    height: 0

    readonly property string defaultGeneralDefaultReadingMode: SettingsCatalog.defaultGeneralDefaultReadingMode
    readonly property bool defaultGeneralOpenReaderFullscreenByDefault: SettingsCatalog.defaultGeneralOpenReaderFullscreenByDefault
    readonly property string defaultGeneralAfterImport: SettingsCatalog.defaultGeneralAfterImport
    readonly property string defaultGeneralDefaultViewAfterLaunch: SettingsCatalog.defaultGeneralDefaultViewAfterLaunch
    readonly property bool defaultReaderRememberLastReaderMode: SettingsCatalog.defaultReaderRememberLastReaderMode
    readonly property string defaultReaderDefaultReadingMode: SettingsCatalog.defaultReaderDefaultReadingMode
    readonly property string defaultReaderMagnifierSize: SettingsCatalog.defaultReaderMagnifierSize
    readonly property string defaultReaderPageEdgeBehavior: SettingsCatalog.defaultReaderPageEdgeBehavior
    readonly property bool defaultReaderShowBookmarkRibbonOnGridCovers: SettingsCatalog.defaultReaderShowBookmarkRibbonOnGridCovers
    readonly property bool defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage: SettingsCatalog.defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
    readonly property bool defaultReaderShowActionNotifications: SettingsCatalog.defaultReaderShowActionNotifications
    readonly property bool defaultImportDoubleClickArchiveIntoLibrary: SettingsCatalog.defaultImportDoubleClickArchiveIntoLibrary
    readonly property bool defaultImportTreatImageFoldersAsIssues: SettingsCatalog.defaultImportTreatImageFoldersAsIssues
    readonly property string defaultAppearanceLibraryBackground: SettingsCatalog.defaultAppearanceLibraryBackground
    readonly property string defaultAppearanceGridDensity: SettingsCatalog.defaultAppearanceGridDensity
    readonly property bool defaultAppearanceShowHeroBlock: SettingsCatalog.defaultAppearanceShowHeroBlock
    readonly property string defaultAppearanceLibraryBackgroundSolidColor: SettingsCatalog.defaultAppearanceLibraryBackgroundSolidColor
    readonly property string defaultAppearanceLibraryBackgroundTexture: SettingsCatalog.defaultAppearanceLibraryBackgroundTexture
    readonly property string defaultAppearanceLibraryBackgroundCustomImagePath: SettingsCatalog.defaultAppearanceLibraryBackgroundCustomImagePath
    readonly property string defaultAppearanceLibraryBackgroundImageMode: SettingsCatalog.defaultAppearanceLibraryBackgroundImageMode
    readonly property string defaultAppearanceLibraryBackgroundTileSize: SettingsCatalog.defaultAppearanceLibraryBackgroundTileSize
    readonly property bool defaultSafetyConfirmBeforeDeletingFiles: SettingsCatalog.defaultSafetyConfirmBeforeDeletingFiles
    readonly property bool defaultSafetyConfirmBeforeDeletingSeries: SettingsCatalog.defaultSafetyConfirmBeforeDeletingSeries
    readonly property bool defaultSafetyConfirmBeforeReplace: SettingsCatalog.defaultSafetyConfirmBeforeReplace
    readonly property bool defaultSafetyConfirmBeforeDeletingPage: SettingsCatalog.defaultSafetyConfirmBeforeDeletingPage
    readonly property var appearanceSettingDescriptors: SettingsCatalog.appearanceSettingDescriptors

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

    function settingDescriptor(descriptors, valueKey) {
        const normalizedKey = String(valueKey || "")
        const source = Array.isArray(descriptors) ? descriptors : []
        for (let i = 0; i < source.length; i += 1) {
            const descriptor = source[i] || {}
            if (String(descriptor.valueKey || "") === normalizedKey) {
                return descriptor
            }
        }
        return null
    }

    function normalizeConfiguredSetting(descriptor, value, fallbackValue) {
        const entry = descriptor || ({})
        const defaultValue = entry.hasOwnProperty("defaultValue")
            ? entry.defaultValue
            : fallbackValue
        const normalization = String(entry.normalization || "").trim()
        if (normalization === "boolean") {
            return normalizeBoolean(value, defaultValue)
        }
        if (normalization === "trimmed_string") {
            return String(value || "").trim()
        }
        return normalizeChoice(value, entry.options || [], defaultValue)
    }

    function appearanceSettingDescriptor(valueKey) {
        return settingDescriptor(appearanceSettingDescriptors, valueKey)
    }

    function normalizeAppearanceSettingValue(valueKey, value, fallbackValue) {
        const descriptor = appearanceSettingDescriptor(valueKey)
        if (!descriptor) {
            return fallbackValue
        }
        return normalizeConfiguredSetting(descriptor, value, fallbackValue)
    }

    function syncAppearanceSetting(valueKey) {
        const descriptor = appearanceSettingDescriptor(valueKey)
        if (!descriptor) return

        const propertyName = String(descriptor.controllerProperty || "").trim()
        const storePropertyName = String(descriptor.storeProperty || "").trim()
        if (propertyName.length < 1 || storePropertyName.length < 1) return

        const currentValue = controller[propertyName]
        const normalized = normalizeConfiguredSetting(descriptor, currentValue, descriptor.defaultValue)
        if (currentValue !== normalized) {
            controller[propertyName] = normalized
            return
        }
        if (settingsStore[storePropertyName] !== normalized) {
            settingsStore[storePropertyName] = normalized
        }
    }

    function normalizeGeneralDefaultReadingMode(value) {
        return normalizeChoice(
            value,
            SettingsCatalog.generalDefaultReadingModeOptions,
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
            SettingsCatalog.generalAfterImportOptions,
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
            SettingsCatalog.generalDefaultViewAfterLaunchOptions,
            defaultGeneralDefaultViewAfterLaunch
        )
    }

    function normalizeReaderDefaultReadingMode(value) {
        return normalizeChoice(
            value,
            SettingsCatalog.readerDefaultReadingModeOptions,
            defaultReaderDefaultReadingMode
        )
    }

    function normalizeReaderMagnifierSize(value) {
        return normalizeChoice(
            value,
            SettingsCatalog.readerMagnifierSizeOptions,
            defaultReaderMagnifierSize
        )
    }

    function normalizeReaderPageEdgeBehavior(value) {
        return normalizeChoice(
            value,
            SettingsCatalog.readerPageEdgeBehaviorOptions,
            defaultReaderPageEdgeBehavior
        )
    }

    function normalizedReaderViewMode(currentMode) {
        if (Boolean(readerRememberLastReaderMode)) {
            return String(currentMode || "one_page") === "two_page" ? "two_page" : "one_page"
        }
        const mode = normalizeReaderDefaultReadingMode(readerDefaultReadingMode)
        return mode === "2 pages" ? "two_page" : "one_page"
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
        if (key === "reader_show_action_notifications") {
            return normalizeBoolean(readerShowActionNotifications, fallbackValue)
        }
        if (key === "import_double_click_archive_into_library") {
            return normalizeBoolean(importDoubleClickArchiveIntoLibrary, fallbackValue)
        }
        if (key === "import_treat_image_folders_as_issues") {
            return normalizeBoolean(importTreatImageFoldersAsIssues, fallbackValue)
        }
        const appearanceDescriptor = appearanceSettingDescriptor(key)
        if (appearanceDescriptor) {
            return normalizeConfiguredSetting(
                appearanceDescriptor,
                controller[String(appearanceDescriptor.controllerProperty || "").trim()],
                fallbackValue
            )
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
        if (key === "safety_confirm_before_deleting_page") {
            return normalizeBoolean(safetyConfirmBeforeDeletingPage, fallbackValue)
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
        if (key === "reader_show_action_notifications") {
            readerShowActionNotifications = normalizeBoolean(
                nextValue,
                defaultReaderShowActionNotifications
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
        const appearanceDescriptor = appearanceSettingDescriptor(key)
        if (appearanceDescriptor) {
            const propertyName = String(appearanceDescriptor.controllerProperty || "").trim()
            if (propertyName.length > 0) {
                controller[propertyName] = normalizeConfiguredSetting(
                    appearanceDescriptor,
                    nextValue,
                    appearanceDescriptor.defaultValue
                )
            }
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
        if (key === "safety_confirm_before_deleting_page") {
            safetyConfirmBeforeDeletingPage = normalizeBoolean(
                nextValue,
                defaultSafetyConfirmBeforeDeletingPage
            )
        }
    }

    function applySettingsSnapshot(snapshot) {
        const values = snapshot || ({})
        const keys = Object.keys(values)
        for (let i = 0; i < keys.length; i += 1) {
            const key = String(keys[i] || "")
            setSettingValue(key, values[key])
        }
    }

    function resetAllSettingsToDefaults() {
        applySettingsSnapshot(SettingsCatalog.defaultSettingsSnapshot())
    }

    Settings {
        id: settingsStore
        category: "AppSettings"
        property string generalDefaultReadingMode: controller.defaultGeneralDefaultReadingMode
        property bool generalOpenReaderFullscreenByDefault: controller.defaultGeneralOpenReaderFullscreenByDefault
        property string generalAfterImport: controller.defaultGeneralAfterImport
        property string generalDefaultViewAfterLaunch: controller.defaultGeneralDefaultViewAfterLaunch
        property bool readerRememberLastReaderMode: controller.defaultReaderRememberLastReaderMode
        property string readerDefaultReadingMode: controller.defaultReaderDefaultReadingMode
        property string readerMagnifierSize: controller.defaultReaderMagnifierSize
        property string readerPageEdgeBehavior: controller.defaultReaderPageEdgeBehavior
        property bool readerShowBookmarkRibbonOnGridCovers: controller.defaultReaderShowBookmarkRibbonOnGridCovers
        property bool readerAutoOpenBookmarkedPageInsteadOfLastPage: controller.defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
        property bool readerShowActionNotifications: controller.defaultReaderShowActionNotifications
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
        property bool safetyConfirmBeforeDeletingPage: controller.defaultSafetyConfirmBeforeDeletingPage
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
    property bool readerShowActionNotifications: normalizeBoolean(
        settingsStore.readerShowActionNotifications,
        defaultReaderShowActionNotifications
    )
    property bool importDoubleClickArchiveIntoLibrary: normalizeBoolean(
        settingsStore.importDoubleClickArchiveIntoLibrary,
        defaultImportDoubleClickArchiveIntoLibrary
    )
    property bool importTreatImageFoldersAsIssues: normalizeBoolean(
        settingsStore.importTreatImageFoldersAsIssues,
        defaultImportTreatImageFoldersAsIssues
    )
    property string appearanceLibraryBackground: normalizeAppearanceSettingValue(
        "appearance_library_background",
        settingsStore.appearanceLibraryBackground,
        defaultAppearanceLibraryBackground
    )
    property string appearanceGridDensity: normalizeAppearanceSettingValue(
        "appearance_grid_density",
        settingsStore.appearanceGridDensity,
        defaultAppearanceGridDensity
    )
    property bool appearanceShowHeroBlock: normalizeAppearanceSettingValue(
        "appearance_show_hero_block",
        settingsStore.appearanceShowHeroBlock,
        defaultAppearanceShowHeroBlock
    )
    property string appearanceLibraryBackgroundSolidColor: normalizeAppearanceSettingValue(
        "appearance_library_background_solid_color",
        settingsStore.appearanceLibraryBackgroundSolidColor,
        defaultAppearanceLibraryBackgroundSolidColor
    )
    property string appearanceLibraryBackgroundTexture: normalizeAppearanceSettingValue(
        "appearance_library_background_texture",
        settingsStore.appearanceLibraryBackgroundTexture,
        defaultAppearanceLibraryBackgroundTexture
    )
    property string appearanceLibraryBackgroundCustomImagePath: normalizeAppearanceSettingValue(
        "appearance_library_background_custom_image_path",
        settingsStore.appearanceLibraryBackgroundCustomImagePath,
        defaultAppearanceLibraryBackgroundCustomImagePath
    )
    property string appearanceLibraryBackgroundImageMode: normalizeAppearanceSettingValue(
        "appearance_library_background_image_mode",
        settingsStore.appearanceLibraryBackgroundImageMode,
        defaultAppearanceLibraryBackgroundImageMode
    )
    property string appearanceLibraryBackgroundTileSize: normalizeAppearanceSettingValue(
        "appearance_library_background_tile_size",
        settingsStore.appearanceLibraryBackgroundTileSize,
        defaultAppearanceLibraryBackgroundTileSize
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
    property bool safetyConfirmBeforeDeletingPage: normalizeBoolean(
        settingsStore.safetyConfirmBeforeDeletingPage,
        defaultSafetyConfirmBeforeDeletingPage
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
        syncAppearanceSetting("appearance_library_background")
    }

    onAppearanceGridDensityChanged: {
        syncAppearanceSetting("appearance_grid_density")
    }

    onAppearanceShowHeroBlockChanged: {
        syncAppearanceSetting("appearance_show_hero_block")
    }

    onAppearanceLibraryBackgroundSolidColorChanged: {
        syncAppearanceSetting("appearance_library_background_solid_color")
    }

    onAppearanceLibraryBackgroundTextureChanged: {
        syncAppearanceSetting("appearance_library_background_texture")
    }

    onAppearanceLibraryBackgroundCustomImagePathChanged: {
        syncAppearanceSetting("appearance_library_background_custom_image_path")
    }

    onAppearanceLibraryBackgroundImageModeChanged: {
        syncAppearanceSetting("appearance_library_background_image_mode")
    }

    onAppearanceLibraryBackgroundTileSizeChanged: {
        syncAppearanceSetting("appearance_library_background_tile_size")
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

    onSafetyConfirmBeforeDeletingPageChanged: {
        const normalized = normalizeBoolean(
            safetyConfirmBeforeDeletingPage,
            defaultSafetyConfirmBeforeDeletingPage
        )
        if (safetyConfirmBeforeDeletingPage !== normalized) {
            safetyConfirmBeforeDeletingPage = normalized
            return
        }
        if (settingsStore.safetyConfirmBeforeDeletingPage !== normalized) {
            settingsStore.safetyConfirmBeforeDeletingPage = normalized
        }
    }
}
