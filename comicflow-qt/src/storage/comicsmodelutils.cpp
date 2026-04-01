#include "storage/comicsmodelutils.h"

#include "storage/importmatching.h"
#include "storage/storedpathutils.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QStringList>

namespace {

bool isPathInsideDirectory(const QString &candidatePath, const QString &directoryPath)
{
    const QFileInfo directoryInfo(QDir::fromNativeSeparators(directoryPath));
    const QFileInfo candidateInfo(QDir::fromNativeSeparators(candidatePath));
    const QString normalizedDirectory = QDir::cleanPath(directoryInfo.absoluteFilePath());
    const QString normalizedCandidate = QDir::cleanPath(candidateInfo.absoluteFilePath());
    if (normalizedDirectory.isEmpty() || normalizedCandidate.isEmpty()) return false;

    const QString directoryPrefix = normalizedDirectory.endsWith(QDir::separator())
        ? normalizedDirectory
        : normalizedDirectory + QDir::separator();
    return normalizedCandidate.compare(normalizedDirectory, Qt::CaseInsensitive) == 0
        || normalizedCandidate.startsWith(directoryPrefix, Qt::CaseInsensitive);
}

} // namespace

namespace ComicModelUtils {

QString normalizeSeriesKey(const QString &value)
{
    return ComicImportMatching::normalizeSeriesKey(value);
}

QString normalizeVolumeKey(const QString &value)
{
    return ComicImportMatching::normalizeVolumeKey(value);
}

QString normalizeReadStatus(const QString &value)
{
    QString normalized = value.trimmed().toLower();
    if (normalized.isEmpty()) return QStringLiteral("unread");

    normalized.replace('-', '_');
    normalized.replace(' ', '_');
    if (normalized == QStringLiteral("inprogress")) normalized = QStringLiteral("in_progress");

    if (normalized == QStringLiteral("unread")
        || normalized == QStringLiteral("in_progress")
        || normalized == QStringLiteral("read")) {
        return normalized;
    }

    return {};
}

QString makeGroupTitle(const QString &groupKey)
{
    if (groupKey.trimmed().isEmpty() || groupKey == QStringLiteral("unknown-series")) {
        return QStringLiteral("Unknown Series");
    }

    QStringList words = groupKey.split(' ', Qt::SkipEmptyParts);
    for (QString &word : words) {
        if (!word.isEmpty()) {
            word[0] = word[0].toUpper();
        }
    }
    return words.join(' ');
}

QString resolveLibraryFilePath(const QString &libraryPath, const QString &inputFilename)
{
    const QDir libraryDir(libraryPath);
    if (!libraryDir.exists()) return {};

    const QString rawInput = inputFilename.trimmed();
    if (rawInput.isEmpty()) return {};

    const QString normalizedInput = QDir::fromNativeSeparators(rawInput);
    const QFileInfo inputInfo(normalizedInput);

    if (inputInfo.isAbsolute()) {
        if (inputInfo.exists() && inputInfo.isFile()
            && isPathInsideDirectory(inputInfo.absoluteFilePath(), libraryDir.absolutePath())) {
            return QDir::toNativeSeparators(inputInfo.absoluteFilePath());
        }
    }

    const QFileInfo directRelative(libraryDir.filePath(normalizedInput));
    if (directRelative.exists() && directRelative.isFile()) {
        return QDir::toNativeSeparators(directRelative.absoluteFilePath());
    }

    const QString inputFileName = QFileInfo(normalizedInput).fileName().trimmed();
    if (inputFileName.isEmpty()) return {};
    const QString inputRelativeKey = QDir::cleanPath(normalizedInput).toLower();

    QString filenameMatchPath;
    QDirIterator iterator(
        libraryDir.absolutePath(),
        QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::Subdirectories
    );
    while (iterator.hasNext()) {
        const QString candidatePath = iterator.next();
        const QFileInfo candidateInfo(candidatePath);
        const QString candidateName = candidateInfo.fileName();
        if (candidateName.isEmpty()) continue;

        const QString relative = QDir::cleanPath(libraryDir.relativeFilePath(candidateInfo.absoluteFilePath()));
        if (!inputRelativeKey.isEmpty() && relative.toLower() == inputRelativeKey) {
            return QDir::toNativeSeparators(candidateInfo.absoluteFilePath());
        }

        bool nameMatches = candidateName.compare(inputFileName, Qt::CaseInsensitive) == 0;
        if (!nameMatches) {
            const int dashIndex = candidateName.indexOf('-');
            if (dashIndex > 0 && dashIndex + 1 < candidateName.length()) {
                const QString originalName = candidateName.mid(dashIndex + 1);
                nameMatches = originalName.compare(inputFileName, Qt::CaseInsensitive) == 0;
            }
        }
        if (!nameMatches) continue;
        if (filenameMatchPath.isEmpty()) {
            filenameMatchPath = candidateInfo.absoluteFilePath();
        }
    }

    return filenameMatchPath.isEmpty() ? QString() : QDir::toNativeSeparators(filenameMatchPath);
}

QString resolveStoredArchivePathForDataRoot(
    const QString &dataRoot,
    const QString &storedFilePath,
    const QString &storedFilename
)
{
    return ComicStoragePaths::resolveStoredArchivePath(dataRoot, storedFilePath, storedFilename);
}

QString baseNameWithoutExtension(const QString &filename)
{
    return QFileInfo(filename).completeBaseName();
}

} // namespace ComicModelUtils
