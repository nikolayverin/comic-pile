#pragma once

#include <QFileDevice>
#include <QString>
#include <QStringList>
#include <QVector>

namespace ComicDeleteOps {

struct DeleteFailureInfo {
    QString path;
    QString reasonCode;
    QString systemMessage;
};

struct StagedArchiveDeleteOp {
    int comicId = 0;
    QString originalPath;
    QString stagedPath;
    QString originalDirPath;
};

DeleteFailureInfo makeDeleteFailureInfo(
    const QString &rawPath,
    QFileDevice::FileError error,
    const QString &systemMessage
);
QString formatDeleteFailureLine(const DeleteFailureInfo &info);
bool tryRemoveFileWithDetails(
    const QString &filePath,
    QString &removedDirPathOut,
    DeleteFailureInfo &failureOut
);
bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText);
bool stageArchiveDelete(
    const QString &filePath,
    StagedArchiveDeleteOp &opOut,
    DeleteFailureInfo &failureOut
);
bool rollbackStagedArchiveDelete(const StagedArchiveDeleteOp &op, DeleteFailureInfo &failureOut);
bool finalizeStagedArchiveDelete(
    const StagedArchiveDeleteOp &op,
    QString &cleanupDirPathOut,
    DeleteFailureInfo &failureOut
);
QString rollbackStagedArchiveDeletes(const QVector<StagedArchiveDeleteOp> &ops);
void rememberPendingStagedDelete(const QString &dataRoot, const QString &filePath);
void forgetPendingStagedDelete(const QString &dataRoot, const QString &filePath);
void cleanupPendingStagedDeletes(const QString &dataRoot, const QString &libraryRootPath);
void cleanupEmptyLibraryDirs(const QString &libraryRootPath, const QStringList &candidateDirs);

} // namespace ComicDeleteOps
