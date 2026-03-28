#include "storage/datarootrelocationops.h"

#include "storage/datarootsettingsutils.h"

#include <QDir>
#include <QFileInfo>

namespace ComicDataRootRelocationOps {

QString validateScheduledTarget(const QString &currentDataRoot, const QString &targetPath)
{
    if (ComicDataRootSettings::hasExternalDataRootOverride()) {
        return QStringLiteral(
            "Library data location is currently forced by an external launch override. Remove that override before changing it here."
        );
    }

    const QString normalizedCurrent = ComicDataRootSettings::normalizedFolderPath(currentDataRoot);
    const QString normalizedTarget = ComicDataRootSettings::normalizedFolderPath(targetPath);
    if (normalizedTarget.isEmpty()) {
        return QStringLiteral("Choose a new folder for library data.");
    }
    if (normalizedCurrent.isEmpty()) {
        return QStringLiteral("Current library data location is unavailable.");
    }
    if (normalizedCurrent.compare(normalizedTarget, Qt::CaseInsensitive) == 0) {
        return QStringLiteral("Choose a different folder for library data.");
    }
    if (ComicDataRootSettings::isSameOrNestedFolderPath(normalizedCurrent, normalizedTarget)) {
        return QStringLiteral("Choose a folder outside the current library data location.");
    }

    const QFileInfo targetInfo(QDir::toNativeSeparators(normalizedTarget));
    if (targetInfo.exists() && !targetInfo.isDir()) {
        return QStringLiteral("The selected library data location is not a folder.");
    }

    if (targetInfo.exists()) {
        const QDir targetDir(targetInfo.absoluteFilePath());
        if (!targetDir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).isEmpty()) {
            return QStringLiteral("Choose an empty folder for the new library data location.");
        }
    }

    const QFileInfo currentInfo(QDir::toNativeSeparators(normalizedCurrent));
    if (!currentInfo.exists() || !currentInfo.isDir()) {
        return QStringLiteral("Current library data location is unavailable.");
    }

    return {};
}

bool ensureEmptyTarget(const QString &targetRoot, QString &errorText)
{
    const QFileInfo info(QDir::toNativeSeparators(targetRoot));
    if (info.exists() && !info.isDir()) {
        errorText = QStringLiteral("The scheduled library data location is not a folder.");
        return false;
    }

    if (info.exists()) {
        const QDir dir(info.absoluteFilePath());
        if (!dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).isEmpty()) {
            errorText = QStringLiteral("The scheduled library data location is not empty.");
            return false;
        }
        return true;
    }

    if (!QDir().mkpath(QDir::toNativeSeparators(targetRoot))) {
        errorText = QStringLiteral("Failed to create the scheduled library data folder.");
        return false;
    }
    return true;
}

} // namespace ComicDataRootRelocationOps
