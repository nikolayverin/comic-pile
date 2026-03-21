#pragma once

#include <QString>

namespace ComicReaderSessionOps {

struct ReaderIssueRecord {
    bool found = false;
    QString filePath;
    QString filename;
    QString series;
    QString seriesKey;
    QString title;
    int currentPage = 0;
    int bookmarkPage = 0;
    bool favoriteActive = false;
    QString error;
};

ReaderIssueRecord loadReaderIssueRecord(const QString &dbPath, int comicId);
QString saveReaderProgress(
    const QString &dbPath,
    int comicId,
    int currentPage,
    const QString &readStatus
);
QString saveReaderBookmark(
    const QString &dbPath,
    int comicId,
    int bookmarkPage
);
QString saveReaderFavorite(
    const QString &dbPath,
    int comicId,
    bool favoriteActive
);

} // namespace ComicReaderSessionOps
