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
var safetyMarkAsReadBehaviorOptions = [
    "Open next issue",
    "Stay on current issue",
    "Close reader on last issue"
]

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
            label: "Restore previous window position",
            controlType: "switch",
            valueKey: "reader_restore_previous_window_position"
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
            label: "Show bookmark ribbon on grid covers",
            controlType: "switch",
            valueKey: "reader_show_bookmark_ribbon_on_grid_covers"
        },
        {
            label: "Auto-open bookmarked page instead of last page",
            controlType: "switch",
            valueKey: "reader_auto_open_bookmarked_page_instead_of_last_page"
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
            label: "Mark as read behavior",
            controlType: "radio",
            valueKey: "safety_mark_as_read_behavior",
            options: safetyMarkAsReadBehaviorOptions
        }
    ]
}

var defaultGeneralDefaultReadingMode = "Remember last state"
var defaultGeneralOpenReaderFullscreenByDefault = false
var defaultGeneralAfterImport = "Focus imported series"
var defaultGeneralDefaultViewAfterLaunch = "Remember last state"
var defaultReaderRestorePreviousWindowPosition = false
var defaultReaderRememberLastReaderMode = false
var defaultReaderDefaultReadingMode = "1 page"
var defaultReaderMagnifierSize = "Medium"
var defaultReaderPageEdgeBehavior = "Stop at boundary"
var defaultReaderShowBookmarkRibbonOnGridCovers = false
var defaultReaderAutoOpenBookmarkedPageInsteadOfLastPage = false
var defaultImportDoubleClickArchiveIntoLibrary = false
var defaultImportTreatImageFoldersAsIssues = false
var defaultAppearanceLibraryBackground = "Default"
var defaultAppearanceGridDensity = "Default"
var defaultAppearanceShowHeroBlock = true
var defaultAppearanceLibraryBackgroundSolidColor = "#8A8A8A"
var defaultAppearanceLibraryBackgroundTexture = "Dots"
var defaultAppearanceLibraryBackgroundCustomImagePath = ""
var defaultAppearanceLibraryBackgroundImageMode = "Fill"
var defaultAppearanceLibraryBackgroundTileSize = "64x64px"
var defaultSafetyConfirmBeforeDeletingFiles = true
var defaultSafetyConfirmBeforeDeletingSeries = true
var defaultSafetyConfirmBeforeReplace = true
var defaultSafetyMarkAsReadBehavior = "Open next issue"
