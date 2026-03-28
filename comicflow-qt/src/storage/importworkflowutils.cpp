#include "storage/importworkflowutils.h"

#include "storage/comicinfoops.h"

#include <QSet>

namespace {

QString valueFromMap(const QVariantMap &map, const QString &key)
{
    return map.value(key).toString().trimmed();
}

QString parentFolderNameForFile(const QFileInfo &fileInfo)
{
    const QString absolutePath = fileInfo.absolutePath();
    if (absolutePath.isEmpty()) return {};
    return QFileInfo(absolutePath).fileName().trimmed();
}

QVariantMap readComicInfoIdentityHints(const QString &archivePath)
{
    return ComicInfoOps::readComicInfoIdentityHints(archivePath);
}

QString normalizeImportIntentValue(const QString &value)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == QStringLiteral("global_add")
        || normalized == QStringLiteral("series_add")
        || normalized == QStringLiteral("issue_replace")) {
        return normalized;
    }
    return {};
}

bool hasNarrowImportSeriesContextImpl(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
)
{
    QString contextSeries = valueFromMap(values, QStringLiteral("importContextSeries")).trimmed();
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("seriesContext")).trimmed();
    }
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("selectedSeriesContext")).trimmed();
    }
    if (contextSeries.isEmpty()) {
        return false;
    }

    const QString contextSeriesKey = ComicImportMatching::normalizeSeriesKey(contextSeries);
    if (contextSeriesKey.isEmpty() || contextSeriesKey == QStringLiteral("unknown-series")) {
        return false;
    }

    return contextSeriesKey == effectiveSeriesKey.trimmed();
}

} // namespace

namespace ComicImportWorkflow {

PersistedImportSignals resolvePersistedImportSignals(
    const QVariantMap &values,
    const QString &fallbackOriginalFilename,
    const QString &fallbackSourceType
)
{
    PersistedImportSignals resolvedSignals;
    resolvedSignals.originalFilename = valueFromMap(values, QStringLiteral("importOriginalFilename"));
    if (resolvedSignals.originalFilename.isEmpty()) {
        resolvedSignals.originalFilename = fallbackOriginalFilename.trimmed();
    }

    resolvedSignals.sourceType = ComicImportMatching::normalizeImportSourceType(
        valueFromMap(values, QStringLiteral("importSourceType"))
    );
    if (resolvedSignals.sourceType.isEmpty()) {
        resolvedSignals.sourceType = ComicImportMatching::normalizeImportSourceType(fallbackSourceType);
    }
    if (resolvedSignals.sourceType.isEmpty()) {
        resolvedSignals.sourceType = QStringLiteral("archive");
    }

    resolvedSignals.strictFilenameSignature = valueFromMap(values, QStringLiteral("importStrictFilenameSignature"));
    if (resolvedSignals.strictFilenameSignature.isEmpty()) {
        resolvedSignals.strictFilenameSignature =
            ComicImportMatching::normalizeFilenameSignatureStrict(resolvedSignals.originalFilename);
    }

    resolvedSignals.looseFilenameSignature = valueFromMap(values, QStringLiteral("importLooseFilenameSignature"));
    if (resolvedSignals.looseFilenameSignature.isEmpty()) {
        resolvedSignals.looseFilenameSignature =
            ComicImportMatching::normalizeFilenameSignatureLoose(resolvedSignals.originalFilename);
    }

    return resolvedSignals;
}

QVariantMap importSignalsToVariantMap(const PersistedImportSignals &persistedSignals)
{
    QVariantMap values;
    values.insert(QStringLiteral("importOriginalFilename"), persistedSignals.originalFilename);
    values.insert(QStringLiteral("importStrictFilenameSignature"), persistedSignals.strictFilenameSignature);
    values.insert(QStringLiteral("importLooseFilenameSignature"), persistedSignals.looseFilenameSignature);
    values.insert(QStringLiteral("importSourceType"), persistedSignals.sourceType);
    return values;
}

QVariantMap withImportSeriesContext(const QVariantMap &values, const QString &seriesContext)
{
    QVariantMap result = values;
    const QString trimmedContext = seriesContext.trimmed();
    if (trimmedContext.isEmpty()) {
        return result;
    }

    if (valueFromMap(result, QStringLiteral("importContextSeries")).isEmpty()) {
        result.insert(QStringLiteral("importContextSeries"), trimmedContext);
    }
    if (valueFromMap(result, QStringLiteral("series")).isEmpty()) {
        result.insert(QStringLiteral("series"), trimmedContext);
    }
    return result;
}

QString ensureTargetCbzFilename(const QString &filenameHint, const QString &sourceFilename)
{
    auto stripKnownArchiveExtension = [](const QString &value) -> QString {
        const QString trimmedValue = value.trimmed();
        if (trimmedValue.isEmpty()) return {};

        const QFileInfo info(trimmedValue);
        const QString suffix = info.suffix().trimmed().toLower();
        static const QSet<QString> knownArchiveSuffixes = {
            QStringLiteral("cbz"),
            QStringLiteral("zip"),
            QStringLiteral("cbr"),
            QStringLiteral("rar"),
            QStringLiteral("7z"),
            QStringLiteral("cb7"),
            QStringLiteral("cbt"),
            QStringLiteral("tar"),
        };
        if (knownArchiveSuffixes.contains(suffix)) {
            return info.completeBaseName().trimmed();
        }
        return trimmedValue;
    };

    QString baseName = filenameHint.trimmed();
    if (!baseName.isEmpty()) {
        baseName = QFileInfo(baseName).fileName().trimmed();
        baseName = stripKnownArchiveExtension(baseName);
    } else {
        baseName = stripKnownArchiveExtension(QFileInfo(sourceFilename).fileName());
    }

    if (baseName.isEmpty()) {
        baseName = QStringLiteral("imported");
    }

    return QStringLiteral("%1.cbz").arg(baseName);
}

QString importIntentKey(const QVariantMap &values)
{
    const QString explicitIntent = normalizeImportIntentValue(valueFromMap(values, QStringLiteral("importIntent")));
    if (!explicitIntent.isEmpty()) {
        return explicitIntent;
    }

    QString contextSeries = valueFromMap(values, QStringLiteral("importContextSeries")).trimmed();
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("seriesContext")).trimmed();
    }
    if (contextSeries.isEmpty()) {
        contextSeries = valueFromMap(values, QStringLiteral("selectedSeriesContext")).trimmed();
    }
    if (!contextSeries.isEmpty()) {
        return QStringLiteral("series_add");
    }

    return {};
}

bool shouldAllowMetadataRestoreForImport(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
)
{
    const QString intent = importIntentKey(values);
    if (intent == QStringLiteral("global_add")) {
        return false;
    }
    if (intent == QStringLiteral("series_add")) {
        return hasNarrowImportSeriesContextImpl(values, effectiveSeriesKey);
    }
    return true;
}

bool hasNarrowImportSeriesContext(
    const QVariantMap &values,
    const QString &effectiveSeriesKey
)
{
    return hasNarrowImportSeriesContextImpl(values, effectiveSeriesKey);
}

ComicImportMatching::ImportIdentityPassport buildArchiveImportPassport(
    const QFileInfo &sourceInfo,
    const QString &normalizedSourcePath,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    QString passportSourcePath = valueFromMap(values, QStringLiteral("importHistorySourcePath"));
    if (passportSourcePath.isEmpty()) {
        passportSourcePath = normalizedSourcePath;
    }

    QString passportSourceLabel = valueFromMap(values, QStringLiteral("importHistorySourceLabel"));
    if (passportSourceLabel.isEmpty()) {
        passportSourceLabel = filenameHint.trimmed();
    }
    if (passportSourceLabel.isEmpty()) {
        passportSourceLabel = sourceInfo.fileName();
    } else {
        passportSourceLabel = QFileInfo(passportSourceLabel).fileName().trimmed();
    }

    QString passportParentFolderLabel = parentFolderNameForFile(sourceInfo);
    const QFileInfo originalSourceInfo(passportSourcePath);
    const QString originalParentFolderLabel = parentFolderNameForFile(originalSourceInfo);
    if (!originalParentFolderLabel.isEmpty()) {
        passportParentFolderLabel = originalParentFolderLabel;
    }

    return ComicImportMatching::buildImportIdentityPassport(
        QStringLiteral("archive"),
        passportSourcePath,
        passportSourceLabel,
        passportParentFolderLabel,
        filenameHint,
        values,
        readComicInfoIdentityHints(normalizedSourcePath)
    );
}

ComicImportMatching::ImportIdentityPassport buildImageFolderImportPassport(
    const QFileInfo &folderInfo,
    const QString &normalizedFolderPath,
    const QString &filenameHint,
    const QVariantMap &values
)
{
    return ComicImportMatching::buildImportIdentityPassport(
        QStringLiteral("image_folder"),
        normalizedFolderPath,
        folderInfo.fileName(),
        QFileInfo(folderInfo.absolutePath()).fileName().trimmed(),
        filenameHint,
        values
    );
}

} // namespace ComicImportWorkflow
