import QtQuick

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var popupControllerRef: null
    property var seriesListModelRef: null
    property var appSettingsRef: null
    property var deleteConfirmDialogRef: null
    property var deleteErrorDialogRef: null
    property var seriesDeleteConfirmDialogRef: null

    property int pendingDeleteId: -1
    property string deleteErrorHeadline: ""
    property string deleteErrorReasonText: ""
    property string deleteErrorDetailsText: ""
    property string deleteErrorSystemText: ""
    property string deleteErrorRawText: ""
    property string deleteErrorPrimaryPath: ""
    property var deleteErrorFailedPaths: []
    property string deleteRetryMode: ""
    property int deleteRetryComicId: -1
    property var deleteRetrySeriesKeys: []
    property string pendingSeriesKey: ""
    property string pendingSeriesTitle: ""
    property var pendingSeriesKeys: []
    property int pendingSeriesIssueCount: 0

    function root() {
        return rootObject
    }

    function normalizeImportPath(rawPath) {
        const rootRef = root()
        return rootRef && typeof rootRef.normalizeImportPath === "function"
            ? String(rootRef.normalizeImportPath(rawPath) || "")
            : ""
    }

    function fileNameFromPath(pathValue) {
        const rootRef = root()
        return rootRef && typeof rootRef.fileNameFromPath === "function"
            ? rootRef.fileNameFromPath(pathValue)
            : ""
    }

    function openExclusivePopup(targetPopup) {
        if (popupControllerRef && typeof popupControllerRef.openExclusivePopup === "function") {
            popupControllerRef.openExclusivePopup(targetPopup)
        }
    }

    function showActionResult(message, isError) {
        if (popupControllerRef && typeof popupControllerRef.showActionResult === "function") {
            popupControllerRef.showActionResult(message, isError)
        }
    }

    function clearSelection() {
        const rootRef = root()
        if (rootRef && typeof rootRef.clearSelection === "function") {
            rootRef.clearSelection()
        }
    }

    function hasTextInputFocus() {
        const rootRef = root()
        return rootRef && typeof rootRef.hasTextInputFocus === "function"
            ? Boolean(rootRef.hasTextInputFocus())
            : false
    }

    function selectedSeriesCount() {
        const rootRef = root()
        return rootRef && typeof rootRef.selectedSeriesCount === "function"
            ? Number(rootRef.selectedSeriesCount() || 0)
            : 0
    }

    function selectedSeriesIssueCount() {
        const rootRef = root()
        return rootRef && typeof rootRef.selectedSeriesIssueCount === "function"
            ? Number(rootRef.selectedSeriesIssueCount() || 0)
            : 0
    }

    function indexForSeriesKey(seriesKey) {
        const rootRef = root()
        return rootRef && typeof rootRef.indexForSeriesKey === "function"
            ? Number(rootRef.indexForSeriesKey(seriesKey) || -1)
            : -1
    }

    function isSeriesSelected(seriesKey) {
        const rootRef = root()
        return rootRef && typeof rootRef.isSeriesSelected === "function"
            ? Boolean(rootRef.isSeriesSelected(seriesKey))
            : false
    }

    function parseDeleteFailureItems(rawErrorText) {
        const raw = String(rawErrorText || "")
        const lines = raw.split(/\r?\n/)
        const items = []

        for (let i = 0; i < lines.length; i += 1) {
            const line = String(lines[i] || "").trim()
            if (line.length < 1) continue
            const pathMatch = line.match(/Path:\s*(.*?)\s*(?:\|\s*Reason:|$)/i)
            if (!pathMatch) continue

            const parsedPath = normalizeImportPath(pathMatch[1] || "")
            if (parsedPath.length < 1) continue

            const reasonMatch = line.match(/\bReason:\s*([a-z_]+)/i)
            const systemMatch = line.match(/\bSystem:\s*(.+)$/i)
            const reasonCode = reasonMatch ? String(reasonMatch[1] || "").toLowerCase() : "system_error"
            const systemText = systemMatch ? String(systemMatch[1] || "").trim() : ""

            items.push({
                path: parsedPath,
                reasonCode: reasonCode.length > 0 ? reasonCode : "system_error",
                systemText: systemText
            })
        }

        if (items.length < 1) {
            const legacyMatch = raw.match(/Failed to remove(?: archive)? file:\s*(.+)$/im)
            if (legacyMatch) {
                const legacyPath = normalizeImportPath(String(legacyMatch[1] || "").trim())
                if (legacyPath.length > 0) {
                    items.push({
                        path: legacyPath,
                        reasonCode: "system_error",
                        systemText: ""
                    })
                }
            }
        }

        const uniquePaths = []
        const seen = ({})
        for (let i = 0; i < items.length; i += 1) {
            const path = String(items[i].path || "")
            if (path.length < 1) continue
            const key = path.toLowerCase()
            if (seen[key] === true) continue
            seen[key] = true
            uniquePaths.push(path)
        }

        return {
            items: items,
            paths: uniquePaths
        }
    }

    function classifyDeleteFailureCopy(parsedDeleteData, rawErrorText) {
        const parsed = parsedDeleteData || ({ items: [], paths: [] })
        const items = Array.isArray(parsed.items) ? parsed.items : []
        const paths = Array.isArray(parsed.paths) ? parsed.paths : []
        const lowerRaw = String(rawErrorText || "").toLowerCase()

        let hasLock = false
        let hasAccessDenied = false
        let hasPathUnavailable = false
        for (let i = 0; i < items.length; i += 1) {
            const code = String(items[i].reasonCode || "").toLowerCase()
            if (code === "lock") hasLock = true
            if (code === "access_denied") hasAccessDenied = true
            if (code === "path_unavailable") hasPathUnavailable = true
        }

        if (!hasLock) {
            hasLock = lowerRaw.indexOf("being used by another process") >= 0
                || lowerRaw.indexOf("sharing violation") >= 0
                || lowerRaw.indexOf("in use") >= 0
                || lowerRaw.indexOf("resource busy") >= 0
        }
        if (!hasAccessDenied) {
            hasAccessDenied = lowerRaw.indexOf("access denied") >= 0
                || lowerRaw.indexOf("permission denied") >= 0
                || lowerRaw.indexOf("operation not permitted") >= 0
        }
        if (!hasPathUnavailable) {
            hasPathUnavailable = lowerRaw.indexOf("path not found") >= 0
                || lowerRaw.indexOf("cannot find the path") >= 0
                || lowerRaw.indexOf("directory name is invalid") >= 0
                || lowerRaw.indexOf("device is not ready") >= 0
        }

        let reasonText = "The app couldn't remove the file due to a system error."
        if (hasLock) {
            reasonText = "File is currently used by another application."
        } else if (hasAccessDenied) {
            reasonText = "No permission to remove files in this folder."
        } else if (hasPathUnavailable) {
            reasonText = "Folder or disk is currently unavailable."
        }

        const isBulk = paths.length > 1
        const primaryPath = paths.length > 0 ? String(paths[0] || "") : ""
        let detailsText = ""
        if (isBulk) {
            detailsText = "Couldn't remove " + paths.length + " files right now."
        } else if (primaryPath.length > 0) {
            detailsText = "File: " + fileNameFromPath(primaryPath)
        } else {
            detailsText = "The requested delete action could not be completed right now."
        }

        let systemText = ""
        if (items.length > 0) {
            systemText = String(items[0].systemText || "").trim()
        }

        return {
            headline: isBulk ? "Couldn't remove some files" : "Couldn't remove file",
            reasonText: reasonText,
            detailsText: detailsText,
            systemText: systemText,
            primaryPath: primaryPath,
            failedPaths: paths
        }
    }

    function clearDeleteFailureContext() {
        deleteErrorHeadline = ""
        deleteErrorReasonText = ""
        deleteErrorDetailsText = ""
        deleteErrorSystemText = ""
        deleteErrorRawText = ""
        deleteErrorPrimaryPath = ""
        deleteErrorFailedPaths = []
        deleteRetryMode = ""
        deleteRetryComicId = -1
        deleteRetrySeriesKeys = []
    }

    function openDeleteFailureDialog(rawErrorText, retryContext) {
        const raw = String(rawErrorText || "").trim()
        const parsed = parseDeleteFailureItems(raw)
        const copy = classifyDeleteFailureCopy(parsed, raw)

        deleteErrorHeadline = String(copy.headline || "")
        deleteErrorReasonText = String(copy.reasonText || "")
        deleteErrorDetailsText = String(copy.detailsText || "")
        deleteErrorSystemText = String(copy.systemText || "")
        deleteErrorPrimaryPath = String(copy.primaryPath || "")
        deleteErrorFailedPaths = Array.isArray(copy.failedPaths) ? copy.failedPaths.slice(0) : []
        deleteErrorRawText = raw

        const ctx = retryContext || ({})
        deleteRetryMode = String(ctx.mode || "")
        deleteRetryComicId = Number(ctx.comicId || -1)
        deleteRetrySeriesKeys = Array.isArray(ctx.seriesKeys) ? ctx.seriesKeys.slice(0) : []

        openExclusivePopup(deleteErrorDialogRef)
    }

    function retryDeleteFailure() {
        if (!libraryModelRef) return

        if (deleteRetryMode === "issue") {
            const issueId = Number(deleteRetryComicId || 0)
            if (issueId < 1) {
                if (deleteErrorDialogRef) deleteErrorDialogRef.close()
                return
            }

            const retryResult = String(libraryModelRef.deleteComic(issueId) || "")
            if (retryResult.length > 0) {
                openDeleteFailureDialog(retryResult, { mode: "issue", comicId: issueId })
                return
            }
            if (deleteErrorDialogRef) deleteErrorDialogRef.close()
            return
        }

        if (deleteRetryMode === "series") {
            const keys = Array.isArray(deleteRetrySeriesKeys) ? deleteRetrySeriesKeys.slice(0) : []
            if (keys.length < 1) {
                if (deleteErrorDialogRef) deleteErrorDialogRef.close()
                return
            }

            const errors = []
            for (let i = 0; i < keys.length; i += 1) {
                const key = String(keys[i] || "").trim()
                if (key.length < 1) continue
                const result = String(libraryModelRef.deleteSeriesFiles(key) || "")
                if (result.length > 0) {
                    errors.push(result)
                }
            }

            if (errors.length > 0) {
                openDeleteFailureDialog(errors.join("\n"), { mode: "series", seriesKeys: keys })
                return
            }
            if (deleteErrorDialogRef) deleteErrorDialogRef.close()
            return
        }

        if (deleteErrorDialogRef) deleteErrorDialogRef.close()
    }

    function requestDeleteSelectedSeries() {
        const rootRef = root()
        if (!rootRef || hasTextInputFocus()) return
        if (Boolean(rootRef.importInProgress)) return
        if ((rootRef.readerDialog && rootRef.readerDialog.visible)
            || (rootRef.metadataDialog && rootRef.metadataDialog.visible)
            || (rootRef.seriesMetaDialog && rootRef.seriesMetaDialog.visible)
            || (rootRef.failedImportsDialog && rootRef.failedImportsDialog.visible)) {
            return
        }

        let keys = Object.keys(rootRef.selectedSeriesKeys || ({}))
        if (keys.length < 1 && String(rootRef.selectedSeriesKey || "").length > 0) {
            keys = [String(rootRef.selectedSeriesKey || "")]
        }
        if (keys.length < 1) return

        pendingSeriesKeys = keys
        pendingSeriesKey = keys.length === 1 ? String(keys[0] || "") : ""
        pendingSeriesTitle = ""
        if (keys.length === 1) {
            const singleIndex = indexForSeriesKey(keys[0])
            if (singleIndex >= 0 && seriesListModelRef) {
                pendingSeriesTitle = String(seriesListModelRef.get(singleIndex).seriesTitle || "")
            }
        }
        pendingSeriesIssueCount = selectedSeriesIssueCount()
        if (appSettingsRef && !Boolean(appSettingsRef.safetyConfirmBeforeDeletingSeries)) {
            performSeriesDelete()
            return
        }
        openExclusivePopup(seriesDeleteConfirmDialogRef)
    }

    function requestSeriesDelete(seriesKey, seriesTitle) {
        const rootRef = root()
        const key = String(seriesKey || "")
        if (!rootRef || key.length < 1) return

        const multipleSelected = selectedSeriesCount() > 1 && isSeriesSelected(key)
        if (multipleSelected) {
            pendingSeriesKeys = Object.keys(rootRef.selectedSeriesKeys || ({}))
            pendingSeriesKey = ""
            pendingSeriesTitle = ""
            pendingSeriesIssueCount = selectedSeriesIssueCount()
        } else {
            pendingSeriesKeys = [key]
            pendingSeriesKey = key
            pendingSeriesTitle = String(seriesTitle || "")
            const idx = indexForSeriesKey(key)
            pendingSeriesIssueCount = idx >= 0 && seriesListModelRef
                ? Number(seriesListModelRef.get(idx).count || 0)
                : 0
        }
        if (appSettingsRef && !Boolean(appSettingsRef.safetyConfirmBeforeDeletingSeries)) {
            performSeriesDelete()
            return
        }
        openExclusivePopup(seriesDeleteConfirmDialogRef)
    }

    function performSeriesDelete() {
        if (!libraryModelRef) return
        const keys = Array.isArray(pendingSeriesKeys) ? pendingSeriesKeys.slice(0) : []
        if (keys.length < 1) return

        const errors = []
        for (let i = 0; i < keys.length; i += 1) {
            const key = String(keys[i] || "")
            if (key.length < 1) continue
            const result = String(libraryModelRef.deleteSeriesFiles(key) || "")
            if (result.length > 0) {
                errors.push(result)
            }
        }

        if (errors.length > 0) {
            openDeleteFailureDialog(errors.join("\n"), {
                mode: "series",
                seriesKeys: keys
            })
        }

        pendingSeriesKeys = []
        pendingSeriesKey = ""
        pendingSeriesTitle = ""
        pendingSeriesIssueCount = 0

        const rootRef = root()
        if (rootRef) {
            rootRef.selectedSeriesKeys = ({})
            rootRef.seriesSelectionAnchorIndex = -1
        }
    }

    function requestDelete(comicId) {
        pendingDeleteId = Number(comicId || -1)
        if (appSettingsRef && !Boolean(appSettingsRef.safetyConfirmBeforeDeletingFiles)) {
            performDelete()
            return
        }
        openExclusivePopup(deleteConfirmDialogRef)
    }

    function performDelete() {
        if (!libraryModelRef) return
        if (pendingDeleteId < 1) return

        const targetComicId = Number(pendingDeleteId || -1)
        const result = String(libraryModelRef.deleteComic(targetComicId) || "")
        if (result.length > 0) {
            openDeleteFailureDialog(result, {
                mode: "issue",
                comicId: targetComicId
            })
        }
        pendingDeleteId = -1
        clearSelection()
    }
}
