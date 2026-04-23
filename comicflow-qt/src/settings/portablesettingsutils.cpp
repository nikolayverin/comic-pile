#include "settings/portablesettingsutils.h"

#include <QCoreApplication>
#include <QDir>

namespace ComicPortableSettings {

QString settingsFilePath()
{
    return QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("ComicPile.ini"));
}

QUrl settingsFileUrl()
{
    return QUrl::fromLocalFile(settingsFilePath());
}

QSettings settingsStore()
{
    return QSettings(settingsFilePath(), QSettings::IniFormat);
}

} // namespace ComicPortableSettings
