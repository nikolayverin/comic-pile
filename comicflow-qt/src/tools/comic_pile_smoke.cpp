#include "storage/comicslistmodel.h"
#include "common/scopedsqlconnectionremoval.h"

#include <QByteArray>
#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QProcess>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTextStream>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

namespace {

void printStepResult(const QString &name, bool ok, const QString &details = {})
{
    QTextStream out(stdout);
    QTextStream err(stderr);
    if (ok) {
        out << QString("[OK] %1%2\n")
                   .arg(name, details.isEmpty() ? QString() : QString(": %1").arg(details));
        out.flush();
        return;
    }

    err << QString("[FAIL] %1%2\n")
               .arg(name, details.isEmpty() ? QString() : QString(": %1").arg(details));
    err.flush();
}

QString findWorkspaceRoot()
{
    QDir dir(QDir::currentPath());
    for (int depth = 0; depth < 12; depth += 1) {
        const bool hasProject = QFileInfo::exists(dir.filePath("PROJECT_BIBLE.md"));
        const bool hasQtDir = QFileInfo::exists(dir.filePath("comicflow-qt/CMakeLists.txt"));
        if (hasProject && hasQtDir) {
            return dir.absolutePath();
        }
        if (!dir.cdUp()) break;
    }
    return {};
}

QString findSeedArchive(const QString &workspaceRoot)
{
    const QStringList candidateDirs = {
        QDir(workspaceRoot).filePath("Database/Library"),
        QDir(workspaceRoot).filePath("Database/SeedScrollTest"),
    };
    for (const QString &dirPath : candidateDirs) {
        QDirIterator it(
            dirPath,
            { "*.cbz", "*.zip", "*.cbr" },
            QDir::Files | QDir::NoSymLinks,
            QDirIterator::Subdirectories
        );
        while (it.hasNext()) {
            return it.next();
        }
    }

    const QStringList recursiveRoots = {
        QDir(workspaceRoot).filePath("_tmp"),
        QDir(workspaceRoot).filePath("Library"),
        workspaceRoot,
    };
    for (const QString &rootPath : recursiveRoots) {
        if (!QFileInfo::exists(rootPath)) continue;

        QDirIterator it(
            rootPath,
            { "*.cbz", "*.zip", "*.cbr" },
            QDir::Files | QDir::NoSymLinks,
            QDirIterator::Subdirectories
        );
        while (it.hasNext()) {
            const QString archivePath = it.next();
            const QString normalizedPath = QDir::fromNativeSeparators(archivePath);
            if (normalizedPath.contains(QStringLiteral("/_build/"), Qt::CaseInsensitive)
                || normalizedPath.contains(QStringLiteral("/tools/"), Qt::CaseInsensitive)
                || normalizedPath.contains(QStringLiteral("/.git/"), Qt::CaseInsensitive)) {
                continue;
            }
            return archivePath;
        }
    }

    return {};
}

bool copyFileStrict(const QString &sourcePath, const QString &targetPath, QString &error)
{
    QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        error = QString("Source file not found: %1").arg(sourcePath);
        return false;
    }

    QFileInfo targetInfo(targetPath);
    QDir targetDir = targetInfo.dir();
    if (!targetDir.exists() && !targetDir.mkpath(".")) {
        error = QString("Failed to create target directory: %1").arg(targetDir.absolutePath());
        return false;
    }

    QFile::remove(targetPath);
    if (!QFile::copy(sourcePath, targetPath)) {
        error = QString("Failed to copy %1 -> %2").arg(sourcePath, targetPath);
        return false;
    }
    return true;
}

bool writeBinaryFile(const QString &targetPath, const QByteArray &bytes, QString &error)
{
    QFileInfo targetInfo(targetPath);
    QDir targetDir = targetInfo.dir();
    if (!targetDir.exists() && !targetDir.mkpath(".")) {
        error = QString("Failed to create target directory: %1").arg(targetDir.absolutePath());
        return false;
    }

    QFile file(targetPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        error = QString("Failed to open %1 for writing.").arg(targetPath);
        return false;
    }
    if (file.write(bytes) != bytes.size()) {
        error = QString("Failed to write test image: %1").arg(targetPath);
        return false;
    }
    file.close();
    return true;
}

QByteArray tinyBmpBytes()
{
    static const QByteArray encoded =
        "424d3a0000000000000036000000280000000100000001000000010018000000000004000000130b0000130b000000000000000000000000ff00";
    return QByteArray::fromHex(encoded);
}

bool archiveContainsImages(const QString &archivePath, QString &details)
{
    details.clear();

    const QFileInfo info(archivePath);
    if (!info.exists() || !info.isFile()) {
        details = QStringLiteral("Archive file not found.");
        return false;
    }

    QString quotedArchivePath = archivePath;
    quotedArchivePath.replace('\'', QLatin1String("''"));

    const QString script = QString(
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\n"
        "Add-Type -AssemblyName System.IO.Compression\n"
        "Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
        "$archivePath = '%1'\n"
        "$exts = @('.jpg','.jpeg','.png','.bmp','.webp')\n"
        "try {\n"
        "  $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)\n"
        "  try {\n"
        "    $count = 0\n"
        "    foreach ($entry in $zip.Entries) {\n"
        "      if ([string]::IsNullOrEmpty($entry.Name)) { continue }\n"
        "      $entryExt = [System.IO.Path]::GetExtension($entry.FullName).ToLowerInvariant()\n"
        "      if ($exts -contains $entryExt) { $count += 1 }\n"
        "    }\n"
        "    [Console]::WriteLine($count)\n"
        "  } finally {\n"
        "    $zip.Dispose()\n"
        "  }\n"
        "} catch {\n"
        "  [Console]::Error.WriteLine($_.Exception.Message)\n"
        "  exit 2\n"
        "}\n"
    ).arg(quotedArchivePath);

    QProcess process;
    process.setProgram(QStringLiteral("powershell"));
    process.setArguments({
        QStringLiteral("-NoProfile"),
        QStringLiteral("-ExecutionPolicy"),
        QStringLiteral("Bypass"),
        QStringLiteral("-Command"),
        script
    });
    process.start();

    if (!process.waitForStarted(15000)) {
        details = QStringLiteral("Failed to start PowerShell.");
        return false;
    }
    if (!process.waitForFinished(15000)) {
        process.kill();
        process.waitForFinished(5000);
        details = QStringLiteral("PowerShell timed out.");
        return false;
    }

    const QString stdErr = QString::fromUtf8(process.readAllStandardError()).trimmed();
    const QString stdOut = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        details = stdErr.isEmpty() ? QStringLiteral("PowerShell zip scan failed.") : stdErr;
        return false;
    }

    bool ok = false;
    const int count = stdOut.toInt(&ok);
    details = QStringLiteral("count=%1").arg(stdOut);
    return ok && count > 0;
}

bool initIsolatedDatabase(const QString &dbPath, QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_smoke_init_db");
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            error = QString("Failed to open isolated DB: %1").arg(db.lastError().text());
            return false;
        }

        auto execSql = [&](const QString &sql) -> bool {
            QSqlQuery query(db);
            if (!query.exec(sql)) {
                error = QString("SQL failed: %1").arg(query.lastError().text());
                return false;
            }
            return true;
        };

        if (!execSql(
                "CREATE TABLE IF NOT EXISTS comics ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                "file_path TEXT DEFAULT '',"
                "filename TEXT DEFAULT '',"
                "series TEXT DEFAULT '',"
                "series_key TEXT DEFAULT '',"
                "volume TEXT DEFAULT '',"
                "title TEXT DEFAULT '',"
                "issue_number TEXT DEFAULT '',"
                "issue TEXT DEFAULT '',"
                "publisher TEXT DEFAULT '',"
                "year INTEGER,"
                "month INTEGER,"
                "writer TEXT DEFAULT '',"
                "penciller TEXT DEFAULT '',"
                "inker TEXT DEFAULT '',"
                "colorist TEXT DEFAULT '',"
                "letterer TEXT DEFAULT '',"
                "cover_artist TEXT DEFAULT '',"
                "editor TEXT DEFAULT '',"
                "story_arc TEXT DEFAULT '',"
                "summary TEXT DEFAULT '',"
                "characters TEXT DEFAULT '',"
                "genres TEXT DEFAULT '',"
                "age_rating TEXT DEFAULT '',"
                "read_status TEXT DEFAULT 'unread',"
                "current_page INTEGER DEFAULT 0,"
                "added_date TEXT DEFAULT (datetime('now'))"
                ")")) {
            db.close();
            return false;
        }

        if (!execSql(
                "CREATE TABLE IF NOT EXISTS series_metadata ("
                "series_group_key TEXT PRIMARY KEY,"
                "series_title TEXT NOT NULL DEFAULT '',"
                "series_summary TEXT NOT NULL DEFAULT '',"
                "updated_at TEXT NOT NULL DEFAULT (datetime('now'))"
                ")")) {
            db.close();
            return false;
        }

        if (!execSql(QStringLiteral("PRAGMA user_version = 2"))) {
            db.close();
            return false;
        }

        db.close();
    }
    return true;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    const QString workspaceRoot = findWorkspaceRoot();
    if (workspaceRoot.isEmpty()) {
        printStepResult(QStringLiteral("Smoke setup"), false, QStringLiteral("Could not locate project root."));
        return 1;
    }

    const QString seedArchivePath = findSeedArchive(workspaceRoot);
    if (seedArchivePath.isEmpty()) {
        printStepResult(QStringLiteral("Smoke setup"), false, QStringLiteral("No archive fixture found."));
        return 1;
    }

    QTemporaryDir sandbox;
    if (!sandbox.isValid()) {
        printStepResult(QStringLiteral("Smoke setup"), false, QStringLiteral("Failed to create temporary sandbox."));
        return 1;
    }
    const QString dataRoot = sandbox.path();
    const QString libraryDirPath = QDir(dataRoot).filePath(QStringLiteral("Library"));
    const QString incomingDirPath = QDir(dataRoot).filePath(QStringLiteral("Incoming"));
    if (!QDir().mkpath(libraryDirPath) || !QDir().mkpath(incomingDirPath)) {
        printStepResult(QStringLiteral("Smoke setup"), false, QStringLiteral("Failed to create sandbox folders."));
        return 1;
    }

    QString setupError;
    const QString dbPath = QDir(dataRoot).filePath(QStringLiteral("library.db"));
    if (!initIsolatedDatabase(dbPath, setupError)) {
        printStepResult(QStringLiteral("Smoke setup"), false, setupError);
        return 1;
    }

    const QString ext = QFileInfo(seedArchivePath).suffix().toLower();
    const QString incomingPath = QDir(incomingDirPath).filePath(QStringLiteral("smoke_incoming.%1").arg(ext));
    if (!copyFileStrict(seedArchivePath, incomingPath, setupError)) {
        printStepResult(QStringLiteral("Smoke setup"), false, setupError);
        return 1;
    }

    qputenv("COMIC_PILE_DATA_DIR", dataRoot.toUtf8());
    ComicsListModel model;
    if (!model.lastError().trimmed().isEmpty()) {
        printStepResult(QStringLiteral("Model load"), false, model.lastError());
        return 1;
    }
    printStepResult(QStringLiteral("Model load"), true);

    const QString configured7zPath = model.configuredSevenZipExecutablePath();
    const QStringList supportedExtensions = model.supportedImportArchiveExtensions();
    if (configured7zPath.isEmpty()
        || !QFileInfo::exists(configured7zPath)
        || !model.isCbrBackendAvailable()
        || !supportedExtensions.contains(QStringLiteral("cbr"), Qt::CaseInsensitive)) {
        printStepResult(
            QStringLiteral("Bundled 7z Detection"),
            false,
            QStringLiteral("path=%1 cbrAvailable=%2 hasCbr=%3")
                .arg(configured7zPath)
                .arg(model.isCbrBackendAvailable() ? QStringLiteral("true") : QStringLiteral("false"))
                .arg(supportedExtensions.contains(QStringLiteral("cbr"), Qt::CaseInsensitive) ? QStringLiteral("true") : QStringLiteral("false"))
        );
        return 1;
    }
    printStepResult(QStringLiteral("Bundled 7z Detection"), true, configured7zPath);

    const QString nestedBatchRoot = QDir(incomingDirPath).filePath(QStringLiteral("drop-batch"));
    const QString nestedArchiveOne = QDir(nestedBatchRoot).filePath(QStringLiteral("Series One/series-one-001.%1").arg(ext));
    const QString nestedArchiveTwo = QDir(nestedBatchRoot).filePath(QStringLiteral("Series Two/Season A/series-two-002.%1").arg(ext));
    if (!copyFileStrict(seedArchivePath, nestedArchiveOne, setupError)
        || !copyFileStrict(seedArchivePath, nestedArchiveTwo, setupError)) {
        printStepResult(QStringLiteral("Expand Import Sources"), false, setupError);
        return 1;
    }

    const QVariantList expandedSources = model.expandImportSources(
        QVariantList{
            nestedBatchRoot,
            nestedArchiveOne,
            QStringLiteral("E:/does/not/exist/nope.cbz")
        },
        true
    );
    QSet<QString> expandedSourceSet;
    for (const QVariant &entryValue : expandedSources) {
        const QVariantMap entry = entryValue.toMap();
        const QString path = entry.value(QStringLiteral("path")).toString();
        const QString sourceType = entry.value(QStringLiteral("sourceType")).toString();
        expandedSourceSet.insert(QStringLiteral("%1|%2").arg(sourceType, path));
    }
    const QSet<QString> expectedExpandedSources = {
        QStringLiteral("archive|%1").arg(QDir::toNativeSeparators(QFileInfo(nestedArchiveOne).absoluteFilePath())),
        QStringLiteral("archive|%1").arg(QDir::toNativeSeparators(QFileInfo(nestedArchiveTwo).absoluteFilePath()))
    };
    if (expandedSourceSet != expectedExpandedSources || expandedSources.size() != expectedExpandedSources.size()) {
        printStepResult(
            QStringLiteral("Expand Import Sources"),
            false,
            QStringLiteral("Expanded paths do not match recursive folder contents.")
        );
        return 1;
    }
    printStepResult(QStringLiteral("Expand Import Sources"), true);

    const QString imageFolderPath = QDir(incomingDirPath).filePath(QStringLiteral("Spawn 001"));
    if (!writeBinaryFile(QDir(imageFolderPath).filePath(QStringLiteral("001.bmp")), tinyBmpBytes(), setupError)
        || !writeBinaryFile(QDir(imageFolderPath).filePath(QStringLiteral("002.bmp")), tinyBmpBytes(), setupError)) {
        printStepResult(QStringLiteral("Image Folder Setup"), false, setupError);
        return 1;
    }

    const QVariantList expandedImageFolderSources = model.expandImportSources(QVariantList{ imageFolderPath }, true);
    if (expandedImageFolderSources.size() != 1) {
        printStepResult(QStringLiteral("Image Folder Source Expansion"), false, QStringLiteral("Expected exactly one image_folder source."));
        return 1;
    }
    {
        const QVariantMap entry = expandedImageFolderSources.first().toMap();
        if (entry.value(QStringLiteral("sourceType")).toString() != QStringLiteral("image_folder")
            || QDir::toNativeSeparators(entry.value(QStringLiteral("path")).toString())
                != QDir::toNativeSeparators(QFileInfo(imageFolderPath).absoluteFilePath())) {
            printStepResult(QStringLiteral("Image Folder Source Expansion"), false, QStringLiteral("Image folder source type/path mismatch."));
            return 1;
        }
    }
    printStepResult(QStringLiteral("Image Folder Source Expansion"), true);

    const QVariantMap createdFromImageFolder = model.importSourceAndCreateIssueEx(
        imageFolderPath,
        QStringLiteral("image_folder"),
        QString(),
        QVariantMap{
            { QStringLiteral("deferReload"), true }
        }
    );
    if (!createdFromImageFolder.value(QStringLiteral("ok")).toBool()) {
        printStepResult(
            QStringLiteral("Image Folder Import"),
            false,
            createdFromImageFolder.value(QStringLiteral("error")).toString()
        );
        return 1;
    }
    const int imageFolderComicId = createdFromImageFolder.value(QStringLiteral("comicId")).toInt();
    const QString imageFolderArchivePath = createdFromImageFolder.value(QStringLiteral("filePath")).toString();
    if (imageFolderComicId < 1
        || imageFolderArchivePath.isEmpty()
        || !QFileInfo::exists(imageFolderArchivePath)
        || QFileInfo(imageFolderArchivePath).suffix().compare(QStringLiteral("cbz"), Qt::CaseInsensitive) != 0) {
        printStepResult(QStringLiteral("Image Folder Import"), false, QStringLiteral("Image folder did not produce a valid library .cbz."));
        return 1;
    }
    const QVariantMap imageFolderMeta = model.loadComicMetadata(imageFolderComicId);
    if (imageFolderMeta.contains(QStringLiteral("error"))
        || imageFolderMeta.value(QStringLiteral("series")).toString() != QStringLiteral("Spawn")
        || imageFolderMeta.value(QStringLiteral("issueNumber")).toString() != QStringLiteral("1")) {
        printStepResult(QStringLiteral("Image Folder Import"), false, QStringLiteral("Folder-derived series/issue metadata mismatch."));
        return 1;
    }
    QString imageFolderArchiveDetails;
    if (!archiveContainsImages(imageFolderArchivePath, imageFolderArchiveDetails)) {
        printStepResult(QStringLiteral("Image Folder Archive Pages"), false, imageFolderArchiveDetails);
        return 1;
    }
    printStepResult(QStringLiteral("Image Folder Import"), true);

    const QVariantMap values = {
        { QStringLiteral("series"), QStringLiteral("Smoke Series") },
        { QStringLiteral("volume"), QStringLiteral("1") },
        { QStringLiteral("issueNumber"), QStringLiteral("1") },
        { QStringLiteral("title"), QStringLiteral("Smoke Issue #1") },
        { QStringLiteral("deferReload"), true },
    };

    const QVariantMap created = model.importArchiveAndCreateIssueEx(incomingPath, QStringLiteral("smoke-created.cbz"), values);
    if (!created.value(QStringLiteral("ok")).toBool()
        || created.value(QStringLiteral("code")).toString() != QStringLiteral("created")) {
        printStepResult(
            QStringLiteral("Import created"),
            false,
            QString("code=%1 error=%2")
                .arg(created.value(QStringLiteral("code")).toString(),
                     created.value(QStringLiteral("error")).toString())
        );
        return 1;
    }
    const int comicId = created.value(QStringLiteral("comicId")).toInt();
    const QString filePath = created.value(QStringLiteral("filePath")).toString();
    const QString fileName = created.value(QStringLiteral("filename")).toString();
    if (comicId < 1 || filePath.isEmpty() || !QFileInfo::exists(filePath)) {
        printStepResult(QStringLiteral("Import created"), false, QStringLiteral("Missing created comic id/path."));
        return 1;
    }
    if (QFileInfo(filePath).absoluteDir().dirName() != QStringLiteral("Smoke Series")) {
        printStepResult(QStringLiteral("Import created"), false, QStringLiteral("Archive was not placed into Smoke Series folder."));
        return 1;
    }
    printStepResult(QStringLiteral("Import created"), true);

    QString archiveDetails;
    if (!archiveContainsImages(filePath, archiveDetails)) {
        printStepResult(
            QStringLiteral("Imported archive pages"),
            false,
            QStringLiteral("path=%1 details=%2").arg(filePath, archiveDetails)
        );
        return 1;
    }
    printStepResult(QStringLiteral("Imported archive pages"), true, archiveDetails);

    const QVariantMap duplicate = model.importArchiveAndCreateIssueEx(filePath, fileName, values);
    if (duplicate.value(QStringLiteral("ok")).toBool()
        || duplicate.value(QStringLiteral("code")).toString() != QStringLiteral("duplicate")
        || duplicate.value(QStringLiteral("existingId")).toInt() != comicId) {
        printStepResult(
            QStringLiteral("Import duplicate"),
            false,
            QString("ok=%1 code=%2 existing=%3")
                .arg(QString::number(duplicate.value(QStringLiteral("ok")).toBool()),
                     duplicate.value(QStringLiteral("code")).toString(),
                     duplicate.value(QStringLiteral("existingId")).toString())
        );
        return 1;
    }
    printStepResult(QStringLiteral("Import duplicate"), true);

    const QVariantMap meta = model.loadComicMetadata(comicId);
    if (meta.contains(QStringLiteral("error"))
        || meta.value(QStringLiteral("series")).toString() != QStringLiteral("Smoke Series")) {
        printStepResult(QStringLiteral("Metadata load"), false, meta.value(QStringLiteral("error")).toString());
        return 1;
    }
    printStepResult(QStringLiteral("Metadata load"), true);

    model.reload();
    const QVariantMap navigationTarget = model.navigationTargetForComic(comicId);
    const QString smokeSeriesKey = navigationTarget.value(QStringLiteral("seriesKey")).toString();
    if (!navigationTarget.value(QStringLiteral("ok")).toBool()
        || navigationTarget.value(QStringLiteral("comicId")).toInt() != comicId
        || smokeSeriesKey.isEmpty()) {
        printStepResult(QStringLiteral("Navigation target"), false, QStringLiteral("Created issue did not resolve to a navigation target."));
        return 1;
    }
    printStepResult(QStringLiteral("Navigation target"), true);

    const QString continueStatePath = QDir(dataRoot)
        .filePath(QStringLiteral(".runtime/continue-reading-state.json"));
    if (!model.readContinueReadingState().isEmpty()) {
        printStepResult(QStringLiteral("Continue reading state"), false, QStringLiteral("Expected empty persisted continue-reading state at startup."));
        return 1;
    }
    if (!model.writeContinueReadingState({
            { QStringLiteral("comicId"), comicId },
            { QStringLiteral("seriesKey"), smokeSeriesKey },
        })) {
        printStepResult(QStringLiteral("Continue reading state"), false, QStringLiteral("Failed to persist continue-reading state."));
        return 1;
    }
    const QVariantMap persistedContinueState = model.readContinueReadingState();
    if (persistedContinueState.value(QStringLiteral("comicId")).toInt() != comicId
        || persistedContinueState.value(QStringLiteral("seriesKey")).toString() != smokeSeriesKey
        || !QFileInfo::exists(continueStatePath)) {
        printStepResult(QStringLiteral("Continue reading state"), false, QStringLiteral("Persisted continue-reading state did not round-trip."));
        return 1;
    }
    if (!model.writeContinueReadingState({
            { QStringLiteral("comicId"), -1 },
            { QStringLiteral("seriesKey"), QString() },
        })) {
        printStepResult(QStringLiteral("Continue reading state clear"), false, QStringLiteral("Failed to clear continue-reading state."));
        return 1;
    }
    if (!model.readContinueReadingState().isEmpty() || QFileInfo::exists(continueStatePath)) {
        printStepResult(QStringLiteral("Continue reading state clear"), false, QStringLiteral("Continue-reading state file still exists after clear."));
        return 1;
    }
    printStepResult(QStringLiteral("Continue reading state"), true);

    const QString readingFlowIncomingOne = QDir(incomingDirPath).filePath(QStringLiteral("reading-flow-001.%1").arg(ext));
    const QString readingFlowIncomingTwo = QDir(incomingDirPath).filePath(QStringLiteral("reading-flow-002.%1").arg(ext));
    const QString readingFlowIncomingThree = QDir(incomingDirPath).filePath(QStringLiteral("reading-flow-003.%1").arg(ext));
    if (!copyFileStrict(seedArchivePath, readingFlowIncomingOne, setupError)
        || !copyFileStrict(seedArchivePath, readingFlowIncomingTwo, setupError)
        || !copyFileStrict(seedArchivePath, readingFlowIncomingThree, setupError)) {
        printStepResult(QStringLiteral("Reading flow setup"), false, setupError);
        return 1;
    }

    auto importReadingFlowIssue = [&](const QString &sourcePath,
                                      const QString &issueNumber,
                                      const QString &title,
                                      int &comicIdOut,
                                      QString &errorOut) -> bool {
        const QVariantMap importResult = model.importArchiveAndCreateIssueEx(
            sourcePath,
            QStringLiteral("reading-flow-%1.cbz").arg(issueNumber),
            {
                { QStringLiteral("series"), QStringLiteral("Reading Flow") },
                { QStringLiteral("volume"), QStringLiteral("1") },
                { QStringLiteral("issueNumber"), issueNumber },
                { QStringLiteral("title"), title },
                { QStringLiteral("deferReload"), true },
            }
        );
        if (!importResult.value(QStringLiteral("ok")).toBool()) {
            errorOut = importResult.value(QStringLiteral("error")).toString();
            return false;
        }
        comicIdOut = importResult.value(QStringLiteral("comicId")).toInt();
        if (comicIdOut < 1) {
            errorOut = QStringLiteral("Imported issue did not return a valid comic id.");
            return false;
        }
        return true;
    };

    int readingFlowOneId = 0;
    int readingFlowTwoId = 0;
    int readingFlowThreeId = 0;
    QString readingFlowError;
    if (!importReadingFlowIssue(
            readingFlowIncomingOne,
            QStringLiteral("1"),
            QStringLiteral("Reading Flow #1"),
            readingFlowOneId,
            readingFlowError)
        || !importReadingFlowIssue(
            readingFlowIncomingTwo,
            QStringLiteral("2"),
            QStringLiteral("Reading Flow #2"),
            readingFlowTwoId,
            readingFlowError)
        || !importReadingFlowIssue(
            readingFlowIncomingThree,
            QStringLiteral("3"),
            QStringLiteral("Reading Flow #3"),
            readingFlowThreeId,
            readingFlowError)) {
        printStepResult(QStringLiteral("Reading flow setup"), false, readingFlowError);
        return 1;
    }

    model.reload();
    const QVariantMap readingFlowAnchorTarget = model.navigationTargetForComic(readingFlowOneId);
    const QString readingFlowSeriesKey = readingFlowAnchorTarget.value(QStringLiteral("seriesKey")).toString();
    if (!readingFlowAnchorTarget.value(QStringLiteral("ok")).toBool()
        || readingFlowAnchorTarget.value(QStringLiteral("comicId")).toInt() != readingFlowOneId
        || readingFlowSeriesKey.isEmpty()) {
        printStepResult(QStringLiteral("Reading flow setup"), false, QStringLiteral("Failed to resolve the reading-flow navigation anchor."));
        return 1;
    }
    const QVariantMap noActiveReadingTarget = model.continueReadingTarget();
    if (noActiveReadingTarget.value(QStringLiteral("ok")).toBool()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Expected no active reading target before progress or bookmarks."));
        return 1;
    }

    if (!model.saveReaderProgress(readingFlowOneId, 7).isEmpty()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Failed to save reader progress for issue #1."));
        return 1;
    }
    QVariantMap continueTarget = model.continueReadingTarget();
    if (!continueTarget.value(QStringLiteral("ok")).toBool()
        || continueTarget.value(QStringLiteral("comicId")).toInt() != readingFlowOneId
        || continueTarget.value(QStringLiteral("seriesKey")).toString() != readingFlowSeriesKey
        || continueTarget.value(QStringLiteral("startPageIndex")).toInt() != 6
        || !continueTarget.value(QStringLiteral("hasProgress")).toBool()
        || continueTarget.value(QStringLiteral("hasBookmark")).toBool()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Progress-only continue target did not resolve to issue #1."));
        return 1;
    }

    if (!model.saveReaderBookmark(readingFlowTwoId, 3).isEmpty()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Failed to save bookmark for issue #2."));
        return 1;
    }
    continueTarget = model.continueReadingTarget();
    if (!continueTarget.value(QStringLiteral("ok")).toBool()
        || continueTarget.value(QStringLiteral("comicId")).toInt() != readingFlowTwoId
        || continueTarget.value(QStringLiteral("startPageIndex")).toInt() != 2
        || !continueTarget.value(QStringLiteral("hasBookmark")).toBool()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Bookmark should outrank plain reading progress."));
        return 1;
    }

    if (!model.saveReaderBookmark(readingFlowTwoId, 0).isEmpty()
        || !model.saveReaderProgress(readingFlowThreeId, 11).isEmpty()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Failed to update progress state for ranking fallback."));
        return 1;
    }
    continueTarget = model.continueReadingTarget();
    if (!continueTarget.value(QStringLiteral("ok")).toBool()
        || continueTarget.value(QStringLiteral("comicId")).toInt() != readingFlowThreeId
        || continueTarget.value(QStringLiteral("startPageIndex")).toInt() != 10
        || !continueTarget.value(QStringLiteral("hasProgress")).toBool()
        || continueTarget.value(QStringLiteral("hasBookmark")).toBool()) {
        printStepResult(QStringLiteral("Continue reading target ranking"), false, QStringLiteral("Highest in-progress issue should win when no bookmarks remain."));
        return 1;
    }
    printStepResult(QStringLiteral("Continue reading target ranking"), true);

    if (!model.updateComicMetadata(readingFlowOneId, {
            { QStringLiteral("readStatus"), QStringLiteral("read") },
            { QStringLiteral("currentPage"), QStringLiteral("0") },
        }).isEmpty()
        || !model.updateComicMetadata(readingFlowTwoId, {
            { QStringLiteral("readStatus"), QStringLiteral("unread") },
            { QStringLiteral("currentPage"), QStringLiteral("0") },
        }).isEmpty()
        || !model.updateComicMetadata(readingFlowThreeId, {
            { QStringLiteral("readStatus"), QStringLiteral("read") },
            { QStringLiteral("currentPage"), QStringLiteral("0") },
        }).isEmpty()) {
        printStepResult(QStringLiteral("Next unread target"), false, QStringLiteral("Failed to prepare read-status ordering for next unread."));
        return 1;
    }
    model.reload();

    QVariantMap nextUnreadTarget = model.nextUnreadTarget(readingFlowSeriesKey, readingFlowOneId);
    if (!nextUnreadTarget.value(QStringLiteral("ok")).toBool()
        || nextUnreadTarget.value(QStringLiteral("comicId")).toInt() != readingFlowTwoId
        || nextUnreadTarget.value(QStringLiteral("seriesKey")).toString() != readingFlowSeriesKey) {
        printStepResult(QStringLiteral("Next unread target"), false, QStringLiteral("Expected issue #2 as the next unread target after issue #1."));
        return 1;
    }

    nextUnreadTarget = model.nextUnreadTarget(readingFlowSeriesKey, -1);
    if (!nextUnreadTarget.value(QStringLiteral("ok")).toBool()
        || nextUnreadTarget.value(QStringLiteral("comicId")).toInt() != readingFlowTwoId) {
        printStepResult(QStringLiteral("Next unread target"), false, QStringLiteral("Expected first unread issue when no anchor comic is provided."));
        return 1;
    }

    nextUnreadTarget = model.nextUnreadTarget(readingFlowSeriesKey, readingFlowTwoId);
    if (nextUnreadTarget.value(QStringLiteral("ok")).toBool()
        || !nextUnreadTarget.value(QStringLiteral("message")).toString().contains(QStringLiteral("No next unread issue"), Qt::CaseInsensitive)) {
        printStepResult(QStringLiteral("Next unread target"), false, QStringLiteral("Expected no queued next unread issue after the last unread item."));
        return 1;
    }
    printStepResult(QStringLiteral("Next unread target"), true);

    QString coverImageSource;
    QString coverError;
    {
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        const int thumbRequestId = model.requestIssueThumbnailAsync(comicId);
        QMetaObject::Connection pageConn;
        QMetaObject::Connection timerConn;
        pageConn = QObject::connect(
            &model,
            &ComicsListModel::pageImageReady,
            &loop,
            [&](int requestId, int resultComicId, int pageIndex, const QString &imageSource, const QString &error, bool thumbnail) {
                Q_UNUSED(pageIndex);
                if (!thumbnail || requestId != thumbRequestId || resultComicId != comicId) return;
                coverImageSource = imageSource;
                coverError = error;
                loop.quit();
            }
        );
        timerConn = QObject::connect(&timer, &QTimer::timeout, &loop, [&]() {
            coverError = QStringLiteral("Timed out waiting for thumbnail.");
            loop.quit();
        });
        timer.start(15000);
        loop.exec();
        QObject::disconnect(pageConn);
        QObject::disconnect(timerConn);
    }
    const QString coverPath = QUrl(coverImageSource).toLocalFile();
    if (!coverError.trimmed().isEmpty()
        || coverPath.isEmpty()
        || !QFileInfo::exists(coverPath)
        || !coverPath.contains(QStringLiteral("/Covers/"), Qt::CaseInsensitive)) {
        printStepResult(
            QStringLiteral("Persistent cover generation"),
            false,
            QString("error=%1 path=%2").arg(coverError, coverPath)
        );
        return 1;
    }
    printStepResult(QStringLiteral("Persistent cover generation"), true);

    QString earlyReaderError;
    QString earlyReaderImageSource;
    int earlyReaderPageIndex = -1;
    {
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        const int pageRequestId = model.requestReaderPageAsync(comicId, 0);
        QMetaObject::Connection pageConn;
        QMetaObject::Connection timerConn;
        pageConn = QObject::connect(
            &model,
            &ComicsListModel::pageImageReady,
            &loop,
            [&](int requestId, int resultComicId, int pageIndex, const QString &imageSource, const QString &error, bool thumbnail) {
                if (thumbnail || requestId != pageRequestId || resultComicId != comicId) return;
                earlyReaderPageIndex = pageIndex;
                earlyReaderImageSource = imageSource;
                earlyReaderError = error;
                loop.quit();
            }
        );
        timerConn = QObject::connect(&timer, &QTimer::timeout, &loop, [&]() {
            earlyReaderError = QStringLiteral("Timed out waiting for cold reader page.");
            loop.quit();
        });
        timer.start(10000);
        loop.exec();
        QObject::disconnect(pageConn);
        QObject::disconnect(timerConn);
    }
    const QString earlyReaderPath = QUrl(earlyReaderImageSource).toLocalFile();
    if (!earlyReaderError.trimmed().isEmpty()
        || earlyReaderPageIndex != 0
        || earlyReaderPath.isEmpty()
        || !QFileInfo::exists(earlyReaderPath)) {
        printStepResult(
            QStringLiteral("Reader async boundary"),
            false,
            QString("error=%1 page=%2 path=%3").arg(earlyReaderError).arg(earlyReaderPageIndex).arg(earlyReaderPath)
        );
        return 1;
    }
    printStepResult(QStringLiteral("Reader async boundary"), true);

    QVariantMap readerSession;
    {
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        const int sessionRequestId = model.requestReaderSessionAsync(comicId);
        QMetaObject::Connection sessionConn;
        QMetaObject::Connection timerConn;
        sessionConn = QObject::connect(
            &model,
            &ComicsListModel::readerSessionReady,
            &loop,
            [&](int requestId, const QVariantMap &result) {
                if (requestId != sessionRequestId) return;
                readerSession = result;
                loop.quit();
            }
        );
        timerConn = QObject::connect(&timer, &QTimer::timeout, &loop, [&]() {
            readerSession.insert(QStringLiteral("error"), QStringLiteral("Timed out waiting for reader session."));
            loop.quit();
        });
        timer.start(20000);
        loop.exec();
        QObject::disconnect(sessionConn);
        QObject::disconnect(timerConn);
    }
    if (readerSession.contains(QStringLiteral("error"))
        || readerSession.value(QStringLiteral("pageCount")).toInt() < 1) {
        printStepResult(
            QStringLiteral("requestReaderSessionAsync"),
            false,
            readerSession.value(QStringLiteral("error")).toString()
        );
        return 1;
    }
    printStepResult(QStringLiteral("requestReaderSessionAsync"), true);

    QString readerImageSource;
    QString readerPageError;
    {
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        const int pageRequestId = model.requestReaderPageAsync(comicId, 0);
        QMetaObject::Connection pageConn;
        QMetaObject::Connection timerConn;
        pageConn = QObject::connect(
            &model,
            &ComicsListModel::pageImageReady,
            &loop,
            [&](int requestId, int resultComicId, int pageIndex, const QString &imageSource, const QString &error, bool thumbnail) {
                Q_UNUSED(pageIndex);
                if (thumbnail || requestId != pageRequestId || resultComicId != comicId) return;
                readerImageSource = imageSource;
                readerPageError = error;
                loop.quit();
            }
        );
        timerConn = QObject::connect(&timer, &QTimer::timeout, &loop, [&]() {
            readerPageError = QStringLiteral("Timed out waiting for reader page.");
            loop.quit();
        });
        timer.start(20000);
        loop.exec();
        QObject::disconnect(pageConn);
        QObject::disconnect(timerConn);
    }
    const QString readerPagePath = QUrl(readerImageSource).toLocalFile();
    if (!readerPageError.trimmed().isEmpty()
        || readerPagePath.isEmpty()
        || !QFileInfo::exists(readerPagePath)
        || !readerPagePath.contains(QStringLiteral(".runtime/reader-cache"), Qt::CaseInsensitive)) {
        printStepResult(
            QStringLiteral("requestReaderPageAsync"),
            false,
            QString("error=%1 path=%2").arg(readerPageError, readerPagePath)
        );
        return 1;
    }
    printStepResult(QStringLiteral("requestReaderPageAsync"), true);

    const QString hardDeleteError = model.deleteComicHard(comicId);
    if (!hardDeleteError.isEmpty()) {
        printStepResult(QStringLiteral("deleteComicHard"), false, hardDeleteError);
        return 1;
    }
    if (QFileInfo::exists(filePath)) {
        printStepResult(QStringLiteral("deleteComicHard"), false, QStringLiteral("Archive file still exists after hard delete."));
        return 1;
    }
    if (QFileInfo(QFileInfo(filePath).absolutePath()).exists()) {
        printStepResult(QStringLiteral("deleteComicHard"), false, QStringLiteral("Series folder still exists after deleting last issue."));
        return 1;
    }
    if (QFileInfo::exists(coverPath)) {
        printStepResult(QStringLiteral("deleteComicHard"), false, QStringLiteral("Cover asset still exists after hard delete."));
        return 1;
    }
    printStepResult(QStringLiteral("deleteComicHard"), true);

    QTextStream(stdout) << "[OK] Smoke completed.\n";
    return 0;
}
