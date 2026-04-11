#include "storage/comicslistmodel.h"
#include "common/scopedsqlconnectionremoval.h"

#include <QDir>
#include <QDirIterator>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMetaObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
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

bool initIsolatedDatabase(const QString &dbPath, QString &error)
{
    const QString connectionName = QStringLiteral("comic_pile_workstream1_init_db");
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

} // namespace

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", QByteArrayLiteral("offscreen"));
    }

    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("ComicPileSmoke"));
    QCoreApplication::setApplicationName(QStringLiteral("comic_pile_workstream1"));

    QSettings settings;
    settings.clear();
    settings.sync();

    const QString workspaceRoot = findWorkspaceRoot();
    if (workspaceRoot.isEmpty()) {
        printStepResult(QStringLiteral("Workstream 1 setup"), false, QStringLiteral("Could not locate project root."));
        return 1;
    }

    const QString seedArchivePath = findSeedArchive(workspaceRoot);
    if (seedArchivePath.isEmpty()) {
        printStepResult(QStringLiteral("Workstream 1 setup"), false, QStringLiteral("No archive fixture found."));
        return 1;
    }

    QTemporaryDir sandbox;
    if (!sandbox.isValid()) {
        printStepResult(QStringLiteral("Workstream 1 setup"), false, QStringLiteral("Failed to create temporary sandbox."));
        return 1;
    }

    const QString dataRoot = sandbox.path();
    const QString libraryDirPath = QDir(dataRoot).filePath(QStringLiteral("Library"));
    const QString incomingDirPath = QDir(dataRoot).filePath(QStringLiteral("Incoming"));
    if (!QDir().mkpath(libraryDirPath) || !QDir().mkpath(incomingDirPath)) {
        printStepResult(QStringLiteral("Workstream 1 setup"), false, QStringLiteral("Failed to create sandbox folders."));
        return 1;
    }

    QString setupError;
    const QString dbPath = QDir(dataRoot).filePath(QStringLiteral("library.db"));
    if (!initIsolatedDatabase(dbPath, setupError)) {
        printStepResult(QStringLiteral("Workstream 1 setup"), false, setupError);
        return 1;
    }

    const QString ext = QFileInfo(seedArchivePath).suffix().toLower();
    const QString incomingAlphaOne = QDir(incomingDirPath).filePath(QStringLiteral("alpha-001.%1").arg(ext));
    const QString incomingAlphaTwo = QDir(incomingDirPath).filePath(QStringLiteral("alpha-002.%1").arg(ext));
    const QString incomingBetaOne = QDir(incomingDirPath).filePath(QStringLiteral("beta-001.%1").arg(ext));
    if (!copyFileStrict(seedArchivePath, incomingAlphaOne, setupError)
        || !copyFileStrict(seedArchivePath, incomingAlphaTwo, setupError)
        || !copyFileStrict(seedArchivePath, incomingBetaOne, setupError)) {
        printStepResult(QStringLiteral("Workstream 1 setup"), false, setupError);
        return 1;
    }

    qputenv("COMIC_PILE_DATA_DIR", dataRoot.toUtf8());
    ComicsListModel model;
    if (!model.lastError().trimmed().isEmpty()) {
        printStepResult(QStringLiteral("Workstream 1 model load"), false, model.lastError());
        return 1;
    }

    int alphaIssueOneId = 0;
    int alphaIssueTwoId = 0;
    int betaIssueOneId = 0;
    if (!importIssue(
            model,
            incomingAlphaOne,
            QStringLiteral("alpha-001.cbz"),
            QStringLiteral("Alpha Series"),
            QStringLiteral("1"),
            QStringLiteral("Alpha Issue 001"),
            2024,
            alphaIssueOneId,
            setupError)
        || !importIssue(
            model,
            incomingAlphaTwo,
            QStringLiteral("alpha-002.cbz"),
            QStringLiteral("Alpha Series"),
            QStringLiteral("2"),
            QStringLiteral("Alpha Issue 002"),
            2025,
            alphaIssueTwoId,
            setupError)
        || !importIssue(
            model,
            incomingBetaOne,
            QStringLiteral("beta-001.cbz"),
            QStringLiteral("Beta Series"),
            QStringLiteral("1"),
            QStringLiteral("Beta Issue 001"),
            2023,
            betaIssueOneId,
            setupError)) {
        printStepResult(QStringLiteral("Workstream 1 seed import"), false, setupError);
        return 1;
    }

    model.reload();
    const QVariantMap alphaNavigation = model.navigationTargetForComic(alphaIssueOneId);
    const QVariantMap betaNavigation = model.navigationTargetForComic(betaIssueOneId);
    const QString alphaSeriesKey = alphaNavigation.value(QStringLiteral("seriesKey")).toString();
    const QString betaSeriesKey = betaNavigation.value(QStringLiteral("seriesKey")).toString();
    if (!alphaNavigation.value(QStringLiteral("ok")).toBool()
        || alphaSeriesKey.isEmpty()
        || !betaNavigation.value(QStringLiteral("ok")).toBool()
        || betaSeriesKey.isEmpty()) {
        printStepResult(QStringLiteral("Workstream 1 seed import"), false, QStringLiteral("Failed to resolve seeded series keys."));
        return 1;
    }

    if (!model.saveReaderProgress(alphaIssueOneId, 5).isEmpty()
        || !model.updateComicMetadata(alphaIssueOneId, {
                { QStringLiteral("readStatus"), QStringLiteral("read") },
                { QStringLiteral("currentPage"), QStringLiteral("5") },
            }).isEmpty()
        || !model.updateComicMetadata(alphaIssueTwoId, {
                { QStringLiteral("readStatus"), QStringLiteral("unread") },
                { QStringLiteral("currentPage"), QStringLiteral("0") },
            }).isEmpty()
        || !model.updateComicMetadata(betaIssueOneId, {
                { QStringLiteral("readStatus"), QStringLiteral("unread") },
                { QStringLiteral("currentPage"), QStringLiteral("0") },
            }).isEmpty()) {
        printStepResult(QStringLiteral("Workstream 1 seed state"), false, QStringLiteral("Failed to prepare reading/navigation state."));
        return 1;
    }
    model.reload();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("workstreamModel"), &model);
    engine.rootContext()->setContextProperty(
        QStringLiteral("workstreamSeed"),
        QVariantMap{
            { QStringLiteral("alphaIssue1Id"), alphaIssueOneId },
            { QStringLiteral("alphaIssue2Id"), alphaIssueTwoId },
            { QStringLiteral("betaIssue1Id"), betaIssueOneId },
            { QStringLiteral("alphaSeriesKey"), alphaSeriesKey },
            { QStringLiteral("betaSeriesKey"), betaSeriesKey },
        }
    );

    const QString harnessPath = QDir(workspaceRoot)
        .filePath(QStringLiteral("comicflow-qt/qml/tests/Workstream1ContractSmoke.qml"));
    engine.load(QUrl::fromLocalFile(harnessPath));
    if (engine.rootObjects().isEmpty()) {
        printStepResult(QStringLiteral("Workstream 1 harness"), false, QStringLiteral("Failed to load QML harness."));
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
        harnessDetails = QStringLiteral("Timed out waiting for Workstream 1 contract smoke.");
    } else {
        harnessDetails = rootObject->property("details").toString();
        if (harnessDetails.isEmpty()) {
            harnessDetails = harnessSuccess
                ? QStringLiteral("Workstream 1 contract smoke passed.")
                : QStringLiteral("Workstream 1 contract smoke failed.");
        }
    }

    printStepResult(QStringLiteral("Workstream 1 contract smoke"), harnessSuccess, harnessDetails);
    return harnessSuccess ? 0 : 1;
}
