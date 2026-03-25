import QtQuick
import "ReaderSpreadLayout.js" as ReaderSpreadLayout

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var libraryModelRef: null
    property var readerDialogRef: null
    property var readerCoverControllerRef: null
    readonly property real widePageThresholdFactor: 1.2
    property int metricsRequestId: -1
    property var pageMetrics: []
    property var twoPageSpreads: []
    property bool twoPageLayoutReady: false
    property var sessionEntries: []
    property int displayToken: 0
    property var displayRequestMeta: ({})

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

    function currentReaderViewMode() {
        const root = rootObject
        if (!root) return "one_page"
        return String(root.readerViewMode || "one_page") === "two_page"
            ? "two_page"
            : "one_page"
    }

    function readerUsesTwoPageLayout() {
        return currentReaderViewMode() === "two_page" && twoPageLayoutReady
    }

    function normalizedReaderPageIndex(pageIndex) {
        const root = rootObject
        if (!root) return -1
        const total = Math.max(0, Number(root.readerPageCount || 0))
        if (total < 1) return -1
        return Math.max(0, Math.min(total - 1, Number(pageIndex || 0)))
    }

    function pageMetricFor(pageIndex) {
        const metrics = Array.isArray(pageMetrics) ? pageMetrics : []
        const index = Number(pageIndex || 0)
        if (index < 0 || index >= metrics.length) {
            return { "width": 0, "height": 0 }
        }
        const metric = metrics[index] || {}
        return {
            "width": Math.max(0, Number(metric.width || 0)),
            "height": Math.max(0, Number(metric.height || 0))
        }
    }

    function clearDisplayState() {
        const root = rootObject
        if (!root) return
        root.readerDisplayPages = []
        root.readerImageSource = ""
        root.readerPageRequestId = -1
    }

    function resetLayoutState() {
        metricsRequestId = -1
        pageMetrics = []
        twoPageSpreads = []
        twoPageLayoutReady = false
        sessionEntries = []
        displayToken = 0
        displayRequestMeta = ({})
        clearDisplayState()
    }

    function recordSessionEntries(entryNames) {
        sessionEntries = listCopy(entryNames)
    }

    function applyReaderPageMetrics(comicId, metricsInput) {
        const root = rootObject
        if (!root) return
        if (Number(comicId || 0) !== Number(root.readerComicId || 0)) return

        const total = Math.max(
            Number(root.readerPageCount || 0),
            listCount(metricsInput)
        )
        const layout = ReaderSpreadLayout.buildTwoPageLayout(
            metricsInput,
            total,
            widePageThresholdFactor
        )
        pageMetrics = Array.isArray(layout.metrics) ? layout.metrics : []
        twoPageSpreads = Array.isArray(layout.spreads) ? layout.spreads : []
        twoPageLayoutReady = twoPageSpreads.length > 0

        if (currentReaderViewMode() === "two_page"
            && Number(root.readerPageCount || 0) > 0) {
            loadReaderPage(root.readerPageIndex)
        }
    }

    function buildProvisionalReaderPageMetrics(entryNames, totalCount) {
        const total = Math.max(0, Number(totalCount || 0))
        const source = listCopy(entryNames)
        const metrics = []
        for (let i = 0; i < total; i += 1) {
            metrics.push({
                "pageIndex": i,
                "entryName": String(source[i] || ""),
                "width": 0,
                "height": 0
            })
        }
        return metrics
    }

    function maybeApplyProvisionalLayout() {
        const root = rootObject
        if (!root) return false
        if (currentReaderViewMode() !== "two_page" || twoPageLayoutReady) {
            return false
        }

        const provisionalMetrics = buildProvisionalReaderPageMetrics(
            sessionEntries,
            root.readerPageCount
        )
        if (provisionalMetrics.length < 1) {
            return false
        }

        applyReaderPageMetrics(root.readerComicId, provisionalMetrics)
        return twoPageLayoutReady
            && Number(root.readerPageCount || 0) > 0
    }

    function beginPageMetricsRequest(comicId) {
        if (!libraryModelRef) return
        const normalizedComicId = Number(comicId || 0)
        if (normalizedComicId < 1) return

        const cachedMetrics = libraryModelRef.cachedReaderPageMetrics(normalizedComicId)
        if (listCount(cachedMetrics) > 0) {
            applyReaderPageMetrics(normalizedComicId, cachedMetrics)
            return
        }

        metricsRequestId = Number(libraryModelRef.requestReaderPageMetricsAsync(normalizedComicId) || -1)
    }

    function displayPageIndexesForReaderPage(pageIndex) {
        const normalizedIndex = normalizedReaderPageIndex(pageIndex)
        if (normalizedIndex < 0) return []

        if (!readerUsesTwoPageLayout()) {
            return [normalizedIndex]
        }

        const spreadPages = ReaderSpreadLayout.pageIndexesForPage(twoPageSpreads, normalizedIndex)
        if (Array.isArray(spreadPages) && spreadPages.length > 0) {
            return spreadPages
        }

        return [normalizedIndex]
    }

    function buildDisplayPageDescriptors(pageIndexes) {
        const descriptors = []
        const source = Array.isArray(pageIndexes) ? pageIndexes : []
        for (let i = 0; i < source.length; i += 1) {
            const pageIndex = Number(source[i] || 0)
            const metric = pageMetricFor(pageIndex)
            descriptors.push({
                "pageIndex": pageIndex,
                "width": metric.width,
                "height": metric.height,
                "imageSource": ""
            })
        }
        return descriptors
    }

    function updateDisplayPageSourceForRequest(displayTokenValue, slotIndex, pageIndex, imageSource) {
        const root = rootObject
        if (!root) return
        if (Number(displayTokenValue || 0) !== Number(displayToken || 0)) return

        const currentPages = Array.isArray(root.readerDisplayPages) ? root.readerDisplayPages.slice(0) : []
        if (slotIndex < 0 || slotIndex >= currentPages.length) return

        const nextPage = Object.assign({}, currentPages[slotIndex] || {})
        nextPage.pageIndex = Number(pageIndex || 0)
        nextPage.imageSource = String(imageSource || "")
        currentPages[slotIndex] = nextPage
        root.readerDisplayPages = currentPages
    }

    function canNavigateDisplay(offset) {
        const root = rootObject
        if (!root) return false

        const currentPageIndex = normalizedReaderPageIndex(root.readerPageIndex)
        if (currentPageIndex < 0) return false

        if (!readerUsesTwoPageLayout()) {
            const target = currentPageIndex + Number(offset || 0)
            return target >= 0 && target < Number(root.readerPageCount || 0)
        }

        return ReaderSpreadLayout.canNavigate(
            twoPageSpreads,
            currentPageIndex,
            offset
        )
    }

    function canGoPreviousDisplayPage() {
        return canNavigateDisplay(-1)
    }

    function canGoNextDisplayPage() {
        return canNavigateDisplay(1)
    }

    function targetAnchorForDisplayOffset(offset) {
        const root = rootObject
        if (!root) return -1

        const currentPageIndex = normalizedReaderPageIndex(root.readerPageIndex)
        if (currentPageIndex < 0) return -1

        if (!readerUsesTwoPageLayout()) {
            return normalizedReaderPageIndex(currentPageIndex + Number(offset || 0))
        }

        return ReaderSpreadLayout.targetAnchorForOffset(
            twoPageSpreads,
            currentPageIndex,
            offset
        )
    }

    function setReaderViewMode(mode) {
        const root = rootObject
        if (!root) return

        const normalizedMode = String(mode || "one_page") === "two_page"
            ? "two_page"
            : "one_page"
        if (String(root.readerViewMode || "one_page") === normalizedMode) return

        root.readerViewMode = normalizedMode
        let loadedFromProvisionalLayout = false

        if (normalizedMode === "two_page" && Number(root.readerComicId || 0) > 0) {
            loadedFromProvisionalLayout = maybeApplyProvisionalLayout()
            beginPageMetricsRequest(root.readerComicId)
        }

        if (!loadedFromProvisionalLayout
            && Number(root.readerComicId || 0) > 0
            && Number(root.readerPageCount || 0) > 0) {
            loadReaderPage(root.readerPageIndex)
        }
    }

    function loadReaderPage(pageIndex, preserveVisibleContent) {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (Number(root.readerComicId || 0) < 1) return

        const normalizedIndex = normalizedReaderPageIndex(pageIndex)
        if (normalizedIndex < 0) return

        root.readerError = ""
        root.readerLoading = true
        root.readerPageIndex = normalizedIndex
        if (!Boolean(preserveVisibleContent)) {
            clearDisplayState()
        } else {
            root.readerPageRequestId = -1
        }

        const nextDisplayToken = Number(displayToken || 0) + 1
        displayToken = nextDisplayToken
        const displayPageIndexes = displayPageIndexesForReaderPage(normalizedIndex)
        const nextDisplayPages = buildDisplayPageDescriptors(displayPageIndexes)
        if (Boolean(preserveVisibleContent)) {
            const currentPages = Array.isArray(root.readerDisplayPages) ? root.readerDisplayPages : []
            for (let i = 0; i < nextDisplayPages.length; i += 1) {
                const fallbackSource = String((currentPages[i] || {}).imageSource || "")
                if (fallbackSource.length > 0) {
                    nextDisplayPages[i].imageSource = fallbackSource
                    continue
                }
                if (i === 0) {
                    nextDisplayPages[i].imageSource = String(root.readerImageSource || "")
                }
            }
        }
        root.readerDisplayPages = nextDisplayPages

        const nextRequestMeta = ({})
        for (let i = 0; i < displayPageIndexes.length; i += 1) {
            const displayPageIndex = Number(displayPageIndexes[i] || 0)
            const requestId = Number(libraryModelRef.requestReaderPageAsync(root.readerComicId, displayPageIndex) || -1)
            if (requestId < 1) continue
            nextRequestMeta[String(requestId)] = {
                "token": nextDisplayToken,
                "slotIndex": i,
                "pageIndex": displayPageIndex,
                "primary": displayPageIndex === normalizedIndex
            }
            if (displayPageIndex === normalizedIndex) {
                root.readerPageRequestId = requestId
            }
        }
        displayRequestMeta = nextRequestMeta
        if (Object.keys(nextRequestMeta).length < 1) {
            root.readerLoading = false
        }
    }

    function applyDeletedPageToLayout(deletedPageIndex, remainingPageCount) {
        const normalizedDeletedPageIndex = Number(deletedPageIndex)
        const nextEntries = listCopy(sessionEntries)
        if (normalizedDeletedPageIndex >= 0 && normalizedDeletedPageIndex < nextEntries.length) {
            nextEntries.splice(normalizedDeletedPageIndex, 1)
        }
        sessionEntries = nextEntries

        const sourceMetrics = Array.isArray(pageMetrics) ? pageMetrics : []
        const nextMetrics = []
        for (let i = 0; i < sourceMetrics.length; i += 1) {
            if (i === normalizedDeletedPageIndex) continue
            nextMetrics.push(sourceMetrics[i])
        }

        if (nextMetrics.length < 1) {
            pageMetrics = []
            twoPageSpreads = []
            twoPageLayoutReady = false
            return
        }

        const layout = ReaderSpreadLayout.buildTwoPageLayout(
            nextMetrics,
            Number(remainingPageCount || nextMetrics.length),
            widePageThresholdFactor
        )
        pageMetrics = Array.isArray(layout.metrics) ? layout.metrics : []
        twoPageSpreads = Array.isArray(layout.spreads) ? layout.spreads : []
        twoPageLayoutReady = twoPageSpreads.length > 0
    }

    function prefetchReaderNeighborPage(pageIndex) {
        const root = rootObject
        if (!root || !libraryModelRef) return
        if (Number(root.readerComicId || 0) < 1) return
        if (pageIndex < 0 || pageIndex >= Number(root.readerPageCount || 0)) return
        if (pageIndex === Number(root.readerPageIndex || 0)) return

        const reqId = libraryModelRef.requestReaderPageAsync(root.readerComicId, pageIndex)
        if (reqId > 0) {
            const next = Object.assign({}, root.readerPrefetchRequestIds)
            next[String(reqId)] = true
            root.readerPrefetchRequestIds = next
        }
    }

    function prefetchReaderNeighbors(centerPageIndex) {
        const root = rootObject
        if (!root) return

        if (!readerUsesTwoPageLayout()) {
            prefetchReaderNeighborPage(centerPageIndex - 1)
            prefetchReaderNeighborPage(centerPageIndex + 1)
            return
        }

        const spreadIndex = ReaderSpreadLayout.spreadIndexForPage(
            twoPageSpreads,
            normalizedReaderPageIndex(centerPageIndex)
        )
        if (spreadIndex < 0) {
            prefetchReaderNeighborPage(centerPageIndex - 1)
            prefetchReaderNeighborPage(centerPageIndex + 1)
            return
        }

        const currentPages = ReaderSpreadLayout.pageIndexesForPage(twoPageSpreads, centerPageIndex)
        const seen = ({})
        for (let i = 0; i < currentPages.length; i += 1) {
            seen[String(currentPages[i])] = true
        }

        const neighborSpreadIndexes = [spreadIndex - 1, spreadIndex + 1]
        for (let i = 0; i < neighborSpreadIndexes.length; i += 1) {
            const spread = twoPageSpreads[neighborSpreadIndexes[i]] || {}
            const pageIndexes = Array.isArray(spread.pageIndexes) ? spread.pageIndexes : []
            for (let pageCursor = 0; pageCursor < pageIndexes.length; pageCursor += 1) {
                const pageIndex = Number(pageIndexes[pageCursor] || 0)
                if (seen[String(pageIndex)] === true) continue
                prefetchReaderNeighborPage(pageIndex)
            }
        }
    }

    function shouldSuppressReaderStateError(message) {
        const text = String(message || "").trim()
        return text.indexOf("Archive path is empty for issue id ") === 0
            || text === "Reader session is not ready."
            || text === "Invalid issue id."
    }

    Connections {
        target: libraryModelRef

        function onReaderPageMetricsReady(requestId, comicId, result) {
            const root = rootObject
            if (!root) return
            if (Number(comicId || 0) !== Number(root.readerComicId || 0)) return
            if (Number(requestId || 0) !== Number(metricsRequestId || 0)
                && metricsRequestId > 0) {
                return
            }

            metricsRequestId = -1
            const requestError = String((result || {}).error || "").trim()
            if (requestError.length > 0) {
                pageMetrics = []
                twoPageSpreads = []
                twoPageLayoutReady = false
                return
            }

            applyReaderPageMetrics(comicId, (result || {}).pageMetrics || [])
        }

        function onPageImageReady(requestId, comicId, pageIndex, imageSource, error, thumbnail) {
            const root = rootObject
            if (!root || thumbnail) return

            const prefetchKey = String(requestId)
            if (root.readerPrefetchRequestIds[prefetchKey] === true) {
                const next = Object.assign({}, root.readerPrefetchRequestIds)
                delete next[prefetchKey]
                root.readerPrefetchRequestIds = next
                return
            }

            const requestMeta = displayRequestMeta[String(requestId)] || null
            if (!requestMeta) return

            if (String(error).length > 0) {
                displayToken = Number(displayToken || 0) + 1
                displayRequestMeta = ({})
                root.readerPageRequestId = -1
                if (shouldSuppressReaderStateError(error)) {
                    if (readerDialogRef
                        && !readerDialogRef.visible
                        && readerCoverControllerRef
                        && typeof readerCoverControllerRef.handlePendingPopupLoadFailure === "function") {
                        readerCoverControllerRef.handlePendingPopupLoadFailure("", true)
                        return
                    }
                    root.readerError = ""
                    root.readerLoading = false
                    return
                }
                const popupController = readerCoverControllerRef
                    ? readerCoverControllerRef.popupControllerRef
                    : null
                if (readerDialogRef
                    && !readerDialogRef.visible
                    && readerCoverControllerRef
                    && typeof readerCoverControllerRef.handlePendingPopupLoadFailure === "function") {
                    readerCoverControllerRef.handlePendingPopupLoadFailure(String(error), false)
                    return
                }
                if (popupController && typeof popupController.showActionResult === "function") {
                    root.readerError = ""
                    root.readerLoading = false
                    if (readerCoverControllerRef && typeof readerCoverControllerRef.showReaderActionError === "function") {
                        readerCoverControllerRef.showReaderActionError(String(error))
                    } else {
                        popupController.showActionResult(String(error), true)
                    }
                    return
                }
                root.readerError = ""
                root.readerLoading = false
                return
            }

            updateDisplayPageSourceForRequest(
                Number(requestMeta.token || 0),
                Number(requestMeta.slotIndex || 0),
                Number(pageIndex || 0),
                String(imageSource || "")
            )
            root.readerError = ""
            if (requestMeta.primary === true) {
                root.readerPageIndex = Number(pageIndex || 0)
                root.readerImageSource = String(imageSource || "")
                root.readerPageRequestId = -1
            }

            const nextDisplayRequestMeta = Object.assign({}, displayRequestMeta)
            delete nextDisplayRequestMeta[String(requestId)]
            displayRequestMeta = nextDisplayRequestMeta

            if (Object.keys(displayRequestMeta).length > 0) {
                return
            }

            root.readerLoading = false
            if (readerCoverControllerRef && typeof readerCoverControllerRef.persistReaderProgress === "function") {
                readerCoverControllerRef.persistReaderProgress(false)
            }
            prefetchReaderNeighbors(root.readerPageIndex)
        }
    }
}
