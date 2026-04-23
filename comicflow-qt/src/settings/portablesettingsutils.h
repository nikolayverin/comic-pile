#pragma once

#include <QSettings>
#include <QString>
#include <QUrl>

namespace ComicPortableSettings {

QString settingsFilePath();
QUrl settingsFileUrl();
QSettings settingsStore();

} // namespace ComicPortableSettings
