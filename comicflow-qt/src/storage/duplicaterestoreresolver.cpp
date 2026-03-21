#include "storage/duplicaterestoreresolver.h"

#include "storage/importmatching.h"

namespace DuplicateRestoreResolver {

bool matchesIssueKey(const RestoreMatchInput &input, const QString &candidateIssue)
{
    if (input.issueKey.isEmpty()) return true;
    return ComicImportMatching::normalizeIssueKey(candidateIssue) == input.issueKey;
}

bool matchesVolumeKey(const RestoreMatchInput &input, const QString &candidateVolume)
{
    if (input.volumeKey == QStringLiteral("__no_volume__")) return true;
    return ComicImportMatching::normalizeVolumeKey(candidateVolume) == input.volumeKey;
}

QVector<RestoreCandidate> narrowExactCandidates(
    const QVector<RestoreCandidate> &candidates,
    const RestoreMatchInput &input
)
{
    QVector<RestoreCandidate> narrowed = candidates;
    const QString exactIssueValue = input.exactIssueValue.trimmed();
    if (!exactIssueValue.isEmpty() && narrowed.size() > 1) {
        QVector<RestoreCandidate> exactIssueMatches;
        for (const RestoreCandidate &candidate : narrowed) {
            if (candidate.issue.trimmed() == exactIssueValue) {
                exactIssueMatches.push_back(candidate);
            }
        }
        if (!exactIssueMatches.isEmpty()) {
            narrowed = exactIssueMatches;
        }
    }

    const QString exactVolumeValue = input.exactVolumeValue.trimmed();
    if (!exactVolumeValue.isEmpty() && narrowed.size() > 1) {
        QVector<RestoreCandidate> exactVolumeMatches;
        for (const RestoreCandidate &candidate : narrowed) {
            if (candidate.volume.trimmed() == exactVolumeValue) {
                exactVolumeMatches.push_back(candidate);
            }
        }
        if (!exactVolumeMatches.isEmpty()) {
            narrowed = exactVolumeMatches;
        }
    }

    return narrowed;
}

bool hasFilenameMetadataMismatch(
    const RestoreCandidate &candidate,
    const RestoreMatchInput &input
)
{
    bool metadataMismatch = false;
    if (input.seriesKey != QStringLiteral("unknown-series")
        && !candidate.seriesKey.isEmpty()
        && candidate.seriesKey != input.seriesKey) {
        metadataMismatch = true;
    }
    if (!input.issueKey.isEmpty()
        && !candidate.issue.isEmpty()
        && !matchesIssueKey(input, candidate.issue)) {
        metadataMismatch = true;
    }
    if (input.volumeKey != QStringLiteral("__no_volume__")
        && !candidate.volume.isEmpty()
        && !matchesVolumeKey(input, candidate.volume)) {
        metadataMismatch = true;
    }
    return metadataMismatch;
}

bool isExactMetadataCandidate(
    const RestoreCandidate &candidate,
    const RestoreMatchInput &input
)
{
    if (input.seriesKey != QStringLiteral("unknown-series")
        && !candidate.seriesKey.isEmpty()
        && candidate.seriesKey != input.seriesKey) {
        return false;
    }

    const QString exactIssueValue = input.exactIssueValue.trimmed();
    if (!exactIssueValue.isEmpty() && candidate.issue.trimmed() != exactIssueValue) {
        return false;
    }

    const QString exactVolumeValue = input.exactVolumeValue.trimmed();
    if (!exactVolumeValue.isEmpty() && candidate.volume.trimmed() != exactVolumeValue) {
        return false;
    }

    return true;
}

Resolution resolveFilenameCandidates(
    const QVector<RestoreCandidate> &filenameCandidates,
    const RestoreMatchInput &input
)
{
    Resolution resolution;
    resolution.priority = RestorePriority::Filename;

    if (filenameCandidates.size() == 1) {
        const RestoreCandidate candidate = filenameCandidates.first();
        if (!hasFilenameMetadataMismatch(candidate, input)) {
            resolution.candidates = { candidate };
            return resolution;
        }
    }

    if (filenameCandidates.size() > 1
        && input.seriesKey != QStringLiteral("unknown-series")
        && !input.issueKey.isEmpty()) {
        QVector<RestoreCandidate> narrowed;
        for (const RestoreCandidate &candidate : filenameCandidates) {
            if (candidate.seriesKey != input.seriesKey) continue;
            if (!matchesIssueKey(input, candidate.issue)) continue;
            if (!matchesVolumeKey(input, candidate.volume)) continue;
            narrowed.push_back(candidate);
        }
        resolution.candidates = narrowExactCandidates(narrowed, input);
        return resolution;
    }

    return resolution;
}

Resolution resolveMetadataCandidates(
    const QVector<RestoreCandidate> &metadataCandidates,
    const RestoreMatchInput &input
)
{
    Resolution resolution;
    resolution.priority = RestorePriority::Metadata;
    resolution.candidates = narrowExactCandidates(metadataCandidates, input);
    return resolution;
}

Resolution resolveStrictSignatureCandidates(
    const QVector<RestoreCandidate> &strictSignatureCandidates
)
{
    Resolution resolution;
    resolution.priority = RestorePriority::StrictSignature;
    resolution.candidates = strictSignatureCandidates;
    return resolution;
}

} // namespace DuplicateRestoreResolver
