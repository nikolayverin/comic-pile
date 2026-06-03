# Comic Pile

Comic Pile is a portable Windows app for building, organizing, and reading a local comics library.

It is a classic Windows utility for comic collectors: local-first, portable, and built around files the user already owns.

It is designed around a simple flow:
- add comic files from your computer
- keep them in one local library
- browse issues visually
- mark series with optional color tags
- edit series and issue details when needed
- open issues in a focused reader
- update the portable app without rebuilding the library

## Current app highlights

- local-library workflow
- issue and series metadata editing
- optional series color tags and sidebar filtering
- built-in reader with bookmarks, favorites, continue reading, and next unread
- full in-app `Help`, `Quick tour`, and `What's new`
- in-app update flow with `Check for updates`, `Update available`, `Downloading update`, and `Install update`
- lightweight built-in update packages that avoid downloading the starter library again
- responsive import flow that lets you browse or read existing library content while import continues
- bundled startup demo library with 2 public-domain series and 5 issues
- portable release package with the library stored next to the app in `Database/`
- bundled 7-Zip and DjVu support

## Portable app behavior

Comic Pile is distributed as a portable Windows `.zip` app.

That means:
- no installer is required
- the app can be unpacked and launched directly
- the bundled starter library lives next to the app in `Database/`
- app settings are stored in `ComicPile.ini` next to the app
- future portable updates are designed to replace app files while keeping `Database/` and `ComicPile.ini` in place
- full release archives include the starter `Database`; in-app update archives intentionally do not

## Demo library

Comic Pile ships with a small starter library so a new user can browse and read immediately after launch.

Current starter library:
- `Popular Comics`
- `Space Action`
- 5 bundled public-domain issues total

Bundled public-domain comics attribution:
- Courtesy of ComicBookPlus.Com

## Bug reports

Bug reports go through GitHub Issues.

Useful report details:
- what happened
- what you expected
- how to reproduce it
- Windows version
- Comic Pile version from `About`

## Build from source

The working Qt/C++ application lives in `comicflow-qt/`.

Local build notes currently live in:
- `comicflow-qt/README.md`

## Project status

Comic Pile is early public-release software.

The current work is focused on:
- stabilizing the portable Windows release
- improving the reader and library workflow
- keeping local library data predictable during app updates
