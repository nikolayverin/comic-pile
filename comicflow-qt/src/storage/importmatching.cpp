#include "storage/importmatching.h"

#include <initializer_list>
#include <limits>

#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>

namespace {

bool isIssueMarkerToken(const QString &token)
{
    const QString normalized = token.normalized(QString::NormalizationForm_KC).toLower().trimmed();
    static const QSet<QString> markers = {
        QStringLiteral("issue"),
        QStringLiteral("iss"),
        QStringLiteral("no"),
        QStringLiteral("n"),
        QStringLiteral("ch"),
        QStringLiteral("chapter"),
        QStringLiteral("ep"),
        QStringLiteral("episode"),
        QStringLiteral("part"),
        QStringLiteral("pt")
    };
    return markers.contains(normalized);
}

bool isYearToken(const QString &token)
{
    bool ok = false;
    const int value = token.toInt(&ok);
    return ok && token.length() == 4 && value >= 1900 && value <= 2099;
}

bool isNumericIssueToken(const QString &token)
{
    static const QRegularExpression numericPattern(QStringLiteral("^#?\\d+(?:\\.\\d+)?$"));
    return numericPattern.match(token).hasMatch();
}

QString trimmedAliasValue(
    const QVariantMap &map,
    std::initializer_list<const char *> keys
)
{
    for (const char *key : keys) {
        const QString value = map.value(QString::fromLatin1(key)).toString().trimmed();
        if (!value.isEmpty()) return value;
    }
    return {};
}

QString sourceFallbackTitle(const QString &sourceType, const QString &sourceLabel)
{
    const QString trimmedLabel = sourceLabel.trimmed();
    if (trimmedLabel.isEmpty()) return QStringLiteral("imported");

    if (sourceType.trimmed().compare(QStringLiteral("archive"), Qt::CaseInsensitive) == 0) {
        const QString baseName = QFileInfo(trimmedLabel).completeBaseName().trimmed();
        if (!baseName.isEmpty()) return baseName;
    }

    return trimmedLabel;
}

QString normalizeLooseText(const QString &value)
{
    QString key = value.normalized(QString::NormalizationForm_KC).toLower().trimmed();
    key.replace(QRegularExpression(QStringLiteral("[^a-z0-9]+")), QString());
    return key;
}

QString normalizedIssueToken(const QString &issueValue)
{
    QString normalized = issueValue.normalized(QString::NormalizationForm_KC).toLower().trimmed();
    normalized.remove(QRegularExpression(QStringLiteral("^(?:issue|iss|no|n|chapter|ch|ep|episode|part|pt)\\s*#?\\s*")));
    normalized.remove(QRegularExpression(QStringLiteral("^#+")));
    normalized = normalized.trimmed();
    normalized.replace(QRegularExpression(QStringLiteral("\\s+")), QString());
    return normalized;
}

bool fallbackTitleRepeatsSeriesAndIssue(
    const QString &fallbackTitle,
    const QString &seriesValue,
    const QString &issueValue
)
{
    const QString fallbackKey = normalizeLooseText(fallbackTitle);
    const QString seriesKey = normalizeLooseText(seriesValue);
    if (fallbackKey.isEmpty() || seriesKey.isEmpty()) {
        return false;
    }

    QStringList issueCandidates;
    const QString rawIssueToken = normalizedIssueToken(issueValue);
    if (!rawIssueToken.isEmpty()) {
        issueCandidates.push_back(rawIssueToken);
    }

    const QString normalizedIssueKey = ComicImportMatching::normalizeIssueKey(issueValue);
    if (!normalizedIssueKey.isEmpty()) {
        const QString normalizedIssueTokenValue = normalizeLooseText(normalizedIssueKey);
        if (!normalizedIssueTokenValue.isEmpty() && !issueCandidates.contains(normalizedIssueTokenValue)) {
            issueCandidates.push_back(normalizedIssueTokenValue);
        }
    }

    if (issueCandidates.isEmpty()) {
        return false;
    }

    static const QStringList markers = {
        QString(),
        QStringLiteral("issue"),
        QStringLiteral("iss"),
        QStringLiteral("no"),
        QStringLiteral("n"),
        QStringLiteral("ch"),
        QStringLiteral("chapter"),
        QStringLiteral("ep"),
        QStringLiteral("episode"),
        QStringLiteral("part"),
        QStringLiteral("pt")
    };

    for (const QString &issueCandidate : issueCandidates) {
        for (const QString &marker : markers) {
            const QString candidateKey = seriesKey + marker + issueCandidate;
            if (fallbackKey == candidateKey) {
                return true;
            }
        }
    }

    return false;
}

} // namespace

namespace ComicImportMatching {

QVariantMap ImportIdentityPassport::toVariantMap() const
{
    QVariantMap result;
    result.insert(QStringLiteral("sourceType"), sourceType);
    result.insert(QStringLiteral("sourcePath"), sourcePath);
    result.insert(QStringLiteral("sourceLabel"), sourceLabel);
    result.insert(QStringLiteral("filenameHint"), filenameHint);
    result.insert(QStringLiteral("parentFolderLabel"), parentFolderLabel);
    result.insert(QStringLiteral("fallbackTitle"), fallbackTitle);
    result.insert(QStringLiteral("parsedFilenameSeries"), parsedFilenameSeries);
    result.insert(QStringLiteral("parsedFolderSeries"), parsedFolderSeries);
    result.insert(QStringLiteral("parsedIssue"), parsedIssue);
    result.insert(QStringLiteral("explicitSeries"), explicitSeries);
    result.insert(QStringLiteral("explicitVolume"), explicitVolume);
    result.insert(QStringLiteral("explicitIssue"), explicitIssue);
    result.insert(QStringLiteral("explicitTitle"), explicitTitle);
    result.insert(QStringLiteral("contextSeries"), contextSeries);
    result.insert(QStringLiteral("comicInfoSeries"), comicInfoSeries);
    result.insert(QStringLiteral("comicInfoVolume"), comicInfoVolume);
    result.insert(QStringLiteral("comicInfoIssue"), comicInfoIssue);
    result.insert(QStringLiteral("comicInfoTitle"), comicInfoTitle);
    result.insert(QStringLiteral("strictFilenameSignature"), strictFilenameSignature);
    result.insert(QStringLiteral("looseFilenameSignature"), looseFilenameSignature);
    result.insert(QStringLiteral("effectiveSeries"), effectiveSeries);
    result.insert(QStringLiteral("effectiveVolume"), effectiveVolume);
    result.insert(QStringLiteral("effectiveIssue"), effectiveIssue);
    result.insert(QStringLiteral("effectiveTitle"), effectiveTitle);
    result.insert(QStringLiteral("seriesKey"), seriesKey);
    result.insert(QStringLiteral("volumeKey"), volumeKey);
    result.insert(QStringLiteral("issueKey"), issueKey);
    result.insert(QStringLiteral("seriesSource"), seriesSource);
    result.insert(QStringLiteral("volumeSource"), volumeSource);
    result.insert(QStringLiteral("issueSource"), issueSource);
    result.insert(QStringLiteral("titleSource"), titleSource);
    return result;
}

QString normalizeSeriesKey(const QString &value)
{
    QString key = value.normalized(QString::NormalizationForm_KC).toLower().trimmed();
    key.replace(QRegularExpression(QStringLiteral("[\\-_.:/\\\\]+")), QStringLiteral(" "));
    key.replace(QRegularExpression(QStringLiteral("[\"'`,!?\\(\\)\\[\\]\\{\\}]")), QString());
    key.replace(QRegularExpression(QStringLiteral("#\\s*\\d+\\b")), QStringLiteral(" "));
    key.replace(QRegularExpression(QStringLiteral("\\b(issue|vol|volume)\\s*\\d+\\b")), QStringLiteral(" "));
    key = key.simplified();
    if (key.isEmpty()) return QStringLiteral("unknown-series");
    return key;
}

QString normalizeVolumeKey(const QString &value)
{
    QString key = semanticVolumeValue(value).normalized(QString::NormalizationForm_KC).toLower().trimmed();
    key.replace(QRegularExpression(QStringLiteral("[\\-_.:/\\\\]+")), QStringLiteral(" "));
    key = key.simplified();
    if (key.isEmpty()) return QStringLiteral("__no_volume__");
    return key;
}

QString semanticVolumeValue(const QString &value)
{
    const QString trimmed = value.trimmed();
    if (trimmed.isEmpty()) return {};

    QString normalized = trimmed.normalized(QString::NormalizationForm_KC);
    normalized.remove(QRegularExpression(
        QStringLiteral("^vol(?:ume)?\\.?\\s*"),
        QRegularExpression::CaseInsensitiveOption
    ));
    normalized = normalized.simplified();

    static const QRegularExpression defaultOnePattern(QStringLiteral("^0*1(?:\\.0+)?$"));
    if (defaultOnePattern.match(normalized).hasMatch()) {
        return {};
    }

    return trimmed;
}

QString normalizeImportSourceType(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("archive") || normalized == QStringLiteral("image_folder")) {
        return normalized;
    }
    return {};
}

QString guessIssueNumberFromFilename(const QString &filename)
{
    QString baseName = QFileInfo(filename).completeBaseName().trimmed();
    if (baseName.isEmpty()) return {};

    baseName.replace(QLatin1Char('_'), QLatin1Char(' '));
    baseName.replace(QLatin1Char('.'), QLatin1Char(' '));
    baseName = baseName.simplified();

    const QRegularExpression trailingBracketPattern(QStringLiteral("\\s*[\\(\\[][^(\\)\\[\\]]*[\\)\\]]\\s*$"));
    while (true) {
        const QRegularExpressionMatch match = trailingBracketPattern.match(baseName);
        if (!match.hasMatch()) break;
        baseName = baseName.left(match.capturedStart()).trimmed();
    }

    const QRegularExpression issueYearSuffixPattern(
        QStringLiteral("^(.*?)(?:[\\s\\-]+(?:(?:issue|iss|no|n|ch|chapter|ep|episode)\\s*#?(\\d+(?:\\.\\d+)?)|#?(\\d{1,6}(?:\\.\\d+)?)))[\\s\\-]+((?:19|20)\\d{2})\\s*$"),
        QRegularExpression::CaseInsensitiveOption
    );
    {
        const QRegularExpressionMatch match = issueYearSuffixPattern.match(baseName);
        if (match.hasMatch()) {
            const QString withMarker = match.captured(2).trimmed();
            const QString plain = match.captured(3).trimmed();
            const QString resolved = !withMarker.isEmpty() ? withMarker : plain;
            if (!resolved.isEmpty()) return resolved;
        }
    }

    const QRegularExpression trailingIssuePattern(
        QStringLiteral("^(.*?)(?:[\\s\\-]+(?:(issue|iss|no|n|ch|chapter|ep|episode)\\s*#?(\\d+(?:\\.\\d+)?)|#?(\\d{1,6}(?:\\.\\d+)?)))\\s*$"),
        QRegularExpression::CaseInsensitiveOption
    );
    const QRegularExpressionMatch match = trailingIssuePattern.match(baseName);
    if (!match.hasMatch()) {
        if (isNumericIssueToken(baseName)) {
            const QString standalone = baseName.trimmed();
            if (!standalone.contains(QLatin1Char('.'))) {
                QString yearProbe = standalone;
                yearProbe.remove(QRegularExpression(QStringLiteral("^#+")));
                bool ok = false;
                const int yearLikeValue = yearProbe.toInt(&ok);
                if (ok && yearProbe.length() == 4 && yearLikeValue >= 1900 && yearLikeValue <= 2099) {
                    return {};
                }
            }
            return standalone;
        }
        return {};
    }

    const QString marker = match.captured(2);
    const QString withMarker = match.captured(3).trimmed();
    const QString plain = match.captured(4).trimmed();
    QString resolved = !withMarker.isEmpty() ? withMarker : plain;
    if (resolved.isEmpty()) return {};

    if (marker.isEmpty() && !resolved.contains(QLatin1Char('.'))) {
        bool ok = false;
        const int yearLikeValue = resolved.toInt(&ok);
        if (ok && resolved.length() == 4 && yearLikeValue >= 1900 && yearLikeValue <= 2099) {
            return {};
        }
    }
    return resolved;
}

int extractPositiveIssueNumber(const QString &issueNumber)
{
    const QString trimmed = issueNumber.trimmed();
    if (trimmed.isEmpty()) return -1;

    static const QVector<QRegularExpression> patterns = {
        QRegularExpression(QStringLiteral("^(?:issue|iss|no|n|chapter|ch|ep|episode|part|pt)\\s*#?\\s*(\\d+)\\b"), QRegularExpression::CaseInsensitiveOption),
        QRegularExpression(QStringLiteral("^#\\s*(\\d+)\\b")),
        QRegularExpression(QStringLiteral("^(\\d+)\\b"))
    };

    for (const QRegularExpression &pattern : patterns) {
        const QRegularExpressionMatch match = pattern.match(trimmed);
        if (!match.hasMatch()) continue;

        bool ok = false;
        const qlonglong value = match.captured(1).toLongLong(&ok);
        if (!ok || value < 1 || value > std::numeric_limits<int>::max()) continue;
        return static_cast<int>(value);
    }

    return -1;
}

int extractPositiveNumberFromFilename(const QString &filename)
{
    const QString baseName = QFileInfo(filename).completeBaseName().trimmed();
    if (baseName.isEmpty()) return -1;

    const QString simplified = baseName
        .normalized(QString::NormalizationForm_KC)
        .replace(QLatin1Char('_'), QLatin1Char(' '))
        .replace(QLatin1Char('.'), QLatin1Char(' '))
        .simplified();

    static const QVector<QRegularExpression> patterns = {
        QRegularExpression(QStringLiteral("(?:^|[\\s\\-])(?:issue|iss|no|n|chapter|ch|ep|episode|part|pt)\\s*#?(\\d+)\\b"), QRegularExpression::CaseInsensitiveOption),
        QRegularExpression(QStringLiteral("(?:^|[\\s\\-])#(\\d+)\\b")),
        QRegularExpression(QStringLiteral("(?:^|[\\s\\-])(\\d{1,6})\\b"))
    };

    int best = -1;
    for (const QRegularExpression &pattern : patterns) {
        auto it = pattern.globalMatch(simplified);
        while (it.hasNext()) {
            const QRegularExpressionMatch match = it.next();
            bool ok = false;
            const qlonglong value = match.captured(1).toLongLong(&ok);
            if (!ok || value < 1 || value > std::numeric_limits<int>::max()) continue;
            const int parsed = static_cast<int>(value);
            if (best < 0 || parsed < best) {
                best = parsed;
            }
        }
    }
    return best;
}

QString guessSeriesFromFilename(const QString &filename)
{
    const QString rawBaseName = QFileInfo(filename).completeBaseName().trimmed();
    if (rawBaseName.isEmpty()) return {};

    QString series = rawBaseName;
    series.replace(QLatin1Char('_'), QLatin1Char(' '));
    series.replace(QLatin1Char('.'), QLatin1Char(' '));
    series = series.simplified();

    const QRegularExpression trailingBracketPattern(QStringLiteral("\\s*[\\(\\[][^(\\)\\[\\]]*[\\)\\]]\\s*$"));
    while (true) {
        const QRegularExpressionMatch match = trailingBracketPattern.match(series);
        if (!match.hasMatch()) break;
        series = series.left(match.capturedStart()).trimmed();
    }

    const QRegularExpression trailingIssueYearPattern(
        QStringLiteral("^(.*?)(?:[\\s\\-]+(?:(?:issue|iss|no|n|ch|chapter|ep|episode)\\s*#?(\\d+(?:\\.\\d+)?)|#?(\\d{1,6}(?:\\.\\d+)?)))[\\s\\-]+((?:19|20)\\d{2})\\s*$"),
        QRegularExpression::CaseInsensitiveOption
    );
    const QRegularExpressionMatch issueYearMatch = trailingIssueYearPattern.match(series);
    if (issueYearMatch.hasMatch()) {
        const QString prefix = issueYearMatch.captured(1).trimmed();
        if (!prefix.isEmpty()) {
            series = prefix;
        }
    }

    const QRegularExpression trailingAttachedHashIssuePattern(
        QStringLiteral("^(.*?)\\s*#\\s*(\\d{1,6}(?:\\.\\d+)?)\\s*$"),
        QRegularExpression::CaseInsensitiveOption
    );
    const QRegularExpressionMatch attachedHashIssueMatch = trailingAttachedHashIssuePattern.match(series);
    if (attachedHashIssueMatch.hasMatch()) {
        const QString prefix = attachedHashIssueMatch.captured(1).trimmed();
        if (!prefix.isEmpty()) {
            series = prefix;
        }
    }

    const QRegularExpression trailingIssuePattern(
        QStringLiteral("^(.*?)(?:[\\s\\-]+(?:(issue|iss|no|n|ch|chapter|ep|episode)\\s*#?(\\d+(?:\\.\\d+)?)|#?(\\d{1,4}(?:\\.\\d+)?)))\\s*$"),
        QRegularExpression::CaseInsensitiveOption
    );
    const QRegularExpressionMatch issueMatch = trailingIssuePattern.match(series);
    if (issueMatch.hasMatch()) {
        const QString prefix = issueMatch.captured(1).trimmed();
        const QString marker = issueMatch.captured(2);
        const QString plainNumber = issueMatch.captured(4);

        bool shouldTrimIssueSuffix = !prefix.isEmpty();
        if (shouldTrimIssueSuffix && marker.isEmpty() && !plainNumber.contains(QLatin1Char('.'))) {
            bool ok = false;
            const int yearLikeValue = plainNumber.toInt(&ok);
            const bool looksLikeYear = ok
                && plainNumber.length() == 4
                && yearLikeValue >= 1900
                && yearLikeValue <= 2099;
            if (looksLikeYear) {
                shouldTrimIssueSuffix = false;
            }
        }

        if (shouldTrimIssueSuffix) {
            series = prefix;
        }
    }

    QStringList tokens = series.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (tokens.size() >= 3 && isYearToken(tokens.last()) && isNumericIssueToken(tokens.at(tokens.size() - 2))) {
        tokens.removeLast();
        tokens.removeLast();
        if (!tokens.isEmpty() && isIssueMarkerToken(tokens.last())) {
            tokens.removeLast();
        }
    } else if (tokens.size() >= 2 && isNumericIssueToken(tokens.last())) {
        tokens.removeLast();
        if (!tokens.isEmpty() && isIssueMarkerToken(tokens.last())) {
            tokens.removeLast();
        }
    }
    if (!tokens.isEmpty()) {
        series = tokens.join(QLatin1Char(' '));
    }

    series = series.trimmed();
    series.remove(QRegularExpression(QStringLiteral("^[\\s\\-]+|[\\s\\-]+$")));
    series = series.simplified();

    if (series.isEmpty()) {
        return rawBaseName;
    }
    return series;
}

bool isWeakSeriesName(const QString &seriesName)
{
    const QString normalized = seriesName.trimmed();
    if (normalized.isEmpty()) return true;

    static const QRegularExpression numericOnlyPattern(
        QStringLiteral("^[#\\s\\-_.()\\[\\]]*\\d+(?:\\.\\d+)?[#\\s\\-_.()\\[\\]]*$")
    );
    if (numericOnlyPattern.match(normalized).hasMatch()) return true;

    static const QRegularExpression genericIssuePattern(
        QStringLiteral("^(?:issue|iss|no|n|chapter|ch|ep|episode|part|pt)\\s*#?\\d*(?:\\.\\d+)?$"),
        QRegularExpression::CaseInsensitiveOption
    );
    return genericIssuePattern.match(normalized).hasMatch();
}

QString normalizeFilenameSignatureStrict(const QString &filename)
{
    QString key = QFileInfo(filename).completeBaseName().normalized(QString::NormalizationForm_KC).toLower().trimmed();
    key.replace(QRegularExpression(QStringLiteral("[\\-_.:/\\\\]+")), QStringLiteral(" "));
    key.replace(QRegularExpression(QStringLiteral("[\"'`,!?\\(\\)\\[\\]\\{\\}]")), QString());
    key = key.simplified();
    return key;
}

QString normalizeFilenameSignatureLoose(const QString &filename)
{
    QString key = QFileInfo(filename).completeBaseName().normalized(QString::NormalizationForm_KC).toLower().trimmed();
    key.replace(QRegularExpression(QStringLiteral("[^a-z0-9]+")), QString());
    return key;
}

QString normalizeIssueKey(const QString &issueValue)
{
    QString normalized = issueValue.normalized(QString::NormalizationForm_KC).toLower().trimmed();
    if (normalized.isEmpty()) return {};

    normalized.remove(QRegularExpression(QStringLiteral("^(?:issue|iss|no|n|chapter|ch|ep|episode|part|pt)\\s*#?\\s*")));
    normalized.remove(QRegularExpression(QStringLiteral("^#+")));
    normalized = normalized.trimmed();
    if (normalized.isEmpty()) return {};

    const QRegularExpression numericPattern(QStringLiteral("^0*([0-9]+)(?:\\.([0-9]+))?$"));
    const QRegularExpressionMatch numericMatch = numericPattern.match(normalized);
    if (numericMatch.hasMatch()) {
        QString integerPart = numericMatch.captured(1);
        QString decimalPart = numericMatch.captured(2);
        if (integerPart.isEmpty()) integerPart = QStringLiteral("0");
        if (decimalPart.isEmpty()) return integerPart;
        return QStringLiteral("%1.%2").arg(integerPart, decimalPart);
    }

    normalized.replace(QRegularExpression(QStringLiteral("\\s+")), QString());
    return normalized;
}

QString normalizeStoredIssueNumber(const QString &issueValue)
{
    const QString trimmed = issueValue.trimmed();
    if (trimmed.isEmpty()) return {};

    static const QRegularExpression numericPattern(QStringLiteral("^0*([0-9]+)(?:\\.([0-9]+))?$"));
    {
        const QRegularExpressionMatch match = numericPattern.match(trimmed);
        if (match.hasMatch()) {
            const QString integerPart = match.captured(1).isEmpty()
                ? QStringLiteral("0")
                : match.captured(1);
            const QString decimalPart = match.captured(2);
            return decimalPart.isEmpty()
                ? integerPart
                : QStringLiteral("%1.%2").arg(integerPart, decimalPart);
        }
    }

    static const QRegularExpression spacedPrefixPattern(
        QStringLiteral("^(.*?)(\\s+#?\\s*)(0*([0-9]+))(?:\\.([0-9]+))?$"),
        QRegularExpression::CaseInsensitiveOption
    );
    {
        const QRegularExpressionMatch match = spacedPrefixPattern.match(trimmed);
        if (match.hasMatch()) {
            const QString prefix = match.captured(1).trimmed();
            if (!prefix.isEmpty()) {
                const QString separator = match.captured(2).contains(QLatin1Char('#'))
                    ? QStringLiteral(" #")
                    : QStringLiteral(" ");
                const QString integerPart = match.captured(4).isEmpty()
                    ? QStringLiteral("0")
                    : match.captured(4);
                const QString decimalPart = match.captured(5);
                return decimalPart.isEmpty()
                    ? QStringLiteral("%1%2%3").arg(prefix, separator, integerPart)
                    : QStringLiteral("%1%2%3.%4").arg(prefix, separator, integerPart, decimalPart);
            }
        }
    }

    static const QRegularExpression attachedHashPattern(
        QStringLiteral("^(.*?)(#\\s*)(0*([0-9]+))(?:\\.([0-9]+))?$"),
        QRegularExpression::CaseInsensitiveOption
    );
    {
        const QRegularExpressionMatch match = attachedHashPattern.match(trimmed);
        if (match.hasMatch()) {
            const QString prefix = match.captured(1).trimmed();
            if (!prefix.isEmpty()) {
                const QString integerPart = match.captured(4).isEmpty()
                    ? QStringLiteral("0")
                    : match.captured(4);
                const QString decimalPart = match.captured(5);
                return decimalPart.isEmpty()
                    ? QStringLiteral("%1#%2").arg(prefix, integerPart)
                    : QStringLiteral("%1#%2.%3").arg(prefix, integerPart, decimalPart);
            }
        }
    }

    return trimmed;
}

QString displayIssueNumber(const QString &issueValue)
{
    return normalizeStoredIssueNumber(issueValue);
}

ImportIdentityPassport buildImportIdentityPassport(
    const QString &sourceType,
    const QString &sourcePath,
    const QString &sourceLabel,
    const QString &parentFolderLabel,
    const QString &filenameHint,
    const QVariantMap &importValues,
    const QVariantMap &comicInfoValues
)
{
    ImportIdentityPassport passport;
    passport.sourceType = sourceType.trimmed().toLower();
    passport.sourcePath = sourcePath.trimmed();
    passport.sourceLabel = sourceLabel.trimmed();
    passport.filenameHint = filenameHint.trimmed();
    passport.parentFolderLabel = parentFolderLabel.trimmed();

    passport.fallbackTitle = sourceFallbackTitle(passport.sourceType, passport.sourceLabel);
    passport.parsedFilenameSeries = guessSeriesFromFilename(passport.sourceLabel);
    passport.parsedIssue = guessIssueNumberFromFilename(passport.sourceLabel);

    QString folderSeries = guessSeriesFromFilename(passport.parentFolderLabel);
    if (isWeakSeriesName(folderSeries)) {
        folderSeries = passport.parentFolderLabel.trimmed();
    }
    passport.parsedFolderSeries = folderSeries.trimmed();

    passport.explicitSeries = trimmedAliasValue(importValues, { "series" });
    passport.explicitVolume = trimmedAliasValue(importValues, { "volume" });
    passport.explicitIssue = trimmedAliasValue(importValues, { "issueNumber", "issue" });
    passport.explicitTitle = trimmedAliasValue(importValues, { "title" });

    passport.contextSeries = trimmedAliasValue(importValues, {
        "importContextSeries",
        "seriesContext",
        "selectedSeriesContext"
    });
    if (passport.contextSeries.isEmpty()) {
        passport.contextSeries = passport.explicitSeries;
    }

    passport.comicInfoSeries = trimmedAliasValue(comicInfoValues, { "series" });
    passport.comicInfoVolume = trimmedAliasValue(comicInfoValues, { "volume" });
    passport.comicInfoIssue = trimmedAliasValue(comicInfoValues, { "issueNumber", "issue" });
    passport.comicInfoTitle = trimmedAliasValue(comicInfoValues, { "title" });

    passport.strictFilenameSignature = normalizeFilenameSignatureStrict(passport.sourceLabel);
    passport.looseFilenameSignature = normalizeFilenameSignatureLoose(passport.sourceLabel);

    if (!passport.explicitSeries.isEmpty()) {
        passport.effectiveSeries = passport.explicitSeries;
        passport.seriesSource = QStringLiteral("explicit");
    } else if (!passport.contextSeries.isEmpty()) {
        passport.effectiveSeries = passport.contextSeries;
        passport.seriesSource = QStringLiteral("context");
    } else if (!passport.comicInfoSeries.isEmpty() && !isWeakSeriesName(passport.comicInfoSeries)) {
        passport.effectiveSeries = passport.comicInfoSeries;
        passport.seriesSource = QStringLiteral("comicinfo");
    } else if (!isWeakSeriesName(passport.parsedFilenameSeries)) {
        passport.effectiveSeries = passport.parsedFilenameSeries;
        passport.seriesSource = QStringLiteral("filename");
    } else if (!passport.parsedFolderSeries.isEmpty() && !isWeakSeriesName(passport.parsedFolderSeries)) {
        passport.effectiveSeries = passport.parsedFolderSeries;
        passport.seriesSource = QStringLiteral("folder");
    } else {
        passport.effectiveSeries = passport.fallbackTitle;
        passport.seriesSource = QStringLiteral("fallback");
    }

    if (!passport.explicitVolume.isEmpty()) {
        passport.effectiveVolume = passport.explicitVolume;
        passport.volumeSource = QStringLiteral("explicit");
    } else if (!passport.comicInfoVolume.isEmpty()) {
        passport.effectiveVolume = passport.comicInfoVolume;
        passport.volumeSource = QStringLiteral("comicinfo");
    } else {
        passport.volumeSource = QStringLiteral("empty");
    }

    if (!passport.explicitIssue.isEmpty()) {
        passport.effectiveIssue = passport.explicitIssue;
        passport.issueSource = QStringLiteral("explicit");
    } else if (!passport.comicInfoIssue.isEmpty()) {
        passport.effectiveIssue = passport.comicInfoIssue;
        passport.issueSource = QStringLiteral("comicinfo");
    } else if (!passport.parsedIssue.isEmpty()) {
        passport.effectiveIssue = passport.parsedIssue;
        passport.issueSource = QStringLiteral("filename");
    } else {
        passport.issueSource = QStringLiteral("empty");
    }
    passport.effectiveIssue = normalizeStoredIssueNumber(passport.effectiveIssue);

    if (!passport.explicitTitle.isEmpty()) {
        passport.effectiveTitle = passport.explicitTitle;
        passport.titleSource = QStringLiteral("explicit");
    } else if (!passport.comicInfoTitle.isEmpty()) {
        passport.effectiveTitle = passport.comicInfoTitle;
        passport.titleSource = QStringLiteral("comicinfo");
    } else if (fallbackTitleRepeatsSeriesAndIssue(
                   passport.fallbackTitle,
                   passport.effectiveSeries,
                   passport.effectiveIssue
               )) {
        passport.titleSource = QStringLiteral("empty");
    } else {
        passport.effectiveTitle = passport.fallbackTitle;
        passport.titleSource = QStringLiteral("fallback");
    }

    passport.seriesKey = normalizeSeriesKey(passport.effectiveSeries);
    passport.volumeKey = normalizeVolumeKey(passport.effectiveVolume);
    passport.issueKey = normalizeIssueKey(passport.effectiveIssue);

    return passport;
}

QVariantMap applyPassportDefaults(
    const QVariantMap &importValues,
    const ImportIdentityPassport &passport
)
{
    QVariantMap result = importValues;

    if (trimmedAliasValue(result, { "importOriginalFilename" }).isEmpty() && !passport.sourceLabel.isEmpty()) {
        result.insert(QStringLiteral("importOriginalFilename"), passport.sourceLabel);
    }
    if (trimmedAliasValue(result, { "importSourceType" }).isEmpty() && !passport.sourceType.isEmpty()) {
        result.insert(QStringLiteral("importSourceType"), passport.sourceType);
    }
    if (trimmedAliasValue(result, { "importStrictFilenameSignature" }).isEmpty() && !passport.strictFilenameSignature.isEmpty()) {
        result.insert(QStringLiteral("importStrictFilenameSignature"), passport.strictFilenameSignature);
    }
    if (trimmedAliasValue(result, { "importLooseFilenameSignature" }).isEmpty() && !passport.looseFilenameSignature.isEmpty()) {
        result.insert(QStringLiteral("importLooseFilenameSignature"), passport.looseFilenameSignature);
    }

    if (trimmedAliasValue(result, { "series" }).isEmpty() && !passport.effectiveSeries.isEmpty()) {
        result.insert(QStringLiteral("series"), passport.effectiveSeries);
    }
    if (trimmedAliasValue(result, { "volume" }).isEmpty() && !passport.effectiveVolume.isEmpty()) {
        result.insert(QStringLiteral("volume"), passport.effectiveVolume);
    }
    if (trimmedAliasValue(result, { "issueNumber", "issue" }).isEmpty() && !passport.effectiveIssue.isEmpty()) {
        result.insert(QStringLiteral("issueNumber"), passport.effectiveIssue);
    }
    if (trimmedAliasValue(result, { "title" }).isEmpty() && !passport.effectiveTitle.isEmpty()) {
        result.insert(QStringLiteral("title"), passport.effectiveTitle);
    }

    return result;
}

} // namespace ComicImportMatching
