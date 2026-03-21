#pragma once

#include <QString>
#include <QVariantMap>

namespace ComicLibraryStorageMigration {

QVariantMap runLibraryStorageLayoutMigration(const QString &dataRoot, const QString &dbPath);

} // namespace ComicLibraryStorageMigration
