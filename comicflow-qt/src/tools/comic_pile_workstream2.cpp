#include "storage/comicslistmodel.h"
#include "storage/datarootsettingsutils.h"
#include "storage/librarystoragemigrationstate.h"
#include "common/scopedsqlconnectionremoval.h"

#include <QDir>
#include <QDirIterator>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTextStream>
#include <QTimer>
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

void configureIsolatedSettings(const QString &settingsRoot)
{
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, settingsRoot);
    QSettings::setPath(QSettings::IniFormat, QSettings::SystemScope, settingsRoot);
    QSettings settings(
        QSettings::IniFormat,
        QSettings::UserScope,
        QStringLiteral("ComicPile"),
        QStringLiteral("ComicPile")
    );
    settings.clear();
    settings.sync();
}

bool initIsolatedDatabase(const QString &dbPath, QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_workstream2_init_db");
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
                "bookmark_page INTEGER DEFAULT 0,"
                "bookmark_added_at TEXT DEFAULT '',"
                "favorite_active INTEGER DEFAULT 0,"
                "favorite_added_at TEXT DEFAULT '',"
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

bool createDataRootSkeleton(const QString &dataRoot, QString &error)
{
    const QString libraryDirPath = QDir(dataRoot).filePath(QStringLiteral("Library"));
    if (!QDir().mkpath(libraryDirPath)) {
        error = QStringLiteral("Failed to create Library folder.");
        return false;
    }
    const QString dbPath = QDir(dataRoot).filePath(QStringLiteral("library.db"));
    return initIsolatedDatabase(dbPath, error);
}

bool copyFileStrict(const QString &sourcePath, const QString &targetPath, QString &error)
{
    const QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        error = QString("Source file not found: %1").arg(sourcePath);
        return false;
    }

    const QFileInfo targetInfo(targetPath);
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

bool importIssue(ComicsListModel &model,
                 const QString &sourcePath,
                 const QString &targetFilename,
                 const QString &series,
                 const QString &issueNumber,
                 const QString &title,
                 int year,
                 int &comicIdOut,
                 QString &error)
{
    const QVariantMap result = model.importArchiveAndCreateIssueEx(
        sourcePath,
        targetFilename,
        QVariantMap{
            { QStringLiteral("series"), series },
            { QStringLiteral("volume"), QStringLiteral("1") },
            { QStringLiteral("issueNumber"), issueNumber },
            { QStringLiteral("title"), title },
            { QStringLiteral("publisher"), QStringLiteral("Smoke Publisher") },
            { QStringLiteral("year"), QString::number(year) },
            { QStringLiteral("deferReload"), true },
        }
    );
    if (!result.value(QStringLiteral("ok")).toBool()) {
        error = result.value(QStringLiteral("error")).toString();
        return false;
    }

    comicIdOut = result.value(QStringLiteral("comicId")).toInt();
    if (comicIdOut < 1) {
        error = QStringLiteral("Imported issue did not return a valid comic id.");
        return false;
    }
    return true;
}

struct SeedData {
    int alphaIssueOneId = 0;
    int alphaIssueTwoId = 0;
    QString alphaSeriesKey;
    QString alphaSeriesTitle;
};

bool seedPopulatedLibrary(
    const QString &workspaceRoot,
    const QString &dataRoot,
    ComicsListModel &model,
    SeedData &seed,
    QString &error
)
{
    const QString seedArchivePath = findSeedArchive(workspaceRoot);
    if (seedArchivePath.isEmpty()) {
        error = QStringLiteral("No archive fixture found.");
        return false;
    }

    const QString incomingDirPath = QDir(dataRoot).filePath(QStringLiteral("Incoming"));
    if (!QDir().mkpath(incomingDirPath)) {
        error = QStringLiteral("Failed to create incoming folder.");
        return false;
    }

    const QString ext = QFileInfo(seedArchivePath).suffix().toLower();
    const QString incomingAlphaOne = QDir(incomingDirPath).filePath(QStringLiteral("alpha-001.%1").arg(ext));
    const QString incomingAlphaTwo = QDir(incomingDirPath).filePath(QStringLiteral("alpha-002.%1").arg(ext));
    if (!copyFileStrict(seedArchivePath, incomingAlphaOne, error)
        || !copyFileStrict(seedArchivePath, incomingAlphaTwo, error)) {
        return false;
    }

    if (!importIssue(
            model,
            incomingAlphaOne,
            QStringLiteral("alpha-001.cbz"),
            QStringLiteral("Alpha Series"),
            QStringLiteral("1"),
            QStringLiteral("Alpha Issue 001"),
            2024,
            seed.alphaIssueOneId,
            error)
        || !importIssue(
            model,
            incomingAlphaTwo,
            QStringLiteral("alpha-002.cbz"),
            QStringLiteral("Alpha Series"),
            QStringLiteral("2"),
            QStringLiteral("Alpha Issue 002"),
            2025,
            seed.alphaIssueTwoId,
            error)) {
        return false;
    }

    model.reload();
    const QVariantMap alphaNavigation = model.navigationTargetForComic(seed.alphaIssueOneId);
    if (!alphaNavigation.value(QStringLiteral("ok")).toBool()) {
        error = QStringLiteral("Failed to resolve seeded series navigation target.");
        return false;
    }

    seed.alphaSeriesKey = alphaNavigation.value(QStringLiteral("seriesKey")).toString();
    seed.alphaSeriesTitle = alphaNavigation.value(QStringLiteral("seriesTitle")).toString();
    if (seed.alphaSeriesKey.isEmpty() || seed.alphaSeriesTitle.isEmpty()) {
        error = QStringLiteral("Seeded series identity is incomplete.");
        return false;
    }

    return true;
}

bool verifyRelocationFlags(QString &details)
{
    QTemporaryDir sandbox;
    if (!sandbox.isValid()) {
        details = QStringLiteral("Failed to create relocation sandbox.");
        return false;
    }

    QString error;
    const QString relocationRoot = QDir(sandbox.path()).filePath(QStringLiteral("RelocationRoot"));
    const QString completionRoot = QDir(sandbox.path()).filePath(QStringLiteral("CompletionRoot"));
    if (!createDataRootSkeleton(relocationRoot, error) || !createDataRootSkeleton(completionRoot, error)) {
        details = error;
        return false;
    }

    qunsetenv("COMIC_PILE_DATA_DIR");
    qunsetenv("COMICFLOW_DATA_DIR");

    if (!ComicDataRootSettings::writeConfiguredDataRootOverridePath(relocationRoot)) {
        details = QStringLiteral("Failed to configure isolated relocation root.");
        return false;
    }
    ComicDataRootSettings::clearPendingDataRootRelocationPath();

    ComicsListModel relocationModel;
    if (!relocationModel.lastError().trimmed().isEmpty()) {
        details = relocationModel.lastError();
        return false;
    }
    if (!relocationModel.isLibraryStorageMigrationPending()) {
        details = QStringLiteral("Fresh relocation root did not report pending storage migration.");
        return false;
    }

    const QString targetRoot = QDir(sandbox.path()).filePath(QStringLiteral("RelocatedTarget"));
    const QVariantMap scheduleResult = relocationModel.scheduleDataRootRelocation(targetRoot);
    if (!scheduleResult.value(QStringLiteral("ok")).toBool()) {
        details = QStringLiteral("Scheduling relocation failed: %1")
            .arg(scheduleResult.value(QStringLiteral("error")).toString());
        return false;
    }
    if (!scheduleResult.value(QStringLiteral("restartRequired")).toBool()) {
        details = QStringLiteral("Relocation scheduling stopped reporting restartRequired.");
        return false;
    }

    ComicsListModel relocationReloadedModel;
    const QString expectedPendingPath = ComicDataRootSettings::persistedFolderPathForDisplay(targetRoot);
    if (relocationReloadedModel.pendingDataRootRelocationPath() != expectedPendingPath) {
        details = QStringLiteral("Pending relocation path did not survive model recreation.");
        return false;
    }

    if (!ComicDataRootSettings::writeConfiguredDataRootOverridePath(completionRoot)) {
        details = QStringLiteral("Failed to switch to completion-state root.");
        return false;
    }
    ComicDataRootSettings::clearPendingDataRootRelocationPath();

    ComicsListModel completionPendingModel;
    if (!completionPendingModel.isLibraryStorageMigrationPending()) {
        details = QStringLiteral("Completion root did not start in pending state.");
        return false;
    }

    if (!ComicLibraryStorageMigrationState::writeCompletedLayoutMigrationMarker(completionRoot)) {
        details = QStringLiteral("Failed to write storage migration marker.");
        return false;
    }

    ComicsListModel completionFinishedModel;
    if (completionFinishedModel.isLibraryStorageMigrationPending()) {
        details = QStringLiteral("Completed storage migration marker did not clear the pending state.");
        return false;
    }

    ComicDataRootSettings::clearPendingDataRootRelocationPath();
    ComicDataRootSettings::writeConfiguredDataRootOverridePath(QString());
    details = QStringLiteral("pending path, restart-required state, and completion marker behavior are stable");
    return true;
}

} // namespace

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
#ifdef Q_OS_WIN
        qputenv("QT_QPA_PLATFORM", QByteArrayLiteral("windows"));
#else
        qputenv("QT_QPA_PLATFORM", QByteArrayLiteral("offscreen"));
#endif
    }

    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("ComicPileSmoke"));
    QCoreApplication::setApplicationName(QStringLiteral("comic_pile_workstream2"));

    QTemporaryDir settingsSandbox;
    if (!settingsSandbox.isValid()) {
        printStepResult(QStringLiteral("Workstream 2 setup"), false, QStringLiteral("Failed to create isolated settings sandbox."));
        return 1;
    }
    configureIsolatedSettings(settingsSandbox.path());

    const QString workspaceRoot = findWorkspaceRoot();
    if (workspaceRoot.isEmpty()) {
        printStepResult(QStringLiteral("Workstream 2 setup"), false, QStringLiteral("Could not locate project root."));
        return 1;
    }

    QString relocationDetails;
    const bool relocationOk = verifyRelocationFlags(relocationDetails);
    printStepResult(QStringLiteral("Workstream 2 relocation flags"), relocationOk, relocationDetails);
    if (!relocationOk) {
        return 1;
    }

    QTemporaryDir dataSandbox;
    if (!dataSandbox.isValid()) {
        printStepResult(QStringLiteral("Workstream 2 setup"), false, QStringLiteral("Failed to create isolated data sandbox."));
        return 1;
    }

    QString error;
    const QString populatedRoot = QDir(dataSandbox.path()).filePath(QStringLiteral("PopulatedRoot"));
    const QString emptyRoot = QDir(dataSandbox.path()).filePath(QStringLiteral("EmptyRoot"));
    if (!createDataRootSkeleton(populatedRoot, error) || !createDataRootSkeleton(emptyRoot, error)) {
        printStepResult(QStringLiteral("Workstream 2 setup"), false, error);
        return 1;
    }

    SeedData seed;
    qputenv("COMIC_PILE_DATA_DIR", populatedRoot.toUtf8());
    qunsetenv("COMICFLOW_DATA_DIR");
    ComicsListModel populatedModel;
    if (!populatedModel.lastError().trimmed().isEmpty()) {
        printStepResult(QStringLiteral("Workstream 2 populated model"), false, populatedModel.lastError());
        return 1;
    }
    if (!seedPopulatedLibrary(workspaceRoot, populatedRoot, populatedModel, seed, error)) {
        printStepResult(QStringLiteral("Workstream 2 seed import"), false, error);
        return 1;
    }

    qputenv("COMIC_PILE_DATA_DIR", emptyRoot.toUtf8());
    ComicsListModel emptyModel;
    if (!emptyModel.lastError().trimmed().isEmpty()) {
        printStepResult(QStringLiteral("Workstream 2 empty model"), false, emptyModel.lastError());
        return 1;
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("workstream2Model"), &populatedModel);
    engine.rootContext()->setContextProperty(QStringLiteral("workstream2EmptyModel"), &emptyModel);
    engine.rootContext()->setContextProperty(
        QStringLiteral("workstream2Seed"),
        QVariantMap{
            { QStringLiteral("alphaIssue1Id"), seed.alphaIssueOneId },
            { QStringLiteral("alphaIssue2Id"), seed.alphaIssueTwoId },
            { QStringLiteral("alphaSeriesKey"), seed.alphaSeriesKey },
            { QStringLiteral("alphaSeriesTitle"), seed.alphaSeriesTitle },
        }
    );

    const QString harnessPath = QDir(workspaceRoot)
        .filePath(QStringLiteral("comicflow-qt/qml/tests/Workstream2RecoverySmoke.qml"));
    engine.load(QUrl::fromLocalFile(harnessPath));
    if (engine.rootObjects().isEmpty()) {
        printStepResult(QStringLiteral("Workstream 2 harness"), false, QStringLiteral("Failed to load QML harness."));
        return 1;
    }

    QObject *rootObject = engine.rootObjects().constFirst();
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    bool timedOut = false;

    QObject::connect(rootObject, SIGNAL(finished(bool,QString)), &loop, SLOT(quit()));
    QObject::connect(&timeout, &QTimer::timeout, &loop, [&]() {
        timedOut = true;
        loop.quit();
    });

    timeout.start(15000);
    loop.exec();

    const bool harnessSuccess = !timedOut && rootObject->property("success").toBool();
    QString harnessDetails;
    if (timedOut) {
        harnessDetails = QStringLiteral("Timed out waiting for Workstream 2 recovery smoke.");
    } else {
        harnessDetails = rootObject->property("details").toString();
        if (harnessDetails.isEmpty()) {
            harnessDetails = harnessSuccess
                ? QStringLiteral("Workstream 2 recovery smoke passed.")
                : QStringLiteral("Workstream 2 recovery smoke failed.");
        }
    }

    printStepResult(QStringLiteral("Workstream 2 recovery smoke"), harnessSuccess, harnessDetails);
    return harnessSuccess ? 0 : 1;
}
