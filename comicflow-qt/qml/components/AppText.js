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
var popupIssueArchiveUnavailableTitle = "Issue archive unavailable"
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

var settingsGeneralAutomaticallyCheckForUpdates = "Automatically check for updates"
var settingsGeneralOpenReaderFullscreenByDefault = "Open reader in fullscreen by default"
var settingsGeneralAfterImport = "After import:"
var settingsGeneralDefaultViewAfterLaunch = "Default view after launch:"

var settingsReaderDefaultReadingMode = "Default reading mode"
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

var sidebarQuickFilterLastImport = "Last import"
var sidebarQuickFilterFavorites = "Favorites"
var sidebarQuickFilterBookmarks = "Bookmarks"
var sidebarLibrarySection = "Library"
var sidebarMenuAddIssues = "Add issues"
var sidebarMenuBulkEdit = "Bulk Edit"
var sidebarMenuEditSeries = "Edit Series"
var sidebarMenuMergeIntoSeries = "Merge into series"
var sidebarMenuShowFolder = "Show folder"
var sidebarMenuDeleteFiles = "Delete files"
var sidebarMenuDeleteSelected = "Delete selected"
var sidebarDropZoneTitle = "Drop comic archives\nto your library"
var sidebarDropZoneSubtitleLineOne = "Supported archives"
var sidebarDropZoneSubtitleLineTwoPrefix = "and "
var sidebarDropZoneSubtitleLink = "other supported files"
var sidebarDropNoLocalFiles = "Drop Contains No Local Files."
var sidebarDropNoSupportedSources = "Drop Contains No Supported Comic Sources."

var importNoValidFilesSelected = "No valid files selected for import."
var importAlreadyRunning = "Import is already running. Wait for completion."
var importFailedDefault = "Import failed."
var importPreparationFailed = "Import preparation failed."
var importModelUnavailable = "Import model is unavailable."
var importRuntimeErrorPrefix = "Import runtime error: "
var importRetrySourceMissing = "Source path no longer resolves to a single importable item."
var importFailedUnknownFile = "[unknown file]"
var importRollbackFailedPrefix = "Rollback failed: "

var navigationContinueReadingTitle = "Continue reading"
var navigationNextUnreadTitle = "Next unread"
var navigationNoActiveReadingSession = "No active reading session is available yet."
var navigationNoNextUnread = "No next unread issue is queued right now."
var navigationIssueUnavailable = "The requested issue is unavailable."
var navigationRevealIssueUnavailable = "The requested issue could not be revealed in the library view."
var navigationContinueRevealFailure = "The saved reading target could not be opened from the library view."
var navigationNextUnreadRevealFailure = "The next unread issue could not be opened from the library view."

var metadataNothingSelected = "Nothing selected."
var metadataSelectSeriesFirst = "Select a series first."
var metadataSeriesContextMissing = "Series context is missing."
var metadataNoIssuesFound = "No issues found for selected series."
var metadataMergeTargetRequired = "Enter a series name to merge into."
var metadataBulkEditFieldRequired = "Enter at least one field for bulk edit."
var metadataSaveVerificationFailed = "Save verification failed."
var metadataSaveMismatch = "Metadata save verification mismatch. Please retry."
var mainSeriesFolderUnavailable = "Series folder is unavailable."
var mainTileModeImageLimit = "Tile mode supports background images up to 1 MB."
var mainFailedScheduleLibraryLocation = "Failed to schedule the new library data location."
var libraryAllVolumes = "All volumes"
var libraryNoVolume = "No Volume"
var quickFilterLastImportedIssuesTitle = "Last imported issues"
var quickFilterFavoriteIssuesTitle = "Favorite issues"
var quickFilterBookmarkedIssuesTitle = "Bookmarked issues"
var quickFilterLastImportedEmpty = "No recent import yet"
var quickFilterFavoriteEmpty = "No favorite issues yet"
var quickFilterBookmarkedEmpty = "No bookmarked issues yet"
var seriesHeaderContextMissing = "Series context is missing."
var seriesHeaderPrepareShuffleFailed = "Failed to prepare shuffled background."
var seriesHeaderSaveFailed = "Failed to save series header images."
var seriesMetaTitleMerge = "Merge into series"
var seriesMetaTitleBulk = "Bulk Edit"
var seriesMetaTitleSingle = "Series Metadata"
var seriesMetaSectionGeneral = "General"
var seriesMetaLabelSeries = "Series"
var seriesMetaLabelVolume = "Volume"
var seriesMetaLabelGenres = "Genres"
var seriesMetaLabelPublisher = "Publisher"
var seriesMetaLabelSeriesTitle = "Series title"
var seriesMetaLabelYear = "Year"
var seriesMetaLabelMonth = "Month"
var seriesMetaLabelAgeRating = "Age rating"
var seriesMetaLabelSummary = "Summary"
var seriesMetaInlineErrorHeadline = "Save failed"
var seriesMetaButtonMerge = "Merge"
var seriesMetaButtonSave = "Save"

function issueAutofillMessage(issueNumber, seriesLabel) {
    return "Saved issue data was found in your library.\n\n"
        + "Do you want to fill the remaining empty fields from it, or keep the values currently in this form and update saved data?"
}

function seriesAutofillMessage(seriesLabel) {
    return "Saved series info was found for \"" + String(seriesLabel || "this series") + "\".\n\n"
        + "Fill the remaining series fields automatically before saving?"
}

function noFolderAvailableMessage(label) {
    return "No folder is available for " + String(label || "this series") + "."
}

function backgroundImageTooLargeMessage(limitLabel) {
    return "Selected background image is too large. Limit for this mode is " + String(limitLabel || "") + "."
}

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
