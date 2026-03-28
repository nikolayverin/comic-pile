#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QtGlobal>

namespace ComicFingerprintHistory {

struct FingerprintSnapshot {
    QString sha1;
    qint64 sizeBytes = 0;

    bool isValid() const;
};

struct FingerprintHistoryEntrySpec {
    int comicId = 0;
    QString seriesKey;
    QString eventType;
    QString sourceType;
    QString fingerprintOrigin;
    QString fingerprintSha1;
    qint64 fingerprintSizeBytes = 0;
    QString entryLabel;
};

bool computeFileFingerprint(const QString &filePath, FingerprintSnapshot &fingerprintOut, QString &errorText);

bool loadFingerprintSnapshotFromValues(
    const QVariantMap &values,
    const QString &sha1Key,
    const QString &sizeKey,
    FingerprintSnapshot &fingerprintOut);

void appendFingerprintHistoryEntry(
    QVector<FingerprintHistoryEntrySpec> &entries,
    int comicId,
    const QString &seriesKey,
    const QString &eventType,
    const QString &sourceType,
    const QString &fingerprintOrigin,
    const FingerprintSnapshot &fingerprint,
    const QString &entryLabel);

QString insertFingerprintHistoryEntries(
    const QString &dbPath,
    const QVector<FingerprintHistoryEntrySpec> &entries,
    QVariantList *insertedIdsOut = nullptr);

} // namespace ComicFingerprintHistory
