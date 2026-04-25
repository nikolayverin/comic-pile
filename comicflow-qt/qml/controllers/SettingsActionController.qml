import QtQuick
import "../components/AppErrorMapper.js" as AppErrorMapper
import "../components/AppSharedUtils.js" as AppSharedUtils
import "../components/AppText.js" as AppText

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var appSettingsControllerRef: null
    property var popupControllerRef: null
    property var startupControllerRef: null
    property var settingsDialogRef: null
    property bool libraryBackgroundImageMigrationInProgress: false

    readonly property int libraryBackgroundImageMaxBytes: 8 * 1024 * 1024
    readonly property int libraryBackgroundTileImageMaxBytes: 1 * 1024 * 1024

    function traceSettings(message) {
        const root = rootObject
        if (!root || typeof root.runtimeDebugLog !== "function") return
        root.runtimeDebugLog("settings-actions", String(message || ""))
    }

    function fileSizeBytes(pathValue) {
        const normalized = AppSharedUtils.normalizeImportPath(pathValue)
        if (!libraryModelRef || typeof libraryModelRef.fileSizeBytes !== "function") return 0
        const value = Number(libraryModelRef.fileSizeBytes(normalized))
        return Number.isFinite(value) && value > 0 ? value : 0
    }

    function looksLikeAbsoluteLocalPath(pathValue) {
        const normalized = String(pathValue || "").trim().replace(/\//g, "\\")
        return /^[A-Za-z]:\\/.test(normalized) || normalized.startsWith("\\\\")
    }

    function resolveLibraryBackgroundStoredPath(pathValue) {
        const storedPath = String(pathValue || "").trim()
        if (storedPath.length < 1) return ""
        if (libraryModelRef && typeof libraryModelRef.resolveStoredPathAgainstDataRoot === "function") {
            return String(libraryModelRef.resolveStoredPathAgainstDataRoot(storedPath) || "")
        }
        return storedPath
    }

    function showSettingsActionResultPayload(payload) {
        if (!popupControllerRef || typeof popupControllerRef.showMappedActionResult !== "function") return
        if (settingsDialogRef
                && settingsDialogRef.visible
                && typeof popupControllerRef.showMappedActionResultAbovePopup === "function") {
            popupControllerRef.showMappedActionResultAbovePopup(payload, settingsDialogRef)
            return
        }
        popupControllerRef.showMappedActionResult(payload)
    }

    function showSettingsError(messageText, detailsText, buttonText, actionKey, filePath, titleOverride) {
        showSettingsActionResultPayload(AppErrorMapper.defaultActionResultPayload(
            String(messageText || ""),
            String(titleOverride || AppText.popupActionErrorTitle),
            String(detailsText || ""),
            String(buttonText || ""),
            String(actionKey || ""),
            String(filePath || "")
        ))
    }

    function presentLibraryLoadError(messageText) {
        const message = String(messageText || "").trim()
        if (message.length < 1) return
        showSettingsActionResultPayload(AppErrorMapper.libraryLoadFailure(message))
    }

    function storeLibraryBackgroundImageSelection(sourcePath, showErrorPopup) {
        const candidatePath = String(sourcePath || "").trim()
        if (candidatePath.length < 1) return ""

        if (!libraryModelRef || typeof libraryModelRef.storeLibraryBackgroundImage !== "function") {
            if (showErrorPopup) {
                showSettingsError("Failed to save custom background image.")
            }
            traceSettings("background image store failed reason=model_unavailable")
            return ""
        }

        const result = libraryModelRef.storeLibraryBackgroundImage(candidatePath) || {}
        if (!Boolean(result.ok)) {
            if (showErrorPopup) {
                showSettingsError(String(result.error || "Failed to save custom background image."))
            }
            traceSettings(
                "background image store failed"
                + " file=" + AppSharedUtils.fileNameFromPath(candidatePath)
                + " reason=store_failed"
            )
            return ""
        }

        traceSettings(
            "background image store ok"
            + " file=" + AppSharedUtils.fileNameFromPath(candidatePath)
        )
        return String(result.storedPath || "")
    }

    function migrateLibraryBackgroundImageSettingIfNeeded() {
        if (libraryBackgroundImageMigrationInProgress) return

        const root = rootObject
        if (!root || !appSettingsControllerRef) return

        const storedPath = String(root.libraryBackgroundCustomImageStoredPath || "").trim()
        if (!looksLikeAbsoluteLocalPath(storedPath)) return

        const resolvedPath = String(root.libraryBackgroundCustomImageResolvedPath || "").trim()
        if (resolvedPath.length < 1) return

        traceSettings(
            "background image migration begin"
            + " file=" + AppSharedUtils.fileNameFromPath(resolvedPath)
        )
        libraryBackgroundImageMigrationInProgress = true
        const migratedStoredPath = storeLibraryBackgroundImageSelection(resolvedPath, false)
        libraryBackgroundImageMigrationInProgress = false

        if (migratedStoredPath.length > 0 && migratedStoredPath !== storedPath) {
            appSettingsControllerRef.setSettingValue(
                "appearance_library_background_custom_image_path",
                migratedStoredPath
            )
            traceSettings("background image migration ok")
        } else {
            traceSettings("background image migration skipped reason=no_new_stored_path")
        }
    }

    function scheduleLibraryDataRelocationFromSettings() {
        const root = rootObject
        if (!root || !libraryModelRef) return

        const initialPath = String(
            root.pendingLibraryDataRelocationPath
            || root.libraryDataRootPath
            || ""
        )
        const selectedPath = String(libraryModelRef.browseDataRootFolder(initialPath) || "")
        if (selectedPath.length < 1) {
            traceSettings("library data relocation canceled")
            return
        }

        const result = libraryModelRef.scheduleDataRootRelocation(selectedPath)
        if (!Boolean((result || {}).ok)) {
            showSettingsError(String((result || {}).error || AppText.mainFailedScheduleLibraryLocation))
            traceSettings(
                "library data relocation failed"
                + " reason=schedule_failed"
            )
            return
        }

        root.pendingLibraryDataRelocationPath = String((result || {}).pendingPath || selectedPath || "")
        traceSettings("library data relocation scheduled")
    }

    function chooseSevenZipPathFromSettings() {
        if (!libraryModelRef) return

        const root = rootObject
        const initialPath = String(
            root && (root.sevenZipConfiguredPath || root.sevenZipEffectivePath) || ""
        )
        const selectedPath = String(libraryModelRef.browseArchiveFile(initialPath) || "")
        if (selectedPath.length < 1) {
            traceSettings("7zip path choose canceled")
            return
        }

        const applyError = String(libraryModelRef.setSevenZipExecutablePath(selectedPath) || "").trim()
        if (applyError.length > 0) {
            showSettingsError(applyError)
            traceSettings(
                "7zip path apply failed"
                + " file=" + AppSharedUtils.fileNameFromPath(selectedPath)
                + " reason=apply_failed"
            )
            return
        }

        if (root && typeof root.refreshCbrSupportState === "function") {
            root.refreshCbrSupportState()
        }
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
        traceSettings(
            "7zip path apply ok"
            + " file=" + AppSharedUtils.fileNameFromPath(selectedPath)
        )
    }

    function verifySevenZipFromSettings() {
        const root = rootObject
        if (root && typeof root.refreshCbrSupportState === "function") {
            root.refreshCbrSupportState()
        }
        traceSettings("7zip verify requested")
    }

    function checkStorageAccessFromSettings() {
        if (!libraryModelRef || !settingsDialogRef) return

        const result = libraryModelRef.checkStorageAccess()
        const ok = Boolean((result || {}).ok)
        settingsDialogRef.storageAccessCheckState = ok ? "success" : "failure"
        settingsDialogRef.storageAccessResultText = String(
            (result || {}).statusText || (ok ? "All good" : "Needs attention")
        )
        settingsDialogRef.storageAccessHintText = ok
            ? ""
            : String((result || {}).hintText || "")
        traceSettings("storage access checked ok=" + String(ok))
    }

    function resetSettingsToDefaults() {
        traceSettings("settings reset begin")
        if (appSettingsControllerRef
                && typeof appSettingsControllerRef.resetAllSettingsToDefaults === "function") {
            appSettingsControllerRef.resetAllSettingsToDefaults()
        }
        verifySevenZipFromSettings()
        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }
        traceSettings("settings reset done")
    }

    function chooseLibraryBackgroundImageFromSettings() {
        const root = rootObject
        if (!root || !libraryModelRef || !appSettingsControllerRef) return

        const currentPath = String(root.libraryBackgroundCustomImageResolvedPath || "")
        const selectedPath = String(libraryModelRef.browseImageFile(currentPath) || "")
        if (selectedPath.length < 1) {
            traceSettings("background image choose canceled")
            return
        }

        const mode = String(root.libraryBackgroundCustomImageMode || "")
        const limitBytes = mode === "Tile"
            ? libraryBackgroundTileImageMaxBytes
            : libraryBackgroundImageMaxBytes
        const sizeBytes = fileSizeBytes(selectedPath)
        if (sizeBytes > limitBytes) {
            const label = mode === "Tile" ? "1 MB" : "8 MB"
            showSettingsError(AppText.backgroundImageTooLargeMessage(label))
            traceSettings(
                "background image rejected reason=too_large"
                + " mode=" + mode
                + " sizeBytes=" + String(sizeBytes)
                + " limitBytes=" + String(limitBytes)
                + " file=" + AppSharedUtils.fileNameFromPath(selectedPath)
            )
            return
        }

        const storedPath = storeLibraryBackgroundImageSelection(selectedPath, true)
        if (storedPath.length < 1) return

        appSettingsControllerRef.setSettingValue("appearance_library_background_custom_image_path", storedPath)
        appSettingsControllerRef.setSettingValue("appearance_library_background", "Custom image")
        traceSettings(
            "background image selected"
            + " mode=" + mode
            + " file=" + AppSharedUtils.fileNameFromPath(selectedPath)
        )
    }

    function setLibraryBackgroundImageModeFromSettings(nextMode) {
        const root = rootObject
        if (!root || !appSettingsControllerRef) return

        const mode = String(nextMode || "").trim()
        if (mode.length < 1) return
        if (mode === "Tile") {
            const currentPath = String(root.libraryBackgroundCustomImageResolvedPath || "")
            if (currentPath.length > 0) {
                const sizeBytes = fileSizeBytes(currentPath)
                if (sizeBytes > libraryBackgroundTileImageMaxBytes) {
                    showSettingsError(AppText.mainTileModeImageLimit)
                    traceSettings(
                        "background image mode rejected reason=tile_limit"
                        + " sizeBytes=" + String(sizeBytes)
                        + " limitBytes=" + String(libraryBackgroundTileImageMaxBytes)
                    )
                    return
                }
            }
        }
        appSettingsControllerRef.setSettingValue("appearance_library_background_image_mode", mode)
        traceSettings("background image mode set mode=" + mode)
    }
}
