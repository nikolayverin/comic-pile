import QtQuick
import "../components/AppText.js" as AppText

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var popupControllerRef: null
    property var importConflictDialogRef: null
    property var failedImportsDialogRef: null
    property var failedImportItemsModelRef: null

    property bool importInProgress: false
    property int importTotal: 0
    property int importProcessed: 0
    property double importTotalBytes: 0
    property double importProcessedBytes: 0
    property int importImportedCount: 0
    property int importErrorCount: 0
    property bool importCancelRequested: false
    property string importLifecycleState: "idle"
    property string importCurrentPath: ""
    property string importCurrentFileName: ""
    property bool importPausedForConflict: false
    property var importConflictContext: ({})
    property var importConflictNextContext: ({})
    property string importConflictExistingLabel: ""
    property string importConflictIncomingLabel: ""
    property string importConflictNextExistingLabel: ""
    property string importConflictNextIncomingLabel: ""
    property string importConflictBatchAction: ""
    property int importConflictBatchDuplicateCount: 0
    property bool importConflictOperationActive: false
    property string importConflictPendingAction: ""
    property string importConflictProgressCurrentFileName: ""
    property int importConflictProgressProcessedCount: 0
    property int importConflictProgressTotalCount: 0
    readonly property real importConflictProgressFraction: importConflictProgressTotalCount > 0
        ? Math.max(0, Math.min(1, importConflictProgressProcessedCount / importConflictProgressTotalCount))
        : 0
    property var importQueue: []
    property var importErrors: []
    property var importFailedPaths: []
    property var lastFailedImportPaths: []
    property var lastFailedImportErrors: []

    property var importBatchRollbackOps: []
    property var importPendingOldFileDeletes: []
    property int importArchiveNormalizationRequestId: -1
    property var importPendingStepContext: ({})
    property var importCleanupQueue: []
    property int importCleanupTotalCount: 0
    property int importCleanupProcessedCount: 0
    property string importCleanupCurrentFileName: ""

    readonly property bool importCleanupActive: importLifecycleState === "cleanup"

    function root() {
        return rootObject
    }

    function cloneVariantMap(sourceValues) {
        const rootRef = root()
        return rootRef && typeof rootRef.cloneVariantMap === "function"
            ? rootRef.cloneVariantMap(sourceValues)
            : ({})
    }

    function fileNameFromPath(pathValue) {
        const rootRef = root()
        return rootRef && typeof rootRef.fileNameFromPath === "function"
            ? rootRef.fileNameFromPath(pathValue)
            : ""
    }

    function baseNameWithoutExtension(pathValue) {
        const fileName = String(fileNameFromPath(pathValue) || "").trim()
        if (fileName.length < 1) return ""
        const lastDot = fileName.lastIndexOf(".")
        if (lastDot <= 0) return fileName
        return String(fileName.substring(0, lastDot) || "").trim()
    }

    function fileSizeBytes(pathValue) {
        const rootRef = root()
        return rootRef && typeof rootRef.fileSizeBytes === "function"
            ? Number(rootRef.fileSizeBytes(pathValue) || 0)
            : 0
    }

    function normalizeImportPath(rawPath) {
        const rootRef = root()
        return rootRef && typeof rootRef.normalizeImportPath === "function"
            ? String(rootRef.normalizeImportPath(rawPath) || "")
            : ""
    }

    function parentFolderPath(pathValue) {
        const rootRef = root()
        return rootRef && typeof rootRef.parentFolderPath === "function"
            ? String(rootRef.parentFolderPath(pathValue) || "")
            : ""
    }

    function resolveImportSourceEntries(paths) {
        const rootRef = root()
        return rootRef && typeof rootRef.resolveImportSourceEntries === "function"
            ? rootRef.resolveImportSourceEntries(paths)
            : []
    }

    function openExclusivePopup(targetPopup) {
        if (popupControllerRef && typeof popupControllerRef.openExclusivePopup === "function") {
            popupControllerRef.openExclusivePopup(targetPopup)
        }
    }

    function closeAllModalPopups(exceptPopup) {
        if (popupControllerRef && typeof popupControllerRef.closeAllManagedPopups === "function") {
            popupControllerRef.closeAllManagedPopups(exceptPopup)
        }
    }

    function showActionResult(message, isError) {
        if (popupControllerRef && typeof popupControllerRef.showActionResult === "function") {
            popupControllerRef.showActionResult(message, isError)
        }
    }

    function captureImportSeriesFocusBaseline() {
        const rootRef = root()
        if (rootRef && typeof rootRef.captureImportSeriesFocusBaseline === "function") {
            rootRef.captureImportSeriesFocusBaseline()
        }
    }

    function requestImportNewSeriesFocusAfterReload() {
        const rootRef = root()
        if (rootRef && typeof rootRef.requestImportNewSeriesFocusAfterReload === "function") {
            rootRef.requestImportNewSeriesFocusAfterReload()
        }
    }

    function resetLastImportSessionState() {
        const rootRef = root()
        if (rootRef && typeof rootRef.resetLastImportSession === "function") {
            rootRef.resetLastImportSession()
        }
    }

    function rememberLastImportComicId(comicId) {
        const rootRef = root()
        if (rootRef && typeof rootRef.rememberLastImportComicId === "function") {
            rootRef.rememberLastImportComicId(comicId)
        }
    }

    function clearImportSeriesFocusState() {
        const rootRef = root()
        if (rootRef && typeof rootRef.clearImportSeriesFocusState === "function") {
            rootRef.clearImportSeriesFocusState()
        }
    }

    function classifyImportError(pathValue, rawErrorText, rawErrorCode) {
        const rootRef = root()
        if (rootRef && typeof rootRef.classifyImportError === "function") {
            return rootRef.classifyImportError(pathValue, rawErrorText, rawErrorCode)
        }
        return {
            reason: "Import failed"
        }
    }

    function archiveUnsupportedReason(pathValue) {
        if (!libraryModelRef) return ""
        return String(libraryModelRef.importArchiveUnsupportedReason(String(pathValue || "")) || "")
    }

    function pushImportFailure(pathValue, rawErrorText, rawErrorCode) {
        const classified = classifyImportError(pathValue, rawErrorText, rawErrorCode)
        importErrorCount += 1
        importFailedPaths.push(String(pathValue || ""))
        importErrors.push(classified.reason)
    }

    function advanceCompletedImportBytes(sizeBytes) {
        const resolvedSizeBytes = Math.max(0, Number(sizeBytes || 0))
        if (resolvedSizeBytes < 1) return
        importProcessedBytes = Math.min(importTotalBytes, importProcessedBytes + resolvedSizeBytes)
    }

    function clearPendingImportStepContext() {
        importArchiveNormalizationRequestId = -1
        importPendingStepContext = ({})
    }

    function cleanupTemporaryNormalizedArchive(pathValue, temporaryFile) {
        const normalizedPath = String(pathValue || "").trim()
        if (!Boolean(temporaryFile) || normalizedPath.length < 1 || !libraryModelRef) return
        libraryModelRef.deleteFileAtPath(normalizedPath)
    }

    function resetImportConflictState(closeDialog) {
        importPausedForConflict = false
        importConflictContext = ({})
        importConflictNextContext = ({})
        importConflictIncomingLabel = ""
        importConflictExistingLabel = ""
        importConflictNextIncomingLabel = ""
        importConflictNextExistingLabel = ""
        importConflictBatchAction = ""
        importConflictBatchDuplicateCount = 0
        importConflictOperationActive = false
        importConflictPendingAction = ""
        importConflictProgressCurrentFileName = ""
        importConflictProgressProcessedCount = 0
        importConflictProgressTotalCount = 0
        if (closeDialog === true && importConflictDialogRef && typeof importConflictDialogRef.close === "function") {
            importConflictDialogRef.close()
        }
    }

    function resetImportCleanupState() {
        importCleanupQueue = []
        importCleanupTotalCount = 0
        importCleanupProcessedCount = 0
        importCleanupCurrentFileName = ""
    }

    function rollbackDisplayName(op) {
        const entry = op || ({})
        const explicitLabel = String(entry.label || "").trim()
        if (explicitLabel.length > 0) return explicitLabel

        const oldFilename = String(entry.oldFilename || "").trim()
        if (oldFilename.length > 0) return oldFilename

        const newFileName = fileNameFromPath(String(entry.newFilePath || ""))
        if (newFileName.length > 0) return newFileName

        const oldFileName = fileNameFromPath(String(entry.oldFilePath || ""))
        if (oldFileName.length > 0) return oldFileName

        const comicId = Number(entry.comicId || 0)
        return comicId > 0 ? ("Issue #" + String(comicId)) : "Imported item"
    }

    function buildImportCleanupQueue() {
        const queue = []
        for (let i = importBatchRollbackOps.length - 1; i >= 0; i -= 1) {
            queue.push(importBatchRollbackOps[i] || ({}))
        }
        return queue
    }

    function rollbackSingleImportOp(op) {
        const entry = op || ({})
        const type = String(entry.type || "")
        const comicId = Number(entry.comicId || 0)
        if (comicId < 1 || !libraryModelRef) return

        const oldImportSignals = cloneVariantMap(entry.oldImportSignals)
        let rollbackError = ""

        if (type === "replace") {
            const backupFilePath = String(entry.backupFilePath || "")
            const oldFilePath = String(entry.oldFilePath || "")
            const oldFilename = String(entry.oldFilename || "")
            if (backupFilePath.length > 0) {
                rollbackError = String(
                    libraryModelRef.restoreReplacedComicFileFromBackupEx(
                        comicId,
                        backupFilePath,
                        oldFilePath,
                        oldFilename,
                        oldImportSignals
                    ) || ""
                )
            } else {
                rollbackError = String(libraryModelRef.detachComicFileKeepMetadata(comicId) || "")
                if (rollbackError.length < 1) {
                    const newFilePath = String(entry.newFilePath || "")
                    if (newFilePath.length > 0) {
                        const deleteNewError = String(libraryModelRef.deleteFileAtPath(newFilePath) || "")
                        if (deleteNewError.length > 0) {
                            rollbackError = deleteNewError
                        }
                    }
                }
                if (rollbackError.length < 1) {
                    rollbackError = String(
                        libraryModelRef.relinkComicFileKeepMetadataEx(
                            comicId,
                            oldFilePath,
                            oldFilename,
                            oldImportSignals
                        ) || ""
                    )
                }
            }
        } else if (type === "restored") {
            rollbackError = String(libraryModelRef.detachComicFileKeepMetadata(comicId) || "")
            if (rollbackError.length < 1) {
                const restoredFilePath = String(entry.newFilePath || "")
                if (restoredFilePath.length > 0) {
                    rollbackError = String(libraryModelRef.deleteFileAtPath(restoredFilePath) || "")
                }
            }
        } else {
            rollbackError = String(libraryModelRef.deleteComicHard(comicId) || "")
        }

        if (rollbackError.length > 0) {
            pushImportFailure(
                "[rollback] issue " + String(comicId),
                AppText.importRollbackFailedPrefix + rollbackError,
                "runtime_error"
            )
        }
    }

    function finalizeImportBatch(cancelled) {
        importBatchTimer.stop()
        importConflictActionTimer.stop()
        importCleanupTimer.stop()
        clearPendingImportStepContext()
        resetImportConflictState(true)

        importInProgress = false
        importCancelRequested = false
        importLifecycleState = "idle"
        importCurrentPath = ""
        importCurrentFileName = ""

        if (!cancelled) {
            commitPendingReplaceDeletes()
        }

        const shouldReloadLibrary = importImportedCount > 0 || cancelled === true
        if (shouldReloadLibrary && libraryModelRef) {
            if (!cancelled && importImportedCount > 0) {
                requestImportNewSeriesFocusAfterReload()
            } else {
                clearImportSeriesFocusState()
            }
            libraryModelRef.reload()
        } else {
            clearImportSeriesFocusState()
        }

        lastFailedImportPaths = importFailedPaths.slice(0)
        lastFailedImportErrors = importErrors.slice(0)
        rebuildFailedImportItemsModel()

        importBatchRollbackOps = []
        importPendingOldFileDeletes = []
        importQueue = []
        resetImportCleanupState()

        if (cancelled === true) {
            if (lastFailedImportPaths.length > 0) {
                openExclusivePopup(failedImportsDialogRef)
            }
            return
        }

        if (importErrorCount === 0) return
        openExclusivePopup(failedImportsDialogRef)
    }

    function beginImportCleanup() {
        if (!importInProgress || importCleanupActive) return

        importBatchTimer.stop()
        importConflictActionTimer.stop()
        importQueue = []
        resetImportConflictState(true)

        importLifecycleState = "cleanup"
        importCleanupQueue = buildImportCleanupQueue()
        importCleanupTotalCount = importCleanupQueue.length
        importCleanupProcessedCount = 0
        importCleanupCurrentFileName = importCleanupQueue.length > 0
            ? rollbackDisplayName(importCleanupQueue[0])
            : ""

        if (importCleanupQueue.length < 1) {
            finalizeImportBatch(true)
            return
        }

        importCleanupTimer.start()
    }

    function finishImportBatch(cancelled) {
        if (cancelled === true) {
            beginImportCleanup()
            return
        }
        finalizeImportBatch(false)
    }

    function finalizeImportStepResult(sourcePath, queuedFileSizeBytes, result, cleanupPath, cleanupIsTemporary, stepContext) {
        const effectiveResult = result || ({})
        const context = stepContext || ({})
        const ok = Boolean(effectiveResult.ok)
        if (!ok) {
            const code = String(effectiveResult.code || "runtime_error")
            const errorText = String(effectiveResult.error || AppText.importFailedDefault)
            const duplicateTier = String(effectiveResult.duplicateTier || "").trim().toLowerCase()
            if ((code === "duplicate" || code === "restore_review_required")
                && Number(effectiveResult.existingId || 0) > 0) {
                if (code === "duplicate"
                    && duplicateTier === "exact"
                    && (importConflictBatchAction === "skip_all" || importConflictBatchAction === "replace_all")) {
                    const duplicateContext = createImportConflictContext(
                        sourcePath,
                        String(effectiveResult.sourceType || "archive"),
                        String(context.seriesOverride || ""),
                        String(context.filenameHint || ""),
                        cloneVariantMap(context.importValues),
                        effectiveResult
                    )
                    applyImportConflictChoice(importConflictBatchAction, duplicateContext)
                    cleanupTemporaryNormalizedArchive(cleanupPath, cleanupIsTemporary)
                    if (importQueue.length < 1) {
                        finishImportBatch(false)
                    } else {
                        importBatchTimer.start()
                    }
                    return
                }

                openImportConflictDialog(
                    sourcePath,
                    String(effectiveResult.sourceType || "archive"),
                    String(context.seriesOverride || ""),
                    String(context.filenameHint || ""),
                    cloneVariantMap(context.importValues),
                    effectiveResult
                )
                cleanupTemporaryNormalizedArchive(cleanupPath, cleanupIsTemporary)
                return
            }

            pushImportFailure(sourcePath, errorText, code)
            advanceCompletedImportBytes(queuedFileSizeBytes)
            cleanupTemporaryNormalizedArchive(cleanupPath, cleanupIsTemporary)
            if (importQueue.length < 1) {
                finishImportBatch(false)
            } else {
                importBatchTimer.start()
            }
            return
        }

        importImportedCount += 1
        rememberLastImportComicId(Number(effectiveResult.comicId || 0))
        registerBatchRollbackOp(effectiveResult, "", { newFilePath: String(effectiveResult.filePath || "") })
        advanceCompletedImportBytes(queuedFileSizeBytes)
        cleanupTemporaryNormalizedArchive(cleanupPath, cleanupIsTemporary)

        if (importQueue.length < 1) {
            finishImportBatch(false)
        } else {
            importBatchTimer.start()
        }
    }

    function registerBatchRollbackOp(importResult, overrideType, extra) {
        const comicId = Number((importResult || {}).comicId || 0)
        if (comicId < 1) return

        let opType = String(overrideType || "").trim()
        if (opType.length < 1) {
            const code = String((importResult || {}).code || "").toLowerCase()
            if (code === "restored") opType = "restored"
            else opType = "created"
        }

        const op = {
            type: opType,
            comicId: comicId,
            label: String((importResult || {}).filename || "").trim()
        }
        if (extra && typeof extra === "object") {
            const keys = Object.keys(extra)
            for (let i = 0; i < keys.length; i += 1) {
                op[keys[i]] = extra[keys[i]]
            }
        }
        importBatchRollbackOps.push(op)
    }

    function commitPendingReplaceDeletes() {
        if (!libraryModelRef || importPendingOldFileDeletes.length < 1) {
            importPendingOldFileDeletes = []
            return
        }

        const seen = ({})
        for (let i = 0; i < importPendingOldFileDeletes.length; i += 1) {
            const rawPath = String(importPendingOldFileDeletes[i] || "")
            const normalizedPath = normalizeImportPath(rawPath)
            if (normalizedPath.length < 1) continue

            const dedupeKey = normalizedPath.toLowerCase()
            if (seen[dedupeKey] === true) continue
            seen[dedupeKey] = true

            libraryModelRef.deleteFileAtPath(normalizedPath)
        }

        importPendingOldFileDeletes = []
    }

    function buildImportConflictExistingLabel(meta, fallbackExistingId) {
        const values = meta || ({})
        const existingId = Number(fallbackExistingId || 0)
        const existingSeries = String(values.series || "").trim()
        const existingIssue = String(values.issueNumber || "").trim()
        const existingTitle = String(values.title || "").trim()
        const existingFilename = String(values.filename || "").trim()

        let existingLabel = existingFilename.length > 0 ? existingFilename : ("Issue #" + String(existingId))
        if (existingSeries.length > 0) existingLabel = existingSeries + " | " + existingLabel
        if (existingIssue.length > 0) existingLabel += " | #" + existingIssue
        if (existingTitle.length > 0) existingLabel += " | " + existingTitle
        return existingLabel
    }

    function createImportConflictContext(sourcePath, sourceType, seriesOverride, filenameHint, importValues, importResult) {
        const conflictCode = String((importResult || {}).code || "").trim().toLowerCase() || "duplicate"
        const duplicateTier = String((importResult || {}).duplicateTier || "").trim().toLowerCase() || "exact"
        const existingId = Number((importResult || {}).existingId || 0)
        const meta = existingId > 0 && libraryModelRef ? libraryModelRef.loadComicMetadata(existingId) : ({})
        const storedOldFilePath = String(meta.filePath || "").trim()
        const resolvedOldFilePath = existingId > 0 && libraryModelRef
            ? String(libraryModelRef.archivePathForComic(existingId) || "").trim()
            : ""

        return {
            conflictCode: conflictCode,
            sourcePath: String(sourcePath || ""),
            sourceType: String(sourceType || "archive"),
            seriesOverride: String(seriesOverride || ""),
            filenameHint: String(filenameHint || ""),
            importIntent: String(((importValues || {}).importIntent) || "").trim().toLowerCase(),
            importValues: cloneVariantMap(importValues),
            duplicateTier: duplicateTier,
            existingId: existingId,
            existingFilename: String(meta.filename || "").trim(),
            existingVolume: String(meta.volume || "").trim(),
            oldFilePath: resolvedOldFilePath.length > 0 ? resolvedOldFilePath : storedOldFilePath,
            existingSeries: String(meta.series || "").trim(),
            existingIssue: String(meta.issueNumber || "").trim(),
            existingTitle: String(meta.title || "").trim(),
            oldImportSignals: {
                importOriginalFilename: String(meta.importOriginalFilename || "").trim(),
                importStrictFilenameSignature: String(meta.importStrictFilenameSignature || "").trim(),
                importLooseFilenameSignature: String(meta.importLooseFilenameSignature || "").trim(),
                importSourceType: String(meta.importSourceType || "").trim()
            },
            incomingLabel: fileNameFromPath(sourcePath),
            existingLabel: buildImportConflictExistingLabel(meta, existingId)
        }
    }

    function importConflictTier(context) {
        return String((context || {}).duplicateTier || "").trim().toLowerCase() || "exact"
    }

    function importConflictCode(context) {
        return String((context || {}).conflictCode || "").trim().toLowerCase() || "duplicate"
    }

    function importConflictSupportsBatchActions(context) {
        if (importConflictCode(context) === "restore_review_required") return false
        return importConflictTier(context) === "exact"
    }

    function importConflictDialogTitle(context) {
        if (importConflictCode(context) === "restore_review_required") {
            return "Restore Existing Issue?"
        }
        const tier = importConflictTier(context)
        if (tier === "very_likely") return "Possible Duplicate Found"
        if (tier === "weak") return "Suspicious Match Found"
        return "Issue Already Exists"
    }

    function importConflictDialogMessage(context) {
        if (importConflictCode(context) === "restore_review_required") {
            return "This archive looks close to a deleted issue in this series, but the match is not exact. Restore that issue or import this as a new issue:"
        }
        const tier = importConflictTier(context)
        if (tier === "very_likely") {
            return "This looks like the same issue in your library, but the archive is not an exact file match. Replace the existing file or import this as a new issue:"
        }
        if (tier === "weak") {
            return "This might be related to an existing issue, but the match is weak. Import it as a new issue or skip this file:"
        }
        return "This archive matches an existing issue in your library. Choose what to do:"
    }

    function importConflictDialogSecondaryLabel(context) {
        if (importConflictCode(context) === "restore_review_required") return "Import as new"
        const tier = importConflictTier(context)
        if (tier === "very_likely") return "Import as new"
        if (tier === "weak") return "Skip"
        return "Keep current"
    }

    function importConflictDialogPrimaryLabel(context) {
        if (importConflictCode(context) === "restore_review_required") return "Restore existing"
        const tier = importConflictTier(context)
        if (tier === "weak") return "Import as new"
        if (tier === "very_likely") return "Replace existing"
        return "Replace"
    }

    function importConflictSecondaryAction(context) {
        if (importConflictCode(context) === "restore_review_required") return "import_as_new"
        const tier = importConflictTier(context)
        if (tier === "very_likely") return "import_as_new"
        if (tier === "weak") return "skip"
        return "keep_current"
    }

    function importConflictPrimaryAction(context) {
        if (importConflictCode(context) === "restore_review_required") return "restore_existing"
        const tier = importConflictTier(context)
        if (tier === "weak") return "import_as_new"
        return "replace"
    }

    function findQueuedImportConflictEntryIndex(pathValue, sourceTypeValue, filenameHintValue) {
        const normalizedPath = String(pathValue || "")
        const normalizedSourceType = String(sourceTypeValue || "archive")
        const normalizedFilenameHint = String(filenameHintValue || "")
        for (let i = 0; i < importQueue.length; i += 1) {
            const queued = importQueue[i]
            if (!queued || typeof queued !== "object") continue
            if (String(queued.path || "") !== normalizedPath) continue
            if (String(queued.sourceType || "archive") !== normalizedSourceType) continue
            if (String(queued.filenameHint || "") !== normalizedFilenameHint) continue
            return i
        }
        return -1
    }

    function buildImportConflictContextFromPreview(previewData, queuedEntry) {
        const preview = previewData || ({})
        const queued = queuedEntry || ({})
        const conflictCode = String(preview.conflictCode || "duplicate").trim().toLowerCase() || "duplicate"
        const duplicateTier = String(preview.duplicateTier || "exact").trim().toLowerCase() || "exact"
        const existingId = Number(preview.existingId || 0)
        const meta = existingId > 0 && libraryModelRef ? libraryModelRef.loadComicMetadata(existingId) : ({})
        const storedOldFilePath = String(meta.filePath || "").trim()
        const resolvedOldFilePath = existingId > 0 && libraryModelRef
            ? String(libraryModelRef.archivePathForComic(existingId) || "").trim()
            : ""
        const sourcePath = String(preview.path || queued.path || "")
        const sourceType = String(preview.sourceType || queued.sourceType || "archive")
        const filenameHint = String(preview.filenameHint || queued.filenameHint || "")

        return {
            conflictCode: conflictCode,
            sourcePath: sourcePath,
            sourceType: sourceType,
            seriesOverride: String(queued.seriesOverride || ""),
            filenameHint: filenameHint,
            importIntent: String((queued.importIntent || ((queued.values || {}).importIntent) || "")).trim().toLowerCase(),
            importValues: cloneVariantMap(queued.values || ({})),
            duplicateTier: duplicateTier,
            existingId: existingId,
            existingFilename: String(meta.filename || "").trim(),
            existingVolume: String(meta.volume || "").trim(),
            oldFilePath: resolvedOldFilePath.length > 0 ? resolvedOldFilePath : storedOldFilePath,
            existingSeries: String(meta.series || "").trim(),
            existingIssue: String(meta.issueNumber || "").trim(),
            existingTitle: String(meta.title || "").trim(),
            oldImportSignals: {
                importOriginalFilename: String(meta.importOriginalFilename || "").trim(),
                importStrictFilenameSignature: String(meta.importStrictFilenameSignature || "").trim(),
                importLooseFilenameSignature: String(meta.importLooseFilenameSignature || "").trim(),
                importSourceType: String(meta.importSourceType || "").trim()
            },
            incomingLabel: fileNameFromPath(sourcePath),
            existingLabel: buildImportConflictExistingLabel(meta, existingId),
            fileSizeBytes: Math.max(0, Number(queued.fileSizeBytes || 0))
        }
    }

    function updateImportConflictBatchPreview(duplicateEntries) {
        importConflictNextContext = ({})
        importConflictNextIncomingLabel = ""
        importConflictNextExistingLabel = ""
        if (!libraryModelRef) return

        const nextDuplicate = libraryModelRef.previewPendingImportDuplicate(duplicateEntries, 1)
        const nextExistingId = Number((nextDuplicate || {}).existingId || 0)
        const nextPath = String((nextDuplicate || {}).path || "")
        if (nextExistingId < 1 || nextPath.length < 1) return

        const queuedIndex = findQueuedImportConflictEntryIndex(
            nextPath,
            String((nextDuplicate || {}).sourceType || "archive"),
            String((nextDuplicate || {}).filenameHint || "")
        )
        const queuedEntry = queuedIndex >= 0 ? importQueue[queuedIndex] : ({})
        importConflictNextContext = buildImportConflictContextFromPreview(nextDuplicate, queuedEntry)
        importConflictNextIncomingLabel = String(importConflictNextContext.incomingLabel || "")
        importConflictNextExistingLabel = String(importConflictNextContext.existingLabel || "")
    }

    function promoteNextImportConflict() {
        const nextContext = importConflictNextContext || ({})
        const nextPath = String(nextContext.sourcePath || "")
        if (nextPath.length < 1 || !libraryModelRef) return false

        const queuedIndex = findQueuedImportConflictEntryIndex(
            nextPath,
            String(nextContext.sourceType || "archive"),
            String(nextContext.filenameHint || "")
        )
        if (queuedIndex < 0) return false

        const queuedEntry = importQueue.splice(queuedIndex, 1)[0] || ({})
        const queuedSizeBytes = Math.max(0, Number(queuedEntry.fileSizeBytes || nextContext.fileSizeBytes || 0))

        importProcessed += 1

        const promotedContext = buildImportConflictContextFromPreview(nextContext, queuedEntry)
        importCurrentPath = String(promotedContext.sourcePath || "")
        importCurrentFileName = fileNameFromPath(importCurrentPath)
        importConflictContext = promotedContext
        importConflictIncomingLabel = String(promotedContext.incomingLabel || "")
        importConflictExistingLabel = String(promotedContext.existingLabel || "")

        if (importConflictSupportsBatchActions(importConflictContext)) {
            const duplicateEntries = buildPendingImportConflictEntries(importConflictContext)
            const duplicateCount = Number(libraryModelRef.countPendingImportDuplicates(duplicateEntries) || 0)
            importConflictBatchDuplicateCount = Math.max(1, duplicateCount)
            if (importConflictBatchDuplicateCount > 1) {
                updateImportConflictBatchPreview(duplicateEntries)
            } else {
                importConflictNextContext = ({})
                importConflictNextIncomingLabel = ""
                importConflictNextExistingLabel = ""
            }
        } else {
            importConflictBatchDuplicateCount = 1
            importConflictNextContext = ({})
            importConflictNextIncomingLabel = ""
            importConflictNextExistingLabel = ""
        }

        importPausedForConflict = true
        return true
    }

    function buildPendingImportConflictEntries(currentContext) {
        const entries = []
        const ctx = currentContext || ({})
        if (String(ctx.sourcePath || "").length > 0) {
            entries.push({
                path: String(ctx.sourcePath || ""),
                sourceType: String(ctx.sourceType || "archive"),
                seriesOverride: String(ctx.seriesOverride || ""),
                importIntent: String(ctx.importIntent || ((ctx.importValues || {}).importIntent) || "").trim().toLowerCase(),
                filenameHint: String(ctx.filenameHint || ""),
                values: cloneVariantMap(ctx.importValues)
            })
        }

        for (let i = 0; i < importQueue.length; i += 1) {
            const queued = importQueue[i]
            if (!queued || typeof queued !== "object") continue
            entries.push({
                path: String(queued.path || ""),
                sourceType: String(queued.sourceType || "archive"),
                seriesOverride: String(queued.seriesOverride || ""),
                importIntent: String(queued.importIntent || ((queued.values || {}).importIntent) || "").trim().toLowerCase(),
                filenameHint: String(queued.filenameHint || ""),
                values: cloneVariantMap(queued.values)
            })
        }
        return entries
    }

    function adoptExistingSeriesContextForSiblingQueuedEntries(conflictContext) {
        const ctx = conflictContext || ({})
        const existingSeries = String(ctx.existingSeries || "").trim()
        const sourceFolder = parentFolderPath(String(ctx.sourcePath || ""))
        const importIntent = String(ctx.importIntent || ((ctx.importValues || {}).importIntent) || "").trim().toLowerCase()
        if (existingSeries.length < 1 || sourceFolder.length < 1 || importIntent !== "global_add") {
            return false
        }

        let changed = false
        const nextQueue = []
        for (let i = 0; i < importQueue.length; i += 1) {
            const queued = importQueue[i]
            if (!queued || typeof queued !== "object") {
                nextQueue.push(queued)
                continue
            }

            const queuedFolder = parentFolderPath(String(queued.path || ""))
            const queuedIntent = String(queued.importIntent || ((queued.values || {}).importIntent) || "").trim().toLowerCase()
            if (queuedFolder !== sourceFolder || queuedIntent !== "global_add" || String(queued.seriesOverride || "").trim().length > 0) {
                nextQueue.push(queued)
                continue
            }

            const nextValues = cloneVariantMap(queued.values)
            const explicitSeries = String(nextValues.series || "").trim()
            const contextSeries = String(nextValues.importContextSeries || "").trim()
            if (explicitSeries.length > 0 || contextSeries.length > 0) {
                nextQueue.push(queued)
                continue
            }

            nextValues.importContextSeries = existingSeries
            nextQueue.push(Object.assign({}, queued, { values: nextValues }))
            changed = true
        }

        if (changed) {
            importQueue = nextQueue
        }
        return changed
    }

    function openImportConflictDialog(sourcePath, sourceType, seriesOverride, filenameHint, importValues, importResult) {
        importConflictContext = createImportConflictContext(sourcePath, sourceType, seriesOverride, filenameHint, importValues, importResult)
        importConflictIncomingLabel = String(importConflictContext.incomingLabel || "")
        importConflictExistingLabel = String(importConflictContext.existingLabel || "")

        if (importConflictSupportsBatchActions(importConflictContext)) {
            adoptExistingSeriesContextForSiblingQueuedEntries(importConflictContext)
        }

        if (importConflictSupportsBatchActions(importConflictContext) && libraryModelRef) {
            const duplicateEntries = buildPendingImportConflictEntries(importConflictContext)
            const duplicateCount = Number(libraryModelRef.countPendingImportDuplicates(duplicateEntries) || 0)
            importConflictBatchDuplicateCount = Math.max(1, duplicateCount)
            if (importConflictBatchDuplicateCount > 1) {
                updateImportConflictBatchPreview(duplicateEntries)
            } else {
                importConflictNextContext = ({})
                importConflictNextIncomingLabel = ""
                importConflictNextExistingLabel = ""
            }
        } else {
            importConflictBatchDuplicateCount = 1
            importConflictNextContext = ({})
            importConflictNextIncomingLabel = ""
            importConflictNextExistingLabel = ""
        }

        importPausedForConflict = true
        openExclusivePopup(importConflictDialogRef)
    }

    function clearImportConflictState() {
        importPausedForConflict = false
        importConflictActionTimer.stop()
        if (importConflictDialogRef && typeof importConflictDialogRef.close === "function") {
            importConflictDialogRef.close()
        }
        importConflictContext = ({})
        importConflictNextContext = ({})
        importConflictIncomingLabel = ""
        importConflictExistingLabel = ""
        importConflictNextIncomingLabel = ""
        importConflictNextExistingLabel = ""
        importConflictBatchAction = ""
        importConflictBatchDuplicateCount = 0
        importConflictOperationActive = false
        importConflictPendingAction = ""
        importConflictProgressCurrentFileName = ""
        importConflictProgressProcessedCount = 0
        importConflictProgressTotalCount = 0
    }

    function currentImportConflictIncomingLabel(context) {
        const ctx = context || ({})
        const labeled = String(ctx.incomingLabel || "").trim()
        if (labeled.length > 0) return labeled
        return fileNameFromPath(String(ctx.sourcePath || ""))
    }

    function resumeImportAfterConflict() {
        clearImportConflictState()
        if (importCancelRequested) {
            finishImportBatch(true)
            return
        }
        if (importQueue.length < 1) {
            finishImportBatch(false)
            return
        }
        importBatchTimer.start()
    }

    function applyImportConflictChoice(choice, context) {
        const action = String(choice || "").toLowerCase()
        const ctx = context || ({})
        const sourcePath = String(ctx.sourcePath || "")
        const sourceType = String(ctx.sourceType || "archive")
        const seriesOverride = String(ctx.seriesOverride || "")
        const importIntent = String(ctx.importIntent || ((ctx.importValues || {}).importIntent) || "").trim().toLowerCase()
        const baseImportValues = cloneVariantMap(ctx.importValues)
        const existingId = Number(ctx.existingId || 0)
        const existingFilename = String(ctx.existingFilename || "")
        const existingSeries = String(ctx.existingSeries || "")
        const existingVolume = String(ctx.existingVolume || "")
        const existingIssue = String(ctx.existingIssue || "")

        if (sourcePath.length < 1 || !libraryModelRef) return false
        if (action === "skip" || action === "keep_current" || action === "keep_existing" || action === "skip_all") {
            advanceCompletedImportBytes(ctx.fileSizeBytes)
            return true
        }

        const importValues = cloneVariantMap(baseImportValues)
        importValues.deferReload = true
        if (importIntent.length > 0) {
            importValues.importIntent = importIntent
        }
        if (seriesOverride.length > 0) {
            importValues.importContextSeries = seriesOverride
            importValues.series = seriesOverride
            const sourceBaseName = baseNameWithoutExtension(sourcePath)
            if (sourceBaseName.length > 0) {
                importValues.title = sourceBaseName
            }
        }

        let result = ({})
        if (action === "replace" || action === "replace_all") {
            if (existingId < 1) {
                pushImportFailure(sourcePath, "Replace failed: existing issue is not available.", "runtime_error")
                advanceCompletedImportBytes(ctx.fileSizeBytes)
                return false
            }

            const targetHint = existingFilename.length > 0 ? existingFilename : ""
            const oldFilePath = String(ctx.oldFilePath || "")
            const oldImportSignals = cloneVariantMap(ctx.oldImportSignals)
            if (oldFilePath.length < 1) {
                pushImportFailure(sourcePath, "Replace failed: existing archive path is missing.", "runtime_error")
                advanceCompletedImportBytes(ctx.fileSizeBytes)
                return false
            }

            const replaceValues = {
                deferReload: true,
                keepBackupForRollback: true,
                series: existingSeries,
                volume: existingVolume,
                issueNumber: existingIssue
            }
            result = libraryModelRef.replaceComicFileFromSourceEx(existingId, sourcePath, sourceType, targetHint, replaceValues)
            if (Boolean((result || {}).ok)) {
                const backupPath = String((result || {}).backupPath || "")
                if (backupPath.length > 0) {
                    importPendingOldFileDeletes.push(backupPath)
                }
                registerBatchRollbackOp(result, "replace", {
                    newFilePath: String((result || {}).filePath || ""),
                    oldFilePath: oldFilePath,
                    oldFilename: existingFilename,
                    backupFilePath: backupPath,
                    oldImportSignals: oldImportSignals
                })
            }
        } else if (action === "restore_existing") {
            if (existingId < 1) {
                pushImportFailure(sourcePath, "Restore failed: matching issue is not available.", "runtime_error")
                advanceCompletedImportBytes(ctx.fileSizeBytes)
                return false
            }
            importValues.allowWeakMetadataRestore = true
            importValues.restoreCandidateId = existingId
            result = libraryModelRef.importSourceAndCreateIssueEx(sourcePath, sourceType, String(ctx.filenameHint || ""), importValues)
            if (Boolean((result || {}).ok)) {
                registerBatchRollbackOp(result, "", { newFilePath: String((result || {}).filePath || "") })
            }
        } else if (action === "import_as_new") {
            importValues.duplicateDecision = "import_as_new"
            result = libraryModelRef.importSourceAndCreateIssueEx(sourcePath, sourceType, String(ctx.filenameHint || ""), importValues)
            if (Boolean((result || {}).ok)) {
                registerBatchRollbackOp(result, "", { newFilePath: String((result || {}).filePath || "") })
            }
        } else {
            return false
        }

        if (!Boolean((result || {}).ok)) {
            pushImportFailure(
                sourcePath,
                String((result || {}).error || "Import action failed."),
                String((result || {}).code || "runtime_error")
            )
            advanceCompletedImportBytes(ctx.fileSizeBytes)
            return false
        }

        importImportedCount += 1
        rememberLastImportComicId(Number((result || {}).comicId || 0))
        advanceCompletedImportBytes(ctx.fileSizeBytes)
        return true
    }

    function queueImportConflictAction(choice) {
        const action = String(choice || "").toLowerCase()
        importConflictPendingAction = action
        importConflictOperationActive = true
        importConflictProgressCurrentFileName = currentImportConflictIncomingLabel(importConflictContext)
        importConflictProgressProcessedCount = 0
        importConflictProgressTotalCount = (action === "replace_all" || action === "skip_all")
            ? Math.max(1, Number(importConflictBatchDuplicateCount || 1))
            : 1
        importConflictActionTimer.start()
    }

    function executePendingImportConflictAction() {
        const action = String(importConflictPendingAction || "").toLowerCase()
        if (action.length < 1) return

        importConflictProgressCurrentFileName = currentImportConflictIncomingLabel(importConflictContext)
        const success = applyImportConflictChoice(action, importConflictContext || {})
        if (success) {
            importConflictProgressProcessedCount += 1
        }

        if (action === "replace_all" || action === "skip_all") {
            if (success && promoteNextImportConflict()) {
                importConflictActionTimer.start()
                return
            }
            importConflictOperationActive = false
            importConflictPendingAction = ""
            importConflictProgressCurrentFileName = ""
            importConflictProgressProcessedCount = 0
            importConflictProgressTotalCount = 0
            resumeImportAfterConflict()
            return
        }

        importConflictOperationActive = false
        importConflictPendingAction = ""
        importConflictProgressCurrentFileName = ""
        importConflictProgressProcessedCount = 0
        importConflictProgressTotalCount = 0

        if (success && promoteNextImportConflict()) return
        resumeImportAfterConflict()
    }

    function resolveImportConflict(choice) {
        const action = String(choice || "").toLowerCase()
        if (action === "skip_all" || action === "replace_all") {
            importConflictBatchAction = action
        }
        if (action === "replace" || action === "replace_all" || action === "skip_all" || action === "import_as_new") {
            queueImportConflictAction(action)
            return
        }

        const success = applyImportConflictChoice(action, importConflictContext || {})
        if (success && (action === "keep_current" || action === "skip")) {
            if (promoteNextImportConflict()) return
        }
        resumeImportAfterConflict()
    }

    function prepareImportQueue(paths, options) {
        const queue = []
        const seen = {}
        const batchSeriesOverride = String((options && options.seriesOverride) ? options.seriesOverride : "").trim()
        const batchImportIntent = String((options && options.importIntent) ? options.importIntent : "").trim().toLowerCase()
        if (!paths || paths.length < 1) return queue

        for (let i = 0; i < paths.length; i += 1) {
            let rawPath = paths[i]
            let entrySeriesOverride = batchSeriesOverride
            let entryImportIntent = batchImportIntent
            let entryFilenameHint = ""
            let entrySourceType = "archive"
            let entryValues = ({})
            let entrySizeBytes = 0

            if (rawPath && typeof rawPath === "object") {
                entrySeriesOverride = String(rawPath.seriesOverride || entrySeriesOverride).trim()
                entryImportIntent = String(rawPath.importIntent || entryImportIntent).trim().toLowerCase()
                entryFilenameHint = String(rawPath.filenameHint || "").trim()
                entrySourceType = String(rawPath.sourceType || entrySourceType).trim().toLowerCase() || "archive"
                entryValues = cloneVariantMap(rawPath.values)
                entrySizeBytes = Math.max(0, Number(rawPath.fileSizeBytes || 0))
                rawPath = rawPath.path
            }

            const normalized = normalizeImportPath(rawPath)
            if (normalized.length < 1) continue
            const dedupeKey = entrySourceType + "|" + normalized.toLowerCase()
            if (seen[dedupeKey] === true) continue
            seen[dedupeKey] = true
            if (entrySizeBytes < 1 && entrySourceType === "archive") {
                entrySizeBytes = fileSizeBytes(normalized)
            }
            queue.push({
                path: normalized,
                sourceType: entrySourceType,
                seriesOverride: entrySeriesOverride,
                importIntent: entryImportIntent,
                filenameHint: entryFilenameHint,
                values: entryValues,
                fileSizeBytes: entrySizeBytes
            })
        }
        return queue
    }

    function startImportBatch(paths, options) {
        const queue = prepareImportQueue(paths, options)
        if (queue.length < 1) {
            showActionResult(AppText.importNoValidFilesSelected, true)
            return false
        }
        if (importInProgress) {
            showActionResult(AppText.importAlreadyRunning, true)
            return false
        }

        closeAllModalPopups(null)
        resetLastImportSessionState()
        captureImportSeriesFocusBaseline()
        importInProgress = true
        importLifecycleState = "running"
        importConflictActionTimer.stop()
        importQueue = queue
        importTotal = queue.length
        importProcessed = 0

        let totalBytes = 0
        for (let i = 0; i < queue.length; i += 1) {
            const item = queue[i] || {}
            totalBytes += Math.max(0, Number(item.fileSizeBytes || 0))
        }

        importTotalBytes = totalBytes
        importProcessedBytes = 0
        importImportedCount = 0
        importErrorCount = 0
        importCancelRequested = false
        importCurrentPath = String((queue[0] || {}).path || "")
        importCurrentFileName = fileNameFromPath(importCurrentPath)
        importBatchRollbackOps = []
        importPendingOldFileDeletes = []
        resetImportConflictState(false)
        resetImportCleanupState()
        importErrors = []
        importFailedPaths = []
        clearPendingImportStepContext()
        importBatchTimer.start()
        return true
    }

    function rebuildFailedImportItemsModel() {
        if (!failedImportItemsModelRef) return
        failedImportItemsModelRef.clear()
        const maxCount = Math.min(lastFailedImportPaths.length, lastFailedImportErrors.length)
        for (let i = 0; i < maxCount; i += 1) {
            const path = String(lastFailedImportPaths[i] || "")
            const fileName = fileNameFromPath(path)
            failedImportItemsModelRef.append({
                path: path,
                fileName: fileName.length > 0 ? fileName : AppText.importFailedUnknownFile,
                error: String(lastFailedImportErrors[i] || "")
            })
        }
    }

    function processImportBatchStep() {
        try {
            if (!importInProgress) {
                importBatchTimer.stop()
                return
            }
            if (importPausedForConflict) {
                importBatchTimer.stop()
                return
            }
            if (importCancelRequested) {
                importQueue = []
                beginImportCleanup()
                return
            }
            if (importQueue.length < 1) {
                finishImportBatch(false)
                return
            }

            const queued = importQueue.shift()
            let sourcePath = ""
            let sourceType = "archive"
            let seriesOverride = ""
            let importIntent = ""
            let filenameHint = ""
            let queuedValues = ({})
            let queuedFileSizeBytes = 0
            if (typeof queued === "string") {
                sourcePath = String(queued || "")
            } else if (queued && typeof queued === "object") {
                sourcePath = String(queued.path || "")
                sourceType = String(queued.sourceType || "archive").trim().toLowerCase() || "archive"
                seriesOverride = String(queued.seriesOverride || "").trim()
                importIntent = String(queued.importIntent || "").trim().toLowerCase()
                filenameHint = String(queued.filenameHint || "").trim()
                queuedValues = cloneVariantMap(queued.values)
                queuedFileSizeBytes = Math.max(0, Number(queued.fileSizeBytes || 0))
            }

            if (queuedFileSizeBytes < 1 && sourcePath.length > 0) {
                queuedFileSizeBytes = fileSizeBytes(sourcePath)
            }

            importProcessed += 1
            importCurrentPath = sourcePath
            importCurrentFileName = fileNameFromPath(sourcePath)

            if (sourceType === "archive") {
                const unsupportedReason = archiveUnsupportedReason(sourcePath)
                if (unsupportedReason.length > 0) {
                    pushImportFailure(sourcePath, unsupportedReason, "unsupported_format")
                    advanceCompletedImportBytes(queuedFileSizeBytes)
                    if (importQueue.length < 1) finishImportBatch(false)
                    return
                }
            }

            const importValues = cloneVariantMap(queuedValues)
            importValues.deferReload = true
            if (importIntent.length > 0) {
                importValues.importIntent = importIntent
            }
            if (seriesOverride.length > 0) {
                importValues.importContextSeries = seriesOverride
                importValues.series = seriesOverride
                const sourceBaseName = baseNameWithoutExtension(sourcePath)
                if (sourceBaseName.length > 0) {
                    importValues.title = sourceBaseName
                }
            }

            if (!libraryModelRef) {
                pushImportFailure(sourcePath, AppText.importModelUnavailable, "runtime_error")
                advanceCompletedImportBytes(queuedFileSizeBytes)
                finishImportBatch(false)
                return
            }
            if (sourceType === "archive" && typeof libraryModelRef.requestNormalizeImportArchiveAsync === "function") {
                importPendingStepContext = {
                    sourcePath: sourcePath,
                    sourceType: sourceType,
                    seriesOverride: seriesOverride,
                    filenameHint: filenameHint,
                    importValues: cloneVariantMap(importValues),
                    queuedFileSizeBytes: queuedFileSizeBytes
                }
                importArchiveNormalizationRequestId = Number(
                    libraryModelRef.requestNormalizeImportArchiveAsync(sourcePath) || -1
                )
                if (importArchiveNormalizationRequestId > 0) {
                    importBatchTimer.stop()
                    return
                }
                clearPendingImportStepContext()
            }

            const result = libraryModelRef.importSourceAndCreateIssueEx(sourcePath, sourceType, filenameHint, importValues)
            finalizeImportStepResult(sourcePath, queuedFileSizeBytes, result, "", false, ({
                sourceType: sourceType,
                seriesOverride: seriesOverride,
                filenameHint: filenameHint,
                importValues: cloneVariantMap(importValues)
            }))
        } catch (e) {
            pushImportFailure("[runtime]", AppText.importRuntimeErrorPrefix + String(e), "runtime_error")
            finishImportBatch(false)
        }
    }

    function cancelImportBatch() {
        if (!importInProgress || importCancelRequested || importCleanupActive) return
        importCancelRequested = true
        importLifecycleState = "cancelling"
        if (importPausedForConflict) {
            beginImportCleanup()
        }
    }

    function dismissFailedImportAt(index) {
        if (index < 0 || index >= lastFailedImportPaths.length) return

        const nextPaths = []
        const nextErrors = []
        for (let i = 0; i < lastFailedImportPaths.length; i += 1) {
            if (i === index) continue
            nextPaths.push(lastFailedImportPaths[i])
            nextErrors.push(lastFailedImportErrors[i])
        }

        lastFailedImportPaths = nextPaths
        lastFailedImportErrors = nextErrors
        rebuildFailedImportItemsModel()
        if (failedImportItemsModelRef && failedImportItemsModelRef.count < 1 && failedImportsDialogRef && failedImportsDialogRef.visible) {
            failedImportsDialogRef.close()
        }
    }

    function skipFailedImportAt(index) {
        dismissFailedImportAt(index)
    }

    function skipAllFailedImports() {
        lastFailedImportPaths = []
        lastFailedImportErrors = []
        rebuildFailedImportItemsModel()
        if (failedImportsDialogRef && failedImportsDialogRef.visible) {
            failedImportsDialogRef.close()
        }
    }

    function retryFailedImportAt(index) {
        if (importInProgress) return
        if (index < 0 || index >= lastFailedImportPaths.length || !libraryModelRef) return

        const sourcePath = String(lastFailedImportPaths[index] || "")
        if (sourcePath.length < 1) return

        const resolvedEntries = resolveImportSourceEntries([sourcePath])
        if (!resolvedEntries || resolvedEntries.length !== 1) {
            const classifiedMissing = classifyImportError(sourcePath, AppText.importRetrySourceMissing, "file_not_found")
            lastFailedImportErrors[index] = classifiedMissing.reason
            rebuildFailedImportItemsModel()
            return
        }

        const resolvedEntry = resolvedEntries[0] || ({})
        const resolvedSourcePath = String(resolvedEntry.path || sourcePath)
        const resolvedSourceType = String(resolvedEntry.sourceType || "archive").trim().toLowerCase() || "archive"
        if (resolvedSourceType === "archive") {
            const unsupportedReason = archiveUnsupportedReason(resolvedSourcePath)
            if (unsupportedReason.length > 0) {
                const classifiedUnsupported = classifyImportError(resolvedSourcePath, unsupportedReason, "unsupported_format")
                lastFailedImportErrors[index] = classifiedUnsupported.reason
                rebuildFailedImportItemsModel()
                return
            }
        }

        const result = libraryModelRef.importSourceAndCreateIssueEx(
            resolvedSourcePath,
            resolvedSourceType,
            "",
            { importIntent: "global_add" }
        )
        if (!Boolean((result || {}).ok)) {
            const classifiedResult = classifyImportError(
                resolvedSourcePath,
                String((result || {}).error || "Import failed."),
                String((result || {}).code || "")
            )
            lastFailedImportErrors[index] = classifiedResult.reason
            rebuildFailedImportItemsModel()
            return
        }

        dismissFailedImportAt(index)
    }

    function importSourceEntries(paths, options) {
        return startImportBatch(paths, options)
    }

    function importArchivePaths(paths, options) {
        return importSourceEntries(paths, options)
    }

    Connections {
        target: libraryModelRef

        function onNormalizeImportArchiveFinished(requestId, result) {
            if (Number(requestId || -1) !== Number(importArchiveNormalizationRequestId || -1)) return

            const context = importPendingStepContext || ({})
            clearPendingImportStepContext()

            const sourcePath = String(context.sourcePath || "")
            const queuedFileSizeBytes = Math.max(0, Number(context.queuedFileSizeBytes || 0))
            const normalizationResult = result || ({})
            const normalizedPath = String(normalizationResult.normalizedPath || "")
            const temporaryFile = Boolean(normalizationResult.temporaryFile)

            if (importCancelRequested) {
                cleanupTemporaryNormalizedArchive(normalizedPath, temporaryFile)
                beginImportCleanup()
                return
            }

            if (!Boolean(normalizationResult.ok)) {
                pushImportFailure(
                    sourcePath,
                    String(normalizationResult.error || AppText.importPreparationFailed),
                    String(normalizationResult.code || "archive_normalize_failed")
                )
                advanceCompletedImportBytes(queuedFileSizeBytes)
                cleanupTemporaryNormalizedArchive(normalizedPath, temporaryFile)
                if (importQueue.length < 1) {
                    finishImportBatch(false)
                } else {
                    importBatchTimer.start()
                }
                return
            }

            if (!libraryModelRef) {
                pushImportFailure(sourcePath, AppText.importModelUnavailable, "runtime_error")
                advanceCompletedImportBytes(queuedFileSizeBytes)
                cleanupTemporaryNormalizedArchive(normalizedPath, temporaryFile)
                finishImportBatch(false)
                return
            }

            const effectiveFilenameHint = String(context.filenameHint || "").trim().length > 0
                ? String(context.filenameHint || "").trim()
                : String(normalizationResult.filenameHint || fileNameFromPath(sourcePath))
            const importValues = cloneVariantMap(context.importValues)
            importValues.importHistorySourcePath = sourcePath
            importValues.importHistorySourceLabel = fileNameFromPath(sourcePath)

            const importResult = libraryModelRef.importSourceAndCreateIssueEx(
                normalizedPath,
                "archive",
                effectiveFilenameHint,
                importValues
            )
            finalizeImportStepResult(
                sourcePath,
                queuedFileSizeBytes,
                importResult,
                normalizedPath,
                temporaryFile,
                context
            )
        }
    }

    Timer {
        id: importBatchTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: controller.processImportBatchStep()
    }

    Timer {
        id: importConflictActionTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: controller.executePendingImportConflictAction()
    }

    Timer {
        id: importCleanupTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: {
            if (!controller.importCleanupActive) return

            if (!controller.importCleanupQueue || controller.importCleanupQueue.length < 1) {
                controller.finalizeImportBatch(true)
                return
            }

            const nextQueue = controller.importCleanupQueue.slice(0)
            const op = nextQueue.shift() || ({})
            controller.importCleanupQueue = nextQueue
            controller.importCleanupCurrentFileName = controller.rollbackDisplayName(op)
            controller.rollbackSingleImportOp(op)
            controller.importCleanupProcessedCount += 1

            if (controller.importCleanupQueue.length < 1) {
                controller.finalizeImportBatch(true)
                return
            }

            controller.importCleanupCurrentFileName = controller.rollbackDisplayName(
                controller.importCleanupQueue[0] || ({})
            )
            importCleanupTimer.restart()
        }
    }
}
