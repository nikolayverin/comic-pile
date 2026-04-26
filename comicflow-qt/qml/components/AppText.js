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
        commonOpen: "Abrir",
        commonChoose: "Elegir",
        commonChange: "Cambiar",
        commonUpload: "Cargar",
        commonCheck: "Comprobar",
        commonReset: "Restablecer",
        popupSettingsTitle: "Configuración",
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
        settingsRelocationHint: "La transferencia se ejecutará después de reiniciar la aplicación y puede tardar según el tamaño de la biblioteca. Elige una carpeta vacía."
    },
    de: {
        commonOpen: "Öffnen",
        commonChoose: "Auswählen",
        commonChange: "Ändern",
        commonUpload: "Hochladen",
        commonCheck: "Prüfen",
        commonReset: "Zurücksetzen",
        popupSettingsTitle: "Einstellungen",
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
        settingsRelocationHint: "Die Übertragung wird nach dem Neustart der App ausgeführt und kann je nach Bibliotheksgröße dauern. Wähle einen leeren Ordner."
    },
    fr: {
        commonOpen: "Ouvrir",
        commonChoose: "Choisir",
        commonChange: "Modifier",
        commonUpload: "Importer",
        commonCheck: "Vérifier",
        commonReset: "Réinitialiser",
        popupSettingsTitle: "Paramètres",
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
        settingsRelocationHint: "Le transfert s'exécutera après le redémarrage de l'application et peut prendre du temps selon la taille de la bibliothèque. Choisis un dossier vide."
    },
    ja: {
        commonOpen: "開く",
        commonChoose: "選択",
        commonChange: "変更",
        commonUpload: "アップロード",
        commonCheck: "確認",
        commonReset: "リセット",
        popupSettingsTitle: "設定",
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
        settingsRelocationHint: "転送はアプリ再起動後に実行され、ライブラリのサイズによって時間がかかる場合があります。空のフォルダーを選択してください。"
    },
    ko: {
        commonOpen: "열기",
        commonChoose: "선택",
        commonChange: "변경",
        commonUpload: "업로드",
        commonCheck: "확인",
        commonReset: "초기화",
        popupSettingsTitle: "설정",
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
        settingsRelocationHint: "전송은 앱을 재시작한 뒤 실행되며 라이브러리 크기에 따라 시간이 걸릴 수 있습니다. 빈 폴더를 선택하세요."
    },
    "zh-Hans": {
        commonOpen: "打开",
        commonChoose: "选择",
        commonChange: "更改",
        commonUpload: "上传",
        commonCheck: "检查",
        commonReset: "重置",
        popupSettingsTitle: "设置",
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
        settingsRelocationHint: "传输将在应用重启后执行，耗时取决于资料库大小。请选择一个空文件夹。"
    },
    "zh-Hant": {
        commonOpen: "開啟",
        commonChoose: "選擇",
        commonChange: "更改",
        commonUpload: "上傳",
        commonCheck: "檢查",
        commonReset: "重設",
        popupSettingsTitle: "設定",
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
        settingsRelocationHint: "傳輸會在應用程式重新啟動後執行，所需時間取決於資料庫大小。請選擇空資料夾。"
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
