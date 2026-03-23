#pragma once

#include <QObject>
#include <QString>

class QElapsedTimer;
class QQmlApplicationEngine;

namespace ComicStartupLaunch {

class LaunchState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool rootWindowObjectCreated READ rootWindowObjectCreated NOTIFY rootWindowObjectCreatedChanged)
    Q_PROPERTY(bool rootWindowShowCalled READ rootWindowShowCalled NOTIFY rootWindowShowCalledChanged)
    Q_PROPERTY(bool rootWindowVisible READ rootWindowVisible NOTIFY rootWindowVisibleChanged)

public:
    explicit LaunchState(QObject *parent = nullptr);

    bool rootWindowObjectCreated() const;
    bool rootWindowShowCalled() const;
    bool rootWindowVisible() const;

    void setRootWindowObjectCreated(bool value);
    void setRootWindowShowCalled(bool value);
    void setRootWindowVisible(bool value);

signals:
    void rootWindowObjectCreatedChanged();
    void rootWindowShowCalledChanged();
    void rootWindowVisibleChanged();

private:
    bool m_rootWindowObjectCreated = false;
    bool m_rootWindowShowCalled = false;
    bool m_rootWindowVisible = false;
};

QString resolveLaunchLogPath();
void resetLaunchLog(const QString &path);
QString formatLaunchLogLine(QElapsedTimer &timer, const QString &message);
void appendLaunchLog(const QString &path, QElapsedTimer &timer, const QString &message);
QString singleInstanceServerName();
bool activateRootWindow(QQmlApplicationEngine &engine);

} // namespace ComicStartupLaunch
