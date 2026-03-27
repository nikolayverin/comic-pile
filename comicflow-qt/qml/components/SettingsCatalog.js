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
    {
        key: "Blueprint",
        label: "Blueprint",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/4-grid-tile-blueprint-256px.png",
        tileSize: 256,
        previewUseDefaultBase: false
    },
    {
        key: "Linen",
        label: "Linen",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/5-grid-tile-linen-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Felt",
        label: "Felt",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/6-grid-tile-felt-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Cartographer 01",
        label: "Cartographer 01",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/7-grid-tile-cartographer-1-512px.png",
        tileSize: 512,
        previewUseDefaultBase: true
    },
    {
        key: "Craft 02",
        label: "Craft 02",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/8-grid-tile-cradt-2-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Craft 01",
        label: "Craft 01",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/9-grid-tile-cradt-1-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Cork 01",
        label: "Cork 01",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/10-grid-tile-cork-1-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Cork 02",
        label: "Cork 02",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/11-grid-tile-cork-2-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Cardboard",
        label: "Cardboard",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/12-grid-tile-ccardbosrd-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Crosslines",
        label: "Crosslines",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/13-grid-tile-crosslines-512px.png",
        tileSize: 512,
        previewUseDefaultBase: true
    },
    {
        key: "Fabric",
        label: "Fabric",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/14-grid-tile-fabtic-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    },
    {
        key: "Strains",
        label: "Strains",
        source: "qrc:/qt/qml/ComicPile/assets/ui/grid-backgrounds/15-grid-tile-strains-512px.png",
        tileSize: 512,
        previewUseDefaultBase: false
    }
]
var appearanceTexturePresetOptions = optionKeys(appearanceTextureOptions)

function appearanceTextureOption(textureKey) {
    const key = String(textureKey || "").trim()
    const options = Array.isArray(appearanceTextureOptions) ? appearanceTextureOptions : []
    for (let i = 0; i < options.length; i += 1) {
        const entry = options[i] || {}
        if (String(entry.key || "") === key) {
            return entry
        }
    }
    return options[0] || {}
}

function appearanceTextureSource(textureKey) {
    return String((appearanceTextureOption(textureKey) || {}).source || "")
}

function appearanceTextureTilePixelSize(textureKey) {
    const raw = Number((appearanceTextureOption(textureKey) || {}).tileSize || 64)
    return raw === 512 ? 512 : raw === 256 ? 256 : 64
}

function appearanceTextureUsesDefaultBase(textureKey) {
    return Boolean((appearanceTextureOption(textureKey) || {}).previewUseDefaultBase)
}
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
    appearance_library_background_texture: "Blueprint",
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
