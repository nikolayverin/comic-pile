#pragma once

#include <QString>
#include <QVariantMap>

namespace ComicStartupRuntime {

void resetTextLogFile(const QString &path);
void appendNormalizedTextLogLine(const QString &path, const QString &line);

QString startupRuntimeDirPath(const QString &dataRoot);
QString startupLogPath(const QString &dataRoot);
QString startupDebugLogPath(const QString &dataRoot);
QString startupPreviewPath(const QString &dataRoot);
QString startupPreviewMetaPath(const QString &dataRoot);

QString readStartupSnapshot(const QString &dataRoot);
bool writeStartupSnapshot(const QString &dataRoot, const QString &payload);
QString readStartupPreviewMeta(const QString &dataRoot);
bool writeStartupPreviewMeta(const QString &dataRoot, const QString &payload);

void appendLaunchTimelineEventForDataRoot(const QString &dataRoot, const QString &message);

QVariantMap runDatabaseHealthCheck(const QString &dbPath);
QVariantMap buildStartupInventorySignature(const QString &dataRoot, const QString &dbPath);

} // namespace ComicStartupRuntime
