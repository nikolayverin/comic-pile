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

    function startupLog(message) { startupTelemetry.startupLog(message) }

    function startupStep(stepName, details) { startupTelemetry.startupStep(stepName, details) }

    function trackingLog(message) { startupTelemetry.trackingLog(message) }

    function logWindowTrackingState(tag) { startupTelemetry.logWindowTrackingState(tag) }

    function launchLog(message) { startupTelemetry.launchLog(message) }

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

    function toLocalFileUrl(pathValue) {
        const raw = String(pathValue || "")
        if (raw.length < 1) return ""
        const normalized = raw.replace(/\\/g, "/")
        if (/^[a-zA-Z]:\//.test(normalized)) {
            return "file:///" + normalized
        }
        if (normalized.startsWith("/")) {
            return "file://" + normalized
        }
        return "file:///" + normalized
    }

    function refreshStartupPreviewSource() {
        const root = rootObject
        if (!root || root.startupPreviewPrimaryPath.length < 1) return
        root.startupPreviewTriedFallback = false
        root.startupPreviewSource = toLocalFileUrl(root.startupPreviewPrimaryPath) + "?v=" + String(Date.now())
    }

    function deriveStartupPreviewPaths(rawPath) {
        const root = rootObject
        if (!root) return
        const baseRaw = String(rawPath || "")
        if (baseRaw.length < 1) {
            root.startupPreviewPrimaryPath = ""
            root.startupPreviewFallbackPath = ""
            return
        }
        const base = baseRaw.replace(/\.(png|jpg|jpeg|webp)$/i, "")
        root.startupPreviewPrimaryPath = base + ".webp"
        root.startupPreviewFallbackPath = base + ".jpg"
    }

    function requestSnapshotSave() {
        startupSnapshotSaveDebounce.restart()
    }

    function scheduleStartupPreviewCapture() {
        const root = rootObject
        if (!root) return
        if (!root.startupReconcileCompleted) return
        startupPreviewCaptureDebounce.restart()
    }

    function collectStartupPreviewMetrics(rawW, rawH, targetW, targetH) {
        const root = rootObject
        if (!root) return {}
        const m = {
            windowX: Math.round(root.x),
            windowY: Math.round(root.y),
            windowW: Math.round(root.width),
            windowH: Math.round(root.height),
            rawW: Math.round(rawW),
            rawH: Math.round(rawH),
            targetW: Math.round(targetW),
            targetH: Math.round(targetH),
            visible: root.visible,
            startupReconcileCompleted: root.startupReconcileCompleted,
            startupHydrationInProgress: root.startupHydrationInProgress,
            selectedSeriesKey: String(root.selectedSeriesKey || ""),
            issuesCount: Number((root.issuesGridData || []).length || 0)
        }
        if (issuesFlick) {
            m.gridContentY = Number(issuesFlick.contentY || 0)
            m.gridTopMargin = Number(issuesFlick.topMargin || 0)
            m.gridCellHeight = Number(issuesFlick.cellHeight || 0)
            m.gridCardHeight = Number(issuesFlick.cardHeight || 0)
            m.gridSafeTop = Number(issuesFlick.safeZoneTop || 0)
            m.gridColumns = Number(issuesFlick.columns || 0)
            m.gridHeight = Number(issuesFlick.height || 0)
            m.gridContentHeight = Number(issuesFlick.contentHeight || 0)
            m.gridFirstRowExpectedTop = Number((issuesFlick.topMargin || 0) - (issuesFlick.contentY || 0))
        }
        return m
    }

    function captureStartupPreviewFrame(finalizeClose) {
        const root = rootObject
        if (!root || !appContentLayout || !libraryModelRef) return
        if (root.startupPreviewPrimaryPath.length < 1) return
        if (!root.visible) return

        const rawW = Math.max(1, Math.round(root.width))
        const rawH = Math.max(1, Math.round(root.height))
        const longSide = Math.max(rawW, rawH)
        const scale = longSide > root.startupPreviewMaxLongSide
            ? root.startupPreviewMaxLongSide / longSide
            : 1.0
        const targetW = Math.max(1, Math.round(rawW * scale))
        const targetH = Math.max(1, Math.round(rawH * scale))
        if (targetW < 2 || targetH < 2) return

        const captureMeta = collectStartupPreviewMetrics(rawW, rawH, targetW, targetH)
        startupLog(
            "close[" + String(root.startupCloseSeq) + "] preview_capture_begin"
            + " finalize=" + String(finalizeClose === true)
            + " raw=" + String(rawW) + "x" + String(rawH)
            + " target=" + String(targetW) + "x" + String(targetH)
        )

        try {
            appContentLayout.grabToImage(function(result) {
                const okWebp = result.saveToFile(root.startupPreviewPrimaryPath)
                let okJpg = false
                if (!okWebp && root.startupPreviewFallbackPath.length > 0) {
                    okJpg = result.saveToFile(root.startupPreviewFallbackPath)
                }
                const metaPayload = JSON.stringify({
                    closeSeq: root.startupCloseSeq,
                    captureAtMs: Date.now(),
                    finalizeClose: finalizeClose === true,
                    webpPath: root.startupPreviewPrimaryPath,
                    jpgPath: root.startupPreviewFallbackPath,
                    webpOk: okWebp,
                    jpgOk: okJpg,
                    metrics: captureMeta
                })
                const metaOk = libraryModelRef.writeStartupPreviewMeta(metaPayload)
                startupLog(
                    "close[" + String(root.startupCloseSeq) + "] preview_capture_done"
                    + " webp=" + String(okWebp)
                    + " jpg=" + String(okJpg)
                    + " meta=" + String(metaOk)
                    + " size=" + String(targetW) + "x" + String(targetH)
                )
                if (finalizeClose === true && root.startupClosingAfterPreview) {
                    startupCloseFinalizeTimer.stop()
                    Qt.callLater(function() {
                        startupLog(
                            "close[" + String(root.startupCloseSeq) + "] finalize_by_callback"
                            + " delayMs=" + String(Math.max(0, Math.round(Date.now() - root.startupCloseRequestedAtMs)))
                        )
                        controller.resetStartupLogForNextRun()
                        Qt.quit()
                    })
                }
            }, Qt.size(targetW, targetH))
        } catch (e) {
            startupLog("close[" + String(root.startupCloseSeq) + "] preview_capture_error: " + String(e))
            if (finalizeClose === true && root.startupClosingAfterPreview) {
                startupCloseFinalizeTimer.stop()
                Qt.callLater(function() {
                    startupLog(
                        "close[" + String(root.startupCloseSeq) + "] finalize_after_error"
                        + " delayMs=" + String(Math.max(0, Math.round(Date.now() - root.startupCloseRequestedAtMs)))
                    )
                    controller.resetStartupLogForNextRun()
                    Qt.quit()
                })
            }
        }
    }

    function stampWindowState(snapshotObject) {
        if (windowDisplayControllerRef && typeof windowDisplayControllerRef.stampWindowState === "function") {
            return windowDisplayControllerRef.stampWindowState(snapshotObject)
        }
        return snapshotObject && typeof snapshotObject === "object" ? snapshotObject : {}
    }

    function stripSnapshotScrollState(snapshotObject) {
        const target = snapshotObject && typeof snapshotObject === "object" ? snapshotObject : {}
        delete target.seriesContentY
        delete target.issuesContentY
        return target
    }

    function applyWindowSnapshot(parsed) {
        if (windowDisplayControllerRef && typeof windowDisplayControllerRef.applyWindowSnapshot === "function") {
            windowDisplayControllerRef.applyWindowSnapshot(parsed)
        }
    }

    function applyDeferredWindowState() {
        if (windowDisplayControllerRef && typeof windowDisplayControllerRef.applyDeferredWindowState === "function") {
            windowDisplayControllerRef.applyDeferredWindowState()
        }
    }

    function compactIssueForSnapshot(item) {
        const src = item || {}
        return {
            id: Number(src.id || 0),
            series: String(src.series || ""),
            volume: String(src.volume || ""),
            title: String(src.title || ""),
            issueNumber: String(src.issueNumber || ""),
            filename: String(src.filename || ""),
            readStatus: String(src.readStatus || "unread"),
            currentPage: Number(src.currentPage || 0),
            publisher: String(src.publisher || ""),
            year: Number(src.year || 0),
            month: Number(src.month || 0)
        }
    }

    function issueListsEquivalentByIdAndOrder(leftList, rightList) {
        const left = Array.isArray(leftList) ? leftList : []
        const right = Array.isArray(rightList) ? rightList : []
        if (left.length !== right.length) return false
        for (let i = 0; i < left.length; i += 1) {
            const leftId = Number((left[i] || {}).id || 0)
            const rightId = Number((right[i] || {}).id || 0)
            if (leftId !== rightId) return false
        }
        return true
    }

    function buildStartupSnapshotPayload() {
        const root = rootObject
        if (!root || !libraryModelRef) return ""

        const seriesItems = []
        const maxSeries = Math.max(0, Number(root.startupSnapshotMaxSeries || 0))
        const seriesCount = Math.min(seriesListModel ? seriesListModel.count : 0, maxSeries)
        for (let i = 0; i < seriesCount; i += 1) {
            const item = seriesListModel.get(i)
            seriesItems.push({
                seriesKey: String(item.seriesKey || ""),
                seriesTitle: String(item.seriesTitle || ""),
                count: Number(item.count || 0)
            })
        }

        const issuesItems = []
        const maxIssues = Math.max(0, Number(root.startupSnapshotMaxIssues || 0))
        const totalIssues = Math.max(0, Number((root.issuesGridData || []).length || 0))
        let captureStart = 0
        let captureEnd = Math.min(totalIssues - 1, maxIssues - 1)
        if (totalIssues > 0) {
            const visibleRange = root.visibleIssueRange(totalIssues)
            if (visibleRange.end >= visibleRange.start) {
                captureStart = Math.max(0, visibleRange.start)
                captureEnd = Math.min(
                    totalIssues - 1,
                    visibleRange.end,
                    captureStart + maxIssues - 1
                )
            }
        }
        const coverSubset = {}
        for (let i = captureStart; i <= captureEnd; i += 1) {
            const item = root.issuesGridData[i]
            if (!item) continue
            issuesItems.push(compactIssueForSnapshot(item))
            const comicId = Number(item.id || 0)
            if (comicId < 1) continue
            const source = root.coverSourceForComic(comicId)
            if (source.length > 0) {
                coverSubset[String(comicId)] = source
            }
        }

        if (root.heroCoverComicId > 0) {
            const heroSource = root.coverSourceForComic(root.heroCoverComicId)
            if (heroSource.length > 0) {
                coverSubset[String(root.heroCoverComicId)] = heroSource
            }
        }

        const selectedSeriesTitle = String(root.selectedSeriesTitle || "")
        const snapshotHeroTitle = root.selectedSeriesKey
            ? selectedSeriesTitle
            : String((root.heroSeriesData || {}).seriesTitle || "")
        const payload = {
            version: root.startupSnapshotVersion,
            dbPath: String(libraryModelRef.dbPath || ""),
            inventorySignature: root.startupInventorySignature || {},
            selectedSeriesKey: String(root.selectedSeriesKey || ""),
            selectedSeriesTitle: selectedSeriesTitle,
            selectedVolumeKey: String(root.selectedVolumeKey || "__all__"),
            selectedVolumeTitle: String(root.selectedVolumeTitle || "All volumes"),
            sidebarQuickFilterKey: String(root.sidebarQuickFilterKey || ""),
            lastImportSessionComicIds: Array.isArray(root.lastImportSessionComicIds)
                ? root.lastImportSessionComicIds
                    .map(function(value) { return Number(value || 0) })
                    .filter(function(value) { return value > 0 })
                : [],
            sidebarSearchText: String(root.sidebarSearchText || ""),
            librarySearchText: String(root.librarySearchText || ""),
            libraryReadStatusFilter: String(root.libraryReadStatusFilter || "all"),
            sevenZipConfiguredPath: String(root.sevenZipConfiguredPath || ""),
            heroCoverComicId: Number(root.heroCoverComicId || -1),
            heroSeriesData: {
                seriesTitle: snapshotHeroTitle,
                summary: String((root.heroSeriesData || {}).summary || "-"),
                year: String((root.heroSeriesData || {}).year || "-"),
                volume: String((root.heroSeriesData || {}).volume || "-"),
                publisher: String((root.heroSeriesData || {}).publisher || "-"),
                genres: String((root.heroSeriesData || {}).genres || "-"),
                logoSource: String((root.heroSeriesData || {}).logoSource || "")
            },
            seriesItems: seriesItems,
            issuesItems: issuesItems,
            coverByComicId: coverSubset
        }
        return JSON.stringify(stripSnapshotScrollState(stampWindowState(payload)))
    }

    function saveStartupSnapshot() {
        if (!libraryModelRef) return
        try {
            logWindowTrackingState("save_begin")
            const payload = buildStartupSnapshotPayload()
            if (payload.length > 0) {
                startupLog("saveSnapshot payloadLen=" + String(payload.length))
                try {
                    const parsedPayload = JSON.parse(payload)
                    const message =
                        "saveSnapshot window"
                        + " state=" + String(parsedPayload.windowState || "")
                        + " x=" + String(parsedPayload.windowX)
                        + " y=" + String(parsedPayload.windowY)
                        + " w=" + String(parsedPayload.windowWidth)
                        + " h=" + String(parsedPayload.windowHeight)
                    startupLog(message)
                    trackingLog(message)
                } catch (payloadError) {
                    startupLog("saveSnapshot payload_parse_error=" + String(payloadError))
                }
                libraryModelRef.writeStartupSnapshot(payload)
                return
            }

            const rawExisting = String(libraryModelRef.readStartupSnapshot() || "").trim()
            if (rawExisting.length < 2) return
            let parsedExisting = null
            try {
                parsedExisting = JSON.parse(rawExisting)
            } catch (e) {
                startupLog("saveSnapshot keep-window-state parseFailed")
                return
            }
            startupLog("saveSnapshot contentFrozen, updating window-only fields")
            const windowOnlyPayload = JSON.stringify(stripSnapshotScrollState(stampWindowState(parsedExisting)))
            try {
                const parsedWindowOnlyPayload = JSON.parse(windowOnlyPayload)
                const message =
                    "saveSnapshot window_only"
                    + " state=" + String(parsedWindowOnlyPayload.windowState || "")
                    + " x=" + String(parsedWindowOnlyPayload.windowX)
                    + " y=" + String(parsedWindowOnlyPayload.windowY)
                    + " w=" + String(parsedWindowOnlyPayload.windowWidth)
                    + " h=" + String(parsedWindowOnlyPayload.windowHeight)
                startupLog(message)
                trackingLog(message)
            } catch (windowOnlyError) {
                startupLog("saveSnapshot window_only_parse_error=" + String(windowOnlyError))
            }
            libraryModelRef.writeStartupSnapshot(windowOnlyPayload)
        } catch (e) {
            startupLog("saveSnapshot error: " + String(e))
        }
    }

    function applyStartupScrollSnapshot() {
        const root = rootObject
        if (!root) return
        if (seriesListView) {
            seriesListView.contentY = 0
        }
        root.setGridScrollToTop()
    }

    function restoreStartupSnapshot() {
        const root = rootObject
        if (!root || !libraryModelRef || !seriesListModel) return false

        const raw = String(libraryModelRef.readStartupSnapshot() || "").trim()
        startupLog("restoreSnapshot rawLen=" + String(raw.length))
        if (raw.length < 2) {
            startupLog("restoreSnapshot: empty/missing")
            return false
        }

        let parsed = null
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            startupLog("restoreSnapshot: json parse failed")
            return false
        }
        if (!parsed || typeof parsed !== "object") {
            startupLog("restoreSnapshot: parsed payload is not an object")
            return false
        }

        const parsedSeries = Array.isArray(parsed.seriesItems) ? parsed.seriesItems : []
        const parsedIssues = Array.isArray(parsed.issuesItems) ? parsed.issuesItems : []
        const restoreWindowMessage =
            "restoreSnapshot window"
            + " state=" + String(parsed.windowState || "")
            + " x=" + String(parsed.windowX)
            + " y=" + String(parsed.windowY)
            + " w=" + String(parsed.windowWidth)
            + " h=" + String(parsed.windowHeight)
        startupLog(restoreWindowMessage)
        trackingLog(restoreWindowMessage)
        startupLog(
            "restoreSnapshot counts series=" + String(parsedSeries.length)
            + " issues=" + String(parsedIssues.length)
        )
        startupLog("restoreSnapshot step=before_apply_window")
        applyWindowSnapshot(parsed)
        startupWindowStateRestored = true
        startupLog("restoreSnapshot step=after_apply_window")
        const liveTotalCount = Math.max(0, Number(libraryModelRef.totalCount || 0))
        if (liveTotalCount < 1 && (parsedSeries.length > 0 || parsedIssues.length > 0)) {
            startupLog(
                "restoreSnapshot: skip stale content because live library is empty; keep window state"
            )
            return false
        }
        if (parsedSeries.length < 1 && parsedIssues.length < 1) {
            if (liveTotalCount > 0) {
                startupLog(
                    "restoreSnapshot: snapshot content empty while live library has content; ignore snapshot content"
                )
                return false
            }
            startupLog("restoreSnapshot: snapshot has no content, applying window/search state only")
        }

        root.restoringStartupSnapshot = true
        root.suspendSidebarSearchRefresh = true

        root.sidebarSearchText = String(parsed.sidebarSearchText || "")
        root.librarySearchText = String(parsed.librarySearchText || "")
        root.libraryReadStatusFilter = String(parsed.libraryReadStatusFilter || "all")
        root.sidebarQuickFilterKey = String(parsed.sidebarQuickFilterKey || "")
        root.lastImportSessionComicIds = Array.isArray(parsed.lastImportSessionComicIds)
            ? parsed.lastImportSessionComicIds
                .map(function(value) { return Number(value || 0) })
                .filter(function(value) { return value > 0 })
            : []
        if (Object.prototype.hasOwnProperty.call(parsed, "sevenZipConfiguredPath")) {
            root.sevenZipConfiguredPath = String(parsed.sevenZipConfiguredPath || "")
            const setSevenZipPathError = String(libraryModelRef.setSevenZipExecutablePath(root.sevenZipConfiguredPath) || "")
            if (setSevenZipPathError.length > 0) {
                startupLog("restoreSnapshot sevenZipPath rejected: " + setSevenZipPathError)
                root.sevenZipConfiguredPath = ""
                libraryModelRef.setSevenZipExecutablePath("")
            }
        }
        const parsedInventorySignature = (
            parsed.inventorySignature && typeof parsed.inventorySignature === "object"
        ) ? parsed.inventorySignature : null
        const parsedInventoryKey = normalizedInventorySignatureKey(parsedInventorySignature)
        root.startupInventorySignature = parsedInventoryKey.length > 0
            ? parsedInventorySignature
            : libraryModelRef.currentStartupInventorySignature()

        seriesListModel.clear()
        for (let i = 0; i < parsedSeries.length; i += 1) {
            const item = parsedSeries[i] || {}
            const key = String(item.seriesKey || "")
            if (key.length < 1) continue
            seriesListModel.append({
                seriesKey: key,
                seriesTitle: String(item.seriesTitle || ""),
                count: Number(item.count || 0)
            })
        }
        startupLog("restoreSnapshot step=series_applied count=" + String(seriesListModel.count))

        root.selectedSeriesKey = String(parsed.selectedSeriesKey || "")
        root.selectedSeriesTitle = String(parsed.selectedSeriesTitle || "")
        root.selectedVolumeKey = String(parsed.selectedVolumeKey || "__all__")
        root.selectedVolumeTitle = String(parsed.selectedVolumeTitle || "All volumes")
        root.heroCoverComicId = Number(parsed.heroCoverComicId || -1)
        const restoredSelection = {}
        if (root.selectedSeriesKey.length > 0) {
            restoredSelection[root.selectedSeriesKey] = true
        }
        root.selectedSeriesKeys = restoredSelection
        root.seriesSelectionAnchorIndex = -1
        for (let i = 0; i < seriesListModel.count; i += 1) {
            const item = seriesListModel.get(i) || {}
            if (String(item.seriesKey || "") === root.selectedSeriesKey) {
                root.seriesSelectionAnchorIndex = i
                break
            }
        }
        if (parsed.heroSeriesData && typeof parsed.heroSeriesData === "object") {
            const restoredHeroTitle = root.selectedSeriesKey.length > 0 && root.selectedSeriesTitle.length > 0
                ? root.selectedSeriesTitle
                : String(parsed.heroSeriesData.seriesTitle || "")
            root.heroSeriesData = {
                seriesTitle: restoredHeroTitle,
                summary: String(parsed.heroSeriesData.summary || "-"),
                year: String(parsed.heroSeriesData.year || "-"),
                volume: String(parsed.heroSeriesData.volume || "-"),
                publisher: String(parsed.heroSeriesData.publisher || "-"),
                genres: String(parsed.heroSeriesData.genres || "-"),
                logoSource: String(parsed.heroSeriesData.logoSource || "")
            }
        }

        const restoredCovers = {}
        const parsedCovers = parsed.coverByComicId && typeof parsed.coverByComicId === "object"
            ? parsed.coverByComicId
            : {}
        const coverKeys = Object.keys(parsedCovers)
        for (let i = 0; i < coverKeys.length; i += 1) {
            const key = String(coverKeys[i] || "")
            const source = String(parsedCovers[key] || "")
            if (key.length < 1 || source.length < 1) continue
            restoredCovers[key] = source
        }
        root.coverByComicId = restoredCovers
        startupStep("restore_snapshot_covers_applied", "count=" + String(Object.keys(restoredCovers).length))

        const nextIssues = []
        for (let i = 0; i < parsedIssues.length; i += 1) {
            const issue = parsedIssues[i]
            if (!issue) continue
            nextIssues.push(compactIssueForSnapshot(issue))
        }
        root.issuesGridData = nextIssues
        startupStep("restore_snapshot_issues_applied", "count=" + String(root.issuesGridData.length))

        if (root.heroCoverComicId < 1) {
            const liveHeroId = Number(libraryModelRef.heroCoverComicIdForSeries(root.selectedSeriesKey) || -1)
            if (liveHeroId > 0) {
                root.heroCoverComicId = liveHeroId
            } else if (nextIssues.length > 0) {
                root.heroCoverComicId = Number((nextIssues[0] || {}).id || -1)
            }
        }
        if (root.heroCoverComicId > 0 && root.coverSourceForComic(root.heroCoverComicId).length < 1) {
            root.requestIssueThumbnail(root.heroCoverComicId)
        }

        root.startupSnapshotSeriesContentY = 0
        root.startupSnapshotIssuesContentY = 0
        if (typeof root.refreshQuickFilterCounts === "function") {
            root.refreshQuickFilterCounts()
        }
        if (typeof root.applyConfiguredLaunchViewDuringStartupRestore === "function") {
            root.applyConfiguredLaunchViewDuringStartupRestore()
        }
        root.startupSnapshotApplied = true
        root.libraryLoading = false
        startupStep(
            "restore_snapshot_applied",
            "selectedSeriesKey=" + String(root.selectedSeriesKey)
            + " issuesGridData=" + String(root.issuesGridData.length)
        )
        markStartupInteractive(
            "snapshot_applied",
            "selectedSeriesKey=" + String(root.selectedSeriesKey)
            + " issues=" + String(root.issuesGridData.length)
        )
        logStartupUiState("snapshot_applied")

        root.suspendSidebarSearchRefresh = false
        root.restoringStartupSnapshot = false

        if (heroSeriesControllerRef && typeof heroSeriesControllerRef.refreshSeriesData === "function") {
            heroSeriesControllerRef.refreshSeriesData()
        }
        startupSnapshotScrollRestoreTimer.start()
        return true
    }

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
        deriveStartupPreviewPaths(root.startupPreviewPath)
        refreshStartupPreviewSource()
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
        startupCloseFinalizeTimer.restart()
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
        id: startupSnapshotSaveDebounce
        interval: 300
        repeat: false
        running: false
        onTriggered: {
            controller.saveStartupSnapshot()
            controller.scheduleStartupPreviewCapture()
        }
    }

    Timer {
        id: startupPreviewCaptureDebounce
        interval: 900
        repeat: false
        running: false
        onTriggered: controller.captureStartupPreviewFrame()
    }

    Timer {
        id: startupCloseFinalizeTimer
        interval: 350
        repeat: false
        running: false
        onTriggered: {
            const root = rootObject
            if (!root) return
            if (root.startupClosingAfterPreview) {
                controller.startupLog(
                    "close[" + String(root.startupCloseSeq) + "] finalize_by_timeout"
                    + " delayMs=" + String(Math.max(0, Math.round(Date.now() - root.startupCloseRequestedAtMs)))
                )
                controller.resetStartupLogForNextRun()
                Qt.quit()
            }
        }
    }

    Timer {
        id: startupSnapshotScrollRestoreTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: controller.applyStartupScrollSnapshot()
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
