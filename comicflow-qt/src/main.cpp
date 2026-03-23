#include "storage/comicslistmodel.h"
#include "storage/datarootrelocationbootstrap.h"
#include "common/singleinstanceguard.h"
#include "comicpile_build_iteration.h"

#include <QApplication>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFont>
#include <QCryptographicHash>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickWindow>
#include <QWindow>
#include <QtMath>
#include <QtGlobal>

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

QString resolveLaunchLogPath()
{
    const QString runtimeDirPath = QDir(ComicDataRootRelocationBootstrap::resolveLaunchDataRoot()).filePath(".runtime");
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
    ComicDataRootRelocationBootstrap::processPendingDataRootRelocation();
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
