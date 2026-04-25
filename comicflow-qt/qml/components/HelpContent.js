.pragma library

var sections = [
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
        },
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
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/09-issue-edit.png",
                    screenshotTitle: "Edit action in the issue menu",
                    screenshotHint: ""
                },
                {
                    key: "edit_one_series",
                    label: "How do I edit series details?",
                    bodyHtml: "Use this path when you want to change series-level details such as <b>series name</b>, <b>volume</b>, <b>publisher</b>, <b>year</b>, <b>genres</b>, or <b>summary</b>.<br><br>You can open it in two ways:<br>&bull; select the series in <b>Library</b>, open the <b>...</b> menu, and choose <b>Edit Series</b><br>&bull; open the same fields from the small edit buttons in <b>Series spotlight</b><br><br>Both paths edit the same series information. Use whichever feels faster in the moment.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/10-series-edit.png",
                    screenshotTitle: "Edit Series from the selected series menu",
                    screenshotHint: ""
                },
                {
                    key: "series_menu_actions",
                    label: "What can I do from the selected series menu?",
                    bodyHtml: "The <b>...</b> menu for the selected series in <b>Library</b> changes depending on what is selected.<br><br>If one series is selected, you can use it for actions such as:<br>&bull; <b>Add issues</b> when you want to add more files directly into that series<br>&bull; <b>Edit Series</b> when you want to change series-level details<br>&bull; <b>Delete files</b> when you want to remove the files for that series<br><br>To select several series, use <b>Ctrl + LMB</b> to add or remove one series at a time, or <b>Shift + LMB</b> to select a range.<br><br>If several series are selected, the same menu can offer bulk actions such as:<br>&bull; <b>Bulk Edit</b> when you want to apply the same series changes to several selected series<br>&bull; <b>Merge into series</b> when those selected series should become one series<br>&bull; <b>Delete selected</b> when you want to remove the files for all selected series<br><br><b>Merge into series</b> combines the selected series into the first selected one. Its series details are used as the starting values in the merge dialog, so select the target series first when you want to keep its series fields.<br><br>This menu is the main place for series-level actions before you touch the issues inside the series."
                },
                {
                    key: "fill_fields_popup",
                    label: "Can Comic Pile autofill issue or series data that was added before?",
                    bodyHtml: "Yes. If issue or series data was already saved in your library before, Comic Pile can offer to autofill it when you add that issue or series again and save the form.<br><br>This usually helps after you previously filled in the data, later removed that issue or series, and then added it again. The popup appears only when the app finds one clear saved match and the saved data does not conflict with what is already entered in the current form.<br><br><b>For issue details</b><br>The same <b>Series</b> and <b>Issue</b> must match first. The app then checks support fields such as <b>Volume</b>, <b>Publisher</b>, and <b>Year</b>. <b>Title</b>, <b>Month</b>, and <b>Age rating</b> can help refine the match, but they do not have to match first.<br><br><b>For series details</b><br>The same <b>Series</b> must match first. The popup then needs at least one supporting match in <b>Volume</b>, <b>Publisher</b>, <b>Year</b>, <b>Month</b>, or <b>Age rating</b>. <b>Series title</b>, <b>Summary</b>, and <b>Genres</b> do not trigger the popup by themselves, but they can still be filled after a match is found.<br><br>If you choose <b>Fill from library</b>, only the remaining empty fields are filled automatically. If you choose <b>Keep current values</b>, the form is saved as it is and those current values become the saved source for future autofill.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/11-fill-fields.png",
                    screenshotTitle: "Fill Fields popup for saved issue or series info",
                    screenshotHint: ""
                },
                {
                    key: "replace_issue",
                    label: "How do I replace one issue in a series?",
                    bodyHtml: "<b>Replace</b> keeps the existing issue in your library and replaces its current source with a new one. Use it when the new source is a corrected or better copy of the same issue.<br><br>When you choose <b>Replace</b>, Comic Pile first asks what kind of source you want to use: an archive file or a folder of ordered page images.<br><br>This updates the current issue instead of creating a separate one.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/11-replace.png",
                    screenshotTitle: "Replace action in the issue menu",
                    screenshotHint: ""
                },
                {
                    key: "last_import",
                    label: "What is Last Import?",
                    bodyHtml: "<b><i>Last import</i></b> is a quick filter in <b>Library</b> that shows the most recent import session. Use it when you want to quickly find issues from the latest import session again.<br><br>Do not treat it as a permanent reading shelf. After restart, it may no longer contain the previous import session. For long-term access, open the series from <b>Library</b>.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/11-last-imported.png",
                    screenshotTitle: "Last import quick filter in Library",
                    screenshotHint: ""
                },
            ]
        },
        {
            key: "updating_app",
            label: "Updating Comic Pile",
            iconSource: "qrc:/qt/qml/ComicPile/assets/icons/icon-download.svg",
            leadHtml: "Use the built-in update flow to check for a newer portable release, read what changed, download it inside the app, and install it without replacing your current library data.",
            subsections: [
                {
                    key: "check_for_updates",
                    label: "How do I check for updates?",
                    bodyHtml: "Open <b>Help -> About</b>, then press <b>Check for updates</b> in the <b>Updates</b> area.<br><br>If a newer release is found, Comic Pile opens the <b>Update available</b> popup. If no newer release is found, the same area shows that you are already up to date."
                },
                {
                    key: "automatic_update_checks",
                    label: "Does Comic Pile check for updates automatically?",
                    bodyHtml: "Yes. Comic Pile can check for updates automatically while you use the app, so a newer release can be detected without a manual check every time.<br><br>If you prefer to control this yourself, open <b>File -> Settings -> General</b> and turn off <b>Automatically check for updates</b>.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/22-auto-check-for-updates.png",
                    screenshotTitle: "Automatically check for updates setting",
                    bodyHtmlAfterScreenshot: "Turning that option off stops automatic update checks, but you can still use <b>Check for updates</b> in <b>About</b> whenever you want to check manually.",
                    screenshotSourceAfter: "qrc:/qt/qml/ComicPile/assets/ui/help/23-check-for-updatet.png",
                    screenshotTitleAfter: "Check for updates in About"
                },
                {
                    key: "view_update_details",
                    label: "What does the Update available popup show?",
                    bodyHtml: "The <b>Update available</b> popup shows the latest release label and its release notes under <b>What's new</b>.<br><br>Use <b>Later</b> if you only want to review it now. Use <b>Download update</b> when you want Comic Pile to download the portable update package for you.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/19-update-available.png",
                    screenshotTitle: "Update available popup"
                },
                {
                    key: "whats_new_meaning",
                    label: "What is What's new?",
                    bodyHtml: "<b>Help -> What's new</b> shows the bundled patch notes for the version of Comic Pile you currently have installed.<br><br>If an update is already known, the <b>Update available</b> popup also has its own <b>What's new</b> area for that newer release. In short: the Help entry is for your current build, while the update popup is for the available newer build."
                },
                {
                    key: "download_install_flow",
                    label: "How does download and install work?",
                    bodyHtml: "After you press <b>Download update</b>, Comic Pile opens the <b>Downloading update</b> popup and downloads the portable release package into a temporary location.<br><br>When the download finishes, the <b>Install update</b> button becomes available. Pressing <b>Install update</b> starts the update right away: Comic Pile closes, applies the downloaded update over the current app folder, and then starts again automatically.<br><br>This does not wait for some later launch. The install step happens when you press <b>Install update</b>.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/21-install-update.png",
                    screenshotTitle: "Install update button after download"
                },
                {
                    key: "library_data_kept",
                    label: "Will my library data stay in place?",
                    bodyHtml: "Yes. The built-in update flow keeps your current <b>Database</b> folder and <b>ComicPile.ini</b> settings file in place during the app update, so updating Comic Pile by itself does not replace your library data or app settings."
                },
                {
                    key: "update_errors",
                    label: "What if download or install fails?",
                    bodyHtml: "If the download fails, first try the download again from the update popup. Temporary network problems can interrupt the package download.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/20-downloading-failed.png",
                    screenshotTitle: "Download failed popup",
                    bodyHtmlAfterScreenshot: "If the install step cannot finish after Comic Pile closes, first try the update again. If Comic Pile still cannot complete the built-in update, download the latest portable release manually from <a href=\"https://github.com/nikolayverin/comic-pile/releases/latest\" style=\"color:#78b7ff; text-decoration:underline;\">GitHub Releases</a>.<br><br>For a manual portable update, close Comic Pile, extract the latest archive, and replace the app files in the current app folder with the new ones. Keep your existing <b>Database</b> folder and <b>ComicPile.ini</b> file in place instead of replacing them from the archive.<br><br>After a normal file replacement, your library data and app settings should stay available.<br><br>If your library data is stored next to <b>Comic Pile.exe</b>, Comic Pile should usually find it again automatically.<br><br>If your library data was moved to a different location, update the app in the same app folder so the existing <b>ComicPile.ini</b> file stays in place. If you already extracted the app into a new folder, copy <b>ComicPile.ini</b> from the previous app folder so Comic Pile keeps the saved path to that external library data and app settings."
                }
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
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/12-reader.png",
                    screenshotTitle: "Reader layout overview",
                    screenshotHint: ""
                },
                {
                    key: "reader_top_bar_left",
                    label: "Left side of the top bar",
                    bodyHtml: "The left side of the <b>Top bar</b> contains quick utility actions for the current issue:<br>&bull; <b>Delete page</b> permanently removes the current page file from the archive<br>&bull; <b>Info</b> opens the hotkeys popup. Shortcut: <b>I</b><br>&bull; <b>Settings</b> opens reader-related settings<br>&bull; <b>Theme</b> switches the reader between its dark and light look",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/13-reader-top-bar-1.png",
                    screenshotTitle: "Left side of the Reader top bar",
                    screenshotHint: ""
                },
                {
                    key: "reader_top_bar_center",
                    label: "Center of the top bar",
                    bodyHtml: "The center of the <b>Top bar</b> shows the current issue title. The left and right arrows beside it move to the previous or next issue in the same series when available. Shortcuts: <b>A</b> / <b>D</b>",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/14-reader-top-bar-2.png",
                    screenshotTitle: "Center of the Reader top bar",
                    screenshotHint: ""
                },
                {
                    key: "reader_top_bar_right",
                    label: "Right side of the top bar",
                    bodyHtml: "The right side of the <b>Top bar</b> contains reading modes and quick actions:<br>&bull; <b>Manga mode</b> reverses reading direction and page navigation<br>&bull; <b>1 page</b> shows one page at a time<br>&bull; <b>2 pages</b> shows a two-page spread when possible. Pre-merged double-page images still display as their own spread. Shortcut: <b>P</b><br>&bull; <b>Fullscreen</b> expands the reader to fullscreen mode. Shortcut: <b>S</b><br>&bull; <b>Magnifier</b> enables press-and-hold zoom inside the page area. Its size can be changed in <b>File -> Settings -> Reader</b>. Shortcut: <b>Z</b><br>&bull; <b>Bookmark</b> saves or removes a bookmark for the current page. Shortcut: <b>B</b><br>&bull; <b>Favorite</b> adds or removes the current issue from <b>Favorites</b>. Shortcut: <b>F</b><br>&bull; <b>Copy</b> copies the current page as an image to the clipboard, so you can paste it into another app. Shortcut: <b>Ctrl + C</b><br>&bull; <b>Close</b> exits the reader. Shortcut: <b>Esc</b>",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/15-reader-top-bar-3.png",
                    screenshotTitle: "Right side of the Reader top bar",
                    screenshotHint: ""
                },
                {
                    key: "reader_bottom_controls",
                    label: "Bottom controls and page navigation",
                    bodyHtml: "Use the large left and right arrows on the sides of the page area to move between pages. Shortcuts: <b>Left</b> / <b>Right</b> or <b>PgUp</b> / <b>PgDown</b><br><br>At the bottom of the reader:<br>&bull; <b>Read from start</b> clears the saved continue-reading spot and starts the issue again from the beginning. Shortcut: <b>1</b><br>&bull; <b>Mark as read</b> marks the current issue as finished in <b>Library</b>, clears its bookmark, and moves to the next issue when one is available. Shortcut: <b>M</b><br>&bull; in <b>Issues</b>, a read issue appears dimmed and shows a green circular check badge on the cover, and it is no longer used as a <b>Next unread</b> target<br>&bull; the <b>page counter</b> shows your current position and opens the page list when clicked<br><br>If <b>Manga mode</b> is enabled, the page-direction logic is reversed to match manga reading order, including <b>Left</b> / <b>Right</b> navigation.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/16-reader-bottom-bar.png",
                    screenshotTitle: "Reader bottom controls and page list",
                    screenshotHint: ""
                },
                {
                    key: "reader_bookmarks_favorites",
                    label: "Bookmarks and Favorites",
                    bodyHtml: "<b><i>Bookmarks</i></b> save one page inside one issue. Each issue can have only one bookmark at a time.<br><br>If a bookmark exists on a page that is not currently visible, the reader shows a bookmark marker near the page area. Click it to jump back to that bookmarked page.<br><br>In <b>Issues</b>, a bookmarked issue also shows a bookmark ribbon on the cover, so you can spot it from <b>Library</b>.<br><br><b><i>Favorites</i></b> mark whole issues so you can find them again in the <b>Favorites</b> quick filter in <b>Library</b>.",
                    screenshotSource: "qrc:/qt/qml/ComicPile/assets/ui/help/17-series-bookmark.png",
                    screenshotTitle: "Bookmark indicator",
                    screenshotHint: ""
                },
                {
                    key: "continue_next_unread",
                    label: "Continue reading and Next unread",
                    bodyHtml: "You can use <b><i>Continue reading</i></b> and <b><i>Next unread</i></b> from <b>Main menu</b>, so you do not need to open the reader first to keep going.<br><br><b><i>Continue reading</i></b> opens the issue currently used as your reading target. This usually comes from saved reading progress, and a bookmark can take priority over plain progress. Once an issue has saved progress, it can become your <b><i>Continue reading</i></b> target until you build newer progress or a bookmark in another issue.<br><br><b><i>Next unread</i></b> opens the next issue in the same series flow that is not marked as read yet. It follows the current reading target, so it is meant for moving forward through the same series instead of jumping to a random issue.",
                    screenshotSourceAfter: "qrc:/qt/qml/ComicPile/assets/ui/help/18-continue-reading.png",
                    screenshotTitleAfter: "Continue reading and Next unread in the Main menu"
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
                },
                {
                    key: "bug_reports",
                    label: "How do I report a bug?",
                    bodyHtml: "If you find a bug, please report it in <a href=\"https://github.com/nikolayverin/comic-pile/issues\" style=\"color:#78b7ff; text-decoration:underline;\">GitHub Issues</a>. A GitHub account is required to create a report.<br><br>Useful details include: what happened, what you expected, how to reproduce it, your Windows version, and your Comic Pile version from <b>About</b>."
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

function helpSections() {
    return sections
}
