# Comic Pile Qt Prototype

This folder contains the Qt/C++ rewrite foundation (`Phase A`).

## Prerequisites (Windows)
- Qt 6.5+ with MinGW x64 toolchain
- CMake 3.21+
- Ninja
- MinGW 64-bit compiler matching your Qt package (current local setup: `mingw1310_64`)

## Configure and build
```powershell
cd ..
$env:PATH = "C:\Qt\Tools\mingw1310_64\bin;C:\Qt\Tools\Ninja;$env:PATH"
& "C:\Qt\Tools\CMake_64\bin\cmake.exe" -S .\comicflow-qt -B .\_build\comicflow-qt-mingw -G Ninja `
  -DCMAKE_MAKE_PROGRAM="C:/Qt/Tools/Ninja/ninja.exe" `
  -DCMAKE_PREFIX_PATH="C:\Qt\6.10.2\mingw_64" `
  -DCMAKE_C_COMPILER="C:/Qt/Tools/mingw1310_64/bin/gcc.exe" `
  -DCMAKE_CXX_COMPILER="C:/Qt/Tools/mingw1310_64/bin/g++.exe"
& "C:\Qt\Tools\CMake_64\bin\cmake.exe" --build .\_build\comicflow-qt-mingw
```

## Run
```powershell
$env:PATH = "C:\Qt\6.10.2\mingw_64\bin;C:\Qt\Tools\mingw1310_64\bin;$env:PATH"
.\_build\comicflow-qt-mingw\comic_pile_qt.exe
```

## Smoke utility
```powershell
.\_build\comicflow-qt-mingw\comic_pile_smoke.exe
```
- Verifies `ComicInfo.xml` roundtrip (`export/sync/import merge/import replace`) on a visible `cbz/zip` issue.
- Verifies reader open/page smoke for both `cbz/zip` and `cbr` (imports first `.cbr` from `Database/Library` if needed).

## Data source notes
- The prototype reads from `Database/library.db` (same contract as Electron app).
- Optional override:
```powershell
$env:COMIC_PILE_DATA_DIR = "E:\path\to\Database"
```
- `CBR` and extended archive support use bundled `7z.exe` (copied next to the app at build time).
- Optional override with custom path:
```powershell
$env:COMIC_PILE_7ZIP_PATH = "C:\Program Files\7-Zip\7z.exe"
```
- `DJVU` import uses bundled `ddjvu.exe` from `DjVuLibre` (copied next to the app at build time).
- Optional override with custom path:
```powershell
$env:COMIC_PILE_DJVU_PATH = "C:\path\to\ddjvu.exe"
```
- Bundled `DjVuLibre` source archive for redistribution is stored at `tools/djvulibre/djvulibre-3.5.29.tar.gz` next to the app build.

## Structural ownership map
- `storedpathutils` owns storage-aware path persistence and resolution against the active data root.
- `libraryschemamanager` owns schema-version orchestration; `librarydatarepairops` owns repair/backfill steps.
- `librarystoragemigrationops` owns one-time library layout migration; `librarystoragemigrationstate` owns the completion marker.
- `datarootrelocationops` owns relocation target validation and empty-target rules; `datarootrelocationbootstrap` owns the restart-time relocation flow.
- `archivesupportutils` and `archiveprocessutils` own archive capability rules and external process execution contracts.
- `importworkflowutils` owns shared import-intent, passport, and persisted import-signal helpers used across import and replace flows.
- `librarymutationops` owns bulk metadata mutation / verification work; `ComicsListModel` stays the QML-facing facade.

## Current scope
- CMake project created
- Qt Quick window boots successfully
- Issue list is loaded from `Database/library.db` with series grouping and v2 metadata preview
- Issues are auto-grouped by normalized series title
- Metadata edit is available via pop-up modal from issue cards (schema v2 fields)
- Create issue from existing `Database/Library` file is supported (schema v2 fields)
- Import supports `.cbz`, `.zip`, `.pdf`, `.djvu`, `.djv`, `.cbr`, and additional 7-Zip-supported formats (auto-normalized to internal `.cbz`)
- 7-Zip backend is bundled with the app build; custom path override is optional
- `PDF` import uses Qt PDF and is rendered into internal page images during import
- `DJVU` import uses bundled `DjVuLibre`/`ddjvu` and is rendered into internal page images during import
- Import pipeline normalizes archives to internal `.cbz` files inside `Database/Library`
- If bundled `7z` is missing/corrupted, UI shows repair/help dialog
- `File > Add files` supports multi-file import flow
- Sidebar add zone supports drag-drop import for `.cbz/.zip/.cbr`
- Batch import runs as a queued flow with bottom-panel progress and `Retry Failed` action
- Batch import supports `Cancel Import` and failed-items dialog with per-item `Retry`/`Remove`
- Library panel has functional search/filter/sort baseline (`search`, `read status`, sort mode switch)
- Library panel includes volume filter for selected series (`series + volume` grouping path)
- Model sorting applies natural ordering for `volume` and `issue` values (e.g., `2` before `10`)
- Metadata edit/create/bulk flows cover v2 story/category fields (`story arc`, `summary`, `characters`, `genres`, `age rating`)
- Search indexing includes story/category fields in addition to core metadata and credits
- Reader page loading has async request flow (`requestReaderPageAsync`) to reduce UI blocking
- Issue grid cover thumbnails are generated asynchronously and cached at `.runtime/thumb-cache`
- Reader/thumbnail cache integrity guard auto-recovers zero-byte cache files
- Delete issue (DB only or DB + archive file) is supported
- Bulk metadata edit is available for selected issues (including v2 fields)
- Base module structure ready for next phases (`storage`, `archive`, `ui`, `core`)
