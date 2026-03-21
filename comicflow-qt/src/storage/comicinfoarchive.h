#pragma once

#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

namespace ComicInfoArchive {

bool readComicInfoXmlFromArchive(
    const QString &archivePath,
    QString &xmlOut,
    QString &errorText
);
bool writeComicInfoXmlToArchive(
    const QString &archivePath,
    const QString &xml,
    QString &errorText
);
bool listImageEntriesInArchive(
    const QString &archivePath,
    QStringList &entriesOut,
    QString &errorText
);
bool extractArchiveEntryToFile(
    const QString &archivePath,
    const QString &entryName,
    const QString &outputFilePath,
    QString &errorText
);
bool listImageEntryMetricsInArchive(
    const QString &archivePath,
    QVariantList &metricsOut,
    QString &errorText
);
QVariantMap parseComicInfoXml(const QString &xml, QString &errorText);
QString buildComicInfoXmlFromMap(const QVariantMap &values);

} // namespace ComicInfoArchive
