#include "storage/comicslistmodel.h"

#include "common/scopedsqlconnectionremoval.h"
#include "storage/comicsmodelutils.h"
#include "storage/deletestagingops.h"
#include "storage/importmatching.h"
#include "storage/issuefileops.h"
#include "storage/readercacheutils.h"
#include "storage/readerrequestutils.h"
#include "storage/storedpathutils.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QUuid>

namespace {

constexpr auto kSeriesHeaderShufflePreviewKey = "__series_header_shuffle_preview__";

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString normalizeInputFilePath(const QString &rawInput)
{
    return ComicStoragePaths::normalizePathInput(rawInput);
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
    QStringList warnings;
    idsToDelete.reserve(m_rows.size());
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
    cleanupSeriesHeroArtifactsForDeletedSeries(normalizedKey);
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
        if (!deleteMessage.isEmpty()) {
            const QString detail = QStringLiteral("Issue %1: %2").arg(comicId).arg(deleteMessage);
            if (removed) {
                warnings.push_back(detail);
            } else {
                errors.push_back(detail);
            }
        }
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

    for (const ComicRow &row : m_rows) {
        if (row.seriesGroupKey != normalizedKey) continue;

        StagedArchiveDeleteOp stagedDelete;
        stagedDelete.comicId = row.id;
        const QString archivePath = archivePathForComicId(row.id);
        bool markMissing = true;
        if (!archivePath.isEmpty()) {
            DeleteFailureInfo failure;
            if (!ComicDeleteOps::stageArchiveDelete(archivePath, stagedDelete, failure)) {
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
            const QString rollbackWarning = ComicDeleteOps::rollbackStagedArchiveDeletes(stagedDeletes);
            if (!rollbackWarning.isEmpty()) {
                return QString("%1\nRollback warning:\n%2").arg(applyError, rollbackWarning);
            }
            return applyError;
        }
    }

    QVector<int> finalRemovedIds = idsToMarkMissing;
    if (!stagedDeletes.isEmpty()) {
        QHash<int, QString> restoreBindingsByComicId;
        QSet<int> restoredIds;
        QStringList recoveryWarnings;

        for (const StagedArchiveDeleteOp &stagedDelete : stagedDeletes) {
            QString cleanupDirPath;
            DeleteFailureInfo finalizeFailure;
            if (ComicDeleteOps::finalizeStagedArchiveDelete(stagedDelete, cleanupDirPath, finalizeFailure)) {
                if (!cleanupDirPath.isEmpty()) {
                    dirsToCleanup.push_back(cleanupDirPath);
                }
                continue;
            }

            failedFiles.push_back(finalizeFailure);

            const QString rollbackWarning = rollbackStagedArchiveDeleteWithWarning(stagedDelete);
            if (!rollbackWarning.isEmpty()) {
                recoveryWarnings.push_back(rollbackWarning);
                continue;
            }

            if (!stagedDelete.originalPath.trimmed().isEmpty()) {
                restoreBindingsByComicId.insert(stagedDelete.comicId, stagedDelete.originalPath);
            }
            restoredIds.insert(stagedDelete.comicId);
        }

        if (!restoreBindingsByComicId.isEmpty()) {
            const QString restoreError = restoreComicFileBindingsAfterRecovery(
                restoreBindingsByComicId,
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
        lines.reserve(failedFiles.size());
        for (const DeleteFailureInfo &info : failedFiles) {
            lines.push_back(formatDeleteFailureText(info));
        }
        return QString("Some files could not be removed:\n%1").arg(lines.join('\n'));
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

    return ComicModelUtils::normalizeSeriesKey(series);
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

    StagedArchiveDeleteOp stagedDelete;
    stagedDelete.comicId = comicId;
    if (!filePath.isEmpty()) {
        DeleteFailureInfo stageFailure;
        if (!ComicDeleteOps::stageArchiveDelete(filePath, stagedDelete, stageFailure)) {
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
        const QString rollbackWarning = rollbackStagedArchiveDeleteWithWarning(stagedDelete);
        if (!rollbackWarning.isEmpty()) {
            return QString("%1\nRollback warning:\n%2")
                .arg(applyError, rollbackWarning);
        }
        return applyError;
    }

    QString removedDirPath;
    DeleteFailureInfo finalizeFailure;
    if (!ComicDeleteOps::finalizeStagedArchiveDelete(stagedDelete, removedDirPath, finalizeFailure)) {
        const QString rollbackWarning = rollbackStagedArchiveDeleteWithWarning(stagedDelete);
        if (!rollbackWarning.isEmpty()) {
            reload();
            return QString("Could not remove archive file.\n%1\nRecovery warning:\n%2")
                .arg(formatDeleteFailureText(finalizeFailure), rollbackWarning);
        }

        QHash<int, QString> restoreBindingByComicId;
        restoreBindingByComicId.insert(comicId, stagedDelete.originalPath);
        const QString restoreError = restoreComicFileBindingsAfterRecovery(
            restoreBindingByComicId,
            QStringLiteral("restore_issue_file_after_delete")
        );
        if (!restoreError.isEmpty()) {
            reload();
            return QString("Could not remove archive file.\n%1\nRecovery warning: archive was restored on disk but DB relink failed: %2")
                .arg(formatDeleteFailureText(finalizeFailure), restoreError);
        }

        return QString("Could not remove archive file.\n%1").arg(formatDeleteFailureText(finalizeFailure));
    }

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
    if (!ghostCleanupError.isEmpty()) {
        return QStringLiteral(
            "Archive file was removed, but cleanup of older restore duplicates failed.\n%1"
        ).arg(ghostCleanupError);
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
    const QString currentVolumeKey = ComicModelUtils::normalizeVolumeKey(current.volume);
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
            if (ComicModelUtils::normalizeVolumeKey(candidate.volume) != currentVolumeKey) {
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
        cleanupSeriesHeroArtifactsForDeletedSeries(seriesKey);
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

    if (!warnings.isEmpty()) {
        if (warnings.size() == 1) {
            if (!deleteMessage.isEmpty()) {
                return deleteMessage;
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

void ComicsListModel::cleanupSeriesHeroArtifactsForDeletedSeries(const QString &seriesKey)
{
    const QString normalizedKey = seriesKey.trimmed();
    if (normalizedKey.isEmpty()) {
        return;
    }

    purgeSeriesHeroCacheForKey(normalizedKey);
    resetRandomSeriesHeroState(normalizedKey);
    purgeSeriesHeroCacheForKey(QStringLiteral(kSeriesHeaderShufflePreviewKey));
}

bool ComicsListModel::deleteComicHardInternal(int comicId, QString &messageOut)
{
    messageOut.clear();
    if (comicId < 1) {
        messageOut = QStringLiteral("Invalid issue id.");
        return false;
    }

    const QString seriesKey = deleteSeriesKeyForComic(comicId);
    const bool deletingLastIssueInSeries = !seriesKey.isEmpty() && liveIssueCountForSeries(seriesKey) <= 1;

    QString filePath;
    {
        const QString loadError = ComicIssueFileOps::loadComicFilePath(m_dbPath, m_dataRoot, comicId, filePath);
        if (!loadError.isEmpty()) {
            messageOut = loadError;
            return false;
        }
    }

    StagedArchiveDeleteOp stagedDelete;
    bool stagedArchiveDeletePending = false;
    if (!filePath.isEmpty()) {
        DeleteFailureInfo stageFailure;
        if (!ComicDeleteOps::stageArchiveDelete(filePath, stagedDelete, stageFailure)) {
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
            const QString rollbackWarning = rollbackStagedArchiveDeleteWithWarning(stagedDelete);
            if (!rollbackWarning.isEmpty()) {
                messageOut = QStringLiteral("%1\nRollback warning:\n%2")
                    .arg(deleteError, rollbackWarning);
                return false;
            }
        }
        messageOut = deleteError;
        return false;
    }

    ComicReaderCache::purgeRuntimeCacheForComic(m_dataRoot, comicId);
    if (deletingLastIssueInSeries) {
        cleanupSeriesHeroArtifactsForDeletedSeries(seriesKey);
    } else {
        purgeSeriesHeroCacheForKey(seriesKey);
    }
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
        appendWarningLine(
            warnings,
            finalizePendingStagedArchiveDelete(
                stagedDelete,
                QStringLiteral("Archive cleanup after delete failed: ")
            )
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
