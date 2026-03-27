.pragma library

function optionKeys(entries) {
    const result = []
    const source = Array.isArray(entries) ? entries : []
    for (let i = 0; i < source.length; i += 1) {
        const entry = source[i] || {}
        result.push(String(entry.key || ""))
    }
    return result
}

var generalDefaultReadingModeOptions = ["1 page", "2 pages", "Remember last state"]
var generalAfterImportOptions = ["Focus imported series", "Open last import", "Do nothing"]
var generalDefaultViewAfterLaunchOptions = ["First series in library", "Last import", "Remember last state"]
var readerDefaultReadingModeOptions = ["1 page", "2 pages"]
var readerMagnifierSizeOptions = ["Small", "Medium", "Large"]
var readerPageEdgeBehaviorOptions = ["Continue", "Stop at boundary"]
var appearanceGridDensityOptions = ["Compact", "Default", "Comfortable"]
var appearanceBackgroundSourceOptions = [
    { key: "Default", label: "Default" },
    { key: "Solid", label: "Solid" },
    { key: "Texture", label: "Texture" },
    { key: "Custom image", label: "Custom image" }
]
var appearanceBackgroundSourceModeKeys = optionKeys(appearanceBackgroundSourceOptions)
var appearanceSolidColorOptions = [
    "#EA0600", "#F17300", "#F0D200", "#86E600", "#29DC57",
    "#18C7D8", "#1D68D9", "#4821BE", "#C7188D", "#4B392F",
    "#000000", "#1F1F1F", "#4A4A4A", "#8A8A8A", "#C3C3C3"
]
var appearanceTextureOptions = [
    { key: "Dots", label: "Dots", source: "qrc:/qt/qml/ComicPile/assets/ui/grid-tile.png" },
    { key: "Noise", label: "Noise", source: "qrc:/qt/qml/ComicPile/assets/textures/sidebar_dither_noise.png" }
]
var appearanceTexturePresetOptions = optionKeys(appearanceTextureOptions)
var appearanceBackgroundImageModeOptions = ["Fit", "Fill", "Stretch", "Tile"]
var appearanceBackgroundTileSizeOptions = ["64x64px", "256x256px", "512x512px"]
var settingsSections = [
    { key: "general", label: "General", iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-pencil-ruler.svg" },
    { key: "reader", label: "Reader", iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-book-open-text.svg" },
    { key: "import_archives", label: "Import & Archives", iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-download.svg" },
    { key: "library_data", label: "Library & Data", iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-library-big.svg" },
    { key: "appearance", label: "Appearance", iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-appearance.svg" },
    { key: "safety", label: "Safety", iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-shield-check.svg" }
]

var sectionOptionRows = {
    general: [
        {
            label: "Default reading mode",
            controlType: "dropdown",
            valueKey: "general_default_reading_mode",
            options: generalDefaultReadingModeOptions
        },
        {
            label: "Open reader in fullscreen by default",
            controlType: "checkbox",
            valueKey: "general_open_reader_fullscreen_by_default"
        },
        {
            label: "After import:",
            controlType: "dropdown",
            valueKey: "general_after_import",
            options: generalAfterImportOptions
        },
        {
            label: "Default view after launch:",
            controlType: "dropdown",
            valueKey: "general_default_view_after_launch",
            options: generalDefaultViewAfterLaunchOptions
        }
    ],
    reader: [
        {
            label: "Default reading mode",
            controlType: "segmented",
            valueKey: "reader_default_reading_mode",
            options: readerDefaultReadingModeOptions
        },
        {
            label: "Remember last reader mode",
            controlType: "switch",
            valueKey: "reader_remember_last_reader_mode"
        },
        {
            label: "Magnifier size",
            controlType: "segmented",
            valueKey: "reader_magnifier_size",
            options: readerMagnifierSizeOptions
        },
        {
            label: "Page edge behavior",
            controlType: "segmented",
            valueKey: "reader_page_edge_behavior",
            options: readerPageEdgeBehaviorOptions
        },
        {
            label: "Auto-open bookmarked page instead of last page",
            controlType: "switch",
            valueKey: "reader_auto_open_bookmarked_page_instead_of_last_page"
        },
        {
            label: "Show action notifications in Reader",
            controlType: "switch",
            valueKey: "reader_show_action_notifications"
        }
    ],
    import_archives: [],
    library_data: [],
    appearance: [
        {
            label: "Cover grid background",
            controlType: "dropdown",
            valueKey: "appearance_library_background",
            options: appearanceBackgroundSourceModeKeys
        },
        {
            label: "Grid density",
            controlType: "segmented",
            valueKey: "appearance_grid_density",
            options: appearanceGridDensityOptions
        },
        {
            label: "Show hero block",
            controlType: "switch",
            valueKey: "appearance_show_hero_block"
        },
        {
            label: "Show bookmark ribbon on grid covers",
            controlType: "switch",
            valueKey: "reader_show_bookmark_ribbon_on_grid_covers"
        }
    ],
    safety: [
        {
            label: "Confirm before deleting files",
            controlType: "switch",
            valueKey: "safety_confirm_before_deleting_files"
        },
        {
            label: "Confirm before deleting series",
            controlType: "switch",
            valueKey: "safety_confirm_before_deleting_series"
        },
        {
            label: "Confirm before replace",
            controlType: "switch",
            valueKey: "safety_confirm_before_replace"
        },
        {
            label: "Confirm before deleting page",
            controlType: "switch",
            valueKey: "safety_confirm_before_deleting_page"
        }
    ]
}

var defaultSettingsState = {
    general_default_reading_mode: "Remember last state",
    general_open_reader_fullscreen_by_default: false,
    general_after_import: "Focus imported series",
    general_default_view_after_launch: "Remember last state",

    reader_remember_last_reader_mode: true,
    reader_default_reading_mode: "1 page",
    reader_magnifier_size: "Medium",
    reader_page_edge_behavior: "Continue",
    reader_show_bookmark_ribbon_on_grid_covers: true,
    reader_auto_open_bookmarked_page_instead_of_last_page: true,
    reader_show_action_notifications: true,

    import_double_click_archive_into_library: false,
    import_treat_image_folders_as_issues: false,

    appearance_library_background: "Default",
    appearance_grid_density: "Default",
    appearance_show_hero_block: true,
    appearance_library_background_solid_color: "#8A8A8A",
    appearance_library_background_texture: "Dots",
    appearance_library_background_custom_image_path: "",
    appearance_library_background_image_mode: "Fill",
    appearance_library_background_tile_size: "64x64px",

    safety_confirm_before_deleting_files: true,
    safety_confirm_before_deleting_series: true,
    safety_confirm_before_replace: true,
    safety_confirm_before_deleting_page: true
}

function defaultSettingValue(valueKey) {
    const key = String(valueKey || "")
    return defaultSettingsState[key]
}

function defaultSettingsSnapshot() {
    return Object.assign({}, defaultSettingsState)
}

var defaultGeneralDefaultReadingMode = defaultSettingsState.general_default_reading_mode
var defaultGeneralOpenReaderFullscreenByDefault = defaultSettingsState.general_open_reader_fullscreen_by_default
var defaultGeneralAfterImport = defaultSettingsState.general_after_import
var defaultGeneralDefaultViewAfterLaunch = defaultSettingsState.general_default_view_after_launch
var defaultReaderRememberLastReaderMode = defaultSettingsState.reader_remember_last_reader_mode
var defaultReaderDefaultReadingMode = defaultSettingsState.reader_default_reading_mode
var defaultReaderMagnifierSize = defaultSettingsState.reader_magnifier_size
var defaultReaderPageEdgeBehavior = defaultSettingsState.reader_page_edge_behavior
var defaultReaderShowBookmarkRibbonOnGridCovers = defaultSettingsState.reader_show_bookmark_ribbon_on_grid_covers
var defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage = defaultSettingsState.reader_auto_open_bookmarked_page_instead_of_last_page
var defaultReaderShowActionNotifications = defaultSettingsState.reader_show_action_notifications
var defaultImportDoubleClickArchiveIntoLibrary = defaultSettingsState.import_double_click_archive_into_library
var defaultImportTreatImageFoldersAsIssues = defaultSettingsState.import_treat_image_folders_as_issues
var defaultAppearanceLibraryBackground = defaultSettingsState.appearance_library_background
var defaultAppearanceGridDensity = defaultSettingsState.appearance_grid_density
var defaultAppearanceShowHeroBlock = defaultSettingsState.appearance_show_hero_block
var defaultAppearanceLibraryBackgroundSolidColor = defaultSettingsState.appearance_library_background_solid_color
var defaultAppearanceLibraryBackgroundTexture = defaultSettingsState.appearance_library_background_texture
var defaultAppearanceLibraryBackgroundCustomImagePath = defaultSettingsState.appearance_library_background_custom_image_path
var defaultAppearanceLibraryBackgroundImageMode = defaultSettingsState.appearance_library_background_image_mode
var defaultAppearanceLibraryBackgroundTileSize = defaultSettingsState.appearance_library_background_tile_size
var defaultSafetyConfirmBeforeDeletingFiles = defaultSettingsState.safety_confirm_before_deleting_files
var defaultSafetyConfirmBeforeDeletingSeries = defaultSettingsState.safety_confirm_before_deleting_series
var defaultSafetyConfirmBeforeReplace = defaultSettingsState.safety_confirm_before_replace
var defaultSafetyConfirmBeforeDeletingPage = defaultSettingsState.safety_confirm_before_deleting_page
