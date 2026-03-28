#pragma once

#include <QString>

namespace ComicDataRootRelocationOps {

QString validateScheduledTarget(const QString &currentDataRoot, const QString &targetPath);
bool ensureEmptyTarget(const QString &targetRoot, QString &errorText);

} // namespace ComicDataRootRelocationOps
