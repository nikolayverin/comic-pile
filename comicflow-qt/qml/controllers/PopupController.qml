import QtQuick
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
    property var aboutDialogRef: null
    property var replaceArchiveConfirmDialogRef: null
    property var seriesHeaderDialogRef: null
    property var deleteConfirmDialogRef: null
    property var deleteErrorDialogRef: null

    property var actionResultPayload: AppMessagePayload.payload({})
    property var criticalPopupAttentionTarget: null
    readonly property string actionResultMessage: String((actionResultPayload || {}).body || "")
    readonly property string actionResultTitle: String((actionResultPayload || {}).title || AppText.popupActionErrorTitle)
    readonly property string actionResultDetailsText: String((actionResultPayload || {}).details || "")
    readonly property string actionResultSecondaryText: String((actionResultPayload || {}).actionLabel || "")
    readonly property string actionResultSecondaryPath: String((actionResultPayload || {}).filePath || "")
    readonly property string actionResultSecondaryAction: String((actionResultPayload || {}).actionKey || "")
    readonly property bool actionResultSecondaryVisible: actionResultSecondaryText.length > 0

    readonly property bool anyManagedModalPopupVisible: Boolean(importConflictDialogRef && importConflictDialogRef.visible)
        || Boolean(seriesDeleteConfirmDialogRef && seriesDeleteConfirmDialogRef.visible)
        || Boolean(failedImportsDialogRef && failedImportsDialogRef.visible)
        || Boolean(metadataDialogRef && metadataDialogRef.visible)
        || Boolean(readerDialogRef && readerDialogRef.visible)
        || Boolean(actionResultDialogRef && actionResultDialogRef.visible)
        || Boolean(seriesMetaDialogRef && seriesMetaDialogRef.visible)
        || Boolean(settingsDialogRef && settingsDialogRef.visible)
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

    function visibleCriticalPopup() {
        if (importModalOverlayRef && importModalOverlayRef.visible) return importModalOverlayRef.dialogItem
        if (importConflictDialogRef && importConflictDialogRef.visible) return importConflictDialogRef
        if (seriesDeleteConfirmDialogRef && seriesDeleteConfirmDialogRef.visible) return seriesDeleteConfirmDialogRef
        if (deleteConfirmDialogRef && deleteConfirmDialogRef.visible) return deleteConfirmDialogRef
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
            aboutDialogRef,
            replaceArchiveConfirmDialogRef,
            seriesHeaderDialogRef,
            deleteConfirmDialogRef,
            deleteErrorDialogRef
        ]
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
        closeAllManagedPopups(targetPopup)
        if (!targetPopup.visible) {
            targetPopup.open()
        }
    }

    function applyActionResultPayload(payload) {
        actionResultPayload = AppMessagePayload.payload(payload || ({}))
    }

    function showMappedActionResult(payload) {
        applyActionResultPayload(payload)
        openExclusivePopup(actionResultDialogRef)
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

}
