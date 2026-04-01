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
    readonly property var settingDescriptors: SettingsCatalog.settingDescriptors

    function normalizeChoice(value, allowedValues, fallbackValue, aliases) {
        const normalizedValue = String(value || "").trim()
        const aliasEntries = Array.isArray(aliases) ? aliases : []
        for (let i = 0; i < aliasEntries.length; i += 1) {
            const entry = aliasEntries[i] || {}
            if (String(entry.from || "") === normalizedValue) {
                return String(entry.to || fallbackValue || "")
            }
        }
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
        return normalizeChoice(value, entry.options || [], defaultValue, entry.aliases || [])
    }

    function configuredSettingDescriptor(valueKey) {
        return settingDescriptor(settingDescriptors, valueKey)
    }

    function appearanceSettingDescriptor(valueKey) {
        const descriptor = configuredSettingDescriptor(valueKey)
        return descriptor && String(descriptor.valueKey || "").indexOf("appearance_") === 0
            ? descriptor
            : null
    }

    function normalizeSettingValue(valueKey, value, fallbackValue) {
        const descriptor = configuredSettingDescriptor(valueKey)
        if (!descriptor) {
            return fallbackValue
        }
        return normalizeConfiguredSetting(descriptor, value, fallbackValue)
    }

    function normalizeAppearanceSettingValue(valueKey, value, fallbackValue) {
        return normalizeSettingValue(valueKey, value, fallbackValue)
    }

    function syncConfiguredSetting(valueKey) {
        const descriptor = configuredSettingDescriptor(valueKey)
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

    function syncAppearanceSetting(valueKey) {
        syncConfiguredSetting(valueKey)
    }

    function normalizeGeneralDefaultReadingMode(value) {
        return normalizeSettingValue("general_default_reading_mode", value, defaultGeneralDefaultReadingMode)
    }

    function normalizeGeneralAfterImport(value) {
        return normalizeSettingValue("general_after_import", value, defaultGeneralAfterImport)
    }

    function normalizeGeneralDefaultViewAfterLaunch(value) {
        return normalizeSettingValue("general_default_view_after_launch", value, defaultGeneralDefaultViewAfterLaunch)
    }

    function normalizeReaderDefaultReadingMode(value) {
        return normalizeSettingValue("reader_default_reading_mode", value, defaultReaderDefaultReadingMode)
    }

    function normalizeReaderMagnifierSize(value) {
        return normalizeSettingValue("reader_magnifier_size", value, defaultReaderMagnifierSize)
    }

    function normalizeReaderPageEdgeBehavior(value) {
        return normalizeSettingValue("reader_page_edge_behavior", value, defaultReaderPageEdgeBehavior)
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
        const descriptor = configuredSettingDescriptor(key)
        if (descriptor) {
            return normalizeConfiguredSetting(
                descriptor,
                controller[String(descriptor.controllerProperty || "").trim()],
                fallbackValue
            )
        }
        return fallbackValue
    }

    function setSettingValue(valueKey, nextValue) {
        const key = String(valueKey || "")
        const descriptor = configuredSettingDescriptor(key)
        if (descriptor) {
            const propertyName = String(descriptor.controllerProperty || "").trim()
            if (propertyName.length > 0) {
                controller[propertyName] = normalizeConfiguredSetting(
                    descriptor,
                    nextValue,
                    descriptor.defaultValue
                )
            }
            return
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

    property string generalDefaultReadingMode: normalizeSettingValue(
        "general_default_reading_mode",
        settingsStore.generalDefaultReadingMode,
        defaultGeneralDefaultReadingMode
    )
    property bool generalOpenReaderFullscreenByDefault: normalizeSettingValue(
        "general_open_reader_fullscreen_by_default",
        settingsStore.generalOpenReaderFullscreenByDefault,
        defaultGeneralOpenReaderFullscreenByDefault
    )
    property string generalAfterImport: normalizeSettingValue(
        "general_after_import",
        settingsStore.generalAfterImport,
        defaultGeneralAfterImport
    )
    property string generalDefaultViewAfterLaunch: normalizeSettingValue(
        "general_default_view_after_launch",
        settingsStore.generalDefaultViewAfterLaunch,
        defaultGeneralDefaultViewAfterLaunch
    )
    property bool readerRememberLastReaderMode: normalizeSettingValue(
        "reader_remember_last_reader_mode",
        settingsStore.readerRememberLastReaderMode,
        defaultReaderRememberLastReaderMode
    )
    property string readerDefaultReadingMode: normalizeSettingValue(
        "reader_default_reading_mode",
        settingsStore.readerDefaultReadingMode,
        defaultReaderDefaultReadingMode
    )
    property string readerMagnifierSize: normalizeSettingValue(
        "reader_magnifier_size",
        settingsStore.readerMagnifierSize,
        defaultReaderMagnifierSize
    )
    property string readerPageEdgeBehavior: normalizeSettingValue(
        "reader_page_edge_behavior",
        settingsStore.readerPageEdgeBehavior,
        defaultReaderPageEdgeBehavior
    )
    property bool readerShowBookmarkRibbonOnGridCovers: normalizeSettingValue(
        "reader_show_bookmark_ribbon_on_grid_covers",
        settingsStore.readerShowBookmarkRibbonOnGridCovers,
        defaultReaderShowBookmarkRibbonOnGridCovers
    )
    property bool readerAutoOpenBookmarkedPageInsteadOfLastPage: normalizeSettingValue(
        "reader_auto_open_bookmarked_page_instead_of_last_page",
        settingsStore.readerAutoOpenBookmarkedPageInsteadOfLastPage,
        defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage
    )
    property bool readerShowActionNotifications: normalizeSettingValue(
        "reader_show_action_notifications",
        settingsStore.readerShowActionNotifications,
        defaultReaderShowActionNotifications
    )
    property bool importDoubleClickArchiveIntoLibrary: normalizeSettingValue(
        "import_double_click_archive_into_library",
        settingsStore.importDoubleClickArchiveIntoLibrary,
        defaultImportDoubleClickArchiveIntoLibrary
    )
    property bool importTreatImageFoldersAsIssues: normalizeSettingValue(
        "import_treat_image_folders_as_issues",
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
    property bool safetyConfirmBeforeDeletingFiles: normalizeSettingValue(
        "safety_confirm_before_deleting_files",
        settingsStore.safetyConfirmBeforeDeletingFiles,
        defaultSafetyConfirmBeforeDeletingFiles
    )
    property bool safetyConfirmBeforeDeletingSeries: normalizeSettingValue(
        "safety_confirm_before_deleting_series",
        settingsStore.safetyConfirmBeforeDeletingSeries,
        defaultSafetyConfirmBeforeDeletingSeries
    )
    property bool safetyConfirmBeforeReplace: normalizeSettingValue(
        "safety_confirm_before_replace",
        settingsStore.safetyConfirmBeforeReplace,
        defaultSafetyConfirmBeforeReplace
    )
    property bool safetyConfirmBeforeDeletingPage: normalizeSettingValue(
        "safety_confirm_before_deleting_page",
        settingsStore.safetyConfirmBeforeDeletingPage,
        defaultSafetyConfirmBeforeDeletingPage
    )

    onGeneralDefaultReadingModeChanged: syncConfiguredSetting("general_default_reading_mode")

    onGeneralOpenReaderFullscreenByDefaultChanged: syncConfiguredSetting("general_open_reader_fullscreen_by_default")

    onGeneralAfterImportChanged: syncConfiguredSetting("general_after_import")

    onGeneralDefaultViewAfterLaunchChanged: syncConfiguredSetting("general_default_view_after_launch")

    onReaderRememberLastReaderModeChanged: syncConfiguredSetting("reader_remember_last_reader_mode")

    onReaderDefaultReadingModeChanged: syncConfiguredSetting("reader_default_reading_mode")

    onReaderMagnifierSizeChanged: syncConfiguredSetting("reader_magnifier_size")

    onReaderPageEdgeBehaviorChanged: syncConfiguredSetting("reader_page_edge_behavior")

    onReaderShowBookmarkRibbonOnGridCoversChanged: syncConfiguredSetting("reader_show_bookmark_ribbon_on_grid_covers")

    onReaderAutoOpenBookmarkedPageInsteadOfLastPageChanged: syncConfiguredSetting("reader_auto_open_bookmarked_page_instead_of_last_page")

    onReaderShowActionNotificationsChanged: syncConfiguredSetting("reader_show_action_notifications")

    onImportDoubleClickArchiveIntoLibraryChanged: syncConfiguredSetting("import_double_click_archive_into_library")

    onImportTreatImageFoldersAsIssuesChanged: syncConfiguredSetting("import_treat_image_folders_as_issues")

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

    onSafetyConfirmBeforeDeletingFilesChanged: syncConfiguredSetting("safety_confirm_before_deleting_files")

    onSafetyConfirmBeforeDeletingSeriesChanged: syncConfiguredSetting("safety_confirm_before_deleting_series")

    onSafetyConfirmBeforeReplaceChanged: syncConfiguredSetting("safety_confirm_before_replace")

    onSafetyConfirmBeforeDeletingPageChanged: syncConfiguredSetting("safety_confirm_before_deleting_page")
}
