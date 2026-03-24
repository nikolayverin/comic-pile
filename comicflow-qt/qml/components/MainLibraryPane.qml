import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: libraryPane

    property var rootObject: null
    property var uiTokensRef: null
    property var heroSeriesControllerRef: null
    property var startupControllerRef: null
    property var seriesHeaderControllerRef: null
    property var deleteControllerRef: null
    property var metadataDialogRef: null

    readonly property var root: rootObject
    readonly property var uiTokens: uiTokensRef
    readonly property var heroSeriesController: heroSeriesControllerRef
    readonly property var startupController: startupControllerRef
    readonly property var seriesHeaderController: seriesHeaderControllerRef
    readonly property var deleteController: deleteControllerRef
    readonly property var metadataDialog: metadataDialogRef
    // Temporary measurement mode for preparing raster publisher logos.
    // Keep disabled for normal hero logo presentation.
    property bool publisherLogoDebugMode: false

    readonly property var activeIssuesFlick: rightPane.activeIssuesFlick
    property alias heroCollapseOffset: rightPane.heroCollapseOffset
    readonly property real currentSplitScroll: rightPane.currentSplitScroll

    Layout.fillWidth: true
    Layout.fillHeight: true
    color: root ? root.bgContent : "transparent"
    clip: true

    function setAbsoluteSplitScroll(targetValue) {
        rightPane.setAbsoluteSplitScroll(targetValue)
    }

    Item {
        id: rightPane
        anchors.fill: parent

        Item {
            id: libraryBackgroundLayer
            anchors.fill: parent
            z: -1

    Rectangle {
        anchors.fill: parent
        color: root.libraryBackgroundMode === "Solid"
            ? root.libraryBackgroundSolidColor
            : root.bgContent
    }

    Image {
        id: gridTileBackground
        anchors.fill: parent
        visible: root.libraryBackgroundMode === "Default"
            || (root.libraryBackgroundMode === "Texture"
                && root.libraryBackgroundTexturePreset === "Dots")
            || (root.libraryBackgroundMode === "Custom image"
                && root.libraryBackgroundCustomImageSource.length < 1)
        source: uiTokens.gridTile
        fillMode: Image.Tile
        smooth: false
        opacity: root.libraryBackgroundMode === "Default" ? root.gridTileOpacity : 0.86
    }

    Image {
        anchors.fill: parent
        visible: root.libraryBackgroundMode === "Texture"
            && root.libraryBackgroundTexturePreset === "Noise"
        source: root.libraryTextureSource
        fillMode: Image.Tile
        smooth: false
        opacity: 0.92
    }

    Image {
        anchors.fill: parent
        visible: root.libraryBackgroundMode === "Custom image"
            && root.libraryBackgroundCustomImageSource.length > 0
        source: root.libraryBackgroundCustomImageSource
        fillMode: root.libraryBackgroundCustomImageMode === "Fit"
            ? Image.PreserveAspectFit
            : root.libraryBackgroundCustomImageMode === "Stretch"
                ? Image.Stretch
                : root.libraryBackgroundCustomImageMode === "Tile"
                    ? Image.Tile
                    : Image.PreserveAspectCrop
        sourceSize: root.libraryBackgroundCustomImageMode === "Tile"
            ? Qt.size(root.libraryBackgroundTilePixelSize, root.libraryBackgroundTilePixelSize)
            : Qt.size(0, 0)
        smooth: root.libraryBackgroundCustomImageMode !== "Tile"
        asynchronous: true
        cache: true
    }
}

readonly property bool quickFilterMode: root.isQuickFilterModeActive()
readonly property string contentMode: quickFilterMode ? "quick_filter" : "series"
readonly property bool heroSectionVisible: !quickFilterMode && root.libraryShowHeroBlock
readonly property real activeGridTopMargin: quickFilterMode
    ? quickFilterChrome.height
    : heroLayoutHeight
readonly property int activeGridSafeTop: quickFilterMode
    ? 0
    : (heroSectionVisible ? 26 : 0)
readonly property string activeEmptyStateText: quickFilterMode
    ? root.quickFilterEmptyText(root.sidebarQuickFilterKey)
    : ""
readonly property bool activeEmptyStateVisible: quickFilterMode
    && Number(root.issuesGridData.length || 0) < 1
readonly property real heroMinHeight: 0
readonly property real heroLayoutHeight: heroSectionVisible
    ? Math.max(0, root.heroBlockHeight - heroCollapseOffset)
    : 0
readonly property real heroVisualHeight: heroSectionVisible
    ? Math.max(heroLayoutHeight, manualHeroRevealHeight)
    : 0
readonly property real heroCollapseRange: heroSectionVisible
    ? Math.max(0, root.heroBlockHeight - heroMinHeight)
    : 0
readonly property bool heroCollapsed: heroSectionVisible
    && heroCollapseOffset >= heroCollapseRange - 0.5
readonly property real heroCollapseProgress: heroCollapseRange > 0
    ? Math.max(0, Math.min(1, heroCollapseOffset / heroCollapseRange))
    : 0
readonly property real notchOpacity: (!heroSectionVisible || !hasIssueOverflow || !heroCollapsed)
    ? 1.0
    : 0.0
readonly property bool showInfoVisible: heroSectionVisible && hasIssueOverflow && heroCollapsed
readonly property var activeIssuesFlick: issuesFlick
readonly property real maxGridScrollRange: Math.max(
    0,
    Number(activeIssuesFlick ? activeIssuesFlick.contentHeight : 0)
        + Number(activeIssuesFlick ? activeIssuesFlick.topMargin : 0)
        + Number(activeIssuesFlick ? activeIssuesFlick.bottomMargin : 0)
        - Number(activeIssuesFlick ? activeIssuesFlick.height : 0)
)
readonly property bool hasIssueOverflow: maxGridScrollRange > 0.5
readonly property real totalSplitScrollRange: hasIssueOverflow ? (heroCollapseRange + maxGridScrollRange) : 0
readonly property real currentSplitScroll: heroCollapseOffset + root.normalizedGridScrollValue()
property real heroCollapseOffset: 0
property bool scrollSyncInProgress: false
property real smoothScrollValue: 0
property real smoothScrollTarget: 0
property bool smoothScrollActive: false
property bool smoothScrollApplying: false
property real manualHeroRevealHeight: 0
readonly property bool manualHeroRevealActive: manualHeroRevealHeight > 0.5

onWidthChanged: scheduleResolvedOverflowSync()
onHeightChanged: scheduleResolvedOverflowSync()
onQuickFilterModeChanged: {
    heroCollapseAnimation.stop()
    manualHeroRevealAnimation.stop()
    stopSmoothScroll()
    heroCollapseOffset = 0
    manualHeroRevealHeight = 0
}
onHeroSectionVisibleChanged: {
    heroCollapseAnimation.stop()
    manualHeroRevealAnimation.stop()
    stopSmoothScroll()
    heroCollapseOffset = 0
    manualHeroRevealHeight = 0
    scheduleResolvedOverflowSync()
}

function syncHeroWithResolvedOverflow() {
    if (!hasIssueOverflow && (heroCollapseOffset > 0 || root.normalizedGridScrollValue() > 0)) {
        const wasSync = scrollSyncInProgress
        scrollSyncInProgress = true
        heroCollapseOffset = 0
        root.setGridScrollToTop()
        scrollSyncInProgress = wasSync
        stopSmoothScroll()
    }
}

function scheduleResolvedOverflowSync() {
    resolvedOverflowSyncTimer.restart()
}

onMaxGridScrollRangeChanged: scheduleResolvedOverflowSync()

function clampSplitScroll(value) {
    return Math.max(0, Math.min(totalSplitScrollRange, Number(value || 0)))
}

function stopSmoothScroll() {
    smoothScrollAnimation.stop()
    smoothScrollTarget = currentSplitScroll
    smoothScrollActive = false
}

function animateManualHeroReveal(targetHeight) {
    const clamped = Math.max(0, Math.min(root.heroBlockHeight, Number(targetHeight || 0)))
    manualHeroRevealAnimation.stop()
    manualHeroRevealAnimation.to = clamped
    manualHeroRevealAnimation.start()
}

function animateHeroTo(targetOffset) {
    stopSmoothScroll()
    const clamped = Math.max(0, Math.min(heroCollapseRange, Number(targetOffset || 0)))
    heroCollapseAnimation.stop()
    heroCollapseAnimation.to = clamped
    heroCollapseAnimation.start()
}

function toggleHeroPanel() {
    if (manualHeroRevealActive) {
        animateManualHeroReveal(0)
        return
    }
    if (heroCollapsed) {
        animateManualHeroReveal(root.heroBlockHeight)
        return
    }
    animateHeroTo(heroCollapseRange)
}

function setAbsoluteSplitScroll(targetValue) {
    const clamped = clampSplitScroll(targetValue)
    if (Math.abs(clamped - currentSplitScroll) > 0.1) {
        root.dismissGridOverlayMenusForScroll()
    }
    heroCollapseAnimation.stop()
    const wasSync = scrollSyncInProgress
    scrollSyncInProgress = true
    if (clamped <= heroCollapseRange) {
        heroCollapseOffset = clamped
        root.setGridScrollToTop()
    } else {
        heroCollapseOffset = heroCollapseRange
        root.setNormalizedGridScrollValue(Math.min(maxGridScrollRange, clamped - heroCollapseRange))
    }
    scrollSyncInProgress = wasSync
}

function animateSplitScrollTo(targetValue) {
    const clamped = clampSplitScroll(targetValue)
    if (!hasIssueOverflow) {
        setAbsoluteSplitScroll(clamped)
        return
    }
    smoothScrollTarget = clamped
    smoothScrollAnimation.stop()
    smoothScrollApplying = true
    smoothScrollValue = currentSplitScroll
    smoothScrollApplying = false
    smoothScrollAnimation.from = smoothScrollValue
    smoothScrollAnimation.to = smoothScrollTarget
    smoothScrollActive = true
    smoothScrollAnimation.start()
}

function applySplitScroll(deltaPixels) {
    const delta = Number(deltaPixels || 0)
    if (Math.abs(delta) < 0.1) return
    root.dismissGridOverlayMenusForScroll()
    if (manualHeroRevealActive && delta < 0) {
        manualHeroRevealAnimation.stop()
        manualHeroRevealHeight = 0
    }
    const base = smoothScrollActive ? smoothScrollTarget : currentSplitScroll
    animateSplitScrollTo(base + delta)
}

NumberAnimation {
    id: heroCollapseAnimation
    target: rightPane
    property: "heroCollapseOffset"
    duration: root.motionBaseMs
    easing.type: Easing.InOutQuad
}

NumberAnimation {
    id: manualHeroRevealAnimation
    target: rightPane
    property: "manualHeroRevealHeight"
    duration: root.motionBaseMs
    easing.type: Easing.InOutQuad
}

onSmoothScrollValueChanged: {
    if (smoothScrollApplying) return
    setAbsoluteSplitScroll(smoothScrollValue)
}

NumberAnimation {
    id: smoothScrollAnimation
    target: rightPane
    property: "smoothScrollValue"
    duration: root.motionSlowMs
    easing.type: Easing.InOutCubic
    onStopped: {
        rightPane.smoothScrollActive = false
        rightPane.setAbsoluteSplitScroll(rightPane.smoothScrollTarget)
    }
}

WheelHandler {
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(wheelEvent) {
        const pxDelta = wheelEvent.pixelDelta.y !== 0
            ? -wheelEvent.pixelDelta.y
            : (-wheelEvent.angleDelta.y / 120.0) * 36.0
        rightPane.applySplitScroll(pxDelta)
        wheelEvent.accepted = true
    }
}

Timer {
    id: resolvedOverflowSyncTimer
    interval: 0
    repeat: false
    running: false
    onTriggered: rightPane.syncHeroWithResolvedOverflow()
}

Item {
    id: heroLayoutSpacer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: rightPane.heroLayoutHeight
    visible: rightPane.heroSectionVisible
}

Rectangle {
    id: heroBlock
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: rightPane.heroVisualHeight
    color: root.bgHeroBase
    clip: true
    visible: rightPane.heroSectionVisible
    z: 2
    readonly property bool editIconsVisible: heroBlockHover.hovered
    Component.onCompleted: {
        root.markStartupColdRenderOnce("hero", "height=" + String(height))
    }

    HoverHandler {
        id: heroBlockHover
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: root.selectedSeriesKey.length > 0 && heroSeriesController.currentHeroBackgroundSource().length > 0

        Image {
            id: heroBackgroundImage
            readonly property real resolvedSourceWidth: Math.max(3000, Number(sourceSize.width || 0))
            readonly property real resolvedSourceHeight: Math.max(1000, Number(sourceSize.height || 0))
            // Keep extra vertical bleed so the notch under hero can sample image pixels
            // instead of falling back to solid hero color at default window width.
            readonly property real notchBleedHeight: (root.gridNotchDepth * 2) + 2
            readonly property real fillScale: Math.max(
                parent.width / resolvedSourceWidth,
                (parent.height + notchBleedHeight) / resolvedSourceHeight
            )
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Math.ceil(resolvedSourceWidth * fillScale)
            height: Math.ceil(resolvedSourceHeight * fillScale)
            source: heroSeriesController.currentHeroBackgroundSource()
            asynchronous: true
            cache: true
            smooth: true
            opacity: 0.08
        }
    }

    BorderImage {
        anchors.fill: parent
        source: uiTokens.heroSlice
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
        border.left: 25
        border.right: 25
        border.top: 27
        border.bottom: 17
        smooth: true
    }

    Item {
        id: heroSeriesCoverLayer
        x: 25
        y: 19
        width: 172
        height: 256
        visible: root.selectedSeriesKey.length > 0

        Item {
            id: heroSeriesCoverImageShell
            x: 0
            y: 0
            width: 158
            height: 243
            clip: true

            Rectangle {
                anchors.fill: parent
                color: root.heroCoverPlaceholderColor
            }

            Image {
                anchors.fill: parent
                source: heroSeriesController.currentHeroCoverSource()
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }
        }

        Image {
            x: 0
            y: 0
            width: 172
            height: 256
            source: uiTokens.coverShading
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Item {
            x: heroSeriesCoverImageShell.x + heroSeriesCoverImageShell.width - width - 6
            y: heroSeriesCoverImageShell.y + heroSeriesCoverImageShell.height - height - 6
            width: 28
            height: 28
            visible: heroBlock.editIconsVisible
            z: 10

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: coverEditMouseArea.containsMouse
                    ? uiTokens.pencilLineWhiteIcon
                    : uiTokens.pencilLineGrayIcon
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
            }

            MouseArea {
                id: coverEditMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: startupController.launchLog("series_header_cover_icon_pressed key=" + String(root.selectedSeriesKey || ""))
                onClicked: {
                    startupController.launchLog("series_header_cover_icon_clicked key=" + String(root.selectedSeriesKey || ""))
                    seriesHeaderController.openDialog(root.selectedSeriesKey)
                }
            }
        }
    }

    Item {
        id: heroPublisherLogoArea
        width: 162
        height: 162
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 32
        z: 0
        visible: root.selectedSeriesKey.length > 0
            && String(root.heroSeriesData.logoSource || "").length > 0

        readonly property var logoLayout: PublisherCatalog.logoLayoutForLogoSource(
            String(root.heroSeriesData.logoSource || "")
        )
        readonly property string logoLayoutKind: String((logoLayout || {}).kind || "standard")
        readonly property int logoMaxWidth: Math.max(1, Number((logoLayout || {}).maxWidth || 56))
        readonly property int logoMaxHeight: Math.max(1, Number((logoLayout || {}).maxHeight || 44))

        Item {
            id: heroPublisherLogoContent
            anchors.top: parent.top
            anchors.topMargin: 0
            anchors.right: parent.right
            anchors.rightMargin: 0
            width: logoMetricsImage.status === Image.Ready && logoMetricsImage.implicitWidth > 0
                ? logoMetricsImage.implicitWidth
                : heroPublisherLogoArea.logoMaxWidth
            height: logoMetricsImage.status === Image.Ready && logoMetricsImage.implicitHeight > 0
                ? logoMetricsImage.implicitHeight
                : heroPublisherLogoArea.logoMaxHeight

            Image {
                id: logoMetricsImage
                visible: false
                source: String(root.heroSeriesData.logoSource || "")
            }

            Image {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.rightMargin: 1
                width: heroPublisherLogoContent.width
                height: heroPublisherLogoContent.height
                source: String(root.heroSeriesData.logoSource || "")
                smooth: true
                opacity: 0.35
            }

            Image {
                anchors.top: parent.top
                anchors.right: parent.right
                width: heroPublisherLogoContent.width
                height: heroPublisherLogoContent.height
                source: String(root.heroSeriesData.logoSource || "")
                smooth: true
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: libraryPane.publisherLogoDebugMode
            color: "transparent"
            border.width: 1
            border.color: "#ff6b57"
            z: 20
        }

        Rectangle {
            x: heroPublisherLogoContent.x
            y: heroPublisherLogoContent.y
            width: heroPublisherLogoContent.width
            height: heroPublisherLogoContent.height
            visible: libraryPane.publisherLogoDebugMode
            color: "transparent"
            border.width: 1
            border.color: "#4dc7ff"
            z: 21
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: heroPublisherLogoContent.height + 8
            width: debugLabelText.implicitWidth + 12
            height: debugLabelText.implicitHeight + 8
            visible: libraryPane.publisherLogoDebugMode
            radius: 4
            color: "#cc000000"
            border.width: 1
            border.color: "#80ffffff"
            z: 22

            Text {
                id: debugLabelText
                anchors.centerIn: parent
                text: heroPublisherLogoArea.logoLayoutKind
                    + " | block " + heroPublisherLogoArea.width + "x" + heroPublisherLogoArea.height
                    + " | field " + heroPublisherLogoArea.logoMaxWidth + "x" + heroPublisherLogoArea.logoMaxHeight
                color: "#ffffff"
                font.family: root.uiFontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }

    Item {
        id: heroTextLayer
        x: heroSeriesCoverLayer.x + heroSeriesCoverLayer.width + 36
        y: 24
        width: {
            const rightLimit = heroBlock.width - 138
            return Math.max(0, rightLimit - x)
        }
        height: Math.max(0, heroBlock.height - y - 16)
        z: 2
        visible: root.selectedSeriesKey.length > 0

        Text {
            id: heroSeriesLabel
            x: 0
            y: 0
            width: parent.width
            text: "Series:"
            color: root.textMuted
            font.family: root.uiFontFamily
            font.pixelSize: root.fontUiMuted
            font.weight: Font.Normal
        }

        Text {
            id: heroSeriesTitleText
            x: 0
            y: heroSeriesLabel.y + heroSeriesLabel.implicitHeight + 14
            width: parent.width
            text: String(root.heroSeriesData.seriesTitle || root.selectedSeriesTitle || "")
            color: root.textPrimary
            font.family: root.uiFontFamily
            font.pixelSize: root.fontUiHeading
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

        Text {
            id: heroSummaryLabel
            x: 0
            y: heroSeriesTitleText.y + heroSeriesTitleText.implicitHeight + 24
            width: parent.width
            text: "Summary:"
            color: root.textMuted
            font.family: root.uiFontFamily
            font.pixelSize: root.fontUiMuted
            font.weight: Font.Normal
        }

        Text {
            id: heroSummaryText
            x: 0
            y: heroSummaryLabel.y + heroSummaryLabel.implicitHeight + 14
            width: parent.width
            readonly property int reservedBodyHeight: lineHeight * maximumLineCount
            height: reservedBodyHeight
            text: String(root.heroSeriesData.summary || "-")
            color: root.textPrimary
            font.family: root.uiFontFamily
            font.pixelSize: root.fontUiPrimary
            font.weight: Font.Normal
            wrapMode: Text.WordWrap
            maximumLineCount: 7
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: 17
            visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.summary)
        }

        HeroEditIconButton {
            x: 0
            y: heroSummaryLabel.y + heroSummaryLabel.implicitHeight + 14
            visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.summary)
            onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "summary")
        }

        Item {
            id: heroMetaGrid
            x: 0
            y: heroSummaryText.y + heroSummaryText.height + 24
            width: parent.width
            height: heroMetaGrid.singleRowLayout ? 24 : 56

            property bool singleRowLayout: width >= heroMetaGrid.singleRowRequiredWidth
            property int labelWidth: 54
            property int valueWidth: 160
            property int columnGap: 6
            property int rowGap: 24
            property int col2LabelX: labelWidth + columnGap + valueWidth + columnGap
            property int col2ValueX: col2LabelX + labelWidth + columnGap
            property int pairBlockWidth: labelWidth + columnGap + valueWidth
            property int singleRowRequiredWidth: pairBlockWidth * 4 + columnGap * 3
            property int pairLabelWidth: labelWidth
            property int pairValueWidth: valueWidth
            property int pair1LabelX: 0
            property int pair1ValueX: pair1LabelX + labelWidth + columnGap
            property int pair2LabelX: col2LabelX
            property int pair2ValueX: pair2LabelX + pairLabelWidth + columnGap
            property int pair3LabelX: singleRowLayout ? (pairBlockWidth + columnGap) * 2 : 0
            property int pair3ValueX: pair3LabelX + pairLabelWidth + columnGap
            property int pair4LabelX: singleRowLayout ? (pairBlockWidth + columnGap) * 3 : col2LabelX
            property int pair4ValueX: pair4LabelX + pairLabelWidth + columnGap
            property int topRowY: 0
            property int bottomRowY: singleRowLayout ? 0 : 24

            Text {
                x: heroMetaGrid.pair1LabelX
                y: heroMetaGrid.topRowY
                width: heroMetaGrid.pairLabelWidth
                text: "Year:"
                color: root.textMuted
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiMuted
            }

            Text {
                id: heroYearValueText
                x: heroMetaGrid.pair1ValueX
                y: heroMetaGrid.topRowY
                width: heroMetaGrid.pairValueWidth
                text: String(root.heroSeriesData.year || "-")
                color: root.textPrimary
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiPrimary
                elide: Text.ElideRight
                visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.year)
            }

            HeroEditIconButton {
                x: heroMetaGrid.pair1ValueX
                y: heroMetaGrid.topRowY
                visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.year)
                onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "year")
            }

            Text {
                x: heroMetaGrid.pair2LabelX
                y: heroMetaGrid.topRowY
                width: heroMetaGrid.pairLabelWidth
                text: "Volume:"
                color: root.textMuted
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiMuted
            }

            Text {
                id: heroVolumeValueText
                x: heroMetaGrid.pair2ValueX
                y: heroMetaGrid.topRowY
                width: heroMetaGrid.pairValueWidth
                text: String(root.heroSeriesData.volume || "-")
                color: root.textPrimary
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiPrimary
                elide: Text.ElideRight
                visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.volume)
            }

            HeroEditIconButton {
                x: heroMetaGrid.pair2ValueX
                y: heroMetaGrid.topRowY
                visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.volume)
                onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "volume")
            }

            Text {
                x: heroMetaGrid.pair3LabelX
                y: heroMetaGrid.bottomRowY
                width: heroMetaGrid.pairLabelWidth
                text: "Publisher:"
                color: root.textMuted
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiMuted
            }

            Text {
                id: heroPublisherValueText
                x: heroMetaGrid.pair3ValueX
                y: heroMetaGrid.bottomRowY
                width: heroMetaGrid.pairValueWidth
                text: String(root.heroSeriesData.publisher || "-")
                color: root.textPrimary
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiPrimary
                elide: Text.ElideRight
                visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.publisher)
            }

            HeroEditIconButton {
                x: heroMetaGrid.pair3ValueX
                y: heroMetaGrid.bottomRowY
                visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.publisher)
                onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "publisher")
            }

            Text {
                x: heroMetaGrid.pair4LabelX
                y: heroMetaGrid.bottomRowY
                width: heroMetaGrid.pairLabelWidth
                text: "Genres:"
                color: root.textMuted
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiMuted
            }

            Text {
                id: heroGenresValueText
                x: heroMetaGrid.pair4ValueX
                y: heroMetaGrid.bottomRowY
                width: heroMetaGrid.pairValueWidth
                text: String(root.heroSeriesData.genres || "-")
                color: root.textPrimary
                font.family: root.uiFontFamily
                font.pixelSize: root.fontUiPrimary
                elide: Text.ElideRight
                visible: heroSeriesController.heroFieldHasValue(root.heroSeriesData.genres)
            }

            HeroEditIconButton {
                x: heroMetaGrid.pair4ValueX
                y: heroMetaGrid.bottomRowY
                visible: heroBlock.editIconsVisible && !heroSeriesController.heroFieldHasValue(root.heroSeriesData.genres)
                onClicked: root.openSeriesMetadataDialog(root.selectedSeriesKey, root.selectedSeriesTitle, "genres")
            }
        }
    }
}

Item {
    id: quickFilterChrome
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: visible ? 87 : 0
    visible: rightPane.quickFilterMode
    z: 2

    Item {
        x: 40
        y: 30
        width: Math.max(0, parent.width - 80)
        height: 27

        Image {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 27
            height: 27
            source: root.quickFilterTitleIconSource(root.sidebarQuickFilterKey)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 37
            anchors.verticalCenter: parent.verticalCenter
            text: root.quickFilterTitleText(root.sidebarQuickFilterKey)
            color: root.textPrimary
            font.family: root.uiFontFamily
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }
}

Item {
    id: quickFilterEdgeOverlay
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: gridViewport.top
    visible: rightPane.quickFilterMode && height > 0
    z: 1

    readonly property int edgeThickness: 21

    Image {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: quickFilterEdgeOverlay.edgeThickness
        source: uiTokens.gridEdgeLeft
        fillMode: Image.TileVertically
        smooth: true
    }

    Image {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: quickFilterEdgeOverlay.edgeThickness
        source: uiTokens.gridEdgeRight
        fillMode: Image.TileVertically
        smooth: true
    }
}

Item {
    id: gridViewport
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: rightPane.activeGridTopMargin
    anchors.bottom: parent.bottom
    clip: true

    GridView {
        id: issuesFlick
        anchors.fill: parent
        clip: false
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 160
        reuseItems: true
        model: root.issuesGridData
        z: 1
        leftMargin: safeZoneLeft
        rightMargin: safeZoneRight
        topMargin: safeZoneTop
        bottomMargin: safeZoneBottom
        property int spacing: 0
        property int cardHeight: root.libraryGridDensity === "Compact"
            ? 312
            : root.libraryGridDensity === "Comfortable"
                ? 344
                : 328
        property int minCardWidth: root.libraryGridDensity === "Compact"
            ? 196
            : root.libraryGridDensity === "Comfortable"
                ? 220
                : 208
        property int safeZoneLeft: 40
        property int safeZoneRight: 40
        property int safeZoneTop: rightPane.activeGridSafeTop
        property int safeZoneBottom: 18
        property int layoutWidth: Math.max(1, width - safeZoneLeft - safeZoneRight)
        property int columns: Math.max(1, Math.floor((layoutWidth + spacing) / (minCardWidth + spacing)))
        property int cardWidth: Math.max(minCardWidth, Math.floor((layoutWidth - ((columns - 1) * spacing)) / columns))

        onWidthChanged: rightPane.scheduleResolvedOverflowSync()
        onHeightChanged: rightPane.scheduleResolvedOverflowSync()
        onContentHeightChanged: {
            rightPane.scheduleResolvedOverflowSync()
            if (root.gridSplitScrollRestorePending) {
                gridSplitScrollRestoreTimer.restart()
            }
        }

        Component.onCompleted: {
            root.setGridScrollToTop()
            root.markStartupColdRenderOnce(
                "grid",
                "columns=" + String(columns)
                + " cardWidth=" + String(cardWidth)
                + " cardHeight=" + String(cardHeight)
            )
        }

        cellWidth: cardWidth + spacing
        cellHeight: cardHeight + spacing

        delegate: Item {
            readonly property var itemData: modelData || ({})

            readonly property int comicId: Number(itemData.id || 0)
            readonly property string series: String(itemData.series || "")
            readonly property string volume: String(itemData.volume || "")
            readonly property string title: String(itemData.title || "")
            readonly property string issueNumber: String(itemData.issueNumber || "")
            readonly property string publisher: String(itemData.publisher || "")
            readonly property int year: Number(itemData.year || 0)
            readonly property int month: Number(itemData.month || 0)
            readonly property string writer: String(itemData.writer || "")
            readonly property string penciller: String(itemData.penciller || "")
            readonly property string inker: String(itemData.inker || "")
            readonly property string colorist: String(itemData.colorist || "")
            readonly property string letterer: String(itemData.letterer || "")
            readonly property string coverArtist: String(itemData.coverArtist || "")
            readonly property string editor: String(itemData.editor || "")
            readonly property string storyArc: String(itemData.storyArc || "")
            readonly property string summary: String(itemData.summary || "")
            readonly property string characters: String(itemData.characters || "")
            readonly property string genres: String(itemData.genres || "")
            readonly property string ageRating: String(itemData.ageRating || "")
            readonly property string readStatus: String(itemData.readStatus || "")
            readonly property bool hasBookmark: Boolean(itemData.hasBookmark)
            readonly property int currentPage: Number(itemData.currentPage || 0)
            readonly property string filename: String(itemData.filename || "")
            readonly property string coverSource: root.coverSourceForComic(comicId)
            property bool coverRequested: false

            width: issuesFlick.cardWidth
            height: issuesFlick.cardHeight

            function requestCover() {
                if (root.restoringStartupSnapshot || root.startupHydrationInProgress) return
                if (comicId < 1 || coverRequested) return
                if (root.coverSourceForComic(comicId).length > 0) {
                    coverRequested = true
                    return
                }
                coverRequested = true
                root.requestIssueThumbnail(comicId)
            }

            onVisibleChanged: requestCover()
            onComicIdChanged: {
                coverRequested = false
                requestCover()
            }
            Component.onCompleted: requestCover()

            IssueCard {
                anchors.fill: parent
                hoverUiEnabled: !metadataDialog.visible
                actionMenuSuppressed: root.gridOverlayMenusSuppressed
                uiFontFamily: root.uiFontFamily
                uiFontPixelSize: root.fontPxUiBase
                comicId: parent.comicId
                issueNumber: parent.issueNumber
                issueTitle: parent.title
                fallbackTitle: parent.filename
                coverSource: parent.coverSource
                hasBookmark: parent.hasBookmark
                readStatus: parent.readStatus
                selected: root.isSelected(parent.comicId)
                openingInProgress: root.readerLoading && Number(root.readerComicId || 0) === Number(parent.comicId || 0)
                openingOverlayColor: root.readerLoadingChipBgColor
                cardColor: root.cardBg
                textPrimary: root.textPrimary
                textMuted: root.textMuted
                textShadowColor: root.uiTextShadow
                actionMenuBackgroundColor: root.bgApp
                actionMenuHoverColor: root.uiActionHoverBackground
                actionMenuBoundsItem: rightPane
                hoverOverlayColor: root.cardHoverOverlay
                selectedOverlayColor: root.cardSelectedOverlay
                onStartupCardCreated: {
                    root.markStartupColdRenderOnce(
                        "firstCard",
                        "comicId=" + String(parent.comicId)
                        + " issue=" + String(parent.issueNumber)
                    )
                }
                onStartupCoverReady: {
                    root.markStartupColdRenderOnce(
                        "firstCover",
                        "comicId=" + String(parent.comicId)
                        + " source=" + String(parent.coverSource)
                    )
                }

                onReadRequested: root.openReader(parent.comicId, parent.title.length > 0 ? parent.title : parent.filename)
                onSelectionToggled: function(checked) { root.setSelected(parent.comicId, checked) }
                onToggleSelectedRequested: root.setSelected(parent.comicId, !root.isSelected(parent.comicId))
                onDeleteRequested: deleteController.requestDelete(parent.comicId)
                onMarkUnreadRequested: root.markIssueUnread(parent.comicId)
                onReplaceRequested: root.replaceIssueArchive(parent.comicId)
                onEditRequested: {
                    root.openMetadataEditor({
                        id: parent.comicId,
                        series: parent.series,
                        volume: parent.volume,
                        title: parent.title,
                        issueNumber: parent.issueNumber,
                        publisher: parent.publisher,
                        year: parent.year,
                        month: parent.month,
                        writer: parent.writer,
                        penciller: parent.penciller,
                        inker: parent.inker,
                        colorist: parent.colorist,
                        letterer: parent.letterer,
                        coverArtist: parent.coverArtist,
                        editor: parent.editor,
                        storyArc: parent.storyArc,
                        summary: parent.summary,
                        characters: parent.characters,
                        genres: parent.genres,
                        ageRating: parent.ageRating,
                        readStatus: parent.readStatus,
                        currentPage: parent.currentPage
                    })
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: rightPane.activeEmptyStateText
        color: "#515151"
        font.family: root.uiFontFamily
        font.pixelSize: 20
        font.weight: Font.Bold
        visible: rightPane.activeEmptyStateVisible
        z: 3
    }

    Item {
        id: gridShadowsOverlay
        anchors.fill: parent
        visible: true
        z: 4

        readonly property int edgeThickness: 21
        readonly property int cornerWidth: 21
        readonly property int cornerHeight: 155

        Image {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: gridShadowsOverlay.cornerHeight
            width: gridShadowsOverlay.edgeThickness
            source: uiTokens.gridEdgeLeft
            fillMode: Image.TileVertically
            smooth: true
        }

        Image {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: gridShadowsOverlay.cornerHeight
            width: gridShadowsOverlay.edgeThickness
            source: uiTokens.gridEdgeRight
            fillMode: Image.TileVertically
            smooth: true
        }

        Image {
            anchors.left: parent.left
            anchors.leftMargin: gridShadowsOverlay.cornerWidth
            anchors.right: parent.right
            anchors.rightMargin: gridShadowsOverlay.cornerWidth
            anchors.bottom: parent.bottom
            height: gridShadowsOverlay.cornerHeight
            source: uiTokens.gridEdgeBottom
            fillMode: Image.TileHorizontally
            smooth: true
        }

        Image {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: gridShadowsOverlay.cornerWidth
            height: gridShadowsOverlay.cornerHeight
            source: uiTokens.gridCornerBottomLeft
            fillMode: Image.Stretch
            smooth: true
        }

        Image {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: gridShadowsOverlay.cornerWidth
            height: gridShadowsOverlay.cornerHeight
            source: uiTokens.gridCornerBottomRight
            fillMode: Image.Stretch
            smooth: true
        }
    }

    Item {
        id: gridTopEdge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.gridNotchDepth
        visible: rightPane.heroSectionVisible && !rightPane.manualHeroRevealActive
        z: 5

        Rectangle {
            anchors.left: parent.left
            anchors.right: gridNotch.left
            anchors.top: parent.top
            height: 1
            color: root.gridEdgeColor
        }

        Rectangle {
            anchors.left: gridNotch.right
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.gridEdgeColor
        }

        Rectangle {
            anchors.left: gridNotch.left
            anchors.right: gridNotch.right
            anchors.top: parent.top
            height: 1
            color: root.gridEdgeColor
            opacity: 1.0 - rightPane.notchOpacity
        }

        Connections {
            target: heroBackgroundImage

            function onXChanged() { gridNotch.requestPaint() }
            function onYChanged() { gridNotch.requestPaint() }
            function onWidthChanged() { gridNotch.requestPaint() }
            function onHeightChanged() { gridNotch.requestPaint() }
            function onStatusChanged() { gridNotch.requestPaint() }
            function onSourceChanged() { gridNotch.requestPaint() }
        }

        Canvas {
            id: gridNotch
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.gridNotchWidth
            height: root.gridNotchDepth
            antialiasing: true
            opacity: rightPane.notchOpacity
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onXChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const heroImageReady = root.selectedSeriesKey.length > 0
                    && heroSeriesController.currentHeroBackgroundSource().length > 0
                    && heroBackgroundImage.status === Image.Ready

                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width * 0.5, height)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, -1)
                ctx.lineTo(0, -1)
                ctx.closePath()

                ctx.save()
                ctx.clip()
                ctx.fillStyle = root.bgHeroBase
                ctx.fillRect(0, 0, width, height)

                if (heroImageReady) {
                    const drawX = heroBackgroundImage.x - x
                    const drawY = heroBackgroundImage.y - heroBlock.height
                    ctx.globalAlpha = Number(heroBackgroundImage.opacity || 0)
                    ctx.drawImage(
                        heroBackgroundImage,
                        drawX,
                        drawY,
                        heroBackgroundImage.width,
                        heroBackgroundImage.height
                    )
                    ctx.globalAlpha = 1.0
                }
                ctx.restore()

                ctx.strokeStyle = root.gridEdgeColor
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(0, 0.5)
                ctx.lineTo(width * 0.5, height - 0.5)
                ctx.lineTo(width, 0.5)
                ctx.stroke()
            }

            MouseArea {
                anchors.fill: parent
                enabled: rightPane.showInfoVisible
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: rightPane.toggleHeroPanel()
            }
        }

        Image {
            id: notchShadowOverlay
            anchors.fill: gridNotch
            source: uiTokens.gridNotch
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: rightPane.notchOpacity
        }

        Item {
            id: showInfoPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
            width: 76
            height: 20
            z: 7
            visible: rightPane.showInfoVisible

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: root.bgApp
            }

            Rectangle {
                width: 72
                height: 16
                anchors.centerIn: parent
                radius: 8
                color: root.uiActionHoverBackground
                visible: showInfoHoverArea.containsMouse
            }

            Text {
                anchors.centerIn: parent
                text: "Show info"
                color: root.textPrimary
                font.family: root.uiFontFamily
                font.pixelSize: root.fontPxUiBase
                font.weight: Font.Normal
            }

            MouseArea {
                id: showInfoHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rightPane.toggleHeroPanel()
            }
        }
    }
}

VerticalScrollThumb {
    id: rightScrollLayer
    x: parent.width - width - 8
    y: 0
    width: 8
    height: parent.height
    visible: rightPane.hasIssueOverflow
    z: 12
    visibleRatioOverride: {
        const range = rightPane.totalSplitScrollRange
        const ratio = range > 0 ? (rightScrollLayer.height / (rightScrollLayer.height + range)) : 1
        return Math.max(0, Math.min(1, ratio))
    }
    positionRatioOverride: {
        const range = Math.max(0, rightPane.totalSplitScrollRange)
        if (range <= 0) return 0
        return Math.max(0, Math.min(1, rightPane.currentSplitScroll / range))
    }
    thumbWidth: width
    thumbMinHeight: 36
    thumbColor: root.bgApp
    onDragStarted: rightPane.stopSmoothScroll()
    onPositionRequested: function(ratio) {
        const range = Math.max(0, rightPane.totalSplitScrollRange)
        if (range <= 0) return
        root.dismissGridOverlayMenusForScroll()
        rightPane.setAbsoluteSplitScroll(ratio * range)
    }
}

}

}
