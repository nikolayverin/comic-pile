#pragma once

#include <QString>
#include <QVariantMap>

namespace ComicImportMatching {

struct ImportIdentityPassport {
    QString sourceType;
    QString sourcePath;
    QString sourceLabel;
    QString filenameHint;
    QString parentFolderLabel;

    QString fallbackTitle;
    QString parsedFilenameSeries;
    QString parsedFolderSeries;
    QString parsedIssue;

    QString explicitSeries;
    QString explicitVolume;
    QString explicitIssue;
    QString explicitTitle;

    QString contextSeries;

    QString comicInfoSeries;
    QString comicInfoVolume;
    QString comicInfoIssue;
    QString comicInfoTitle;

    QString strictFilenameSignature;
    QString looseFilenameSignature;

    QString effectiveSeries;
    QString effectiveVolume;
    QString effectiveIssue;
    QString effectiveTitle;

    QString seriesKey;
    QString volumeKey;
    QString issueKey;

    QString seriesSource;
    QString volumeSource;
    QString issueSource;
    QString titleSource;

    QVariantMap toVariantMap() const;
};

QString normalizeSeriesKey(const QString &value);
QString normalizeVolumeKey(const QString &value);
QString semanticVolumeValue(const QString &value);
QString normalizeImportSourceType(const QString &value);

QString guessIssueNumberFromFilename(const QString &filename);
QString guessSeriesFromFilename(const QString &filename);
bool isWeakSeriesName(const QString &seriesName);

QString normalizeFilenameSignatureStrict(const QString &filename);
QString normalizeFilenameSignatureLoose(const QString &filename);
QString normalizeIssueKey(const QString &issueValue);
QString normalizeStoredIssueNumber(const QString &issueValue);
QString displayIssueNumber(const QString &issueValue);

int extractPositiveIssueNumber(const QString &issueNumber);
int extractPositiveNumberFromFilename(const QString &filename);

ImportIdentityPassport buildImportIdentityPassport(
    const QString &sourceType,
    const QString &sourcePath,
    const QString &sourceLabel,
    const QString &parentFolderLabel,
    const QString &filenameHint,
    const QVariantMap &importValues,
    const QVariantMap &comicInfoValues = {}
);
QVariantMap applyPassportDefaults(
    const QVariantMap &importValues,
    const ImportIdentityPassport &passport
);

} // namespace ComicImportMatching
