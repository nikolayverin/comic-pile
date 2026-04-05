import QtQuick
import QtQuick.Controls

PopupDialogWindow {
    id: dialog

    ThemeColors { id: themeColors }
    PopupStyle { id: styleTokens }

    property string expandedSectionKey: "getting_started"
    property string contentSectionKey: "getting_started"
    property string selectedSubsectionKey: "what_is_comic_pile"
    property string requestedSection: ""
    property string pendingScrollSubsectionKey: ""
    property var subsectionTargets: ({})
    readonly property var helpSectionsPartA: [
        {
            key: "getting_started",
            label: "Getting started",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-popup-info.svg",
            leadHtml: "New to <b><i>Comic Pile</i></b>? Start by importing a few comics, open one issue in the reader, and then return to the library. That is enough to understand the basic flow.",
            subsections: [
                {
                    key: "what_is_comic_pile",
                    label: "What is Comic Pile?",
                    bodyHtml: "<b><i>Comic Pile</i></b> is a library and reader for local comics and manga files. You import files from your computer, organize them in the library, add series or issue details when needed, and open them in the reader.<br><br>Use it when you want one place to keep reading and manage your collection without reopening files manually every time."
                },
                {
                    key: "what_do_i_do_first",
                    label: "What do I do first?",
                    bodyHtml: "Start with a small batch.<br><br><b>Recommended first steps:</b><br>&bull; import a few issues<br>&bull; check that they appear in the library<br>&bull; open one issue in the reader<br>&bull; close the reader and try <b><i>Continue reading</i></b><br><br>If that works, you are ready to use the app normally.",
                    screenshotTitle: "Import entry points",
                    screenshotHint: ""
                },
                {
                    key: "quick_tour_vs_help",
                    label: "When should I use Quick tour?",
                    bodyHtml: "Use <b><i>Quick tour</i></b> if you want a short walkthrough of the interface.<br><br>Use <b><i>Help</i></b> when you have a question such as:<br>&bull; how do I import files?<br>&bull; why does an issue not open?<br>&bull; what does this feature do?<br><br><b>Quick tour</b> is for the first look. <b>Help</b> is for specific questions."
                },
                {
                    key: "main_areas",
                    label: "Main areas of the app",
                    bodyHtml: "<b>Library</b> is where you browse, filter, and choose what to open.<br><br><b>Reader</b> is where you read the selected issue.<br><br><b>Settings</b> is where you change app behavior.<br><br><b>Help</b> is where you look up how something works or what to do when something goes wrong.",
                    screenshotTitle: "Main interface map",
                    screenshotHint: ""
                },
                {
                    key: "after_import",
                    label: "How do I know import worked?",
                    bodyHtml: "After import, check three things:<br>&bull; the new issues appear in the library<br>&bull; one of them opens in the reader<br>&bull; <b><i>Last Import</i></b> shows the items you expected<br><br>If the files do not appear, or an issue appears but will not open, go to <b><i>Troubleshooting</i></b>.",
                    screenshotTitle: "Library after first import",
                    screenshotHint: ""
                }
            ]
        },
        {
            key: "importing_comics",
            label: "Importing comics",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-download.svg",
            leadHtml: "Use this section before a big import, or when a file does not import the way you expected.",
            subsections: [
                {
                    key: "how_to_import",
                    label: "How do I import comics?",
                    bodyHtml: "You have two main choices:<br><br>&bull; <b>Add Files</b>: best when you want to import a few specific issues. If you are not sure, start here and test a small batch first.<br>&bull; <b>Add Folder</b>: best when one folder already contains many issues that belong together.<br><br><b>Safe way to import:</b><br>&bull; start with a small batch<br>&bull; wait for the import to finish<br>&bull; open one imported issue<br>&bull; only then import a larger batch"
                },
                {
                    key: "file_structure",
                    label: "What should my files look like?",
                    bodyHtml: "Comic Pile works best when one issue is one source.<br><br><b>Good examples:</b><br>&bull; one archive file per issue, such as <b>Batman 001.cbz</b><br>&bull; one folder per issue, such as <b>Series Name/Issue 001/</b><br><br><b>Avoid this when possible:</b><br>&bull; one folder that mixes pages from several issues<br>&bull; folders full of extra files that are not pages<br>&bull; inconsistent issue naming inside the same batch",
                    screenshotTitle: "Example of a clean folder structure",
                    screenshotHint: ""
                },
                {
                    key: "page_order",
                    label: "Page order matters",
                    bodyHtml: "If you import image folders, page names should already be in reading order.<br><br><b>Good page names:</b><br>&bull; <b>001</b><br>&bull; <b>002</b><br>&bull; <b>003</b><br><br>Use leading zeroes. That helps avoid cases like <b>1</b>, <b>10</b>, <b>2</b>, which can put pages in the wrong order.",
                    screenshotTitle: "Duplicate issue popup",
                    screenshotHint: ""
                },
                {
                    key: "duplicate_found",
                    label: "What should I do if a duplicate is found?",
                    bodyHtml: "If Comic Pile finds a matching issue during import, it opens a decision popup.<br><br>Use <b>Keep current</b> when you want to leave the existing issue untouched.<br>Use <b>Replace</b> when the new file is the same issue and should take the place of the current file.<br>Use <b>Import as new</b> when the new file should stay as a separate issue.<br>Use <b>Skip</b> when you do not want to import that file right now.<br><br>If you are working through many exact duplicates, <b>Skip all</b> or <b>Replace all</b> applies the same choice to the rest of that batch."
                },
                {
                    key: "replace_issue",
                    label: "What does Replace do?",
                    bodyHtml: "<b>Replace</b> keeps the existing issue entry but swaps in the new file.<br><br>Use it when the new archive is a corrected or better copy of the same issue.<br><br>If you are not sure whether the new file really represents the same issue, choose <b>Import as new</b> instead.",
                    screenshotTitle: "Import Errors popup",
                    screenshotHint: ""
                },
                {
                    key: "import_errors_batch",
                    label: "What should I do if Import Errors appears?",
                    bodyHtml: "This means one or more files in the batch were not imported.<br><br>Use <b>Retry</b> after you fix the file and want to try again.<br>Use <b>Skip</b> to ignore only the current failed file.<br>Use <b>Skip all</b> to ignore the remaining failed files and finish the review faster.<br><br>If only one file fails, the problem is usually in that file. If many files fail in the same batch, check the source folder and storage access."
                },
                {
                    key: "last_import",
                    label: "What is Last Import?",
                    bodyHtml: "<b><i>Last Import</i></b> shows the most recent import session.<br><br>Use it right after import if you want to confirm what was added, especially after a large batch."
                }
            ]
        },
        {
            key: "supported_formats",
            label: "Supported formats",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-book-open-text.svg",
            leadHtml: "Check this section if you are not sure whether a file or folder can be imported.",
            subsections: [
                {
                    key: "import_formats",
                    label: "What formats can I import?",
                    bodyHtml: "Comic Pile currently supports:<br><br><b>Archives:</b> <b>CBZ</b>, <b>ZIP</b>, <b>CBR</b><br><b>Documents:</b> <b>PDF</b>, <b>DJVU</b>, <b>DJV</b><br><b>Image folders:</b> folders with page files such as <b>JPG</b>, <b>JPEG</b>, <b>PNG</b>, <b>BMP</b>, and <b>WEBP</b>"
                },
                {
                    key: "cbr_note",
                    label: "What if CBR does not import?",
                    bodyHtml: "<b>CBR</b> support depends on a working <b>7-Zip</b> setup.<br><br>If CBR files fail while CBZ or PDF files still import normally, check the <b>Import &amp; Archives</b> section in <b>Settings</b> and verify that 7-Zip is available."
                },
                {
                    key: "after_import_normalization",
                    label: "Can I import image folders?",
                    bodyHtml: "Yes, if the folder directly contains page images in reading order.<br><br><b>Best practice:</b><br>&bull; keep one issue per folder<br>&bull; name pages in order<br>&bull; do not mix pages from different issues in one folder"
                },
                {
                    key: "unsupported_formats",
                    label: "What is not supported?",
                    bodyHtml: "Do not assume that every archive or every image folder will work.<br><br><b>Common problem cases:</b><br>&bull; folders with no readable pages<br>&bull; folders with pages from several issues mixed together<br>&bull; unsupported document types<br>&bull; formats not listed above<br><br>If you are not sure, test one issue first."
                }
            ]
        }
    ]
    readonly property var helpSectionsPartB: [
        {
            key: "library_data",
            label: "Library and data",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-library-big.svg",
            leadHtml: "Use this section when you move folders, replace the app build, or need to check whether Comic Pile can still reach your library files.",
            subsections: [
                {
                    key: "app_vs_data",
                    label: "What is stored where?",
                    bodyHtml: "<b>The app</b> is what you launch.<br><b>Library data</b> is what the app uses to keep your active collection state.<br><br>This is why reinstalling or updating the app is not the same as deleting your library data."
                },
                {
                    key: "move_data_location",
                    label: "Can I move the library data location?",
                    bodyHtml: "Yes. Do it through <b>Settings -> Library &amp; Data</b>.<br><br><b>Recommended steps:</b><br>&bull; open <b>Settings</b><br>&bull; go to <b>Library &amp; Data</b><br>&bull; choose the new location<br>&bull; restart when asked<br><br>Do not move the active library-data location manually while the app is using it.",
                    screenshotTitle: "Location of Check storage access in Settings",
                    screenshotHint: ""
                },
                {
                    key: "check_storage_access",
                    label: "When should I use Check storage access?",
                    bodyHtml: "Use <b><i>Check storage access</i></b> when files stop opening, import starts failing, or the library feels wrong after you moved folders.<br><br>It is the fastest way to check whether the current storage setup is still reachable."
                },
                {
                    key: "reset_settings",
                    label: "What should I avoid moving manually?",
                    bodyHtml: "Avoid manually moving active library folders, storage folders, or library-data folders while Comic Pile is using them.<br><br>If you need to move storage-related content, use the app's own controls first. That is the safest way to avoid broken paths and missing-file problems."
                },
                {
                    key: "moved_folders_problem",
                    label: "What should I do if files stop opening after I moved folders?",
                    bodyHtml: "Start with this order:<br>&bull; open <b>Settings -> Library &amp; Data</b><br>&bull; run <b><i>Check storage access</i></b><br>&bull; confirm that the moved location is the one the app is using now<br><br>If the problem started right after a manual move, do not keep reimporting files immediately. Check the storage setup first."
                }
            ]
        },
        {
            key: "reader",
            label: "Reader",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-reader-settings.svg",
            leadHtml: "Use this section when you want to resume reading, move through issues more quickly, or understand why the reader behaves differently than expected.",
            subsections: [
                {
                    key: "opening_issue",
                    label: "Opening an issue",
                    bodyHtml: "Open any issue from the library to start reading.<br><br>If the issue belongs to a series, you can keep moving through nearby issues from inside the reader instead of returning to the library every time.",
                    screenshotTitle: "Reader menu and navigation controls",
                    screenshotHint: ""
                },
                {
                    key: "continue_next_unread",
                    label: "Continue reading and Next unread",
                    bodyHtml: "<b><i>Continue reading</i></b> takes you back to where you left off.<br><br><b><i>Next unread</i></b> opens the next unread issue from that same reading flow.<br><br>Use them when you want to keep reading without searching the library by hand."
                },
                {
                    key: "bookmark_vs_continue",
                    label: "What is the difference between a bookmark and continue reading?",
                    bodyHtml: "A <b><i>bookmark</i></b> is a manual saved spot inside one issue.<br><br><b><i>Continue reading</i></b> uses the latest saved reading progress.<br><br>Use a bookmark when you want to mark a page on purpose. Use Continue reading when you just want to resume."
                },
                {
                    key: "manga_mode",
                    label: "Manga mode",
                    bodyHtml: "<b><i>Manga mode</i></b> changes reading direction.<br><br>Turn it on for manga or any content that reads in the opposite direction from the default comic flow.<br><br>If page navigation suddenly feels reversed, check whether manga mode is active.",
                    screenshotTitle: "Manga mode toggle",
                    screenshotHint: ""
                }
            ]
        },
        {
            key: "troubleshooting",
            label: "Troubleshooting",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-alert-triangle.svg",
            leadHtml: "Start here when something does not open, import fails, or the app behaves differently than you expected.",
            subsections: [
                {
                    key: "issue_does_not_open",
                    label: "The issue does not open",
                    bodyHtml: "Try these checks in order:<br>&bull; make sure the issue is still visible in the library<br>&bull; open another issue to see whether the problem affects one file or many<br>&bull; if you moved folders recently, run <b><i>Check storage access</i></b><br><br>If only one issue fails, the problem is usually with that issue. If many issues fail, check storage first."
                },
                {
                    key: "import_failed",
                    label: "Import failed",
                    bodyHtml: "If import fails, check these first:<br>&bull; the file type is supported<br>&bull; the archive or document opens normally outside the app<br>&bull; an image folder really contains page files<br>&bull; the file is not locked by another app<br><br>If you are not sure, try importing one known-good issue first."
                },
                {
                    key: "import_errors_popup",
                    label: "What if only one archive fails during a large import?",
                    bodyHtml: "That usually means the rest of the batch can still be fine.<br><br>Review the failed file in <b>Import Errors</b>. If the other imported issues appear and open normally, the problem is usually limited to that one archive.<br><br>Retry it only after you fix or replace the source file."
                }
            ]
        }
    ]
    readonly property var helpSections: helpSectionsPartA.concat(helpSectionsPartB)

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
    readonly property int sectionTitleSize: 28
    readonly property int sectionLeadSize: 14
    readonly property int subsectionTitleSize: 17
    readonly property int bodyTextSize: 13
    readonly property int screenshotPlaceholderHeight: 188
    readonly property int sectionGap: 30
    readonly property int subsectionGap: 28
    readonly property int subsectionBodyTopGap: 18
    readonly property int subsectionIndent: 18
    readonly property int subsectionItemHeight: 42
    readonly property int subsectionRadius: 6
    readonly property int subsectionSpacing: 6
    readonly property int bodyParagraphSpacing: 18
    readonly property int bodyListLeadGap: 10
    readonly property int bodyListItemSpacing: 8
    readonly property int bodyListIndent: 22
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
        const scaledWidth = Math.round(baseDialogWidth * (hostWidth / baseHostWidth))
        return Math.max(minimumDialogWidth, Math.min(scaledWidth, availableWidth))
    }
    height: {
        if (hostHeight <= 0) return baseDialogHeight
        const availableHeight = Math.max(260, Math.floor(hostHeight - verticalMargin * 2))
        const scaledHeight = Math.round(baseDialogHeight * (hostHeight / baseHostHeight))
        return Math.max(minimumDialogHeight, Math.min(scaledHeight, availableHeight))
    }

    onOpened: {
        const requested = String(requestedSection || "").trim()
        selectSection(requested.length > 0 ? requested : "getting_started")
    }
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

    function scrollToSubsection(subsectionKey) {
        const key = String(subsectionKey || "")
        const index = subsectionIndexForKey(contentSectionKey, key)
        if (contentFlick && index >= 0 && contentFlick.itemAtIndex) {
            let targetItem = contentFlick.itemAtIndex(index)
            if (!targetItem && contentFlick.positionViewAtIndex) {
                contentFlick.positionViewAtIndex(index, ListView.Visible)
                targetItem = contentFlick.itemAtIndex(index)
            }
            if (targetItem) {
                const targetPoint = targetItem.mapToItem(contentFlick.contentItem, 0, 0)
                animateContentTo(Math.max(0, Math.round(targetPoint.y)))
                pendingScrollSubsectionKey = ""
                return
            }
        }
        const target = subsectionTargets[key]
        if (!contentFlick || !target || target.height <= 0 || !target.visible) {
            pendingScrollSubsectionKey = key
            return
        }
        const targetPoint = target.mapToItem(contentFlick.contentItem, 0, 0)
        animateContentTo(Math.max(0, Math.round(targetPoint.y)))
        pendingScrollSubsectionKey = ""
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

    function selectSection(sectionKey) {
        const entry = findSection(sectionKey)
        if (!entry) return
        const nextKey = String(entry.key || "")
        contentSectionKey = nextKey
        expandedSectionKey = nextKey
        if (!sectionOwnsSubsection(nextKey, selectedSubsectionKey)) {
            selectedSubsectionKey = firstSubsectionKey(nextKey)
        }
        clearSubsectionTargets()
        pendingScrollSubsectionKey = ""
        if (contentFlick) {
            contentScrollAnimation.stop()
            contentFlick.contentY = 0
        }
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
        pendingScrollSubsectionKey = selectedSubsectionKey
        Qt.callLater(function() { scrollToSubsection(selectedSubsectionKey) })
    }

    function selectedSectionData() { return findSection(contentSectionKey) }
    function selectedSectionLabel() { return String((selectedSectionData() || {}).label || "") }
    function selectedSectionLeadHtml() { return String((selectedSectionData() || {}).leadHtml || "") }
    function formatBodyHtml(rawHtml) {
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
                    const itemBottomMargin = isLastItem ? blockBottomMargin : bodyListItemSpacing
                    html += "<p style=\"margin:0 0 " + itemBottomMargin + "px " + bodyListIndent + "px;\">&bull; "
                        + items[j]
                        + "</p>"
                }
            }
        }

        return html
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

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: ">"
                        rotation: sectionBlock.expanded ? 90 : 0
                        transformOrigin: Item.Center
                        color: sectionBlock.expanded || sectionMouseArea.containsMouse
                            ? styleTokens.textColor
                            : themeColors.settingsSidebarIdleTextColor
                        font.pixelSize: 12

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

            ListView {
                id: contentFlick
                x: 0
                y: dialog.sectionTitleTop
                width: parent.width
                height: parent.height - y - 16
                clip: true
                model: dialog.subsectionsForSection(dialog.contentSectionKey)
                spacing: dialog.sectionGap
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: {
                    if (dialog.pendingScrollSubsectionKey.length > 0) {
                        Qt.callLater(function() { dialog.scrollToSubsection(dialog.pendingScrollSubsectionKey) })
                    }
                }
                onHeightChanged: {
                    if (dialog.pendingScrollSubsectionKey.length > 0) {
                        Qt.callLater(function() { dialog.scrollToSubsection(dialog.pendingScrollSubsectionKey) })
                    }
                }

                header: Item {
                    width: contentFlick.width
                    height: headerColumn.implicitHeight + dialog.sectionGap

                    Column {
                        id: headerColumn
                        width: Math.max(320, contentFlick.width - 18)
                        spacing: 18

                        Text {
                            width: parent.width
                            text: dialog.selectedSectionLabel()
                            color: styleTokens.textColor
                            font.family: Qt.application.font.family
                            font.pixelSize: dialog.sectionTitleSize
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: dialog.selectedSectionLeadHtml()
                            color: "#a2a2a2"
                            textFormat: Text.RichText
                            font.family: Qt.application.font.family
                            font.pixelSize: dialog.sectionLeadSize
                            wrapMode: Text.WordWrap
                            lineHeight: 1.24
                            lineHeightMode: Text.ProportionalHeight
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: themeColors.lineSidebarRight
                            opacity: 0.7
                        }
                    }
                }

                delegate: Item {
                    id: contentSectionBlock
                    required property var modelData
                    width: Math.max(320, contentFlick.width - 18)
                    height: contentSectionColumn.implicitHeight
                    readonly property string subsectionKey: String(modelData.key || "")
                    readonly property bool selected: dialog.selectedSubsectionKey === subsectionKey
                    readonly property bool hasScreenshotPlaceholder: String(modelData.screenshotTitle || "").trim().length > 0

                    Column {
                        id: contentSectionColumn
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
                            width: parent.width
                            text: dialog.formatBodyHtml(String(modelData.bodyHtml || ""))
                            color: styleTokens.textColor
                            textFormat: Text.RichText
                            font.family: Qt.application.font.family
                            font.pixelSize: dialog.bodyTextSize
                            wrapMode: Text.WordWrap
                            lineHeight: 1.28
                            lineHeightMode: Text.ProportionalHeight
                        }

                        Rectangle {
                            visible: contentSectionBlock.hasScreenshotPlaceholder
                            width: parent.width
                            height: dialog.screenshotPlaceholderHeight
                            radius: 14
                            color: "#171717"
                            border.width: 1
                            border.color: themeColors.lineSidebarRight

                            Column {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 48, 420)
                                spacing: 8

                                Text {
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

                        Rectangle {
                            visible: index < dialog.subsectionsForSection(dialog.contentSectionKey).length - 1
                            width: parent.width
                            height: 1
                            color: themeColors.lineSidebarRight
                            opacity: 0.42
                        }
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
                visible: contentFlick.contentHeight > contentFlick.height
                flickable: contentFlick
                thumbWidth: 8
                thumbInset: 0
                thumbColor: "#111111"
            }
        }
    }
}
