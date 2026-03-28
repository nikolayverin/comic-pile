#pragma once

#include <QSet>
#include <QString>
#include <QStringList>

namespace ComicArchiveSupport {

QString normalizeArchiveExtension(const QString &pathOrExtension);

QString sevenZipMissingMessage();
QString djvuMissingMessage();

QString resolve7ZipExecutableFromHint(const QString &hintPath);
QString resolve7ZipExecutable();
QString resolveDjVuExecutableFromHint(const QString &hintPath);
QString resolveDjVuExecutable();

const QSet<QString> &nativeImportArchiveExtensions();
const QSet<QString> &documentImportExtensions();
const QSet<QString> &fallbackSevenZipArchiveExtensions();
const QSet<QString> &declaredImportArchiveExtensions();
QSet<QString> resolvedSevenZipArchiveExtensions();

bool isPdfExtension(const QString &extension);
bool isDjvuExtension(const QString &extension);
bool isDeclaredImportArchiveExtensionSupported(const QString &extension);
bool isDeclaredSevenZipExtension(const QString &extension);
bool isDeclaredSupportedArchivePath(const QString &path);

QStringList sortedDeclaredImportArchiveExtensions();
QString formatDeclaredSupportedArchiveList();
QString buildDeclaredImportArchiveDialogFilter();

} // namespace ComicArchiveSupport
