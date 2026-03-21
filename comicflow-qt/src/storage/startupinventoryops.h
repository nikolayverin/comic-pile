#pragma once

#include <functional>

#include <QString>
#include <QVariantMap>

class QObject;

namespace ComicStartupInventoryOps {

QVariantMap checkDatabaseHealth(const QString &dbPath);
bool isLibraryStorageMigrationPending(const QString &dataRoot);
QVariantMap currentStartupInventorySignature(const QString &dataRoot, const QString &dbPath);

int requestDatabaseHealthCheckAsync(
    QObject *context,
    const QString &dbPath,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished
);

int requestStartupInventorySignatureAsync(
    QObject *context,
    const QString &dataRoot,
    const QString &dbPath,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished
);

int requestLibraryStorageMigrationAsync(
    QObject *context,
    const QString &dataRoot,
    const QString &dbPath,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished
);

} // namespace ComicStartupInventoryOps
