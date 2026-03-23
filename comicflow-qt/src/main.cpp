#include "storage/comicslistmodel.h"
#include "storage/startupruntimeutils.h"
#include "common/singleinstanceguard.h"
#include "comicpile_build_iteration.h"

#include <QApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFile>
#include <QFont>
#include <QCryptographicHash>
#include <QFileInfo>
#include <QSettings>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QWindow>
#include <QtMath>
#include <QtGlobal>
#include <cmath>
#include <limits>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace {

#ifdef Q_OS_WIN
constexpr int kWindowCornerRadiusPx = 14;

void applyRoundedWindowRegion(QWindow *window)
{
    if (!window) {
        return;
    }

    const HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (!hwnd) {
        return;
    }

    if (window->visibility() != QWindow::Windowed) {
        SetWindowRgn(hwnd, nullptr, TRUE);
        return;
    }

    const qreal dpr = qMax<qreal>(1.0, window->devicePixelRatio());
    const int widthPx = qMax(1, qRound(window->width() * dpr));
    const int heightPx = qMax(1, qRound(window->height() * dpr));
    const int radiusPx = qMax(1, qRound(kWindowCornerRadiusPx * dpr));
    HRGN region = CreateRoundRectRgn(0, 0, widthPx + 1, heightPx + 1, radiusPx * 2, radiusPx * 2);
    if (!region) {
        return;
    }

    if (SetWindowRgn(hwnd, region, TRUE) == 0) {
        DeleteObject(region);
    }
}

void installRoundedWindowRegion(QWindow *window)
{
    if (!window) {
        return;
    }

    auto updateRegion = [window]() {
        applyRoundedWindowRegion(window);
    };

    QObject::connect(window, &QWindow::widthChanged, window, updateRegion);
    QObject::connect(window, &QWindow::heightChanged, window, updateRegion);
    QObject::connect(window, &QWindow::visibleChanged, window, updateRegion);
    QObject::connect(window, &QWindow::visibilityChanged, window, [window](QWindow::Visibility) {
        applyRoundedWindowRegion(window);
    });

    QMetaObject::invokeMethod(window, updateRegion, Qt::QueuedConnection);
}
#endif

class LaunchState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool rootWindowObjectCreated READ rootWindowObjectCreated NOTIFY rootWindowObjectCreatedChanged)
    Q_PROPERTY(bool rootWindowShowCalled READ rootWindowShowCalled NOTIFY rootWindowShowCalledChanged)
    Q_PROPERTY(bool rootWindowVisible READ rootWindowVisible NOTIFY rootWindowVisibleChanged)

public:
    explicit LaunchState(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    bool rootWindowObjectCreated() const { return m_rootWindowObjectCreated; }
    bool rootWindowShowCalled() const { return m_rootWindowShowCalled; }
    bool rootWindowVisible() const { return m_rootWindowVisible; }

    void setRootWindowObjectCreated(bool value)
    {
        if (m_rootWindowObjectCreated == value) {
            return;
        }
        m_rootWindowObjectCreated = value;
        emit rootWindowObjectCreatedChanged();
    }

    void setRootWindowShowCalled(bool value)
    {
        if (m_rootWindowShowCalled == value) {
            return;
        }
        m_rootWindowShowCalled = value;
        emit rootWindowShowCalledChanged();
    }

    void setRootWindowVisible(bool value)
    {
        if (m_rootWindowVisible == value) {
            return;
        }
        m_rootWindowVisible = value;
        emit rootWindowVisibleChanged();
    }

signals:
    void rootWindowObjectCreatedChanged();
    void rootWindowShowCalledChanged();
    void rootWindowVisibleChanged();

private:
    bool m_rootWindowObjectCreated = false;
    bool m_rootWindowShowCalled = false;
    bool m_rootWindowVisible = false;
};

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

QString absolutePathIfExists(const QString &candidate)
{
    const QFileInfo info(candidate);
    if (!info.exists() || !info.isDir()) {
        return {};
    }
    return info.absoluteFilePath();
}

QString dataRootOverrideSettingsKey()
{
    return QStringLiteral("AppSettings/libraryDataRootPath");
}

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

QString normalizedFolderPath(const QString &rawPath)
{
    const QString trimmed = rawPath.trimmed();
    if (trimmed.isEmpty()) {
        return {};
    }
    return QDir::cleanPath(QDir::fromNativeSeparators(trimmed));
}

QString persistedFolderPathForDisplay(const QString &rawPath)
{
    const QString normalized = normalizedFolderPath(rawPath);
    if (normalized.isEmpty()) {
        return {};
    }
    return QDir::toNativeSeparators(normalized);
}

QString configuredDataRootOverridePath()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(dataRootOverrideSettingsKey()).toString());
}

QString pendingDataRootRelocationPath()
{
    QSettings settings = relocationSettingsStore();
    return normalizedFolderPath(settings.value(pendingDataRootRelocationSettingsKey()).toString());
}

bool writeConfiguredDataRootOverridePath(const QString &rawPath)
{
    QSettings settings = relocationSettingsStore();
    settings.setValue(dataRootOverrideSettingsKey(), persistedFolderPathForDisplay(rawPath));
    settings.sync();
    return settings.status() == QSettings::NoError;
}

bool clearPendingDataRootRelocationPath()
{
    QSettings settings = relocationSettingsStore();
    settings.remove(pendingDataRootRelocationSettingsKey());
    settings.sync();
    return settings.status() == QSettings::NoError;
}

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
    const QString normalizedSourceRoot = normalizedFolderPath(sourceRoot);
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

    const QString configuredOverride = configuredDataRootOverridePath();
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
        const QString found = absolutePathIfExists(candidate);
        if (!found.isEmpty()) {
            return found;
        }
    }

    return QDir(appDir).filePath("Database");
}

void processPendingDataRootRelocation()
{
    if (hasExternalDataRootOverride()) {
        return;
    }

    const QString pendingTarget = pendingDataRootRelocationPath();
    if (pendingTarget.isEmpty()) {
        return;
    }

    const QString currentRoot = normalizedFolderPath(resolveLaunchDataRootCandidate());
    if (currentRoot.isEmpty()) {
        return;
    }

    const QFileInfo currentInfo(QDir::toNativeSeparators(currentRoot));
    if (!currentInfo.exists() || !currentInfo.isDir()) {
        return;
    }

    const QString normalizedTarget = normalizedFolderPath(pendingTarget);
    if (normalizedTarget.isEmpty()) {
        return;
    }

    if (currentRoot.compare(normalizedTarget, Qt::CaseInsensitive) == 0) {
        clearPendingDataRootRelocationPath();
        return;
    }

    if (isSameOrNestedFolderPath(currentRoot, normalizedTarget)) {
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
    if (!writeConfiguredDataRootOverridePath(normalizedTarget)) {
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
    clearPendingDataRootRelocationPath();
    if (migrationWindowVisible) {
        closeDataMigrationWindow(migrationEngine);
    }
}

QString resolveLaunchDataRoot()
{
    return resolveLaunchDataRootCandidate();
}

QString resolveLaunchLogPath()
{
    const QString runtimeDirPath = QDir(resolveLaunchDataRoot()).filePath(".runtime");
    QDir().mkpath(runtimeDirPath);
    return QDir(runtimeDirPath).filePath("startup-log.txt");
}

void resetLaunchLog(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return;
    }
    file.close();
}

QString formatLaunchLogLine(QElapsedTimer &timer, const QString &message)
{
    return QStringLiteral("[launch][%1ms] %2")
        .arg(timer.elapsed())
        .arg(message);
}

void appendLaunchLog(const QString &path, QElapsedTimer &timer, const QString &message)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return;
    }

    const QString line = formatLaunchLogLine(timer, message);
    file.write(line.toUtf8());
    file.write("\n");
    file.close();
}

QString singleInstanceServerName()
{
    QString seed = QFileInfo(QCoreApplication::applicationFilePath()).canonicalFilePath();
    if (seed.isEmpty()) {
        seed = QCoreApplication::applicationFilePath();
    }
    const QByteArray hash = QCryptographicHash::hash(seed.toUtf8(), QCryptographicHash::Sha1).toHex();
    return QStringLiteral("ComicPile.SingleInstance.%1").arg(QString::fromLatin1(hash));
}

bool activateRootWindow(QQmlApplicationEngine &engine)
{
    const QObjectList roots = engine.rootObjects();
    for (QObject *root : roots) {
        auto *window = qobject_cast<QWindow *>(root);
        if (!window) {
            continue;
        }

        if (window->visibility() == QWindow::Minimized) {
            window->showNormal();
        } else if (!window->isVisible()) {
            window->show();
        }
        window->raise();
        window->requestActivate();
        return true;
    }

    return false;
}

}

int main(int argc, char *argv[])
{
    QElapsedTimer launchTimer;
    launchTimer.start();
    qputenv("COMIC_PILE_LAUNCH_STARTED_AT_MS", QByteArray::number(QDateTime::currentMSecsSinceEpoch()));
    QString launchLogPath;
    QStringList deferredLaunchLines;
    auto deferLaunchLog = [&](const QString &message) {
        deferredLaunchLines.push_back(formatLaunchLogLine(launchTimer, message));
    };
    auto flushDeferredLaunchLog = [&]() {
        resetLaunchLog(launchLogPath);

        QFile file(launchLogPath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            return;
        }

        for (const QString &line : deferredLaunchLines) {
            file.write(line.toUtf8());
            file.write("\n");
        }
        file.close();
        deferredLaunchLines.clear();
    };
    deferLaunchLog(QStringLiteral("main_enter"));

    // Keep fast startup by default; allow disabling QML disk cache only for explicit UI debugging.
    const bool disableQmlDiskCache =
        qEnvironmentVariableIntValue("COMIC_PILE_DISABLE_QML_DISK_CACHE") == 1;
    if (disableQmlDiskCache) {
        qputenv("QML_DISABLE_DISK_CACHE", "1");
    }

    QApplication app(argc, argv);
    deferLaunchLog(QStringLiteral("qapplication_created"));

#ifdef Q_OS_WIN
    QQuickWindow::setTextRenderType(QQuickWindow::NativeTextRendering);
    QFont appFont = app.font();
    appFont.setHintingPreference(QFont::PreferFullHinting);
    app.setFont(appFont);
#endif

    SingleInstanceGuard instanceGuard(singleInstanceServerName(), &app);
    if (instanceGuard.notifyExistingInstance()) {
        return 0;
    }
    if (!instanceGuard.startServer()) {
        launchLogPath = resolveLaunchLogPath();
        flushDeferredLaunchLog();
        appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("single_instance_server_failed"));
        return -2;
    }
    processPendingDataRootRelocation();
    launchLogPath = resolveLaunchLogPath();
    flushDeferredLaunchLog();
    appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("single_instance_ready"));

    QQmlApplicationEngine engine;
    appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("engine_created"));

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [&](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            appendLaunchLog(
                launchLogPath,
                launchTimer,
                QStringLiteral("qml_warning %1").arg(warning.toString()));
        }
    });

    LaunchState launchState;

    ComicsListModel libraryModel;
    appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("library_model_created"));
    bool pendingActivation = false;
    engine.rootContext()->setContextProperty("libraryModel", &libraryModel);
    engine.rootContext()->setContextProperty(
        "appBuildIteration",
        QString::fromLatin1(ComicPileBuildIteration::kText));
    engine.rootContext()->setContextProperty("appLaunchStartedAtMs", QDateTime::currentMSecsSinceEpoch() - launchTimer.elapsed());
    engine.rootContext()->setContextProperty("appLaunchState", &launchState);
    appendLaunchLog(
        launchLogPath,
        launchTimer,
        QStringLiteral("build_iteration=%1").arg(QString::fromLatin1(ComicPileBuildIteration::kText)));

    bool rootWindowVisibleLogged = false;
    auto markRootWindowVisible = [&]() {
        if (rootWindowVisibleLogged) {
            return;
        }
        rootWindowVisibleLogged = true;
        launchState.setRootWindowVisible(true);
        appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("root_window_visible"));
    };

    QObject::connect(&instanceGuard, &SingleInstanceGuard::activationRequested, &app, [&]() {
        if (!activateRootWindow(engine)) {
            pendingActivation = true;
        }
    });

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [&]() {
            appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("object_creation_failed"));
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [&](QObject *object, const QUrl &) {
        if (!object) {
            return;
        }

        appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("main_qml_object_created"));
        launchState.setRootWindowObjectCreated(true);

        if (auto *window = qobject_cast<QWindow *>(object)) {
#ifdef Q_OS_WIN
            installRoundedWindowRegion(window);
#endif
            QObject::connect(window, &QWindow::visibleChanged, &app, [&, window]() {
                if (window->isVisible()) {
                    markRootWindowVisible();
                }
            });

            if (window->isVisible()) {
                markRootWindowVisible();
            }
        }

        if (auto *window = qobject_cast<QWindow *>(object); window && window->isVisible()) {
            markRootWindowVisible();
        }

        if (!pendingActivation) {
            return;
        }
        pendingActivation = false;
        activateRootWindow(engine);
    });

    appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("load_main_qml_begin"));
    engine.loadFromModule("ComicPile", "Main");
    appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("load_main_qml_end"));
    appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("app_exec_begin"));

    return app.exec();
}

#include "main.moc"
