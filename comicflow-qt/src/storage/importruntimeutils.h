#pragma once

#include <QHash>
#include <QString>
#include <QVariantMap>

namespace ComicImportRuntime {

struct ImportWorkflowState {
    QHash<QString, QString> deferredFolderBySeriesKey;
    QString lastAction;
    int lastComicId = -1;
    int lastDuplicateId = -1;
    QString lastDuplicateTier;
    int lastRestoreCandidateCount = 0;
    int lastRestoreCandidateId = -1;
};

void resetOutcome(ImportWorkflowState &state);
void recordCreated(ImportWorkflowState &state, int comicId);
void recordRestored(ImportWorkflowState &state, int comicId);
void recordDuplicate(ImportWorkflowState &state, int duplicateId, const QString &duplicateTier);
void recordRestoreConflict(ImportWorkflowState &state, int candidateCount);
void recordRestoreReviewRequired(ImportWorkflowState &state, int candidateCount, int candidateId);

QString resolvedAction(const ImportWorkflowState &state);

QVariantMap makeFailureResult(
    const QString &code,
    const QString &message,
    const QString &sourcePath = QString(),
    const QString &sourceType = QString()
);

QVariantMap makeSuccessResult(
    const ImportWorkflowState &state,
    const QString &finalFilename,
    const QString &finalFilePath,
    bool createdArchiveFile,
    const QString &sourcePath
);

QVariantMap makeCreateFailureResult(
    const ImportWorkflowState &state,
    const QString &fallbackCode,
    const QString &message,
    const QString &sourcePath
);

} // namespace ComicImportRuntime
