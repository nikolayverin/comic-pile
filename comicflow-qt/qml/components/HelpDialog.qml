import QtQuick
import QtQuick.Controls

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
                    bodyHtml: "<b><i>Comic Pile</i></b> is a library and reader for your local comics and manga files. Import files from your computer, organize them in the library, add series or issue details when needed, and open them in the reader. Use <b><i>Comic Pile</i></b> as your personal library to keep, organize, and read comics in one place instead of handling them as separate files."
                },
                {
                    key: "main_areas",
                    label: "Main areas of the app",
                    bodyHtml: "<b>Main menu</b><br>The <b>Top bar</b> contains the main app menus <b>File</b> and <b>Help</b>, plus reading shortcuts such as <b>Continue reading</b> and <b>Next unread</b>. Use it to open main commands without leaving the current screen.<br><br><b>Library</b><br>The <b>Library</b> shows search, quick filters such as <b>Last import</b>, <b>Favorites</b>, and <b>Bookmarks</b>, and the list of series in your library. Use it to move around the library, switch between filters and series, and find what you want to open.<br><br><b>Drop zone</b><br>The <b>bottom of Library</b> contains the drop zone for files and folders. Use it to quickly add comics to the app by dropping supported files or folders into it.<br><br><b>Series spotlight</b><br>The <b>Series spotlight</b> shows the currently selected series and its main details. Use it to confirm which series you are viewing before opening an issue or editing series information.<br><br><b>Issues</b><br><b>Issues</b> shows the issues that belong to the selected series or active filter. Use it to browse the available issues and click a cover to open it in the reader.<br><br><b>Grid view controls</b><br>The <b>Bottom bar</b> contains the controls for issue order and grid density. Use them to change how <b>Issues</b> is sorted and how compact or spacious it looks.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/01-interface.png",
                    screenshotTitle: "Main interface map",
                    screenshotHint: ""
                },
                {
                    key: "what_do_i_do_first",
                    label: "What do I do first?",
                    bodyHtml: "Start with these simple steps:<br><br>&bull; import one issue file into the app through the <b>drop zone</b><br>&bull; make sure it appears in the interface<br>&bull; click the issue cover to open the reader<br><br>Done. You now know the basic flow of the app.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/02-dropzone.png",
                    screenshotTitle: "Start by dropping files here",
                    screenshotHint: ""
                },
                {
                    key: "after_import",
                    label: "How do I know import worked?",
                    bodyHtml: "After import, check two things:<br>&bull; the imported series appears in <b>Library</b><br>&bull; one of the imported issues appears in <b>Issues</b> and opens in <b>Reader</b> when you click its cover",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/03-library-issues.png",
                    screenshotTitle: "Check imported series and issue",
                    screenshotHint: ""
                }
            ]
        },
        {
            key: "importing_comics",
            label: "Importing comics",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-download.svg",
            leadHtml: "",
            subsections: [
                {
                    key: "import_source_types",
                    label: "What files can I import?",
                    bodyHtml: "Comic Pile can import many file types, not just archives.<br><br><b>Archives</b> such as <b>CBZ</b>, <b>ZIP</b>, <b>CBR</b>, <b>RAR</b>, <b>CB7</b>, <b>7Z</b>, <b>CBT</b>, and <b>TAR</b><br>&bull; one archive usually means one issue<br><br><b>Folders with image files</b> such as <b>JPG</b>, <b>JPEG</b>, <b>PNG</b>, <b>BMP</b>, and <b>WEBP</b><br>&bull; one folder usually means one issue made of page images<br><br><b>Multi-page documents</b> such as <b>PDF</b>, <b>DJVU</b>, and <b>DJV</b><br>&bull; one document usually means one issue<br><br>Some archive formats depend on the built-in <b>7-Zip</b> component that comes with <b>Comic Pile</b>.<br><br>This is why one source may look like a file, while another may look like a folder. Comic Pile can treat both as one issue when the structure is correct."
                },
                {
                    key: "file_structure",
                    label: "How should files be prepared for import?",
                    bodyHtml: "For reliable import, prepare each issue as one clear source.<br><br><b>Good examples:</b><br>&bull; one archive file per issue, such as <b>ComicsName 001.cbz</b><br>&bull; one folder per issue, such as <b>Series Name/Issue 001/</b><br><br>If you import page-based sources such as image folders or archives, page names should already be in reading order.<br><br><b>Good page names:</b><br>&bull; <b>001</b><br>&bull; <b>002</b><br>&bull; <b>003</b><br><br>Use leading zeroes. That helps avoid cases like <b>1</b>, <b>10</b>, and <b>2</b>, which can put pages in the wrong order.<br><br><b>For image folders:</b><br>&bull; keep the pages of one issue in one folder<br>&bull; do not mix pages from different issues in the same folder<br>&bull; keep page names in reading order<br>&bull; vertical page images work best for issue covers in the grid<br>&bull; horizontal double-page spreads inside the issue still open normally in <b>Reader</b><br><br><b>Before importing, check for these common problems.</b> If you see any of them, fix them first for a more predictable result:<br>&bull; one folder that mixes pages from several issues<br>&bull; folders full of extra files that are not pages<br>&bull; inconsistent issue naming inside the same batch",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/04-file-naming.png",
                    screenshotTitle: "Example of a clean folder structure",
                    screenshotHint: ""
                },
                {
                    key: "import_size",
                    label: "Does file size matter?",
                    bodyHtml: "Comic Pile does not use a fixed import size limit in MB. Your files stay on your own computer, so the main difference with large sources is usually import time. Bigger archives, folders, or documents can take longer to process and appear in the app."
                },
                {
                    key: "how_to_import",
                    label: "How do I import comics?",
                    bodyHtml: "You can import in three simple ways:<br><br>&bull; <b>Drop files or folders</b> into the <b>drop zone</b> in <b>Library</b><br>&bull; <b>File -> Add files</b>: best when you want to import a few specific issues<br>&bull; <b>File -> Add folder</b>: best when one folder already contains many issues that belong together"
                },
                {
                    key: "duplicate_found",
                    label: "What happens if Comic Pile finds a matching issue during import?",
                    bodyHtml: "If Comic Pile finds a match during import, it opens a review popup before anything is changed.<br><br>In that popup, you will see two references:<br><br>&bull; the file you are importing, shown under <b>Incoming archive</b><br>&bull; the issue already in your library, shown under <b>Existing record</b><br><br>The names can look identical or very similar when the match is close.<br><br><b>1. Exact duplicate</b><br>If Comic Pile is confident that the imported file matches an issue that already exists in your library, it opens the <b>Issue Already Exists</b> popup.<br><br>In that popup, decide whether to:<br><br>&bull; keep the existing issue with <b>Keep current</b><br>&bull; replace it with the new file using <b>Replace</b><br>&bull; apply the same choice to the remaining exact duplicates with <b>Skip all</b> or <b>Replace all</b>, if those actions appear",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/05-popup.png",
                    screenshotTitle: "Issue Already Exists popup for exact duplicates",
                    bodyHtmlAfterScreenshot: "<b>2. Related match</b><br>If Comic Pile finds something that looks close to an existing issue, but the match is not exact enough to treat it as a confirmed duplicate, it opens the <b>Possible Duplicate Found</b> popup.<br><br>In that popup, decide whether to:<br><br>&bull; keep the new file as a separate issue with <b>Import as new</b><br>&bull; leave it out of the import for now with <b>Skip</b><br>&bull; replace the existing issue with <b>Replace existing</b>, if that option appears",
                    screenshotSourceAfter: "qrc:/qt/qml/ComicPile/assets/ui/help/06-popup.png",
                    screenshotTitleAfter: "Possible Duplicate Found popup for related matches",
                    screenshotHint: ""
                },
                {
                    key: "import_errors_batch",
                    label: "What should I do if Comic Pile shows Import Errors during import?",
                    bodyHtml: "If Comic Pile shows an <b>Import Errors</b> popup during import, one or more files in the current batch could not be imported.<br><br>Use <b>Retry</b> after you fix the file and want Comic Pile to try it again.<br>Use <b>Skip</b> to leave out only the current failed file.<br>Use <b>Skip all</b> to leave out the remaining failed files and finish the current batch faster.<br><br>If only one file fails, the problem is usually in that file. If many files fail in the same batch, check the source folder and storage access.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/07-popup.png",
                    screenshotTitle: "Import Errors popup during import",
                    screenshotHint: ""
                },
                {
                    key: "after_import_flow",
                    label: "What happens after import?",
                    bodyHtml: "After import, the first imported series opens automatically. This lets you check the result and start opening issues right away. If several series were imported, you can then move between them from the library."
                }
            ]
        },
        {
            key: "supported_formats",
            label: "Supported formats",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-book-open-text.svg",
            leadHtml: "",
            subsections: [
                {
                    key: "import_formats",
                    label: "What formats can I import?",
                    bodyHtml: "Comic Pile currently supports:<br><br><b>Archives:</b> <b>CBZ</b>, <b>ZIP</b>, <b>CBR</b>, <b>RAR</b>, <b>7Z</b>, <b>CB7</b>, <b>CBT</b>, and <b>TAR</b><br><b>Documents:</b> <b>PDF</b>, <b>DJVU</b>, <b>DJV</b><br><b>Image folders:</b> folders with page files such as <b>JPG</b>, <b>JPEG</b>, <b>PNG</b>, <b>BMP</b>, and <b>WEBP</b>"
                },
                {
                    key: "cbr_note",
                    label: "What if CBR does not import?",
                    bodyHtml: "<b>CBR</b> support depends on a working <b>7-Zip</b> setup. If CBR files fail while CBZ or PDF files still import normally, open <b>File -> Settings -> Import &amp; Archives</b> and run the 7-Zip verification.<br><br>If 7-Zip is missing and verification still fails, first update the app, because 7-Zip is bundled with <b>Comic Pile</b>. If it is still not available, install 7-Zip manually from the official website: <a href=\"https://www.7-zip.org/\" style=\"color:#78b7ff; text-decoration:underline;\">https://www.7-zip.org/</a>"
                },
                {
                    key: "after_import_normalization",
                    label: "Can I import image folders?",
                    bodyHtml: "Yes. Image folders can be imported when the final folder for one issue directly contains the page images in reading order.<br><br><b>Best practice:</b><br>&bull; keep one issue per folder<br>&bull; give the folder a clear issue-style name, for example <b>Series Name 001</b><br>&bull; name pages in order<br>&bull; do not mix pages from different issues in one folder<br>&bull; nested parent folders are also fine, as long as the final issue folders contain the actual page files"
                },
                {
                    key: "unsupported_formats",
                    label: "What input usually causes import problems?",
                    bodyHtml: "These cases often cause import problems:<br><br>&bull; corrupted archives, documents, or image files<br>&bull; files in formats not listed in <b>What formats can I import?</b><br>&bull; folders that mix pages from different issues can import incorrectly and should be split before import<br><br>If you are not sure, test one issue first."
                }
            ]
        }
    ]
    readonly property var helpSectionsPartB: [
        {
            key: "library_data",
            label: "Library and data",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-library-big.svg",
            leadHtml: "",
            subsections: [
                {
                    key: "app_vs_data",
                    label: "What is stored where?",
                    bodyHtml: "The app is what you launch. Your library is stored separately and, by default, is created in the app folder rather than inside the app itself. This is why replacing the app files or updating the app does not remove your library by itself."
                },
                {
                    key: "move_data_location",
                    label: "Can I move the library data location?",
                    bodyHtml: "Yes. Open <b>File -> Settings -> Library &amp; Data</b>, then use <b>Move library data -> Choose</b> to select a new folder. After that, restart the app. The transfer runs on the next launch, so choose an empty folder in advance and do not move the active library data manually while the app is using it.<br><br>Once that transfer has started, it must finish or stop with an error before the app can continue."
                },
                {
                    key: "check_storage_access",
                    label: "When should I use Check storage access?",
                    bodyHtml: "Use <b><i>Check storage access</i></b> when the problem looks related to file access or the current library location.<br><br><b>Typical cases:</b><br>&bull; files stop opening<br>&bull; many issues suddenly stop opening at once<br>&bull; import starts failing because the app cannot access the current storage location<br><br><b>If files stop opening, start with this order:</b><br>&bull; open <b>File -> Settings -> Library &amp; Data</b><br>&bull; run <b><i>Check storage access</i></b><br>&bull; confirm that the current library data location is the one the app is using now<br><br>This check quickly tests whether the current library data location, database, library folder, and runtime folder are still reachable and writable. If everything works normally, you usually do not need to run it.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/08-settings-check.png",
                    screenshotTitle: "Location of Check storage access in Settings",
                    screenshotHint: ""
                },
                {
                    key: "edit_one_issue",
                    label: "How do I edit one issue?",
                    bodyHtml: "Use this path:<br>&bull; open the series in <b>Library</b><br>&bull; find the issue in <b>Issues</b><br>&bull; open the issue menu and press <b>Edit</b><br><br>Use it when you want to change issue-level fields such as <b>issue number</b>, <b>title</b>, <b>publisher</b>, credits, story details, or other details for that one issue.",
                    screenshotTitle: "Edit action in the issue menu",
                    screenshotHint: ""
                },
                {
                    key: "edit_one_series",
                    label: "How do I edit series details?",
                    bodyHtml: "Use this path when you want to change series-level details such as <b>series name</b>, <b>volume</b>, <b>publisher</b>, <b>year</b>, <b>genres</b>, or <b>summary</b>.<br><br>You can open it in two ways:<br>&bull; select the series in <b>Library</b>, open the <b>...</b> menu, and choose <b>Edit Series</b><br>&bull; open the same fields from the small edit buttons in <b>Series spotlight</b><br><br>Both paths edit the same series information. Use whichever feels faster in the moment.",
                    screenshotTitle: "Edit Series from the selected series menu",
                    screenshotHint: ""
                },
                {
                    key: "series_menu_actions",
                    label: "What can I do from the selected series menu?",
                    bodyHtml: "The <b>...</b> menu for the selected series in <b>Library</b> changes depending on what is selected.<br><br>If one series is selected, you can use it for actions such as:<br>&bull; <b>Add issues</b> when you want to add more files directly into that series<br>&bull; <b>Edit Series</b> when you want to change series-level details<br>&bull; <b>Delete files</b> when you want to remove the files for that series<br><br>To select several series, use <b>Ctrl + LMB</b> to add or remove one series at a time, or <b>Shift + LMB</b> to select a range.<br><br>If several series are selected, the same menu can offer bulk actions such as:<br>&bull; <b>Bulk Edit</b> when you want to apply the same series changes to several selected series<br>&bull; <b>Merge into series</b> when those selected series should become one series<br>&bull; <b>Delete selected</b> when you want to remove the files for all selected series<br><br>This menu is the main place for series-level actions before you touch the issues inside the series.",
                    screenshotTitle: "Selected series menu in Library",
                    screenshotHint: ""
                },
                {
                    key: "fill_fields_popup",
                    label: "What does Fill Fields do?",
                    bodyHtml: "A <b>Fill Fields</b> popup appears only when the app finds one clear, non-conflicting match in your local library data.<br><br><b>For one issue</b><br>The saved issue info must already match the same <b>series</b> and <b>issue number</b>. The popup can then appear if supporting fields such as <b>volume</b>, <b>title</b>, <b>publisher</b>, <b>year</b>, <b>month</b>, or <b>age rating</b> also fit and do not conflict.<br><br><b>For series details</b><br>The saved series info must match the same series and at least one supporting field such as <b>volume</b>, <b>publisher</b>, <b>year</b>, <b>month</b>, or <b>age rating</b>.<br><br>If the saved data conflicts with what is already in the form, or if there is no one clear best match, the popup does not appear.<br><br>If you choose <b>Fill Fields</b>, only the remaining empty fields are filled automatically. The values you already entered manually stay as they are. Use <b>Keep Current</b> when you want to save only what is already in the form.",
                    screenshotTitle: "Fill Fields popup for saved issue or series info",
                    screenshotHint: ""
                },
                {
                    key: "replace_issue",
                    label: "How do I replace one issue in a series?",
                    bodyHtml: "<b>Replace</b> keeps the existing issue in your library and replaces its current file with the new one. Use it when the new file is a corrected or better copy of the same issue.<br><br>This updates the current issue instead of creating a separate one.",
                    screenshotTitle: "Replace action in the issue menu",
                    screenshotHint: ""
                },
                {
                    key: "last_import",
                    label: "What is Last Import?",
                    bodyHtml: "<b><i>Last import</i></b> is a quick filter in <b>Library</b> that shows the most recent import session. Use it when you want to quickly find issues from the latest import session again.<br><br>Do not treat it as a permanent reading shelf. After restart, it may no longer contain the previous import session. For long-term access, open the series from <b>Library</b>."
                },
            ]
        },
        {
            key: "reader",
            label: "Reader",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-reader-settings.svg",
            leadHtml: "",
            subsections: [
                {
                    key: "reader_overview",
                    label: "Reader interface overview",
                    bodyHtml: "Open any issue from <b>Issues</b> to start reading.<br><br>The reader has four main areas:<br>&bull; the <b>Top bar</b> with issue title and icon buttons<br>&bull; the <b>page area</b> in the middle<br>&bull; the <b>side arrows</b> for previous and next page<br>&bull; the <b>Bottom controls</b> for page list, <b>Read from start</b>, and <b>Mark as read</b><br><br>Comic Pile reopens an issue from your saved spot when progress already exists. If <b>Auto-open bookmarked page instead of last page</b> is enabled in <b>File -> Settings -> Reader</b>, a bookmark can open first.",
                    screenshotTitle: "Reader layout overview",
                    screenshotHint: ""
                },
                {
                    key: "reader_top_bar_left",
                    label: "Left side of the top bar",
                    bodyHtml: "The left side of the <b>Top bar</b> contains quick utility actions for the current issue:<br>&bull; <b>Delete page</b> permanently removes the current page file from the archive<br>&bull; <b>Info</b> opens the hotkeys popup. Shortcut: <b>I</b><br>&bull; <b>Settings</b> opens reader-related settings<br>&bull; <b>Theme</b> switches the reader between its dark and light look"
                },
                {
                    key: "reader_top_bar_center",
                    label: "Center of the top bar",
                    bodyHtml: "The center of the <b>Top bar</b> shows the current issue title. The left and right arrows beside it move to the previous or next issue in the same series when available. Shortcuts: <b>A</b> / <b>D</b>"
                },
                {
                    key: "reader_top_bar_right",
                    label: "Right side of the top bar",
                    bodyHtml: "The right side of the <b>Top bar</b> contains reading modes and quick actions:<br>&bull; <b>Manga mode</b> reverses reading direction and page navigation<br>&bull; <b>1 page</b> shows one page at a time<br>&bull; <b>2 pages</b> shows a two-page spread when possible. Pre-merged double-page images still display as their own spread. Shortcut: <b>P</b><br>&bull; <b>Fullscreen</b> expands the reader to fullscreen mode. Shortcut: <b>S</b><br>&bull; <b>Magnifier</b> enables press-and-hold zoom inside the page area. Its size can be changed in <b>File -> Settings -> Reader</b>. Shortcut: <b>Z</b><br>&bull; <b>Bookmark</b> saves or removes a bookmark for the current page. Shortcut: <b>B</b><br>&bull; <b>Favorite</b> adds or removes the current issue from <b>Favorites</b>. Shortcut: <b>F</b><br>&bull; <b>Copy</b> copies the current page as an image to the clipboard, so you can paste it into another app. Shortcut: <b>Ctrl + C</b><br>&bull; <b>Close</b> exits the reader. Shortcut: <b>Esc</b>",
                    screenshotTitle: "Reader top bar layout",
                    screenshotHint: ""
                },
                {
                    key: "reader_bottom_controls",
                    label: "Bottom controls and page navigation",
                    bodyHtml: "Use the large left and right arrows on the sides of the page area to move between pages. Shortcuts: <b>Left</b> / <b>Right</b> or <b>PgUp</b> / <b>PgDown</b><br><br>At the bottom of the reader:<br>&bull; <b>Read from start</b> clears the saved continue-reading spot and starts the issue again from the beginning. Shortcut: <b>1</b><br>&bull; <b>Mark as read</b> marks the current issue as finished in <b>Library</b>, clears its bookmark, and moves to the next issue when one is available. Shortcut: <b>M</b><br>&bull; in <b>Issues</b>, a read issue appears dimmed and shows a green circular check badge on the cover, and it is no longer used as a <b>Next unread</b> target<br>&bull; the <b>page counter</b> shows your current position and opens the page list when clicked<br><br>If <b>Manga mode</b> is enabled, the page-direction logic is reversed to match manga reading order, including <b>Left</b> / <b>Right</b> navigation.",
                    screenshotTitle: "Reader bottom controls and page list",
                    screenshotHint: ""
                },
                {
                    key: "reader_bookmarks_favorites",
                    label: "Bookmarks and Favorites",
                    bodyHtml: "<b><i>Bookmarks</i></b> save one page inside one issue. Each issue can have only one bookmark at a time.<br><br>If a bookmark exists on a page that is not currently visible, the reader shows a bookmark marker near the page area. Click it to jump back to that bookmarked page.<br><br>In <b>Issues</b>, a bookmarked issue also shows a bookmark ribbon on the cover, so you can spot it from <b>Library</b>.<br><br><b><i>Favorites</i></b> mark whole issues so you can find them again in the <b>Favorites</b> quick filter in <b>Library</b>.",
                    screenshotTitle: "Bookmark indicator and favorites",
                    screenshotHint: ""
                },
                {
                    key: "continue_next_unread",
                    label: "Continue reading and Next unread",
                    bodyHtml: "You can use <b><i>Continue reading</i></b> and <b><i>Next unread</i></b> from <b>Main menu</b>, so you do not need to open the reader first to keep going.<br><br><b><i>Continue reading</i></b> opens the issue currently used as your reading target. This usually comes from saved reading progress, and a bookmark can take priority over plain progress. Once an issue has saved progress, it can become your <b><i>Continue reading</i></b> target until you build newer progress or a bookmark in another issue.<br><br><b><i>Next unread</i></b> opens the next issue in the same series flow that is not marked as read yet. It follows the current reading target, so it is meant for moving forward through the same series instead of jumping to a random issue.",
                    screenshotTitleAfter: "Continue reading and Next unread in the Top bar"
                }
            ]
        },
        {
            key: "troubleshooting",
            label: "Troubleshooting",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-alert-triangle.svg",
            leadHtml: "",
            subsections: [
                {
                    key: "issue_does_not_open",
                    label: "The issue does not open",
                    bodyHtml: "Start with these checks:<br>&bull; make sure the issue is still visible in <b>Issues</b><br>&bull; open another issue to see whether the problem affects one file or many<br>&bull; if many issues stop opening, open <b>File -> Settings -> Library &amp; Data</b> and run <b><i>Check storage access</i></b><br><br>If only one issue fails, the problem is usually in that file. If many issues fail at once, check the current library data location first."
                },
                {
                    key: "import_failed",
                    label: "Import failed",
                    bodyHtml: "Start with these checks:<br>&bull; make sure the file type is listed in <b>What formats can I import?</b><br>&bull; make sure the archive, document, or image files open normally outside the app<br>&bull; if you are importing a folder, make sure it really contains supported page files<br>&bull; if only <b>CBR</b> fails, check the 7-Zip setup in <b>File -> Settings -> Import &amp; Archives</b><br><br>If the source file is broken, unsupported, or structured incorrectly, fix or replace it and then import it again."
                },
                {
                    key: "import_errors_popup",
                    label: "What if only one archive fails during a large import?",
                    bodyHtml: "That usually means the rest of the batch can still be fine. Review the failed file in <b>Import Errors</b>. If the other imported issues appear and open normally, the problem is usually limited to that one archive.<br><br>Retry it only after you fix or replace the source file."
                }
            ]
        },
        {
            key: "faq",
            label: "FAQ",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-popup-info.svg",
            leadHtml: "",
            subsections: [
                {
                    key: "window_size_limits",
                    label: "Why can't I make the app window much smaller?",
                    bodyHtml: "The app is designed around a minimum working size for the full interface. If the available screen area is <b>1440 x 980</b> or larger, the window does not shrink much below that layout.<br><br>If the available screen area is smaller than <b>1440 x 980</b>, the app switches to a display-constrained mode and opens maximized for that screen instead of using a smaller windowed size."
                },
                {
                    key: "critical_popup_close_block",
                    label: "Why can't I close the app while this popup is open?",
                    bodyHtml: "Some popups require a decision before the app can safely continue. While one of these critical popups is open, closing the app is temporarily blocked so that this step is not skipped by accident.<br><br>If you try to close the app anyway, the popup highlights itself in green to show that it still needs your answer first."
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

        return html
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
                                    visible: text.length > 0
                                    width: parent.width
                                    text: String(modelData.leadHtml || "")
                                    color: "#a2a2a2"
                                    textFormat: Text.RichText
                                    onLinkActivated: function(link) { dialog.openHelpLink(link) }
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
                                    width: parent.width
                                    text: dialog.formatBodyHtml(String(modelData.bodyHtml || ""))
                                    color: styleTokens.textColor
                                    textFormat: Text.RichText
                                    onLinkActivated: function(link) { dialog.openHelpLink(link) }
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.bodyTextSize
                                    wrapMode: Text.WordWrap
                                    lineHeight: dialog.bodyLineHeight
                                    lineHeightMode: Text.ProportionalHeight
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
                                    visible: contentSectionBlock.hasPostScreenshotBody
                                    width: parent.width
                                    text: dialog.formatBodyHtml(String(modelData.bodyHtmlAfterScreenshot || ""))
                                    color: styleTokens.textColor
                                    textFormat: Text.RichText
                                    onLinkActivated: function(link) { dialog.openHelpLink(link) }
                                    font.family: Qt.application.font.family
                                    font.pixelSize: dialog.bodyTextSize
                                    wrapMode: Text.WordWrap
                                    lineHeight: dialog.bodyLineHeight
                                    lineHeightMode: Text.ProportionalHeight
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
