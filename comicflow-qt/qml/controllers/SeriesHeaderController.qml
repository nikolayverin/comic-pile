import QtQuick
import "../components/AppText.js" as AppText
import "../components/AppSharedUtils.js" as AppSharedUtils

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var heroSeriesControllerRef: null
    property var popupControllerRef: null
    property var startupControllerRef: null
    property var seriesHeaderDialogRef: null

    property string dialogSeriesKey: ""
    property string dialogCoverPath: ""
    property string dialogBackgroundPath: ""
    property int dialogBackgroundShuffleRequestId: -1

    function root() {
        return rootObject
    }

    function dialog() {
        return seriesHeaderDialogRef
    }

    function normalizeImportPath(rawPath) {
        return AppSharedUtils.normalizeImportPath(rawPath)
    }

    function imageFileSource(pathValue) {
        const normalizedPath = normalizeImportPath(pathValue)
        if (normalizedPath.length < 1) return ""

        const normalizedSlashes = normalizedPath.replace(/\\/g, "/")
        if (/^[A-Za-z]:\//.test(normalizedSlashes)) {
            const encodedPath = normalizedSlashes
                .split("/")
                .map(function(segment, index) {
                    if (index === 0 && /^[A-Za-z]:$/.test(segment)) {
                        return segment
                    }
                    return encodeURIComponent(segment)
                })
                .join("/")
            return "file:///" + encodedPath
        }

        if (normalizedSlashes.startsWith("/")) {
            return "file://" + normalizedSlashes
        }

        return normalizedPath
    }

    function cacheBustedSource(source) {
        const text = String(source || "").trim()
        if (text.length < 1) return ""
        const separator = text.indexOf("?") >= 0 ? "&" : "?"
        return text + separator + "v=" + String(Date.now())
    }

    function stripSourceRevision(source) {
        return String(source || "").trim().replace(/[?#].*$/, "")
    }

    function currentCustomCoverPath() {
        const rootRef = root()
        return rootRef ? stripSourceRevision(rootRef.heroCustomCoverSource) : ""
    }

    function currentCustomBackgroundPath() {
        const rootRef = root()
        return rootRef ? stripSourceRevision(rootRef.heroCustomBackgroundSource) : ""
    }

    function setErrorText(message) {
        const dialogRef = dialog()
        if (!dialogRef) return
        dialogRef.errorText = String(message || "")
    }

    function clearErrorText() {
        setErrorText("")
    }

    function automaticHeroCoverSource() {
        return heroSeriesControllerRef && typeof heroSeriesControllerRef.automaticHeroCoverSource === "function"
            ? String(heroSeriesControllerRef.automaticHeroCoverSource() || "")
            : ""
    }

    function automaticHeroBackgroundSource() {
        return heroSeriesControllerRef && typeof heroSeriesControllerRef.automaticHeroBackgroundSource === "function"
            ? String(heroSeriesControllerRef.automaticHeroBackgroundSource() || "")
            : ""
    }

    function resolveHeroCoverForSelectedSeries() {
        if (heroSeriesControllerRef && typeof heroSeriesControllerRef.resolveHeroMediaForSelectedSeries === "function") {
            heroSeriesControllerRef.resolveHeroMediaForSelectedSeries()
        }
    }

    function resolveHeroBackgroundForSelectedSeries() {
        if (heroSeriesControllerRef && typeof heroSeriesControllerRef.resolveHeroBackgroundForSelectedSeries === "function") {
            heroSeriesControllerRef.resolveHeroBackgroundForSelectedSeries()
        }
    }

    function refreshHeroSeriesData() {
        if (heroSeriesControllerRef && typeof heroSeriesControllerRef.refreshSeriesData === "function") {
            heroSeriesControllerRef.refreshSeriesData()
        }
    }

    function resetDialogState() {
        dialogSeriesKey = ""
        dialogCoverPath = ""
        dialogBackgroundPath = ""
        dialogBackgroundShuffleRequestId = -1
        clearErrorText()
    }

    function openDialog(seriesKey) {
        const rootRef = root()
        const key = String(seriesKey || (rootRef ? rootRef.selectedSeriesKey : "") || "").trim()
        if (key.length < 1) return

        if (startupControllerRef && typeof startupControllerRef.launchLog === "function") {
            startupControllerRef.launchLog("series_header_dialog_open_request key=" + key)
        }

        resolveHeroCoverForSelectedSeries()
        resolveHeroBackgroundForSelectedSeries()
        if (libraryModelRef && typeof libraryModelRef.resetRandomSeriesHeroState === "function") {
            libraryModelRef.resetRandomSeriesHeroState(key)
        }

        const storedSeriesMetadata = libraryModelRef && typeof libraryModelRef.seriesMetadataForKey === "function"
            ? libraryModelRef.seriesMetadataForKey(key) || {}
            : {}

        dialogSeriesKey = key
        dialogCoverPath = String(storedSeriesMetadata.headerCoverPath || "").trim()
        dialogBackgroundPath = String(storedSeriesMetadata.headerBackgroundPath || "").trim()
        // If metadata path is temporarily unavailable but hero already shows a custom image,
        // keep dialog preview consistent with what user sees in hero.
        if (dialogCoverPath.length < 1) {
            dialogCoverPath = currentCustomCoverPath()
        }
        if (dialogBackgroundPath.length < 1) {
            dialogBackgroundPath = currentCustomBackgroundPath()
        }
        dialogBackgroundShuffleRequestId = -1
        clearErrorText()

        if (startupControllerRef && typeof startupControllerRef.launchLog === "function") {
            startupControllerRef.launchLog("series_header_dialog_open_call key=" + key)
        }

        const dialogRef = dialog()
        if (popupControllerRef && typeof popupControllerRef.openExclusivePopup === "function") {
            popupControllerRef.openExclusivePopup(dialogRef)
        } else if (dialogRef && typeof dialogRef.open === "function") {
            dialogRef.open()
        }
    }

    function selectCoverImage() {
        if (!libraryModelRef || typeof libraryModelRef.browseImageFile !== "function") return

        const currentPath = dialogCoverPath.length > 0
            ? dialogCoverPath
            : (currentCustomCoverPath().length > 0
                ? currentCustomCoverPath()
                : automaticHeroCoverSource())
        const selectedPath = imageFileSource(libraryModelRef.browseImageFile(currentPath))
        if (selectedPath.length < 1) return

        dialogCoverPath = selectedPath
        clearErrorText()
    }

    function selectBackgroundImage() {
        if (!libraryModelRef || typeof libraryModelRef.browseImageFile !== "function") return

        const currentPath = dialogBackgroundPath.length > 0
            ? dialogBackgroundPath
            : (currentCustomBackgroundPath().length > 0
                ? currentCustomBackgroundPath()
                : automaticHeroBackgroundSource())
        const selectedPath = imageFileSource(libraryModelRef.browseImageFile(currentPath))
        if (selectedPath.length < 1) return

        dialogBackgroundShuffleRequestId = -1
        dialogBackgroundPath = selectedPath
        clearErrorText()
    }

    function canShuffleBackground(seriesKey) {
        if (!libraryModelRef || typeof libraryModelRef.issuesForSeries !== "function") return false

        const rootRef = root()
        const key = String(seriesKey || dialogSeriesKey || (rootRef ? rootRef.selectedSeriesKey : "") || "").trim()
        if (key.length < 1) return false

        const rows = libraryModelRef.issuesForSeries(key, "__all__", "all", "")
        return Boolean(rows && rows.length > 0)
    }

    function isShuffleBackgroundBusy() {
        return Number(dialogBackgroundShuffleRequestId || -1) !== -1
    }

    function shuffleBackground() {
        if (isShuffleBackgroundBusy()) {
            return
        }

        const key = String(dialogSeriesKey || "").trim()
        if (key.length < 1) {
            setErrorText(AppText.seriesHeaderContextMissing)
            return
        }
        if (!libraryModelRef || typeof libraryModelRef.requestRandomSeriesHeroAsync !== "function") {
            setErrorText(AppText.seriesHeaderPrepareShuffleFailed)
            return
        }

        dialogBackgroundShuffleRequestId = 0
        const requestId = Number(libraryModelRef.requestRandomSeriesHeroAsync(key) || -1)
        if (requestId < 1) {
            dialogBackgroundShuffleRequestId = -1
            setErrorText(AppText.seriesHeaderPrepareShuffleFailed)
            return
        }

        dialogBackgroundShuffleRequestId = requestId
        clearErrorText()
    }

    function resetToDefaultPending() {
        resolveHeroCoverForSelectedSeries()
        resolveHeroBackgroundForSelectedSeries()
        dialogCoverPath = ""
        dialogBackgroundPath = ""
        dialogBackgroundShuffleRequestId = -1
        clearErrorText()
    }

    function saveDialogChanges() {
        const key = String(dialogSeriesKey || "").trim()
        if (key.length < 1) {
            setErrorText(AppText.seriesHeaderContextMissing)
            return false
        }
        if (!libraryModelRef || typeof libraryModelRef.saveSeriesHeaderImages !== "function") {
            setErrorText(AppText.seriesHeaderSaveFailed)
            return false
        }

        const result = libraryModelRef.saveSeriesHeaderImages(
            key,
            dialogCoverPath,
            dialogBackgroundPath
        ) || {}
        if (!Boolean(result.ok)) {
            setErrorText(String(result.error || AppText.seriesHeaderSaveFailed))
            return false
        }

        const rootRef = root()
        if (rootRef) {
            rootRef.heroCustomCoverSource = cacheBustedSource(String(result.coverPath || "").trim())
            rootRef.heroCustomBackgroundSource = cacheBustedSource(String(result.backgroundPath || "").trim())
        }

        clearErrorText()
        resolveHeroCoverForSelectedSeries()
        resolveHeroBackgroundForSelectedSeries()
        refreshHeroSeriesData()

        if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
            startupControllerRef.requestSnapshotSave()
        }

        const dialogRef = dialog()
        if (dialogRef && typeof dialogRef.close === "function") {
            dialogRef.close()
        }
        return true
    }

    function handleSeriesHeroReady(requestId, seriesKey, imageSource, error) {
        if (requestId !== dialogBackgroundShuffleRequestId) return

        dialogBackgroundShuffleRequestId = -1
        const dialogRef = dialog()
        if (!dialogRef || !dialogRef.visible) {
            return
        }

        if (String(error || "").trim().length > 0 || String(imageSource || "").trim().length < 1) {
            setErrorText(String(error || AppText.seriesHeaderPrepareShuffleFailed))
            return
        }

        dialogBackgroundPath = String(imageSource || "")
        clearErrorText()
    }
}
