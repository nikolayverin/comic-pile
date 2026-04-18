#include "common/singleinstanceguard.h"
#include "common/startuplaunchbootstrap.h"
#include "comicpile_build_iteration.h"
#include "storage/comicslistmodel.h"
#include "storage/datarootrelocationbootstrap.h"
#include "updates/bundledreleasenotes.h"
#include "updates/releasecheckservice.h"

#include <QApplication>
#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QFont>
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

#ifndef COMICPILE_APP_VERSION
#define COMICPILE_APP_VERSION "0.0.0"
#endif

#ifndef COMICPILE_FAST_DEV_BUILD_ENABLED
#define COMICPILE_FAST_DEV_BUILD_ENABLED 0
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

QString effectiveBuildIterationText()
{
#if COMICPILE_FAST_DEV_BUILD_ENABLED
    const QString appDirPath = QCoreApplication::applicationDirPath();
    const QString successfulBuildStampPath =
        appDirPath + QStringLiteral("/generated/build_meta/successful_build_iteration.txt");
    QFile successfulBuildStamp(successfulBuildStampPath);
    if (successfulBuildStamp.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString successfulBuildText = QString::fromUtf8(successfulBuildStamp.readAll()).trimmed();
        if (!successfulBuildText.isEmpty()) {
            return successfulBuildText;
        }
    }
#endif
    return QString::fromLatin1(ComicPileBuildIteration::kText);
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
        deferredLaunchLines.push_back(ComicStartupLaunch::formatLaunchLogLine(launchTimer, message));
    };
    auto flushDeferredLaunchLog = [&]() {
        ComicStartupLaunch::resetLaunchLog(launchLogPath);

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
    app.setOrganizationName(QStringLiteral("ComicPile"));
    app.setApplicationName(QStringLiteral("Comic Pile"));
    app.setApplicationVersion(QStringLiteral(COMICPILE_APP_VERSION));
    deferLaunchLog(QStringLiteral("qapplication_created"));

#ifdef Q_OS_WIN
    QQuickWindow::setTextRenderType(QQuickWindow::NativeTextRendering);
    QFont appFont = app.font();
    appFont.setHintingPreference(QFont::PreferFullHinting);
    app.setFont(appFont);
#endif

    SingleInstanceGuard instanceGuard(ComicStartupLaunch::singleInstanceServerName(), &app);
    if (instanceGuard.notifyExistingInstance()) {
        return 0;
    }
    if (!instanceGuard.startServer()) {
        launchLogPath = ComicStartupLaunch::resolveLaunchLogPath();
        flushDeferredLaunchLog();
        ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("single_instance_server_failed"));
        return -2;
    }
    ComicDataRootRelocationBootstrap::processPendingDataRootRelocation();
    launchLogPath = ComicStartupLaunch::resolveLaunchLogPath();
    flushDeferredLaunchLog();
    ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("single_instance_ready"));

    QQmlApplicationEngine engine;
    ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("engine_created"));

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [&](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            ComicStartupLaunch::appendLaunchLog(
                launchLogPath,
                launchTimer,
                QStringLiteral("qml_warning %1").arg(warning.toString()));
        }
    });

    ComicStartupLaunch::LaunchState launchState;

    ComicsListModel libraryModel;
    ReleaseCheckService releaseCheckService;
    ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("library_model_created"));
    bool pendingActivation = false;
    const QString effectiveBuildIteration = effectiveBuildIterationText();
    const QString bundledWhatsNewText = bundledReleaseNotesTextForVersion(QStringLiteral(COMICPILE_APP_VERSION));
    const QVariantList bundledWhatsNewEntries = bundledReleaseNotesEntries(QStringLiteral(COMICPILE_APP_VERSION));
    engine.rootContext()->setContextProperty("libraryModel", &libraryModel);
    engine.rootContext()->setContextProperty("releaseCheckService", &releaseCheckService);
    engine.rootContext()->setContextProperty(
        "appVersion",
        QString::fromLatin1(COMICPILE_APP_VERSION));
    engine.rootContext()->setContextProperty(
        "appBuildIteration",
        effectiveBuildIteration);
    engine.rootContext()->setContextProperty(
        "appBundledWhatsNewText",
        bundledWhatsNewText);
    engine.rootContext()->setContextProperty(
        "appBundledWhatsNewEntries",
        bundledWhatsNewEntries);
    engine.rootContext()->setContextProperty(
        "appIsFastDevBuild",
        QVariant::fromValue(bool(COMICPILE_FAST_DEV_BUILD_ENABLED)));
    engine.rootContext()->setContextProperty("appLaunchStartedAtMs", QDateTime::currentMSecsSinceEpoch() - launchTimer.elapsed());
    engine.rootContext()->setContextProperty("appLaunchState", &launchState);
    ComicStartupLaunch::appendLaunchLog(
        launchLogPath,
        launchTimer,
        QStringLiteral("build_iteration=%1").arg(effectiveBuildIteration));

    bool rootWindowVisibleLogged = false;
    auto markRootWindowVisible = [&]() {
        if (rootWindowVisibleLogged) {
            return;
        }
        rootWindowVisibleLogged = true;
        launchState.setRootWindowVisible(true);
        ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("root_window_visible"));
    };

    QObject::connect(&instanceGuard, &SingleInstanceGuard::activationRequested, &app, [&]() {
        if (!ComicStartupLaunch::activateRootWindow(engine)) {
            pendingActivation = true;
        }
    });

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [&]() {
            ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("object_creation_failed"));
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [&](QObject *object, const QUrl &) {
        if (!object) {
            return;
        }

        ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("main_qml_object_created"));
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
        ComicStartupLaunch::activateRootWindow(engine);
    });

    ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("load_main_qml_begin"));
    engine.loadFromModule("ComicPile", "Main");
    ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("load_main_qml_end"));
    ComicStartupLaunch::appendLaunchLog(launchLogPath, launchTimer, QStringLiteral("app_exec_begin"));

    return app.exec();
}

#include "main.moc"
