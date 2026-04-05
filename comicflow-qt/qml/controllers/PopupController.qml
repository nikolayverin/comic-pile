import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../components/AppText.js" as AppText
import "../components/AppErrorMapper.js" as AppErrorMapper
import "../components/AppMessagePayload.js" as AppMessagePayload

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var rootObject: null
    property var importControllerRef: null
    property var deleteControllerRef: null
    property var importModalOverlayRef: null
    property var importConflictDialogRef: null
    property var seriesDeleteConfirmDialogRef: null
    property var failedImportsDialogRef: null
    property var metadataDialogRef: null
    property var readerDialogRef: null
    property var actionResultDialogRef: null
    property var seriesMetaDialogRef: null
    property var settingsDialogRef: null
    property var helpDialogRef: null
    property var aboutDialogRef: null
    property var replaceArchiveConfirmDialogRef: null
    property var seriesHeaderDialogRef: null
    property var deleteConfirmDialogRef: null
    property var deleteErrorDialogRef: null
    property var secondaryLayerHostPopup: null

    property var actionResultPayload: AppMessagePayload.payload({})
    property var criticalPopupAttentionTarget: null
    readonly property string actionResultMessage: String((actionResultPayload || {}).body || "")
    readonly property string actionResultTitle: String((actionResultPayload || {}).title || AppText.popupActionErrorTitle)
    readonly property string actionResultDetailsText: String((actionResultPayload || {}).details || "")
    readonly property string actionResultSecondaryText: String((actionResultPayload || {}).actionLabel || "")
    readonly property string actionResultSecondaryPath: String((actionResultPayload || {}).filePath || "")
    readonly property string actionResultSecondaryAction: String((actionResultPayload || {}).actionKey || "")
    readonly property bool actionResultSecondaryVisible: actionResultSecondaryText.length > 0
    readonly property bool actionResultLayered: Boolean(
        actionResultDialogRef
        && actionResultDialogRef.visible
        && secondaryLayerHostPopup
        && secondaryLayerHostPopup.visible
    )
    readonly property bool secondaryLayerPopupVisible: Boolean(visibleSecondaryLayerPopup())

    readonly property bool anyManagedModalPopupVisible: Boolean(importConflictDialogRef && importConflictDialogRef.visible)
        || Boolean(seriesDeleteConfirmDialogRef && seriesDeleteConfirmDialogRef.visible)
        || Boolean(failedImportsDialogRef && failedImportsDialogRef.visible)
        || Boolean(metadataDialogRef && metadataDialogRef.visible)
        || Boolean(readerDialogRef && readerDialogRef.visible)
        || Boolean(actionResultDialogRef && actionResultDialogRef.visible)
        || Boolean(seriesMetaDialogRef && seriesMetaDialogRef.visible)
        || Boolean(settingsDialogRef && settingsDialogRef.visible)
        || Boolean(helpDialogRef && helpDialogRef.visible)
        || Boolean(aboutDialogRef && aboutDialogRef.visible)
        || Boolean(replaceArchiveConfirmDialogRef && replaceArchiveConfirmDialogRef.visible)
        || Boolean(seriesHeaderDialogRef && seriesHeaderDialogRef.visible)
        || Boolean(deleteConfirmDialogRef && deleteConfirmDialogRef.visible)
        || Boolean(deleteErrorDialogRef && deleteErrorDialogRef.visible)

    readonly property bool anyCriticalPopupVisible: Boolean(importModalOverlayRef && importModalOverlayRef.visible)
        || Boolean(importConflictDialogRef && importConflictDialogRef.visible)
        || Boolean(seriesDeleteConfirmDialogRef && seriesDeleteConfirmDialogRef.visible)
        || Boolean(deleteConfirmDialogRef && deleteConfirmDialogRef.visible)

    function root() {
        return rootObject
    }

    function tracePopupLayer(message) {
        const rootRef = root()
        if (!rootRef || typeof rootRef.runtimeDebugLog !== "function") return
        rootRef.runtimeDebugLog("popup-layer", String(message || ""))
    }

    function popupDebugLabel(popup) {
        if (!popup) return "unknown-popup"
        const explicitName = String(popup.debugName || "").trim()
        if (explicitName.length > 0) return explicitName
        const titleText = String(popup.title || "").trim()
        if (titleText.length > 0) return titleText
        const objectLabel = String(popup.objectName || "").trim()
        if (objectLabel.length > 0) return objectLabel
        return "unnamed-popup"
    }

    function visibleCriticalPopup() {
        if (importModalOverlayRef && importModalOverlayRef.visible) return importModalOverlayRef.dialogItem
        if (importConflictDialogRef && importConflictDialogRef.visible) return importConflictDialogRef
        if (seriesDeleteConfirmDialogRef && seriesDeleteConfirmDialogRef.visible) return seriesDeleteConfirmDialogRef
        if (deleteConfirmDialogRef && deleteConfirmDialogRef.visible) return deleteConfirmDialogRef
        return null
    }

    function visibleSecondaryLayerPopup() {
        if (actionResultLayered) {
            return actionResultDialogRef
        }
        return null
    }

    function bringWindowToFrontForCriticalPopup() {
        const rootRef = root()
        if (!rootRef) return
        if (rootRef.visibility === Window.Minimized) {
            rootRef.showNormal()
        }
        if (!rootRef.visible) {
            rootRef.show()
        }
        rootRef.raise()
        rootRef.requestActivate()
    }

    function blockCloseAndHighlightCriticalPopup(closeEvent) {
        const targetPopup = visibleCriticalPopup()
        if (!targetPopup) return false
        if (closeEvent) {
            closeEvent.accepted = false
        }
        bringWindowToFrontForCriticalPopup()
        criticalPopupAttentionTarget = targetPopup
        return true
    }

    function clearCriticalPopupAttention(popupObject) {
        if (criticalPopupAttentionTarget === popupObject) {
            criticalPopupAttentionTarget = null
        }
    }

    function managedModalPopups() {
        return [
            importConflictDialogRef,
            seriesDeleteConfirmDialogRef,
            failedImportsDialogRef,
            metadataDialogRef,
            readerDialogRef,
            actionResultDialogRef,
            seriesMetaDialogRef,
            settingsDialogRef,
            helpDialogRef,
            aboutDialogRef,
            replaceArchiveConfirmDialogRef,
            seriesHeaderDialogRef,
            deleteConfirmDialogRef,
            deleteErrorDialogRef
        ]
    }

    function activeManagedPopup() {
        const layeredPopup = visibleSecondaryLayerPopup()
        if (layeredPopup) {
            return layeredPopup
        }
        const list = managedModalPopups()
        for (let i = 0; i < list.length; i += 1) {
            const popup = list[i]
            if (popup && popup.visible) {
                return popup
            }
        }
        return null
    }

    function popupAllowsOutsideDismiss(popup) {
        if (!popup) return false
        const closePolicy = Number(popup.closePolicy || 0)
        return Boolean(closePolicy & Popup.CloseOnPressOutside)
            || Boolean(closePolicy & Popup.CloseOnPressOutsideParent)
    }

    function requestPopupDismiss(popup) {
        if (!popup) return
        tracePopupLayer("dismiss request popup=" + popupDebugLabel(popup))
        if (typeof popup.closeRequested === "function") {
            popup.closeRequested()
            return
        }
        if (typeof popup.cancelRequested === "function") {
            popup.cancelRequested()
            return
        }
        if (typeof popup.close === "function") {
            popup.close()
        }
    }

    function handleManagedOutsideClick() {
        const popup = activeManagedPopup()
        if (!popup) {
            tracePopupLayer("outside click ignored activePopup=none")
            return
        }
        const popupLabel = popupDebugLabel(popup)
        const allowsDismiss = popupAllowsOutsideDismiss(popup)
        tracePopupLayer(
            "outside click activePopup=" + popupLabel
            + " allowDismiss=" + String(allowsDismiss)
        )
        if (allowsDismiss) {
            tracePopupLayer("outside click -> dismiss popup=" + popupLabel)
            requestPopupDismiss(popup)
            return
        }
        tracePopupLayer("outside click -> restore focus popup=" + popupLabel)
        if (typeof popup.forceActiveFocus === "function") {
            popup.forceActiveFocus()
        }
    }

    function closeAllManagedPopups(exceptPopup) {
        const list = managedModalPopups()
        for (let i = 0; i < list.length; i += 1) {
            const popup = list[i]
            if (!popup || popup === exceptPopup) continue
            if (popup.visible && typeof popup.close === "function") {
                popup.close()
            }
        }
    }

    function openExclusivePopup(targetPopup) {
        if (!targetPopup || typeof targetPopup.open !== "function") return
        tracePopupLayer("open exclusive popup=" + popupDebugLabel(targetPopup))
        secondaryLayerHostPopup = null
        closeAllManagedPopups(targetPopup)
        if (!targetPopup.visible) {
            targetPopup.open()
        }
    }

    function canOpenSecondaryPopupOver(hostPopup, targetPopup) {
        return Boolean(
            hostPopup
            && hostPopup.visible
            && hostPopup === settingsDialogRef
            && targetPopup
            && targetPopup === actionResultDialogRef
        )
    }

    function openPopupAbove(targetPopup, hostPopup) {
        if (!targetPopup || typeof targetPopup.open !== "function") return
        if (!canOpenSecondaryPopupOver(hostPopup, targetPopup)) {
            tracePopupLayer(
                "open second-layer fallback popup=" + popupDebugLabel(targetPopup)
                + " host=" + popupDebugLabel(hostPopup)
            )
            openExclusivePopup(targetPopup)
            return
        }

        tracePopupLayer(
            "open second-layer popup=" + popupDebugLabel(targetPopup)
            + " host=" + popupDebugLabel(hostPopup)
        )
        secondaryLayerHostPopup = hostPopup
        if (!targetPopup.visible) {
            targetPopup.open()
            return
        }
        if (typeof targetPopup.forceActiveFocus === "function") {
            targetPopup.forceActiveFocus()
        }
    }

    function applyActionResultPayload(payload) {
        actionResultPayload = AppMessagePayload.payload(payload || ({}))
    }

    function showMappedActionResult(payload) {
        applyActionResultPayload(payload)
        openExclusivePopup(actionResultDialogRef)
    }

    function showMappedActionResultAbovePopup(payload, hostPopup) {
        applyActionResultPayload(payload)
        openPopupAbove(actionResultDialogRef, hostPopup)
    }

    function showActionResult(message, isError) {
        if (!Boolean(isError)) return
        showMappedActionResult(AppErrorMapper.defaultActionResultPayload(
            message,
            AppText.popupActionErrorTitle,
            "",
            "",
            "",
            ""
        ))
    }

    function showActionResultWithDetails(message, detailsText) {
        showMappedActionResult(AppErrorMapper.defaultActionResultPayload(
            message,
            AppText.popupActionErrorTitle,
            detailsText,
            "",
            "",
            ""
        ))
    }

    function showActionResultWithFolder(message, detailsText, filePath, buttonText) {
        showMappedActionResult(AppErrorMapper.defaultActionResultPayload(
            message,
            AppText.popupActionErrorTitle,
            detailsText,
            filePath ? String(buttonText || AppText.popupOpenFolder) : "",
            "",
            filePath
        ))
    }

    function showActionResultWithAction(message, detailsText, buttonText, actionKey) {
        const explicitTitle = String((actionResultPayload || {}).title || "").trim()
        showMappedActionResult(AppErrorMapper.defaultActionResultPayload(
            message,
            explicitTitle.length > 0 ? explicitTitle : AppText.popupActionErrorTitle,
            detailsText,
            buttonText,
            actionKey,
            ""
        ))
    }

    function triggerActionResultSecondary() {
        const rootRef = root()
        const actionKey = String(actionResultSecondaryAction || "").trim()
        if (rootRef && actionKey === "open_library_data_settings") {
            if (typeof rootRef.openSettingsDialog === "function") {
                rootRef.openSettingsDialog("library_data")
            }
            if (actionResultDialogRef) {
                actionResultDialogRef.close()
            }
            return
        }
        const targetPath = String(actionResultSecondaryPath || "").trim()
        if (!rootRef || targetPath.length < 1) return
        if (typeof rootRef.openFolderForPath === "function" && rootRef.openFolderForPath(targetPath)) {
            if (actionResultDialogRef) {
                actionResultDialogRef.close()
            }
        }
    }

    function clearSeriesDeleteContext() {
        if (!deleteControllerRef) return
        deleteControllerRef.pendingSeriesKeys = []
        deleteControllerRef.pendingSeriesKey = ""
        deleteControllerRef.pendingSeriesTitle = ""
        deleteControllerRef.pendingSeriesIssueCount = 0
    }

    function clearSeriesMetadataContext() {
        const rootRef = root()
        if (seriesMetaDialogRef) {
            seriesMetaDialogRef.errorText = ""
        }
        if (!rootRef) return
        rootRef.editingSeriesKey = ""
        rootRef.editingSeriesKeys = []
        rootRef.editingSeriesTitle = ""
        rootRef.editingSeriesDialogMode = "single"
    }

    function closeSeriesMetadataDialog() {
        if (seriesMetaDialogRef) {
            seriesMetaDialogRef.close()
        }
        clearSeriesMetadataContext()
    }

    function handleImportConflictClosed() {
        clearCriticalPopupAttention(importConflictDialogRef)
    }

    function handleSeriesDeleteDialogClosed() {
        clearCriticalPopupAttention(seriesDeleteConfirmDialogRef)
    }

    function cancelSeriesDeleteDialog() {
        clearSeriesDeleteContext()
        if (seriesDeleteConfirmDialogRef) {
            seriesDeleteConfirmDialogRef.close()
        }
    }

    function handleIssueMetadataDialogClosed() {
        const rootRef = root()
        if (metadataDialogRef) {
            metadataDialogRef.errorText = ""
        }
        if (rootRef) {
            rootRef.editingComic = null
        }
    }

    function handleActionResultDialogClosed() {
        secondaryLayerHostPopup = null
        actionResultPayload = AppMessagePayload.payload({
            title: AppText.popupActionErrorTitle,
            body: "",
            details: "",
            actionLabel: "",
            actionKey: "",
            filePath: ""
        })
    }

    function handleSeriesMetadataDialogClosed() {
        clearSeriesMetadataContext()
    }

    function handleDeleteConfirmDialogClosed() {
        clearCriticalPopupAttention(deleteConfirmDialogRef)
    }

    function handleDeleteErrorDialogClosed() {
        if (deleteControllerRef) {
            deleteControllerRef.clearDeleteFailureContext()
        }
    }

    function handleSecondaryLayerOutsideClick() {
        const popup = visibleSecondaryLayerPopup()
        if (!popup) {
            tracePopupLayer("second-layer outside click ignored activePopup=none")
            return
        }
        const popupLabel = popupDebugLabel(popup)
        const allowsDismiss = popupAllowsOutsideDismiss(popup)
        tracePopupLayer(
            "second-layer outside click activePopup=" + popupLabel
            + " allowDismiss=" + String(allowsDismiss)
        )
        if (allowsDismiss) {
            tracePopupLayer("second-layer outside click -> dismiss popup=" + popupLabel)
            requestPopupDismiss(popup)
            return
        }
        tracePopupLayer("second-layer outside click -> restore focus popup=" + popupLabel)
        if (typeof popup.forceActiveFocus === "function") {
            popup.forceActiveFocus()
        }
    }

}
