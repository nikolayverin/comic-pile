import QtQuick
import QtQuick.Controls

Item {
    id: dialogHost
    anchors.fill: parent

    property var rootObject: null
    property var popupStyleTokensRef: null
    property var appSettingsControllerRef: null
    property var importControllerRef: null
    property var popupControllerRef: null
    property var deleteControllerRef: null
    property var readerSessionControllerRef: null
    property var heroSeriesControllerRef: null
    property var startupControllerRef: null
    property var seriesHeaderControllerRef: null
    property var libraryModelRef: null
    property var failedImportItemsModelRef: null

    readonly property var root: rootObject
    readonly property var popupStyleTokens: popupStyleTokensRef
    readonly property var appSettingsController: appSettingsControllerRef
    readonly property var importController: importControllerRef
    readonly property var popupController: popupControllerRef
    readonly property var deleteController: deleteControllerRef
    readonly property var readerSessionController: readerSessionControllerRef
    readonly property var heroSeriesController: heroSeriesControllerRef
    readonly property var startupController: startupControllerRef
    readonly property var seriesHeaderController: seriesHeaderControllerRef
    readonly property var libraryModel: libraryModelRef
    readonly property var failedImportItemsModel: failedImportItemsModelRef

    property alias importModalOverlayRef: importModalOverlay
    property alias importConflictDialogRef: importConflictDialog
    property alias seriesDeleteConfirmDialogRef: seriesDeleteConfirmDialog
    property alias failedImportsDialogRef: failedImportsDialog
    property alias metadataDialogRef: metadataDialog
    property alias readerDialogRef: readerDialog
    property alias actionResultDialogRef: actionResultDialog
    property alias issueMetadataAutofillConfirmDialogRef: issueMetadataAutofillConfirmDialog
    property alias seriesMetadataAutofillConfirmDialogRef: seriesMetadataAutofillConfirmDialog
    property alias readerDeletePageConfirmDialogRef: readerDeletePageConfirmDialog
    property alias replaceSourceChoiceDialogRef: replaceSourceChoiceDialog
    property alias seriesMetaDialogRef: seriesMetaDialog
    property alias settingsDialogRef: settingsDialog
    property alias helpDialogRef: helpDialog
    property alias aboutDialogRef: aboutDialog
    property alias updateAvailableDialogRef: updateAvailableDialog
    property alias whatsNewDialogRef: whatsNewDialog
    property alias seriesHeaderDialogRef: seriesHeaderDialog
    property alias deleteConfirmDialogRef: deleteConfirmDialog
    property alias deleteErrorDialogRef: deleteErrorDialog
    property alias seriesMetaSeriesField: seriesMetaDialog.seriesField
    property alias seriesMetaTitleField: seriesMetaDialog.titleField
    property alias seriesMetaVolumeField: seriesMetaDialog.volumeField
    property alias seriesMetaGenresField: seriesMetaDialog.genresField
    property alias seriesMetaPublisherField: seriesMetaDialog.publisherField
    property alias seriesMetaYearField: seriesMetaDialog.yearField
    property alias seriesMetaMonthCombo: seriesMetaDialog.monthCombo
    property alias seriesMetaAgeRatingCombo: seriesMetaDialog.ageRatingCombo
    property alias seriesMetaSummaryField: seriesMetaDialog.summaryField

    PopupModalOverlay {
        anchors.fill: parent
        visible: root.anyManagedModalPopupVisible
        z: 900
        overlayColor: popupStyleTokens.overlayColor
        onOutsideClicked: popupController.handleManagedOutsideClick()
    }

    PopupModalOverlay {
        parent: Overlay.overlay
        anchors.fill: parent
        visible: popupController.secondaryLayerPopupVisible
        z: 10
        overlayColor: "transparent"
        onOutsideClicked: popupController.handleSecondaryLayerOutsideClick()
    }

    ImportProgressOverlay {
        id: importModalOverlay
        active: root.importInProgress
        blockedByModalPopup: root.anyManagedModalPopupVisible
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        currentFileName: root.importCurrentFileName
        importQueue: root.importQueue
        totalCount: root.importTotal
        processedCount: root.importProcessed
        totalBytes: root.importTotalBytes
        processedBytes: root.importProcessedBytes
        cancelPending: root.importCancelRequested
        cleanupActive: root.importCleanupActive
        cleanupTotalCount: root.importCleanupTotalCount
        cleanupProcessedCount: root.importCleanupProcessedCount
        cleanupCurrentFileName: root.importCleanupCurrentFileName
        onCancelRequested: importController.cancelImportBatch()
        onHidden: popupController.clearCriticalPopupAttention(importModalOverlay.dialogItem)
    }

    ImportConflictDialog {
        id: importConflictDialog
        hostWidth: root.width
        hostHeight: root.height
        titleText: importController.importConflictDialogTitle(root.importConflictContext)
        messageText: importController.importConflictDialogMessage(root.importConflictContext)
        secondaryActionText: importController.importConflictDialogSecondaryLabel(root.importConflictContext)
        primaryActionText: importController.importConflictDialogPrimaryLabel(root.importConflictContext)
        incomingLabel: root.importConflictIncomingLabel
        existingLabel: root.importConflictExistingLabel
        nextIncomingLabel: root.importConflictNextIncomingLabel
        nextExistingLabel: root.importConflictNextExistingLabel
        showBatchActions: importController.importConflictSupportsBatchActions(root.importConflictContext)
            && root.importConflictBatchDuplicateCount > 1
        progressActive: root.importConflictOperationActive
        progressCurrentFileName: root.importConflictProgressCurrentFileName
        progressTotalCount: root.importConflictProgressTotalCount
        progressProcessedCount: root.importConflictProgressProcessedCount
        progressFraction: root.importConflictProgressFraction
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        onClosed: popupController.handleImportConflictClosed()
        onSecondaryRequested: importController.resolveImportConflict(importController.importConflictSecondaryAction(root.importConflictContext))
        onPrimaryRequested: importController.resolveImportConflict(importController.importConflictPrimaryAction(root.importConflictContext))
        onSkipAllRequested: importController.resolveImportConflict("skip_all")
        onReplaceAllRequested: importController.resolveImportConflict("replace_all")
    }

    SeriesDeleteConfirmDialog {
        id: seriesDeleteConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        questionText: root.seriesDeleteQuestionText(popupStyleTokens.dialogBodyEmphasisFontSize)
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        onClosed: popupController.handleSeriesDeleteDialogClosed()
        onCancelConfirmed: popupController.cancelSeriesDeleteDialog()
        onDeleteRequested: deleteController.performSeriesDelete()
    }

    FailedImportsDialog {
        id: failedImportsDialog
        hostWidth: root.width
        hostHeight: root.height
        itemsModel: failedImportItemsModel
        actionsEnabled: !root.importInProgress
        onRetryRequested: importController.retryFailedImportAt(index)
        onSkipRequested: importController.skipFailedImportAt(index)
        onSkipAllRequested: importController.skipAllFailedImports()
        onPathOpenRequested: function(path) {
            if (!root.openFolderForPath(path)) return
        }
    }

    IssueMetadataDialog {
        id: metadataDialog
        hostWidth: root.width
        hostHeight: root.height
        dangerColor: root.dangerColor
        onSaveRequested: function(draft) {
            root.requestApplyIssueMetadataEdit(draft)
        }
        onResetRequested: root.resetMetadataEditor()
        onClosed: {
            if (issueMetadataAutofillConfirmDialog.visible) {
                issueMetadataAutofillConfirmDialog.close()
            }
            root.pendingIssueMetadataSuggestion = ({})
            popupController.handleIssueMetadataDialogClosed()
        }
    }

    ReaderPopup {
        id: readerDialog
        hostWidth: root.width
        hostHeight: root.height
        uiFontFamily: root.uiFontFamily
        issueTitle: readerSessionController.issueTitle
        imageSource: readerSessionController.imageSource
        displayPages: readerSessionController.displayPages
        errorText: readerSessionController.errorText
        loading: readerSessionController.loading
        pageIndex: readerSessionController.pageIndex
        pageCount: readerSessionController.pageCount
        fullscreenMode: readerSessionController.fullscreenMode
        readingViewMode: readerSessionController.readingViewMode
        mangaModeEnabled: Boolean(root.readerMangaModeEnabled)
        canGoPreviousPage: readerSessionController.canGoPreviousPage
        canGoNextPage: readerSessionController.canGoNextPage
        canGoPreviousIssue: readerSessionController.canGoPreviousIssue
        canGoNextIssue: readerSessionController.canGoNextIssue
        bookmarkActive: readerSessionController.bookmarkActive
        bookmarkPageIndex: readerSessionController.bookmarkPageIndex
        favoriteActive: readerSessionController.favoriteActive
        actionNotificationsEnabled: Boolean(appSettingsController.readerShowActionNotifications)
        inputSuspended: settingsDialog.visible
        magnifierSizePreset: appSettingsController.readerMagnifierSize
        onDismissRequested: readerSessionController.closeReader()
        onPreviousPageRequested: readerSessionController.previousReaderPage()
        onNextPageRequested: readerSessionController.nextReaderPage()
        onPreviousIssueRequested: readerSessionController.previousReaderIssue()
        onNextIssueRequested: readerSessionController.nextReaderIssue()
        onReadingViewModeChangeRequested: function(mode) {
            readerSessionController.setReaderViewMode(mode)
            if (String(mode || "") === "one_page") {
                readerDialog.showActionToast("One-page mode is enabled")
                return
            }
            if (String(mode || "") === "two_page") {
                readerDialog.showActionToast("Two-page mode is enabled")
            }
        }
        onBookmarkRequested: {
            const wasActive = Boolean(readerSessionController.bookmarkActive)
            readerSessionController.toggleReaderBookmark()
            const isActive = Boolean(readerSessionController.bookmarkActive)
            if (wasActive === isActive) return
            readerDialog.showActionToast(isActive ? "Page bookmarked" : "Bookmark removed")
        }
        onBookmarkJumpRequested: readerSessionController.jumpToReaderBookmark()
        onFavoriteRequested: {
            const wasActive = Boolean(readerSessionController.favoriteActive)
            readerSessionController.toggleReaderFavorite()
            const isActive = Boolean(readerSessionController.favoriteActive)
            if (wasActive === isActive) return
            readerDialog.showActionToast(
                isActive
                    ? "Issue added to Favorites"
                    : "Issue removed from Favorites"
            )
        }
        onDeletePageRequested: function(pageIndex) {
            root.requestDeleteReaderPageConfirmation(root.readerComicId, pageIndex)
        }
        onMangaModeToggleRequested: {
            const wasEnabled = Boolean(root.readerMangaModeEnabled)
            readerSessionController.toggleReaderMangaMode()
            const isEnabled = Boolean(root.readerMangaModeEnabled)
            if (wasEnabled === isEnabled) return
            readerDialog.showActionToast(
                isEnabled
                    ? "Manga reading mode is enabled"
                    : "Manga reading mode is disabled"
            )
        }
        onSettingsRequested: root.openSettingsDialog("reader", true)
        onCopyImageRequested: {
            const copyError = String(readerSessionController.copyCurrentReaderImage() || "").trim()
            if (copyError.length < 1) {
                readerDialog.showActionToast("Page image copied")
            }
        }
        onMarkAsReadRequested: readerSessionController.markCurrentReaderIssueReadAndAdvance()
        onReadFromStartRequested: readerSessionController.restartFromBeginning()
        onFullscreenToggleRequested: readerSessionController.toggleFullscreenMode()
        onPageSelected: function(pageIndex) { readerSessionController.loadReaderPage(pageIndex) }
        onClosed: readerSessionController.handlePopupClosed()
    }

    ActionResultDialog {
        id: actionResultDialog
        hostWidth: root.width
        hostHeight: root.height
        payload: popupController.actionResultPayload
        popupStackLayer: popupController.actionResultLayered ? 20 : 0
        onClosed: popupController.handleActionResultDialogClosed()
        onSecondaryRequested: popupController.triggerActionResultSecondary()
    }

    PopupConfirmDialog {
        id: issueMetadataAutofillConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        primaryButtonText: "Fill from library"
        secondaryButtonText: "Keep current values"
        onPrimaryRequested: root.acceptIssueMetadataSuggestion()
        onSecondaryRequested: root.skipIssueMetadataSuggestion()
    }

    PopupConfirmDialog {
        id: seriesMetadataAutofillConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        primaryButtonText: "Fill Fields"
        secondaryButtonText: "Keep Current"
        onPrimaryRequested: root.acceptSeriesMetadataSuggestion()
        onSecondaryRequested: root.skipSeriesMetadataSuggestion()
    }

    PopupConfirmDialog {
        id: readerDeletePageConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        messageText: "Вы уверены что хотите удалить эту страницу?"
        primaryButtonText: "OK"
        secondaryButtonText: "Cancel"
        onPrimaryRequested: root.confirmDeleteReaderPage()
        onSecondaryRequested: root.cancelDeleteReaderPageConfirmation()
    }

    ReplaceSourceChoiceDialog {
        id: replaceSourceChoiceDialog
        hostWidth: root.width
        hostHeight: root.height
        onArchiveRequested: root.chooseReplaceIssueArchiveSource(root.pendingReplaceArchiveComicId, "archive")
        onImageFolderRequested: root.chooseReplaceIssueArchiveSource(root.pendingReplaceArchiveComicId, "image_folder")
        onCancelRequested: root.cancelReplaceIssueArchiveConfirmation()
    }

    SeriesMetadataDialog {
        id: seriesMetaDialog
        hostWidth: root.width
        hostHeight: root.height
        dangerColor: root.dangerColor
        dialogMode: root.editingSeriesDialogMode
        previewErrorText: ""
        monthOptions: root.seriesMetaMonthOptions
        ageRatingOptions: root.seriesMetaAgeRatingOptions
        onSaveRequested: root.requestApplySeriesMetadataEdit()
        onCancelRequested: popupController.closeSeriesMetadataDialog()
        onClosed: {
            if (seriesMetadataAutofillConfirmDialog.visible) {
                seriesMetadataAutofillConfirmDialog.close()
            }
            root.pendingSeriesMetadataSuggestion = ({})
            popupController.handleSeriesMetadataDialogClosed()
        }
    }

    SettingsDialog {
        id: settingsDialog
        hostWidth: root.width
        hostHeight: root.height
        escapeShortcutEnabled: !popupController.secondaryLayerPopupVisible
        settingsController: appSettingsController
        libraryModelRef: libraryModel
        libraryBackgroundCustomImageResolvedPath: String(root.libraryBackgroundCustomImageResolvedPath || "")
        sevenZipConfiguredPath: root.sevenZipConfiguredPath
        sevenZipDisplayPath: root.sevenZipEffectivePath
        sevenZipAvailable: root.cbrBackendAvailable
        sevenZipStatusMessage: root.cbrBackendMissingMessage
        libraryDataRootPath: String(root.libraryDataRootPath || "")
        libraryDataPendingMovePath: root.pendingLibraryDataRelocationPath
        libraryFolderPath: String(root.libraryFolderPath || "")
        libraryRuntimeFolderPath: String(root.libraryRuntimeFolderPath || "")
        onChooseSevenZipRequested: root.chooseSevenZipPathFromSettings()
        onVerifySevenZipRequested: root.verifySevenZipFromSettings()
        onChangeLibraryDataLocationRequested: root.scheduleLibraryDataRelocationFromSettings()
        onChooseLibraryBackgroundImageRequested: root.chooseLibraryBackgroundImageFromSettings()
        onLibraryBackgroundImageModeRequested: root.setLibraryBackgroundImageModeFromSettings(mode)
        onOpenLibraryDataFolderRequested: root.openExactFolderPath(String(root.libraryDataRootPath || ""))
        onOpenLibraryFolderRequested: root.openExactFolderPath(String(root.libraryFolderPath || ""))
        onOpenLibraryRuntimeFolderRequested: root.openExactFolderPath(String(root.libraryRuntimeFolderPath || ""))
        onCheckStorageAccessRequested: root.checkStorageAccessFromSettings()
        onReloadLibraryRequested: root.reloadLibraryFromSettings()
        onResetSettingsRequested: root.resetSettingsToDefaults()
    }

    HelpDialog {
        id: helpDialog
        hostWidth: root.width
        hostHeight: root.height
        escapeShortcutEnabled: !popupController.secondaryLayerPopupVisible
    }

    AboutDialog {
        id: aboutDialog
        hostWidth: root.width
        hostHeight: root.height
        onUpdateDetailsRequested: root.openUpdateAvailableDialog()
    }

    UpdateAvailableDialog {
        id: updateAvailableDialog
        hostWidth: root.width
        hostHeight: root.height
    }

    WhatsNewDialog {
        id: whatsNewDialog
        hostWidth: root.width
        hostHeight: root.height
    }

    SeriesHeaderDialog {
        id: seriesHeaderDialog
        hostWidth: root.width
        hostHeight: root.height
        shuffleBackgroundEnabled: seriesHeaderController.canShuffleBackground()
        shuffleBackgroundBusy: seriesHeaderController.dialogBackgroundShuffleRequestId !== -1
        coverPreviewSource: seriesHeaderController.dialogCoverPath.length > 0
            ? seriesHeaderController.dialogCoverPath
            : heroSeriesController.automaticHeroCoverSource()
        backgroundPreviewSource: seriesHeaderController.dialogBackgroundPath.length > 0
            ? seriesHeaderController.dialogBackgroundPath
            : heroSeriesController.automaticHeroBackgroundSource()
        onUploadCoverRequested: seriesHeaderController.selectCoverImage()
        onUploadBackgroundRequested: seriesHeaderController.selectBackgroundImage()
        onShuffleBackgroundRequested: seriesHeaderController.shuffleBackground()
        onSaveRequested: seriesHeaderController.saveDialogChanges()
        onResetRequested: seriesHeaderController.resetToDefaultPending()
        onCancelRequested: seriesHeaderDialog.close()
        onOpened: startupController.launchLog("series_header_dialog_opened")
        onClosed: seriesHeaderController.resetDialogState()
    }

    DeleteConfirmDialog {
        id: deleteConfirmDialog
        hostWidth: root.width
        hostHeight: root.height
        criticalAttentionTarget: root.criticalPopupAttentionTarget
        criticalAttentionColor: root.criticalPopupAttentionColor
        onClosed: popupController.handleDeleteConfirmDialogClosed()
        onDeleteRequested: deleteController.performDelete()
    }

    DeleteErrorDialog {
        id: deleteErrorDialog
        hostWidth: root.width
        hostHeight: root.height
        payload: deleteController.deleteErrorPayload
        retryActive: root.deleteRetryInProgress
        retryStatusText: root.deleteRetryStatusText
        onClosed: popupController.handleDeleteErrorDialogClosed()
        onRetryRequested: deleteController.retryDeleteFailure()
        onOpenFolderRequested: {
            if (!root.openFolderForPath(root.deleteErrorPrimaryPath)) return
        }
    }
}
