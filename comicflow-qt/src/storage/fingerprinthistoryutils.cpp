#include "storage/fingerprinthistoryutils.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/libraryschemamanager.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUrl>
#include <QUuid>
#include <QVector>

namespace {

QString normalizeInputFilePath(const QString &rawInput)
{
    QString input = rawInput.trimmed();
    if (input.isEmpty()) return {};

    if ((input.startsWith('"') && input.endsWith('"')) || (input.startsWith('\'') && input.endsWith('\''))) {
        input = input.mid(1, input.length() - 2).trimmed();
    }

    const QUrl url = QUrl::fromUserInput(input);
    if (url.isValid() && url.isLocalFile()) {
        return QDir::toNativeSeparators(url.toLocalFile());
    }

    return QDir::toNativeSeparators(input);
}

} // namespace

namespace ComicFingerprintHistory {

bool FingerprintSnapshot::isValid() const
{
    return !sha1.trimmed().isEmpty() && sizeBytes > 0;
}

bool computeFileFingerprint(const QString &filePath, FingerprintSnapshot &fingerprintOut, QString &errorText)
{
    fingerprintOut = {};
    errorText.clear();

    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        errorText = QStringLiteral("Fingerprint path is empty.");
        return false;
    }

    QFile file(normalizedPath);
    if (!file.open(QIODevice::ReadOnly)) {
        errorText = QStringLiteral("Failed to open file for fingerprinting: %1").arg(normalizedPath);
        return false;
    }

    QCryptographicHash hash(QCryptographicHash::Sha1);
    qint64 totalBytes = 0;
    while (!file.atEnd()) {
        const QByteArray chunk = file.read(1024 * 1024);
        if (chunk.isEmpty() && file.error() != QFileDevice::NoError) {
            errorText = QStringLiteral("Failed to read file for fingerprinting: %1").arg(normalizedPath);
            file.close();
            return false;
        }
        if (!chunk.isEmpty()) {
            hash.addData(chunk);
            totalBytes += chunk.size();
        }
    }
    file.close();

    if (totalBytes < 1) {
        errorText = QStringLiteral("Fingerprint source is empty: %1").arg(normalizedPath);
        return false;
    }

    fingerprintOut.sha1 = QString::fromLatin1(hash.result().toHex());
    fingerprintOut.sizeBytes = totalBytes;
    return true;
}

bool loadFingerprintSnapshotFromValues(
    const QVariantMap &values,
    const QString &sha1Key,
    const QString &sizeKey,
    FingerprintSnapshot &fingerprintOut)
{
    fingerprintOut = {};

    const QString sha1 = values.value(sha1Key).toString().trimmed().toLower();
    if (sha1.isEmpty()) {
        return false;
    }

    bool sizeOk = false;
    const qint64 sizeBytes = values.value(sizeKey).toLongLong(&sizeOk);
    if (!sizeOk || sizeBytes < 1) {
        return false;
    }

    fingerprintOut.sha1 = sha1;
    fingerprintOut.sizeBytes = sizeBytes;
    return true;
}

void appendFingerprintHistoryEntry(
    QVector<FingerprintHistoryEntrySpec> &entries,
    int comicId,
    const QString &seriesKey,
    const QString &eventType,
    const QString &sourceType,
    const QString &fingerprintOrigin,
    const FingerprintSnapshot &fingerprint,
    const QString &entryLabel)
{
    if (!fingerprint.isValid()) {
        return;
    }

    FingerprintHistoryEntrySpec entry;
    entry.comicId = comicId;
    entry.seriesKey = seriesKey.trimmed();
    entry.eventType = eventType.trimmed().toLower();
    entry.sourceType = sourceType.trimmed().toLower();
    entry.fingerprintOrigin = fingerprintOrigin.trimmed().toLower();
    entry.fingerprintSha1 = fingerprint.sha1.trimmed().toLower();
    entry.fingerprintSizeBytes = fingerprint.sizeBytes;
    entry.entryLabel = entryLabel.trimmed();
    entries.push_back(entry);
}

QString insertFingerprintHistoryEntries(
    const QString &dbPath,
    const QVector<FingerprintHistoryEntrySpec> &entries,
    QVariantList *insertedIdsOut)
{
    if (insertedIdsOut) {
        insertedIdsOut->clear();
    }
    if (entries.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_fingerprint_history_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    if (!db.open()) {
        return QStringLiteral("Failed to open DB for fingerprint history: %1").arg(db.lastError().text());
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureFileFingerprintHistoryTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    if (!db.transaction()) {
        const QString error = QStringLiteral("Failed to start fingerprint history transaction: %1").arg(db.lastError().text());
        db.close();
        return error;
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral(
            "INSERT INTO file_fingerprint_history ("
            "comic_id, series_key, event_type, source_type, "
            "fingerprint_origin, fingerprint_sha1, fingerprint_size_bytes, entry_label"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
    );

    for (const FingerprintHistoryEntrySpec &entry : entries) {
        query.addBindValue(entry.comicId);
        query.addBindValue(entry.seriesKey);
        query.addBindValue(entry.eventType);
        query.addBindValue(entry.sourceType);
        query.addBindValue(entry.fingerprintOrigin);
        query.addBindValue(entry.fingerprintSha1);
        query.addBindValue(entry.fingerprintSizeBytes);
        query.addBindValue(entry.entryLabel);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to write fingerprint history: %1").arg(query.lastError().text());
            db.rollback();
            db.close();
            return error;
        }
        if (insertedIdsOut) {
            insertedIdsOut->push_back(query.lastInsertId());
        }
        query.finish();
    }

    if (!db.commit()) {
        const QString error = QStringLiteral("Failed to commit fingerprint history: %1").arg(db.lastError().text());
        db.rollback();
        db.close();
        return error;
    }

    db.close();
    return {};
}

} // namespace ComicFingerprintHistory
