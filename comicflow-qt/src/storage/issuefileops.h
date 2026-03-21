#pragma once

#include <QString>
#include <QVariantMap>
#include <QVector>

namespace ComicIssueFileOps {

struct ComicFilePathBinding {
    int comicId = 0;
    QString filePath;
};

struct RelinkInput {
    int comicId = 0;
    QString absoluteFilePath;
    QString filename;
    bool updateImportSignals = false;
    QString importOriginalFilename;
    QString importStrictFilenameSignature;
    QString importLooseFilenameSignature;
    QString importSourceType;
};

QString applyComicFilePathBindings(
    const QString &dbPath,
    const QVector<ComicFilePathBinding> &bindings,
    const QString &connectionTag
);

QString loadComicFilePath(
    const QString &dbPath,
    int comicId,
    QString &filePathOut
);

QString hardDeleteComicRecord(
    const QString &dbPath,
    int comicId,
    QString &deletedFilePathOut
);

QString relinkComicFileKeepMetadata(
    const QString &dbPath,
    const RelinkInput &input
);

} // namespace ComicIssueFileOps
