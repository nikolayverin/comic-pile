#include "storage/startupruntimeutils.h"

#include "common/scopedsqlconnectionremoval.h"

#include <algorithm>

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace {

qint64 launchStartedAtMsFromEnv()
{
    bool ok = false;
    const qint64 startedAtMs = qEnvironmentVariable("COMIC_PILE_LAUNCH_STARTED_AT_MS").toLongLong(&ok);
    return ok ? startedAtMs : 0;
}

QString readTextFileIfPresent(const QString &path, QIODevice::OpenMode openMode = QIODevice::ReadOnly)
{
    const QFileInfo info(path);
    if (!info.exists() || !info.isFile()) {
        return {};
    }

    QFile file(path);
    if (!file.open(openMode)) {
        return {};
    }

    return QString::fromUtf8(file.readAll());
}

bool writeTextFileAtomically(
    const QString &path,
    const QString &payload,
    QIODevice::OpenMode openMode = QIODevice::WriteOnly | QIODevice::Truncate
)
{
    QSaveFile file(path);
    if (!file.open(openMode)) {
        return false;
    }

    if (file.write(payload.toUtf8()) < 0) {
        file.cancelWriting();
        return false;
    }

    return file.commit();
}

#ifdef Q_OS_WIN
void ensureHiddenDirectoryOnWindows(const QString &path)
{
    const QFileInfo info(path);
    if (!info.exists() || !info.isDir()) {
        return;
    }

    const std::wstring nativePath = QDir::toNativeSeparators(info.absoluteFilePath()).toStdWString();
    const DWORD currentAttributes = GetFileAttributesW(nativePath.c_str());
    if (currentAttributes == INVALID_FILE_ATTRIBUTES) {
        return;
    }

    if ((currentAttributes & FILE_ATTRIBUTE_HIDDEN) != 0) {
        return;
    }

    SetFileAttributesW(nativePath.c_str(), currentAttributes | FILE_ATTRIBUTE_HIDDEN);
}
#endif

} // namespace

namespace ComicStartupRuntime {

QString absolutePathIfExists(const QString &candidate)
{
    const QFileInfo info(candidate);
    if (!info.exists() || !info.isDir()) return {};
    return info.absoluteFilePath();
}

void resetTextLogFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return;
    }
    file.close();
}

void appendNormalizedTextLogLine(const QString &path, const QString &line)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return;
    }

    QString normalized = line;
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    file.write(normalized.toUtf8());
    file.write("\n");
    file.close();
}

QString startupRuntimeDirPath(const QString &dataRoot)
{
    const QString runtimeDirPath = QDir(dataRoot).filePath(QStringLiteral(".runtime"));
    QDir().mkpath(runtimeDirPath);
#ifdef Q_OS_WIN
    ensureHiddenDirectoryOnWindows(runtimeDirPath);
#endif
    return runtimeDirPath;
}

QString startupLaunchLogPathForDataRoot(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("startup-log.txt"));
}

QString startupSnapshotPath(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("startup-snapshot.json"));
}

QString startupLogPath(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("startup-log.txt"));
}

QString startupDebugLogPath(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("startup-debug-log.txt"));
}

QString startupPreviewPath(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("startup-preview.png"));
}

QString startupPreviewMetaPath(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("startup-preview-meta.json"));
}

QString readStartupSnapshot(const QString &dataRoot)
{
    return readTextFileIfPresent(startupSnapshotPath(dataRoot));
}

bool writeStartupSnapshot(const QString &dataRoot, const QString &payload)
{
    return writeTextFileAtomically(startupSnapshotPath(dataRoot), payload);
}

QString readStartupPreviewMeta(const QString &dataRoot)
{
    return readTextFileIfPresent(
        startupPreviewMetaPath(dataRoot),
        QIODevice::ReadOnly | QIODevice::Text
    );
}

bool writeStartupPreviewMeta(const QString &dataRoot, const QString &payload)
{
    return writeTextFileAtomically(
        startupPreviewMetaPath(dataRoot),
        payload,
        QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text
    );
}

QString libraryStorageMigrationMarkerPath(const QString &dataRoot)
{
    return QDir(startupRuntimeDirPath(dataRoot)).filePath(QStringLiteral("library-storage-layout-migration-v1.done"));
}

bool hasLibraryStorageMigrationMarker(const QString &dataRoot)
{
    return QFileInfo::exists(libraryStorageMigrationMarkerPath(dataRoot));
}

bool writeLibraryStorageMigrationMarker(const QString &dataRoot)
{
    QSaveFile file(libraryStorageMigrationMarkerPath(dataRoot));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return false;
    }

    const QByteArray payload = QByteArrayLiteral("{\"version\":1}\n");
    if (file.write(payload) < 0) {
        file.cancelWriting();
        return false;
    }

    return file.commit();
}

void appendLaunchTimelineEventForDataRoot(const QString &dataRoot, const QString &message)
{
    if (dataRoot.isEmpty()) {
        return;
    }

    const qint64 startedAtMs = launchStartedAtMsFromEnv();
    if (startedAtMs <= 0) {
        return;
    }

    const qint64 elapsedMs = std::max<qint64>(0, QDateTime::currentMSecsSinceEpoch() - startedAtMs);
    appendNormalizedTextLogLine(
        startupLaunchLogPathForDataRoot(dataRoot),
        QStringLiteral("[launch][%1ms] %2").arg(elapsedMs).arg(message)
    );
}

QVariantMap runDatabaseHealthCheck(const QString &dbPath)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("code"), QStringLiteral("unknown"));
    result.insert(QStringLiteral("message"), QString());
    result.insert(QStringLiteral("dbPath"), dbPath);
    result.insert(QStringLiteral("exists"), false);
    result.insert(QStringLiteral("fileWritable"), false);
    result.insert(QStringLiteral("writeLockFree"), false);
    result.insert(QStringLiteral("quickCheckOk"), false);
    result.insert(QStringLiteral("quickCheckResult"), QString());

    const QFileInfo dbInfo(dbPath);
    if (!dbInfo.exists() || !dbInfo.isFile()) {
        result.insert(QStringLiteral("code"), QStringLiteral("missing"));
        result.insert(QStringLiteral("message"), QStringLiteral("Database file is missing."));
        return result;
    }

    result.insert(QStringLiteral("exists"), true);
    result.insert(QStringLiteral("fileWritable"), dbInfo.isWritable());

    const QString connectionName = QStringLiteral("comic_pile_health_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));

    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(dbPath);
        if (!db.open()) {
            result.insert(QStringLiteral("code"), QStringLiteral("open_failed"));
            result.insert(QStringLiteral("message"), QStringLiteral("Failed to open DB: %1").arg(db.lastError().text()));
            db.close();
        } else {
            bool quickCheckOk = false;
            QString quickCheckResult;
            {
                QSqlQuery quickQuery(db);
                if (quickQuery.exec(QStringLiteral("PRAGMA quick_check(1)"))) {
                    if (quickQuery.next()) {
                        quickCheckResult = quickQuery.value(0).toString().trimmed();
                        quickCheckOk = quickCheckResult.compare(QStringLiteral("ok"), Qt::CaseInsensitive) == 0;
                    }
                } else {
                    quickCheckResult = quickQuery.lastError().text().trimmed();
                }
            }

            bool writeLockFree = false;
            QString writeCheckError;
            {
                QSqlQuery txQuery(db);
                if (txQuery.exec(QStringLiteral("BEGIN IMMEDIATE TRANSACTION"))) {
                    writeLockFree = true;
                    QSqlQuery rollbackQuery(db);
                    rollbackQuery.exec(QStringLiteral("ROLLBACK"));
                } else {
                    writeCheckError = txQuery.lastError().text().trimmed();
                }
            }

            result.insert(QStringLiteral("writeLockFree"), writeLockFree);
            result.insert(QStringLiteral("quickCheckOk"), quickCheckOk);
            result.insert(QStringLiteral("quickCheckResult"), quickCheckResult);

            if (!quickCheckOk) {
                result.insert(QStringLiteral("code"), QStringLiteral("integrity_failed"));
                result.insert(
                    QStringLiteral("message"),
                    quickCheckResult.isEmpty()
                        ? QStringLiteral("Integrity check failed.")
                        : quickCheckResult
                );
            } else if (!writeLockFree) {
                result.insert(QStringLiteral("code"), QStringLiteral("write_locked"));
                result.insert(
                    QStringLiteral("message"),
                    writeCheckError.isEmpty()
                        ? QStringLiteral("Database is locked for writing.")
                        : writeCheckError
                );
            } else if (!dbInfo.isWritable()) {
                result.insert(QStringLiteral("code"), QStringLiteral("readonly_file"));
                result.insert(QStringLiteral("message"), QStringLiteral("Database file is read-only."));
            } else {
                result.insert(QStringLiteral("ok"), true);
                result.insert(QStringLiteral("code"), QStringLiteral("ok"));
                result.insert(QStringLiteral("message"), QString());
            }

            db.close();
        }
    }

    return result;
}

QVariantMap buildStartupInventorySignature(const QString &dataRoot, const QString &dbPath)
{
    QVariantMap result;

    Q_UNUSED(dbPath);

    const QString libraryRootPath = QDir(dataRoot).filePath(QStringLiteral("Library"));
    const QFileInfo libraryRootInfo(libraryRootPath);
    const bool libraryExists = libraryRootInfo.exists() && libraryRootInfo.isDir();

    qint64 libraryLatestModifiedMs = libraryExists
        ? libraryRootInfo.lastModified().toUTC().toMSecsSinceEpoch()
        : -1;
    qint64 libraryTotalBytes = 0;
    int libraryFileCount = 0;

    if (libraryExists) {
        QDirIterator iterator(
            libraryRootPath,
            QDir::Files | QDir::NoDotAndDotDot,
            QDirIterator::Subdirectories
        );
        while (iterator.hasNext()) {
            const QString path = iterator.next();
            const QFileInfo info(path);
            if (!info.exists() || !info.isFile()) continue;
            libraryFileCount += 1;
            libraryTotalBytes += info.size();
            libraryLatestModifiedMs = std::max(
                libraryLatestModifiedMs,
                info.lastModified().toUTC().toMSecsSinceEpoch()
            );
        }
    }

    result.insert(QStringLiteral("libraryRootPath"), libraryRootPath);
    result.insert(QStringLiteral("libraryExists"), libraryExists);
    result.insert(QStringLiteral("libraryFileCount"), libraryFileCount);
    result.insert(QStringLiteral("libraryTotalBytes"), libraryTotalBytes);
    result.insert(QStringLiteral("libraryLatestModifiedMs"), libraryLatestModifiedMs);
    result.insert(
        QStringLiteral("signatureKey"),
        QStringLiteral("lib:%1:%2:%3:%4")
            .arg(libraryExists ? QStringLiteral("1") : QStringLiteral("0"))
            .arg(libraryFileCount)
            .arg(libraryTotalBytes)
            .arg(libraryLatestModifiedMs)
    );
    return result;
}

} // namespace ComicStartupRuntime
