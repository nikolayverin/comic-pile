#pragma once

#include <QString>
#include <QVariantMap>
#include <QVector>

namespace ComicLibraryQueries {

struct ComicRecord {
    int id = 0;
    QString filePath;
    QString filename;
    QString series;
    QString volume;
    QString title;
    QString issueNumber;
    QString publisher;
    int year = 0;
    int month = 0;
    QString writer;
    QString penciller;
    QString inker;
    QString colorist;
    QString letterer;
    QString coverArtist;
    QString editor;
    QString storyArc;
    QString summary;
    QString characters;
    QString genres;
    QString ageRating;
    QString readStatus;
    int currentPage = 0;
    int bookmarkPage = 0;
    QString bookmarkAddedAt;
    bool favoriteActive = false;
    QString favoriteAddedAt;
    QString addedDate;
};

bool loadComicRecords(const QString &dbPath, QVector<ComicRecord> &rowsOut, QString &errorText);
QVariantMap loadComicMetadata(const QString &dbPath, int comicId);
QVariantMap seriesMetadataForKey(const QString &dbPath, const QString &seriesKey);
QString setSeriesMetadataForKey(const QString &dbPath, const QString &seriesKey, const QVariantMap &values);
QString removeSeriesMetadataForKey(const QString &dbPath, const QString &seriesKey);

} // namespace ComicLibraryQueries
