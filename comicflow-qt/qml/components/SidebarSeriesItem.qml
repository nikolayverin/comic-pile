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
    property string seriesColorTag: ""
    property var colorTagOptions: []
    property int seriesIssueCount: 0
    property int itemIndex: -1
    property int dismissToken: 0
    property int sidebarWidth: 320
    property var debugLogTarget: null
    property bool selected: false
    property bool importInProgress: false
    property bool menuDeleteOnly: false
    property bool menuBulkEditMode: false
    property bool menuMergeMode: false
    property string menuDeleteLabel: AppText.sidebarMenuDeleteFiles
    property string menuShowFolderLabel: AppText.sidebarMenuShowFolder
    property string textLanguage: AppText.fallbackLanguageCode
    readonly property string menuEditLabel: menuBulkEditMode
        ? localizedText("sidebarMenuBulkEdit")
        : localizedText("sidebarMenuEditSeries")
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
    signal colorTagRequested(string colorTag)

    width: sidebarWidth
    implicitHeight: uiTokens.sidebarRowHeight

    onDismissTokenChanged: {
        if (seriesMenuPopup.visible) {
            seriesMenuPopup.close()
        }
    }

    function buildMenuItems() {
        const items = []
        if (!menuDeleteOnly) {
            items.push({
                text: localizedText("sidebarMenuAddIssues"),
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
                text: localizedText("sidebarMenuMergeIntoSeries"),
                action: "mergeSeries"
            })
        }
        if (!menuDeleteOnly) {
            items.push({
                text: menuShowFolderLabel,
                action: "showFolder"
            })
            items.push({
                type: "colorTags",
                action: "colorTag",
                colorTagOptions: root.colorTagOptions,
                selectedColorTag: root.seriesColorTag
            })
        }
        items.push({
            text: menuDeleteLabel,
            action: "deleteSeries"
        })
        return items
    }

    function localizedText(textKey) {
        return AppText.t(textKey, textLanguage)
    }

    function traceSeriesMenu(message) {
        const target = debugLogTarget
        if (!target || typeof target.appendStartupLog !== "function") return
        target.appendStartupLog(
            "[metadata-dialog] sidebar-item "
            + "key=" + String(root.seriesKey || "")
            + " selected=" + String(root.selected)
            + " bulk=" + String(root.menuBulkEditMode)
            + " deleteOnly=" + String(root.menuDeleteOnly)
            + " " + String(message || "")
        )
    }

    Rectangle {
        id: hoverRect
        width: uiTokens.sidebarRowWidth
        height: uiTokens.sidebarRowHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        radius: uiTokens.sidebarRowRadius
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
            anchors.leftMargin: uiTokens.sidebarRowIconLeftMargin + 17
            anchors.verticalCenter: hoverRect.verticalCenter
            width: uiTokens.sidebarSeriesIconSize
            height: uiTokens.sidebarSeriesIconSize
            source: root.selected
                ? uiTokens.folderOpenedIcon
                : (rowMouseArea.containsMouse
                    ? uiTokens.folderHoverIcon
                    : uiTokens.folderClosedIcon)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Rectangle {
            id: seriesColorTagDot
            anchors.left: parent.left
            anchors.leftMargin: uiTokens.sidebarRowIconLeftMargin
            anchors.verticalCenter: hoverRect.verticalCenter
            width: 11
            height: 11
            radius: 5.5
            visible: root.seriesColorTag.length > 0
            color: {
                for (let i = 0; i < root.colorTagOptions.length; i += 1) {
                    const item = root.colorTagOptions[i] || {}
                    if (String(item.key || "") === root.seriesColorTag) {
                        return String(item.color || "transparent")
                    }
                }
                return "transparent"
            }
            border.width: 0
        }

        Label {
            id: seriesLabel
            anchors.left: parent.left
            anchors.leftMargin: uiTokens.sidebarRowLabelLeftMargin + 17
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
                width: uiTokens.sidebarSeriesMenuDotsWidth
                height: uiTokens.sidebarSeriesMenuDotsHeight
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.utilityVisible
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    root.traceSeriesMenu(
                        "dots clicked modifiers=" + String(mouse.modifiers)
                        + " items=" + JSON.stringify(root.menuItems)
                    )
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
                root.traceSeriesMenu("menu triggered index=" + String(index) + " action=" + String(action || ""))
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
                    return
                }
                if (action.indexOf("colorTag:") === 0) {
                    root.colorTagRequested(action.slice(String("colorTag:").length))
                }
            }
        }
    }
}
