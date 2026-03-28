#include "storage/startupinventoryops.h"

#include "storage/librarystoragemigrationops.h"
#include "storage/librarystoragemigrationstate.h"
#include "storage/startupruntimeutils.h"

#include <QFutureWatcher>
#include <QObject>
#include <QtConcurrent>

namespace {

int requestVariantMapAsync(
    QObject *context,
    const std::function<QVariantMap()> &task,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished,
    int &requestSeq
)
{
    requestSeq += 1;
    const int requestId = requestSeq;

    auto *watcher = new QFutureWatcher<QVariantMap>(context);
    QObject::connect(watcher, &QFutureWatcher<QVariantMap>::finished, context, [watcher, requestId, onFinished]() {
        const QVariantMap result = watcher->result();
        onFinished(requestId, result);
        watcher->deleteLater();
    });
    watcher->setFuture(QtConcurrent::run(task));
    return requestId;
}

} // namespace

namespace ComicStartupInventoryOps {

QVariantMap checkDatabaseHealth(const QString &dbPath)
{
    return ComicStartupRuntime::runDatabaseHealthCheck(dbPath);
}

bool isLibraryStorageMigrationPending(const QString &dataRoot)
{
    return !ComicLibraryStorageMigrationState::hasCompletedLayoutMigration(dataRoot);
}

QVariantMap currentStartupInventorySignature(const QString &dataRoot, const QString &dbPath)
{
    return ComicStartupRuntime::buildStartupInventorySignature(dataRoot, dbPath);
}

int requestDatabaseHealthCheckAsync(
    QObject *context,
    const QString &dbPath,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished
)
{
    static int requestSeq = 0;
    return requestVariantMapAsync(
        context,
        [dbPath]() {
            return ComicStartupRuntime::runDatabaseHealthCheck(dbPath);
        },
        onFinished,
        requestSeq
    );
}

int requestStartupInventorySignatureAsync(
    QObject *context,
    const QString &dataRoot,
    const QString &dbPath,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished
)
{
    static int requestSeq = 0;
    return requestVariantMapAsync(
        context,
        [dataRoot, dbPath]() {
            return ComicStartupRuntime::buildStartupInventorySignature(dataRoot, dbPath);
        },
        onFinished,
        requestSeq
    );
}

int requestLibraryStorageMigrationAsync(
    QObject *context,
    const QString &dataRoot,
    const QString &dbPath,
    const std::function<void(int requestId, const QVariantMap &result)> &onFinished
)
{
    static int requestSeq = 0;
    return requestVariantMapAsync(
        context,
        [dataRoot, dbPath]() {
            return ComicLibraryStorageMigration::runLibraryStorageLayoutMigration(dataRoot, dbPath);
        },
        onFinished,
        requestSeq
    );
}

} // namespace ComicStartupInventoryOps
