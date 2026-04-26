.pragma library
.import "AppLanguageCatalog.js" as AppLanguageCatalog

var fallbackLanguageCode = AppLanguageCatalog.fallbackLanguageCode

var translations = {
    en: {
        commonOk: "OK",
        commonCancel: "Cancel",
        commonOpen: "Open",
        commonChoose: "Choose",
        commonChange: "Change",
        commonUpload: "Upload",
        commonCheck: "Check",
        commonReset: "Reset",
        commonRetry: "Retry",
        commonRetrying: "Retrying...",
        commonSkip: "Skip",
        commonSkipAll: "Skip all",
        commonReplaceAll: "Replace all",
        commonWorking: "Working...",
        commonClose: "Close",

        popupActionErrorTitle: "Action Error",
        popupIssueArchiveUnavailableTitle: "Issue archive unavailable",
        popupSettingsTitle: "Settings",
        popupDeleteErrorTitle: "Couldn't remove file",
        popupDeleteRetrying: "Retrying delete...",
        popupOpenFolder: "Open folder",
        popupImportErrorsTitle: "Import Errors",
        popupImportErrorsIntro: "These archives were not imported. Review reason and retry after fixing.",
        popupImportConflictTitle: "Issue Already Exists",
        popupImportConflictMessage: "This archive matches an existing issue in your library. Choose what to do:",
        popupImportConflictKeepCurrent: "Keep current",
        popupImportConflictReplace: "Replace",
        popupIncomingArchive: "Incoming archive:",
        popupExistingRecord: "Existing record:",
        popupSystemPrefix: "System: ",

        settingsResetToDefault: "Reset settings to default",
        settingsSevenZipUnavailable: "7-Zip is not available.",
        settingsImportArchivesSection: "Import & Archives",
        settingsLibraryDataSection: "Library & Data",
        settingsGeneralSection: "General",
        settingsReaderSection: "Reader",
        settingsAppearanceSection: "Appearance",
        settingsSafetySection: "Safety",

        settingsGeneralAutomaticallyCheckForUpdates: "Automatically check for updates",
        settingsGeneralAppLanguage: "App language",
        settingsGeneralOpenReaderFullscreenByDefault: "Open reader in fullscreen by default",
        settingsGeneralAfterImport: "After import:",
        settingsGeneralDefaultViewAfterLaunch: "Default view after launch:",

        settingsReaderDefaultReadingMode: "Default reading mode",
        settingsReaderRememberLastReaderMode: "Remember last reader mode",
        settingsReaderMagnifierSize: "Magnifier size",
        settingsReaderPageEdgeBehavior: "Page edge behavior",
        settingsReaderAutoOpenBookmarkedPage: "Auto-open bookmarked page instead of last page",
        settingsReaderShowActionNotifications: "Show action notifications in Reader",

        settingsAppearanceCoverGridBackground: "Cover grid background",
        settingsAppearanceUseBuiltInBackground: "Use a built-in cover grid background",
        settingsAppearanceCustomShort: "Custom",
        settingsAppearanceGridDensity: "Grid density",
        settingsAppearanceShowHeroBlock: "Show hero block",
        settingsAppearanceShowBookmarkRibbon: "Show bookmark ribbon on grid covers",

        settingsSevenZipPath: "7-Zip path:",
        settingsVerifySevenZip: "Verify 7-Zip",
        settingsSupportedArchiveFormats: "Supported archive formats:",
        settingsSupportedImageFormats: "Supported image formats:",
        settingsSupportedDocumentFormats: "Supported document formats:",

        settingsLibraryDataLocation: "Library data location:",
        settingsLibraryFolder: "Library folder:",
        settingsRuntimeFolder: "Runtime folder:",
        settingsCheckStorageAccess: "Check storage access",
        settingsChecking: "Checking...",
        settingsMoveLibraryData: "Move library data:",
        settingsNoDestinationSelected: "No destination selected",
        settingsScheduledAfterRestart: "Scheduled after restart.",
        settingsRelocationHint: "The transfer will run after you restart the app and may take time depending on library size. Choose an empty folder.",

        sidebarQuickFilterLastImport: "Last import",
        sidebarQuickFilterFavorites: "Favorites",
        sidebarQuickFilterBookmarks: "Bookmarks",
        sidebarLibrarySection: "Library",
        sidebarMenuAddIssues: "Add issues",
        sidebarMenuBulkEdit: "Bulk Edit",
        sidebarMenuEditSeries: "Edit Series",
        sidebarMenuMergeIntoSeries: "Merge into series",
        sidebarMenuShowFolder: "Show folder",
        sidebarMenuDeleteFiles: "Delete files",
        sidebarMenuDeleteSelected: "Delete selected",
        sidebarDropZoneTitle: "Drop comic archives\nto your library",
        sidebarDropZoneSubtitleLineOne: "Supported archives",
        sidebarDropZoneSubtitleLineTwoPrefix: "and ",
        sidebarDropZoneSubtitleLink: "other supported files",
        sidebarDropNoLocalFiles: "Drop Contains No Local Files.",
        sidebarDropNoSupportedSources: "Drop Contains No Supported Comic Sources.",

        importNoValidFilesSelected: "No valid files selected for import.",
        importAlreadyRunning: "Import is already running. Wait for completion.",
        importFailedDefault: "Import failed.",
        importPreparationFailed: "Import preparation failed.",
        importModelUnavailable: "Import model is unavailable.",
        importRuntimeErrorPrefix: "Import runtime error: ",
        importRetrySourceMissing: "Source path no longer resolves to a single importable item.",
        importFailedUnknownFile: "[unknown file]",
        importRollbackFailedPrefix: "Rollback failed: ",

        navigationContinueReadingTitle: "Continue reading",
        navigationNextUnreadTitle: "Next unread",
        navigationNoActiveReadingSession: "No active reading session is available yet.",
        navigationNoNextUnread: "No next unread issue is queued right now.",
        navigationIssueUnavailable: "The requested issue is unavailable.",
        navigationRevealIssueUnavailable: "The requested issue could not be revealed in the library view.",
        navigationContinueRevealFailure: "The saved reading target could not be opened from the library view.",
        navigationNextUnreadRevealFailure: "The next unread issue could not be opened from the library view.",

        metadataNothingSelected: "Nothing selected.",
        metadataSelectSeriesFirst: "Select a series first.",
        metadataSeriesContextMissing: "Series context is missing.",
        metadataNoIssuesFound: "No issues found for selected series.",
        metadataMergeTargetRequired: "Enter a series name to merge into.",
        metadataBulkEditFieldRequired: "Enter at least one field for bulk edit.",
        metadataSaveVerificationFailed: "Save verification failed.",
        metadataSaveMismatch: "Metadata save verification mismatch. Please retry.",
        mainSeriesFolderUnavailable: "Series folder is unavailable.",
        mainTileModeImageLimit: "Tile mode supports background images up to 1 MB.",
        mainFailedScheduleLibraryLocation: "Failed to schedule the new library data location.",
        libraryAllVolumes: "All volumes",
        libraryNoVolume: "No Volume",
        quickFilterLastImportedIssuesTitle: "Last imported issues",
        quickFilterFavoriteIssuesTitle: "Favorite issues",
        quickFilterBookmarkedIssuesTitle: "Bookmarked issues",
        quickFilterLastImportedEmpty: "No recent import yet",
        quickFilterFavoriteEmpty: "No favorite issues yet",
        quickFilterBookmarkedEmpty: "No bookmarked issues yet",
        seriesHeaderContextMissing: "Series context is missing.",
        seriesHeaderPrepareShuffleFailed: "Failed to prepare shuffled background.",
        seriesHeaderSaveFailed: "Failed to save series header images.",
        seriesMetaTitleMerge: "Merge into series",
        seriesMetaTitleBulk: "Bulk Edit",
        seriesMetaTitleSingle: "Series Metadata",
        seriesMetaSectionGeneral: "General",
        seriesMetaLabelSeries: "Series",
        seriesMetaLabelVolume: "Volume",
        seriesMetaLabelGenres: "Genres",
        seriesMetaLabelPublisher: "Publisher",
        seriesMetaLabelSeriesTitle: "Series title",
        seriesMetaLabelYear: "Year",
        seriesMetaLabelMonth: "Month",
        seriesMetaLabelAgeRating: "Age rating",
        seriesMetaLabelSummary: "Summary",
        seriesMetaInlineErrorHeadline: "Save failed",
        seriesMetaButtonMerge: "Merge",
        seriesMetaButtonSave: "Save",

        issueAutofillMessage: "Saved issue data was found in your library.\n\nDo you want to fill the remaining empty fields from it, or keep the values currently in this form and update saved data?",
        seriesAutofillMessage: "Saved series info was found for \"{seriesLabel}\".\n\nFill the remaining series fields automatically before saving?",
        noFolderAvailableMessage: "No folder is available for {label}.",
        backgroundImageTooLargeMessage: "Selected background image is too large. Limit for this mode is {limitLabel}."
    }
}

function normalizedLanguageCode(language) {
    const normalized = AppLanguageCatalog.normalizeLanguageCode(language)
    if (translations[normalized]) {
        return normalized
    }
    return fallbackLanguageCode
}

function hasTextKey(source, key) {
    return Boolean(source) && Object.prototype.hasOwnProperty.call(source, key)
}

function missingText(key) {
    const normalizedKey = String(key || "missing_text")
    return "[[" + normalizedKey + "]]"
}

function t(key, language) {
    const normalizedKey = String(key || "").trim()
    if (normalizedKey.length < 1) {
        return missingText("empty_key")
    }

    const languageCode = normalizedLanguageCode(language)
    const languageTexts = translations[languageCode] || {}
    if (hasTextKey(languageTexts, normalizedKey)) {
        return String(languageTexts[normalizedKey])
    }

    const fallbackTexts = translations[fallbackLanguageCode] || {}
    if (hasTextKey(fallbackTexts, normalizedKey)) {
        return String(fallbackTexts[normalizedKey])
    }

    return missingText(normalizedKey)
}

function templateValue(values, key) {
    if (!values || !Object.prototype.hasOwnProperty.call(values, key)) {
        return ""
    }
    return String(values[key])
}

function formatTemplate(template, values) {
    return String(template || "").replace(/\{([^}]+)\}/g, function(match, key) {
        return templateValue(values, key)
    })
}

function tf(key, values, language) {
    return formatTemplate(t(key, language), values)
}

var commonOk = t("commonOk")
var commonCancel = t("commonCancel")
var commonOpen = t("commonOpen")
var commonChoose = t("commonChoose")
var commonChange = t("commonChange")
var commonUpload = t("commonUpload")
var commonCheck = t("commonCheck")
var commonReset = t("commonReset")
var commonRetry = t("commonRetry")
var commonRetrying = t("commonRetrying")
var commonSkip = t("commonSkip")
var commonSkipAll = t("commonSkipAll")
var commonReplaceAll = t("commonReplaceAll")
var commonWorking = t("commonWorking")
var commonClose = t("commonClose")

var popupActionErrorTitle = t("popupActionErrorTitle")
var popupIssueArchiveUnavailableTitle = t("popupIssueArchiveUnavailableTitle")
var popupSettingsTitle = t("popupSettingsTitle")
var popupDeleteErrorTitle = t("popupDeleteErrorTitle")
var popupDeleteRetrying = t("popupDeleteRetrying")
var popupOpenFolder = t("popupOpenFolder")
var popupImportErrorsTitle = t("popupImportErrorsTitle")
var popupImportErrorsIntro = t("popupImportErrorsIntro")
var popupImportConflictTitle = t("popupImportConflictTitle")
var popupImportConflictMessage = t("popupImportConflictMessage")
var popupImportConflictKeepCurrent = t("popupImportConflictKeepCurrent")
var popupImportConflictReplace = t("popupImportConflictReplace")
var popupIncomingArchive = t("popupIncomingArchive")
var popupExistingRecord = t("popupExistingRecord")
var popupSystemPrefix = t("popupSystemPrefix")

var settingsResetToDefault = t("settingsResetToDefault")
var settingsSevenZipUnavailable = t("settingsSevenZipUnavailable")
var settingsImportArchivesSection = t("settingsImportArchivesSection")
var settingsLibraryDataSection = t("settingsLibraryDataSection")
var settingsGeneralSection = t("settingsGeneralSection")
var settingsReaderSection = t("settingsReaderSection")
var settingsAppearanceSection = t("settingsAppearanceSection")
var settingsSafetySection = t("settingsSafetySection")

var settingsGeneralAutomaticallyCheckForUpdates = t("settingsGeneralAutomaticallyCheckForUpdates")
var settingsGeneralAppLanguage = t("settingsGeneralAppLanguage")
var settingsGeneralOpenReaderFullscreenByDefault = t("settingsGeneralOpenReaderFullscreenByDefault")
var settingsGeneralAfterImport = t("settingsGeneralAfterImport")
var settingsGeneralDefaultViewAfterLaunch = t("settingsGeneralDefaultViewAfterLaunch")

var settingsReaderDefaultReadingMode = t("settingsReaderDefaultReadingMode")
var settingsReaderRememberLastReaderMode = t("settingsReaderRememberLastReaderMode")
var settingsReaderMagnifierSize = t("settingsReaderMagnifierSize")
var settingsReaderPageEdgeBehavior = t("settingsReaderPageEdgeBehavior")
var settingsReaderAutoOpenBookmarkedPage = t("settingsReaderAutoOpenBookmarkedPage")
var settingsReaderShowActionNotifications = t("settingsReaderShowActionNotifications")

var settingsAppearanceCoverGridBackground = t("settingsAppearanceCoverGridBackground")
var settingsAppearanceUseBuiltInBackground = t("settingsAppearanceUseBuiltInBackground")
var settingsAppearanceCustomShort = t("settingsAppearanceCustomShort")
var settingsAppearanceGridDensity = t("settingsAppearanceGridDensity")
var settingsAppearanceShowHeroBlock = t("settingsAppearanceShowHeroBlock")
var settingsAppearanceShowBookmarkRibbon = t("settingsAppearanceShowBookmarkRibbon")

var settingsSevenZipPath = t("settingsSevenZipPath")
var settingsVerifySevenZip = t("settingsVerifySevenZip")
var settingsSupportedArchiveFormats = t("settingsSupportedArchiveFormats")
var settingsSupportedImageFormats = t("settingsSupportedImageFormats")
var settingsSupportedDocumentFormats = t("settingsSupportedDocumentFormats")

var settingsLibraryDataLocation = t("settingsLibraryDataLocation")
var settingsLibraryFolder = t("settingsLibraryFolder")
var settingsRuntimeFolder = t("settingsRuntimeFolder")
var settingsCheckStorageAccess = t("settingsCheckStorageAccess")
var settingsChecking = t("settingsChecking")
var settingsMoveLibraryData = t("settingsMoveLibraryData")
var settingsNoDestinationSelected = t("settingsNoDestinationSelected")
var settingsScheduledAfterRestart = t("settingsScheduledAfterRestart")
var settingsRelocationHint = t("settingsRelocationHint")

var sidebarQuickFilterLastImport = t("sidebarQuickFilterLastImport")
var sidebarQuickFilterFavorites = t("sidebarQuickFilterFavorites")
var sidebarQuickFilterBookmarks = t("sidebarQuickFilterBookmarks")
var sidebarLibrarySection = t("sidebarLibrarySection")
var sidebarMenuAddIssues = t("sidebarMenuAddIssues")
var sidebarMenuBulkEdit = t("sidebarMenuBulkEdit")
var sidebarMenuEditSeries = t("sidebarMenuEditSeries")
var sidebarMenuMergeIntoSeries = t("sidebarMenuMergeIntoSeries")
var sidebarMenuShowFolder = t("sidebarMenuShowFolder")
var sidebarMenuDeleteFiles = t("sidebarMenuDeleteFiles")
var sidebarMenuDeleteSelected = t("sidebarMenuDeleteSelected")
var sidebarDropZoneTitle = t("sidebarDropZoneTitle")
var sidebarDropZoneSubtitleLineOne = t("sidebarDropZoneSubtitleLineOne")
var sidebarDropZoneSubtitleLineTwoPrefix = t("sidebarDropZoneSubtitleLineTwoPrefix")
var sidebarDropZoneSubtitleLink = t("sidebarDropZoneSubtitleLink")
var sidebarDropNoLocalFiles = t("sidebarDropNoLocalFiles")
var sidebarDropNoSupportedSources = t("sidebarDropNoSupportedSources")

var importNoValidFilesSelected = t("importNoValidFilesSelected")
var importAlreadyRunning = t("importAlreadyRunning")
var importFailedDefault = t("importFailedDefault")
var importPreparationFailed = t("importPreparationFailed")
var importModelUnavailable = t("importModelUnavailable")
var importRuntimeErrorPrefix = t("importRuntimeErrorPrefix")
var importRetrySourceMissing = t("importRetrySourceMissing")
var importFailedUnknownFile = t("importFailedUnknownFile")
var importRollbackFailedPrefix = t("importRollbackFailedPrefix")

var navigationContinueReadingTitle = t("navigationContinueReadingTitle")
var navigationNextUnreadTitle = t("navigationNextUnreadTitle")
var navigationNoActiveReadingSession = t("navigationNoActiveReadingSession")
var navigationNoNextUnread = t("navigationNoNextUnread")
var navigationIssueUnavailable = t("navigationIssueUnavailable")
var navigationRevealIssueUnavailable = t("navigationRevealIssueUnavailable")
var navigationContinueRevealFailure = t("navigationContinueRevealFailure")
var navigationNextUnreadRevealFailure = t("navigationNextUnreadRevealFailure")

var metadataNothingSelected = t("metadataNothingSelected")
var metadataSelectSeriesFirst = t("metadataSelectSeriesFirst")
var metadataSeriesContextMissing = t("metadataSeriesContextMissing")
var metadataNoIssuesFound = t("metadataNoIssuesFound")
var metadataMergeTargetRequired = t("metadataMergeTargetRequired")
var metadataBulkEditFieldRequired = t("metadataBulkEditFieldRequired")
var metadataSaveVerificationFailed = t("metadataSaveVerificationFailed")
var metadataSaveMismatch = t("metadataSaveMismatch")
var mainSeriesFolderUnavailable = t("mainSeriesFolderUnavailable")
var mainTileModeImageLimit = t("mainTileModeImageLimit")
var mainFailedScheduleLibraryLocation = t("mainFailedScheduleLibraryLocation")
var libraryAllVolumes = t("libraryAllVolumes")
var libraryNoVolume = t("libraryNoVolume")
var quickFilterLastImportedIssuesTitle = t("quickFilterLastImportedIssuesTitle")
var quickFilterFavoriteIssuesTitle = t("quickFilterFavoriteIssuesTitle")
var quickFilterBookmarkedIssuesTitle = t("quickFilterBookmarkedIssuesTitle")
var quickFilterLastImportedEmpty = t("quickFilterLastImportedEmpty")
var quickFilterFavoriteEmpty = t("quickFilterFavoriteEmpty")
var quickFilterBookmarkedEmpty = t("quickFilterBookmarkedEmpty")
var seriesHeaderContextMissing = t("seriesHeaderContextMissing")
var seriesHeaderPrepareShuffleFailed = t("seriesHeaderPrepareShuffleFailed")
var seriesHeaderSaveFailed = t("seriesHeaderSaveFailed")
var seriesMetaTitleMerge = t("seriesMetaTitleMerge")
var seriesMetaTitleBulk = t("seriesMetaTitleBulk")
var seriesMetaTitleSingle = t("seriesMetaTitleSingle")
var seriesMetaSectionGeneral = t("seriesMetaSectionGeneral")
var seriesMetaLabelSeries = t("seriesMetaLabelSeries")
var seriesMetaLabelVolume = t("seriesMetaLabelVolume")
var seriesMetaLabelGenres = t("seriesMetaLabelGenres")
var seriesMetaLabelPublisher = t("seriesMetaLabelPublisher")
var seriesMetaLabelSeriesTitle = t("seriesMetaLabelSeriesTitle")
var seriesMetaLabelYear = t("seriesMetaLabelYear")
var seriesMetaLabelMonth = t("seriesMetaLabelMonth")
var seriesMetaLabelAgeRating = t("seriesMetaLabelAgeRating")
var seriesMetaLabelSummary = t("seriesMetaLabelSummary")
var seriesMetaInlineErrorHeadline = t("seriesMetaInlineErrorHeadline")
var seriesMetaButtonMerge = t("seriesMetaButtonMerge")
var seriesMetaButtonSave = t("seriesMetaButtonSave")

function issueAutofillMessage(issueNumber, seriesLabel, language) {
    return tf("issueAutofillMessage", {
        issueNumber: issueNumber,
        seriesLabel: seriesLabel
    }, language)
}

function seriesAutofillMessage(seriesLabel, language) {
    return tf("seriesAutofillMessage", {
        seriesLabel: String(seriesLabel || "this series")
    }, language)
}

function noFolderAvailableMessage(label, language) {
    return tf("noFolderAvailableMessage", {
        label: String(label || "this series")
    }, language)
}

function backgroundImageTooLargeMessage(limitLabel, language) {
    return tf("backgroundImageTooLargeMessage", {
        limitLabel: String(limitLabel || "")
    }, language)
}

function settingsSectionLabel(key, language) {
    const normalized = String(key || "").trim()
    if (normalized === "general") return t("settingsGeneralSection", language)
    if (normalized === "reader") return t("settingsReaderSection", language)
    if (normalized === "import_archives") return t("settingsImportArchivesSection", language)
    if (normalized === "library_data") return t("settingsLibraryDataSection", language)
    if (normalized === "appearance") return t("settingsAppearanceSection", language)
    if (normalized === "safety") return t("settingsSafetySection", language)
    return normalized
}
