import QtQuick

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var readerCoverControllerRef: null
    property int issueIndexInSeries: -1
    property int issueCountInSeries: 0

    function normalizedBookmarkPageIndex(value) {
        const parsed = Number(value)
        return isNaN(parsed) ? -1 : parsed
    }

    readonly property string issueTitle: {
        const root = rootObject
        return root ? String(root.readerTitle || "") : ""
    }
    readonly property string imageSource: {
        const root = rootObject
        return root ? String(root.readerImageSource || "") : ""
    }
    readonly property var displayPages: {
        const root = rootObject
        return root ? (root.readerDisplayPages || []) : []
    }
    readonly property string errorText: {
        const root = rootObject
        return root ? String(root.readerError || "") : ""
    }
    readonly property bool loading: {
        const root = rootObject
        return root ? Boolean(root.readerLoading) : false
    }
    readonly property int pageIndex: {
        const root = rootObject
        return root ? Number(root.readerPageIndex || 0) : 0
    }
    readonly property int pageCount: {
        const root = rootObject
        return root ? Number(root.readerPageCount || 0) : 0
    }
    readonly property bool fullscreenMode: {
        const root = rootObject
        return root ? Boolean(root.readerUiFullscreen) : false
    }
    readonly property string readingViewMode: {
        const root = rootObject
        return root ? String(root.readerViewMode || "one_page") : "one_page"
    }
    readonly property bool bookmarkActive: {
        const root = rootObject
        return root
            ? Boolean(root.readerBookmarkActive)
                && Number(root.readerBookmarkComicId || -1) === Number(root.readerComicId || 0)
            : false
    }
    readonly property int bookmarkPageIndex: {
        const root = rootObject
        return root
            && Number(root.readerBookmarkComicId || -1) === Number(root.readerComicId || 0)
            ? normalizedBookmarkPageIndex(root.readerBookmarkPageIndex)
            : -1
    }
    readonly property bool favoriteActive: {
        const root = rootObject
        return root ? Boolean(root.readerFavoriteActive) : false
    }
    readonly property bool canGoPreviousIssue: issueIndexInSeries > 0
    readonly property bool canGoNextIssue: issueIndexInSeries >= 0
        && issueIndexInSeries + 1 < issueCountInSeries
    readonly property bool canGoPreviousPage: {
        const hasPreviousPageInIssue = readerCoverControllerRef && typeof readerCoverControllerRef.canGoPreviousDisplayPage === "function"
            ? Boolean(readerCoverControllerRef.canGoPreviousDisplayPage())
            : false
        if (hasPreviousPageInIssue) return true
        return issueIndexInSeries > 0
    }
    readonly property bool canGoNextPage: {
        const hasNextPageInIssue = readerCoverControllerRef && typeof readerCoverControllerRef.canGoNextDisplayPage === "function"
            ? Boolean(readerCoverControllerRef.canGoNextDisplayPage())
            : false
        if (hasNextPageInIssue) return true
        return issueIndexInSeries >= 0 && issueIndexInSeries + 1 < issueCountInSeries
    }

    function openReader(comicId, title) {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.openReader === "function") {
            readerCoverControllerRef.openReader(comicId, title)
        }
        refreshIssueNavigationState()
    }

    function loadReaderPage(pageIndex) {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.loadReaderPage === "function") {
            readerCoverControllerRef.loadReaderPage(pageIndex)
        }
        refreshIssueNavigationState()
    }

    function restartFromBeginning() {
        loadReaderPage(0)
    }

    function setReaderViewMode(mode) {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.setReaderViewMode === "function") {
            readerCoverControllerRef.setReaderViewMode(mode)
        }
    }

    function refreshIssueNavigationState() {
        const root = rootObject
        if (!root || !readerCoverControllerRef) {
            issueIndexInSeries = -1
            issueCountInSeries = 0
            return
        }

        const rows = typeof readerCoverControllerRef.readerIssueRows === "function"
            ? readerCoverControllerRef.readerIssueRows()
            : []
        const comicId = Number(root.readerComicId || 0)
        let nextIndex = -1
        for (let i = 0; i < rows.length; i += 1) {
            const row = rows[i] || {}
            if (Number(row.id || 0) !== comicId) continue
            nextIndex = i
            break
        }

        issueIndexInSeries = nextIndex
        issueCountInSeries = Array.isArray(rows) ? rows.length : Number(rows.length || 0)
    }

    function persistReaderProgress(showErrorDialog) {
        return readerCoverControllerRef && typeof readerCoverControllerRef.persistReaderProgress === "function"
            ? readerCoverControllerRef.persistReaderProgress(showErrorDialog)
            : true
    }

    function finalizeReaderSession(showErrorDialog) {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.finalizeReaderSession === "function") {
            readerCoverControllerRef.finalizeReaderSession(showErrorDialog)
        }
        refreshIssueNavigationState()
    }

    function closeReader() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.closeReader === "function") {
            readerCoverControllerRef.closeReader()
        }
        refreshIssueNavigationState()
    }

    function nextReaderPage() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.nextReaderPage === "function") {
            readerCoverControllerRef.nextReaderPage()
        }
    }

    function previousReaderPage() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.previousReaderPage === "function") {
            readerCoverControllerRef.previousReaderPage()
        }
    }

    function previousReaderIssue() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.navigateReaderIssue === "function") {
            readerCoverControllerRef.navigateReaderIssue(-1)
        }
        refreshIssueNavigationState()
    }

    function nextReaderIssue() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.navigateReaderIssue === "function") {
            readerCoverControllerRef.navigateReaderIssue(1)
        }
        refreshIssueNavigationState()
    }

    function copyCurrentReaderImage() {
        return readerCoverControllerRef && typeof readerCoverControllerRef.copyCurrentReaderImageToClipboard === "function"
            ? String(readerCoverControllerRef.copyCurrentReaderImageToClipboard() || "")
            : ""
    }

    function markCurrentReaderIssueReadAndAdvance() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.markCurrentReaderIssueReadAndAdvance === "function") {
            readerCoverControllerRef.markCurrentReaderIssueReadAndAdvance()
        }
    }

    function toggleReaderBookmark() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.toggleCurrentReaderBookmark === "function") {
            readerCoverControllerRef.toggleCurrentReaderBookmark()
        }
    }

    function jumpToReaderBookmark() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.jumpToReaderBookmark === "function") {
            readerCoverControllerRef.jumpToReaderBookmark()
        }
    }

    function toggleReaderFavorite() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.toggleCurrentReaderFavorite === "function") {
            readerCoverControllerRef.toggleCurrentReaderFavorite()
        }
    }

    function toggleFullscreenMode() {
        const root = rootObject
        if (!root) return
        const nextValue = !root.readerUiFullscreen
        if (readerCoverControllerRef && typeof readerCoverControllerRef.reopenReaderPopupWithFullscreenMode === "function") {
            readerCoverControllerRef.reopenReaderPopupWithFullscreenMode(nextValue)
            return
        }
        if (typeof root.setReaderWindowFullscreen === "function") {
            root.setReaderWindowFullscreen(nextValue)
            return
        }
        root.readerUiFullscreen = nextValue
    }

    function handlePopupClosed() {
        if (readerCoverControllerRef && typeof readerCoverControllerRef.handleReaderDialogClosed === "function") {
            readerCoverControllerRef.handleReaderDialogClosed()
            return
        }
        finalizeReaderSession(true)
    }

    Connections {
        target: rootObject

        function onReaderComicIdChanged() { controller.refreshIssueNavigationState() }
        function onReaderSeriesKeyChanged() { controller.refreshIssueNavigationState() }
        function onSelectedSeriesKeyChanged() { controller.refreshIssueNavigationState() }
        function onIssuesGridDataChanged() { controller.refreshIssueNavigationState() }
    }

    Component.onCompleted: refreshIssueNavigationState()
}
