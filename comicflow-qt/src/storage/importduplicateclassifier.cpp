#include "storage/importduplicateclassifier.h"

#include "storage/importmatching.h"

#include <QDir>

namespace {

QString normalizePathForCompare(const QString &path)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(path.trimmed())).toLower();
}

QString candidateVolumeKey(const ImportDuplicateClassifier::Candidate &candidate)
{
    return ComicImportMatching::normalizeVolumeKey(candidate.volume);
}

QString candidateIssueKey(const ImportDuplicateClassifier::Candidate &candidate)
{
    return ComicImportMatching::normalizeIssueKey(candidate.issue);
}

bool volumeCompatible(
    const ImportDuplicateClassifier::Input &input,
    const ImportDuplicateClassifier::Candidate &candidate
)
{
    const QString inputKey = input.volumeKey.trimmed();
    const QString candidateKey = candidateVolumeKey(candidate);
    if (inputKey.isEmpty() || inputKey == QStringLiteral("__no_volume__")) return true;
    if (candidateKey.isEmpty() || candidateKey == QStringLiteral("__no_volume__")) return true;
    return inputKey == candidateKey;
}

QVector<ImportDuplicateClassifier::Candidate> exactMatches(
    const ImportDuplicateClassifier::Input &input,
    const QVector<ImportDuplicateClassifier::Candidate> &liveCandidates
)
{
    QVector<ImportDuplicateClassifier::Candidate> matches;
    const QString plannedKey = normalizePathForCompare(input.plannedFilePath);
    if (plannedKey.isEmpty()) return matches;

    for (const auto &candidate : liveCandidates) {
        if (normalizePathForCompare(candidate.filePath) != plannedKey) continue;
        matches.push_back(candidate);
    }
    return matches;
}

QVector<ImportDuplicateClassifier::Candidate> veryLikelyMatches(
    const ImportDuplicateClassifier::Input &input,
    const QVector<ImportDuplicateClassifier::Candidate> &liveCandidates
)
{
    QVector<ImportDuplicateClassifier::Candidate> matches;
    if (input.seriesKey.trimmed().isEmpty() || input.seriesKey == QStringLiteral("unknown-series")) return matches;
    if (input.issueKey.trimmed().isEmpty()) return matches;

    for (const auto &candidate : liveCandidates) {
        if (candidate.seriesKey != input.seriesKey) continue;
        if (candidateIssueKey(candidate) != input.issueKey) continue;
        if (!volumeCompatible(input, candidate)) continue;
        matches.push_back(candidate);
    }
    return matches;
}

QVector<ImportDuplicateClassifier::Candidate> weakStrictSignatureMatches(
    const ImportDuplicateClassifier::Input &input,
    const QVector<ImportDuplicateClassifier::Candidate> &liveCandidates
)
{
    QVector<ImportDuplicateClassifier::Candidate> matches;
    if (input.seriesKey.trimmed().isEmpty() || input.seriesKey == QStringLiteral("unknown-series")) return matches;
    if (input.strictFilenameSignature.trimmed().isEmpty()) return matches;

    for (const auto &candidate : liveCandidates) {
        if (candidate.seriesKey != input.seriesKey) continue;
        if (candidate.strictFilenameSignature != input.strictFilenameSignature) continue;
        matches.push_back(candidate);
    }
    return matches;
}

QVector<ImportDuplicateClassifier::Candidate> weakIssueOnlyMatches(
    const ImportDuplicateClassifier::Input &input,
    const QVector<ImportDuplicateClassifier::Candidate> &liveCandidates
)
{
    QVector<ImportDuplicateClassifier::Candidate> matches;
    if (input.seriesKey.trimmed().isEmpty() || input.seriesKey == QStringLiteral("unknown-series")) return matches;
    if (input.issueKey.trimmed().isEmpty()) return matches;

    for (const auto &candidate : liveCandidates) {
        if (candidate.seriesKey != input.seriesKey) continue;
        if (candidateIssueKey(candidate) != input.issueKey) continue;
        if (volumeCompatible(input, candidate)) continue;
        matches.push_back(candidate);
    }
    return matches;
}

QVector<ImportDuplicateClassifier::Candidate> weakLooseSignatureMatches(
    const ImportDuplicateClassifier::Input &input,
    const QVector<ImportDuplicateClassifier::Candidate> &liveCandidates
)
{
    QVector<ImportDuplicateClassifier::Candidate> matches;
    if (input.seriesKey.trimmed().isEmpty() || input.seriesKey == QStringLiteral("unknown-series")) return matches;
    if (input.looseFilenameSignature.trimmed().isEmpty()) return matches;

    for (const auto &candidate : liveCandidates) {
        if (candidate.seriesKey != input.seriesKey) continue;
        if (candidate.looseFilenameSignature != input.looseFilenameSignature) continue;
        matches.push_back(candidate);
    }
    return matches;
}

ImportDuplicateClassifier::MatchResult buildResult(
    ImportDuplicateClassifier::Tier tier,
    const QVector<ImportDuplicateClassifier::Candidate> &matches,
    const QString &reasonKey
)
{
    ImportDuplicateClassifier::MatchResult result;
    result.tier = tier;
    result.candidates = matches;
    result.reasonKey = reasonKey;
    return result;
}

} // namespace

namespace ImportDuplicateClassifier {

QString tierKey(Tier tier)
{
    switch (tier) {
    case Tier::Exact:
        return QStringLiteral("exact");
    case Tier::VeryLikely:
        return QStringLiteral("very_likely");
    case Tier::Weak:
        return QStringLiteral("weak");
    case Tier::None:
    default:
        return {};
    }
}

MatchResult classifyLiveDuplicate(
    const Input &input,
    const QVector<Candidate> &liveCandidates
)
{
    const QVector<Candidate> exact = exactMatches(input, liveCandidates);
    if (exact.size() == 1) {
        return buildResult(Tier::Exact, exact, QStringLiteral("same_path"));
    }

    const QVector<Candidate> veryLikely = veryLikelyMatches(input, liveCandidates);
    if (veryLikely.size() == 1) {
        return buildResult(Tier::VeryLikely, veryLikely, QStringLiteral("same_series_issue"));
    }

    if (input.relaxWeakMatchesForSeriesContext) {
        return {};
    }

    const QVector<Candidate> weakStrict = weakStrictSignatureMatches(input, liveCandidates);
    if (weakStrict.size() == 1) {
        return buildResult(Tier::Weak, weakStrict, QStringLiteral("strict_filename_signature"));
    }

    const QVector<Candidate> weakIssueOnly = weakIssueOnlyMatches(input, liveCandidates);
    if (weakIssueOnly.size() == 1) {
        return buildResult(Tier::Weak, weakIssueOnly, QStringLiteral("same_issue_volume_drift"));
    }

    const QVector<Candidate> weakLoose = weakLooseSignatureMatches(input, liveCandidates);
    if (weakLoose.size() == 1) {
        return buildResult(Tier::Weak, weakLoose, QStringLiteral("loose_filename_signature"));
    }

    return {};
}

} // namespace ImportDuplicateClassifier
