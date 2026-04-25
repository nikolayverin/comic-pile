import QtQuick
import QtQuick.Controls
import "HelpContent.js" as HelpContent

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }
    PopupStyle { id: styleTokens }

    property string expandedSectionKey: "getting_started"
    property string contentSectionKey: "getting_started"
    property string selectedSubsectionKey: ""
    property string requestedSection: ""
    property string pendingScrollSubsectionKey: ""
    property bool hasSessionState: false
    property string sessionSectionKey: "getting_started"
    property string sessionExpandedSectionKey: "getting_started"
    property string sessionSubsectionKey: ""
    property real sessionContentY: 0
    property real pendingRestoreContentY: -1
    property bool contentThumbDragActive: false
    property var subsectionTargets: ({})
    readonly property var helpSections: HelpContent.helpSections()
    readonly property int sidebarWidth: 252
    readonly property int menuTop: 52
    readonly property int menuLeft: 12
    readonly property int menuAreaWidth: sidebarWidth - menuLeft - 16
    readonly property int menuItemHeight: 34
    readonly property int menuItemRadius: 8
    readonly property int menuItemSpacing: 8
    readonly property int menuTextSize: 13
    readonly property int menuIconSize: 14
    readonly property int menuIconLeftInset: 10
    readonly property int menuTextGlobalX: 40
    readonly property int titleToMenuGap: 25
    readonly property int contentInsetFromSidebar: 30
    readonly property int sectionTitleTop: 20
    readonly property int contentTopSafeArea: styleTokens.closeTopMargin
        + styleTokens.closeButtonSize
        + 12
    readonly property int sectionTitleSize: 28
    readonly property int sectionLeadSize: 14
    readonly property int subsectionTitleSize: 17
    readonly property int bodyTextSize: 13
    readonly property int screenshotCardPadding: 24
    readonly property int sectionGap: 30
    readonly property int subsectionGap: 28
    readonly property int subsectionBodyTopGap: 18
    readonly property int subsectionIndent: 18
    readonly property int subsectionItemHeight: 42
    readonly property int subsectionRadius: 6
    readonly property int subsectionSpacing: 6
    readonly property int bodyParagraphSpacing: 18
    readonly property int bodyListLeadGap: 10
    readonly property int bodyListIndent: 22
    readonly property real bodyLineHeight: 1.28
    readonly property int baseHostWidth: 1440
    readonly property int baseHostHeight: 980
    readonly property int baseDialogWidth: 1024
    readonly property int baseDialogHeight: 820
    readonly property int minimumDialogWidth: 620
    readonly property int minimumDialogHeight: 520
    readonly property int horizontalMargin: hostWidth >= 1800 ? 60 : 36
    readonly property int verticalMargin: hostHeight >= 1100 ? 56 : 36

    popupStyle: styleTokens
    debugName: "help-dialog"
    title: ""
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnPressOutsideParent
    width: {
        if (hostWidth <= 0) return baseDialogWidth
        const availableWidth = Math.max(420, Math.floor(hostWidth - horizontalMargin * 2))
        return Math.min(baseDialogWidth, availableWidth)
    }
    height: {
        if (hostHeight <= 0) return baseDialogHeight
        const availableHeight = Math.max(260, Math.floor(hostHeight - verticalMargin * 2))
        const scaledHeight = Math.round(baseDialogHeight * (hostHeight / baseHostHeight))
        return Math.max(minimumDialogHeight, Math.min(scaledHeight, availableHeight))
    }

    onOpened: {
        const requested = String(requestedSection || "").trim()
        if (requested.length > 0) {
            selectSection(requested)
            Qt.callLater(function() {
                if (selectedSubsectionKey.length === 0) {
                    scrollToSectionStart()
                }
            })
            return
        }

        if (hasSessionState) {
            restoreSessionState()
            return
        }

        selectSection("getting_started")
        Qt.callLater(function() {
            if (selectedSubsectionKey.length === 0) {
                scrollToSectionStart()
            }
        })
    }
    onClosed: saveSessionState()
    onCloseRequested: close()

    function findSection(sectionKey) {
        const key = String(sectionKey || "")
        for (let i = 0; i < helpSections.length; i += 1) {
            const entry = helpSections[i] || {}
            if (String(entry.key || "") === key) return entry
        }
        return null
    }

    function subsectionsForSection(sectionKey) {
        const entry = findSection(sectionKey)
        return entry && Array.isArray(entry.subsections) ? entry.subsections : []
    }

    function firstSubsectionKey(sectionKey) {
        const subsections = subsectionsForSection(sectionKey)
        return subsections.length > 0 ? String((subsections[0] || {}).key || "") : ""
    }

    function subsectionIndexForKey(sectionKey, subsectionKey) {
        const key = String(subsectionKey || "")
        const subsections = subsectionsForSection(sectionKey)
        for (let i = 0; i < subsections.length; i += 1) {
            if (String((subsections[i] || {}).key || "") === key) return i
        }
        return -1
    }

    function sectionOwnsSubsection(sectionKey, subsectionKey) {
        const key = String(subsectionKey || "")
        const subsections = subsectionsForSection(sectionKey)
        for (let i = 0; i < subsections.length; i += 1) {
            if (String((subsections[i] || {}).key || "") === key) return true
        }
        return false
    }

    function clearSubsectionTargets() { subsectionTargets = ({}) }

    function registerSubsectionTarget(subsectionKey, item) {
        const key = String(subsectionKey || "")
        if (!key.length || !item) return
        const nextTargets = Object.assign({}, subsectionTargets)
        nextTargets[key] = item
        subsectionTargets = nextTargets
        if (pendingScrollSubsectionKey === key) {
            Qt.callLater(function() { scrollToSubsection(key) })
        }
    }

    function unregisterSubsectionTarget(subsectionKey, item) {
        const key = String(subsectionKey || "")
        if (!key.length || subsectionTargets[key] !== item) return
        const nextTargets = Object.assign({}, subsectionTargets)
        delete nextTargets[key]
        subsectionTargets = nextTargets
    }

    function subsectionItemForKey(subsectionKey) {
        const index = subsectionIndexForKey(contentSectionKey, subsectionKey)
        if (index < 0 || !contentRepeater || typeof contentRepeater.itemAt !== "function") {
            return null
        }
        return contentRepeater.itemAt(index + 1)
    }

    function scrollToSubsection(subsectionKey) {
        const key = String(subsectionKey || "")
        if (sectionOwnsSubsection(contentSectionKey, key)) {
            selectedSubsectionKey = key
        }
        const target = subsectionItemForKey(key)
        if (contentFlick && target && target.height > 0 && target.visible) {
            animateContentTo(Math.max(0, Math.round(Number(target.y || 0))))
            pendingScrollSubsectionKey = ""
            return
        }
        pendingScrollSubsectionKey = key
    }

    function syncVisibleSubsectionFromContentY() {
        if (!contentFlick) return
        if (contentScrollAnimation.running) return
        if (pendingScrollSubsectionKey.length > 0) return
        if (pendingRestoreContentY >= 0) return

        const subsections = subsectionsForSection(contentSectionKey)
        if (!Array.isArray(subsections) || subsections.length < 1) {
            if (selectedSubsectionKey.length > 0) {
                selectedSubsectionKey = ""
            }
            return
        }

        const triggerOffset = Math.max(48, Math.min(120, Math.round(Number(contentFlick.height || 0) * 0.18)))
        const anchorY = Math.max(0, Number(contentFlick.contentY || 0)) + triggerOffset
        let activeKey = ""
        for (let i = 0; i < subsections.length; i += 1) {
            const key = String((subsections[i] || {}).key || "")
            if (!key.length) continue
            const item = subsectionItemForKey(key)
            if (!item) continue
            const itemY = Math.max(0, Math.round(Number(item.y || 0)))
            if (itemY <= anchorY) {
                activeKey = key
            } else {
                break
            }
        }

        if (selectedSubsectionKey !== activeKey) {
            selectedSubsectionKey = activeKey
        }
    }

    function animateContentTo(desiredY) {
        if (!contentFlick) return
        const maxY = Math.max(0, contentFlick.contentHeight - contentFlick.height)
        const clampedY = Math.min(Math.max(0, desiredY), maxY)
        contentFlick.cancelFlick()
        contentScrollAnimation.stop()
        contentScrollAnimation.from = contentFlick.contentY
        contentScrollAnimation.to = clampedY
        contentScrollAnimation.start()
    }

    function restorePendingContentPosition() {
        if (!contentFlick || pendingRestoreContentY < 0 || pendingScrollSubsectionKey.length > 0) return
        const maxY = Math.max(0, contentFlick.contentHeight - contentFlick.height)
        if (maxY <= 0 && pendingRestoreContentY > 0) return
        const clampedY = Math.min(Math.max(0, pendingRestoreContentY), maxY)
        contentFlick.cancelFlick()
        contentScrollAnimation.stop()
        contentFlick.contentY = clampedY
        pendingRestoreContentY = -1
    }

    function scrollToSectionStart() {
        if (!contentFlick) return
        contentFlick.cancelFlick()
        contentScrollAnimation.stop()
        if (typeof contentFlick.positionViewAtBeginning === "function") {
            contentFlick.positionViewAtBeginning()
        }
        contentFlick.contentY = 0
        Qt.callLater(function() {
            if (!contentFlick || pendingScrollSubsectionKey.length > 0) return
            contentFlick.cancelFlick()
            contentScrollAnimation.stop()
            if (typeof contentFlick.positionViewAtBeginning === "function") {
                contentFlick.positionViewAtBeginning()
            }
            contentFlick.contentY = 0
        })
    }

    function selectSection(sectionKey) {
        const entry = findSection(sectionKey)
        if (!entry) return
        const nextKey = String(entry.key || "")
        contentSectionKey = nextKey
        expandedSectionKey = nextKey
        selectedSubsectionKey = ""
        clearSubsectionTargets()
        pendingScrollSubsectionKey = ""
        pendingRestoreContentY = -1
        scrollToSectionStart()
    }

    function saveSessionState() {
        const sectionKey = findSection(contentSectionKey)
            ? String(contentSectionKey || "")
            : "getting_started"
        hasSessionState = true
        sessionSectionKey = sectionKey
        sessionExpandedSectionKey = findSection(expandedSectionKey)
            ? String(expandedSectionKey || "")
            : sectionKey
        sessionSubsectionKey = sectionOwnsSubsection(sectionKey, selectedSubsectionKey)
            ? String(selectedSubsectionKey || "")
            : ""
        if (!contentFlick) {
            sessionContentY = 0
            return
        }
        const maxY = Math.max(0, contentFlick.contentHeight - contentFlick.height)
        sessionContentY = Math.min(Math.max(0, Number(contentFlick.contentY || 0)), maxY)
    }

    function restoreSessionState() {
        const sectionKey = findSection(sessionSectionKey)
            ? String(sessionSectionKey || "")
            : "getting_started"
        const expandedKey = findSection(sessionExpandedSectionKey)
            ? String(sessionExpandedSectionKey || "")
            : sectionKey
        contentSectionKey = sectionKey
        expandedSectionKey = expandedKey
        selectedSubsectionKey = sectionOwnsSubsection(sectionKey, sessionSubsectionKey)
            ? String(sessionSubsectionKey || "")
            : ""
        clearSubsectionTargets()
        pendingScrollSubsectionKey = ""
        pendingRestoreContentY = Math.max(0, Number(sessionContentY || 0))
        Qt.callLater(function() { restorePendingContentPosition() })
    }

    function selectSubsection(sectionKey, subsectionKey) {
        const entry = findSection(sectionKey)
        if (!entry) return
        const nextKey = String(entry.key || "")
        contentSectionKey = nextKey
        expandedSectionKey = nextKey
        selectedSubsectionKey = sectionOwnsSubsection(nextKey, subsectionKey)
            ? String(subsectionKey || "")
            : firstSubsectionKey(nextKey)
        pendingRestoreContentY = -1
        pendingScrollSubsectionKey = selectedSubsectionKey
        Qt.callLater(function() { scrollToSubsection(selectedSubsectionKey) })
    }

    function selectedSectionData() { return findSection(contentSectionKey) }
    function selectedSectionLabel() { return String((selectedSectionData() || {}).label || "") }
    function selectedSectionLeadHtml() { return String((selectedSectionData() || {}).leadHtml || "") }
    function contentRowsModel() {
        const rows = []
        const section = selectedSectionData() || {}

        rows.push({
            rowType: "section_intro",
            label: selectedSectionLabel(),
            leadHtml: selectedSectionLeadHtml()
        })

        const subsections = Array.isArray(section.subsections) ? section.subsections : []
        for (let i = 0; i < subsections.length; i += 1) {
            const subsection = subsections[i] || {}
            rows.push({
                rowType: "subsection",
                key: String(subsection.key || ""),
                label: String(subsection.label || ""),
                bodyHtml: String(subsection.bodyHtml || ""),
                bodyHtmlAfterScreenshot: String(subsection.bodyHtmlAfterScreenshot || ""),
                screenshotSource: String(subsection.screenshotSource || ""),
                screenshotTitle: String(subsection.screenshotTitle || ""),
                screenshotSourceAfter: String(subsection.screenshotSourceAfter || ""),
                screenshotTitleAfter: String(subsection.screenshotTitleAfter || ""),
                screenshotHintAfter: String(subsection.screenshotHintAfter || ""),
                screenshotHint: String(subsection.screenshotHint || "")
            })
        }

        return rows
    }
    function applyHelpLinkStyles(rawHtml, hoveredLink) {
        const html = String(rawHtml || "")
        if (!html.length) return ""

        const activeLink = String(hoveredLink || "")
        return html.replace(/<a\b([^>]*?)href=(["'])(.*?)\2([^>]*)>/gi, function(match, before, quote, href, after) {
            const cleanedBefore = String(before || "").replace(/\sstyle=(["']).*?\1/gi, "")
            const cleanedAfter = String(after || "").replace(/\sstyle=(["']).*?\1/gi, "")
            const decoration = href === activeLink ? "underline" : "none"
            return "<a" + cleanedBefore
                + " href=" + quote + href + quote
                + cleanedAfter
                + " style=\"color:#78b7ff; text-decoration:" + decoration + ";\">"
        })
    }
    function formatBodyHtml(rawHtml, hoveredLink) {
        const source = String(rawHtml || "").replace(/\r\n/g, "\n")
        if (!source.length) return ""

        const blocks = []
        let paragraphLines = []
        let bulletItems = []

        function pushParagraph() {
            if (!paragraphLines.length) return
            blocks.push({ type: "paragraph", lines: paragraphLines.slice(0) })
            paragraphLines = []
        }

        function pushBullets() {
            if (!bulletItems.length) return
            blocks.push({ type: "bullets", items: bulletItems.slice(0) })
            bulletItems = []
        }

        const lines = source.split(/<br\s*\/?\s*>/i)
        for (let i = 0; i < lines.length; i += 1) {
            const line = String(lines[i] || "").trim()
            if (!line.length) {
                pushParagraph()
                pushBullets()
                continue
            }
            if (/^(&bull;|•)\s*/i.test(line)) {
                pushParagraph()
                bulletItems.push(line.replace(/^(&bull;|•)\s*/i, ""))
                continue
            }
            pushBullets()
            paragraphLines.push(line)
        }

        pushParagraph()
        pushBullets()

        let html = ""
        for (let i = 0; i < blocks.length; i += 1) {
            const block = blocks[i] || {}
            const nextBlock = i + 1 < blocks.length ? (blocks[i + 1] || {}) : null
            const isLastBlock = i === blocks.length - 1
            const paragraphToList = block.type === "paragraph" && nextBlock && nextBlock.type === "bullets"
            const blockBottomMargin = isLastBlock ? 0 : (paragraphToList ? bodyListLeadGap : bodyParagraphSpacing)

            if (block.type === "paragraph") {
                html += "<p style=\"margin:0 0 " + blockBottomMargin + "px 0;\">"
                    + block.lines.join("<br>")
                    + "</p>"
                continue
            }

            if (block.type === "bullets") {
                const items = Array.isArray(block.items) ? block.items : []
                for (let j = 0; j < items.length; j += 1) {
                    const isLastItem = j === items.length - 1
                    const itemBottomMargin = isLastItem ? blockBottomMargin : 0
                    html += "<table style=\"margin:0 0 " + itemBottomMargin + "px " + bodyListIndent + "px; border-collapse:collapse;\" cellpadding=\"0\" cellspacing=\"0\">"
                        + "<tr>"
                        + "<td style=\"padding:0 10px 0 0; vertical-align:top; line-height:" + bodyLineHeight + ";\">&bull;</td>"
                        + "<td style=\"padding:0; vertical-align:top; line-height:" + bodyLineHeight + ";\">"
                        + items[j]
                        + "</td>"
                        + "</tr>"
                        + "</table>"
                }
            }
        }

        return applyHelpLinkStyles(html, hoveredLink)
    }
    function openHelpLink(url) {
        const normalized = String(url || "").trim()
        if (!normalized.length) return
        Qt.openUrlExternally(normalized)
    }
    function sidebarRowsModel() {
        const rows = []
        const sections = Array.isArray(helpSections) ? helpSections : []

        for (let i = 0; i < sections.length; i += 1) {
            const section = sections[i] || {}
            const sectionKey = String(section.key || "")
            const expanded = expandedSectionKey === sectionKey

            rows.push({
                rowType: "section",
                sectionKey: sectionKey,
                label: String(section.label || ""),
                iconSource: String(section.iconSource || ""),
                expanded: expanded
            })

            const subsections = Array.isArray(section.subsections) ? section.subsections : []
            for (let j = 0; j < subsections.length; j += 1) {
                const subsection = subsections[j] || {}
                rows.push({
                    rowType: "subsection",
                    sectionKey: sectionKey,
                    subsectionKey: String(subsection.key || ""),
                    label: String(subsection.label || ""),
                    expanded: expanded
                })
            }
        }

        return rows
    }

    Item {
        anchors.fill: parent

        Canvas {
            x: 1
            y: 1
            width: dialog.sidebarWidth
            height: parent.height - 2
            antialiasing: true
            contextType: "2d"
            onPaint: {
                const ctx = getContext("2d")
                const w = Math.max(1, width)
                const h = Math.max(1, height)
                const r = Math.max(0, Math.min(styleTokens.popupRadius - 1, w / 2, h / 2))
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(r, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h); ctx.lineTo(r, h)
                ctx.quadraticCurveTo(0, h, 0, h - r); ctx.lineTo(0, r); ctx.quadraticCurveTo(0, 0, r, 0)
                ctx.closePath(); ctx.fillStyle = themeColors.settingsSidebarPanelColor; ctx.fill()
            }
        }

        Image {
            id: helpTitleIcon
            x: dialog.menuLeft + dialog.menuIconLeftInset
            y: helpTitle.y + Math.round((helpTitle.implicitHeight - height) / 2)
            width: dialog.menuIconSize
            height: dialog.menuIconSize
            source: "qrc:/qt/qml/ComicPile/assets/icons/icon-book-open-text.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            id: helpTitle
            x: dialog.menuTextGlobalX
            y: dialog.menuTop - dialog.titleToMenuGap - implicitHeight
            text: "Help"
            color: styleTokens.textColor
            font.family: Qt.application.font.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        ListView {
            id: sidebarFlick
            x: dialog.menuLeft
            y: dialog.menuTop
            width: dialog.menuAreaWidth
            height: parent.height - dialog.menuTop - 16
            model: dialog.helpSections
            spacing: 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 190
                    easing.type: Easing.OutCubic
                }
            }

            delegate: Item {
                id: sectionBlock
                required property var modelData
                width: sidebarFlick.width

                readonly property string sectionKey: String(modelData.key || "")
                readonly property bool expanded: dialog.expandedSectionKey === sectionKey
                readonly property var sectionSubsections: dialog.subsectionsForSection(sectionKey)
                readonly property real subsectionBodyHeight: subsectionColumn.implicitHeight
                readonly property real targetOpenHeight: expanded && sectionSubsections.length > 0
                    ? dialog.menuItemSpacing + subsectionBodyHeight
                    : 0
                property real animatedOpenHeight: targetOpenHeight
                readonly property real subsectionReveal: subsectionBodyHeight > 0
                    ? Math.max(0, Math.min(1, (animatedOpenHeight - dialog.menuItemSpacing) / subsectionBodyHeight))
                    : 0

                height: sectionHeader.height + Math.max(0, animatedOpenHeight)
                clip: true

                onTargetOpenHeightChanged: animatedOpenHeight = targetOpenHeight

                Behavior on animatedOpenHeight {
                    NumberAnimation {
                        duration: 190
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: sectionHeader
                    width: parent.width
                    height: dialog.menuItemHeight

                    InsetEdgeSurface {
                        anchors.fill: parent
                        cornerRadius: dialog.menuItemRadius
                        visible: sectionMouseArea.containsMouse || sectionMouseArea.pressed || sectionBlock.expanded
                        fillColor: sectionMouseArea.pressed ? themeColors.settingsSidebarPressedColor
                            : sectionBlock.expanded ? themeColors.settingsSidebarSelectedColor
                            : themeColors.settingsSidebarHoverColor
                        edgeColor: sectionBlock.expanded ? themeColors.settingsSidebarSelectedEdgeColor
                            : themeColors.settingsSidebarHoverEdgeColor
                        fillOffsetY: sectionMouseArea.pressed ? -1 : 0
                    }

                    Text {
                        x: dialog.menuIconLeftInset + 18
                        y: Math.round((parent.height - implicitHeight) / 2) + (sectionMouseArea.pressed ? 1 : 0)
                        width: parent.width - x - 28
                        text: String(modelData.label || "")
                        color: sectionBlock.expanded || sectionMouseArea.containsMouse
                            ? styleTokens.textColor
                            : themeColors.settingsSidebarIdleTextColor
                        font.family: Qt.application.font.family
                        font.pixelSize: dialog.menuTextSize
                        font.weight: Font.Normal
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }

                    Canvas {
                        id: sectionIndicatorGlyph
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11
                        height: 5
                        rotation: sectionBlock.expanded ? 0 : -90
                        transformOrigin: Item.Center
                        contextType: "2d"
                        property color glyphColor: sectionBlock.expanded || sectionMouseArea.containsMouse
                            ? styleTokens.textColor
                            : themeColors.settingsSidebarIdleTextColor

                        onGlyphColorChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = glyphColor
                            ctx.beginPath()
                            ctx.moveTo(0, 0)
                            ctx.lineTo(width, 0)
                            ctx.lineTo(width / 2, height)
                            ctx.closePath()
                            ctx.fill()
                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: sectionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialog.selectSection(sectionBlock.sectionKey)
                    }
                }

                Item {
                    id: subsectionContainer
                    x: 0
                    y: sectionHeader.height + dialog.menuItemSpacing
                    width: parent.width
                    height: Math.max(0, sectionBlock.animatedOpenHeight - dialog.menuItemSpacing)
                    opacity: sectionBlock.subsectionReveal
                    clip: true

                    Column {
                        id: subsectionColumn
                        width: parent.width
                        spacing: dialog.subsectionSpacing

                        Repeater {
                            model: sectionBlock.sectionSubsections
                            delegate: Item {
                                id: subsectionRow
                                required property var modelData
                                width: subsectionColumn.width
                                height: dialog.subsectionItemHeight

                                readonly property string subsectionKey: String(modelData.key || "")
                                readonly property bool selected: dialog.selectedSubsectionKey === subsectionKey

                                Text {
                                    x: dialog.menuTextGlobalX + 15
                                    y: Math.round((parent.height - paintedHeight) / 2) + (subsectionMouseArea.pressed ? 1 : 0)
                                    width: parent.width - x - 16
                                    text: String(modelData.label || "")
                                    color: subsectionRow.selected || subsectionMouseArea.containsMouse ? "#ffffff" : "#a9a9a9"
                                    font.family: Qt.application.font.family
                                    font.pixelSize: 12
                                    font.weight: subsectionRow.selected ? Font.DemiBold : Font.Normal
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideNone
                                    lineHeight: 1.05
                                    lineHeightMode: Text.ProportionalHeight
                                }

                                MouseArea {
                                    id: subsectionMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dialog.selectSubsection(sectionBlock.sectionKey, subsectionRow.subsectionKey)
                                }
                            }
                        }
                    }
                }
            }
        }

        VerticalScrollThumb {
            anchors.top: sidebarFlick.top
            anchors.bottom: sidebarFlick.bottom
            anchors.right: sidebarFlick.right
            width: thumbWidth
            visible: sidebarFlick.contentHeight > sidebarFlick.height
            flickable: sidebarFlick
            thumbWidth: 8
            thumbInset: 0
            thumbColor: "#111111"
        }

        Item {
            id: contentPane
            x: dialog.sidebarWidth + dialog.contentInsetFromSidebar
            width: parent.width - x - styleTokens.dialogSideMargin
            height: parent.height

            Flickable {
                id: contentFlick
                x: 0
                y: Math.max(dialog.sectionTitleTop, dialog.contentTopSafeArea)
                width: parent.width
                height: parent.height - y - 16
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                interactive: !dialog.contentThumbDragActive && contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: {
                    if (dialog.pendingScrollSubsectionKey.length > 0) {
                        Qt.callLater(function() { dialog.scrollToSubsection(dialog.pendingScrollSubsectionKey) })
                    } else if (dialog.pendingRestoreContentY >= 0) {
                        Qt.callLater(function() { dialog.restorePendingContentPosition() })
                    } else if (dialog.selectedSubsectionKey.length === 0) {
                        Qt.callLater(function() { dialog.scrollToSectionStart() })
                    }
                }
                onContentYChanged: dialog.syncVisibleSubsectionFromContentY()
                onHeightChanged: {
                    if (dialog.pendingScrollSubsectionKey.length > 0) {
                        Qt.callLater(function() { dialog.scrollToSubsection(dialog.pendingScrollSubsectionKey) })
                    } else if (dialog.pendingRestoreContentY >= 0) {
                        Qt.callLater(function() { dialog.restorePendingContentPosition() })
                    } else if (dialog.selectedSubsectionKey.length === 0) {
                        Qt.callLater(function() { dialog.scrollToSectionStart() })
                    }
                }
                Column {
                    id: contentColumn
                    width: Math.max(320, contentFlick.width - 18)
                    spacing: dialog.sectionGap

                    Repeater {
                        id: contentRepeater
                        model: dialog.contentRowsModel()

                        delegate: Item {
                            id: contentSectionBlock
                            required property var modelData
                            width: contentColumn.width
                            readonly property string rowType: String(modelData.rowType || "")
                            readonly property string subsectionKey: String(modelData.key || "")
                            readonly property bool selected: dialog.selectedSubsectionKey === subsectionKey
                            readonly property bool hasScreenshotSource: String(modelData.screenshotSource || "").trim().length > 0
                            readonly property bool hasScreenshotPlaceholder: String(modelData.screenshotTitle || "").trim().length > 0
                            readonly property bool hasScreenshotCard: hasScreenshotSource || hasScreenshotPlaceholder
                            readonly property bool hasPostScreenshotBody: String(modelData.bodyHtmlAfterScreenshot || "").trim().length > 0
                            readonly property bool hasPostScreenshotSource: String(modelData.screenshotSourceAfter || "").trim().length > 0
                            readonly property bool hasPostScreenshotPlaceholder: String(modelData.screenshotTitleAfter || "").trim().length > 0
                            readonly property bool hasPostScreenshotCard: hasPostScreenshotSource || hasPostScreenshotPlaceholder
                            height: rowType === "section_intro"
                                ? introColumn.implicitHeight
                                : contentSectionColumn.implicitHeight

                            Component.onCompleted: {
                                if (contentSectionBlock.rowType === "subsection") {
                                    dialog.registerSubsectionTarget(contentSectionBlock.subsectionKey, contentSectionBlock)
                                }
                            }
                            Component.onDestruction: {
                                if (contentSectionBlock.rowType === "subsection") {
                                    dialog.unregisterSubsectionTarget(contentSectionBlock.subsectionKey, contentSectionBlock)
                                }
                            }

                            Column {
                                id: introColumn
                                visible: contentSectionBlock.rowType === "section_intro"
                                width: parent.width
                                spacing: 18

                                Text {
                                    width: parent.width
                                    text: String(modelData.label || "")
                                    color: styleTokens.textColor
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.sectionTitleSize
                                    font.weight: Font.Bold
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    id: introRichText
                                    property string hoveredLink: ""
                                    visible: text.length > 0
                                    width: parent.width
                                    text: dialog.applyHelpLinkStyles(String(modelData.leadHtml || ""), hoveredLink)
                                    color: "#a2a2a2"
                                    textFormat: Text.RichText
                                    onLinkActivated: function(link) { dialog.openHelpLink(link) }
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.sectionLeadSize
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.24
                                    lineHeightMode: Text.ProportionalHeight

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: introRichText.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onPositionChanged: function(mouse) {
                                            introRichText.hoveredLink = introRichText.linkAt(mouse.x, mouse.y)
                                        }
                                        onExited: introRichText.hoveredLink = ""
                                        onClicked: function(mouse) {
                                            const link = introRichText.linkAt(mouse.x, mouse.y)
                                            if (link.length > 0)
                                                dialog.openHelpLink(link)
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: themeColors.lineSidebarRight
                                    opacity: 0.7
                                }
                            }

                            Column {
                                id: contentSectionColumn
                                visible: contentSectionBlock.rowType === "subsection"
                                width: parent.width
                                spacing: dialog.subsectionBodyTopGap

                                Text {
                                    width: parent.width
                                    text: String(modelData.label || "")
                                    color: contentSectionBlock.selected ? styleTokens.textColor : "#e5e5e5"
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.subsectionTitleSize
                                    font.weight: Font.Bold
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    id: bodyRichText
                                    property string hoveredLink: ""
                                    width: parent.width
                                    text: dialog.formatBodyHtml(String(modelData.bodyHtml || ""), hoveredLink)
                                    color: styleTokens.textColor
                                    textFormat: Text.RichText
                                    onLinkActivated: function(link) { dialog.openHelpLink(link) }
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.bodyTextSize
                                    wrapMode: Text.WordWrap
                                    lineHeight: dialog.bodyLineHeight
                                    lineHeightMode: Text.ProportionalHeight

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: bodyRichText.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onPositionChanged: function(mouse) {
                                            bodyRichText.hoveredLink = bodyRichText.linkAt(mouse.x, mouse.y)
                                        }
                                        onExited: bodyRichText.hoveredLink = ""
                                        onClicked: function(mouse) {
                                            const link = bodyRichText.linkAt(mouse.x, mouse.y)
                                            if (link.length > 0)
                                                dialog.openHelpLink(link)
                                        }
                                    }
                                }

                                Item {
                                    visible: contentSectionBlock.hasScreenshotCard
                                    width: parent.width
                                    height: contentSectionBlock.hasScreenshotSource
                                        ? screenshotInlineColumn.implicitHeight
                                        : screenshotCardBackground.height

                                    Column {
                                        id: screenshotInlineColumn
                                        visible: contentSectionBlock.hasScreenshotSource
                                        width: parent.width
                                        spacing: 10

                                        Item {
                                            width: parent.width
                                            height: screenshotImage.height

                                            Image {
                                                id: screenshotImage
                                                readonly property real naturalWidth: Math.max(
                                                    0,
                                                    Number(sourceSize.width || implicitWidth || 0)
                                                )
                                                readonly property real naturalHeight: Math.max(
                                                    0,
                                                    Number(sourceSize.height || implicitHeight || 0)
                                                )
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                source: String(modelData.screenshotSource || "")
                                                asynchronous: true
                                                smooth: true
                                                fillMode: Image.PreserveAspectFit
                                                width: naturalWidth > 0
                                                    ? Math.min(parent.width, naturalWidth)
                                                    : 0
                                                height: naturalWidth > 0 && naturalHeight > 0
                                                    ? Math.round(width * naturalHeight / naturalWidth)
                                                    : 0
                                            }
                                        }

                                        Text {
                                            visible: String(modelData.screenshotTitle || "").trim().length > 0
                                            width: parent.width
                                            text: String(modelData.screenshotTitle || "")
                                            color: "#c9c9c9"
                                            font.family: Qt.application.font.family
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    Rectangle {
                                        id: screenshotCardBackground
                                        visible: !contentSectionBlock.hasScreenshotSource
                                        width: parent.width
                                        height: screenshotCardColumn.implicitHeight + dialog.screenshotCardPadding * 2
                                        radius: 14
                                        color: "#171717"
                                        border.width: 1
                                        border.color: themeColors.lineSidebarRight

                                        Column {
                                            id: screenshotCardColumn
                                            x: dialog.screenshotCardPadding
                                            y: dialog.screenshotCardPadding
                                            width: parent.width - dialog.screenshotCardPadding * 2
                                            spacing: contentSectionBlock.hasScreenshotSource ? 14 : 8

                                            Text {
                                                visible: !contentSectionBlock.hasScreenshotSource
                                                width: parent.width
                                                text: "Screenshot"
                                                color: styleTokens.textColor
                                                font.family: Qt.application.font.family
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                visible: !contentSectionBlock.hasScreenshotSource
                                                    && String(modelData.screenshotTitle || "").trim().length > 0
                                                width: parent.width
                                                text: String(modelData.screenshotTitle || "")
                                                color: "#d7d7d7"
                                                font.family: Qt.application.font.family
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                visible: String(modelData.screenshotHint || "").trim().length > 0
                                                width: parent.width
                                                text: String(modelData.screenshotHint || "")
                                                color: "#8d8d8d"
                                                font.family: Qt.application.font.family
                                                font.pixelSize: 12
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                                lineHeight: 1.18
                                                lineHeightMode: Text.ProportionalHeight
                                            }
                                        }
                                    }
                                }

                                Text {
                                    id: postBodyRichText
                                    property string hoveredLink: ""
                                    visible: contentSectionBlock.hasPostScreenshotBody
                                    width: parent.width
                                    text: dialog.formatBodyHtml(String(modelData.bodyHtmlAfterScreenshot || ""), hoveredLink)
                                    color: styleTokens.textColor
                                    textFormat: Text.RichText
                                    onLinkActivated: function(link) { dialog.openHelpLink(link) }
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.bodyTextSize
                                    wrapMode: Text.WordWrap
                                    lineHeight: dialog.bodyLineHeight
                                    lineHeightMode: Text.ProportionalHeight

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: postBodyRichText.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onPositionChanged: function(mouse) {
                                            postBodyRichText.hoveredLink = postBodyRichText.linkAt(mouse.x, mouse.y)
                                        }
                                        onExited: postBodyRichText.hoveredLink = ""
                                        onClicked: function(mouse) {
                                            const link = postBodyRichText.linkAt(mouse.x, mouse.y)
                                            if (link.length > 0)
                                                dialog.openHelpLink(link)
                                        }
                                    }
                                }

                                Item {
                                    visible: contentSectionBlock.hasPostScreenshotCard
                                    width: parent.width
                                    height: contentSectionBlock.hasPostScreenshotSource
                                        ? postScreenshotInlineColumn.implicitHeight
                                        : postScreenshotCardBackground.height

                                    Column {
                                        id: postScreenshotInlineColumn
                                        visible: contentSectionBlock.hasPostScreenshotSource
                                        width: parent.width
                                        spacing: 10

                                        Item {
                                            width: parent.width
                                            height: postScreenshotImage.height

                                            Image {
                                                id: postScreenshotImage
                                                readonly property real naturalWidth: Math.max(
                                                    0,
                                                    Number(sourceSize.width || implicitWidth || 0)
                                                )
                                                readonly property real naturalHeight: Math.max(
                                                    0,
                                                    Number(sourceSize.height || implicitHeight || 0)
                                                )
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                source: String(modelData.screenshotSourceAfter || "")
                                                asynchronous: true
                                                smooth: true
                                                fillMode: Image.PreserveAspectFit
                                                width: naturalWidth > 0
                                                    ? Math.min(parent.width, naturalWidth)
                                                    : 0
                                                height: naturalWidth > 0 && naturalHeight > 0
                                                    ? Math.round(width * naturalHeight / naturalWidth)
                                                    : 0
                                            }
                                        }

                                        Text {
                                            visible: String(modelData.screenshotTitleAfter || "").trim().length > 0
                                            width: parent.width
                                            text: String(modelData.screenshotTitleAfter || "")
                                            color: "#c9c9c9"
                                            font.family: Qt.application.font.family
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    Rectangle {
                                        id: postScreenshotCardBackground
                                        visible: !contentSectionBlock.hasPostScreenshotSource
                                        width: parent.width
                                        height: postScreenshotCardColumn.implicitHeight + dialog.screenshotCardPadding * 2
                                        radius: 14
                                        color: "#171717"
                                        border.width: 1
                                        border.color: themeColors.lineSidebarRight

                                        Column {
                                            id: postScreenshotCardColumn
                                            x: dialog.screenshotCardPadding
                                            y: dialog.screenshotCardPadding
                                            width: parent.width - dialog.screenshotCardPadding * 2
                                            spacing: contentSectionBlock.hasPostScreenshotSource ? 14 : 8

                                            Text {
                                                visible: !contentSectionBlock.hasPostScreenshotSource
                                                width: parent.width
                                                text: "Screenshot"
                                                color: styleTokens.textColor
                                                font.family: Qt.application.font.family
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                visible: !contentSectionBlock.hasPostScreenshotSource
                                                    && String(modelData.screenshotTitleAfter || "").trim().length > 0
                                                width: parent.width
                                                text: String(modelData.screenshotTitleAfter || "")
                                                color: "#d7d7d7"
                                                font.family: Qt.application.font.family
                                                font.pixelSize: 15
                                                font.weight: Font.Bold
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                visible: String(modelData.screenshotHintAfter || "").trim().length > 0
                                                width: parent.width
                                                text: String(modelData.screenshotHintAfter || "")
                                                color: "#8d8d8d"
                                                font.family: Qt.application.font.family
                                                font.pixelSize: 12
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                                lineHeight: 1.18
                                                lineHeightMode: Text.ProportionalHeight
                                            }
                                        }
                                    }
                                }

                            }
                        }
                    }

                    Item {
                        width: contentColumn.width
                        height: Math.max(0, contentFlick.height - 140)
                    }
                }
            }

            NumberAnimation {
                id: contentScrollAnimation
                target: contentFlick
                property: "contentY"
                duration: 220
                easing.type: Easing.OutCubic
            }

            VerticalScrollThumb {
                anchors.top: contentFlick.top
                anchors.bottom: contentFlick.bottom
                anchors.right: parent.right
                width: thumbWidth
                visible: contentFlick.contentHeight > contentFlick.height
                z: 12
                flickable: contentFlick
                thumbWidth: 8
                thumbInset: 0
                thumbColor: "#111111"
                onDragStarted: {
                    dialog.contentThumbDragActive = true
                    contentFlick.cancelFlick()
                    contentScrollAnimation.stop()
                }
                onDragEnded: {
                    dialog.contentThumbDragActive = false
                }
            }
        }
    }
}
