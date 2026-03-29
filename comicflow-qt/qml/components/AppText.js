.pragma library

var commonOk = "OK"
var commonCancel = "Cancel"
var commonOpen = "Open"
var commonChoose = "Choose"
var commonChange = "Change"
var commonUpload = "Upload"
var commonCheck = "Check"
var commonReset = "Reset"
var commonRetry = "Retry"
var commonRetrying = "Retrying..."
var commonSkip = "Skip"
var commonSkipAll = "Skip all"
var commonReplaceAll = "Replace all"
var commonWorking = "Working..."
var commonClose = "Close"

var popupActionErrorTitle = "Action Error"
var popupSettingsTitle = "Settings"
var popupDeleteErrorTitle = "Couldn't remove file"
var popupDeleteRetrying = "Retrying delete..."
var popupOpenFolder = "Open folder"
var popupImportErrorsTitle = "Import Errors"
var popupImportErrorsIntro = "These archives were not imported. Review reason and retry after fixing."
var popupImportConflictTitle = "Issue Already Exists"
var popupImportConflictMessage = "This archive matches an existing issue in your library. Choose what to do:"
var popupImportConflictKeepCurrent = "Keep current"
var popupImportConflictReplace = "Replace"
var popupIncomingArchive = "Incoming archive:"
var popupExistingRecord = "Existing record:"
var popupSystemPrefix = "System: "

var settingsResetToDefault = "Reset settings to default"
var settingsSevenZipUnavailable = "7-Zip is not available."
var settingsImportArchivesSection = "Import & Archives"
var settingsLibraryDataSection = "Library & Data"
var settingsGeneralSection = "General"
var settingsReaderSection = "Reader"
var settingsAppearanceSection = "Appearance"
var settingsSafetySection = "Safety"

var settingsGeneralDefaultReadingMode = "Default reading mode"
var settingsGeneralOpenReaderFullscreenByDefault = "Open reader in fullscreen by default"
var settingsGeneralAfterImport = "After import:"
var settingsGeneralDefaultViewAfterLaunch = "Default view after launch:"

var settingsReaderRememberLastReaderMode = "Remember last reader mode"
var settingsReaderMagnifierSize = "Magnifier size"
var settingsReaderPageEdgeBehavior = "Page edge behavior"
var settingsReaderAutoOpenBookmarkedPage = "Auto-open bookmarked page instead of last page"
var settingsReaderShowActionNotifications = "Show action notifications in Reader"

var settingsAppearanceCoverGridBackground = "Cover grid background"
var settingsAppearanceUseBuiltInBackground = "Use a built-in cover grid background"
var settingsAppearanceCustomShort = "Custom"
var settingsAppearanceGridDensity = "Grid density"
var settingsAppearanceShowHeroBlock = "Show hero block"
var settingsAppearanceShowBookmarkRibbon = "Show bookmark ribbon on grid covers"

var settingsSevenZipPath = "7-Zip path:"
var settingsVerifySevenZip = "Verify 7-Zip"
var settingsSupportedArchiveFormats = "Supported archive formats:"
var settingsSupportedImageFormats = "Supported image formats:"
var settingsSupportedDocumentFormats = "Supported document formats:"

var settingsLibraryDataLocation = "Library data location:"
var settingsLibraryFolder = "Library folder:"
var settingsRuntimeFolder = "Runtime folder:"
var settingsCheckStorageAccess = "Check storage access"
var settingsChecking = "Checking..."
var settingsMoveLibraryData = "Move library data:"
var settingsNoDestinationSelected = "No destination selected"
var settingsScheduledAfterRestart = "Scheduled after restart."
var settingsRelocationHint = "The transfer will run after you restart the app and may take time depending on library size. Choose an empty folder."

function settingsSectionLabel(key) {
    const normalized = String(key || "").trim()
    if (normalized === "general") return settingsGeneralSection
    if (normalized === "reader") return settingsReaderSection
    if (normalized === "import_archives") return settingsImportArchivesSection
    if (normalized === "library_data") return settingsLibraryDataSection
    if (normalized === "appearance") return settingsAppearanceSection
    if (normalized === "safety") return settingsSafetySection
    return normalized
}
