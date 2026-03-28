#pragma once

#include <QString>

namespace ComicLibraryStorageMigrationState {

QString markerPath(const QString &dataRoot);
bool hasCompletedLayoutMigration(const QString &dataRoot);
bool writeCompletedLayoutMigrationMarker(const QString &dataRoot);
bool clearCompletedLayoutMigrationMarker(const QString &dataRoot);

} // namespace ComicLibraryStorageMigrationState
