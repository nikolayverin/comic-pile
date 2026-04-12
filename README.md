# Comic Pile

Comic Pile is a portable Windows app for building, organizing, and reading a local comics library.

It is designed around a simple flow:
- add files from your computer
- keep them in one local library
- edit series and issue details when needed
- open issues in a focused reader

## Current first-release scope

- local-library workflow
- issue and series metadata editing
- built-in reader with bookmarks, favorites, continue reading, and next unread
- bundled startup demo library with 2 public-domain series and 5 issues
- portable release package with the library stored next to the app in `Database/`

## Portable app behavior

Comic Pile is planned as a portable `.zip` app for the first public release.

That means:
- no installer is required
- the app can be unpacked and launched directly
- the bundled starter library lives next to the app in `Database/`
- later app updates can replace app files without rebuilding the library structure

## Demo library

The first public release is planned to ship with a small starter library so a new user can browse and read immediately after launch.

Current starter library direction:
- `Popular Comics`
- `Space Action`
- 5 bundled public-domain issues total

Bundled public-domain comics attribution:
- Courtesy of ComicBookPlus.Com

## Bug reports

Bug reports are planned to go through GitHub Issues once the repository and issue flow are public.

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

Comic Pile is in pre-release preparation.

The current work is focused on:
- stabilizing the first public portable release
- finishing legal/notices packaging
- preparing the public release surface and repository presentation
