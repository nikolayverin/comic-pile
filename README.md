# Comic Pile Reader

Comic Pile is a portable comic reader.
User data lives next to the app in `Database/` so app binaries can be replaced without losing library metadata.

## Data storage model

- `Database/library.db` - SQLite metadata database
- `Database/Library/` - imported comic archives (`.cbz`, `.zip`)

On first run, legacy root storage (`./library.db`, `./Library`) is migrated into `./Database` (if found).

## Qt/C++ prototype

Primary app implementation lives in `comicflow-qt/`.
Local build artifacts live in `_build/` so they do not clutter the source tree.
See:
- `comicflow-qt/README.md`
- `TODO.md`
