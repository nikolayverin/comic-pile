#include "storage/comicslistmodel.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/deletestagingops.h"
#include "storage/importmatching.h"
#include "storage/issuefileops.h"
#include "storage/libraryschemamanager.h"
#include "storage/readercacheutils.h"
#include "storage/readerrequestutils.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QUrl>
#include <QUuid>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

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

using DeleteFailureInfo = ComicDeleteOps::DeleteFailureInfo;
using StagedArchiveDeleteOp = ComicDeleteOps::StagedArchiveDeleteOp;

DeleteFailureInfo makeDeleteFailureInfo(
    const QString &rawPath,
    QFileDevice::FileError error,
    const QString &systemMessage
)
{
    return ComicDeleteOps::makeDeleteFailureInfo(rawPath, error, systemMessage);
}

QString formatDeleteFailureText(const DeleteFailureInfo &info)
{
    return ComicDeleteOps::formatDeleteFailureLine(info);
}

void appendWarningLine(QStringList &lines, const QString &text)
{
    const QString trimmed = text.trimmed();
    if (!trimmed.isEmpty()) {
        lines.push_back(trimmed);
    }
}

struct FingerprintSnapshot {
    QString sha1;
    qint64 sizeBytes = 0;

    bool isValid() const
    {
        return !sha1.trimmed().isEmpty() && sizeBytes > 0;
    }
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

void appendFingerprintHistoryEntry(
    QVector<FingerprintHistoryEntrySpec> &entries,
    int comicId,
    const QString &seriesKey,
    const QString &eventType,
    const QString &sourceType,
    const QString &fingerprintOrigin,
    const FingerprintSnapshot &fingerprint,
    const QString &entryLabel
)
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
    QVariantList *insertedIdsOut = nullptr
)
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

bool performStageArchiveDelete(
    const QString &filePath,
    StagedArchiveDeleteOp &opOut,
    DeleteFailureInfo &failureOut
)
{
    return ComicDeleteOps::stageArchiveDelete(filePath, opOut, failureOut);
}

bool performRollbackStagedArchiveDelete(const StagedArchiveDeleteOp &op, DeleteFailureInfo &failureOut)
{
    return ComicDeleteOps::rollbackStagedArchiveDelete(op, failureOut);
}

bool performFinalizeStagedArchiveDelete(
    const StagedArchiveDeleteOp &op,
    QString &cleanupDirPathOut,
    DeleteFailureInfo &failureOut
)
{
    return ComicDeleteOps::finalizeStagedArchiveDelete(op, cleanupDirPathOut, failureOut);
}

QString performRollbackStagedArchiveDeletes(const QVector<StagedArchiveDeleteOp> &ops)
{
    return ComicDeleteOps::rollbackStagedArchiveDeletes(ops);
}

void cleanupEmptyLibraryDirs(const QString &libraryRootPath, const QStringList &candidateDirs)
{
    ComicDeleteOps::cleanupEmptyLibraryDirs(libraryRootPath, candidateDirs);
}

} // namespace

QString ComicsListModel::deleteSeriesFiles(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return QStringLiteral("Series key is required.");

    QVector<int> idsToDelete;
    QVector<int> deletedComicIds;
    QStringList warnings;
    idsToDelete.reserve(m_rows.size());
    deletedComicIds.reserve(m_rows.size());
    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey == normalizedKey) {
            idsToDelete.push_back(row.id);
        }
    }

    if (idsToDelete.isEmpty()) {
        return QStringLiteral("No issues found for selected series.");
    }

    const QString preserveError = preserveRetainedSeriesMetadata(normalizedKey);
    if (!preserveError.isEmpty()) {
        return preserveError;
    }
    purgeSeriesHeroCacheForKey(normalizedKey);
    ComicReaderCache::purgeSeriesHeaderOverridesForKey(m_dataRoot, normalizedKey);

    QStringList errors;
    for (int comicId : idsToDelete) {
        const QString preserveIssueError = preserveRetainedIssueMetadata(comicId);
        if (!preserveIssueError.isEmpty()) {
            errors.push_back(preserveIssueError);
            continue;
        }
        QString deleteMessage;
        const bool removed = deleteComicHardInternal(comicId, deleteMessage);
        if (removed) {
            deletedComicIds.push_back(comicId);
        }
        if (!deleteMessage.isEmpty()) {
            const QString detail = QStringLiteral("Issue %1: %2").arg(comicId).arg(deleteMessage);
            if (removed) {
                warnings.push_back(detail);
            } else {
                errors.push_back(detail);
            }
        }
    }

    const QString historyCleanupError = deleteFileFingerprintHistoryForComicIds(deletedComicIds);
    if (!historyCleanupError.isEmpty()) {
        warnings.push_back(QStringLiteral("Fingerprint history cleanup failed: %1").arg(historyCleanupError));
    }

    if (!errors.isEmpty()) {
        QString result = QStringLiteral("Some issues could not be removed:\n%1").arg(errors.join('\n'));
        if (!warnings.isEmpty()) {
            result += QStringLiteral("\nWarnings:\n%1").arg(warnings.join('\n'));
        }
        return result;
    }
    if (!warnings.isEmpty()) {
        return QStringLiteral("Issues were removed with warnings:\n%1").arg(warnings.join('\n'));
    }
    return {};
}

QString ComicsListModel::deleteSeriesFilesKeepRecords(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) return QString("Series key is required.");

    QVector<int> idsToMarkMissing;
    QVector<DeleteFailureInfo> failedFiles;
    QVector<StagedArchiveDeleteOp> stagedDeletes;
    QVector<ComicIssueFileOps::ComicFilePathBinding> clearBindings;
    QStringList dirsToCleanup;
    QStringList followUpWarnings;
    QHash<int, FingerprintHistoryEntrySpec> deleteFingerprintEntriesById;

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != normalizedKey) continue;

        StagedArchiveDeleteOp stagedDelete;
        stagedDelete.comicId = row.id;
        const QString archivePath = archivePathForComicId(row.id);
        bool markMissing = true;
        if (!archivePath.isEmpty()) {
            FingerprintSnapshot deleteFingerprint;
            QString deleteFingerprintError;
            if (computeFileFingerprint(archivePath, deleteFingerprint, deleteFingerprintError)) {
                QVector<FingerprintHistoryEntrySpec> historyEntries;
                appendFingerprintHistoryEntry(
                    historyEntries,
                    row.id,
                    row.seriesGroupKey,
                    QStringLiteral("delete_keep_record"),
                    QStringLiteral("archive"),
                    QStringLiteral("library"),
                    deleteFingerprint,
                    row.filename
                );
                if (!historyEntries.isEmpty()) {
                    deleteFingerprintEntriesById.insert(row.id, historyEntries.first());
                }
            }

            DeleteFailureInfo failure;
            if (!performStageArchiveDelete(archivePath, stagedDelete, failure)) {
                markMissing = false;
                failedFiles.push_back(failure);
            }
        }

        if (markMissing) {
            idsToMarkMissing.push_back(row.id);
            stagedDeletes.push_back(stagedDelete);
            clearBindings.push_back({ row.id, QString() });
        }
    }

    if (idsToMarkMissing.isEmpty() && failedFiles.isEmpty()) {
        return QString("No issues found for selected series.");
    }

    if (!clearBindings.isEmpty()) {
        const QString applyError = ComicIssueFileOps::applyComicFilePathBindings(
            m_dbPath,
            m_dataRoot,
            clearBindings,
            QStringLiteral("delete_series_files")
        );
        if (!applyError.isEmpty()) {
            const QString rollbackWarning = performRollbackStagedArchiveDeletes(stagedDeletes);
            if (!rollbackWarning.isEmpty()) {
                return QString("%1\nRollback warning:\n%2").arg(applyError, rollbackWarning);
            }
            return applyError;
        }
    }

    QVector<int> finalRemovedIds = idsToMarkMissing;
    if (!stagedDeletes.isEmpty()) {
        QVector<ComicIssueFileOps::ComicFilePathBinding> restoreBindings;
        QSet<int> restoredIds;
        QStringList recoveryWarnings;

        for (const StagedArchiveDeleteOp &stagedDelete : stagedDeletes) {
            QString cleanupDirPath;
            DeleteFailureInfo finalizeFailure;
            if (performFinalizeStagedArchiveDelete(stagedDelete, cleanupDirPath, finalizeFailure)) {
                if (!cleanupDirPath.isEmpty()) {
                    dirsToCleanup.push_back(cleanupDirPath);
                }
                continue;
            }

            failedFiles.push_back(finalizeFailure);

            DeleteFailureInfo rollbackFailure;
            if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
                recoveryWarnings.push_back(formatDeleteFailureText(rollbackFailure));
                continue;
            }

            if (!stagedDelete.originalPath.trimmed().isEmpty()) {
                restoreBindings.push_back({ stagedDelete.comicId, stagedDelete.originalPath });
            }
            restoredIds.insert(stagedDelete.comicId);
        }

        if (!restoreBindings.isEmpty()) {
            const QString restoreError = ComicIssueFileOps::applyComicFilePathBindings(
                m_dbPath,
                m_dataRoot,
                restoreBindings,
                QStringLiteral("restore_series_files_after_delete")
            );
            if (!restoreError.isEmpty()) {
                recoveryWarnings.push_back(
                    QStringLiteral("Failed to restore DB links for recovered archives: %1").arg(restoreError)
                );
            } else {
                QVector<int> keptIds;
                keptIds.reserve(finalRemovedIds.size());
                for (int id : finalRemovedIds) {
                    if (!restoredIds.contains(id)) {
                        keptIds.push_back(id);
                    }
                }
                finalRemovedIds.swap(keptIds);
            }
        }

        cleanupEmptyLibraryDirs(QDir(m_dataRoot).filePath(QStringLiteral("Library")), dirsToCleanup);

        if (!recoveryWarnings.isEmpty()) {
            reload();
            QStringList lines;
            lines.reserve(failedFiles.size() + recoveryWarnings.size());
            for (const DeleteFailureInfo &info : failedFiles) {
                lines.push_back(formatDeleteFailureText(info));
            }
            for (const QString &warning : recoveryWarnings) {
                lines.push_back(QStringLiteral("Recovery: %1").arg(warning));
            }
            return QString("Some files could not be removed:\n%1").arg(lines.join('\n'));
        }
    } else {
        cleanupEmptyLibraryDirs(QDir(m_dataRoot).filePath(QStringLiteral("Library")), dirsToCleanup);
    }

    if (!finalRemovedIds.isEmpty()) {
        QVector<FingerprintHistoryEntrySpec> fingerprintEntries;
        for (int id : finalRemovedIds) {
            const auto found = deleteFingerprintEntriesById.constFind(id);
            if (found != deleteFingerprintEntriesById.constEnd()) {
                fingerprintEntries.push_back(found.value());
            }
        }
        const QString fingerprintHistoryError = insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, nullptr);
        if (!fingerprintHistoryError.isEmpty()) {
            appendWarningLine(followUpWarnings, QStringLiteral("Restore history update failed: %1").arg(fingerprintHistoryError));
        }

        purgeSeriesHeroCacheForKey(normalizedKey);

        for (int id : finalRemovedIds) {
            ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, id);
        }
        clearReaderRuntimeStateForComics(finalRemovedIds);

        m_lastMutationKind = QString("delete_series_files_keep_records");
        emit statusChanged();
        reload();
    }

    if (!failedFiles.isEmpty()) {
        if (finalRemovedIds.isEmpty()) {
            reload();
        }
        QStringList lines;
        lines.reserve(failedFiles.size() + followUpWarnings.size());
        for (const DeleteFailureInfo &info : failedFiles) {
            lines.push_back(formatDeleteFailureText(info));
        }
        for (const QString &warning : followUpWarnings) {
            lines.push_back(QStringLiteral("Follow-up: %1").arg(warning));
        }
        return QString("Some files could not be removed:\n%1").arg(lines.join('\n'));
    }

    if (!followUpWarnings.isEmpty()) {
        return QStringLiteral(
            "Files were removed, but follow-up cleanup was incomplete.\n%1"
        ).arg(followUpWarnings.join('\n'));
    }

    return {};
}

QString ComicsListModel::deleteSeriesKeyForComic(int comicId) const
{
    const QString liveSeriesKey = seriesGroupKeyForComicId(comicId);
    if (!liveSeriesKey.isEmpty()) {
        return liveSeriesKey;
    }

    const QVariantMap metadata = loadComicMetadata(comicId);
    if (!trimOrEmpty(metadata.value(QStringLiteral("error"))).isEmpty()) {
        return {};
    }

    const QString series = trimOrEmpty(metadata.value(QStringLiteral("series")));
    if (series.isEmpty()) {
        return {};
    }

    return ComicImportMatching::normalizeSeriesKey(series);
}

QString ComicsListModel::deleteComicFilesKeepRecord(int comicId)
{
    if (comicId < 1) return QString("Invalid issue id.");

    const QString seriesKey = deleteSeriesKeyForComic(comicId);

    QString filePath;
    {
        const QString loadError = ComicIssueFileOps::loadComicFilePath(m_dbPath, m_dataRoot, comicId, filePath);
        if (!loadError.isEmpty()) {
            return loadError;
        }
    }

    QVector<FingerprintHistoryEntrySpec> fingerprintEntries;
    if (!filePath.isEmpty()) {
        FingerprintSnapshot deleteFingerprint;
        QString deleteFingerprintError;
        if (computeFileFingerprint(filePath, deleteFingerprint, deleteFingerprintError)) {
            appendFingerprintHistoryEntry(
                fingerprintEntries,
                comicId,
                seriesKey,
                QStringLiteral("delete_keep_record"),
                QStringLiteral("archive"),
                QStringLiteral("library"),
                deleteFingerprint,
                QFileInfo(filePath).fileName().trimmed()
            );
        }
    }

    StagedArchiveDeleteOp stagedDelete;
    stagedDelete.comicId = comicId;
    if (!filePath.isEmpty()) {
        DeleteFailureInfo stageFailure;
        if (!performStageArchiveDelete(filePath, stagedDelete, stageFailure)) {
            return QString("Could not remove archive file.\n%1").arg(formatDeleteFailureText(stageFailure));
        }
    }

    const QString applyError = ComicIssueFileOps::applyComicFilePathBindings(
        m_dbPath,
        m_dataRoot,
        { { comicId, QString() } },
        QStringLiteral("delete_issue_files")
    );
    if (!applyError.isEmpty()) {
        DeleteFailureInfo rollbackFailure;
        if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
            return QString("%1\nRollback warning:\n%2")
                .arg(applyError, formatDeleteFailureText(rollbackFailure));
        }
        return applyError;
    }

    QString removedDirPath;
    DeleteFailureInfo finalizeFailure;
    if (!performFinalizeStagedArchiveDelete(stagedDelete, removedDirPath, finalizeFailure)) {
        DeleteFailureInfo rollbackFailure;
        if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
            reload();
            return QString("Could not remove archive file.\n%1\nRecovery warning:\n%2")
                .arg(formatDeleteFailureText(finalizeFailure), formatDeleteFailureText(rollbackFailure));
        }

        const QString restoreError = ComicIssueFileOps::applyComicFilePathBindings(
            m_dbPath,
            m_dataRoot,
            { { comicId, stagedDelete.originalPath } },
            QStringLiteral("restore_issue_file_after_delete")
        );
        if (!restoreError.isEmpty()) {
            reload();
            return QString("Could not remove archive file.\n%1\nRecovery warning: archive was restored on disk but DB relink failed: %2")
                .arg(formatDeleteFailureText(finalizeFailure), restoreError);
        }

        return QString("Could not remove archive file.\n%1").arg(formatDeleteFailureText(finalizeFailure));
    }

    const QString fingerprintHistoryError = insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, nullptr);
    const QString ghostCleanupError = pruneEquivalentDetachedGhostRowsForComic(comicId);
    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);
    clearReaderRuntimeStateForComic(comicId);

    m_lastMutationKind = QString("delete_issue_files_keep_record");
    emit statusChanged();
    if (!removedDirPath.isEmpty()) {
        cleanupEmptyLibraryDirs(
            QDir(m_dataRoot).filePath(QStringLiteral("Library")),
            { removedDirPath }
        );
    }
    reload();
    if (!ghostCleanupError.isEmpty() && fingerprintHistoryError.isEmpty()) {
        return QStringLiteral(
            "Archive file was removed, but cleanup of older restore duplicates failed.\n%1"
        ).arg(ghostCleanupError);
    }
    if (ghostCleanupError.isEmpty() && !fingerprintHistoryError.isEmpty()) {
        return QStringLiteral(
            "Archive file was removed, but restore history update failed.\n%1"
        ).arg(fingerprintHistoryError);
    }
    if (!ghostCleanupError.isEmpty() && !fingerprintHistoryError.isEmpty()) {
        return QStringLiteral(
            "Archive file was removed, but follow-up cleanup was incomplete.\nCleanup of older restore duplicates failed: %1\nRestore history update failed: %2"
        ).arg(ghostCleanupError, fingerprintHistoryError);
    }
    return {};
}

QString ComicsListModel::detachComicFileKeepMetadata(int comicId)
{
    if (comicId < 1) return QString("Invalid issue id.");

    const QString seriesKey = deleteSeriesKeyForComic(comicId);

    const QString updateError = ComicIssueFileOps::applyComicFilePathBindings(
        m_dbPath,
        m_dataRoot,
        { { comicId, QString() } },
        QStringLiteral("detach_issue_file")
    );
    if (!updateError.isEmpty()) {
        return updateError;
    }

    const QString ghostCleanupError = pruneEquivalentDetachedGhostRowsForComic(comicId);
    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);
    clearReaderRuntimeStateForComic(comicId);

    int removeIndex = -1;
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        if (m_rows.at(rowIndex).id == comicId) {
            removeIndex = rowIndex;
            break;
        }
    }
    if (removeIndex >= 0) {
        beginRemoveRows(QModelIndex(), removeIndex, removeIndex);
        m_rows.removeAt(removeIndex);
        endRemoveRows();
    }
    m_lastMutationKind = QString("detach_issue_file_keep_metadata");
    emit statusChanged();
    if (!ghostCleanupError.isEmpty()) {
        return QStringLiteral(
            "Issue file was detached, but cleanup of older restore duplicates failed.\n%1"
        ).arg(ghostCleanupError);
    }
    return {};
}

QString ComicsListModel::pruneEquivalentDetachedGhostRowsForComic(int comicId)
{
    if (comicId < 1) return {};

    struct DetachedGhostIdentity {
        int id = 0;
        QString filename;
        QString importOriginalFilename;
        QString importStrictFilenameSignature;
        QString importLooseFilenameSignature;
        QString seriesKey;
        QString volume;
        QString issue;
    };

    auto effectiveFilenameLabel = [](const DetachedGhostIdentity &identity) -> QString {
        const QString original = identity.importOriginalFilename.trimmed();
        if (!original.isEmpty()) {
            return original;
        }
        return identity.filename.trimmed();
    };

    auto effectiveStrictSignature = [&](const DetachedGhostIdentity &identity) -> QString {
        const QString stored = identity.importStrictFilenameSignature.trimmed();
        if (!stored.isEmpty()) {
            return stored;
        }
        const QString sourceName = effectiveFilenameLabel(identity);
        if (sourceName.isEmpty()) {
            return {};
        }
        return ComicImportMatching::normalizeFilenameSignatureStrict(sourceName);
    };

    auto effectiveLooseSignature = [&](const DetachedGhostIdentity &identity) -> QString {
        const QString stored = identity.importLooseFilenameSignature.trimmed();
        if (!stored.isEmpty()) {
            return stored;
        }
        const QString sourceName = effectiveFilenameLabel(identity);
        if (sourceName.isEmpty()) {
            return {};
        }
        return ComicImportMatching::normalizeFilenameSignatureLoose(sourceName);
    };

    auto sameTextCi = [](const QString &left, const QString &right) -> bool {
        return !left.trimmed().isEmpty()
            && !right.trimmed().isEmpty()
            && QString::compare(left.trimmed(), right.trimmed(), Qt::CaseInsensitive) == 0;
    };

    const QString connectionName = QStringLiteral("comic_pile_prune_detached_ghosts_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return openError;
    }

    DetachedGhostIdentity current;
    {
        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT "
                "COALESCE(filename, ''), "
                "COALESCE(import_original_filename, ''), "
                "COALESCE(import_strict_filename_signature, ''), "
                "COALESCE(import_loose_filename_signature, ''), "
                "COALESCE(series_key, ''), "
                "COALESCE(volume, ''), "
                "COALESCE(issue_number, issue, '') "
                "FROM comics "
                "WHERE id = ?"
            )
        );
        query.addBindValue(comicId);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to inspect restore duplicates: %1").arg(query.lastError().text());
            db.close();
            return error;
        }
        if (!query.next()) {
            db.close();
            return {};
        }

        current.id = comicId;
        current.filename = trimOrEmpty(query.value(0));
        current.importOriginalFilename = trimOrEmpty(query.value(1));
        current.importStrictFilenameSignature = trimOrEmpty(query.value(2));
        current.importLooseFilenameSignature = trimOrEmpty(query.value(3));
        current.seriesKey = trimOrEmpty(query.value(4));
        current.volume = trimOrEmpty(query.value(5));
        current.issue = trimOrEmpty(query.value(6));
    }

    const QString currentSeriesKey = current.seriesKey.trimmed();
    const QString currentIssueKey = ComicImportMatching::normalizeIssueKey(current.issue);
    const QString currentVolumeKey = normalizeVolumeKey(current.volume);
    const QString currentStrictSignature = effectiveStrictSignature(current);
    const QString currentLooseSignature = effectiveLooseSignature(current);

    if (currentSeriesKey.isEmpty() || currentIssueKey.isEmpty()) {
        db.close();
        return {};
    }

    QVector<int> duplicateIds;
    {
        QSqlQuery query(db);
        query.prepare(
            QStringLiteral(
                "SELECT "
                "id, "
                "COALESCE(filename, ''), "
                "COALESCE(import_original_filename, ''), "
                "COALESCE(import_strict_filename_signature, ''), "
                "COALESCE(import_loose_filename_signature, ''), "
                "COALESCE(volume, ''), "
                "COALESCE(issue_number, issue, '') "
                "FROM comics "
                "WHERE id <> ? "
                "AND series_key = ? "
                "AND COALESCE(file_path, '') = ''"
            )
        );
        query.addBindValue(comicId);
        query.addBindValue(currentSeriesKey);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to load restore duplicates: %1").arg(query.lastError().text());
            db.close();
            return error;
        }

        while (query.next()) {
            DetachedGhostIdentity candidate;
            candidate.id = query.value(0).toInt();
            candidate.filename = trimOrEmpty(query.value(1));
            candidate.importOriginalFilename = trimOrEmpty(query.value(2));
            candidate.importStrictFilenameSignature = trimOrEmpty(query.value(3));
            candidate.importLooseFilenameSignature = trimOrEmpty(query.value(4));
            candidate.volume = trimOrEmpty(query.value(5));
            candidate.issue = trimOrEmpty(query.value(6));

            if (ComicImportMatching::normalizeIssueKey(candidate.issue) != currentIssueKey) {
                continue;
            }
            if (normalizeVolumeKey(candidate.volume) != currentVolumeKey) {
                continue;
            }

            const bool nameMatch =
                sameTextCi(current.filename, candidate.filename)
                || sameTextCi(current.filename, candidate.importOriginalFilename)
                || sameTextCi(current.importOriginalFilename, candidate.filename)
                || sameTextCi(current.importOriginalFilename, candidate.importOriginalFilename);

            const QString candidateStrictSignature = effectiveStrictSignature(candidate);
            const QString candidateLooseSignature = effectiveLooseSignature(candidate);
            const bool signatureMatch =
                !currentStrictSignature.isEmpty()
                && !candidateStrictSignature.isEmpty()
                && currentStrictSignature == candidateStrictSignature
                && !currentLooseSignature.isEmpty()
                && !candidateLooseSignature.isEmpty()
                && currentLooseSignature == candidateLooseSignature;

            if (!nameMatch && !signatureMatch) {
                continue;
            }

            duplicateIds.push_back(candidate.id);
        }
    }

    if (duplicateIds.isEmpty()) {
        db.close();
        return {};
    }

    QStringList placeholders;
    placeholders.reserve(duplicateIds.size());
    for (int i = 0; i < duplicateIds.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery deleteHistoryQuery(db);
    deleteHistoryQuery.prepare(
        QStringLiteral("DELETE FROM file_fingerprint_history WHERE comic_id IN (%1)")
            .arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : duplicateIds) {
        deleteHistoryQuery.addBindValue(id);
    }
    if (!deleteHistoryQuery.exec()) {
        const QString error = QStringLiteral("Failed to remove fingerprint history for stale restore duplicates: %1")
            .arg(deleteHistoryQuery.lastError().text());
        db.close();
        return error;
    }

    QSqlQuery deleteQuery(db);
    deleteQuery.prepare(
        QStringLiteral("DELETE FROM comics WHERE id IN (%1)").arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : duplicateIds) {
        deleteQuery.addBindValue(id);
    }
    if (!deleteQuery.exec()) {
        const QString error = QStringLiteral("Failed to remove stale restore duplicates: %1").arg(deleteQuery.lastError().text());
        db.close();
        return error;
    }

    db.close();

    for (int id : duplicateIds) {
        ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, id);
    }
    clearReaderRuntimeStateForComics(duplicateIds);

    return {};
}

QString ComicsListModel::deleteFileAtPath(const QString &filePath)
{
    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        return QString("File path is required.");
    }

    QFile file(normalizedPath);
    if (!file.exists()) {
        ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, normalizedPath);
        return {};
    }
    if (!file.remove()) {
        const DeleteFailureInfo failure = makeDeleteFailureInfo(normalizedPath, file.error(), file.errorString());
        return QString("Failed to remove file: %1\n%2")
            .arg(QDir::toNativeSeparators(QFileInfo(normalizedPath).absoluteFilePath()), formatDeleteFailureText(failure));
    }
    ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, normalizedPath);
    cleanupEmptyLibraryDirs(
        QDir(m_dataRoot).filePath(QStringLiteral("Library")),
        { QFileInfo(normalizedPath).absolutePath() }
    );
    return {};
}

QString ComicsListModel::deleteFileFingerprintHistoryEntries(const QVariantList &entryIds)
{
    QVector<int> ids;
    ids.reserve(entryIds.size());
    for (const QVariant &value : entryIds) {
        const int id = value.toInt();
        if (id > 0) {
            ids.push_back(id);
        }
    }
    if (ids.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_delete_fingerprint_history_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureFileFingerprintHistoryTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    QStringList placeholders;
    placeholders.reserve(ids.size());
    for (int i = 0; i < ids.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral("DELETE FROM file_fingerprint_history WHERE id IN (%1)")
            .arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : ids) {
        query.addBindValue(id);
    }
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to remove fingerprint history: %1").arg(query.lastError().text());
        db.close();
        return error;
    }

    db.close();
    return {};
}

QString ComicsListModel::deleteFileFingerprintHistoryForComicIds(const QVector<int> &comicIds)
{
    QVector<int> ids;
    ids.reserve(comicIds.size());
    for (int comicId : comicIds) {
        if (comicId > 0 && !ids.contains(comicId)) {
            ids.push_back(comicId);
        }
    }
    if (ids.isEmpty()) {
        return {};
    }

    const QString connectionName = QStringLiteral("comic_pile_delete_fingerprint_history_by_comic_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);

    QString openError;
    QSqlDatabase db;
    if (!openDatabaseConnection(db, connectionName, openError)) {
        return openError;
    }

    QString schemaError;
    if (!LibrarySchemaManager::ensureFileFingerprintHistoryTable(db, schemaError)) {
        db.close();
        return schemaError;
    }

    QStringList placeholders;
    placeholders.reserve(ids.size());
    for (int i = 0; i < ids.size(); i += 1) {
        placeholders.push_back(QStringLiteral("?"));
    }

    QSqlQuery query(db);
    query.prepare(
        QStringLiteral("DELETE FROM file_fingerprint_history WHERE comic_id IN (%1)")
            .arg(placeholders.join(QStringLiteral(", ")))
    );
    for (int id : ids) {
        query.addBindValue(id);
    }
    if (!query.exec()) {
        const QString error = QStringLiteral("Failed to remove fingerprint history: %1").arg(query.lastError().text());
        db.close();
        return error;
    }

    db.close();
    return {};
}

QString ComicsListModel::deleteComic(int comicId)
{
    if (comicId < 1) return QStringLiteral("Invalid issue id.");

    const QString seriesKey = deleteSeriesKeyForComic(comicId);
    const bool deletingLastIssueInSeries = !seriesKey.isEmpty() && liveIssueCountForSeries(seriesKey) <= 1;
    if (deletingLastIssueInSeries) {
        const QString preserveError = preserveRetainedSeriesMetadata(seriesKey);
        if (!preserveError.isEmpty()) {
            return preserveError;
        }
        purgeSeriesHeroCacheForKey(seriesKey);
        ComicReaderCache::purgeSeriesHeaderOverridesForKey(m_dataRoot, seriesKey);
    }

    const QString preserveIssueError = preserveRetainedIssueMetadata(comicId);
    if (!preserveIssueError.isEmpty()) {
        return preserveIssueError;
    }

    QString deleteMessage;
    if (!deleteComicHardInternal(comicId, deleteMessage)) {
        return deleteMessage;
    }

    QStringList warnings;
    appendWarningLine(warnings, deleteMessage);
    QString historyCleanupError;
    if (deletingLastIssueInSeries) {
        historyCleanupError = deleteFileFingerprintHistoryForComicIds({ comicId });
        if (!historyCleanupError.isEmpty()) {
            appendWarningLine(
                warnings,
                QStringLiteral("Fingerprint history cleanup failed: %1").arg(historyCleanupError)
            );
        }
    }

    if (!warnings.isEmpty()) {
        if (warnings.size() == 1) {
            if (!deleteMessage.isEmpty() && historyCleanupError.isEmpty()) {
                return deleteMessage;
            }
            if (deleteMessage.isEmpty() && !historyCleanupError.isEmpty()) {
                return QStringLiteral("Issue was removed, but %1").arg(warnings.first());
            }
        }
        return QStringLiteral("Issue was removed with warnings:\n%1").arg(warnings.join('\n'));
    }

    return {};
}

QString ComicsListModel::deleteComicHard(int comicId)
{
    QString message;
    deleteComicHardInternal(comicId, message);
    return message;
}

bool ComicsListModel::deleteComicHardInternal(int comicId, QString &messageOut)
{
    messageOut.clear();
    if (comicId < 1) {
        messageOut = QStringLiteral("Invalid issue id.");
        return false;
    }

    const QString seriesKey = deleteSeriesKeyForComic(comicId);

    QString filePath;
    {
        const QString loadError = ComicIssueFileOps::loadComicFilePath(m_dbPath, m_dataRoot, comicId, filePath);
        if (!loadError.isEmpty()) {
            messageOut = loadError;
            return false;
        }
    }

    QVector<FingerprintHistoryEntrySpec> fingerprintEntries;
    if (!filePath.isEmpty()) {
        FingerprintSnapshot deleteFingerprint;
        QString deleteFingerprintError;
        if (computeFileFingerprint(filePath, deleteFingerprint, deleteFingerprintError)) {
            appendFingerprintHistoryEntry(
                fingerprintEntries,
                comicId,
                seriesKey,
                QStringLiteral("delete_hard"),
                QStringLiteral("archive"),
                QStringLiteral("library"),
                deleteFingerprint,
                QFileInfo(filePath).fileName().trimmed()
            );
        }
    }

    StagedArchiveDeleteOp stagedDelete;
    bool stagedArchiveDeletePending = false;
    if (!filePath.isEmpty()) {
        DeleteFailureInfo stageFailure;
        if (!performStageArchiveDelete(filePath, stagedDelete, stageFailure)) {
            messageOut = QStringLiteral(
                "Issue was not removed because the archive file could not be deleted.\n%1"
            ).arg(formatDeleteFailureText(stageFailure));
            return false;
        }
        stagedArchiveDeletePending = !stagedDelete.stagedPath.trimmed().isEmpty();
    }

    const QString deleteError = ComicIssueFileOps::hardDeleteComicRecord(m_dbPath, comicId);
    if (!deleteError.isEmpty()) {
        if (stagedArchiveDeletePending) {
            DeleteFailureInfo rollbackFailure;
            if (!performRollbackStagedArchiveDelete(stagedDelete, rollbackFailure)) {
                messageOut = QStringLiteral("%1\nRollback warning:\n%2")
                    .arg(deleteError, formatDeleteFailureText(rollbackFailure));
                return false;
            }
        }
        messageOut = deleteError;
        return false;
    }

    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    purgeSeriesHeroCacheForKey(seriesKey);
    clearReaderRuntimeStateForComic(comicId);

    int removeIndex = -1;
    for (int rowIndex = 0; rowIndex < m_rows.size(); rowIndex += 1) {
        if (m_rows.at(rowIndex).id == comicId) {
            removeIndex = rowIndex;
            break;
        }
    }
    if (removeIndex >= 0) {
        beginRemoveRows(QModelIndex(), removeIndex, removeIndex);
        m_rows.removeAt(removeIndex);
        endRemoveRows();
    }
    m_lastMutationKind = QString("delete_comic_hard");
    emit statusChanged();

    QStringList warnings;
    if (stagedArchiveDeletePending) {
        ComicDeleteOps::rememberPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);

        QString removedDirPath;
        DeleteFailureInfo finalizeFailure;
        if (!performFinalizeStagedArchiveDelete(stagedDelete, removedDirPath, finalizeFailure)) {
            appendWarningLine(
                warnings,
                QStringLiteral("Archive cleanup after delete failed: %1").arg(formatDeleteFailureText(finalizeFailure))
            );
        } else {
            ComicDeleteOps::forgetPendingStagedDelete(m_dataRoot, stagedDelete.stagedPath);
            if (!removedDirPath.isEmpty()) {
                cleanupEmptyLibraryDirs(
                    QDir(m_dataRoot).filePath(QStringLiteral("Library")),
                    { removedDirPath }
                );
            }
        }
    }

    const QString fingerprintHistoryError = insertFingerprintHistoryEntries(m_dbPath, fingerprintEntries, nullptr);
    if (!fingerprintHistoryError.isEmpty()) {
        appendWarningLine(
            warnings,
            QStringLiteral("Restore history update failed: %1").arg(fingerprintHistoryError)
        );
    }

    if (!warnings.isEmpty()) {
        if (warnings.size() == 1) {
            messageOut = QStringLiteral("Issue was removed with warning.\n%1").arg(warnings.first());
            return true;
        }
        messageOut = QStringLiteral("Issue was removed with warnings.\n%1").arg(warnings.join('\n'));
    }
    return true;
}
