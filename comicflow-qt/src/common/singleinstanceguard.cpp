#include "common/singleinstanceguard.h"

#include <QLocalServer>
#include <QLocalSocket>

SingleInstanceGuard::SingleInstanceGuard(const QString &serverName, QObject *parent)
    : QObject(parent)
    , m_serverName(serverName.trimmed())
    , m_server(new QLocalServer(this))
{
    connect(m_server, &QLocalServer::newConnection, this, &SingleInstanceGuard::handleNewConnection);
}

bool SingleInstanceGuard::notifyExistingInstance(int timeoutMs)
{
    if (m_serverName.isEmpty()) {
        return false;
    }

    QLocalSocket socket;
    socket.connectToServer(m_serverName, QIODevice::WriteOnly);
    if (!socket.waitForConnected(timeoutMs)) {
        return false;
    }

    socket.write("activate");
    socket.flush();
    socket.waitForBytesWritten(timeoutMs);
    socket.disconnectFromServer();
    return true;
}

bool SingleInstanceGuard::startServer()
{
    if (m_serverName.isEmpty()) {
        return false;
    }

    if (m_server->isListening()) {
        return true;
    }

    if (m_server->listen(m_serverName)) {
        return true;
    }

    if (m_server->serverError() == QAbstractSocket::AddressInUseError) {
        QLocalServer::removeServer(m_serverName);
        return m_server->listen(m_serverName);
    }

    return false;
}

void SingleInstanceGuard::handleNewConnection()
{
    while (m_server->hasPendingConnections()) {
        if (QLocalSocket *socket = m_server->nextPendingConnection()) {
            connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            socket->readAll();
            socket->disconnectFromServer();
            emit activationRequested();
        }
    }
}
