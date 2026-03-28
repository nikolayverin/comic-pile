#include "storage/comicslistmodel.h"

#include "storage/datarootrelocationops.h"
#include "storage/datarootsettingsutils.h"
#include "storage/startupinventoryops.h"
#include "storage/startupruntimeutils.h"

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
