import QtQuick
import "../components/AppErrorMapper.js" as AppErrorMapper

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var popupControllerRef: null
    property var readerDialog: null
    property var appSettingsRef: null
    property var issuesFlick: null
    property int pendingReaderStartOverrideComicId: -1
    property int pendingReaderStartOverridePageIndex: -1
    property int pendingReaderPersistGuardComicId: -1
    property int pendingReaderPersistGuardPageIndex: -1

    function normalizedBookmarkPageIndex(value) {
        const parsed = Number(value)
        return isNaN(parsed) ? -1 : parsed
    }

    ReaderDisplayModeController {
        id: readerDisplayModeController
        rootObject: controller.rootObject
        libraryModelRef: controller.libraryModelRef
        readerDialogRef: controller.readerDialog
        readerCoverControllerRef: controller
    }

    function listCount(value) {
        if (Array.isArray(value)) {
            return value.length
        }
        if (value && typeof value.length === "number") {
            return Math.max(0, Number(value.length))
        }
        return 0
    }

    function listCopy(value) {
        const count = listCount(value)
        const copy = []
        for (let i = 0; i < count; i += 1) {
            copy.push(value[i])
        }
        return copy
    }

    function normalizedReaderPageIndex(pageIndex) {
        return readerDisplayModeController.normalizedReaderPageIndex(pageIndex)
    }

    function clearReaderDisplayState() {
        readerDisplayModeController.clearDisplayState()
    }

    function resetReaderLayoutState() {
        readerDisplayModeController.resetLayoutState()
    }

    function canGoPreviousDisplayPage() {
        return readerDisplayModeController.canGoPreviousDisplayPage()
    }

    function canGoNextDisplayPage() {
        return readerDisplayModeController.canGoNextDisplayPage()
    }

    function setReaderViewMode(mode) {
        readerDisplayModeController.setReaderViewMode(mode)
    }

    function clearPendingPopupOpen() {
        // Reader popup is revealed immediately. No deferred open state to clear.
    }

    function clearPendingReaderStartOverride() {
        pendingReaderStartOverrideComicId = -1
        pendingReaderStartOverridePageIndex = -1
    }

    function clearPendingReaderPersistGuard() {
        pendingReaderPersistGuardComicId = -1
        pendingReaderPersistGuardPageIndex = -1
    }

    function reopenReaderPopupWithFullscreenMode(enabled) {
        const root = rootObject
        if (!root) return

        if (typeof root.setReaderWindowFullscreen === "function") {
            root.setReaderWindowFullscreen(enabled)
            return
        }

        root.readerUiFullscreen = Boolean(enabled)
    }

    function readerPageEdgeBehaviorValue() {
        return appSettingsRef
            ? String(appSettingsRef.readerPageEdgeBehavior || "Stop at boundary")
            : "Stop at boundary"
    }

    function shouldContinueReaderAtBoundary() {
        return readerPageEdgeBehaviorValue() === "Continue"
    }

    function canCrossReaderIssueBoundary(offset) {
        if (!shouldContinueReaderAtBoundary()) return false
        return canNavigateReaderIssue(offset)
    }

    function preferredReaderStartPageIndex(sessionResult) {
        const result = sessionResult || ({})
        const pageCount = Math.max(0, Number(result.pageCount || 0))
        if (pageCount < 1) return 0

        const bookmarkPage = Number(result.bookmarkPage || 0)
        const currentPage = Number(result.currentPage || 0)
        const bookmarkPageIndex = bookmarkPage > 0 && bookmarkPage <= pageCount
            ? (bookmarkPage - 1)
            : -1
        const currentPageIndex = currentPage > 0
            ? Math.max(0, Math.min(pageCount - 1, currentPage - 1))
            : -1
        const preferBookmark = appSettingsRef
            ? Boolean(appSettingsRef.readerAutoOpenBookmarkedPageInsteadOfLastPage)
            : false

        if (preferBookmark && bookmarkPageIndex >= 0) return bookmarkPageIndex
        if (currentPageIndex >= 0) return currentPageIndex
        if (bookmarkPageIndex >= 0) return bookmarkPageIndex
        return Math.max(0, Math.min(pageCount - 1, Number(result.startPageIndex || 0)))
    }

    function syncOpenReaderViewModeFromSettings() {
        const root = rootObject
        if (!root || !appSettingsRef) return
        if (Number(root.readerComicId || 0) < 1) return
        if (!readerDialog || !readerDialog.visible) return
        if (Boolean(appSettingsRef.readerRememberLastReaderMode)) return

        const nextMode = typeof appSettingsRef.normalizedReaderViewMode === "function"
            ? appSettingsRef.normalizedReaderViewMode(root.readerViewMode)
            : "one_page"
        setReaderViewMode(nextMode)
    }

    function syncOpenReaderMangaLayoutPreferences() {
        const root = rootObject
        if (!root) return
        if (Number(root.readerComicId || 0) < 1) return
        if (!readerDialog || !readerDialog.visible) return
        readerDisplayModeController.refreshCurrentTwoPageLayoutForPreferences()
    }

    function handleReaderDialogClosed() {
        finalizeReaderSession(true)
    }

    function showReaderActionError(message) {
        const text = String(message || "").trim()
        if (text.length < 1 || !popupControllerRef) return
        if (typeof popupControllerRef.showMappedActionResult === "function") {
            popupControllerRef.showMappedActionResult(AppErrorMapper.readerActionResult(text))
            return
        }
        popupControllerRef.showActionResult(text, true)
    }

    function scheduleReaderGridRefresh() {
        const root = rootObject
        if (!root || typeof root.scheduleIssuesGridRefresh !== "function") return
        root.scheduleIssuesGridRefresh(true, true)
    }

    function handlePendingPopupLoadFailure(message, suppressPopup) {
        const text = String(message || "").trim()
        clearPendingPopupOpen()
        finalizeReaderSession(false)
        if (Boolean(suppressPopup) || text.length < 1) {
            return
        }
        showReaderActionError(text)
    }

    function coverSourceForComic(comicId) {
        const root = rootObject
        if (!root) return ""
        return String(root.coverByComicId[String(comicId)] || "")
    }

    function setCoverSource(comicId, source) {
        const root = rootObject
        if (!root) return
        const key = String(comicId)
        const next = Object.assign({}, root.coverByComicId)
        next[key] = String(source || "")
        root.coverByComicId = next
    }

    function clearCoverSourcesForComicIds(comicIds) {
        const root = rootObject
        if (!root) return

        const ids = Array.isArray(comicIds) ? comicIds : []
        if (ids.length < 1) return

        const current = root.coverByComicId && typeof root.coverByComicId === "object"
            ? root.coverByComicId
            : {}
        const next = Object.assign({}, current)
        let changed = false

        for (let i = 0; i < ids.length; i += 1) {
            const comicId = Number(ids[i] || 0)
            if (comicId < 1) continue

            const key = String(comicId)
            if (!Object.prototype.hasOwnProperty.call(next, key)) continue
            delete next[key]
            changed = true
        }

        if (changed) {
            root.coverByComicId = next
        }
    }

    function stripSourceRevision(source) {
        return String(source || "").trim().replace(/[?#].*$/, "")
    }

    function cacheBustedSource(source) {
        const text = String(source || "").trim()
        if (text.length < 1) return ""
        const separator = text.indexOf("?") >= 0 ? "&" : "?"
        return text + separator + "v=" + String(Date.now())
    }

    function refreshedCoverSource(existingSource, nextSource) {
        const normalizedNext = String(nextSource || "").trim()
        if (normalizedNext.length < 1) return ""

        const existingBase = stripSourceRevision(existingSource)
        const nextBase = stripSourceRevision(normalizedNext)
        if (existingBase.length > 0 && existingBase === nextBase) {
            return cacheBustedSource(normalizedNext)
        }
        return normalizedNext
    }

    function requestIssueThumbnail(comicId) {
        if (comicId < 1 || !libraryModelRef) return
        libraryModelRef.requestIssueThumbnailAsync(comicId)
    }

    function resolvedSeriesKeyForComic(comicId, fallbackSeriesKey) {
        const normalizedComicId = Number(comicId || 0)
        if (!libraryModelRef || normalizedComicId < 1) {
            return String(fallbackSeriesKey || "").trim()
        }

        if (typeof libraryModelRef.navigationTargetForComic === "function") {
            const target = libraryModelRef.navigationTargetForComic(normalizedComicId) || ({})
            const resolvedSeriesKey = String(target.seriesKey || "").trim()
            if (Boolean(target.ok) && resolvedSeriesKey.length > 0) {
                return resolvedSeriesKey
            }
        }

        return String(fallbackSeriesKey || "").trim()
    }

    function displaySeriesTitleForIssue(issue) {
        const row = issue || {}
        const series = String(row.series || "").trim()
        const volume = String(row.volume || "").trim()
        if (series.length < 1) return ""
        if (volume.length < 1) return series
        return series + " - Vol. " + volume
    }

    function snapshotHeroFallbackComicId() {
        const root = rootObject
        if (!root) return -1

        const selectedTitle = String(root.selectedSeriesTitle || "").trim()
        if (selectedTitle.length < 1) return -1

        const rows = Array.isArray(root.issuesGridData) ? root.issuesGridData : []
        if (rows.length < 1) return -1

        const firstIssue = rows[0] || {}
        const gridTitle = displaySeriesTitleForIssue(firstIssue)
        if (gridTitle.length < 1 || gridTitle !== selectedTitle) return -1

        return Number(firstIssue.id || -1)
    }

    function resolveHeroCoverForSelectedSeries() {
        const root = rootObject
        if (!root || !libraryModelRef) return

        const key = String(root.selectedSeriesKey || "")
        if (key.length < 1) {
            root.heroCoverComicId = -1
            return
        }

        const resolvedId = Number(libraryModelRef.heroCoverComicIdForSeries(key) || -1)
        if (resolvedId > 0) {
            root.heroCoverComicId = resolvedId
            requestIssueThumbnail(resolvedId)
            return
        }

        const fallbackId = snapshotHeroFallbackComicId()
        if (fallbackId > 0) {
            root.heroCoverComicId = fallbackId
            if (coverSourceForComic(fallbackId).length < 1) {
                requestIssueThumbnail(fallbackId)
            }
            return
        }

        root.heroCoverComicId = -1
    }

    function resolveHeroBackgroundForSelectedSeries() {
        const root = rootObject
        if (!root || !libraryModelRef) return

        const key = String(root.selectedSeriesKey || "").trim()
        if (key.length < 1) {
            root.heroBackgroundRequestId = -1
            root.heroBackgroundSeriesKey = ""
            root.heroBackgroundSource = ""
            return
        }

        const isSameSeries = key === String(root.heroBackgroundSeriesKey || "")
        root.heroBackgroundSeriesKey = key
        root.heroBackgroundRequestId = Number(libraryModelRef.requestSeriesHeroAsync(key) || -1)
        if (root.heroBackgroundRequestId < 1) {
            root.heroBackgroundSource = ""
            return
        }
        if (!isSameSeries) {
            root.heroBackgroundSource = ""
        }
    }

    function visibleIssueRange(totalCount) {
        const total = Math.max(0, Number(totalCount || 0))
        if (total < 1) return { start: 0, end: -1 }

        if (!issuesFlick) {
            const fallbackEnd = Math.min(total - 1, 19)
            return { start: 0, end: fallbackEnd }
        }

        const cols = Math.max(1, Number(issuesFlick.columns || 1))
        const cellH = Math.max(1, Number(issuesFlick.cellHeight || 1))
        const viewH = Math.max(1, Number(issuesFlick.height || 1))
        const normalizedY = Math.max(0, Number(issuesFlick.contentY || 0))
        const firstRow = Math.max(0, Math.floor(normalizedY / cellH))
        const rowsVisible = Math.max(1, Math.ceil(viewH / cellH))
        const preloadBefore = 1
        const preloadAfter = 2
        const startRow = Math.max(0, firstRow - preloadBefore)
        const endRow = firstRow + rowsVisible + preloadAfter

        const start = Math.max(0, startRow * cols)
        const end = Math.min(total - 1, (endRow * cols) - 1)
        return { start: start, end: end }
    }

    function primeVisibleIssueCoverSourcesFromCache() {
        const root = rootObject
        if (!root || !libraryModelRef) return

        const total = Number(root.issuesGridData.length || 0)
        if (total < 1) return

        const range = visibleIssueRange(total)
        for (let i = range.start; i <= range.end; i += 1) {
            const item = root.issuesGridData[i]
            const comicId = Number(item && item.id ? item.id : 0)
            if (comicId < 1) continue
            if (coverSourceForComic(comicId).length > 0) continue
            const cachedSource = String(libraryModelRef.cachedIssueThumbnailSource(comicId) || "")
            if (cachedSource.length > 0) {
                setCoverSource(comicId, cachedSource)
            }
        }
    }

    function warmVisibleIssueThumbnails() {
        const root = rootObject
        if (!root) return

        const total = Number(root.issuesGridData.length || 0)
        if (total < 1) return

        const range = visibleIssueRange(total)
        for (let i = range.start; i <= range.end; i += 1) {
            const item = root.issuesGridData[i]
            const comicId = Number(item && item.id ? item.id : 0)
            if (comicId < 1) continue
            if (coverSourceForComic(comicId).length > 0) continue
            requestIssueThumbnail(comicId)
        }
    }

    function beginReaderSession(comicId, title, openPopup, startPageOverride, persistGuardPageIndex) {
        const root = rootObject
        if (!root || !libraryModelRef) return

        clearPendingPopupOpen()
        resetReaderLayoutState()
        clearPendingReaderStartOverride()
        clearPendingReaderPersistGuard()
        if (appSettingsRef && typeof appSettingsRef.normalizedReaderViewMode === "function") {
            root.readerViewMode = appSettingsRef.normalizedReaderViewMode(root.readerViewMode)
        }
        root.readerComicId = Number(comicId || -1)
        root.readerTitle = String(title || ("Issue #" + comicId))
        root.readerPageCount = 0
        root.readerPageIndex = 0
        root.readerSessionRequestId = Number(libraryModelRef.requestReaderSessionAsync(comicId) || 0)
        root.readerPageRequestId = -1
        root.readerImageSource = ""
        root.readerError = ""
        root.readerLoading = true
        root.readerPrefetchRequestIds = ({})
        if (Boolean(openPopup)) {
            const shouldOpenFullscreen = appSettingsRef && typeof appSettingsRef.shouldOpenReaderFullscreen === "function"
                ? appSettingsRef.shouldOpenReaderFullscreen()
                : false
            if (typeof root.setReaderWindowFullscreen === "function") {
                root.setReaderWindowFullscreen(shouldOpenFullscreen)
            } else {
                root.readerUiFullscreen = shouldOpenFullscreen
            }
            if (readerDialog && popupControllerRef) {
                popupControllerRef.openExclusivePopup(readerDialog)
            }
        }
        const normalizedStartPageOverride = Number(startPageOverride)
        if (!isNaN(normalizedStartPageOverride) && normalizedStartPageOverride >= 0) {
            pendingReaderStartOverrideComicId = Number(comicId || -1)
            pendingReaderStartOverridePageIndex = Math.max(0, Math.round(normalizedStartPageOverride))
        }
        const normalizedPersistGuardPageIndex = Number(persistGuardPageIndex)
        if (!isNaN(normalizedPersistGuardPageIndex) && normalizedPersistGuardPageIndex >= 0) {
            pendingReaderPersistGuardComicId = Number(comicId || -1)
            pendingReaderPersistGuardPageIndex = Math.max(0, Math.round(normalizedPersistGuardPageIndex))
        }
        root.readerSeriesKey = resolvedSeriesKeyForComic(
            root.readerComicId,
            root.readerSeriesKey
        )
        root.readerBookmarkActive = false
        root.readerBookmarkPageIndex = -1
        root.readerBookmarkComicId = -1
        root.readerFavoriteActive = false
        root.readerDisplayPages = []
        readerDisplayModeController.beginPageMetricsRequest(root.readerComicId)
    }

    function readerIssueRows() {
        const root = rootObject
        if (!root) return []
        const gridRows = listCopy(root.issuesGridData)

        const seriesKey = String(root.readerSeriesKey || "").trim()
        if (libraryModelRef && seriesKey.length > 0) {
            const seriesRows = libraryModelRef.issuesForSeries(seriesKey, "__all__", "all", "")
            if (listCount(seriesRows) > 0) {
                return listCopy(seriesRows)
            }
        }

        return gridRows
    }

    function currentReaderIssueIndex() {
        const root = rootObject
        if (!root) return -1
        const rows = readerIssueRows()
        for (let i = 0; i < rows.length; i += 1) {
            const row = rows[i] || {}
            if (Number(row.id || 0) === Number(root.readerComicId || 0)) {
                return i
            }
        }
        return -1
    }

    function readerIssueCount() {
        return readerIssueRows().length
    }

    function canNavigateReaderIssue(offset) {
        const currentIndex = currentReaderIssueIndex()
        if (currentIndex < 0) return false
        const rows = readerIssueRows()
        const targetIndex = currentIndex + Number(offset || 0)
        return targetIndex >= 0 && targetIndex < rows.length
    }

    function navigateReaderIssue(offset) {
        if (!canNavigateReaderIssue(offset)) return
        const rows = readerIssueRows()
        const currentIndex = currentReaderIssueIndex()
        const targetRow = rows[currentIndex + Number(offset || 0)] || {}
        const targetComicId = Number(targetRow.id || 0)
        if (targetComicId < 1) return
        persistReaderProgress(false)
        beginReaderSession(
            targetComicId,
            String(targetRow.title || targetRow.filename || ("Issue #" + targetComicId)),
            false,
            -1,
            -1
        )
    }

    function markCurrentReaderIssueReadAndAdvance() {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (Number(root.readerComicId || 0) < 1) return
        if (Number(root.readerPageCount || 0) < 1) return

        const targetPageValue = Number(root.readerPageCount || 0)
        root.readerPageIndex = Math.max(0, targetPageValue - 1)
        const saveError = String(libraryModelRef.saveReaderProgress(root.readerComicId, targetPageValue) || "").trim()
        if (saveError.length > 0) {
            if (typeof root.queueSilentReaderProgressSave === "function") {
                root.queueSilentReaderProgressSave(root.readerComicId, targetPageValue, true)
            }
        } else {
            scheduleReaderGridRefresh()
        }

        const clearBookmarkError = String(libraryModelRef.saveReaderBookmark(root.readerComicId, 0) || "").trim()
        if (clearBookmarkError.length === 0) {
            root.readerBookmarkPageIndex = -1
            root.readerBookmarkActive = false
            root.readerBookmarkComicId = -1
            scheduleReaderGridRefresh()
        }

        if (!canNavigateReaderIssue(1)) {
            closeReader()
            return
        }

        const rows = readerIssueRows()
        const currentIndex = currentReaderIssueIndex()
        const targetRow = rows[currentIndex + 1] || {}
        const targetComicId = Number(targetRow.id || 0)
        if (targetComicId < 1) return

        const targetReadStatus = String(targetRow.readStatus || "").trim().toLowerCase()
        const targetCurrentPage = Number(targetRow.currentPage || 0)
        if (targetCurrentPage > 0 && targetReadStatus !== "read") {
            const resetNextIssueError = String(libraryModelRef.saveReaderProgress(targetComicId, 0) || "").trim()
            if (resetNextIssueError.length > 0) {
                if (typeof root.queueSilentReaderProgressSave === "function") {
                    root.queueSilentReaderProgressSave(targetComicId, 0, true)
                }
            } else {
                scheduleReaderGridRefresh()
            }
        }

        beginReaderSession(
            targetComicId,
            String(targetRow.title || targetRow.filename || ("Issue #" + targetComicId)),
            false
        )
    }

    function toggleCurrentReaderFavorite() {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (Number(root.readerComicId || 0) < 1) return

        const nextFavoriteState = !Boolean(root.readerFavoriteActive)
        const saveError = String(libraryModelRef.saveReaderFavorite(root.readerComicId, nextFavoriteState) || "").trim()
        if (saveError.length > 0) {
            if (popupControllerRef) {
                popupControllerRef.showActionResult(saveError, true)
            }
            return
        }

        root.readerFavoriteActive = nextFavoriteState
        scheduleReaderGridRefresh()
    }

    function toggleCurrentReaderBookmark() {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (Number(root.readerComicId || 0) < 1) return
        if (Number(root.readerPageCount || 0) < 1) return

        const currentPageIndex = normalizedReaderPageIndex(root.readerPageIndex)
        if (currentPageIndex < 0) return

        const bookmarkBelongsToCurrentIssue = Number(root.readerBookmarkComicId || -1)
            === Number(root.readerComicId || 0)
        const currentBookmarkPageIndex = bookmarkBelongsToCurrentIssue
            ? normalizedBookmarkPageIndex(root.readerBookmarkPageIndex)
            : -1
        const nextBookmarkPageValue = currentBookmarkPageIndex >= 0
            ? 0
            : (currentPageIndex + 1)
        const saveError = String(libraryModelRef.saveReaderBookmark(root.readerComicId, nextBookmarkPageValue) || "").trim()
        if (saveError.length > 0) {
            if (popupControllerRef) {
                popupControllerRef.showActionResult(saveError, true)
            }
            return
        }

        root.readerBookmarkPageIndex = nextBookmarkPageValue > 0 ? (nextBookmarkPageValue - 1) : -1
        root.readerBookmarkActive = nextBookmarkPageValue > 0
        root.readerBookmarkComicId = nextBookmarkPageValue > 0
            ? Number(root.readerComicId || -1)
            : -1
        scheduleReaderGridRefresh()
    }

    function jumpToReaderBookmark() {
        const root = rootObject
        if (!root) return
        if (Number(root.readerBookmarkComicId || -1) !== Number(root.readerComicId || 0)) return
        const bookmarkPageIndex = normalizedBookmarkPageIndex(root.readerBookmarkPageIndex)
        if (bookmarkPageIndex < 0) return
        loadReaderPage(bookmarkPageIndex)
    }

    function copyCurrentReaderImageToClipboard() {
        const root = rootObject
        if (!root || !libraryModelRef) return ""
        return String(libraryModelRef.copyImageFileToClipboard(String(root.readerImageSource || "")) || "").trim()
    }

    function refreshReaderAfterDeletedPage(result) {
        const root = rootObject
        if (!root) return
        if (Number(root.readerComicId || 0) < 1) return

        const nextPageCount = Math.max(0, Number((result || {}).pageCount || 0))
        const nextCurrentPage = Math.max(0, Number((result || {}).currentPage || 0))
        const nextBookmarkPage = Math.max(0, Number((result || {}).bookmarkPage || 0))
        const deletedPageIndex = Number((result || {}).deletedPageIndex)
        const targetPageIndex = nextPageCount > 0
            ? Math.max(0, Math.min(nextPageCount - 1, nextCurrentPage - 1))
            : 0

        root.readerPageCount = nextPageCount
        root.readerBookmarkPageIndex = nextBookmarkPage > 0 ? (nextBookmarkPage - 1) : -1
        root.readerBookmarkActive = root.readerBookmarkPageIndex >= 0
        root.readerBookmarkComicId = root.readerBookmarkActive
            ? Number(root.readerComicId || -1)
            : -1
        root.readerError = ""

        readerDisplayModeController.applyDeletedPageToLayout(deletedPageIndex, nextPageCount)
        readerDisplayModeController.loadReaderPage(targetPageIndex, true)
        scheduleReaderGridRefresh()
    }

    function openReader(comicId, title) {
        beginReaderSession(comicId, title, true, -1, -1)
    }

    function loadReaderPage(pageIndex) {
        const root = rootObject
        if (root
            && Number(pendingReaderPersistGuardComicId || -1) === Number(root.readerComicId || 0)
            && Number(pendingReaderPersistGuardPageIndex || -1) !== Number(pageIndex || 0)) {
            clearPendingReaderPersistGuard()
        }
        readerDisplayModeController.loadReaderPage(pageIndex)
    }

    function shouldSuppressReaderStateError(message) {
        const text = String(message || "").trim()
        return text.indexOf("Archive path is empty for issue id ") === 0
            || text === "Reader session is not ready."
            || text === "Invalid issue id."
    }

    function persistReaderProgress(refreshAfterSuccess) {
        const root = rootObject
        if (!root || !libraryModelRef) return true
        if (root.readerComicId < 1) return true
        if (root.readerSessionRequestId > 0) return true
        if (root.readerPageCount < 1) return true
        if (String(root.readerImageSource || "").length < 1) return true
        if (Number(pendingReaderPersistGuardComicId || -1) === Number(root.readerComicId || 0)
            && Number(pendingReaderPersistGuardPageIndex || -1) === Number(root.readerPageIndex || 0)) {
            return true
        }

        const bookmarkBelongsToCurrentIssue = Number(root.readerBookmarkComicId || -1)
            === Number(root.readerComicId || 0)
        const bookmarkPageIndex = bookmarkBelongsToCurrentIssue
            ? normalizedBookmarkPageIndex(root.readerBookmarkPageIndex)
            : -1
        const targetPersistPage = bookmarkPageIndex >= 0
            ? (bookmarkPageIndex + 1)
            : (root.readerPageIndex + 1)

        const saveError = libraryModelRef.saveReaderProgress(root.readerComicId, targetPersistPage)
        if (saveError.length > 0) {
            if (typeof root.queueSilentReaderProgressSave === "function") {
                root.queueSilentReaderProgressSave(
                    root.readerComicId,
                    targetPersistPage,
                    refreshAfterSuccess === true
                )
            }
            return false
        }

        return true
    }

    function finalizeReaderSession(showErrorDialog) {
        const root = rootObject
        if (!root) return
        if (root.readerFinalizing) return
        root.readerFinalizing = true

        if (Number(root.readerComicId || 0) > 0 && typeof root.rememberContinueReadingTarget === "function") {
            root.rememberContinueReadingTarget(
                root.readerComicId,
                root.readerSeriesKey,
                root.readerTitle
            )
        }

        clearPendingPopupOpen()
        const persisted = persistReaderProgress(showErrorDialog === true)
        if (persisted) {
            scheduleReaderGridRefresh()
        }

        root.readerComicId = -1
        root.readerTitle = ""
        root.readerPageIndex = 0
        root.readerPageCount = 0
        root.readerSessionRequestId = -1
        root.readerPageRequestId = -1
        root.readerImageSource = ""
        root.readerDisplayPages = []
        root.readerError = ""
        root.readerLoading = false
        root.readerPrefetchRequestIds = ({})
        if (typeof root.setReaderWindowFullscreen === "function") {
            root.setReaderWindowFullscreen(false)
        } else {
            root.readerUiFullscreen = false
        }
        root.readerSeriesKey = ""
        root.readerBookmarkActive = false
        root.readerBookmarkPageIndex = -1
        root.readerBookmarkComicId = -1
        root.readerFavoriteActive = false
        clearPendingReaderStartOverride()
        clearPendingReaderPersistGuard()
        resetReaderLayoutState()
        root.readerFinalizing = false
    }

    function closeReader() {
        if (readerDialog && readerDialog.visible) {
            readerDialog.reject()
            return
        }
        finalizeReaderSession(true)
    }

    function advanceToNextReaderIssueFromPageFlow() {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (!canNavigateReaderIssue(1)) return

        persistReaderProgress(false)

        const rows = readerIssueRows()
        const currentIndex = currentReaderIssueIndex()
        const targetRow = rows[currentIndex + 1] || {}
        const targetComicId = Number(targetRow.id || 0)
        if (targetComicId < 1) return

        const targetReadStatus = String(targetRow.readStatus || "").trim().toLowerCase()
        const targetCurrentPage = Number(targetRow.currentPage || 0)
        if (targetCurrentPage > 0 && targetReadStatus !== "read") {
            const resetNextIssueError = String(libraryModelRef.saveReaderProgress(targetComicId, 0) || "").trim()
            if (resetNextIssueError.length > 0) {
                if (typeof root.queueSilentReaderProgressSave === "function") {
                    root.queueSilentReaderProgressSave(targetComicId, 0, true)
                }
            } else {
                scheduleReaderGridRefresh()
            }
        }

        beginReaderSession(
            targetComicId,
            String(targetRow.title || targetRow.filename || ("Issue #" + targetComicId)),
            false,
            0,
            0
        )
    }

    function retreatToPreviousReaderIssueFromPageFlow() {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (!canNavigateReaderIssue(-1)) return

        persistReaderProgress(false)

        const rows = readerIssueRows()
        const currentIndex = currentReaderIssueIndex()
        const targetRow = rows[currentIndex - 1] || {}
        const targetComicId = Number(targetRow.id || 0)
        if (targetComicId < 1) return

        // Use a large temporary override so the previous issue opens on its last page.
        beginReaderSession(
            targetComicId,
            String(targetRow.title || targetRow.filename || ("Issue #" + targetComicId)),
            false,
            1000000,
            1000000
        )
    }

    function nextReaderPage() {
        const targetAnchor = readerDisplayModeController.targetAnchorForDisplayOffset(1)
        if (targetAnchor < 0) {
            if (!shouldContinueReaderAtBoundary()) return
            advanceToNextReaderIssueFromPageFlow()
            return
        }
        loadReaderPage(targetAnchor)
    }

    function previousReaderPage() {
        const targetAnchor = readerDisplayModeController.targetAnchorForDisplayOffset(-1)
        if (targetAnchor < 0) {
            if (!shouldContinueReaderAtBoundary()) return
            retreatToPreviousReaderIssueFromPageFlow()
            return
        }
        loadReaderPage(targetAnchor)
    }

    Connections {
        target: libraryModelRef

        function onReaderSessionReady(requestId, result) {
            const root = rootObject
            if (!root) return
            if (requestId !== root.readerSessionRequestId) return

            root.readerSessionRequestId = -1
            const requestError = String((result || {}).error || "").trim()
            if (requestError.length > 0) {
                root.readerLoading = false
                const suppressPopup = shouldSuppressReaderStateError(requestError)
                if (readerDialog && readerDialog.visible) {
                    readerDialog.close()
                } else {
                    finalizeReaderSession(false)
                }
                if (suppressPopup) {
                    root.readerError = ""
                } else {
                    root.readerError = ""
                    showReaderActionError(requestError)
                }
                return
            }

            root.readerComicId = Number(result.comicId || root.readerComicId)
            root.readerSeriesKey = resolvedSeriesKeyForComic(
                Number(result.comicId || root.readerComicId),
                String(result.seriesKey || root.readerSeriesKey || "").trim()
            )
            root.readerTitle = String(result.title || root.readerTitle || ("Issue #" + root.readerComicId))
            root.readerPageCount = Number(result.pageCount || 0)
            const hasPendingStartOverride = Number(pendingReaderStartOverrideComicId || -1) === Number(root.readerComicId || 0)
                && Number(pendingReaderStartOverridePageIndex || -1) >= 0
            const overridePageIndex = hasPendingStartOverride
                ? Math.max(0, Math.min(Number(root.readerPageCount || 1) - 1, Number(pendingReaderStartOverridePageIndex || 0)))
                : -1
            root.readerPageIndex = hasPendingStartOverride
                ? overridePageIndex
                : preferredReaderStartPageIndex(result)
            clearPendingReaderStartOverride()
            if (Number(pendingReaderPersistGuardComicId || -1) === Number(root.readerComicId || 0)
                && Number(pendingReaderPersistGuardPageIndex || -1) >= 0) {
                pendingReaderPersistGuardPageIndex = Number(root.readerPageIndex || 0)
            }
            const rawBookmarkPage = Number(result.bookmarkPage || 0)
            const validBookmarkPage = rawBookmarkPage > 0
                && rawBookmarkPage <= Number(root.readerPageCount || 0)
                ? rawBookmarkPage
                : 0
            if (validBookmarkPage !== rawBookmarkPage && Number(root.readerComicId || 0) > 0) {
                const clearBookmarkError = String(libraryModelRef.saveReaderBookmark(root.readerComicId, 0) || "").trim()
                if (clearBookmarkError.length === 0) {
                    scheduleReaderGridRefresh()
                }
            }
            root.readerBookmarkPageIndex = validBookmarkPage > 0
                ? (validBookmarkPage - 1)
                : -1
            root.readerBookmarkActive = root.readerBookmarkPageIndex >= 0
            root.readerBookmarkComicId = root.readerBookmarkActive
                ? Number(root.readerComicId || -1)
                : -1
            root.readerFavoriteActive = Boolean(result.favoriteActive)
            if (typeof root.rememberContinueReadingTarget === "function") {
                root.rememberContinueReadingTarget(
                    root.readerComicId,
                    root.readerSeriesKey,
                    root.readerTitle
                )
            }
            readerDisplayModeController.recordSessionEntries((result || {}).entries || [])
            root.readerError = ""
            root.readerLoading = true
            const openedFromProvisionalLayout = readerDisplayModeController.maybeApplyProvisionalLayout()

            if (!openedFromProvisionalLayout) {
                loadReaderPage(root.readerPageIndex)
            }
            readerDisplayModeController.prefetchReaderNeighbors(root.readerPageIndex)
        }

        function onPageImageReady(requestId, comicId, pageIndex, imageSource, error, thumbnail) {
            const root = rootObject
            if (!root) return

            if (thumbnail) {
                if (String(error).length === 0 && String(imageSource).length > 0) {
                    setCoverSource(comicId, refreshedCoverSource(coverSourceForComic(comicId), imageSource))
                }
            }
        }

        function onSeriesHeroReady(requestId, seriesKey, imageSource, error) {
            const root = rootObject
            if (!root) return
            if (requestId !== root.heroBackgroundRequestId) return

            root.heroBackgroundRequestId = -1
            if (String(root.selectedSeriesKey || "").trim() !== String(seriesKey || "").trim()) {
                return
            }

            root.heroBackgroundSeriesKey = String(seriesKey || "").trim()
            if (String(error || "").trim().length > 0 || String(imageSource || "").trim().length < 1) {
                root.heroBackgroundSource = ""
                return
            }

            root.heroBackgroundSource = String(imageSource || "")
        }
    }

    Connections {
        target: appSettingsRef

        function onReaderDefaultReadingModeChanged() {
            controller.syncOpenReaderViewModeFromSettings()
        }

        function onReaderRememberLastReaderModeChanged() {
            controller.syncOpenReaderViewModeFromSettings()
        }
    }

    Connections {
        target: rootObject

        function onReaderMangaModeEnabledChanged() {
            controller.syncOpenReaderMangaLayoutPreferences()
        }

        function onReaderMangaSpreadOffsetEnabledChanged() {
            controller.syncOpenReaderMangaLayoutPreferences()
        }
    }
}
