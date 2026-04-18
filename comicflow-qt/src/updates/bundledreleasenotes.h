#pragma once

#include <QString>
#include <QVariantList>

QString bundledReleaseNotesTextForVersion(const QString &version);
QVariantList bundledReleaseNotesEntries(const QString &currentVersion);
