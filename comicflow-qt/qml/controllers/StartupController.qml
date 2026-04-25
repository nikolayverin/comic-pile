import QtQuick

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property bool startupInteractiveLogged: false
    property bool startupVisuallyStableLogged: false
    property string startupVisualStabilityReason: ""
    property string startupVisualStabilityDetails: ""
    property string pendingUiReadyMode: ""
    property string pendingUiReadyStateTag: ""
    property string pendingUiStableReason: ""
    property string pendingUiStableDetails: ""

    property var rootObject: null
    property var libraryModelRef: null
    property var heroSeriesControllerRef: null
    property var windowDisplayControllerRef: null
    property var appContentLayout: null
    property var seriesListModel: null
    property var seriesListView: null
    property var issuesFlick: null
    property var launchStateRef: (typeof appLaunchState !== "undefined") ? appLaunchState : null
    property bool startupInitialLoadRequested: false
    property bool startupDelayedInventoryCheckScheduled: false
    property int startupStorageMigrationDelayMs: 250
    property bool startupStorageMigrationScheduled: false
    property bool startupStorageMigrationInProgress: false
    property int startupStorageMigrationRequestId: 0
    property bool startupWindowStateRestored: false

    StartupTelemetryController {
        id: startupTelemetry
        rootObject: controller.rootObject
        libraryModelRef: controller.libraryModelRef
        windowDisplayControllerRef: controller.windowDisplayControllerRef
        seriesListModelRef: controller.seriesListModel
        startupVisuallyStableLogged: controller.startupVisuallyStableLogged
        startupWindowStateRestored: controller.startupWindowStateRestored
    }

    StartupSnapshotController {
        id: startupSnapshotController
        startupControllerRef: controller
        rootObject: controller.rootObject
        libraryModelRef: controller.libraryModelRef
        heroSeriesControllerRef: controller.heroSeriesControllerRef
        windowDisplayControllerRef: controller.windowDisplayControllerRef
        appContentLayout: controller.appContentLayout
        seriesListModel: controller.seriesListModel
        seriesListView: controller.seriesListView
        issuesFlick: controller.issuesFlick
    }

    function startupLog(message) { startupTelemetry.startupLog(message) }

    function startupStep(stepName, details) { startupTelemetry.startupStep(stepName, details) }

    function trackingLog(message) { startupTelemetry.trackingLog(message) }

    function logWindowTrackingState(tag) { startupTelemetry.logWindowTrackingState(tag) }

    function launchLog(message) { startupTelemetry.launchLog(message) }

    function runtimeDebugLog(category, message) { startupTelemetry.runtimeDebugLog(category, message) }

    function windowVisibilityLabel(visibilityValue) { return startupTelemetry.windowVisibilityLabel(visibilityValue) }

    function shouldTraceWindowState() { return startupTelemetry.shouldTraceWindowState() }

    function traceWindowState(tag, details) { startupTelemetry.traceWindowState(tag, details) }

    function revealPrimaryStartupContent() {
        const root = rootObject
        if (!root || root.startupPrimaryContentReady) return
        root.startupPrimaryContentReady = true
        launchLog("startup_primary_content_revealed")
        traceWindowState("primary_content_revealed")
    }

    function markStartupInteractive(reason, details) {
        const root = rootObject
        if (!root || startupInteractiveLogged) return
        startupInteractiveLogged = true

        let message = "STARTUP_INTERACTIVE reason=" + String(reason || "unknown")
        const detailsText = String(details || "").trim()
        if (detailsText.length > 0) {
            message += " " + detailsText
        }
        message += " libraryLoading=" + String(root.libraryLoading)
        message += " snapshotApplied=" + String(root.startupSnapshotApplied)
        message += " reconcileCompleted=" + String(root.startupReconcileCompleted)
        startupLog(message)
    }

    function scheduleStartupVisuallyStable(reason, details) {
        const root = rootObject
        if (!root || startupVisuallyStableLogged) return
        startupVisualStabilityReason = String(reason || "unknown")
        startupVisualStabilityDetails = String(details || "").trim()
        if (!root.startupResultLogged) {
            return
        }
        startupVisualStabilityTimer.restart()
    }

    function isRootWindowVisible() {
        return Boolean(launchStateRef && launchStateRef.rootWindowVisible)
    }

    function queueUiReady(mode, stateTag, stableReason, stableDetails) {
        pendingUiReadyMode = String(mode || "")
        pendingUiReadyStateTag = String(stateTag || "")
        pendingUiStableReason = String(stableReason || "")
        pendingUiStableDetails = String(stableDetails || "").trim()
        flushPendingUiReady()
    }

    function flushPendingUiReady() {
        const root = rootObject
        if (!root || root.startupResultLogged) return
        if (pendingUiReadyMode.length < 1 || !isRootWindowVisible()) return

        root.startupResultLogged = true
        launchLog("ui_ready mode=" + pendingUiReadyMode)
        if (pendingUiReadyStateTag.length > 0) {
            logStartupUiState(pendingUiReadyStateTag)
        }

        const stableReason = pendingUiStableReason
        const stableDetails = pendingUiStableDetails
        pendingUiReadyMode = ""
        pendingUiReadyStateTag = ""
        pendingUiStableReason = ""
        pendingUiStableDetails = ""
        scheduleStartupVisuallyStable(stableReason, stableDetails)
    }

    function markStartupVisuallyStable() {
        const root = rootObject
        if (!root || startupVisuallyStableLogged) return
        traceWindowState("ui_stable")
        startupVisuallyStableLogged = true
        startupPrimaryContentRevealTimer.restart()

        let message = "ui_stable"
        if (startupVisualStabilityReason.length > 0) {
            message += " reason=" + startupVisualStabilityReason
        }
        launchLog(message)

        if (
            root.startupFirstFrameSource === "snapshot"
                && root.startupSnapshotApplied
                && !startupDelayedInventoryCheckScheduled
                && !root.startupInventoryCheckInProgress
                && !root.startupInventoryRebuildInProgress
        ) {
            startupDelayedInventoryCheckScheduled = true
            startupStep(
                "startup_inventory_check_scheduled",
                "delayMs=" + String(root.startupInventoryCheckDelayMs)
            )
            startupInventoryCheckDelayTimer.interval = root.startupInventoryCheckDelayMs
            startupInventoryCheckDelayTimer.restart()
        }

        if (
            libraryModelRef
                && !startupStorageMigrationScheduled
                && !startupStorageMigrationInProgress
                && libraryModelRef.isLibraryStorageMigrationPending()
        ) {
            startupStorageMigrationScheduled = true
            startupStorageMigrationDelayTimer.interval = startupStorageMigrationDelayMs
            startupStorageMigrationDelayTimer.restart()
        }
    }

    function beginDeferredStartupInventoryCheck(reason) {
        const root = rootObject
        if (!root || !libraryModelRef || root.startupFirstFrameSource !== "snapshot") return
        if (root.startupInventoryCheckInProgress || root.startupInventoryRebuildInProgress) return
        root.startupInventoryCheckInProgress = true
        root.startupInventoryCheckRequestId = Number(libraryModelRef.requestStartupInventorySignatureAsync() || 0)
        launchLog(
            "inventory_check_begin"
            + " requestId=" + String(root.startupInventoryCheckRequestId)
            + " reason=" + String(reason || "delayed")
        )
    }

    function beginDeferredLibraryStorageMigration(reason) {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (startupStorageMigrationInProgress) return
        if (!libraryModelRef.isLibraryStorageMigrationPending()) return

        startupStorageMigrationScheduled = true
        startupStorageMigrationInProgress = true
        startupStorageMigrationRequestId = Number(libraryModelRef.requestLibraryStorageMigrationAsync() || 0)
        launchLog(
            "storage_migration_begin"
            + " requestId=" + String(startupStorageMigrationRequestId)
            + " reason=" + String(reason || "post_ui_stable")
        )
    }

    function normalizedInventorySignatureKey(signature) {
        const source = signature && typeof signature === "object" ? signature : {}
        const rawKey = String(source.signatureKey || "").trim()
        const libTokenIndex = rawKey.indexOf("|lib:")
        if (libTokenIndex >= 0) {
            return rawKey.slice(libTokenIndex + 1)
        }
        if (rawKey.startsWith("lib:")) {
            return rawKey
        }

        if (
            Object.prototype.hasOwnProperty.call(source, "libraryExists")
                || Object.prototype.hasOwnProperty.call(source, "libraryFileCount")
                || Object.prototype.hasOwnProperty.call(source, "libraryTotalBytes")
                || Object.prototype.hasOwnProperty.call(source, "libraryLatestModifiedMs")
        ) {
            return "lib:"
                + String(Boolean(source.libraryExists) ? 1 : 0)
                + ":" + String(Number(source.libraryFileCount || 0))
                + ":" + String(Number(source.libraryTotalBytes || 0))
                + ":" + String(
                    Number(
                        Object.prototype.hasOwnProperty.call(source, "libraryLatestModifiedMs")
                            ? source.libraryLatestModifiedMs
                            : -1
                    )
                )
        }

        return rawKey
    }

    function handleStartupDbHealthResult(health) {
        const root = rootObject
        if (!root) return
        const ok = Boolean((health || {}).ok)
        const code = String((health || {}).code || "unknown")
        const message = String((health || {}).message || "").trim()
        const dbPath = String((health || {}).dbPath || "")
        startupLog(
            "db_health ok=" + String(ok)
            + " code=" + code
            + " dbPath=" + dbPath
            + " message=\"" + message + "\""
        )
        if (ok) {
            root.startupDbHealthWarningCode = ""
            root.startupDbHealthWarningMessage = ""
            root.startupDbHealthWarningVisible = false
            return
        }

        root.startupDbHealthWarningCode = code
        root.startupDbHealthWarningMessage = message.length > 0
            ? message
            : "Database check reported a problem."
        root.startupDbHealthWarningVisible = true
    }

    function runStartupDbHealthCheckAsync() {
        const root = rootObject
        if (!root || !libraryModelRef) return
        root.startupDbHealthRequestId = Number(libraryModelRef.requestDatabaseHealthCheckAsync() || 0)
        startupLog("db_health async_requested id=" + String(root.startupDbHealthRequestId))
    }

    function logStartupUiState(tag) { startupTelemetry.logStartupUiState(tag) }

    function toLocalFileUrl(pathValue) { return startupSnapshotController.toLocalFileUrl(pathValue) }

    function requestSnapshotSave() { startupSnapshotController.requestSnapshotSave() }

    function scheduleStartupPreviewCapture() { startupSnapshotController.scheduleStartupPreviewCapture() }

    function captureStartupPreviewFrame(finalizeClose) { startupSnapshotController.captureStartupPreviewFrame(finalizeClose) }

    function applyWindowSnapshot(parsed) { startupSnapshotController.applyWindowSnapshot(parsed) }

    function applyDeferredWindowState() { startupSnapshotController.applyDeferredWindowState() }

    function issueListsEquivalentByIdAndOrder(leftList, rightList) {
        return startupSnapshotController.issueListsEquivalentByIdAndOrder(leftList, rightList)
    }

    function saveStartupSnapshot() { startupSnapshotController.saveStartupSnapshot() }

    function applyStartupScrollSnapshot() { startupSnapshotController.applyStartupScrollSnapshot() }

    function restoreStartupSnapshot() { return startupSnapshotController.restoreStartupSnapshot() }

    function reconcileFromModel() {
        const root = rootObject
        if (!root || !libraryModelRef || !seriesListModel) return

        root.modelReconcilePending = false
        startupLog(
            "reconcileFromModel begin totalCount=" + String(Number(libraryModelRef.totalCount || 0))
            + " snapshotApplied=" + String(root.startupSnapshotApplied)
            + " hydrationInProgress=" + String(root.startupHydrationInProgress)
        )

        if (
            root.startupHydrationInProgress
                && root.startupSnapshotApplied
                && libraryModelRef.lastError.length < 1
                && Number(libraryModelRef.totalCount || 0) < 1
        ) {
            if (root.startupHydrationAttemptCount < root.startupHydrationMaxDeferredAttempts) {
                root.startupHydrationAttemptCount += 1
                startupLog(
                    "reconcile deferred attempt=" + String(root.startupHydrationAttemptCount)
                    + " retryDelayMs=" + String(root.startupHydrationRetryDelayMs)
                )
                modelReconcileTimer.interval = root.startupHydrationRetryDelayMs
                modelReconcileTimer.restart()
                return
            }

            startupLog("reconcile retries exhausted: trust live empty model and clear restored snapshot")
            root.startupHydrationInProgress = false
        }

        root.startupHydrationAttemptCount = 0
        modelReconcileTimer.interval = 50
        root.suspendSelectionDrivenRefresh = true
        try {
            root.refreshCbrSupportState()
            root.refreshSeriesList()
            root.refreshIssuesGridData()
            root.startupReconcileCompleted = true
            root.startupHydrationInProgress = false
            root.startupInventoryRebuildInProgress = false
            if (root.startupPendingInventorySignature && typeof root.startupPendingInventorySignature === "object") {
                root.startupInventorySignature = root.startupPendingInventorySignature
            }
            root.showStartupPreview = false
            root.warmVisibleIssueThumbnails()
            requestSnapshotSave()
            scheduleStartupPreviewCapture()
            startupLog(
                "reconcile complete seriesCount=" + String(seriesListModel.count)
                + " issuesCount=" + String(root.issuesGridData.length)
                + " selectedSeriesKey=" + String(root.selectedSeriesKey)
            )
            markStartupInteractive(
                root.startupFirstFrameSource === "snapshot" ? "reconcile_after_snapshot" : "live_reconcile",
                "seriesCount=" + String(seriesListModel.count)
                + " issuesCount=" + String(root.issuesGridData.length)
            )
            if (!root.startupResultLogged) {
                const mode = root.startupFirstFrameSource === "snapshot"
                    ? "snapshot_reconcile"
                    : "live_model_fallback"
                queueUiReady(
                    mode,
                    "reconcile_complete",
                    root.startupFirstFrameSource === "snapshot"
                        ? "reconcile_after_snapshot"
                        : "live_reconcile",
                    "seriesCount=" + String(seriesListModel.count)
                    + " issuesCount=" + String(root.issuesGridData.length)
                )
            }
            flushPendingUiReady()
            scheduleStartupVisuallyStable(
                root.startupFirstFrameSource === "snapshot"
                    ? "reconcile_after_snapshot"
                    : "live_reconcile",
                "seriesCount=" + String(seriesListModel.count)
                + " issuesCount=" + String(root.issuesGridData.length)
            )
        } finally {
            root.suspendSelectionDrivenRefresh = false
        }
    }

    function scheduleModelReconcile(immediate) {
        if (immediate === true) {
            modelReconcileTimer.stop()
            reconcileFromModel()
            return
        }
        const root = rootObject
        if (!root) return
        root.modelReconcilePending = true
        modelReconcileTimer.restart()
    }

    function requestInitialModelLoad(reason) {
        const root = rootObject
        if (!root || !libraryModelRef || startupInitialLoadRequested) return
        startupInitialLoadRequested = true
        root.startupAwaitingFirstModelSignal = true
        startupStep(
            "initial_model_reload_begin",
            "reason=" + String(reason || "unspecified")
        )
        libraryModelRef.reload()
    }

    function handleComponentCompleted() {
        const root = rootObject
        if (!root || !libraryModelRef) return

        root.startupStartedAtMs = Date.now()
        root.startupFirstStatusSignalReceived = false
        root.startupResultLogged = false
        root.startupInventoryCheckRequestId = 0
        root.startupInventoryCheckInProgress = false
        root.startupInventoryRebuildInProgress = false
        root.startupPendingInventorySignature = null
        startupDelayedInventoryCheckScheduled = false
        startupStorageMigrationScheduled = false
        startupStorageMigrationInProgress = false
        startupStorageMigrationRequestId = 0
        startupInventoryCheckDelayTimer.stop()
        startupStorageMigrationDelayTimer.stop()
        startupPrimaryContentRevealTimer.stop()
        startupInitialLoadRequested = false
        startupInteractiveLogged = false
        startupVisuallyStableLogged = false
        startupVisualStabilityReason = ""
        startupVisualStabilityDetails = ""
        pendingUiReadyMode = ""
        pendingUiReadyStateTag = ""
        pendingUiStableReason = ""
        pendingUiStableDetails = ""
        startupTelemetry.startupLastLogAtMs = root.startupStartedAtMs
        root.startupFirstFrameSource = "unknown"
        root.startupPrimaryContentReady = false
        libraryModelRef.resetStartupDebugLog()
        traceWindowState("component_completed_begin")
        root.startupPreviewPath = String(libraryModelRef.startupPreviewPath() || "")
        startupSnapshotController.deriveStartupPreviewPaths(root.startupPreviewPath)
        startupSnapshotController.refreshStartupPreviewSource()
        root.startupReconcileCompleted = false
        root.startupHydrationInProgress = true
        root.startupAwaitingFirstModelSignal = true
        root.startupHydrationAttemptCount = 0
        startupWindowStateRestored = false
        startupStep("app_start")
        startupLog(
            "preview path primary=" + root.startupPreviewPrimaryPath
            + " fallback=" + root.startupPreviewFallbackPath
        )
        const snapshotRestored = restoreStartupSnapshot()
        if (!snapshotRestored && !startupWindowStateRestored) {
            applyWindowSnapshot({ windowState: "windowed" })
        }
        root.startupFirstFrameSource = snapshotRestored ? "snapshot" : "live_model"
        startupStep("snapshot_restored", "value=" + String(snapshotRestored))
        root.libraryLoading = !root.startupSnapshotApplied
        root.showStartupPreview = root.startupPreviewOverlayEnabled && !snapshotRestored
        startupLog("preview shown=" + String(root.showStartupPreview))
        root.refreshCbrSupportState()
        if (snapshotRestored) {
            startupStep(
                "startup_initial_reload_scheduled",
                "delayMs=" + String(root.startupLoadDelayMs)
            )
            startupLoadTimer.interval = root.startupLoadDelayMs
            startupLoadTimer.restart()
            root.startupReconcileCompleted = true
            root.startupHydrationInProgress = false
        } else {
            startupStep("startup_initial_reload_deferred", "snapshotRestored=false")
            startupLoadTimer.stop()
        }
        if (snapshotRestored && !root.startupResultLogged) {
            queueUiReady(
                "snapshot_first_frame",
                "snapshot_first_frame",
                "snapshot_first_frame",
                "seriesCount=" + String(seriesListModel ? seriesListModel.count : 0)
                + " issuesCount=" + String((root.issuesGridData || []).length)
            )
        }
        Qt.callLater(function() {
            controller.applyDeferredWindowState()
        })
        if (!snapshotRestored) {
            Qt.callLater(function() {
                controller.requestInitialModelLoad("no_snapshot_after_window_visible")
            })
        }
        Qt.callLater(function() {
            controller.runStartupDbHealthCheckAsync()
        })
    }

    function handleClosing(close) {
        const root = rootObject
        if (!root) return

        if (root.startupClosingAfterPreview) {
            startupLog("close[" + String(root.startupCloseSeq) + "] repeated_close_event accepted")
            close.accepted = true
            return
        }
        close.accepted = false
        root.startupClosingAfterPreview = true
        root.startupCloseSeq += 1
        root.startupCloseRequestedAtMs = Date.now()
        startupLog("close[" + String(root.startupCloseSeq) + "] requested")
        logWindowTrackingState("close_requested")
        root.startupInventorySignature = libraryModelRef.currentStartupInventorySignature()
        startupLog("close[" + String(root.startupCloseSeq) + "] save_snapshot_begin")
        saveStartupSnapshot()
        startupLog("close[" + String(root.startupCloseSeq) + "] save_snapshot_end")
        captureStartupPreviewFrame(true)
        startupSnapshotController.startCloseFinalizeTimer()
    }

    function resetStartupLogForNextRun() {
        if (!libraryModelRef) return
        libraryModelRef.resetStartupDebugLog()
    }

    Connections {
        target: libraryModelRef

        function onDatabaseHealthChecked(requestId, result) {
            const root = rootObject
            if (!root) return
            const id = Number(requestId || 0)
            if (id > 0 && id !== root.startupDbHealthRequestId) {
                startupLog(
                    "db_health async_ignored id=" + String(id)
                    + " expected=" + String(root.startupDbHealthRequestId)
                )
                return
            }
            startupLog("db_health async_completed id=" + String(id))
            handleStartupDbHealthResult(result)
        }

        function onStartupInventorySignatureReady(requestId, result) {
            const root = rootObject
            if (!root) return
            const id = Number(requestId || 0)
            if (id > 0 && id !== root.startupInventoryCheckRequestId) {
                startupLog(
                    "startup_inventory_check_ignored id=" + String(id)
                    + " expected=" + String(root.startupInventoryCheckRequestId)
                )
                return
            }

            root.startupInventoryCheckInProgress = false
            root.startupPendingInventorySignature = result || ({})
            const currentKey = normalizedInventorySignatureKey(result)
            const savedKey = normalizedInventorySignatureKey(root.startupInventorySignature)
            const savedKeyRaw = String(((root.startupInventorySignature || {}).signatureKey) || "")
            const changed = currentKey.length < 1 || savedKey.length < 1 || currentKey !== savedKey
            launchLog(
                "inventory_check_complete changed=" + String(changed)
                + " savedKey=" + savedKey
                + (savedKeyRaw.length > 0 && savedKeyRaw !== savedKey
                    ? " savedKeyRaw=" + savedKeyRaw
                    : "")
                + " currentKey=" + currentKey
            )

            if (!changed) {
                root.startupInventorySignature = result || ({})
                return
            }

            root.startupInventoryRebuildInProgress = true
            root.startupReconcileCompleted = false
            root.startupHydrationInProgress = true
            root.startupAwaitingFirstModelSignal = true
            launchLog("inventory_rebuild_begin requestId=" + String(id))
            controller.requestInitialModelLoad("inventory_signature_changed")
        }

        function onLibraryStorageMigrationFinished(requestId, result) {
            const root = rootObject
            if (!root) return

            const id = Number(requestId || 0)
            if (id > 0 && id !== startupStorageMigrationRequestId) {
                startupLog(
                    "storage_migration_ignored id=" + String(id)
                    + " expected=" + String(startupStorageMigrationRequestId)
                )
                return
            }

            startupStorageMigrationInProgress = false
            const payload = result || ({})
            const changed = Boolean(payload.changed)
            const warningText = String(payload.warning || "").trim()
            const errorText = String(payload.error || "").trim()
            const skipped = Boolean(payload.skipped)
            const skipReason = String(payload.skipReason || "").trim()

            let message = "storage_migration_complete"
            message += " changed=" + String(changed)
            message += " skipped=" + String(skipped)
            if (skipReason.length > 0) {
                message += " skipReason=" + skipReason
            }
            if (errorText.length > 0) {
                message += " error=true"
            }
            if (warningText.length > 0) {
                message += " warning=true"
            }
            launchLog(message)

            if (errorText.length > 0) {
                startupLog("storage_migration error: " + errorText)
                return
            }

            if (warningText.length > 0) {
                startupLog("storage_migration warning: " + warningText)
            }

            if (!changed) return

            launchLog("storage_migration_reload_begin")
            libraryModelRef.reload()
        }

        function onStatusChanged() {
            const root = rootObject
            if (!root || !libraryModelRef) return

            startupVisualStabilityTimer.stop()
            root.libraryLoading = false
            startupLog(
                "statusChanged mutation=" + String(libraryModelRef.lastMutationKind || "")
                + " totalCount=" + String(Number(libraryModelRef.totalCount || 0))
                + " startupAwaitingFirstModelSignal=" + String(root.startupAwaitingFirstModelSignal)
            )
            if (!root.startupFirstStatusSignalReceived) {
                root.startupFirstStatusSignalReceived = true
                startupLog("timeline first_status_changed")
                logStartupUiState("first_status_changed")
            }
            if (root.startupAwaitingFirstModelSignal) {
                startupInitialLoadRequested = false
                root.startupAwaitingFirstModelSignal = false
                startupLoadTimer.stop()
                if (root.startupSnapshotApplied) {
                    startupStep(
                        "startup_initial_reconcile_settle_begin",
                        "delayMs=" + String(root.startupInitialReconcileSettleDelayMs)
                    )
                    modelReconcileTimer.interval = root.startupInitialReconcileSettleDelayMs
                    modelReconcileTimer.restart()
                } else {
                    scheduleModelReconcile(true)
                }
                return
            }

            const mutation = String(libraryModelRef.lastMutationKind || "")
            if (
                mutation === "reload"
                    && root.startupHydrationInProgress
                    && root.startupSnapshotApplied
            ) {
                startupStep(
                    "startup_initial_reconcile_settle_refresh",
                    "delayMs=" + String(root.startupInitialReconcileSettleDelayMs)
                    + " totalCount=" + String(Number(libraryModelRef.totalCount || 0))
                )
                modelReconcileTimer.interval = root.startupInitialReconcileSettleDelayMs
                modelReconcileTimer.restart()
                return
            }
            if (
                mutation === "update_metadata"
                    || mutation === "bulk_update_metadata"
                    || mutation === "delete_series_files_keep_records"
                    || mutation === "delete_issue_files_keep_record"
                    || mutation === "delete_comic"
            ) {
                root.refreshSeriesList()
                root.refreshIssuesGridData()
                requestSnapshotSave()
                return
            }
            scheduleModelReconcile(false)
        }
    }

    Connections {
        target: launchStateRef

        function onRootWindowVisibleChanged() {
            if (!controller.isRootWindowVisible()) return
            controller.flushPendingUiReady()
        }
    }

    Timer {
        id: startupLoadTimer
        interval: rootObject ? rootObject.startupLoadDelayMs : 0
        repeat: false
        running: false
        onTriggered: {
            controller.requestInitialModelLoad("delayed_after_snapshot")
        }
    }

    Timer {
        id: modelReconcileTimer
        interval: 50
        repeat: false
        running: false
        onTriggered: controller.reconcileFromModel()
    }

    Timer {
        id: startupVisualStabilityTimer
        interval: 48
        repeat: false
        running: false
        onTriggered: controller.markStartupVisuallyStable()
    }

    Timer {
        id: startupPrimaryContentRevealTimer
        interval: rootObject ? rootObject.startupPrimaryContentRevealDelayMs : 48
        repeat: false
        running: false
        onTriggered: controller.revealPrimaryStartupContent()
    }

    Timer {
        id: startupInventoryCheckDelayTimer
        interval: rootObject ? rootObject.startupInventoryCheckDelayMs : 5000
        repeat: false
        running: false
        onTriggered: controller.beginDeferredStartupInventoryCheck("post_start_delay")
    }

    Timer {
        id: startupStorageMigrationDelayTimer
        interval: startupStorageMigrationDelayMs
        repeat: false
        running: false
        onTriggered: controller.beginDeferredLibraryStorageMigration("post_ui_stable")
    }
}
