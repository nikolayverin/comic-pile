import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebarPanel

    property var rootObject: null
    property var libraryModelRef: null
    property var popupControllerRef: null
    property var deleteControllerRef: null
    property var startupControllerRef: null
    property var uiTokensRef: null
    property var seriesListModelRef: null

    property alias seriesListViewRef: seriesListView

    Layout.preferredWidth: rootObject ? rootObject.sidebarWidth : 320
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.fillHeight: true
    color: rootObject ? rootObject.bgSidebarEnd : "transparent"

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Canvas {
            id: sidebarBackgroundCanvas
            anchors.fill: parent
            contextType: "2d"

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                const gradientWidth = width * 1.8
                const gradientHeight = height * 1.8

                ctx.save()
                ctx.translate(width / 2, height / 2)
                ctx.rotate(-12 * Math.PI / 180)

                const gradient = ctx.createLinearGradient(0, -gradientHeight / 2, 0, gradientHeight / 2)
                gradient.addColorStop(0.0, rootObject.bgSidebarStart)
                gradient.addColorStop(1.0, rootObject.bgSidebarEnd)
                ctx.fillStyle = gradient
                ctx.fillRect(-gradientWidth / 2, -gradientHeight / 2, gradientWidth, gradientHeight)
                ctx.restore()

                if (sidebarNoiseTexture.status !== Image.Ready)
                    return

                ctx.save()
                ctx.globalAlpha = 0.05
                ctx.globalCompositeOperation = "qt-multiply"
                ctx.fillStyle = ctx.createPattern(sidebarNoiseTexture, "repeat")
                ctx.fillRect(0, 0, width, height)
                ctx.restore()
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Image {
            id: sidebarNoiseTexture
            source: uiTokensRef ? uiTokensRef.sidebarNoiseTexture : ""
            visible: false
            smooth: false
            onStatusChanged: {
                if (status === Image.Ready)
                    sidebarBackgroundCanvas.requestPaint()
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: rootObject ? rootObject.lineSidebarRight : "transparent"
    }

    Item {
        anchors.fill: parent

        Item {
            id: sidebarSearchShell
            x: (parent.width - width) / 2
            y: 20
            width: 268
            height: 29

            Image {
                anchors.fill: parent
                source: uiTokensRef ? uiTokensRef.searchShellFrame : ""
                fillMode: Image.Stretch
                smooth: true
            }

            Image {
                id: sidebarSearchIcon
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: uiTokensRef ? uiTokensRef.searchIcon : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: (sidebarSearchField.hovered || sidebarSearchField.activeFocus) ? 1.0 : 0.5
            }

            TextField {
                id: sidebarSearchField
                anchors.fill: parent
                leftPadding: 34
                rightPadding: 12
                topPadding: 8
                bottomPadding: 0
                hoverEnabled: true
                font.pixelSize: rootObject ? rootObject.fontPxUiBase : 14
                placeholderText: uiTokensRef ? uiTokensRef.searchPlaceholder : ""
                text: rootObject ? rootObject.sidebarSearchText : ""
                color: rootObject ? rootObject.textPrimary : "white"
                placeholderTextColor: rootObject ? rootObject.searchPlaceholder : "#808080"
                background: null
                onTextChanged: {
                    if (!rootObject) return
                    rootObject.sidebarSearchText = text
                    if (startupControllerRef && typeof startupControllerRef.requestSnapshotSave === "function") {
                        startupControllerRef.requestSnapshotSave()
                    }
                    if (rootObject.suspendSidebarSearchRefresh) return
                    rootObject.refreshSeriesList()
                }
            }
        }

        Column {
            id: sidebarQuickFiltersColumn
            x: 0
            y: 68
            width: parent.width
            spacing: 6

            SidebarQuickFilterItem {
                title: "Last import"
                issueCount: rootObject ? rootObject.sidebarQuickFilterCount("last_import") : 0
                selected: rootObject ? rootObject.sidebarQuickFilterKey === "last_import" : false
                sidebarWidth: rootObject ? rootObject.sidebarWidth : 320
                uiFontFamily: rootObject ? rootObject.uiFontFamily : ""
                uiFontPixelSize: rootObject ? rootObject.fontPxUiBase : 14
                textColor: rootObject ? rootObject.textPrimary : "white"
                hoverColor: rootObject ? rootObject.sidebarRowHoverColor : "transparent"
                idleIconSource: uiTokensRef ? uiTokensRef.sidebarLastImportIdleIcon : ""
                activeIconSource: uiTokensRef ? uiTokensRef.sidebarLastImportHoverIcon : ""
                onClicked: if (rootObject) rootObject.selectSidebarQuickFilter("last_import")
            }

            SidebarQuickFilterItem {
                title: "Favorites"
                issueCount: rootObject ? rootObject.sidebarQuickFilterCount("favorites") : 0
                selected: rootObject ? rootObject.sidebarQuickFilterKey === "favorites" : false
                sidebarWidth: rootObject ? rootObject.sidebarWidth : 320
                uiFontFamily: rootObject ? rootObject.uiFontFamily : ""
                uiFontPixelSize: rootObject ? rootObject.fontPxUiBase : 14
                textColor: rootObject ? rootObject.textPrimary : "white"
                hoverColor: rootObject ? rootObject.sidebarRowHoverColor : "transparent"
                idleIconSource: uiTokensRef ? uiTokensRef.sidebarFavoritesIdleIcon : ""
                activeIconSource: uiTokensRef ? uiTokensRef.sidebarFavoritesHoverIcon : ""
                onClicked: if (rootObject) rootObject.selectSidebarQuickFilter("favorites")
            }

            SidebarQuickFilterItem {
                title: "Bookmarks"
                issueCount: rootObject ? rootObject.sidebarQuickFilterCount("bookmarks") : 0
                selected: rootObject ? rootObject.sidebarQuickFilterKey === "bookmarks" : false
                sidebarWidth: rootObject ? rootObject.sidebarWidth : 320
                uiFontFamily: rootObject ? rootObject.uiFontFamily : ""
                uiFontPixelSize: rootObject ? rootObject.fontPxUiBase : 14
                textColor: rootObject ? rootObject.textPrimary : "white"
                hoverColor: rootObject ? rootObject.sidebarRowHoverColor : "transparent"
                idleIconSource: uiTokensRef ? uiTokensRef.sidebarBookmarksIdleIcon : ""
                activeIconSource: uiTokensRef ? uiTokensRef.sidebarBookmarksHoverIcon : ""
                onClicked: if (rootObject) rootObject.selectSidebarQuickFilter("bookmarks")
            }
        }

        Item {
            id: librarySectionLabel
            x: 22
            y: sidebarQuickFiltersColumn.y + sidebarQuickFiltersColumn.height + 19
            width: 90
            height: 14

            Text {
                x: 0
                y: 2
                text: "Library"
                color: rootObject ? rootObject.uiTextShadow : "transparent"
                font.family: rootObject ? rootObject.uiFontFamily : ""
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            Text {
                x: 0
                y: 0
                text: "Library"
                color: rootObject ? rootObject.textPrimary : "white"
                font.family: rootObject ? rootObject.uiFontFamily : ""
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        ListView {
            id: seriesListView
            x: 0
            y: librarySectionLabel.y + librarySectionLabel.height + 19
            width: parent.width
            height: Math.max(120, addFilesDropPanel.y - (rootObject ? rootObject.sidebarSeriesListBottomGap : 16) - y)
            spacing: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property real effectiveFadeHeight: Math.max(
                24,
                Math.min(rootObject ? rootObject.sidebarSeriesFadeHeight : 128, height * 0.28)
            )
            model: seriesListModelRef
            footer: Item {
                width: seriesListView.width
                height: Math.round(
                    seriesListView.effectiveFadeHeight + (rootObject ? rootObject.sidebarSeriesBottomSafeOffset : 24)
                )
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
                visible: false
                interactive: false
                width: 0
                height: 0
            }
            ScrollIndicator.vertical: ScrollIndicator {
                visible: false
                active: false
                width: 0
                height: 0
            }

            delegate: SidebarSeriesItem {
                width: rootObject ? rootObject.sidebarWidth : 320
                sidebarWidth: rootObject ? rootObject.sidebarWidth : 320
                itemIndex: index
                dismissToken: rootObject ? rootObject.seriesMenuDismissToken : 0
                seriesKey: String(model.seriesKey || "")
                seriesName: String(model.seriesTitle || "")
                seriesIssueCount: Number(model.count || 0)
                selected: rootObject
                    ? String(rootObject.sidebarQuickFilterKey || "").trim().length < 1
                        && rootObject.isSeriesSelected(seriesKey)
                    : false
                importInProgress: rootObject ? rootObject.importInProgress : false
                menuDeleteOnly: rootObject
                    ? rootObject.selectedSeriesCount() > 1 && rootObject.isSeriesSelected(seriesKey)
                    : false
                menuBulkEditMode: rootObject
                    ? rootObject.selectedSeriesCount() > 1 && rootObject.isSeriesSelected(seriesKey)
                    : false
                menuMergeMode: rootObject
                    ? rootObject.selectedSeriesCount() > 1 && rootObject.isSeriesSelected(seriesKey)
                    : false
                menuDeleteLabel: (rootObject
                    && rootObject.selectedSeriesCount() > 1
                    && rootObject.isSeriesSelected(seriesKey))
                    ? "Delete selected"
                    : "Delete files"
                uiFontFamily: rootObject ? rootObject.uiFontFamily : ""
                uiFontPixelSize: rootObject ? rootObject.fontPxUiBase : 14
                textColor: rootObject ? rootObject.textPrimary : "white"
                hoverColor: rootObject ? rootObject.sidebarRowHoverColor : "transparent"
                menuPopupBackgroundColor: rootObject ? rootObject.uiMenuBackground : "transparent"
                menuPopupHoverColor: rootObject ? rootObject.uiMenuHoverBackground : "transparent"
                menuPopupTextColor: rootObject ? rootObject.uiMenuText : "white"
                menuPopupDisabledTextColor: rootObject ? rootObject.uiMenuTextDisabled : "#808080"
                opacity: {
                    const fadeHeight = Math.max(1, seriesListView.effectiveFadeHeight)
                    const fadeStart = seriesListView.height - fadeHeight
                    const topInViewport = y - seriesListView.contentY
                    const centerInViewport = topInViewport + (height / 2)
                    if (centerInViewport <= fadeStart) return 1.0
                    if (centerInViewport >= seriesListView.height) return 0.0
                    const ratio = (centerInViewport - fadeStart) / fadeHeight
                    return Math.max(0.0, 1.0 - ratio)
                }

                onSeriesSelectionRequested: function(modifiers) {
                    if (rootObject) rootObject.selectSeriesWithModifiers(seriesKey, seriesName, itemIndex, modifiers)
                }
                onDismissMenusRequested: if (rootObject) rootObject.seriesMenuDismissToken += 1
                onAddFilesRequested: if (rootObject) rootObject.quickAddFilesFromDialog()
                onAddIssueRequested: if (rootObject) rootObject.quickAddFilesForSeries(seriesName)
                onEditSeriesRequested: if (rootObject) rootObject.openSeriesMetadataDialog(
                    seriesKey,
                    seriesName,
                    "",
                    rootObject.selectedSeriesCount() > 1 && rootObject.isSeriesSelected(seriesKey)
                        ? "bulk"
                        : "single"
                )
                onMergeSeriesRequested: if (rootObject) rootObject.openSeriesMergeDialog(seriesKey, seriesName)
                onShowFolderRequested: if (rootObject) rootObject.openSeriesFolder(seriesKey, seriesName)
                onClearSelectionRequested: if (rootObject) rootObject.clearSelection()
                onRefreshRequested: if (libraryModelRef) libraryModelRef.reload()
                onDeleteSeriesRequested: if (deleteControllerRef) deleteControllerRef.requestSeriesDelete(seriesKey, seriesName)
            }
        }

        VerticalScrollThumb {
            id: seriesScrollLayer
            x: parent.width - width - 8
            y: seriesListView.y
            width: 8
            height: seriesListView.height
            visible: seriesListView.contentHeight > seriesListView.height
            z: 2
            flickable: seriesListView
            thumbWidth: width
            thumbMinHeight: 36
            thumbColor: rootObject ? rootObject.bgSidebarEnd : "transparent"
        }

        Item {
            id: addFilesDropPanel
            width: 274
            height: 173
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 19

            Item {
                id: addFilesDropHighlight
                anchors.fill: parent
                opacity: (dropZoneMouseArea.containsMouse || (rootObject ? rootObject.addFilesDropActive : false)) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: rootObject ? rootObject.motionBaseMs : 180
                        easing.type: Easing.InOutQuad
                    }
                }

                Canvas {
                    id: dropHighlightCanvas
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cx = width / 2
                        const cy = height / 2
                        const radius = Math.max(width, height) * 0.62
                        const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius)
                        g.addColorStop(0.0, "rgba(58,62,68,0.36)")
                        g.addColorStop(0.68, "rgba(58,62,68,0.16)")
                        g.addColorStop(1.0, "rgba(58,62,68,0.00)")
                        ctx.fillStyle = g
                        ctx.fillRect(0, 0, width, height)
                    }
                }
            }

            Image {
                anchors.fill: parent
                source: uiTokensRef ? uiTokensRef.dropZoneBorder : ""
                fillMode: Image.Stretch
                smooth: true
            }

            Image {
                id: addFilesDropIcon
                width: 52
                height: 55
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                source: uiTokensRef ? uiTokensRef.dropZoneIcon : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                id: dropZoneTitle
                anchors.top: addFilesDropIcon.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: rootObject ? rootObject.uiFontFamily : ""
                font.pixelSize: rootObject ? rootObject.fontPxDropTitle : 16
                font.bold: true
                color: rootObject ? rootObject.dropZoneTextColor : "white"
                z: 1
                text: "Drop archives here to add\nissues to library"
            }

            Text {
                id: dropZoneTitleShadow
                anchors.top: dropZoneTitle.top
                anchors.topMargin: 1
                anchors.horizontalCenter: dropZoneTitle.horizontalCenter
                width: dropZoneTitle.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: rootObject ? rootObject.uiFontFamily : ""
                font.pixelSize: rootObject ? rootObject.fontPxDropTitle : 16
                font.bold: true
                color: rootObject ? rootObject.uiTextShadow : "transparent"
                text: dropZoneTitle.text
                z: 0
            }

            Text {
                id: dropZoneSubtitle
                anchors.top: dropZoneTitle.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: rootObject ? rootObject.uiFontFamily : ""
                font.pixelSize: rootObject ? rootObject.fontPxDropSubtitle : 14
                color: rootObject ? rootObject.dropZoneTextColor : "white"
                z: 1
                text: "Supports any archive files"
            }

            Text {
                anchors.top: dropZoneSubtitle.top
                anchors.topMargin: 1
                anchors.horizontalCenter: dropZoneSubtitle.horizontalCenter
                width: dropZoneSubtitle.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: rootObject ? rootObject.uiFontFamily : ""
                font.pixelSize: rootObject ? rootObject.fontPxDropSubtitle : 14
                color: rootObject ? rootObject.uiTextShadow : "transparent"
                text: dropZoneSubtitle.text
                z: 0
            }

            MouseArea {
                id: dropZoneMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: rootObject ? !rootObject.importInProgress : true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (rootObject) rootObject.quickAddFilesFromDialog()
            }

            DropArea {
                anchors.fill: parent
                enabled: rootObject ? !rootObject.importInProgress : true

                onEntered: if (rootObject) rootObject.addFilesDropActive = true
                onExited: if (rootObject) rootObject.addFilesDropActive = false
                onDropped: function(drop) {
                    if (rootObject) rootObject.addFilesDropActive = false
                    const urls = drop.urls || []
                    const paths = []
                    for (let i = 0; i < urls.length; i += 1) {
                        const rawPath = String(urls[i] || "").trim()
                        if (rawPath.length > 0) {
                            paths.push(rawPath)
                        }
                    }
                    if (paths.length < 1) {
                        if (popupControllerRef) {
                            popupControllerRef.showActionResult("Drop Contains No Local Files.", true)
                        }
                        return
                    }
                    if (rootObject && rootObject.startImportFromSourcePaths(
                                paths,
                                { importIntent: "global_add" },
                                "Drop Contains No Supported Comic Sources."
                            )) {
                        drop.acceptProposedAction()
                    }
                }
            }
        }
    }
}
