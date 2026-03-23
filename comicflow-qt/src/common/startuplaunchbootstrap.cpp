#include "common/startuplaunchbootstrap.h"

#include "storage/datarootrelocationbootstrap.h"
#include "storage/startupruntimeutils.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QWindow>

namespace ComicStartupLaunch {

LaunchState::LaunchState(QObject *parent)
    : QObject(parent)
{
}

bool LaunchState::rootWindowObjectCreated() const
{
    return m_rootWindowObjectCreated;
}

bool LaunchState::rootWindowShowCalled() const
{
    return m_rootWindowShowCalled;
}

bool LaunchState::rootWindowVisible() const
{
    return m_rootWindowVisible;
}

void LaunchState::setRootWindowObjectCreated(bool value)
{
    if (m_rootWindowObjectCreated == value) {
        return;
    }
    m_rootWindowObjectCreated = value;
    emit rootWindowObjectCreatedChanged();
}

void LaunchState::setRootWindowShowCalled(bool value)
{
    if (m_rootWindowShowCalled == value) {
        return;
    }
    m_rootWindowShowCalled = value;
    emit rootWindowShowCalledChanged();
}

void LaunchState::setRootWindowVisible(bool value)
{
    if (m_rootWindowVisible == value) {
        return;
    }
    m_rootWindowVisible = value;
    emit rootWindowVisibleChanged();
}

QString resolveLaunchLogPath()
{
    const QString dataRoot = ComicDataRootRelocationBootstrap::resolveLaunchDataRoot();
    return ComicStartupRuntime::startupLaunchLogPathForDataRoot(dataRoot);
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

} // namespace ComicStartupLaunch
