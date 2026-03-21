#include "storage/deletestagingops.h"

#include <algorithm>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QSet>
#include <QTextStream>
#include <QUuid>

namespace {

QString compactSystemMessage(const QString &message)
{
    const QString simplified = message.simplified();
    if (!simplified.isEmpty()) return simplified;
    return QStringLiteral("Unknown system error.");
}

QString classifyDeleteReasonCode(QFileDevice::FileError error, const QString &systemMessage)
{
    const QString lower = systemMessage.toLower();

    if (lower.contains(QStringLiteral("being used by another process"))
        || lower.contains(QStringLiteral("used by another process"))
        || lower.contains(QStringLiteral("sharing violation"))
        || lower.contains(QStringLiteral("in use"))
        || lower.contains(QStringLiteral("resource busy"))
        || lower.contains(QStringLiteral("device or resource busy"))) {
        return QStringLiteral("lock");
    }

    if (lower.contains(QStringLiteral("access is denied"))
        || lower.contains(QStringLiteral("permission denied"))
        || lower.contains(QStringLiteral("operation not permitted"))
        || lower.contains(QStringLiteral("access denied"))) {
        return QStringLiteral("access_denied");
    }

    if (lower.contains(QStringLiteral("path not found"))
        || lower.contains(QStringLiteral("cannot find the path"))
        || lower.contains(QStringLiteral("directory name is invalid"))
        || lower.contains(QStringLiteral("no such file"))
        || lower.contains(QStringLiteral("device is not ready"))
        || lower.contains(QStringLiteral("not ready"))) {
        return QStringLiteral("path_unavailable");
    }

    if (error == QFileDevice::PermissionsError) return QStringLiteral("access_denied");
    if (error == QFileDevice::OpenError || error == QFileDevice::ResourceError) return QStringLiteral("lock");

    return QStringLiteral("system_error");
}

QString normalizeInputFilePath(const QString &rawInput)
{
    const QString trimmed = rawInput.trimmed();
    if (trimmed.isEmpty()) return {};
    return QDir::toNativeSeparators(QFileInfo(QDir::fromNativeSeparators(trimmed)).absoluteFilePath());
}

bool ensureDirForFile(const QString &filePath)
{
    return QDir().mkpath(QFileInfo(filePath).absolutePath());
}

QString normalizedPathForCompare(const QString &path)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(QFileInfo(path).absoluteFilePath())).toLower();
}

QString buildStagedDeletePath(const QString &originalPath)
{
    const QFileInfo info(originalPath);
    const QDir dir(info.absolutePath());
    const QString token = QUuid::createUuid().toString(QUuid::WithoutBraces);
    return dir.filePath(
        QStringLiteral("%1%2%3")
            .arg(info.fileName(), QStringLiteral(".__comicpile_delete_pending__"), token)
    );
}

QString pendingStagedDeleteMarker()
{
    return QStringLiteral(".__comicpile_delete_pending__");
}

QString pendingStagedDeleteRegistryPath(const QString &dataRoot)
{
    return QDir(dataRoot).filePath(QStringLiteral(".runtime/pending-staged-deletes.txt"));
}

bool isPendingStagedDeletePath(const QString &filePath)
{
    return QFileInfo(filePath).fileName().contains(pendingStagedDeleteMarker(), Qt::CaseInsensitive);
}

QSet<QString> readPendingStagedDeleteRegistry(const QString &dataRoot)
{
    QSet<QString> paths;
    QFile file(pendingStagedDeleteRegistryPath(dataRoot));
    if (!file.exists()) {
        return paths;
    }
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return paths;
    }

    QTextStream stream(&file);
    while (!stream.atEnd()) {
        const QString normalizedPath = normalizeInputFilePath(stream.readLine());
        if (!normalizedPath.isEmpty()) {
            paths.insert(normalizedPath);
        }
    }
    return paths;
}

void writePendingStagedDeleteRegistry(const QString &dataRoot, const QSet<QString> &paths)
{
    const QString registryPath = pendingStagedDeleteRegistryPath(dataRoot);
    if (paths.isEmpty()) {
        QFile::remove(registryPath);
        return;
    }

    if (!ensureDirForFile(registryPath)) {
        return;
    }

    QStringList lines = paths.values();
    std::sort(lines.begin(), lines.end(), [](const QString &left, const QString &right) {
        return left.compare(right, Qt::CaseInsensitive) < 0;
    });

    QSaveFile file(registryPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return;
    }

    QTextStream stream(&file);
    for (const QString &line : lines) {
        stream << line << '\n';
    }
    file.commit();
}

} // namespace

namespace ComicDeleteOps {

DeleteFailureInfo makeDeleteFailureInfo(
    const QString &rawPath,
    QFileDevice::FileError error,
    const QString &systemMessage
)
{
    DeleteFailureInfo info;
    info.path = QDir::toNativeSeparators(QFileInfo(rawPath).absoluteFilePath());
    info.systemMessage = compactSystemMessage(systemMessage);
    info.reasonCode = classifyDeleteReasonCode(error, info.systemMessage);
    return info;
}

QString formatDeleteFailureLine(const DeleteFailureInfo &info)
{
    return QStringLiteral("Path: %1 | Reason: %2 | System: %3")
        .arg(info.path, info.reasonCode, info.systemMessage);
}

bool tryRemoveFileWithDetails(
    const QString &filePath,
    QString &removedDirPathOut,
    DeleteFailureInfo &failureOut
)
{
    removedDirPathOut.clear();

    QFile file(filePath);
    if (!file.exists()) {
        return true;
    }

    if (file.remove()) {
        removedDirPathOut = QFileInfo(filePath).absolutePath();
        return true;
    }

    failureOut = makeDeleteFailureInfo(filePath, file.error(), file.errorString());
    return false;
}

bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText)
{
    errorText.clear();
    const QString sourceAbs = QDir::toNativeSeparators(QFileInfo(sourcePath).absoluteFilePath());
    const QString targetAbs = QDir::toNativeSeparators(QFileInfo(targetPath).absoluteFilePath());
    if (sourceAbs.isEmpty() || targetAbs.isEmpty()) {
        errorText = QStringLiteral("Invalid source/target path for move.");
        return false;
    }
    if (normalizedPathForCompare(sourceAbs) == normalizedPathForCompare(targetAbs)) {
        return true;
    }

    const QFileInfo sourceInfo(sourceAbs);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        errorText = QStringLiteral("Source file does not exist: %1").arg(sourceAbs);
        return false;
    }

    if (!ensureDirForFile(targetAbs)) {
        errorText = QStringLiteral("Failed to create target folder: %1").arg(QFileInfo(targetAbs).absolutePath());
        return false;
    }
    if (QFileInfo::exists(targetAbs)) {
        errorText = QStringLiteral("Target file already exists: %1").arg(targetAbs);
        return false;
    }

    QFile sourceFile(sourceAbs);
    if (sourceFile.rename(targetAbs)) {
        return true;
    }

    if (!QFile::copy(sourceAbs, targetAbs)) {
        errorText = QStringLiteral("Failed to move file to target path: %1").arg(targetAbs);
        return false;
    }
    if (!QFile::remove(sourceAbs)) {
        QFile::remove(targetAbs);
        errorText = QStringLiteral("Failed to remove source file after copy: %1").arg(sourceAbs);
        return false;
    }
    return true;
}

bool stageArchiveDelete(
    const QString &filePath,
    StagedArchiveDeleteOp &opOut,
    DeleteFailureInfo &failureOut
)
{
    opOut = {};
    failureOut = {};

    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        return true;
    }

    const QFileInfo info(normalizedPath);
    opOut.originalPath = QDir::toNativeSeparators(info.absoluteFilePath());
    opOut.originalDirPath = info.absolutePath();
    if (!info.exists()) {
        return true;
    }
    if (!info.isFile()) {
        failureOut = makeDeleteFailureInfo(
            normalizedPath,
            QFileDevice::RemoveError,
            QStringLiteral("Archive path is not a file.")
        );
        return false;
    }

    QString moveError;
    const QString stagedPath = buildStagedDeletePath(opOut.originalPath);
    if (!moveFileWithFallback(opOut.originalPath, stagedPath, moveError)) {
        failureOut = makeDeleteFailureInfo(opOut.originalPath, QFileDevice::RenameError, moveError);
        return false;
    }

    opOut.stagedPath = QDir::toNativeSeparators(QFileInfo(stagedPath).absoluteFilePath());
    return true;
}

bool rollbackStagedArchiveDelete(const StagedArchiveDeleteOp &op, DeleteFailureInfo &failureOut)
{
    failureOut = {};
    if (op.stagedPath.trimmed().isEmpty()) {
        return true;
    }

    QString rollbackError;
    if (moveFileWithFallback(op.stagedPath, op.originalPath, rollbackError)) {
        return true;
    }

    failureOut = makeDeleteFailureInfo(
        op.originalPath,
        QFileDevice::RenameError,
        QStringLiteral("Rollback failed: %1").arg(rollbackError)
    );
    return false;
}

bool finalizeStagedArchiveDelete(
    const StagedArchiveDeleteOp &op,
    QString &cleanupDirPathOut,
    DeleteFailureInfo &failureOut
)
{
    cleanupDirPathOut = op.originalDirPath;
    failureOut = {};

    if (op.stagedPath.trimmed().isEmpty()) {
        return true;
    }

    QString removedDirPath;
    if (tryRemoveFileWithDetails(op.stagedPath, removedDirPath, failureOut)) {
        if (cleanupDirPathOut.isEmpty()) {
            cleanupDirPathOut = removedDirPath;
        }
        return true;
    }

    if (!op.originalPath.trimmed().isEmpty()) {
        failureOut.path = QDir::toNativeSeparators(QFileInfo(op.originalPath).absoluteFilePath());
    }
    return false;
}

QString rollbackStagedArchiveDeletes(const QVector<StagedArchiveDeleteOp> &ops)
{
    QStringList rollbackLines;
    for (int i = ops.size() - 1; i >= 0; i -= 1) {
        DeleteFailureInfo failure;
        if (!rollbackStagedArchiveDelete(ops.at(i), failure)) {
            rollbackLines.push_back(formatDeleteFailureLine(failure));
        }
    }
    return rollbackLines.join(QLatin1Char('\n'));
}

void rememberPendingStagedDelete(const QString &dataRoot, const QString &filePath)
{
    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty() || !isPendingStagedDeletePath(normalizedPath)) {
        return;
    }

    QSet<QString> paths = readPendingStagedDeleteRegistry(dataRoot);
    paths.insert(normalizedPath);
    writePendingStagedDeleteRegistry(dataRoot, paths);
}

void forgetPendingStagedDelete(const QString &dataRoot, const QString &filePath)
{
    const QString normalizedPath = normalizeInputFilePath(filePath);
    if (normalizedPath.isEmpty()) {
        return;
    }

    QSet<QString> paths = readPendingStagedDeleteRegistry(dataRoot);
    if (!paths.remove(normalizedPath)) {
        return;
    }
    writePendingStagedDeleteRegistry(dataRoot, paths);
}

void cleanupPendingStagedDeletes(const QString &dataRoot, const QString &libraryRootPath)
{
    const QSet<QString> pendingPaths = readPendingStagedDeleteRegistry(dataRoot);
    if (pendingPaths.isEmpty()) {
        return;
    }

    QSet<QString> remainingPaths;
    QStringList cleanupDirs;
    for (const QString &path : pendingPaths) {
        const QString normalizedPath = normalizeInputFilePath(path);
        if (normalizedPath.isEmpty() || !isPendingStagedDeletePath(normalizedPath)) {
            continue;
        }

        QString cleanupDirPath;
        DeleteFailureInfo failure;
        if (tryRemoveFileWithDetails(normalizedPath, cleanupDirPath, failure)) {
            if (cleanupDirPath.isEmpty()) {
                cleanupDirPath = QFileInfo(normalizedPath).absolutePath();
            }
            if (!cleanupDirPath.isEmpty()) {
                cleanupDirs.push_back(cleanupDirPath);
            }
            continue;
        }

        remainingPaths.insert(normalizedPath);
    }

    writePendingStagedDeleteRegistry(dataRoot, remainingPaths);
    if (!cleanupDirs.isEmpty()) {
        cleanupEmptyLibraryDirs(libraryRootPath, cleanupDirs);
    }
}

void cleanupEmptyLibraryDirs(const QString &libraryRootPath, const QStringList &candidateDirs)
{
    const QString libraryRoot = normalizedPathForCompare(libraryRootPath);
    if (libraryRoot.isEmpty()) return;

    QSet<QString> visited;
    for (const QString &candidate : candidateDirs) {
        QString current = QDir::toNativeSeparators(QFileInfo(candidate).absoluteFilePath());
        while (!current.isEmpty()) {
            const QString currentKey = normalizedPathForCompare(current);
            if (currentKey.isEmpty()) break;
            if (currentKey == libraryRoot) break;
            if (!currentKey.startsWith(libraryRoot + QStringLiteral("/"))) break;
            if (visited.contains(currentKey)) break;
            visited.insert(currentKey);

            QDir currentDir(current);
            if (!currentDir.exists()) {
                current = QFileInfo(current).absolutePath();
                continue;
            }

            const QStringList entries = currentDir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot);
            if (!entries.isEmpty()) break;

            const QFileInfo info(current);
            const QString parentPath = info.absolutePath();
            QDir parentDir(parentPath);
            if (!parentDir.rmdir(info.fileName())) {
                break;
            }

            current = parentPath;
        }
    }
}

} // namespace ComicDeleteOps
