#include "storage/datarootrelocationbootstrap.h"

#include "storage/datarootsettingsutils.h"
#include "storage/startupruntimeutils.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>

#include <algorithm>
#include <cmath>
#include <limits>

namespace {

class DataMigrationProgressState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentFileName READ currentFileName NOTIFY currentFileNameChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)
    Q_PROPERTY(int processedCount READ processedCount NOTIFY processedCountChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit DataMigrationProgressState(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    QString currentFileName() const { return m_currentFileName; }
    int totalCount() const { return m_totalCount; }
    int processedCount() const { return m_processedCount; }
    bool active() const { return m_active; }

    void setCurrentFileName(const QString &value)
    {
        if (m_currentFileName == value) {
            return;
        }
        m_currentFileName = value;
        emit currentFileNameChanged();
    }

    void setTotalCount(int value)
    {
        const int normalized = qMax(0, value);
        if (m_totalCount == normalized) {
            return;
        }
        m_totalCount = normalized;
        emit totalCountChanged();
    }

    void setProcessedCount(int value)
    {
        const int normalized = qMax(0, value);
        if (m_processedCount == normalized) {
            return;
        }
        m_processedCount = normalized;
        emit processedCountChanged();
    }

    void setActive(bool value)
    {
        if (m_active == value) {
            return;
        }
        m_active = value;
        emit activeChanged();
    }

signals:
    void currentFileNameChanged();
    void totalCountChanged();
    void processedCountChanged();
    void activeChanged();

private:
    QString m_currentFileName;
    int m_totalCount = 0;
    int m_processedCount = 0;
    bool m_active = false;
};

void clearCopiedLibraryStorageMigrationMarker(const QString &dataRoot)
{
    const QString markerPath = ComicStartupRuntime::libraryStorageMigrationMarkerPath(dataRoot);
    if (markerPath.trimmed().isEmpty()) {
        return;
    }

    const QFileInfo markerInfo(markerPath);
    if (!markerInfo.exists() || !markerInfo.isFile()) {
        return;
    }

    QFile::remove(markerInfo.absoluteFilePath());
}

bool ensureEmptyDirectoryTarget(const QString &targetRoot, QString &errorText)
{
    const QFileInfo info(QDir::toNativeSeparators(targetRoot));
    if (info.exists() && !info.isDir()) {
        errorText = QStringLiteral("The scheduled library data location is not a folder.");
        return false;
    }

    if (info.exists()) {
        const QDir dir(info.absoluteFilePath());
        if (!dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System).isEmpty()) {
            errorText = QStringLiteral("The scheduled library data location is not empty.");
            return false;
        }
        return true;
    }

    if (!QDir().mkpath(QDir::toNativeSeparators(targetRoot))) {
        errorText = QStringLiteral("Failed to create the scheduled library data folder.");
        return false;
    }
    return true;
}

struct DataRootCopyPlan {
    QStringList relativeDirectories;
    QStringList relativeFiles;
};

struct DataMigrationWindowPlacement {
    QString stateToken = QStringLiteral("fullscreen");
    qreal x = 0;
    qreal y = 0;
    int width = 0;
    int height = 0;
};

DataRootCopyPlan buildDataRootCopyPlan(const QString &sourceRoot)
{
    DataRootCopyPlan plan;
    const QDir sourceDir(QDir::toNativeSeparators(sourceRoot));
    QDirIterator iterator(
        sourceDir.absolutePath(),
        QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System,
        QDirIterator::Subdirectories
    );

    while (iterator.hasNext()) {
        const QString entryPath = iterator.next();
        const QFileInfo entryInfo(entryPath);
        const QString relativePath = sourceDir.relativeFilePath(entryInfo.absoluteFilePath());
        if (relativePath.trimmed().isEmpty()) {
            continue;
        }

        if (entryInfo.isDir()) {
            plan.relativeDirectories.push_back(relativePath);
            continue;
        }

        if (entryInfo.isFile()) {
            plan.relativeFiles.push_back(relativePath);
        }
    }

    std::sort(
        plan.relativeDirectories.begin(),
        plan.relativeDirectories.end(),
        [](const QString &left, const QString &right) {
            const int leftDepth = left.count(QLatin1Char('/')) + left.count(QLatin1Char('\\'));
            const int rightDepth = right.count(QLatin1Char('/')) + right.count(QLatin1Char('\\'));
            if (leftDepth != rightDepth) {
                return leftDepth < rightDepth;
            }
            return QString::compare(left, right, Qt::CaseInsensitive) < 0;
        }
    );

    return plan;
}

void pumpMigrationUi()
{
    QCoreApplication::processEvents();
}

DataMigrationWindowPlacement loadDataMigrationWindowPlacement(const QString &dataRoot)
{
    DataMigrationWindowPlacement placement;
    const QString rawSnapshot = ComicStartupRuntime::readStartupSnapshot(dataRoot).trimmed();
    if (rawSnapshot.isEmpty()) {
        return placement;
    }

    const QJsonDocument document = QJsonDocument::fromJson(rawSnapshot.toUtf8());
    if (!document.isObject()) {
        return placement;
    }

    const QJsonObject snapshot = document.object();
    const QString token = snapshot.value(QStringLiteral("windowState")).toString().trimmed();
    if (!token.isEmpty()) {
        placement.stateToken = token;
    }

    const double savedX = snapshot.value(QStringLiteral("windowX")).toDouble(std::numeric_limits<double>::quiet_NaN());
    const double savedY = snapshot.value(QStringLiteral("windowY")).toDouble(std::numeric_limits<double>::quiet_NaN());
    const int savedWidth = snapshot.value(QStringLiteral("windowWidth")).toInt();
    const int savedHeight = snapshot.value(QStringLiteral("windowHeight")).toInt();

    if (std::isfinite(savedX)) {
        placement.x = savedX;
    }
    if (std::isfinite(savedY)) {
        placement.y = savedY;
    }
    if (savedWidth > 0) {
        placement.width = savedWidth;
    }
    if (savedHeight > 0) {
        placement.height = savedHeight;
    }

    return placement;
}

bool showDataMigrationWindow(
    QQmlApplicationEngine &engine,
    DataMigrationProgressState &progressState,
    const DataMigrationWindowPlacement &placement
)
{
    engine.rootContext()->setContextProperty("databaseMigrationState", &progressState);
    engine.rootContext()->setContextProperty("databaseMigrationWindowStateToken", placement.stateToken);
    engine.rootContext()->setContextProperty("databaseMigrationWindowX", placement.x);
    engine.rootContext()->setContextProperty("databaseMigrationWindowY", placement.y);
    engine.rootContext()->setContextProperty("databaseMigrationWindowWidth", placement.width);
    engine.rootContext()->setContextProperty("databaseMigrationWindowHeight", placement.height);
    engine.loadFromModule("ComicPile", "DatabaseMigrationWindow");
    pumpMigrationUi();
    return !engine.rootObjects().isEmpty();
}

void closeDataMigrationWindow(QQmlApplicationEngine &engine)
{
    const QObjectList roots = engine.rootObjects();
    for (QObject *root : roots) {
        if (auto *window = qobject_cast<QWindow *>(root)) {
            window->close();
        }
    }
    pumpMigrationUi();
}

bool copyDirectoryContentsRecursive(
    const QString &sourceRoot,
    const QString &targetRoot,
    DataMigrationProgressState *progressState,
    QString &errorText
)
{
    if (!QDir().mkpath(QDir::toNativeSeparators(targetRoot))) {
        errorText = QStringLiteral("Failed to create the new library data folder.");
        return false;
    }

    const DataRootCopyPlan plan = buildDataRootCopyPlan(sourceRoot);
    const QDir sourceDir(QDir::toNativeSeparators(sourceRoot));
    const QDir targetDir(QDir::toNativeSeparators(targetRoot));

    if (progressState) {
        progressState->setTotalCount(plan.relativeFiles.size());
        progressState->setProcessedCount(0);
        progressState->setCurrentFileName(QString());
        progressState->setActive(true);
        pumpMigrationUi();
    }

    for (const QString &relativeDir : plan.relativeDirectories) {
        const QString targetPath = targetDir.filePath(relativeDir);
        if (!QDir().mkpath(targetPath)) {
            errorText = QStringLiteral("Failed to create folder in the new library data location.");
            return false;
        }
    }

    int processedCount = 0;
    for (const QString &relativeFile : plan.relativeFiles) {
        const QString sourcePath = sourceDir.filePath(relativeFile);
        const QString targetPath = targetDir.filePath(relativeFile);
        const QFileInfo targetInfo(targetPath);
        if (!QDir().mkpath(targetInfo.absolutePath())) {
            errorText = QStringLiteral("Failed to prepare the new library data location.");
            return false;
        }
        if (QFileInfo::exists(targetPath)) {
            errorText = QStringLiteral("The new library data location already contains conflicting files.");
            return false;
        }

        if (progressState) {
            progressState->setCurrentFileName(QDir::toNativeSeparators(relativeFile));
            progressState->setProcessedCount(processedCount);
            pumpMigrationUi();
        }

        if (!QFile::copy(sourcePath, targetPath)) {
            errorText = QStringLiteral("Failed to copy library data to the new location.");
            return false;
        }

        processedCount += 1;
        if (progressState) {
            progressState->setProcessedCount(processedCount);
            pumpMigrationUi();
        }
    }

    return true;
}

bool removeSourceDirectoryAfterRelocation(
    const QString &sourceRoot,
    DataMigrationProgressState *progressState,
    QString &errorText
)
{
    const QString normalizedSourceRoot = ComicDataRootSettings::normalizedFolderPath(sourceRoot);
    if (normalizedSourceRoot.isEmpty()) {
        errorText = QStringLiteral("Original library data location is unavailable.");
        return false;
    }

    const QFileInfo sourceInfo(QDir::toNativeSeparators(normalizedSourceRoot));
    if (!sourceInfo.exists() || !sourceInfo.isDir()) {
        return true;
    }

    if (progressState) {
        progressState->setCurrentFileName(QStringLiteral("Removing old library data location..."));
        pumpMigrationUi();
    }

    QDir sourceDir(sourceInfo.absoluteFilePath());
    if (!sourceDir.removeRecursively()) {
        errorText = QStringLiteral("Failed to remove the previous library data folder after transfer.");
        return false;
    }

    return true;
}

QString resolveLaunchDataRootCandidate()
{
    const QString envValuePrimary = qEnvironmentVariable("COMIC_PILE_DATA_DIR").trimmed();
    if (!envValuePrimary.isEmpty()) {
        return QDir(envValuePrimary).absolutePath();
    }

    const QString envValueLegacy = qEnvironmentVariable("COMICFLOW_DATA_DIR").trimmed();
    if (!envValueLegacy.isEmpty()) {
        return QDir(envValueLegacy).absolutePath();
    }

    const QString configuredOverride = ComicDataRootSettings::configuredDataRootOverridePath();
    if (!configuredOverride.isEmpty()) {
        return QDir(configuredOverride).absolutePath();
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    const QStringList candidates = {
        QDir(appDir).filePath("Database"),
        QDir(appDir).filePath("../Database"),
        QDir(appDir).filePath("../../Database"),
        QDir(appDir).filePath("../../../Database"),
        QDir(currentDir).filePath("Database"),
        QDir(currentDir).filePath("../Database"),
        QDir(currentDir).filePath("../../Database"),
    };

    for (const QString &candidate : candidates) {
        const QString found = ComicStartupRuntime::absolutePathIfExists(candidate);
        if (!found.isEmpty()) {
            return found;
        }
    }

    return QDir(appDir).filePath("Database");
}

} // namespace

namespace ComicDataRootRelocationBootstrap {

void processPendingDataRootRelocation()
{
    if (ComicDataRootSettings::hasExternalDataRootOverride()) {
        return;
    }

    const QString pendingTarget = ComicDataRootSettings::pendingDataRootRelocationPath();
    if (pendingTarget.isEmpty()) {
        return;
    }

    const QString currentRoot = ComicDataRootSettings::normalizedFolderPath(resolveLaunchDataRootCandidate());
    if (currentRoot.isEmpty()) {
        return;
    }

    const QFileInfo currentInfo(QDir::toNativeSeparators(currentRoot));
    if (!currentInfo.exists() || !currentInfo.isDir()) {
        return;
    }

    const QString normalizedTarget = ComicDataRootSettings::normalizedFolderPath(pendingTarget);
    if (normalizedTarget.isEmpty()) {
        return;
    }

    if (currentRoot.compare(normalizedTarget, Qt::CaseInsensitive) == 0) {
        ComicDataRootSettings::clearPendingDataRootRelocationPath();
        return;
    }

    if (ComicDataRootSettings::isSameOrNestedFolderPath(currentRoot, normalizedTarget)) {
        return;
    }

    QString errorText;
    DataMigrationProgressState progressState;
    QQmlApplicationEngine migrationEngine;
    const DataMigrationWindowPlacement migrationPlacement = loadDataMigrationWindowPlacement(currentRoot);
    const bool migrationWindowVisible = showDataMigrationWindow(
        migrationEngine,
        progressState,
        migrationPlacement
    );
    if (!ensureEmptyDirectoryTarget(normalizedTarget, errorText)) {
        if (migrationWindowVisible) {
            closeDataMigrationWindow(migrationEngine);
        }
        return;
    }
    if (!copyDirectoryContentsRecursive(currentRoot, normalizedTarget, migrationWindowVisible ? &progressState : nullptr, errorText)) {
        if (migrationWindowVisible) {
            closeDataMigrationWindow(migrationEngine);
        }
        return;
    }
    clearCopiedLibraryStorageMigrationMarker(normalizedTarget);
    if (!ComicDataRootSettings::writeConfiguredDataRootOverridePath(normalizedTarget)) {
        if (migrationWindowVisible) {
            closeDataMigrationWindow(migrationEngine);
        }
        return;
    }
    if (!removeSourceDirectoryAfterRelocation(
            currentRoot,
            migrationWindowVisible ? &progressState : nullptr,
            errorText
        )) {
        if (migrationWindowVisible) {
            closeDataMigrationWindow(migrationEngine);
        }
        return;
    }
    ComicDataRootSettings::clearPendingDataRootRelocationPath();
    if (migrationWindowVisible) {
        closeDataMigrationWindow(migrationEngine);
    }
}

QString resolveLaunchDataRoot()
{
    return resolveLaunchDataRootCandidate();
}

} // namespace ComicDataRootRelocationBootstrap

#include "datarootrelocationbootstrap.moc"
