**Features**

**Updates**
- Added a visible **Check for updates** action in **About**.
- Added an **Automatically check for updates** option in **Settings -> General** while keeping manual checks available.
- Added a dedicated update flow with **Update available**, **Downloading update**, **Install update**, and in-app **What's new** surfaces.
- Added a one-time update prompt for newly detected versions and kept known available updates visible in **About** between launches.
- **Install update** now closes Comic Pile, applies the downloaded portable update over the current app folder, and keeps the existing **Database** library data and **ComicPile.ini** settings file in place.
- Added a dedicated **Updating Comic Pile** Help section that explains update checks, automatic update behavior, the download-and-install flow, and manual portable update guidance.

**Import**
- **Replace** can now use a folder of ordered page images, not only another archive file.
- Updated the **Replace** Help entry so it matches the current replace flow in the app.

**Bugfixes**

**Updates**
- Tightened the **Downloading update** popup layout and fixed the single-item progress animation so the progress bar stays visually stable and inside the rounded track.
- Fixed the failed state in **Downloading update** so the progress bar no longer keeps animating after an error and mock failed downloads no longer misleadingly run to 100% first.

**Library and Series**
- Fixed hero cover behavior in very large series so it no longer reacts badly when issue order is reversed.
- Improved hero background shuffle for very large series by limiting candidate issues and reducing quick repeat backgrounds.
- Fixed temporary shuffled hero preview files so they are cleared when the related series is deleted.
- Fixed issue cover cache so moving the library data folder does not force covers to regenerate just because the absolute path changed.
- Fixed the draggable issue-grid scrollbar thumb so it works properly again.
- Fixed ordinary series in the sidebar so they no longer always show **Vol. 1** when that value is only a default technical volume.

**Metadata**
- Fixed imported issue titles so filenames that only repeat the series name and issue number no longer fill the **Title** field.
- Fixed issue numbers so normal values no longer keep technical zero padding such as 000, 001, or 002.
- Normalized prefixed issue numbers as well, so values such as **Annual 001** are now kept in a cleaner form like **Annual 1**.
