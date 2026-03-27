import QtQuick

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

    property alias importInProgress: session.importInProgress
    property alias importTotal: session.importTotal
    property alias importProcessed: session.importProcessed
    property alias importTotalBytes: session.importTotalBytes
    property alias importProcessedBytes: session.importProcessedBytes
    property alias importImportedCount: session.importImportedCount
    property alias importErrorCount: session.importErrorCount
    property alias importCancelRequested: session.importCancelRequested
    property alias importLifecycleState: session.importLifecycleState
    property alias importCurrentPath: session.importCurrentPath
    property alias importCurrentFileName: session.importCurrentFileName
    readonly property bool importCleanupActive: session.importCleanupActive
    property alias importCleanupTotalCount: session.importCleanupTotalCount
    property alias importCleanupProcessedCount: session.importCleanupProcessedCount
    property alias importCleanupCurrentFileName: session.importCleanupCurrentFileName
    property alias importPausedForConflict: session.importPausedForConflict
    property alias importConflictContext: session.importConflictContext
    property alias importConflictNextContext: session.importConflictNextContext
    property alias importConflictExistingLabel: session.importConflictExistingLabel
    property alias importConflictIncomingLabel: session.importConflictIncomingLabel
    property alias importConflictNextExistingLabel: session.importConflictNextExistingLabel
    property alias importConflictNextIncomingLabel: session.importConflictNextIncomingLabel
    property alias importConflictBatchAction: session.importConflictBatchAction
    property alias importConflictBatchDuplicateCount: session.importConflictBatchDuplicateCount
    property alias importConflictOperationActive: session.importConflictOperationActive
    property alias importConflictPendingAction: session.importConflictPendingAction
    property alias importConflictProgressCurrentFileName: session.importConflictProgressCurrentFileName
    property alias importConflictProgressProcessedCount: session.importConflictProgressProcessedCount
    property alias importConflictProgressTotalCount: session.importConflictProgressTotalCount
    readonly property real importConflictProgressFraction: session.importConflictProgressFraction
    property alias importQueue: session.importQueue
    property alias lastFailedImportPaths: session.lastFailedImportPaths
    property alias lastFailedImportErrors: session.lastFailedImportErrors
    ImportSessionController {
        id: session
        rootObject: controller.rootObject
        libraryModelRef: controller.libraryModelRef
        popupControllerRef: controller.popupControllerRef
        importConflictDialogRef: controller.importConflictDialogRef
        failedImportsDialogRef: controller.failedImportsDialogRef
        failedImportItemsModelRef: controller.failedImportItemsModelRef
    }

    function importConflictTier(context) {
        return session.importConflictTier(context)
    }

    function importConflictSupportsBatchActions(context) {
        return session.importConflictSupportsBatchActions(context)
    }

    function importConflictDialogTitle(context) {
        return session.importConflictDialogTitle(context)
    }

    function importConflictDialogMessage(context) {
        return session.importConflictDialogMessage(context)
    }

    function importConflictDialogSecondaryLabel(context) {
        return session.importConflictDialogSecondaryLabel(context)
    }

    function importConflictDialogPrimaryLabel(context) {
        return session.importConflictDialogPrimaryLabel(context)
    }

    function importConflictSecondaryAction(context) {
        return session.importConflictSecondaryAction(context)
    }

    function importConflictPrimaryAction(context) {
        return session.importConflictPrimaryAction(context)
    }

    function resolveImportConflict(choice) {
        session.resolveImportConflict(choice)
    }

    function cancelImportBatch() {
        session.cancelImportBatch()
    }

    function skipFailedImportAt(index) {
        session.skipFailedImportAt(index)
    }

    function skipAllFailedImports() {
        session.skipAllFailedImports()
    }

    function retryFailedImportAt(index) {
        session.retryFailedImportAt(index)
    }

    function importSourceEntries(paths, options) {
        return session.importSourceEntries(paths, options)
    }

    function importArchivePaths(paths, options) {
        return session.importArchivePaths(paths, options)
    }
}
