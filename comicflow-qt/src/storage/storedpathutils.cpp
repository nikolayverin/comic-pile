#include "storage/storedpathutils.h"

#include "storage/librarylayoututils.h"

#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QUrl>

namespace {

QString cleanNativePath(const QString &path)
{
    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty()) return {};
    return QDir::toNativeSeparators(QDir::cleanPath(QDir::fromNativeSeparators(trimmed)));
}

QString absoluteNativeFilePath(const QString &path)
{
    const QString normalized = ComicStoragePaths::normalizePathInput(path);
    if (normalized.isEmpty()) return {};

    const QFileInfo info(QDir::fromNativeSeparators(normalized));
    if (!info.isAbsolute()) {
        return {};
    }

    return QDir::toNativeSeparators(QFileInfo(info.absoluteFilePath()).absoluteFilePath());
}

bool isInsideRootPath(const QString &candidatePath, const QString &rootPath)
{
    const QString normalizedCandidate = ComicLibraryLayout::normalizedPathForCompare(candidatePath);
    const QString normalizedRoot = ComicLibraryLayout::normalizedPathForCompare(rootPath);
    if (normalizedCandidate.isEmpty() || normalizedRoot.isEmpty()) return false;
    if (normalizedCandidate == normalizedRoot) return true;
    return normalizedCandidate.startsWith(normalizedRoot + QStringLiteral("/"));
}

void appendUnique(QStringList &values, QSet<QString> &seen, const QString &value)
{
    const QString cleaned = cleanNativePath(value);
    if (cleaned.isEmpty()) return;

    const QString key = cleaned.toLower();
    if (seen.contains(key)) return;

    seen.insert(key);
    values.push_back(cleaned);
}

QString libraryRootPath(const QString &dataRoot)
{
    return QDir(dataRoot).filePath(QStringLiteral("Library"));
}

} // namespace

namespace ComicStoragePaths {

QString normalizePathInput(const QString &rawInput)
{
    QString input = rawInput.trimmed();
    if (input.isEmpty()) return {};

    if ((input.startsWith(QLatin1Char('"')) && input.endsWith(QLatin1Char('"')))
        || (input.startsWith(QLatin1Char('\'')) && input.endsWith(QLatin1Char('\'')))) {
        input = input.mid(1, input.length() - 2).trimmed();
    }

    const QUrl url = QUrl::fromUserInput(input);
    if (url.isValid() && url.isLocalFile()) {
        return QDir::toNativeSeparators(url.toLocalFile());
    }

    return QDir::toNativeSeparators(input);
}

QString persistPathForRoot(const QString &rootPath, const QString &absolutePath)
{
    const QString absoluteNativePath = absoluteNativeFilePath(absolutePath);
    if (absoluteNativePath.isEmpty()) {
        return cleanNativePath(absolutePath);
    }

    const QFileInfo rootInfo(rootPath);
    const QString absoluteRootPath = QDir::toNativeSeparators(rootInfo.absoluteFilePath());
    if (!isInsideRootPath(absoluteNativePath, absoluteRootPath)) {
        return absoluteNativePath;
    }

    const QString relativePath = QDir(absoluteRootPath).relativeFilePath(absoluteNativePath);
    return cleanNativePath(relativePath);
}

QString persistPathForDataRoot(const QString &dataRoot, const QString &absolutePath)
{
    return persistPathForRoot(dataRoot, absolutePath);
}

QString resolveStoredPathAgainstRoot(
    const QString &rootPath,
    const QString &storedPath,
    const QString &storedFilename
)
{
    QString candidatePath = normalizePathInput(storedPath);
    if (!candidatePath.isEmpty()) {
        const QString cleanedStoredPath = QDir::cleanPath(QDir::fromNativeSeparators(candidatePath));
        const QFileInfo storedPathInfo(cleanedStoredPath);
        if (storedPathInfo.isAbsolute()) {
            candidatePath = storedPathInfo.absoluteFilePath();
        } else {
            candidatePath = QDir(rootPath).absoluteFilePath(cleanedStoredPath);
        }
    } else {
        const QString filenameInput = storedFilename.trimmed();
        if (filenameInput.isEmpty()) return {};

        const QString normalizedFilename = QDir::cleanPath(QDir::fromNativeSeparators(filenameInput));
        const QFileInfo filenameInfo(normalizedFilename);
        if (filenameInfo.isAbsolute()) {
            candidatePath = filenameInfo.absoluteFilePath();
        } else {
            candidatePath = QDir(rootPath).absoluteFilePath(normalizedFilename);
        }
    }

    const QFileInfo candidateInfo(candidatePath);
    if (!candidateInfo.exists() || !candidateInfo.isFile()) {
        return {};
    }

    return QDir::toNativeSeparators(candidateInfo.absoluteFilePath());
}

QString resolveStoredArchivePath(
    const QString &dataRoot,
    const QString &storedFilePath,
    const QString &storedFilename
)
{
    const QString libraryPath = libraryRootPath(dataRoot);

    QString candidatePath = normalizePathInput(storedFilePath);
    if (!candidatePath.isEmpty()) {
        const QString cleanedStoredPath = QDir::cleanPath(QDir::fromNativeSeparators(candidatePath));
        const QFileInfo storedPathInfo(cleanedStoredPath);
        if (storedPathInfo.isAbsolute()) {
            candidatePath = storedPathInfo.absoluteFilePath();
        } else if (cleanedStoredPath.compare(QStringLiteral("Library"), Qt::CaseInsensitive) == 0
                   || cleanedStoredPath.startsWith(QStringLiteral("Library/"), Qt::CaseInsensitive)) {
            candidatePath = QDir(dataRoot).absoluteFilePath(cleanedStoredPath);
        } else {
            candidatePath = QDir(libraryPath).absoluteFilePath(cleanedStoredPath);
        }
    } else {
        candidatePath = resolveStoredPathAgainstRoot(libraryPath, QString(), storedFilename);
        if (!candidatePath.isEmpty()) {
            return candidatePath;
        }
        return {};
    }

    const QFileInfo candidateInfo(candidatePath);
    if (!candidateInfo.exists() || !candidateInfo.isFile()) {
        return {};
    }

    return QDir::toNativeSeparators(candidateInfo.absoluteFilePath());
}

QStringList archivePathLookupCandidates(const QString &dataRoot, const QString &path)
{
    QStringList candidates;
    QSet<QString> seen;

    const QString normalizedPath = normalizePathInput(path);
    if (normalizedPath.isEmpty()) {
        return candidates;
    }

    const QString cleanedPath = cleanNativePath(normalizedPath);
    const QFileInfo pathInfo(QDir::fromNativeSeparators(cleanedPath));
    const QString libraryPath = libraryRootPath(dataRoot);

    if (pathInfo.isAbsolute()) {
        const QString absolutePath = QDir::toNativeSeparators(pathInfo.absoluteFilePath());
        appendUnique(candidates, seen, absolutePath);
        appendUnique(candidates, seen, persistPathForDataRoot(dataRoot, absolutePath));
        appendUnique(candidates, seen, persistPathForRoot(libraryPath, absolutePath));
        return candidates;
    }

    appendUnique(candidates, seen, cleanedPath);

    if (cleanedPath.compare(QStringLiteral("Library"), Qt::CaseInsensitive) == 0
        || cleanedPath.startsWith(QStringLiteral("Library\\"), Qt::CaseInsensitive)
        || cleanedPath.startsWith(QStringLiteral("Library/"), Qt::CaseInsensitive)) {
        const QString absolutePath = QDir(dataRoot).absoluteFilePath(QDir::fromNativeSeparators(cleanedPath));
        appendUnique(candidates, seen, absolutePath);
        appendUnique(candidates, seen, persistPathForRoot(libraryPath, absolutePath));
    } else {
        const QString absolutePath = QDir(libraryPath).absoluteFilePath(QDir::fromNativeSeparators(cleanedPath));
        appendUnique(candidates, seen, absolutePath);
        appendUnique(candidates, seen, persistPathForDataRoot(dataRoot, absolutePath));
    }

    return candidates;
}

} // namespace ComicStoragePaths
