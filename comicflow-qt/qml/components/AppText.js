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
        commonDelete: "Delete",
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

        importProgressTitleCancelling: "Cancelling Import",
        importProgressTitleInProgress: "Import In Progress",
        importProgressCleanupProgress: "Cleanup progress",
        importProgressCurrentFile: "Current file",
        importProgressCleaningImportedItems: "Cleaning up imported items...",
        importProgressWaitingSafeStop: "Waiting for a safe stop...",
        importProgressPreparingImport: "Preparing import...",
        importProgressFinalizing: "Finalizing...",
        importProgressCleaningUp: "Cleaning up...",
        importProgressCancelling: "Cancelling...",
        importConflictRestoreTitle: "Restore Existing Issue?",
        importConflictPossibleDuplicateTitle: "Possible Duplicate Found",
        importConflictSuspiciousMatchTitle: "Suspicious Match Found",
        importConflictRestoreMessage: "This archive looks close to a deleted issue in this series, but the match is not exact. Restore that issue or import this as a new issue:",
        importConflictPossibleDuplicateMessage: "This looks like the same issue in your library, but the archive is not an exact file match. Replace the existing file or import this as a new issue:",
        importConflictSuspiciousMatchMessage: "This might be related to an existing issue, but the match is weak. Import it as a new issue or skip this file:",
        importConflictImportAsNew: "Import as new",
        importConflictRestoreExisting: "Restore existing",
        importConflictReplaceExisting: "Replace existing",
        updateAvailableTitle: "Update available",
        updateAvailablePatchLabel: "Patch {version}",
        updateAvailableReleaseNotesFallback: "Release notes are available for this update.",
        updateAvailableLater: "Later",
        updateAvailableDownload: "Download update",
        updateDownloadTitle: "Downloading update",
        updateDownloadFailed: "Download failed",
        updateDownloadTimedOut: "The update download timed out before it could finish.",
        updateDownloadInstall: "Install update",
        updateDownloadActionTitle: "Update download",
        updateDownloadNoLink: "No update download link is available for this release.",
        updateInstallActionTitle: "Install update",
        updateInstallHelperStartFailed: "Comic Pile couldn't start the update helper.",

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
        settingsSafetyConfirmBeforeDeletingFiles: "Confirm before deleting files",
        settingsSafetyConfirmBeforeDeletingSeries: "Confirm before deleting series",
        settingsSafetyConfirmBeforeReplace: "Confirm before replace",
        settingsSafetyConfirmBeforeDeletingPage: "Confirm before deleting page",

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

        topMenuFile: "File",
        topMenuHelp: "Help",
        topMenuAddFiles: "Add files",
        topMenuAddFolder: "Add folder",
        topMenuSettings: "Settings",
        topMenuExit: "Exit",
        topMenuQuickTour: "Quick tour",
        topMenuWhatsNew: "What's new",
        topMenuViewHelp: "View Help",
        topMenuAbout: "About",

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
    },
    es: {
        commonOk: "Aceptar",
        commonCancel: "Cancelar",
        commonOpen: "Abrir",
        commonChoose: "Elegir",
        commonChange: "Cambiar",
        commonUpload: "Cargar",
        commonCheck: "Comprobar",
        commonReset: "Restablecer",
        commonRetry: "Reintentar",
        commonRetrying: "Reintentando...",
        commonSkip: "Omitir",
        commonSkipAll: "Omitir todo",
        commonReplaceAll: "Reemplazar todo",
        commonDelete: "Eliminar",
        commonWorking: "Trabajando...",
        commonClose: "Cerrar",
        popupActionErrorTitle: "Error de acción",
        popupIssueArchiveUnavailableTitle: "Archivo del número no disponible",
        popupSettingsTitle: "Configuración",
        popupDeleteErrorTitle: "No se pudo eliminar el archivo",
        popupDeleteRetrying: "Reintentando eliminación...",
        popupOpenFolder: "Abrir carpeta",
        popupImportErrorsTitle: "Errores de importación",
        popupImportErrorsIntro: "Estos archivos no se importaron. Revisa el motivo y reintenta después de corregirlo.",
        popupImportConflictTitle: "El número ya existe",
        popupImportConflictMessage: "Este archivo coincide con un número existente en tu biblioteca. Elige qué hacer:",
        popupImportConflictKeepCurrent: "Mantener actual",
        popupImportConflictReplace: "Reemplazar",
        popupIncomingArchive: "Archivo entrante:",
        popupExistingRecord: "Registro existente:",
        popupSystemPrefix: "Sistema: ",
        importProgressTitleCancelling: "Cancelando importación",
        importProgressTitleInProgress: "Importación en curso",
        importProgressCleanupProgress: "Progreso de limpieza",
        importProgressCurrentFile: "Archivo actual",
        importProgressCleaningImportedItems: "Limpiando elementos importados...",
        importProgressWaitingSafeStop: "Esperando una detención segura...",
        importProgressPreparingImport: "Preparando importación...",
        importProgressFinalizing: "Finalizando...",
        importProgressCleaningUp: "Limpiando...",
        importProgressCancelling: "Cancelando...",
        importConflictRestoreTitle: "¿Restaurar número existente?",
        importConflictPossibleDuplicateTitle: "Posible duplicado encontrado",
        importConflictSuspiciousMatchTitle: "Coincidencia sospechosa encontrada",
        importConflictRestoreMessage: "Este archivo se parece a un número eliminado de esta serie, pero la coincidencia no es exacta. Restaura ese número o impórtalo como nuevo:",
        importConflictPossibleDuplicateMessage: "Parece el mismo número de tu biblioteca, pero el archivo no coincide exactamente. Reemplaza el archivo existente o impórtalo como nuevo:",
        importConflictSuspiciousMatchMessage: "Puede estar relacionado con un número existente, pero la coincidencia es débil. Impórtalo como nuevo u omite este archivo:",
        importConflictImportAsNew: "Importar como nuevo",
        importConflictRestoreExisting: "Restaurar existente",
        importConflictReplaceExisting: "Reemplazar existente",
        updateAvailableTitle: "Actualización disponible",
        updateAvailablePatchLabel: "Parche {version}",
        updateAvailableReleaseNotesFallback: "Las notas de la versión están disponibles para esta actualización.",
        updateAvailableLater: "Más tarde",
        updateAvailableDownload: "Descargar actualización",
        updateDownloadTitle: "Descargando actualización",
        updateDownloadFailed: "Descarga fallida",
        updateDownloadTimedOut: "La descarga de la actualización agotó el tiempo antes de finalizar.",
        updateDownloadInstall: "Instalar actualización",
        updateDownloadActionTitle: "Descarga de actualización",
        updateDownloadNoLink: "No hay enlace de descarga disponible para esta versión.",
        updateInstallActionTitle: "Instalar actualización",
        updateInstallHelperStartFailed: "Comic Pile no pudo iniciar el asistente de actualización.",
        settingsResetToDefault: "Restablecer la configuración predeterminada",
        settingsSevenZipUnavailable: "7-Zip no está disponible.",
        settingsImportArchivesSection: "Importación y archivos",
        settingsLibraryDataSection: "Biblioteca y datos",
        settingsGeneralSection: "General",
        settingsReaderSection: "Lector",
        settingsAppearanceSection: "Apariencia",
        settingsSafetySection: "Seguridad",
        settingsGeneralAutomaticallyCheckForUpdates: "Buscar actualizaciones automáticamente",
        settingsGeneralAppLanguage: "Idioma de la aplicación",
        settingsGeneralOpenReaderFullscreenByDefault: "Abrir el lector en pantalla completa por defecto",
        settingsGeneralAfterImport: "Después de importar:",
        settingsGeneralDefaultViewAfterLaunch: "Vista predeterminada al iniciar:",
        settingsReaderDefaultReadingMode: "Modo de lectura predeterminado",
        settingsReaderRememberLastReaderMode: "Recordar el último modo del lector",
        settingsReaderMagnifierSize: "Tamaño de la lupa",
        settingsReaderPageEdgeBehavior: "Comportamiento al borde de página",
        settingsReaderAutoOpenBookmarkedPage: "Abrir página marcada en vez de la última",
        settingsReaderShowActionNotifications: "Mostrar notificaciones de acción en el lector",
        settingsAppearanceCoverGridBackground: "Fondo de la cuadrícula de portadas",
        settingsAppearanceUseBuiltInBackground: "Usar un fondo integrado para la cuadrícula de portadas",
        settingsAppearanceCustomShort: "Personalizado",
        settingsAppearanceGridDensity: "Densidad de la cuadrícula",
        settingsAppearanceShowHeroBlock: "Mostrar bloque principal",
        settingsAppearanceShowBookmarkRibbon: "Mostrar cinta de marcador en las portadas",
        settingsSafetyConfirmBeforeDeletingFiles: "Confirmar antes de eliminar archivos",
        settingsSafetyConfirmBeforeDeletingSeries: "Confirmar antes de eliminar series",
        settingsSafetyConfirmBeforeReplace: "Confirmar antes de reemplazar",
        settingsSafetyConfirmBeforeDeletingPage: "Confirmar antes de eliminar una página",
        settingsSevenZipPath: "Ruta de 7-Zip:",
        settingsVerifySevenZip: "Verificar 7-Zip",
        settingsSupportedArchiveFormats: "Formatos de archivo compatibles:",
        settingsSupportedImageFormats: "Formatos de imagen compatibles:",
        settingsSupportedDocumentFormats: "Formatos de documento compatibles:",
        settingsLibraryDataLocation: "Ubicación de datos de la biblioteca:",
        settingsLibraryFolder: "Carpeta de la biblioteca:",
        settingsRuntimeFolder: "Carpeta de ejecución:",
        settingsCheckStorageAccess: "Comprobar acceso al almacenamiento",
        settingsChecking: "Comprobando...",
        settingsMoveLibraryData: "Mover datos de la biblioteca:",
        settingsNoDestinationSelected: "No se seleccionó ningún destino",
        settingsScheduledAfterRestart: "Programado para después del reinicio.",
        settingsRelocationHint: "La transferencia se ejecutará después de reiniciar la aplicación y puede tardar según el tamaño de la biblioteca. Elige una carpeta vacía.",
        sidebarQuickFilterLastImport: "Última importación",
        sidebarQuickFilterFavorites: "Favoritos",
        sidebarQuickFilterBookmarks: "Marcadores",
        sidebarLibrarySection: "Biblioteca",
        sidebarMenuAddIssues: "Agregar números",
        sidebarMenuBulkEdit: "Edición masiva",
        sidebarMenuEditSeries: "Editar serie",
        sidebarMenuMergeIntoSeries: "Fusionar en serie",
        sidebarMenuShowFolder: "Mostrar carpeta",
        sidebarMenuDeleteFiles: "Eliminar archivos",
        sidebarMenuDeleteSelected: "Eliminar seleccionados",
        sidebarDropZoneTitle: "Suelta archivos de cómic\nen tu biblioteca",
        sidebarDropZoneSubtitleLineOne: "Archivos compatibles",
        sidebarDropZoneSubtitleLineTwoPrefix: "y ",
        sidebarDropZoneSubtitleLink: "otros archivos compatibles",
        sidebarDropNoLocalFiles: "La suelta no contiene archivos locales.",
        sidebarDropNoSupportedSources: "La suelta no contiene fuentes de cómic compatibles.",
        topMenuFile: "Archivo",
        topMenuHelp: "Ayuda",
        topMenuAddFiles: "Agregar archivos",
        topMenuAddFolder: "Agregar carpeta",
        topMenuSettings: "Configuración",
        topMenuExit: "Salir",
        topMenuQuickTour: "Recorrido rápido",
        topMenuWhatsNew: "Novedades",
        topMenuViewHelp: "Ver ayuda",
        topMenuAbout: "Acerca de",
        navigationContinueReadingTitle: "Continuar leyendo",
        navigationNextUnreadTitle: "Siguiente sin leer",
        quickFilterLastImportedIssuesTitle: "Números importados recientemente",
        quickFilterFavoriteIssuesTitle: "Números favoritos",
        quickFilterBookmarkedIssuesTitle: "Números con marcador",
        quickFilterLastImportedEmpty: "Aún no hay importación reciente",
        quickFilterFavoriteEmpty: "Aún no hay números favoritos",
        quickFilterBookmarkedEmpty: "Aún no hay números con marcador"
    },
    de: {
        commonOk: "OK",
        commonCancel: "Abbrechen",
        commonOpen: "Öffnen",
        commonChoose: "Auswählen",
        commonChange: "Ändern",
        commonUpload: "Hochladen",
        commonCheck: "Prüfen",
        commonReset: "Zurücksetzen",
        commonRetry: "Erneut versuchen",
        commonRetrying: "Erneuter Versuch...",
        commonSkip: "Überspringen",
        commonSkipAll: "Alle überspringen",
        commonReplaceAll: "Alle ersetzen",
        commonDelete: "Löschen",
        commonWorking: "Wird verarbeitet...",
        commonClose: "Schließen",
        popupActionErrorTitle: "Aktionsfehler",
        popupIssueArchiveUnavailableTitle: "Ausgabenarchiv nicht verfügbar",
        popupSettingsTitle: "Einstellungen",
        popupDeleteErrorTitle: "Datei konnte nicht entfernt werden",
        popupDeleteRetrying: "Löschen wird erneut versucht...",
        popupOpenFolder: "Ordner öffnen",
        popupImportErrorsTitle: "Importfehler",
        popupImportErrorsIntro: "Diese Archive wurden nicht importiert. Prüfe den Grund und versuche es nach der Korrektur erneut.",
        popupImportConflictTitle: "Ausgabe existiert bereits",
        popupImportConflictMessage: "Dieses Archiv entspricht einer vorhandenen Ausgabe in deiner Bibliothek. Wähle, was passieren soll:",
        popupImportConflictKeepCurrent: "Aktuelle behalten",
        popupImportConflictReplace: "Ersetzen",
        popupIncomingArchive: "Eingehendes Archiv:",
        popupExistingRecord: "Vorhandener Eintrag:",
        popupSystemPrefix: "System: ",
        importProgressTitleCancelling: "Import wird abgebrochen",
        importProgressTitleInProgress: "Import läuft",
        importProgressCleanupProgress: "Bereinigungsfortschritt",
        importProgressCurrentFile: "Aktuelle Datei",
        importProgressCleaningImportedItems: "Importierte Elemente werden bereinigt...",
        importProgressWaitingSafeStop: "Warten auf sicheren Stopp...",
        importProgressPreparingImport: "Import wird vorbereitet...",
        importProgressFinalizing: "Wird abgeschlossen...",
        importProgressCleaningUp: "Wird bereinigt...",
        importProgressCancelling: "Wird abgebrochen...",
        importConflictRestoreTitle: "Vorhandene Ausgabe wiederherstellen?",
        importConflictPossibleDuplicateTitle: "Mögliches Duplikat gefunden",
        importConflictSuspiciousMatchTitle: "Verdächtige Übereinstimmung gefunden",
        importConflictRestoreMessage: "Dieses Archiv ähnelt einer gelöschten Ausgabe in dieser Serie, ist aber keine exakte Übereinstimmung. Stelle diese Ausgabe wieder her oder importiere sie als neue Ausgabe:",
        importConflictPossibleDuplicateMessage: "Das sieht nach derselben Ausgabe in deiner Bibliothek aus, aber das Archiv ist keine exakte Dateiübereinstimmung. Ersetze die vorhandene Datei oder importiere sie als neue Ausgabe:",
        importConflictSuspiciousMatchMessage: "Dies könnte mit einer vorhandenen Ausgabe zusammenhängen, aber die Übereinstimmung ist schwach. Importiere sie als neue Ausgabe oder überspringe diese Datei:",
        importConflictImportAsNew: "Als neu importieren",
        importConflictRestoreExisting: "Vorhandene wiederherstellen",
        importConflictReplaceExisting: "Vorhandene ersetzen",
        updateAvailableTitle: "Update verfügbar",
        updateAvailablePatchLabel: "Patch {version}",
        updateAvailableReleaseNotesFallback: "Versionshinweise sind für dieses Update verfügbar.",
        updateAvailableLater: "Später",
        updateAvailableDownload: "Update herunterladen",
        updateDownloadTitle: "Update wird heruntergeladen",
        updateDownloadFailed: "Download fehlgeschlagen",
        updateDownloadTimedOut: "Der Update-Download wurde vor dem Abschluss wegen Zeitüberschreitung beendet.",
        updateDownloadInstall: "Update installieren",
        updateDownloadActionTitle: "Update-Download",
        updateDownloadNoLink: "Für diese Version ist kein Update-Download-Link verfügbar.",
        updateInstallActionTitle: "Update installieren",
        updateInstallHelperStartFailed: "Comic Pile konnte den Update-Helfer nicht starten.",
        settingsResetToDefault: "Einstellungen auf Standard zurücksetzen",
        settingsSevenZipUnavailable: "7-Zip ist nicht verfügbar.",
        settingsImportArchivesSection: "Import & Archive",
        settingsLibraryDataSection: "Bibliothek & Daten",
        settingsGeneralSection: "Allgemein",
        settingsReaderSection: "Reader",
        settingsAppearanceSection: "Darstellung",
        settingsSafetySection: "Sicherheit",
        settingsGeneralAutomaticallyCheckForUpdates: "Automatisch nach Updates suchen",
        settingsGeneralAppLanguage: "App-Sprache",
        settingsGeneralOpenReaderFullscreenByDefault: "Reader standardmäßig im Vollbild öffnen",
        settingsGeneralAfterImport: "Nach dem Import:",
        settingsGeneralDefaultViewAfterLaunch: "Standardansicht nach dem Start:",
        settingsReaderDefaultReadingMode: "Standard-Lesemodus",
        settingsReaderRememberLastReaderMode: "Letzten Reader-Modus merken",
        settingsReaderMagnifierSize: "Lupengröße",
        settingsReaderPageEdgeBehavior: "Verhalten am Seitenrand",
        settingsReaderAutoOpenBookmarkedPage: "Lesezeichen-Seite statt letzter Seite öffnen",
        settingsReaderShowActionNotifications: "Aktionshinweise im Reader anzeigen",
        settingsAppearanceCoverGridBackground: "Hintergrund des Cover-Rasters",
        settingsAppearanceUseBuiltInBackground: "Integrierten Hintergrund für das Cover-Raster verwenden",
        settingsAppearanceCustomShort: "Benutzerdefiniert",
        settingsAppearanceGridDensity: "Rasterdichte",
        settingsAppearanceShowHeroBlock: "Hero-Bereich anzeigen",
        settingsAppearanceShowBookmarkRibbon: "Lesezeichenband auf Covern anzeigen",
        settingsSafetyConfirmBeforeDeletingFiles: "Vor dem Löschen von Dateien bestätigen",
        settingsSafetyConfirmBeforeDeletingSeries: "Vor dem Löschen von Serien bestätigen",
        settingsSafetyConfirmBeforeReplace: "Vor dem Ersetzen bestätigen",
        settingsSafetyConfirmBeforeDeletingPage: "Vor dem Löschen einer Seite bestätigen",
        settingsSevenZipPath: "7-Zip-Pfad:",
        settingsVerifySevenZip: "7-Zip prüfen",
        settingsSupportedArchiveFormats: "Unterstützte Archivformate:",
        settingsSupportedImageFormats: "Unterstützte Bildformate:",
        settingsSupportedDocumentFormats: "Unterstützte Dokumentformate:",
        settingsLibraryDataLocation: "Speicherort der Bibliotheksdaten:",
        settingsLibraryFolder: "Bibliotheksordner:",
        settingsRuntimeFolder: "Laufzeitordner:",
        settingsCheckStorageAccess: "Speicherzugriff prüfen",
        settingsChecking: "Prüfung läuft...",
        settingsMoveLibraryData: "Bibliotheksdaten verschieben:",
        settingsNoDestinationSelected: "Kein Ziel ausgewählt",
        settingsScheduledAfterRestart: "Nach dem Neustart geplant.",
        settingsRelocationHint: "Die Übertragung wird nach dem Neustart der App ausgeführt und kann je nach Bibliotheksgröße dauern. Wähle einen leeren Ordner.",
        sidebarQuickFilterLastImport: "Letzter Import",
        sidebarQuickFilterFavorites: "Favoriten",
        sidebarQuickFilterBookmarks: "Lesezeichen",
        sidebarLibrarySection: "Bibliothek",
        sidebarMenuAddIssues: "Ausgaben hinzufügen",
        sidebarMenuBulkEdit: "Massenbearbeitung",
        sidebarMenuEditSeries: "Serie bearbeiten",
        sidebarMenuMergeIntoSeries: "In Serie zusammenführen",
        sidebarMenuShowFolder: "Ordner anzeigen",
        sidebarMenuDeleteFiles: "Dateien löschen",
        sidebarMenuDeleteSelected: "Ausgewählte löschen",
        sidebarDropZoneTitle: "Comic-Archive\nin deine Bibliothek ziehen",
        sidebarDropZoneSubtitleLineOne: "Unterstützte Archive",
        sidebarDropZoneSubtitleLineTwoPrefix: "und ",
        sidebarDropZoneSubtitleLink: "andere unterstützte Dateien",
        sidebarDropNoLocalFiles: "Der Drop enthält keine lokalen Dateien.",
        sidebarDropNoSupportedSources: "Der Drop enthält keine unterstützten Comic-Quellen.",
        topMenuFile: "Datei",
        topMenuHelp: "Hilfe",
        topMenuAddFiles: "Dateien hinzufügen",
        topMenuAddFolder: "Ordner hinzufügen",
        topMenuSettings: "Einstellungen",
        topMenuExit: "Beenden",
        topMenuQuickTour: "Kurztour",
        topMenuWhatsNew: "Neuigkeiten",
        topMenuViewHelp: "Hilfe anzeigen",
        topMenuAbout: "Info",
        navigationContinueReadingTitle: "Weiterlesen",
        navigationNextUnreadTitle: "Nächste ungelesene",
        quickFilterLastImportedIssuesTitle: "Zuletzt importierte Ausgaben",
        quickFilterFavoriteIssuesTitle: "Favorisierte Ausgaben",
        quickFilterBookmarkedIssuesTitle: "Ausgaben mit Lesezeichen",
        quickFilterLastImportedEmpty: "Noch kein aktueller Import",
        quickFilterFavoriteEmpty: "Noch keine favorisierten Ausgaben",
        quickFilterBookmarkedEmpty: "Noch keine Ausgaben mit Lesezeichen"
    },
    fr: {
        commonOk: "OK",
        commonCancel: "Annuler",
        commonOpen: "Ouvrir",
        commonChoose: "Choisir",
        commonChange: "Modifier",
        commonUpload: "Importer",
        commonCheck: "Vérifier",
        commonReset: "Réinitialiser",
        commonRetry: "Réessayer",
        commonRetrying: "Nouvel essai...",
        commonSkip: "Ignorer",
        commonSkipAll: "Tout ignorer",
        commonReplaceAll: "Tout remplacer",
        commonDelete: "Supprimer",
        commonWorking: "Traitement...",
        commonClose: "Fermer",
        popupActionErrorTitle: "Erreur d'action",
        popupIssueArchiveUnavailableTitle: "Archive du numéro indisponible",
        popupSettingsTitle: "Paramètres",
        popupDeleteErrorTitle: "Impossible de supprimer le fichier",
        popupDeleteRetrying: "Nouvel essai de suppression...",
        popupOpenFolder: "Ouvrir le dossier",
        popupImportErrorsTitle: "Erreurs d'importation",
        popupImportErrorsIntro: "Ces archives n'ont pas été importées. Vérifie la raison puis réessaie après correction.",
        popupImportConflictTitle: "Le numéro existe déjà",
        popupImportConflictMessage: "Cette archive correspond à un numéro existant dans ta bibliothèque. Choisis quoi faire :",
        popupImportConflictKeepCurrent: "Garder l'actuel",
        popupImportConflictReplace: "Remplacer",
        popupIncomingArchive: "Archive entrante :",
        popupExistingRecord: "Entrée existante :",
        popupSystemPrefix: "Système : ",
        importProgressTitleCancelling: "Annulation de l'importation",
        importProgressTitleInProgress: "Importation en cours",
        importProgressCleanupProgress: "Progression du nettoyage",
        importProgressCurrentFile: "Fichier actuel",
        importProgressCleaningImportedItems: "Nettoyage des éléments importés...",
        importProgressWaitingSafeStop: "Attente d'un arrêt sûr...",
        importProgressPreparingImport: "Préparation de l'importation...",
        importProgressFinalizing: "Finalisation...",
        importProgressCleaningUp: "Nettoyage...",
        importProgressCancelling: "Annulation...",
        importConflictRestoreTitle: "Restaurer le numéro existant ?",
        importConflictPossibleDuplicateTitle: "Doublon possible trouvé",
        importConflictSuspiciousMatchTitle: "Correspondance suspecte trouvée",
        importConflictRestoreMessage: "Cette archive ressemble à un numéro supprimé de cette série, mais la correspondance n'est pas exacte. Restaure ce numéro ou importe-le comme nouveau :",
        importConflictPossibleDuplicateMessage: "Cela ressemble au même numéro dans ta bibliothèque, mais l'archive n'est pas une correspondance exacte. Remplace le fichier existant ou importe-le comme nouveau :",
        importConflictSuspiciousMatchMessage: "Cela peut être lié à un numéro existant, mais la correspondance est faible. Importe-le comme nouveau ou ignore ce fichier :",
        importConflictImportAsNew: "Importer comme nouveau",
        importConflictRestoreExisting: "Restaurer l'existant",
        importConflictReplaceExisting: "Remplacer l'existant",
        updateAvailableTitle: "Mise à jour disponible",
        updateAvailablePatchLabel: "Correctif {version}",
        updateAvailableReleaseNotesFallback: "Les notes de version sont disponibles pour cette mise à jour.",
        updateAvailableLater: "Plus tard",
        updateAvailableDownload: "Télécharger la mise à jour",
        updateDownloadTitle: "Téléchargement de la mise à jour",
        updateDownloadFailed: "Échec du téléchargement",
        updateDownloadTimedOut: "Le téléchargement de la mise à jour a expiré avant de se terminer.",
        updateDownloadInstall: "Installer la mise à jour",
        updateDownloadActionTitle: "Téléchargement de la mise à jour",
        updateDownloadNoLink: "Aucun lien de téléchargement n'est disponible pour cette version.",
        updateInstallActionTitle: "Installer la mise à jour",
        updateInstallHelperStartFailed: "Comic Pile n'a pas pu démarrer l'assistant de mise à jour.",
        settingsResetToDefault: "Réinitialiser les paramètres par défaut",
        settingsSevenZipUnavailable: "7-Zip n'est pas disponible.",
        settingsImportArchivesSection: "Importation et archives",
        settingsLibraryDataSection: "Bibliothèque et données",
        settingsGeneralSection: "Général",
        settingsReaderSection: "Lecteur",
        settingsAppearanceSection: "Apparence",
        settingsSafetySection: "Sécurité",
        settingsGeneralAutomaticallyCheckForUpdates: "Rechercher automatiquement les mises à jour",
        settingsGeneralAppLanguage: "Langue de l'application",
        settingsGeneralOpenReaderFullscreenByDefault: "Ouvrir le lecteur en plein écran par défaut",
        settingsGeneralAfterImport: "Après l'importation :",
        settingsGeneralDefaultViewAfterLaunch: "Vue par défaut au démarrage :",
        settingsReaderDefaultReadingMode: "Mode de lecture par défaut",
        settingsReaderRememberLastReaderMode: "Mémoriser le dernier mode du lecteur",
        settingsReaderMagnifierSize: "Taille de la loupe",
        settingsReaderPageEdgeBehavior: "Comportement en bord de page",
        settingsReaderAutoOpenBookmarkedPage: "Ouvrir la page marquée au lieu de la dernière page",
        settingsReaderShowActionNotifications: "Afficher les notifications d'action dans le lecteur",
        settingsAppearanceCoverGridBackground: "Arrière-plan de la grille de couvertures",
        settingsAppearanceUseBuiltInBackground: "Utiliser un arrière-plan intégré pour la grille de couvertures",
        settingsAppearanceCustomShort: "Personnalisé",
        settingsAppearanceGridDensity: "Densité de la grille",
        settingsAppearanceShowHeroBlock: "Afficher le bloc principal",
        settingsAppearanceShowBookmarkRibbon: "Afficher le ruban de marque-page sur les couvertures",
        settingsSafetyConfirmBeforeDeletingFiles: "Confirmer avant de supprimer des fichiers",
        settingsSafetyConfirmBeforeDeletingSeries: "Confirmer avant de supprimer des séries",
        settingsSafetyConfirmBeforeReplace: "Confirmer avant de remplacer",
        settingsSafetyConfirmBeforeDeletingPage: "Confirmer avant de supprimer une page",
        settingsSevenZipPath: "Chemin de 7-Zip :",
        settingsVerifySevenZip: "Vérifier 7-Zip",
        settingsSupportedArchiveFormats: "Formats d'archive pris en charge :",
        settingsSupportedImageFormats: "Formats d'image pris en charge :",
        settingsSupportedDocumentFormats: "Formats de document pris en charge :",
        settingsLibraryDataLocation: "Emplacement des données de la bibliothèque :",
        settingsLibraryFolder: "Dossier de la bibliothèque :",
        settingsRuntimeFolder: "Dossier d'exécution :",
        settingsCheckStorageAccess: "Vérifier l'accès au stockage",
        settingsChecking: "Vérification...",
        settingsMoveLibraryData: "Déplacer les données de la bibliothèque :",
        settingsNoDestinationSelected: "Aucune destination sélectionnée",
        settingsScheduledAfterRestart: "Planifié après redémarrage.",
        settingsRelocationHint: "Le transfert s'exécutera après le redémarrage de l'application et peut prendre du temps selon la taille de la bibliothèque. Choisis un dossier vide.",
        sidebarQuickFilterLastImport: "Dernière importation",
        sidebarQuickFilterFavorites: "Favoris",
        sidebarQuickFilterBookmarks: "Marque-pages",
        sidebarLibrarySection: "Bibliothèque",
        sidebarMenuAddIssues: "Ajouter des numéros",
        sidebarMenuBulkEdit: "Modification groupée",
        sidebarMenuEditSeries: "Modifier la série",
        sidebarMenuMergeIntoSeries: "Fusionner dans une série",
        sidebarMenuShowFolder: "Afficher le dossier",
        sidebarMenuDeleteFiles: "Supprimer les fichiers",
        sidebarMenuDeleteSelected: "Supprimer la sélection",
        sidebarDropZoneTitle: "Dépose des archives de BD\ndans ta bibliothèque",
        sidebarDropZoneSubtitleLineOne: "Archives prises en charge",
        sidebarDropZoneSubtitleLineTwoPrefix: "et ",
        sidebarDropZoneSubtitleLink: "autres fichiers pris en charge",
        sidebarDropNoLocalFiles: "Le dépôt ne contient aucun fichier local.",
        sidebarDropNoSupportedSources: "Le dépôt ne contient aucune source de BD prise en charge.",
        topMenuFile: "Fichier",
        topMenuHelp: "Aide",
        topMenuAddFiles: "Ajouter des fichiers",
        topMenuAddFolder: "Ajouter un dossier",
        topMenuSettings: "Paramètres",
        topMenuExit: "Quitter",
        topMenuQuickTour: "Visite rapide",
        topMenuWhatsNew: "Nouveautés",
        topMenuViewHelp: "Voir l'aide",
        topMenuAbout: "À propos",
        navigationContinueReadingTitle: "Continuer la lecture",
        navigationNextUnreadTitle: "Prochain non lu",
        quickFilterLastImportedIssuesTitle: "Numéros importés récemment",
        quickFilterFavoriteIssuesTitle: "Numéros favoris",
        quickFilterBookmarkedIssuesTitle: "Numéros avec marque-page",
        quickFilterLastImportedEmpty: "Aucune importation récente",
        quickFilterFavoriteEmpty: "Aucun numéro favori",
        quickFilterBookmarkedEmpty: "Aucun numéro avec marque-page"
    },
    ja: {
        commonOk: "OK",
        commonCancel: "キャンセル",
        commonOpen: "開く",
        commonChoose: "選択",
        commonChange: "変更",
        commonUpload: "アップロード",
        commonCheck: "確認",
        commonReset: "リセット",
        commonRetry: "再試行",
        commonRetrying: "再試行中...",
        commonSkip: "スキップ",
        commonSkipAll: "すべてスキップ",
        commonReplaceAll: "すべて置換",
        commonDelete: "削除",
        commonWorking: "処理中...",
        commonClose: "閉じる",
        popupActionErrorTitle: "操作エラー",
        popupIssueArchiveUnavailableTitle: "号のアーカイブを利用できません",
        popupSettingsTitle: "設定",
        popupDeleteErrorTitle: "ファイルを削除できませんでした",
        popupDeleteRetrying: "削除を再試行中...",
        popupOpenFolder: "フォルダーを開く",
        popupImportErrorsTitle: "インポートエラー",
        popupImportErrorsIntro: "これらのアーカイブはインポートされませんでした。理由を確認し、修正後に再試行してください。",
        popupImportConflictTitle: "号は既に存在します",
        popupImportConflictMessage: "このアーカイブはライブラリ内の既存の号と一致します。操作を選択してください:",
        popupImportConflictKeepCurrent: "現在のものを保持",
        popupImportConflictReplace: "置換",
        popupIncomingArchive: "取り込みアーカイブ:",
        popupExistingRecord: "既存の記録:",
        popupSystemPrefix: "システム: ",
        importProgressTitleCancelling: "インポートをキャンセル中",
        importProgressTitleInProgress: "インポート中",
        importProgressCleanupProgress: "クリーンアップの進行状況",
        importProgressCurrentFile: "現在のファイル",
        importProgressCleaningImportedItems: "インポート済み項目をクリーンアップ中...",
        importProgressWaitingSafeStop: "安全な停止を待機中...",
        importProgressPreparingImport: "インポートを準備中...",
        importProgressFinalizing: "完了処理中...",
        importProgressCleaningUp: "クリーンアップ中...",
        importProgressCancelling: "キャンセル中...",
        importConflictRestoreTitle: "既存の号を復元しますか?",
        importConflictPossibleDuplicateTitle: "重複の可能性が見つかりました",
        importConflictSuspiciousMatchTitle: "疑わしい一致が見つかりました",
        importConflictRestoreMessage: "このアーカイブはこのシリーズ内の削除済みの号に近いですが、完全一致ではありません。その号を復元するか、新しい号としてインポートしてください:",
        importConflictPossibleDuplicateMessage: "ライブラリ内の同じ号のようですが、アーカイブは完全なファイル一致ではありません。既存ファイルを置換するか、新しい号としてインポートしてください:",
        importConflictSuspiciousMatchMessage: "既存の号に関連している可能性がありますが、一致は弱いです。新しい号としてインポートするか、このファイルをスキップしてください:",
        importConflictImportAsNew: "新規としてインポート",
        importConflictRestoreExisting: "既存を復元",
        importConflictReplaceExisting: "既存を置換",
        updateAvailableTitle: "アップデートがあります",
        updateAvailablePatchLabel: "パッチ {version}",
        updateAvailableReleaseNotesFallback: "このアップデートのリリースノートがあります。",
        updateAvailableLater: "後で",
        updateAvailableDownload: "アップデートをダウンロード",
        updateDownloadTitle: "アップデートをダウンロード中",
        updateDownloadFailed: "ダウンロードに失敗しました",
        updateDownloadTimedOut: "アップデートのダウンロードは完了前にタイムアウトしました。",
        updateDownloadInstall: "アップデートをインストール",
        updateDownloadActionTitle: "アップデートのダウンロード",
        updateDownloadNoLink: "このリリースにはアップデートのダウンロードリンクがありません。",
        updateInstallActionTitle: "アップデートをインストール",
        updateInstallHelperStartFailed: "Comic Pile はアップデートヘルパーを開始できませんでした。",
        settingsResetToDefault: "設定を既定値に戻す",
        settingsSevenZipUnavailable: "7-Zip を利用できません。",
        settingsImportArchivesSection: "インポートとアーカイブ",
        settingsLibraryDataSection: "ライブラリとデータ",
        settingsGeneralSection: "一般",
        settingsReaderSection: "リーダー",
        settingsAppearanceSection: "外観",
        settingsSafetySection: "安全性",
        settingsGeneralAutomaticallyCheckForUpdates: "更新を自動的に確認",
        settingsGeneralAppLanguage: "アプリの言語",
        settingsGeneralOpenReaderFullscreenByDefault: "既定でリーダーを全画面で開く",
        settingsGeneralAfterImport: "インポート後:",
        settingsGeneralDefaultViewAfterLaunch: "起動後の既定ビュー:",
        settingsReaderDefaultReadingMode: "既定の読書モード",
        settingsReaderRememberLastReaderMode: "最後のリーダーモードを記憶",
        settingsReaderMagnifierSize: "拡大鏡のサイズ",
        settingsReaderPageEdgeBehavior: "ページ端の動作",
        settingsReaderAutoOpenBookmarkedPage: "最後のページではなくブックマークページを開く",
        settingsReaderShowActionNotifications: "リーダーで操作通知を表示",
        settingsAppearanceCoverGridBackground: "表紙グリッドの背景",
        settingsAppearanceUseBuiltInBackground: "内蔵の表紙グリッド背景を使用",
        settingsAppearanceCustomShort: "カスタム",
        settingsAppearanceGridDensity: "グリッド密度",
        settingsAppearanceShowHeroBlock: "ヒーローブロックを表示",
        settingsAppearanceShowBookmarkRibbon: "表紙にブックマークリボンを表示",
        settingsSafetyConfirmBeforeDeletingFiles: "ファイル削除前に確認",
        settingsSafetyConfirmBeforeDeletingSeries: "シリーズ削除前に確認",
        settingsSafetyConfirmBeforeReplace: "置換前に確認",
        settingsSafetyConfirmBeforeDeletingPage: "ページ削除前に確認",
        settingsSevenZipPath: "7-Zip のパス:",
        settingsVerifySevenZip: "7-Zip を確認",
        settingsSupportedArchiveFormats: "対応アーカイブ形式:",
        settingsSupportedImageFormats: "対応画像形式:",
        settingsSupportedDocumentFormats: "対応ドキュメント形式:",
        settingsLibraryDataLocation: "ライブラリデータの場所:",
        settingsLibraryFolder: "ライブラリフォルダー:",
        settingsRuntimeFolder: "ランタイムフォルダー:",
        settingsCheckStorageAccess: "ストレージアクセスを確認",
        settingsChecking: "確認中...",
        settingsMoveLibraryData: "ライブラリデータを移動:",
        settingsNoDestinationSelected: "移動先が選択されていません",
        settingsScheduledAfterRestart: "再起動後に実行されます。",
        settingsRelocationHint: "転送はアプリ再起動後に実行され、ライブラリのサイズによって時間がかかる場合があります。空のフォルダーを選択してください。",
        sidebarQuickFilterLastImport: "最新のインポート",
        sidebarQuickFilterFavorites: "お気に入り",
        sidebarQuickFilterBookmarks: "ブックマーク",
        sidebarLibrarySection: "ライブラリ",
        sidebarMenuAddIssues: "号を追加",
        sidebarMenuBulkEdit: "一括編集",
        sidebarMenuEditSeries: "シリーズを編集",
        sidebarMenuMergeIntoSeries: "シリーズに結合",
        sidebarMenuShowFolder: "フォルダーを表示",
        sidebarMenuDeleteFiles: "ファイルを削除",
        sidebarMenuDeleteSelected: "選択項目を削除",
        sidebarDropZoneTitle: "コミックアーカイブを\nライブラリにドロップ",
        sidebarDropZoneSubtitleLineOne: "対応アーカイブ",
        sidebarDropZoneSubtitleLineTwoPrefix: "と ",
        sidebarDropZoneSubtitleLink: "その他の対応ファイル",
        sidebarDropNoLocalFiles: "ドロップにローカルファイルが含まれていません。",
        sidebarDropNoSupportedSources: "ドロップに対応するコミックソースが含まれていません。",
        topMenuFile: "ファイル",
        topMenuHelp: "ヘルプ",
        topMenuAddFiles: "ファイルを追加",
        topMenuAddFolder: "フォルダーを追加",
        topMenuSettings: "設定",
        topMenuExit: "終了",
        topMenuQuickTour: "クイックツアー",
        topMenuWhatsNew: "新機能",
        topMenuViewHelp: "ヘルプを表示",
        topMenuAbout: "このアプリについて",
        navigationContinueReadingTitle: "読書を続ける",
        navigationNextUnreadTitle: "次の未読",
        quickFilterLastImportedIssuesTitle: "最近インポートした号",
        quickFilterFavoriteIssuesTitle: "お気に入りの号",
        quickFilterBookmarkedIssuesTitle: "ブックマーク付きの号",
        quickFilterLastImportedEmpty: "最近のインポートはまだありません",
        quickFilterFavoriteEmpty: "お気に入りの号はまだありません",
        quickFilterBookmarkedEmpty: "ブックマーク付きの号はまだありません"
    },
    ko: {
        commonOk: "확인",
        commonCancel: "취소",
        commonOpen: "열기",
        commonChoose: "선택",
        commonChange: "변경",
        commonUpload: "업로드",
        commonCheck: "확인",
        commonReset: "초기화",
        commonRetry: "다시 시도",
        commonRetrying: "다시 시도 중...",
        commonSkip: "건너뛰기",
        commonSkipAll: "모두 건너뛰기",
        commonReplaceAll: "모두 교체",
        commonDelete: "삭제",
        commonWorking: "작업 중...",
        commonClose: "닫기",
        popupActionErrorTitle: "작업 오류",
        popupIssueArchiveUnavailableTitle: "이슈 아카이브를 사용할 수 없음",
        popupSettingsTitle: "설정",
        popupDeleteErrorTitle: "파일을 제거할 수 없습니다",
        popupDeleteRetrying: "삭제 다시 시도 중...",
        popupOpenFolder: "폴더 열기",
        popupImportErrorsTitle: "가져오기 오류",
        popupImportErrorsIntro: "이 아카이브는 가져오지 못했습니다. 이유를 확인하고 수정한 뒤 다시 시도하세요.",
        popupImportConflictTitle: "이슈가 이미 있습니다",
        popupImportConflictMessage: "이 아카이브는 라이브러리의 기존 이슈와 일치합니다. 수행할 작업을 선택하세요:",
        popupImportConflictKeepCurrent: "현재 항목 유지",
        popupImportConflictReplace: "교체",
        popupIncomingArchive: "들어오는 아카이브:",
        popupExistingRecord: "기존 기록:",
        popupSystemPrefix: "시스템: ",
        importProgressTitleCancelling: "가져오기 취소 중",
        importProgressTitleInProgress: "가져오기 진행 중",
        importProgressCleanupProgress: "정리 진행률",
        importProgressCurrentFile: "현재 파일",
        importProgressCleaningImportedItems: "가져온 항목 정리 중...",
        importProgressWaitingSafeStop: "안전한 중지를 기다리는 중...",
        importProgressPreparingImport: "가져오기 준비 중...",
        importProgressFinalizing: "마무리 중...",
        importProgressCleaningUp: "정리 중...",
        importProgressCancelling: "취소 중...",
        importConflictRestoreTitle: "기존 이슈를 복원할까요?",
        importConflictPossibleDuplicateTitle: "중복 가능성 발견",
        importConflictSuspiciousMatchTitle: "의심스러운 일치 발견",
        importConflictRestoreMessage: "이 아카이브는 이 시리즈에서 삭제된 이슈와 비슷하지만 정확히 일치하지 않습니다. 해당 이슈를 복원하거나 새 이슈로 가져오세요:",
        importConflictPossibleDuplicateMessage: "라이브러리의 같은 이슈처럼 보이지만 아카이브가 정확히 같은 파일은 아닙니다. 기존 파일을 교체하거나 새 이슈로 가져오세요:",
        importConflictSuspiciousMatchMessage: "기존 이슈와 관련이 있을 수 있지만 일치도가 낮습니다. 새 이슈로 가져오거나 이 파일을 건너뛰세요:",
        importConflictImportAsNew: "새 항목으로 가져오기",
        importConflictRestoreExisting: "기존 항목 복원",
        importConflictReplaceExisting: "기존 항목 교체",
        updateAvailableTitle: "업데이트 가능",
        updateAvailablePatchLabel: "패치 {version}",
        updateAvailableReleaseNotesFallback: "이 업데이트의 릴리스 노트를 사용할 수 있습니다.",
        updateAvailableLater: "나중에",
        updateAvailableDownload: "업데이트 다운로드",
        updateDownloadTitle: "업데이트 다운로드 중",
        updateDownloadFailed: "다운로드 실패",
        updateDownloadTimedOut: "업데이트 다운로드가 완료되기 전에 시간 초과되었습니다.",
        updateDownloadInstall: "업데이트 설치",
        updateDownloadActionTitle: "업데이트 다운로드",
        updateDownloadNoLink: "이 릴리스에 사용할 수 있는 업데이트 다운로드 링크가 없습니다.",
        updateInstallActionTitle: "업데이트 설치",
        updateInstallHelperStartFailed: "Comic Pile이 업데이트 도우미를 시작할 수 없습니다.",
        settingsResetToDefault: "설정을 기본값으로 초기화",
        settingsSevenZipUnavailable: "7-Zip을 사용할 수 없습니다.",
        settingsImportArchivesSection: "가져오기 및 아카이브",
        settingsLibraryDataSection: "라이브러리 및 데이터",
        settingsGeneralSection: "일반",
        settingsReaderSection: "리더",
        settingsAppearanceSection: "모양",
        settingsSafetySection: "안전",
        settingsGeneralAutomaticallyCheckForUpdates: "업데이트 자동 확인",
        settingsGeneralAppLanguage: "앱 언어",
        settingsGeneralOpenReaderFullscreenByDefault: "기본적으로 리더를 전체 화면으로 열기",
        settingsGeneralAfterImport: "가져온 후:",
        settingsGeneralDefaultViewAfterLaunch: "실행 후 기본 보기:",
        settingsReaderDefaultReadingMode: "기본 읽기 모드",
        settingsReaderRememberLastReaderMode: "마지막 리더 모드 기억",
        settingsReaderMagnifierSize: "돋보기 크기",
        settingsReaderPageEdgeBehavior: "페이지 가장자리 동작",
        settingsReaderAutoOpenBookmarkedPage: "마지막 페이지 대신 북마크한 페이지 열기",
        settingsReaderShowActionNotifications: "리더에서 동작 알림 표시",
        settingsAppearanceCoverGridBackground: "표지 그리드 배경",
        settingsAppearanceUseBuiltInBackground: "내장 표지 그리드 배경 사용",
        settingsAppearanceCustomShort: "사용자 지정",
        settingsAppearanceGridDensity: "그리드 밀도",
        settingsAppearanceShowHeroBlock: "히어로 블록 표시",
        settingsAppearanceShowBookmarkRibbon: "표지에 북마크 리본 표시",
        settingsSafetyConfirmBeforeDeletingFiles: "파일 삭제 전 확인",
        settingsSafetyConfirmBeforeDeletingSeries: "시리즈 삭제 전 확인",
        settingsSafetyConfirmBeforeReplace: "교체 전 확인",
        settingsSafetyConfirmBeforeDeletingPage: "페이지 삭제 전 확인",
        settingsSevenZipPath: "7-Zip 경로:",
        settingsVerifySevenZip: "7-Zip 확인",
        settingsSupportedArchiveFormats: "지원되는 아카이브 형식:",
        settingsSupportedImageFormats: "지원되는 이미지 형식:",
        settingsSupportedDocumentFormats: "지원되는 문서 형식:",
        settingsLibraryDataLocation: "라이브러리 데이터 위치:",
        settingsLibraryFolder: "라이브러리 폴더:",
        settingsRuntimeFolder: "런타임 폴더:",
        settingsCheckStorageAccess: "저장소 접근 확인",
        settingsChecking: "확인 중...",
        settingsMoveLibraryData: "라이브러리 데이터 이동:",
        settingsNoDestinationSelected: "선택된 대상 없음",
        settingsScheduledAfterRestart: "재시작 후 예약됨.",
        settingsRelocationHint: "전송은 앱을 재시작한 뒤 실행되며 라이브러리 크기에 따라 시간이 걸릴 수 있습니다. 빈 폴더를 선택하세요.",
        sidebarQuickFilterLastImport: "마지막 가져오기",
        sidebarQuickFilterFavorites: "즐겨찾기",
        sidebarQuickFilterBookmarks: "북마크",
        sidebarLibrarySection: "라이브러리",
        sidebarMenuAddIssues: "이슈 추가",
        sidebarMenuBulkEdit: "일괄 편집",
        sidebarMenuEditSeries: "시리즈 편집",
        sidebarMenuMergeIntoSeries: "시리즈로 병합",
        sidebarMenuShowFolder: "폴더 보기",
        sidebarMenuDeleteFiles: "파일 삭제",
        sidebarMenuDeleteSelected: "선택 항목 삭제",
        sidebarDropZoneTitle: "코믹 아카이브를\n라이브러리에 드롭",
        sidebarDropZoneSubtitleLineOne: "지원되는 아카이브",
        sidebarDropZoneSubtitleLineTwoPrefix: "및 ",
        sidebarDropZoneSubtitleLink: "기타 지원 파일",
        sidebarDropNoLocalFiles: "드롭한 항목에 로컬 파일이 없습니다.",
        sidebarDropNoSupportedSources: "드롭한 항목에 지원되는 코믹 소스가 없습니다.",
        topMenuFile: "파일",
        topMenuHelp: "도움말",
        topMenuAddFiles: "파일 추가",
        topMenuAddFolder: "폴더 추가",
        topMenuSettings: "설정",
        topMenuExit: "종료",
        topMenuQuickTour: "빠른 둘러보기",
        topMenuWhatsNew: "새로운 기능",
        topMenuViewHelp: "도움말 보기",
        topMenuAbout: "정보",
        navigationContinueReadingTitle: "이어서 읽기",
        navigationNextUnreadTitle: "다음 안 읽은 항목",
        quickFilterLastImportedIssuesTitle: "최근 가져온 이슈",
        quickFilterFavoriteIssuesTitle: "즐겨찾기 이슈",
        quickFilterBookmarkedIssuesTitle: "북마크한 이슈",
        quickFilterLastImportedEmpty: "아직 최근 가져오기가 없습니다",
        quickFilterFavoriteEmpty: "아직 즐겨찾기 이슈가 없습니다",
        quickFilterBookmarkedEmpty: "아직 북마크한 이슈가 없습니다"
    },
    "zh-Hans": {
        commonOk: "确定",
        commonCancel: "取消",
        commonOpen: "打开",
        commonChoose: "选择",
        commonChange: "更改",
        commonUpload: "上传",
        commonCheck: "检查",
        commonReset: "重置",
        commonRetry: "重试",
        commonRetrying: "正在重试...",
        commonSkip: "跳过",
        commonSkipAll: "全部跳过",
        commonReplaceAll: "全部替换",
        commonDelete: "删除",
        commonWorking: "正在处理...",
        commonClose: "关闭",
        popupActionErrorTitle: "操作错误",
        popupIssueArchiveUnavailableTitle: "期刊压缩包不可用",
        popupSettingsTitle: "设置",
        popupDeleteErrorTitle: "无法移除文件",
        popupDeleteRetrying: "正在重试删除...",
        popupOpenFolder: "打开文件夹",
        popupImportErrorsTitle: "导入错误",
        popupImportErrorsIntro: "这些压缩包未导入。请查看原因并修复后重试。",
        popupImportConflictTitle: "期刊已存在",
        popupImportConflictMessage: "此压缩包与资料库中的现有期刊匹配。请选择操作:",
        popupImportConflictKeepCurrent: "保留当前",
        popupImportConflictReplace: "替换",
        popupIncomingArchive: "传入压缩包:",
        popupExistingRecord: "现有记录:",
        popupSystemPrefix: "系统: ",
        importProgressTitleCancelling: "正在取消导入",
        importProgressTitleInProgress: "正在导入",
        importProgressCleanupProgress: "清理进度",
        importProgressCurrentFile: "当前文件",
        importProgressCleaningImportedItems: "正在清理已导入项目...",
        importProgressWaitingSafeStop: "正在等待安全停止...",
        importProgressPreparingImport: "正在准备导入...",
        importProgressFinalizing: "正在完成...",
        importProgressCleaningUp: "正在清理...",
        importProgressCancelling: "正在取消...",
        importConflictRestoreTitle: "恢复现有期刊？",
        importConflictPossibleDuplicateTitle: "发现可能重复项",
        importConflictSuspiciousMatchTitle: "发现可疑匹配",
        importConflictRestoreMessage: "此压缩包看起来接近此系列中已删除的期刊，但并非完全匹配。恢复该期刊或作为新期刊导入:",
        importConflictPossibleDuplicateMessage: "这看起来像资料库中的同一期刊，但压缩包不是完全相同的文件。替换现有文件或作为新期刊导入:",
        importConflictSuspiciousMatchMessage: "这可能与现有期刊相关，但匹配度较弱。作为新期刊导入或跳过此文件:",
        importConflictImportAsNew: "作为新期刊导入",
        importConflictRestoreExisting: "恢复现有期刊",
        importConflictReplaceExisting: "替换现有期刊",
        updateAvailableTitle: "有可用更新",
        updateAvailablePatchLabel: "补丁 {version}",
        updateAvailableReleaseNotesFallback: "此更新有可用的发行说明。",
        updateAvailableLater: "稍后",
        updateAvailableDownload: "下载更新",
        updateDownloadTitle: "正在下载更新",
        updateDownloadFailed: "下载失败",
        updateDownloadTimedOut: "更新下载在完成前超时。",
        updateDownloadInstall: "安装更新",
        updateDownloadActionTitle: "更新下载",
        updateDownloadNoLink: "此版本没有可用的更新下载链接。",
        updateInstallActionTitle: "安装更新",
        updateInstallHelperStartFailed: "Comic Pile 无法启动更新助手。",
        settingsResetToDefault: "将设置重置为默认值",
        settingsSevenZipUnavailable: "7-Zip 不可用。",
        settingsImportArchivesSection: "导入与压缩包",
        settingsLibraryDataSection: "资料库与数据",
        settingsGeneralSection: "常规",
        settingsReaderSection: "阅读器",
        settingsAppearanceSection: "外观",
        settingsSafetySection: "安全",
        settingsGeneralAutomaticallyCheckForUpdates: "自动检查更新",
        settingsGeneralAppLanguage: "应用语言",
        settingsGeneralOpenReaderFullscreenByDefault: "默认以全屏打开阅读器",
        settingsGeneralAfterImport: "导入后:",
        settingsGeneralDefaultViewAfterLaunch: "启动后的默认视图:",
        settingsReaderDefaultReadingMode: "默认阅读模式",
        settingsReaderRememberLastReaderMode: "记住上次的阅读器模式",
        settingsReaderMagnifierSize: "放大镜大小",
        settingsReaderPageEdgeBehavior: "页面边缘行为",
        settingsReaderAutoOpenBookmarkedPage: "打开书签页而不是最后一页",
        settingsReaderShowActionNotifications: "在阅读器中显示操作通知",
        settingsAppearanceCoverGridBackground: "封面网格背景",
        settingsAppearanceUseBuiltInBackground: "使用内置封面网格背景",
        settingsAppearanceCustomShort: "自定义",
        settingsAppearanceGridDensity: "网格密度",
        settingsAppearanceShowHeroBlock: "显示主视觉区块",
        settingsAppearanceShowBookmarkRibbon: "在封面上显示书签色带",
        settingsSafetyConfirmBeforeDeletingFiles: "删除文件前确认",
        settingsSafetyConfirmBeforeDeletingSeries: "删除系列前确认",
        settingsSafetyConfirmBeforeReplace: "替换前确认",
        settingsSafetyConfirmBeforeDeletingPage: "删除页面前确认",
        settingsSevenZipPath: "7-Zip 路径:",
        settingsVerifySevenZip: "验证 7-Zip",
        settingsSupportedArchiveFormats: "支持的压缩包格式:",
        settingsSupportedImageFormats: "支持的图片格式:",
        settingsSupportedDocumentFormats: "支持的文档格式:",
        settingsLibraryDataLocation: "资料库数据位置:",
        settingsLibraryFolder: "资料库文件夹:",
        settingsRuntimeFolder: "运行时文件夹:",
        settingsCheckStorageAccess: "检查存储访问权限",
        settingsChecking: "正在检查...",
        settingsMoveLibraryData: "移动资料库数据:",
        settingsNoDestinationSelected: "未选择目标位置",
        settingsScheduledAfterRestart: "将在重启后执行。",
        settingsRelocationHint: "传输将在应用重启后执行，耗时取决于资料库大小。请选择一个空文件夹。",
        sidebarQuickFilterLastImport: "上次导入",
        sidebarQuickFilterFavorites: "收藏",
        sidebarQuickFilterBookmarks: "书签",
        sidebarLibrarySection: "资料库",
        sidebarMenuAddIssues: "添加期刊",
        sidebarMenuBulkEdit: "批量编辑",
        sidebarMenuEditSeries: "编辑系列",
        sidebarMenuMergeIntoSeries: "合并到系列",
        sidebarMenuShowFolder: "显示文件夹",
        sidebarMenuDeleteFiles: "删除文件",
        sidebarMenuDeleteSelected: "删除所选",
        sidebarDropZoneTitle: "将漫画压缩包拖放到\n你的资料库",
        sidebarDropZoneSubtitleLineOne: "支持的压缩包",
        sidebarDropZoneSubtitleLineTwoPrefix: "以及 ",
        sidebarDropZoneSubtitleLink: "其他支持的文件",
        sidebarDropNoLocalFiles: "拖放内容不包含本地文件。",
        sidebarDropNoSupportedSources: "拖放内容不包含支持的漫画来源。",
        topMenuFile: "文件",
        topMenuHelp: "帮助",
        topMenuAddFiles: "添加文件",
        topMenuAddFolder: "添加文件夹",
        topMenuSettings: "设置",
        topMenuExit: "退出",
        topMenuQuickTour: "快速导览",
        topMenuWhatsNew: "新增内容",
        topMenuViewHelp: "查看帮助",
        topMenuAbout: "关于",
        navigationContinueReadingTitle: "继续阅读",
        navigationNextUnreadTitle: "下一个未读",
        quickFilterLastImportedIssuesTitle: "最近导入的期刊",
        quickFilterFavoriteIssuesTitle: "收藏的期刊",
        quickFilterBookmarkedIssuesTitle: "带书签的期刊",
        quickFilterLastImportedEmpty: "还没有最近导入",
        quickFilterFavoriteEmpty: "还没有收藏的期刊",
        quickFilterBookmarkedEmpty: "还没有带书签的期刊"
    },
    "zh-Hant": {
        commonOk: "確定",
        commonCancel: "取消",
        commonOpen: "開啟",
        commonChoose: "選擇",
        commonChange: "更改",
        commonUpload: "上傳",
        commonCheck: "檢查",
        commonReset: "重設",
        commonRetry: "重試",
        commonRetrying: "正在重試...",
        commonSkip: "略過",
        commonSkipAll: "全部略過",
        commonReplaceAll: "全部取代",
        commonDelete: "刪除",
        commonWorking: "正在處理...",
        commonClose: "關閉",
        popupActionErrorTitle: "操作錯誤",
        popupIssueArchiveUnavailableTitle: "期刊壓縮檔無法使用",
        popupSettingsTitle: "設定",
        popupDeleteErrorTitle: "無法移除檔案",
        popupDeleteRetrying: "正在重試刪除...",
        popupOpenFolder: "開啟資料夾",
        popupImportErrorsTitle: "匯入錯誤",
        popupImportErrorsIntro: "這些壓縮檔未匯入。請查看原因並修正後重試。",
        popupImportConflictTitle: "期刊已存在",
        popupImportConflictMessage: "此壓縮檔與資料庫中的現有期刊相符。請選擇操作:",
        popupImportConflictKeepCurrent: "保留目前",
        popupImportConflictReplace: "取代",
        popupIncomingArchive: "傳入壓縮檔:",
        popupExistingRecord: "現有記錄:",
        popupSystemPrefix: "系統: ",
        importProgressTitleCancelling: "正在取消匯入",
        importProgressTitleInProgress: "正在匯入",
        importProgressCleanupProgress: "清理進度",
        importProgressCurrentFile: "目前檔案",
        importProgressCleaningImportedItems: "正在清理已匯入項目...",
        importProgressWaitingSafeStop: "正在等待安全停止...",
        importProgressPreparingImport: "正在準備匯入...",
        importProgressFinalizing: "正在完成...",
        importProgressCleaningUp: "正在清理...",
        importProgressCancelling: "正在取消...",
        importConflictRestoreTitle: "要還原現有期刊嗎？",
        importConflictPossibleDuplicateTitle: "發現可能重複項目",
        importConflictSuspiciousMatchTitle: "發現可疑相符項目",
        importConflictRestoreMessage: "此壓縮檔看起來接近此系列中已刪除的期刊，但並非完全相符。還原該期刊或作為新期刊匯入:",
        importConflictPossibleDuplicateMessage: "這看起來像資料庫中的同一期刊，但壓縮檔不是完全相同的檔案。取代現有檔案或作為新期刊匯入:",
        importConflictSuspiciousMatchMessage: "這可能與現有期刊相關，但相符程度較低。作為新期刊匯入或略過此檔案:",
        importConflictImportAsNew: "作為新期刊匯入",
        importConflictRestoreExisting: "還原現有期刊",
        importConflictReplaceExisting: "取代現有期刊",
        updateAvailableTitle: "有可用更新",
        updateAvailablePatchLabel: "修補版 {version}",
        updateAvailableReleaseNotesFallback: "此更新有可用的版本說明。",
        updateAvailableLater: "稍後",
        updateAvailableDownload: "下載更新",
        updateDownloadTitle: "正在下載更新",
        updateDownloadFailed: "下載失敗",
        updateDownloadTimedOut: "更新下載在完成前逾時。",
        updateDownloadInstall: "安裝更新",
        updateDownloadActionTitle: "更新下載",
        updateDownloadNoLink: "此版本沒有可用的更新下載連結。",
        updateInstallActionTitle: "安裝更新",
        updateInstallHelperStartFailed: "Comic Pile 無法啟動更新助手。",
        settingsResetToDefault: "將設定重設為預設值",
        settingsSevenZipUnavailable: "7-Zip 無法使用。",
        settingsImportArchivesSection: "匯入與壓縮檔",
        settingsLibraryDataSection: "資料庫與資料",
        settingsGeneralSection: "一般",
        settingsReaderSection: "閱讀器",
        settingsAppearanceSection: "外觀",
        settingsSafetySection: "安全性",
        settingsGeneralAutomaticallyCheckForUpdates: "自動檢查更新",
        settingsGeneralAppLanguage: "應用程式語言",
        settingsGeneralOpenReaderFullscreenByDefault: "預設以全螢幕開啟閱讀器",
        settingsGeneralAfterImport: "匯入後:",
        settingsGeneralDefaultViewAfterLaunch: "啟動後的預設檢視:",
        settingsReaderDefaultReadingMode: "預設閱讀模式",
        settingsReaderRememberLastReaderMode: "記住上次的閱讀器模式",
        settingsReaderMagnifierSize: "放大鏡大小",
        settingsReaderPageEdgeBehavior: "頁面邊緣行為",
        settingsReaderAutoOpenBookmarkedPage: "開啟書籤頁而不是最後一頁",
        settingsReaderShowActionNotifications: "在閱讀器中顯示操作通知",
        settingsAppearanceCoverGridBackground: "封面網格背景",
        settingsAppearanceUseBuiltInBackground: "使用內建封面網格背景",
        settingsAppearanceCustomShort: "自訂",
        settingsAppearanceGridDensity: "網格密度",
        settingsAppearanceShowHeroBlock: "顯示主視覺區塊",
        settingsAppearanceShowBookmarkRibbon: "在封面上顯示書籤緞帶",
        settingsSafetyConfirmBeforeDeletingFiles: "刪除檔案前確認",
        settingsSafetyConfirmBeforeDeletingSeries: "刪除系列前確認",
        settingsSafetyConfirmBeforeReplace: "取代前確認",
        settingsSafetyConfirmBeforeDeletingPage: "刪除頁面前確認",
        settingsSevenZipPath: "7-Zip 路徑:",
        settingsVerifySevenZip: "驗證 7-Zip",
        settingsSupportedArchiveFormats: "支援的壓縮檔格式:",
        settingsSupportedImageFormats: "支援的圖片格式:",
        settingsSupportedDocumentFormats: "支援的文件格式:",
        settingsLibraryDataLocation: "資料庫資料位置:",
        settingsLibraryFolder: "資料庫資料夾:",
        settingsRuntimeFolder: "執行階段資料夾:",
        settingsCheckStorageAccess: "檢查儲存空間存取權",
        settingsChecking: "正在檢查...",
        settingsMoveLibraryData: "移動資料庫資料:",
        settingsNoDestinationSelected: "未選擇目的地",
        settingsScheduledAfterRestart: "將在重新啟動後執行。",
        settingsRelocationHint: "傳輸會在應用程式重新啟動後執行，所需時間取決於資料庫大小。請選擇空資料夾。",
        sidebarQuickFilterLastImport: "上次匯入",
        sidebarQuickFilterFavorites: "收藏",
        sidebarQuickFilterBookmarks: "書籤",
        sidebarLibrarySection: "資料庫",
        sidebarMenuAddIssues: "新增期刊",
        sidebarMenuBulkEdit: "批次編輯",
        sidebarMenuEditSeries: "編輯系列",
        sidebarMenuMergeIntoSeries: "合併到系列",
        sidebarMenuShowFolder: "顯示資料夾",
        sidebarMenuDeleteFiles: "刪除檔案",
        sidebarMenuDeleteSelected: "刪除所選",
        sidebarDropZoneTitle: "將漫畫壓縮檔拖放到\n你的資料庫",
        sidebarDropZoneSubtitleLineOne: "支援的壓縮檔",
        sidebarDropZoneSubtitleLineTwoPrefix: "以及 ",
        sidebarDropZoneSubtitleLink: "其他支援的檔案",
        sidebarDropNoLocalFiles: "拖放內容不包含本機檔案。",
        sidebarDropNoSupportedSources: "拖放內容不包含支援的漫畫來源。",
        topMenuFile: "檔案",
        topMenuHelp: "說明",
        topMenuAddFiles: "新增檔案",
        topMenuAddFolder: "新增資料夾",
        topMenuSettings: "設定",
        topMenuExit: "結束",
        topMenuQuickTour: "快速導覽",
        topMenuWhatsNew: "新增內容",
        topMenuViewHelp: "查看說明",
        topMenuAbout: "關於",
        navigationContinueReadingTitle: "繼續閱讀",
        navigationNextUnreadTitle: "下一個未讀",
        quickFilterLastImportedIssuesTitle: "最近匯入的期刊",
        quickFilterFavoriteIssuesTitle: "收藏的期刊",
        quickFilterBookmarkedIssuesTitle: "帶書籤的期刊",
        quickFilterLastImportedEmpty: "還沒有最近匯入",
        quickFilterFavoriteEmpty: "還沒有收藏的期刊",
        quickFilterBookmarkedEmpty: "還沒有帶書籤的期刊"
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
var commonDelete = t("commonDelete")
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

var importProgressTitleCancelling = t("importProgressTitleCancelling")
var importProgressTitleInProgress = t("importProgressTitleInProgress")
var importProgressCleanupProgress = t("importProgressCleanupProgress")
var importProgressCurrentFile = t("importProgressCurrentFile")
var importProgressCleaningImportedItems = t("importProgressCleaningImportedItems")
var importProgressWaitingSafeStop = t("importProgressWaitingSafeStop")
var importProgressPreparingImport = t("importProgressPreparingImport")
var importProgressFinalizing = t("importProgressFinalizing")
var importProgressCleaningUp = t("importProgressCleaningUp")
var importProgressCancelling = t("importProgressCancelling")
var importConflictRestoreTitle = t("importConflictRestoreTitle")
var importConflictPossibleDuplicateTitle = t("importConflictPossibleDuplicateTitle")
var importConflictSuspiciousMatchTitle = t("importConflictSuspiciousMatchTitle")
var importConflictRestoreMessage = t("importConflictRestoreMessage")
var importConflictPossibleDuplicateMessage = t("importConflictPossibleDuplicateMessage")
var importConflictSuspiciousMatchMessage = t("importConflictSuspiciousMatchMessage")
var importConflictImportAsNew = t("importConflictImportAsNew")
var importConflictRestoreExisting = t("importConflictRestoreExisting")
var importConflictReplaceExisting = t("importConflictReplaceExisting")
var updateAvailableTitle = t("updateAvailableTitle")
var updateAvailablePatchLabel = t("updateAvailablePatchLabel")
var updateAvailableReleaseNotesFallback = t("updateAvailableReleaseNotesFallback")
var updateAvailableLater = t("updateAvailableLater")
var updateAvailableDownload = t("updateAvailableDownload")
var updateDownloadTitle = t("updateDownloadTitle")
var updateDownloadFailed = t("updateDownloadFailed")
var updateDownloadTimedOut = t("updateDownloadTimedOut")
var updateDownloadInstall = t("updateDownloadInstall")
var updateDownloadActionTitle = t("updateDownloadActionTitle")
var updateDownloadNoLink = t("updateDownloadNoLink")
var updateInstallActionTitle = t("updateInstallActionTitle")
var updateInstallHelperStartFailed = t("updateInstallHelperStartFailed")

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
var settingsSafetyConfirmBeforeDeletingFiles = t("settingsSafetyConfirmBeforeDeletingFiles")
var settingsSafetyConfirmBeforeDeletingSeries = t("settingsSafetyConfirmBeforeDeletingSeries")
var settingsSafetyConfirmBeforeReplace = t("settingsSafetyConfirmBeforeReplace")
var settingsSafetyConfirmBeforeDeletingPage = t("settingsSafetyConfirmBeforeDeletingPage")

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

var topMenuFile = t("topMenuFile")
var topMenuHelp = t("topMenuHelp")
var topMenuAddFiles = t("topMenuAddFiles")
var topMenuAddFolder = t("topMenuAddFolder")
var topMenuSettings = t("topMenuSettings")
var topMenuExit = t("topMenuExit")
var topMenuQuickTour = t("topMenuQuickTour")
var topMenuWhatsNew = t("topMenuWhatsNew")
var topMenuViewHelp = t("topMenuViewHelp")
var topMenuAbout = t("topMenuAbout")

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
