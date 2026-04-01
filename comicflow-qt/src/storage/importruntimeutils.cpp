#include "storage/importruntimeutils.h"

#include <QDir>
#include <QFileInfo>

#include <algorithm>

namespace ComicImportRuntime {

void resetOutcome(ImportWorkflowState &state)
{
    state.lastAction.clear();
    state.lastComicId = -1;
    state.lastDuplicateId = -1;
    state.lastDuplicateTier.clear();
    state.lastRestoreCandidateCount = 0;
    state.lastRestoreCandidateId = -1;
}

void recordCreated(ImportWorkflowState &state, int comicId)
{
    state.lastAction = QStringLiteral("created");
    state.lastComicId = comicId;
}

void recordRestored(ImportWorkflowState &state, int comicId)
{
    state.lastAction = QStringLiteral("restored");
    state.lastComicId = comicId;
}

void recordDuplicate(ImportWorkflowState &state, int duplicateId, const QString &duplicateTier)
{
    state.lastAction = QStringLiteral("duplicate");
    state.lastDuplicateId = duplicateId;
    state.lastDuplicateTier = duplicateTier.trimmed();
}

void recordRestoreConflict(ImportWorkflowState &state, int candidateCount)
{
    state.lastAction = QStringLiteral("restore_conflict");
    state.lastRestoreCandidateCount = std::max(0, candidateCount);
    state.lastRestoreCandidateId = -1;
}

void recordRestoreReviewRequired(ImportWorkflowState &state, int candidateCount, int candidateId)
{
    state.lastAction = QStringLiteral("restore_review_required");
    state.lastRestoreCandidateCount = std::max(1, candidateCount);
    state.lastRestoreCandidateId = candidateId;
}

QString resolvedAction(const ImportWorkflowState &state)
{
    const QString action = state.lastAction.trimmed();
    return action.isEmpty() ? QStringLiteral("created") : action;
}

QVariantMap makeFailureResult(
    const QString &code,
    const QString &message,
    const QString &sourcePath,
    const QString &sourceType
)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("code"), code);
    result.insert(QStringLiteral("error"), message);
    if (!sourcePath.trimmed().isEmpty()) {
        result.insert(QStringLiteral("sourcePath"), sourcePath);
    }
    if (!sourceType.trimmed().isEmpty()) {
        result.insert(QStringLiteral("sourceType"), sourceType);
    }
    return result;
}

QVariantMap makeSuccessResult(
    const ImportWorkflowState &state,
    const QString &finalFilename,
    const QString &finalFilePath,
    bool createdArchiveFile,
    const QString &sourcePath
)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("code"), resolvedAction(state));
    result.insert(QStringLiteral("comicId"), state.lastComicId);
    result.insert(QStringLiteral("filename"), finalFilename);
    result.insert(QStringLiteral("filePath"), QDir::toNativeSeparators(QFileInfo(finalFilePath).absoluteFilePath()));
    result.insert(QStringLiteral("createdArchiveFile"), createdArchiveFile);
    result.insert(QStringLiteral("sourcePath"), sourcePath);
    return result;
}

QVariantMap makeCreateFailureResult(
    const ImportWorkflowState &state,
    const QString &fallbackCode,
    const QString &message,
    const QString &sourcePath
)
{
    QVariantMap result;
    if (state.lastAction == QStringLiteral("duplicate") && state.lastDuplicateId > 0) {
        result = makeFailureResult(QStringLiteral("duplicate"), message, sourcePath);
        result.insert(QStringLiteral("existingId"), state.lastDuplicateId);
        result.insert(QStringLiteral("duplicateTier"), state.lastDuplicateTier);
        return result;
    }

    if (state.lastAction == QStringLiteral("restore_conflict")) {
        result = makeFailureResult(QStringLiteral("restore_conflict"), message, sourcePath);
        result.insert(QStringLiteral("restoreCandidateCount"), state.lastRestoreCandidateCount);
        return result;
    }

    if (state.lastAction == QStringLiteral("restore_review_required")) {
        result = makeFailureResult(QStringLiteral("restore_review_required"), message, sourcePath);
        result.insert(QStringLiteral("restoreCandidateCount"), state.lastRestoreCandidateCount);
        if (state.lastRestoreCandidateId > 0) {
            result.insert(QStringLiteral("existingId"), state.lastRestoreCandidateId);
        }
        return result;
    }

    return makeFailureResult(fallbackCode, message, sourcePath);
}

} // namespace ComicImportRuntime
