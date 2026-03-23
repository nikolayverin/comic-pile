import QtQuick

Item {
    id: snapshotController
    visible: false
    width: 0
    height: 0

    property var startupControllerRef: null
    property var rootObject: null
    property var libraryModelRef: null
    property var heroSeriesControllerRef: null
    property var windowDisplayControllerRef: null
    property var appContentLayout: null
    property var seriesListModel: null
    property var seriesListView: null
    property var issuesFlick: null

    readonly property var startupController: startupControllerRef

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
        if (!root || !appContentLayout || !libraryModelRef || !startupController) return
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
        startupController.startupLog(
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
                startupController.startupLog(
                    "close[" + String(root.startupCloseSeq) + "] preview_capture_done"
                    + " webp=" + String(okWebp)
                    + " jpg=" + String(okJpg)
                    + " meta=" + String(metaOk)
                    + " size=" + String(targetW) + "x" + String(targetH)
                )
                if (finalizeClose === true && root.startupClosingAfterPreview) {
                    startupCloseFinalizeTimer.stop()
                    Qt.callLater(function() {
                        startupController.startupLog(
                            "close[" + String(root.startupCloseSeq) + "] finalize_by_callback"
                            + " delayMs=" + String(Math.max(0, Math.round(Date.now() - root.startupCloseRequestedAtMs)))
                        )
                        startupController.resetStartupLogForNextRun()
                        Qt.quit()
                    })
                }
            }, Qt.size(targetW, targetH))
        } catch (e) {
            startupController.startupLog("close[" + String(root.startupCloseSeq) + "] preview_capture_error: " + String(e))
            if (finalizeClose === true && root.startupClosingAfterPreview) {
                startupCloseFinalizeTimer.stop()
                Qt.callLater(function() {
                    startupController.startupLog(
                        "close[" + String(root.startupCloseSeq) + "] finalize_after_error"
                        + " delayMs=" + String(Math.max(0, Math.round(Date.now() - root.startupCloseRequestedAtMs)))
                    )
                    startupController.resetStartupLogForNextRun()
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

    function startCloseFinalizeTimer() {
        startupCloseFinalizeTimer.restart()
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
        if (!libraryModelRef || !startupController) return
        try {
            startupController.logWindowTrackingState("save_begin")
            const payload = buildStartupSnapshotPayload()
            if (payload.length > 0) {
                startupController.startupLog("saveSnapshot payloadLen=" + String(payload.length))
                try {
                    const parsedPayload = JSON.parse(payload)
                    const message =
                        "saveSnapshot window"
                        + " state=" + String(parsedPayload.windowState || "")
                        + " x=" + String(parsedPayload.windowX)
                        + " y=" + String(parsedPayload.windowY)
                        + " w=" + String(parsedPayload.windowWidth)
                        + " h=" + String(parsedPayload.windowHeight)
                    startupController.startupLog(message)
                    startupController.trackingLog(message)
                } catch (payloadError) {
                    startupController.startupLog("saveSnapshot payload_parse_error=" + String(payloadError))
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
                startupController.startupLog("saveSnapshot keep-window-state parseFailed")
                return
            }
            startupController.startupLog("saveSnapshot contentFrozen, updating window-only fields")
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
                startupController.startupLog(message)
                startupController.trackingLog(message)
            } catch (windowOnlyError) {
                startupController.startupLog("saveSnapshot window_only_parse_error=" + String(windowOnlyError))
            }
            libraryModelRef.writeStartupSnapshot(windowOnlyPayload)
        } catch (e) {
            startupController.startupLog("saveSnapshot error: " + String(e))
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
        if (!root || !libraryModelRef || !seriesListModel || !startupController) return false

        const raw = String(libraryModelRef.readStartupSnapshot() || "").trim()
        startupController.startupLog("restoreSnapshot rawLen=" + String(raw.length))
        if (raw.length < 2) {
            startupController.startupLog("restoreSnapshot: empty/missing")
            return false
        }

        let parsed = null
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            startupController.startupLog("restoreSnapshot: json parse failed")
            return false
        }
        if (!parsed || typeof parsed !== "object") {
            startupController.startupLog("restoreSnapshot: parsed payload is not an object")
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
        startupController.startupLog(restoreWindowMessage)
        startupController.trackingLog(restoreWindowMessage)
        startupController.startupLog(
            "restoreSnapshot counts series=" + String(parsedSeries.length)
            + " issues=" + String(parsedIssues.length)
        )
        startupController.startupLog("restoreSnapshot step=before_apply_window")
        applyWindowSnapshot(parsed)
        startupController.startupWindowStateRestored = true
        startupController.startupLog("restoreSnapshot step=after_apply_window")
        const liveTotalCount = Math.max(0, Number(libraryModelRef.totalCount || 0))
        if (liveTotalCount < 1 && (parsedSeries.length > 0 || parsedIssues.length > 0)) {
            startupController.startupLog(
                "restoreSnapshot: skip stale content because live library is empty; keep window state"
            )
            return false
        }
        if (parsedSeries.length < 1 && parsedIssues.length < 1) {
            if (liveTotalCount > 0) {
                startupController.startupLog(
                    "restoreSnapshot: snapshot content empty while live library has content; ignore snapshot content"
                )
                return false
            }
            startupController.startupLog("restoreSnapshot: snapshot has no content, applying window/search state only")
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
                startupController.startupLog("restoreSnapshot sevenZipPath rejected: " + setSevenZipPathError)
                root.sevenZipConfiguredPath = ""
                libraryModelRef.setSevenZipExecutablePath("")
            }
        }
        const parsedInventorySignature = (
            parsed.inventorySignature && typeof parsed.inventorySignature === "object"
        ) ? parsed.inventorySignature : null
        const parsedInventoryKey = startupController.normalizedInventorySignatureKey(parsedInventorySignature)
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
        startupController.startupLog("restoreSnapshot step=series_applied count=" + String(seriesListModel.count))

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
        startupController.startupStep("restore_snapshot_covers_applied", "count=" + String(Object.keys(restoredCovers).length))

        const nextIssues = []
        for (let i = 0; i < parsedIssues.length; i += 1) {
            const issue = parsedIssues[i]
            if (!issue) continue
            nextIssues.push(compactIssueForSnapshot(issue))
        }
        root.issuesGridData = nextIssues
        startupController.startupStep("restore_snapshot_issues_applied", "count=" + String(root.issuesGridData.length))

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
        startupController.startupStep(
            "restore_snapshot_applied",
            "selectedSeriesKey=" + String(root.selectedSeriesKey)
            + " issuesGridData=" + String(root.issuesGridData.length)
        )
        startupController.markStartupInteractive(
            "snapshot_applied",
            "selectedSeriesKey=" + String(root.selectedSeriesKey)
            + " issues=" + String(root.issuesGridData.length)
        )
        startupController.logStartupUiState("snapshot_applied")

        root.suspendSidebarSearchRefresh = false
        root.restoringStartupSnapshot = false

        if (heroSeriesControllerRef && typeof heroSeriesControllerRef.refreshSeriesData === "function") {
            heroSeriesControllerRef.refreshSeriesData()
        }
        startupSnapshotScrollRestoreTimer.start()
        return true
    }

    Timer {
        id: startupSnapshotSaveDebounce
        interval: 300
        repeat: false
        running: false
        onTriggered: {
            snapshotController.saveStartupSnapshot()
            snapshotController.scheduleStartupPreviewCapture()
        }
    }

    Timer {
        id: startupPreviewCaptureDebounce
        interval: 900
        repeat: false
        running: false
        onTriggered: snapshotController.captureStartupPreviewFrame()
    }

    Timer {
        id: startupCloseFinalizeTimer
        interval: 350
        repeat: false
        running: false
        onTriggered: {
            const root = rootObject
            if (!root || !startupController) return
            if (root.startupClosingAfterPreview) {
                startupController.startupLog(
                    "close[" + String(root.startupCloseSeq) + "] finalize_by_timeout"
                    + " delayMs=" + String(Math.max(0, Math.round(Date.now() - root.startupCloseRequestedAtMs)))
                )
                startupController.resetStartupLogForNextRun()
                Qt.quit()
            }
        }
    }

    Timer {
        id: startupSnapshotScrollRestoreTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: snapshotController.applyStartupScrollSnapshot()
    }
}
