#pragma once

#include <QString>
#include <QVector>

namespace ImportDuplicateClassifier {

enum class Tier {
    None,
    Exact,
    VeryLikely,
    Weak
};

struct Candidate {
    int id = 0;
    QString filename;
    QString filePath;
    QString series;
    QString seriesKey;
    QString volume;
    QString issue;
    QString title;
    QString strictFilenameSignature;
    QString looseFilenameSignature;
};

struct Input {
    QString plannedFilePath;
    QString seriesKey;
    QString volumeKey;
    QString issueKey;
    QString exactVolumeValue;
    QString exactIssueValue;
    QString strictFilenameSignature;
    QString looseFilenameSignature;
    bool relaxWeakMatchesForSeriesContext = false;
};

struct MatchResult {
    Tier tier = Tier::None;
    QVector<Candidate> candidates;
    QString reasonKey;

    bool isUnique() const { return candidates.size() == 1; }
};

QString tierKey(Tier tier);
MatchResult classifyLiveDuplicate(
    const Input &input,
    const QVector<Candidate> &liveCandidates
);

} // namespace ImportDuplicateClassifier
