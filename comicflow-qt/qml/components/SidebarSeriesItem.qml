import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "AppText.js" as AppText

Item {
    id: root

    Typography { id: typography }
    UiTokens { id: uiTokens }
    ThemeColors { id: themeColors }
    PopupMenuStyle { id: popupMenuStyle }

    property string seriesKey: ""
    property string seriesName: ""
    property int seriesIssueCount: 0
    property int itemIndex: -1
    property int dismissToken: 0
    property int sidebarWidth: 320
    property bool selected: false
    property bool importInProgress: false
    property bool menuDeleteOnly: false
    property bool menuBulkEditMode: false
    property bool menuMergeMode: false
    property string menuDeleteLabel: AppText.sidebarMenuDeleteFiles
    property string menuShowFolderLabel: AppText.sidebarMenuShowFolder
    readonly property string menuEditLabel: menuBulkEditMode ? AppText.sidebarMenuBulkEdit : AppText.sidebarMenuEditSeries
    property string uiFontFamily: Qt.application.font.family
    property int uiFontPixelSize: typography.uiBasePx
    property color textColor: themeColors.textPrimary
    property color hoverColor: themeColors.sidebarSeriesHoverColor
    property color menuPopupBackgroundColor: popupMenuStyle.backgroundColor
    property color menuPopupHoverColor: popupMenuStyle.hoverColor
    property color menuPopupTextColor: popupMenuStyle.textColor
    property color menuPopupDisabledTextColor: popupMenuStyle.disabledTextColor
    readonly property int utilityFadeDurationMs: 110
    readonly property var menuItems: buildMenuItems()
    readonly property bool utilityVisible: rowMouseArea.containsMouse || root.selected

    signal seriesSelectionRequested(int modifiers)
    signal addFilesRequested()
    signal addIssueRequested()
    signal editSeriesRequested()
    signal showFolderRequested()
    signal clearSelectionRequested()
    signal refreshRequested()
    signal deleteSeriesRequested()
    signal mergeSeriesRequested()
    signal dismissMenusRequested()

    width: sidebarWidth
    implicitHeight: 24

    onDismissTokenChanged: {
        if (seriesMenuPopup.visible) {
            seriesMenuPopup.close()
        }
    }

    function buildMenuItems() {
        const items = []
        if (!menuDeleteOnly) {
            items.push({
                text: AppText.sidebarMenuAddIssues,
                action: "addIssues",
                enabled: !importInProgress
            })
        }
        if (!menuDeleteOnly || menuBulkEditMode) {
            items.push({
                text: menuEditLabel,
                action: "editSeries"
            })
        }
        if (menuMergeMode) {
            items.push({
                text: AppText.sidebarMenuMergeIntoSeries,
                action: "mergeSeries"
            })
        }
        if (!menuDeleteOnly) {
            items.push({
                text: menuShowFolderLabel,
                action: "showFolder"
            })
        }
        items.push({
            text: menuDeleteLabel,
            action: "deleteSeries"
        })
        return items
    }

    Rectangle {
        id: hoverRect
        width: 268
        height: 24
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: 3
        color: (rowMouseArea.containsMouse || root.selected) ? root.hoverColor : "transparent"

        MouseArea {
            id: rowMouseArea
            anchors.fill: hoverRect
            z: 0
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                root.dismissMenusRequested()
                root.seriesSelectionRequested(mouse.modifiers)
            }
        }

        Image {
            id: seriesFolderIcon
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: hoverRect.verticalCenter
            width: 20
            height: 20
            source: root.selected
                ? uiTokens.folderOpenedIcon
                : (rowMouseArea.containsMouse
                    ? uiTokens.folderHoverIcon
                    : uiTokens.folderClosedIcon)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Label {
            id: seriesLabel
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.verticalCenter: hoverRect.verticalCenter
            text: root.seriesName.length > 0 ? root.seriesName : uiTokens.unknownSeriesLabel
            color: root.textColor
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
            elide: Text.ElideRight
            width: Math.max(10, countLabel.x - x - 8)
        }

        Label {
            id: countLabel
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: hoverRect.verticalCenter
            text: String(root.seriesIssueCount)
            color: root.textColor
            font.family: root.uiFontFamily
            font.pixelSize: root.uiFontPixelSize
            font.weight: Font.Normal
            visible: root.utilityVisible || opacity > 0
            opacity: root.utilityVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.utilityFadeDurationMs
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: dotsButton
            anchors.right: hoverRect.right
            anchors.rightMargin: -2
            anchors.verticalCenter: hoverRect.verticalCenter
            width: hoverRect.height
            height: hoverRect.height
            z: 1
            visible: root.utilityVisible || opacity > 0
            opacity: root.utilityVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.utilityFadeDurationMs
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                anchors.centerIn: parent
                source: uiTokens.verticalDotsIcon
                width: 4
                height: 14
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.utilityVisible
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    root.dismissMenusRequested()
                    if (!root.selected) {
                        root.seriesSelectionRequested(mouse.modifiers)
                    }
                    seriesMenuPopup.openForItem(dotsButton)
                }
            }
        }

        ContextMenuPopup {
            id: seriesMenuPopup
            objectName: "seriesMenuPopup"
            debugLogTarget: (typeof libraryModel !== "undefined") ? libraryModel : null
            debugName: "sidebar-series-menu"
            menuItems: root.menuItems
            uiFontFamily: root.uiFontFamily
            uiFontPixelSize: root.uiFontPixelSize
            backgroundColor: root.menuPopupBackgroundColor
            hoverColor: root.menuPopupHoverColor
            textColor: root.menuPopupTextColor
            disabledTextColor: root.menuPopupDisabledTextColor
            onItemTriggered: function(index, action) {
                if (action === "addIssues") {
                    root.addIssueRequested()
                    return
                }
                if (action === "editSeries") {
                    root.editSeriesRequested()
                    return
                }
                if (action === "mergeSeries") {
                    root.mergeSeriesRequested()
                    return
                }
                if (action === "showFolder") {
                    root.showFolderRequested()
                    return
                }
                if (action === "deleteSeries") {
                    root.deleteSeriesRequested()
                }
            }
        }
    }
}
