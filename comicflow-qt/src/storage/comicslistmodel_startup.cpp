#include "storage/comicslistmodel.h"

#include "storage/datarootrelocationops.h"
#include "storage/datarootsettingsutils.h"
#include "storage/startupinventoryops.h"
#include "storage/startupruntimeutils.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QUuid>

namespace {

QString storageAccessActionText(const QString &target)
{
    if (target == QStringLiteral("library data")) {
        return QStringLiteral("Open the library data folder and check write access.");
    }
    if (target == QStringLiteral("library folder")) {
        return QStringLiteral("Open the library folder and check write access.");
    }
    if (target == QStringLiteral("runtime folder")) {
        return QStringLiteral("Open the runtime folder and check write access.");
    }
    if (target == QStringLiteral("database")) {
        return QStringLiteral("Check whether the library database is locked or read-only.");
    }
    return QStringLiteral("Check the storage location and write access.");
}

bool ensureFolderReadyForStorageProbe(
    const QString &folderPath,
    const QString &folderLabel,
    QString &errorText
)
{
    if (folderPath.trimmed().isEmpty()) {
        errorText = QStringLiteral("%1 path is empty.").arg(folderLabel);
        return false;
    }

    const QDir folder(folderPath);
    if (folder.exists()) {
        return true;
    }

    if (!QDir().mkpath(folderPath)) {
        errorText = QStringLiteral("Couldn't create %1.").arg(folderLabel);
        return false;
    }

    return true;
}

bool runStorageWriteProbe(
    const QString &folderPath,
    const QString &folderLabel,
    QString &errorText
)
{
    if (!ensureFolderReadyForStorageProbe(folderPath, folderLabel, errorText)) {
        return false;
    }

    const QString probeId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString probeBaseName = QStringLiteral(".comic-pile-storage-check-%1").arg(probeId);
    const QString createdPath = QDir(folderPath).filePath(probeBaseName + QStringLiteral(".tmp"));
    const QString renamedPath = QDir(folderPath).filePath(probeBaseName + QStringLiteral(".check"));

    auto cleanupProbeFiles = [&]() {
        QFile::remove(createdPath);
        QFile::remove(renamedPath);
    };

    cleanupProbeFiles();

    QFile createdFile(createdPath);
    if (!createdFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        errorText = QStringLiteral("Couldn't create a temporary file in %1.").arg(folderLabel);
        cleanupProbeFiles();
        return false;
    }

    if (createdFile.write("comic-pile-storage-check\n") < 0) {
        errorText = QStringLiteral("Couldn't write a temporary file in %1.").arg(folderLabel);
        createdFile.close();
        cleanupProbeFiles();
        return false;
    }
    createdFile.close();

    if (!QFile::rename(createdPath, renamedPath)) {
        errorText = QStringLiteral("Couldn't rename a temporary file in %1.").arg(folderLabel);
        cleanupProbeFiles();
        return false;
    }

    QSaveFile replaceFile(renamedPath);
    if (!replaceFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        errorText = QStringLiteral("Couldn't replace a temporary file in %1.").arg(folderLabel);
        cleanupProbeFiles();
        return false;
    }

    if (replaceFile.write("comic-pile-storage-check-replaced\n") < 0 || !replaceFile.commit()) {
        errorText = QStringLiteral("Couldn't replace a temporary file in %1.").arg(folderLabel);
        replaceFile.cancelWriting();
        cleanupProbeFiles();
        return false;
    }

    if (!QFile::remove(renamedPath)) {
        errorText = QStringLiteral("Couldn't remove a temporary file in %1.").arg(folderLabel);
        cleanupProbeFiles();
        return false;
    }

    return true;
}

bool canOpenLibraryDatabaseForReadWrite(const QString &dbPath, QString &errorText)
{
    if (dbPath.trimmed().isEmpty()) {
        errorText = QStringLiteral("Library database path is empty.");
        return false;
    }

    const QFileInfo dbInfo(dbPath);
    if (!dbInfo.exists() || !dbInfo.isFile()) {
        errorText = QStringLiteral("Library database file is missing.");
        return false;
    }

    QFile dbFile(dbPath);
    if (!dbFile.open(QIODevice::ReadWrite)) {
        errorText = QStringLiteral("Couldn't open the library database for read/write access.");
        return false;
    }

    dbFile.close();
    return true;
}

} // namespace

QVariantMap ComicsListModel::checkStorageAccess() const
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("statusText"), QStringLiteral("Needs attention"));
    result.insert(QStringLiteral("hintText"), QString());
    result.insert(QStringLiteral("error"), QString());

    QString errorText;
    const QString libraryPath = QDir(m_dataRoot).filePath(QStringLiteral("Library"));
    const QString runtimePath = ComicStartupRuntime::startupRuntimeDirPath(m_dataRoot);

    if (!runStorageWriteProbe(m_dataRoot, QStringLiteral("library data"), errorText)) {
        result.insert(QStringLiteral("hintText"), storageAccessActionText(QStringLiteral("library data")));
        result.insert(QStringLiteral("error"), errorText);
        return result;
    }

    if (!canOpenLibraryDatabaseForReadWrite(m_dbPath, errorText)) {
        result.insert(QStringLiteral("hintText"), storageAccessActionText(QStringLiteral("database")));
        result.insert(QStringLiteral("error"), errorText);
        return result;
    }

    if (!runStorageWriteProbe(libraryPath, QStringLiteral("library folder"), errorText)) {
        result.insert(QStringLiteral("hintText"), storageAccessActionText(QStringLiteral("library folder")));
        result.insert(QStringLiteral("error"), errorText);
        return result;
    }

    if (!runStorageWriteProbe(runtimePath, QStringLiteral("runtime folder"), errorText)) {
        result.insert(QStringLiteral("hintText"), storageAccessActionText(QStringLiteral("runtime folder")));
        result.insert(QStringLiteral("error"), errorText);
        return result;
    }

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("statusText"), QStringLiteral("All good"));
    return result;
}

QVariantMap ComicsListModel::checkDatabaseHealth() const
{
    return ComicStartupInventoryOps::checkDatabaseHealth(m_dbPath);
}

int ComicsListModel::requestDatabaseHealthCheckAsync()
{
    return ComicStartupInventoryOps::requestDatabaseHealthCheckAsync(
        this,
        m_dbPath,
        [this](int requestId, const QVariantMap &result) {
            emit databaseHealthChecked(requestId, result);
        }
    );
}

bool ComicsListModel::isLibraryStorageMigrationPending() const
{
    return ComicStartupInventoryOps::isLibraryStorageMigrationPending(m_dataRoot);
}

int ComicsListModel::requestLibraryStorageMigrationAsync()
{
    return ComicStartupInventoryOps::requestLibraryStorageMigrationAsync(
        this,
        m_dataRoot,
        m_dbPath,
        [this](int requestId, const QVariantMap &result) {
            emit libraryStorageMigrationFinished(requestId, result);
        }
    );
}

QString ComicsListModel::pendingDataRootRelocationPath() const
{
    return ComicDataRootSettings::persistedFolderPathForDisplay(
        ComicDataRootSettings::pendingDataRootRelocationPath()
    );
}

QVariantMap ComicsListModel::scheduleDataRootRelocation(const QString &targetPath)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("error"), QString());
    result.insert(QStringLiteral("pendingPath"), QString());
    result.insert(QStringLiteral("restartRequired"), false);

    const QString validationError = ComicDataRootRelocationOps::validateScheduledTarget(m_dataRoot, targetPath);
    if (!validationError.isEmpty()) {
        result.insert(QStringLiteral("error"), validationError);
        return result;
    }

    QString persistError;
    if (!ComicDataRootSettings::writePendingDataRootRelocationPath(targetPath, persistError)) {
        result.insert(QStringLiteral("error"), persistError);
        return result;
    }

    result.insert(QStringLiteral("ok"), true);
    result.insert(
        QStringLiteral("pendingPath"),
        ComicDataRootSettings::persistedFolderPathForDisplay(targetPath)
    );
    result.insert(QStringLiteral("restartRequired"), true);
    return result;
}

QString ComicsListModel::readStartupSnapshot() const
{
    return ComicStartupRuntime::readStartupSnapshot(m_dataRoot);
}

bool ComicsListModel::writeStartupSnapshot(const QString &payload) const
{
    return ComicStartupRuntime::writeStartupSnapshot(m_dataRoot, payload);
}

QVariantMap ComicsListModel::readContinueReadingState() const
{
    return ComicStartupRuntime::readContinueReadingState(m_dataRoot);
}

bool ComicsListModel::writeContinueReadingState(const QVariantMap &state) const
{
    return ComicStartupRuntime::writeContinueReadingState(m_dataRoot, state);
}

QVariantMap ComicsListModel::currentStartupInventorySignature() const
{
    return ComicStartupInventoryOps::currentStartupInventorySignature(m_dataRoot, m_dbPath);
}

int ComicsListModel::requestStartupInventorySignatureAsync()
{
    return ComicStartupInventoryOps::requestStartupInventorySignatureAsync(
        this,
        m_dataRoot,
        m_dbPath,
        [this](int requestId, const QVariantMap &result) {
            emit startupInventorySignatureReady(requestId, result);
        }
    );
}

QString ComicsListModel::startupLogPath() const
{
    return ComicStartupRuntime::startupLogPath(m_dataRoot);
}

QString ComicsListModel::startupDebugLogPath() const
{
    return ComicStartupRuntime::startupDebugLogPath(m_dataRoot);
}

QString ComicsListModel::startupPreviewPath() const
{
    return ComicStartupRuntime::startupPreviewPath(m_dataRoot);
}

QString ComicsListModel::startupPreviewMetaPath() const
{
    return ComicStartupRuntime::startupPreviewMetaPath(m_dataRoot);
}

bool ComicsListModel::writeStartupPreviewMeta(const QString &payload) const
{
    return ComicStartupRuntime::writeStartupPreviewMeta(m_dataRoot, payload);
}

QString ComicsListModel::readStartupPreviewMeta() const
{
    return ComicStartupRuntime::readStartupPreviewMeta(m_dataRoot);
}

void ComicsListModel::resetStartupLog() const
{
    ComicStartupRuntime::resetTextLogFile(startupLogPath());
}

void ComicsListModel::appendStartupLog(const QString &line) const
{
    ComicStartupRuntime::appendNormalizedTextLogLine(startupLogPath(), line);
}

void ComicsListModel::resetStartupDebugLog() const
{
    ComicStartupRuntime::resetTextLogFile(startupDebugLogPath());
}

void ComicsListModel::appendStartupDebugLog(const QString &line) const
{
    ComicStartupRuntime::appendNormalizedTextLogLine(startupDebugLogPath(), line);
}
