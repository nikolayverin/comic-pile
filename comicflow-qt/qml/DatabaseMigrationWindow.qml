import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"

Window {
    id: root

    ThemeColors { id: themeColors }

    visible: false
    title: "Database Migration In Progress"
    color: themeColors.bgApp
    flags: Qt.Window | Qt.FramelessWindowHint
    property bool closeBlockedAttentionActive: false
    property color criticalAttentionColor: themeColors.dialogAttentionColor
    property string restoreWindowState: typeof databaseMigrationWindowStateToken !== "undefined"
        ? String(databaseMigrationWindowStateToken || "fullscreen")
        : "fullscreen"
    property real restoreWindowX: typeof databaseMigrationWindowX !== "undefined"
        ? Number(databaseMigrationWindowX || 0)
        : Number(Screen.virtualX || 0)
    property real restoreWindowY: typeof databaseMigrationWindowY !== "undefined"
        ? Number(databaseMigrationWindowY || 0)
        : Number(Screen.virtualY || 0)
    property int restoreWindowWidth: typeof databaseMigrationWindowWidth !== "undefined"
        ? Number(databaseMigrationWindowWidth || 0)
        : 0
    property int restoreWindowHeight: typeof databaseMigrationWindowHeight !== "undefined"
        ? Number(databaseMigrationWindowHeight || 0)
        : 0
    width: Screen.width > 0 ? Screen.width : 1280
    height: Screen.height > 0 ? Screen.height : 720
    x: Screen.virtualX
    y: Screen.virtualY

    function applyLaunchPlacement() {
        const token = String(restoreWindowState || "fullscreen")
        if (token === "fullscreen") {
            root.x = Number(Screen.virtualX || 0)
            root.y = Number(Screen.virtualY || 0)
            root.width = Screen.width > 0 ? Screen.width : 1280
            root.height = Screen.height > 0 ? Screen.height : 720
            root.showFullScreen()
            return
        }

        if (token === "maximized" || token === "display_constrained_maximized") {
            root.showMaximized()
            return
        }

        if (restoreWindowWidth > 0) {
            root.width = restoreWindowWidth
        }
        if (restoreWindowHeight > 0) {
            root.height = restoreWindowHeight
        }
        root.x = restoreWindowX
        root.y = restoreWindowY
        root.show()
    }

    Component.onCompleted: applyLaunchPlacement()

    function bringWindowToFront() {
        if (root.visibility === Window.Minimized) {
            root.showNormal()
        } else if (!root.visible) {
            root.show()
        }
        root.raise()
        root.requestActivate()
    }

    function blockCloseAttempt(closeEvent) {
        if (closeEvent) {
            closeEvent.accepted = false
        }
        bringWindowToFront()
        closeBlockedAttentionActive = true
        closeBlockedAttentionResetTimer.restart()
    }

    onClosing: function(close) {
        blockCloseAttempt(close)
    }

    PopupStyle {
        id: popupStyle
    }

    Timer {
        id: closeBlockedAttentionResetTimer
        interval: 1400
        repeat: false
        onTriggered: root.closeBlockedAttentionActive = false
    }

    Rectangle {
        anchors.fill: parent
        color: themeColors.bgApp
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: function(mouse) { mouse.accepted = true }
        onClicked: function(mouse) { mouse.accepted = true }
        onWheel: function(wheel) { wheel.accepted = true }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.blockCloseAttempt(null)
    }

    Item {
        id: dialogCard
        width: Math.max(520, popupStyle.importProgressWidth)
        height: Math.max(176, migrationBody.implicitHeight)
        anchors.centerIn: parent

        PopupSurface {
            anchors.fill: parent
            cornerRadius: popupStyle.popupRadius
            fillColor: popupStyle.popupFillColor
            edgeColor: popupStyle.edgeLineColor
            attentionPulseActive: root.closeBlockedAttentionActive
            attentionColor: root.criticalAttentionColor
        }

        PopupDialogShell {
            anchors.fill: parent
            popupStyle: popupStyle
            title: "Database Migration In Progress"
            showCloseButton: false

            PopupBodyColumn {
                id: migrationBody
                popupStyle: popupStyle
                spacing: popupStyle.dialogPlainTextSpacing

                Text {
                    Layout.fillWidth: true
                    color: popupStyle.subtleTextColor
                    font.pixelSize: popupStyle.dialogHintFontSize
                    font.family: Qt.application.font.family
                    wrapMode: Text.WordWrap
                    text: "ComicFlow is moving library data to the new location. This may take some time depending on database size."
                }

                PopupProgressBlock {
                    Layout.fillWidth: true
                    popupStyle: popupStyle
                    active: Boolean(databaseMigrationState && databaseMigrationState.active)
                    reserveSpace: true
                    currentFileName: databaseMigrationState && String(databaseMigrationState.currentFileName || "").length > 0
                        ? String(databaseMigrationState.currentFileName || "")
                        : "Preparing migration..."
                    totalCount: databaseMigrationState ? Number(databaseMigrationState.totalCount || 0) : 0
                    processedCount: databaseMigrationState ? Number(databaseMigrationState.processedCount || 0) : 0
                    progressFraction: {
                        const total = databaseMigrationState ? Number(databaseMigrationState.totalCount || 0) : 0
                        const processed = databaseMigrationState ? Number(databaseMigrationState.processedCount || 0) : 0
                        if (total < 1) return 0
                        return Math.max(0, Math.min(1, processed / total))
                    }
                }
            }
        }
    }
}
