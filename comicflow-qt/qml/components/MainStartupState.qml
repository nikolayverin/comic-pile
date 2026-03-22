import QtQml

QtObject {
    id: startupState

    property int startupLoadDelayMs: 16
    property int startupInitialReconcileSettleDelayMs: 48
    property int startupPrimaryContentRevealDelayMs: startupInitialReconcileSettleDelayMs
    property int startupInventoryCheckDelayMs: 5000
    property int startupHydrationRetryDelayMs: 100
    property int startupHydrationMaxDeferredAttempts: 20
    property bool restoringStartupSnapshot: false
    property bool startupSnapshotApplied: false
    property real startupSnapshotSeriesContentY: 0
    property real startupSnapshotIssuesContentY: 0
    property int startupSnapshotVersion: 1
    property int startupSnapshotMaxSeries: 160
    property int startupSnapshotMaxIssues: 24
    property bool startupSnapshotLiveReloadRequested: false
    property bool startupReconcileCompleted: false
    property bool startupHydrationInProgress: true
    property bool startupAwaitingFirstModelSignal: true
    property int startupHydrationAttemptCount: 0
    property bool startupDebugLogsEnabled: false
    property real startupStartedAtMs: 0
    property double launchStartedAtMs: 0
    property bool startupFirstStatusSignalReceived: false
    property bool startupResultLogged: false
    property string startupFirstFrameSource: "unknown"
    property var startupInventorySignature: ({})
    property var startupPendingInventorySignature: ({})
    property int startupInventoryCheckRequestId: 0
    property bool startupInventoryCheckInProgress: false
    property bool startupInventoryRebuildInProgress: false
    property var startupColdRenderLoggedFlags: ({
        topbar: false,
        hero: false,
        grid: false,
        firstCard: false,
        firstCover: false
    })
    property string startupPreviewPath: ""
    property string startupPreviewPrimaryPath: ""
    property string startupPreviewFallbackPath: ""
    property string startupPreviewSource: ""
    property bool startupPreviewTriedFallback: false
    property int startupPreviewMaxLongSide: 1920
    property bool startupPreviewOverlayEnabled: false
    property bool showStartupPreview: false
    property bool startupPrimaryContentReady: false
    readonly property bool startupPrimaryContentVisible: startupPrimaryContentReady
    property bool startupClosingAfterPreview: false
    property int startupCloseSeq: 0
    property real startupCloseRequestedAtMs: 0
    property bool startupDbHealthWarningVisible: false
    property string startupDbHealthWarningMessage: ""
    property string startupDbHealthWarningCode: ""
    property int startupDbHealthRequestId: 0
}
