import QtQuick
import "../components/AppText.js" as AppText

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var seriesListModelRef: null
    property var mainLibraryPaneRef: null

    property var selectedSeriesKeys: ({})
    property int seriesSelectionAnchorIndex: -1

    function activeRoot() {
        return rootObject
    }

    function traceSelection(message) {
        const root = activeRoot()
        if (!root || typeof root.runtimeDebugLog !== "function") return
        root.runtimeDebugLog("series-selection", String(message || ""))
    }

    function isSeriesSelected(seriesKey) {
        return selectedSeriesKeys[String(seriesKey || "")] === true
    }

    function selectedSeriesCount() {
        return Object.keys(selectedSeriesKeys).length
    }

    function selectedSeriesIssueCount() {
        if (!seriesListModelRef) return 0
        let total = 0
        for (let i = 0; i < seriesListModelRef.count; i += 1) {
            const item = seriesListModelRef.get(i)
            const key = String(item.seriesKey || "")
            if (selectedSeriesKeys[key] === true) {
                total += Number(item.count || 0)
            }
        }
        return total
    }

    function indexForSeriesKey(seriesKey) {
        const key = String(seriesKey || "")
        if (!seriesListModelRef || key.length < 1) return -1
        for (let i = 0; i < seriesListModelRef.count; i += 1) {
            const item = seriesListModelRef.get(i)
            if (String(item.seriesKey || "") === key) return i
        }
        return -1
    }

    function applySeriesSelectionRange(fromIndex, toIndex) {
        if (!seriesListModelRef || seriesListModelRef.count < 1) return
        const start = Math.max(0, Math.min(fromIndex, toIndex))
        const end = Math.min(seriesListModelRef.count - 1, Math.max(fromIndex, toIndex))
        const next = {}
        for (let i = start; i <= end; i += 1) {
            const item = seriesListModelRef.get(i)
            const key = String(item.seriesKey || "")
            if (key.length > 0) next[key] = true
        }
        selectedSeriesKeys = next
    }

    function firstSelectedSeriesFromModel() {
        if (!seriesListModelRef || seriesListModelRef.count < 1) {
            return { key: "", title: "", index: -1 }
        }

        for (let i = 0; i < seriesListModelRef.count; i += 1) {
            const item = seriesListModelRef.get(i)
            const key = String(item.seriesKey || "")
            if (selectedSeriesKeys[key] === true) {
                return {
                    key: key,
                    title: String(item.seriesTitle || ""),
                    index: i
                }
            }
        }

        return { key: "", title: "", index: -1 }
    }

    function applyPrimarySeriesSelection(seriesKey, seriesTitle, itemIndex, clearIssueSelection, scrollToTop) {
        const root = activeRoot()
        if (!root) return

        const key = String(seriesKey || "")
        const title = String(seriesTitle || "")
        traceSelection(
            "apply primary"
            + " seriesKey=" + key
            + " title=" + title
            + " index=" + String(itemIndex)
            + " clearIssueSelection=" + String(clearIssueSelection === true)
            + " scrollToTop=" + String(scrollToTop === true)
        )
        if (typeof root.applySelectedSeriesContext === "function") {
            root.applySelectedSeriesContext(key, title, "__all__", AppText.libraryAllVolumes)
        } else {
            root.selectedSeriesKey = key
            root.selectedSeriesTitle = title
            root.selectedVolumeKey = "__all__"
            root.selectedVolumeTitle = AppText.libraryAllVolumes
        }
        seriesSelectionAnchorIndex = Number(itemIndex) >= 0 ? Math.floor(Number(itemIndex)) : -1

        if (typeof root.refreshVolumeList === "function") {
            root.refreshVolumeList()
        }
        if (clearIssueSelection === true && typeof root.clearSelection === "function") {
            root.clearSelection()
        }
        if (scrollToTop === true && typeof root.setGridScrollToTop === "function") {
            root.setGridScrollToTop()
        }
        if (mainLibraryPaneRef) {
            mainLibraryPaneRef.heroCollapseOffset = 0
        }
    }

    function selectSeries(seriesKey, seriesTitle, indexValue) {
        const root = activeRoot()
        if (!root) return

        root.seriesMenuDismissToken += 1
        const key = String(seriesKey || "")
        const title = String(seriesTitle || "")
        const sameSeries = key.length > 0 && key === String(root.selectedSeriesKey || "")
        const hadQuickFilter = String(root.sidebarQuickFilterKey || "").trim().length > 0
        traceSelection(
            "select series"
            + " seriesKey=" + key
            + " title=" + title
            + " index=" + String(indexValue)
            + " sameSeries=" + String(sameSeries)
            + " hadQuickFilter=" + String(hadQuickFilter)
        )
        if (hadQuickFilter) {
            root.sidebarQuickFilterKey = ""
        }
        if (typeof root.applySelectedSeriesContext === "function") {
            root.applySelectedSeriesContext(key, title, "__all__", AppText.libraryAllVolumes)
        } else {
            root.selectedSeriesTitle = title
            root.selectedSeriesKey = key
            root.selectedVolumeKey = "__all__"
            root.selectedVolumeTitle = AppText.libraryAllVolumes
        }

        const next = {}
        if (key.length > 0) next[key] = true
        selectedSeriesKeys = next
        if (typeof indexValue === "number" && indexValue >= 0) {
            seriesSelectionAnchorIndex = Math.floor(indexValue)
        } else {
            seriesSelectionAnchorIndex = indexForSeriesKey(key)
        }

        if (sameSeries) {
            if (typeof root.clearSelection === "function") {
                root.clearSelection()
            }
            if (typeof root.setGridScrollToTop === "function") {
                root.setGridScrollToTop()
            }
            if (mainLibraryPaneRef) {
                mainLibraryPaneRef.heroCollapseOffset = 0
            }
            if (hadQuickFilter && typeof root.scheduleIssuesGridRefresh === "function") {
                root.scheduleIssuesGridRefresh(true)
            }
            return
        }

        if (typeof root.refreshVolumeList === "function") {
            root.refreshVolumeList()
        }
        if (typeof root.clearSelection === "function") {
            root.clearSelection()
        }
        if (typeof root.setGridScrollToTop === "function") {
            root.setGridScrollToTop()
        }
        if (mainLibraryPaneRef) {
            mainLibraryPaneRef.heroCollapseOffset = 0
        }
    }

    function selectSeriesWithModifiers(seriesKey, seriesTitle, itemIndex, modifiers) {
        const root = activeRoot()
        if (!root) return

        const key = String(seriesKey || "")
        const title = String(seriesTitle || "")
        const index = Number(itemIndex || 0)
        const shiftPressed = (Number(modifiers || 0) & Qt.ShiftModifier) !== 0
        const ctrlPressed = (Number(modifiers || 0) & Qt.ControlModifier) !== 0
        traceSelection(
            "select with modifiers"
            + " seriesKey=" + key
            + " title=" + title
            + " index=" + String(index)
            + " shift=" + String(shiftPressed)
            + " ctrl=" + String(ctrlPressed)
        )

        if (shiftPressed && selectedSeriesCount() > 0) {
            const anchor = seriesSelectionAnchorIndex >= 0
                ? seriesSelectionAnchorIndex
                : indexForSeriesKey(root.selectedSeriesKey)
            if (anchor >= 0) {
                applySeriesSelectionRange(anchor, index)
            } else {
                const next = {}
                if (key.length > 0) next[key] = true
                selectedSeriesKeys = next
            }
            if (typeof root.applySelectedSeriesContext === "function") {
                root.applySelectedSeriesContext(key, title, "__all__", AppText.libraryAllVolumes)
            } else {
                root.selectedSeriesTitle = title
                root.selectedSeriesKey = key
                root.selectedVolumeKey = "__all__"
                root.selectedVolumeTitle = AppText.libraryAllVolumes
            }
            if (String(root.sidebarQuickFilterKey || "").trim().length > 0) {
                root.sidebarQuickFilterKey = ""
            }
            if (typeof root.refreshVolumeList === "function") {
                root.refreshVolumeList()
            }
            if (typeof root.clearSelection === "function") {
                root.clearSelection()
            }
            if (typeof root.setGridScrollToTop === "function") {
                root.setGridScrollToTop()
            }
            if (mainLibraryPaneRef) {
                mainLibraryPaneRef.heroCollapseOffset = 0
            }
            return
        }

        if (ctrlPressed) {
            root.seriesMenuDismissToken += 1
            if (String(root.sidebarQuickFilterKey || "").trim().length > 0) {
                root.sidebarQuickFilterKey = ""
            }

            const next = Object.assign({}, selectedSeriesKeys || ({}))
            const currentlySelected = next[key] === true
            if (currentlySelected) {
                delete next[key]
            } else if (key.length > 0) {
                next[key] = true
            }
            selectedSeriesKeys = next

            if (!currentlySelected && key.length > 0) {
                applyPrimarySeriesSelection(key, title, index, true, true)
                return
            }

            const fallback = firstSelectedSeriesFromModel()
            applyPrimarySeriesSelection(
                fallback.key,
                fallback.title,
                fallback.index,
                true,
                true
            )
            return
        }

        selectSeries(key, title, index)
    }
}
