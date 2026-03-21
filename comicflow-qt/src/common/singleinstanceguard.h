#pragma once

#include <QObject>
#include <QString>

class QLocalServer;

class SingleInstanceGuard : public QObject
{
    Q_OBJECT

public:
    explicit SingleInstanceGuard(const QString &serverName, QObject *parent = nullptr);

    bool notifyExistingInstance(int timeoutMs = 400);
    bool startServer();

signals:
    void activationRequested();

private slots:
    void handleNewConnection();

private:
    QString m_serverName;
    QLocalServer *m_server = nullptr;
};
