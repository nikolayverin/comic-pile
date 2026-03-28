#include "storage/librarystoragemigrationstate.h"

#include "storage/startupruntimeutils.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>

namespace ComicLibraryStorageMigrationState {

QString markerPath(const QString &dataRoot)
{
    return QDir(ComicStartupRuntime::startupRuntimeDirPath(dataRoot))
        .filePath(QStringLiteral("library-storage-layout-migration-v1.done"));
}

bool hasCompletedLayoutMigration(const QString &dataRoot)
{
    return QFileInfo::exists(markerPath(dataRoot));
}

bool writeCompletedLayoutMigrationMarker(const QString &dataRoot)
{
    QSaveFile file(markerPath(dataRoot));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return false;
    }

    const QByteArray payload = QByteArrayLiteral("{\"version\":1}\n");
    if (file.write(payload) < 0) {
        file.cancelWriting();
        return false;
    }

    return file.commit();
}

bool clearCompletedLayoutMigrationMarker(const QString &dataRoot)
{
    const QString filePath = markerPath(dataRoot);
    const QFileInfo info(filePath);
    if (!info.exists() || !info.isFile()) {
        return true;
    }
    return QFile::remove(info.absoluteFilePath());
}

} // namespace ComicLibraryStorageMigrationState
