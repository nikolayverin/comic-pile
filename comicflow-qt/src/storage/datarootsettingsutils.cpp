#include "storage/datarootsettingsutils.h"
#include "storage/storedpathutils.h"

#include <QCoreApplication>
#include <QDir>
#include <QSettings>
#include <QtGlobal>

namespace {

QString dataRootOverrideSettingsKey()
{
    return QStringLiteral("AppSettings/libraryDataRootPath");
}

QString pendingDataRootRelocationSettingsKey()
{
    return QStringLiteral("AppSettings/libraryDataRelocationPendingPath");
}

QSettings relocationSettingsStore()
{
    return QSettings(
        QSettings::IniFormat,
        QSettings::UserScope,
        QStringLiteral("ComicPile"),
        QStringLiteral("ComicPile")
    );
}

} // namespace

namespace ComicDataRootSettings {

QString normalizePathInput(const QString &rawInput)
{
    return ComicStoragePaths::normalizePathInput(rawInput);
}

QString normalizedFolderPath(const QString &rawPath)
{
    const QString normalized = normalizePathInput(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }

    return QDir::cleanPath(QDir::fromNativeSeparators(normalized));
}

QString persistedFolderPathForDisplay(const QString &rawPath)
{
    const QString normalized = normalizedFolderPath(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }

    return QDir::toNativeSeparators(normalized);
}

QString configuredDataRootOverridePath()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(dataRootOverrideSettingsKey()).toString());
}

QString pendingDataRootRelocationPath()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(pendingDataRootRelocationSettingsKey()).toString());
}

QString resolveActiveDataRootPath()
{
    const QString envValuePrimary = qEnvironmentVariable("COMIC_PILE_DATA_DIR").trimmed();
    if (!envValuePrimary.isEmpty()) {
        return QDir(envValuePrimary).absolutePath();
    }

    const QString envValueLegacy = qEnvironmentVariable("COMICFLOW_DATA_DIR").trimmed();
    if (!envValueLegacy.isEmpty()) {
        return QDir(envValueLegacy).absolutePath();
    }

    const QString configuredOverride = configuredDataRootOverridePath();
    if (!configuredOverride.isEmpty()) {
        return QDir(configuredOverride).absolutePath();
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    const QStringList candidates = {
        QDir(appDir).filePath(QStringLiteral("Database")),
        QDir(appDir).filePath(QStringLiteral("../Database")),
        QDir(appDir).filePath(QStringLiteral("../../Database")),
        QDir(appDir).filePath(QStringLiteral("../../../Database")),
        QDir(currentDir).filePath(QStringLiteral("Database")),
        QDir(currentDir).filePath(QStringLiteral("../Database")),
        QDir(currentDir).filePath(QStringLiteral("../../Database")),
    };

    for (const QString &candidate : candidates) {
        const QString found = ComicStoragePaths::absoluteExistingDirPath(candidate);
        if (!found.isEmpty()) {
            return found;
        }
    }

    return QDir(appDir).filePath(QStringLiteral("Database"));
}

bool writeConfiguredDataRootOverridePath(const QString &rawPath)
{
    QSettings settings = relocationSettingsStore();
    settings.setValue(dataRootOverrideSettingsKey(), persistedFolderPathForDisplay(rawPath));
    settings.sync();
    return settings.status() == QSettings::NoError;
}

bool writePendingDataRootRelocationPath(const QString &rawPath, QString &errorText)
{
    errorText.clear();

    QSettings settings = relocationSettingsStore();
    settings.setValue(
        pendingDataRootRelocationSettingsKey(),
        persistedFolderPathForDisplay(rawPath)
    );
    settings.sync();
    if (settings.status() != QSettings::NoError) {
        if (settings.status() == QSettings::AccessError) {
            errorText = QStringLiteral(
                "Could not schedule the new library data location because the app could not write its transfer request to settings storage."
            );
        } else {
            errorText = QStringLiteral(
                "Could not schedule the new library data location because the app could not update its settings storage."
            );
        }
        return false;
    }

    return true;
}

bool clearPendingDataRootRelocationPath()
{
    QSettings settings = relocationSettingsStore();
    settings.remove(pendingDataRootRelocationSettingsKey());
    settings.sync();
    return settings.status() == QSettings::NoError;
}

bool hasExternalDataRootOverride()
{
    return !qEnvironmentVariable("COMIC_PILE_DATA_DIR").trimmed().isEmpty()
        || !qEnvironmentVariable("COMICFLOW_DATA_DIR").trimmed().isEmpty();
}

bool isSameOrNestedFolderPath(const QString &leftPath, const QString &rightPath)
{
    const QString left = normalizedFolderPath(leftPath);
    const QString right = normalizedFolderPath(rightPath);
    if (left.isEmpty() || right.isEmpty()) {
        return false;
    }

    if (left.compare(right, Qt::CaseInsensitive) == 0) {
        return true;
    }

    return right.startsWith(left + QLatin1Char('/'), Qt::CaseInsensitive)
        || left.startsWith(right + QLatin1Char('/'), Qt::CaseInsensitive);
}

} // namespace ComicDataRootSettings
