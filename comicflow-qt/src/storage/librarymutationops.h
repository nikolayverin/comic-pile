#pragma once

#include <QHash>
#include <QSet>
#include <QString>
#include <QVector>

namespace ComicLibraryMutationOps {

struct BulkMetadataRuntimeRow {
    int id = 0;
    QString filePath;
    QString series;
};

struct BulkMetadataUpdatePlan {
    QVector<int> ids;

    bool applySeries = false;
    bool applyVolume = false;
    bool applyTitle = false;
    bool applyIssueNumber = false;
    bool applyPublisher = false;
    bool applyYear = false;
    bool applyMonth = false;
    bool applyWriter = false;
    bool applyPenciller = false;
    bool applyInker = false;
    bool applyColorist = false;
    bool applyLetterer = false;
    bool applyCoverArtist = false;
    bool applyEditor = false;
    bool applyStoryArc = false;
    bool applySummary = false;
    bool applyCharacters = false;
    bool applyGenres = false;
    bool applyAgeRating = false;
    bool applyReadStatus = false;
    bool applyCurrentPage = false;

    QString series;
    QString volume;
    QString title;
    QString issueNumber;
    QString publisher;
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

    int parsedYear = 0;
    bool yearIsNull = false;
    int parsedMonth = 0;
    bool monthIsNull = false;
    int parsedCurrentPage = 0;
    bool currentPageIsNull = false;
};

struct BulkMetadataUpdateOutcome {
    QString error;
    QHash<int, QString> movedPathById;
    QHash<int, QString> movedFilenameById;
    QSet<QString> seriesHeroKeysToPurge;

    bool ok() const
    {
        return error.trimmed().isEmpty();
    }
};

BulkMetadataUpdateOutcome applyBulkMetadataUpdate(
    const QString &dbPath,
    const QString &dataRoot,
    const QVector<BulkMetadataRuntimeRow> &runtimeRows,
    const BulkMetadataUpdatePlan &plan
);

} // namespace ComicLibraryMutationOps
