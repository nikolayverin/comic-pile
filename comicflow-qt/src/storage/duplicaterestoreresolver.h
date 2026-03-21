#pragma once

#include <QString>
#include <QVector>

namespace DuplicateRestoreResolver {

enum class RestorePriority {
    None,
    Filename,
    Metadata,
    StrictSignature
};

struct RestoreCandidate {
    int id = 0;
    QString filename;
    QString filePath;
    QString series;
    QString seriesKey;
    QString volume;
    QString issue;
};

struct RestoreMatchInput {
    QString seriesKey;
    QString issueKey;
    QString volumeKey;
    QString exactIssueValue;
    QString exactVolumeValue;
};

struct Resolution {
    RestorePriority priority = RestorePriority::None;
    QVector<RestoreCandidate> candidates;

    bool isUnique() const { return candidates.size() == 1; }
};

bool matchesIssueKey(const RestoreMatchInput &input, const QString &candidateIssue);
bool matchesVolumeKey(const RestoreMatchInput &input, const QString &candidateVolume);
QVector<RestoreCandidate> narrowExactCandidates(
    const QVector<RestoreCandidate> &candidates,
    const RestoreMatchInput &input
);
bool hasFilenameMetadataMismatch(
    const RestoreCandidate &candidate,
    const RestoreMatchInput &input
);
bool isExactMetadataCandidate(
    const RestoreCandidate &candidate,
    const RestoreMatchInput &input
);

Resolution resolveFilenameCandidates(
    const QVector<RestoreCandidate> &filenameCandidates,
    const RestoreMatchInput &input
);
Resolution resolveMetadataCandidates(
    const QVector<RestoreCandidate> &metadataCandidates,
    const RestoreMatchInput &input
);
Resolution resolveStrictSignatureCandidates(
    const QVector<RestoreCandidate> &strictSignatureCandidates
);

} // namespace DuplicateRestoreResolver
