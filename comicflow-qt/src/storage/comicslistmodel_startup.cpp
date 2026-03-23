#include "storage/comicslistmodel.h"

#include "storage/startupinventoryops.h"
#include "storage/startupruntimeutils.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QUrl>
#include <QtGlobal>

namespace {

QSettings relocationSettingsStore()
{
    return QSettings(
        QSettings::IniFormat,
        QSettings::UserScope,
        QStringLiteral("ComicPile"),
        QStringLiteral("ComicPile")
    );
}

QString pendingDataRootRelocationSettingsKey()
{
    return QStringLiteral("AppSettings/libraryDataRelocationPendingPath");
}

QString normalizeStartupPathInput(const QString &rawInput)
{
    QString input = rawInput.trimmed();
    if (input.isEmpty()) return {};

    if ((input.startsWith('"') && input.endsWith('"')) || (input.startsWith('\'') && input.endsWith('\''))) {
        input = input.mid(1, input.length() - 2).trimmed();
    }

    const QUrl url = QUrl::fromUserInput(input);
    if (url.isValid() && url.isLocalFile()) {
        return QDir::toNativeSeparators(url.toLocalFile());
    }

    return QDir::toNativeSeparators(input);
}

QString normalizedFolderPath(const QString &rawPath)
{
    const QString normalized = normalizeStartupPathInput(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }
    return QDir::cleanPath(QDir::fromNativeSeparators(normalized));
}

QString pendingDataRootRelocationPathFromSettings()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(pendingDataRootRelocationSettingsKey()).toString());
}

QString persistedFolderPathForDisplay(const QString &rawPath)
{
    const QString normalized = normalizedFolderPath(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }
    return QDir::toNativeSeparators(normalized);
}

bool writePendingDataRootRelocationPath(const QString &rawPath, QString &errorText)
{
    QSettings settings = relocationSettingsStore();
    settings.setValue(
        pendingDataRootRelocationSettingsKey(),
        persistedFolderPathForDisplay(rawPath)
    );
    settings.sync();
    if (settings.status() != QSettings::NoError) {
        if (settings.status() == QSettings::AccessError) {
            errorText = QStringLiteral(
                "Could not schedule the new library data location because the app could not write its transfer request to settings storage."
            );
        } else {
            errorText = QStringLiteral(
                "Could not schedule the new library data location because the app could not update its settings storage."
            );
        }
        return false;
    }
    return true;
}

bool hasExternalDataRootOverride()
{
    return !qEnvironmentVariable("COMIC_PILE_DATA_DIR").trimmed().isEmpty()
        || !qEnvironmentVariable("COMICFLOW_DATA_DIR").trimmed().isEmpty();
}

bool isSameOrNestedFolderPath(const QString &leftPath, const QString &rightPath)
{
    const QString left = normalizedFolderPath(leftPath);
    const QString right = normalizedFolderPath(rightPath);
    if (left.isEmpty() || right.isEmpty()) {
        return false;
    }
    if (left.compare(right, Qt::CaseInsensitive) == 0) {
        return true;
    }
    return right.startsWith(left + QLatin1Char('/'), Qt::CaseInsensitive)
        || left.startsWith(right + QLatin1Char('/'), Qt::CaseInsensitive);
}

QString validateScheduledDataRootRelocationTarget(
    const QString &currentDataRoot,
    const QString &targetPath
)
{
    if (hasExternalDataRootOverride()) {
        return QStringLiteral("Library data location is currently forced by an external launch override. Remove that override before changing it here.");
    }

    const QString normalizedCurrent = normalizedFolderPath(currentDataRoot);
    const QString normalizedTarget = normalizedFolderPath(targetPath);
    if (normalizedTarget.isEmpty()) {
        return QStringLiteral("Choose a new folder for library data.");
    }
    if (normalizedCurrent.isEmpty()) {
        return QStringLiteral("Current library data location is unavailable.");
    }
    if (normalizedCurrent.compare(normalizedTarget, Qt::CaseInsensitive) == 0) {
        return QStringLiteral("Choose a different folder for library data.");
    }
    if (isSameOrNestedFolderPath(normalizedCurrent, normalizedTarget)) {
        return QStringLiteral("Choose a folder outside the current library data location.");
    }

    const QFileInfo targetInfo(QDir::toNativeSeparators(normalizedTarget));
    if (targetInfo.exists() && !targetInfo.isDir()) {
        return QStringLiteral("The selected library data location is not a folder.");
    }

    if (targetInfo.exists()) {
        const QDir targetDir(targetInfo.absoluteFilePath());
        if (!targetDir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).isEmpty()) {
            return QStringLiteral("Choose an empty folder for the new library data location.");
        }
    }

    const QFileInfo currentInfo(QDir::toNativeSeparators(normalizedCurrent));
    if (!currentInfo.exists() || !currentInfo.isDir()) {
        return QStringLiteral("Current library data location is unavailable.");
    }

    return {};
}

} // namespace

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
    return persistedFolderPathForDisplay(pendingDataRootRelocationPathFromSettings());
}

QVariantMap ComicsListModel::scheduleDataRootRelocation(const QString &targetPath)
{
    QVariantMap result;
    result.insert(QStringLiteral("ok"), false);
    result.insert(QStringLiteral("error"), QString());
    result.insert(QStringLiteral("pendingPath"), QString());
    result.insert(QStringLiteral("restartRequired"), false);

    const QString validationError = validateScheduledDataRootRelocationTarget(m_dataRoot, targetPath);
    if (!validationError.isEmpty()) {
        result.insert(QStringLiteral("error"), validationError);
        return result;
    }

    QString persistError;
    if (!writePendingDataRootRelocationPath(targetPath, persistError)) {
        result.insert(QStringLiteral("error"), persistError);
        return result;
    }

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pendingPath"), persistedFolderPathForDisplay(targetPath));
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
