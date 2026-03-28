#include "storage/archivesupportutils.h"

#include "storage/archiveprocessutils.h"
#include "storage/storedpathutils.h"

#include <algorithm>

#include <QCollator>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>

namespace {

int compareNaturalText(const QString &left, const QString &right)
{
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    return collator.compare(left, right);
}

QString resolveExecutableFromHint(const QString &hintPath, const QStringList &executableNames)
{
    const QString existingFilePath = ComicStoragePaths::absoluteExistingFilePath(hintPath);
    if (!existingFilePath.isEmpty()) {
        return existingFilePath;
    }

    const QString existingDirPath = ComicStoragePaths::absoluteExistingDirPath(hintPath);
    if (existingDirPath.isEmpty()) {
        return {};
    }

    for (const QString &name : executableNames) {
        const QString nestedPath = ComicStoragePaths::absoluteExistingFilePath(
            QDir(existingDirPath).filePath(name)
        );
        if (!nestedPath.isEmpty()) {
            return nestedPath;
        }
    }

    return {};
}

QString resolveExecutable(
    const QStringList &envCandidates,
    const QStringList &bundledCandidates,
    const QStringList &programCandidates,
    const QStringList &absoluteCandidates,
    const QStringList &directoryExecutableNames
)
{
    for (const QString &envKey : envCandidates) {
        const QString resolved = resolveExecutableFromHint(
            qEnvironmentVariable(envKey.toUtf8().constData()),
            directoryExecutableNames
        );
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    for (const QString &candidate : bundledCandidates) {
        const QString resolved = resolveExecutableFromHint(candidate, directoryExecutableNames);
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    for (const QString &candidate : programCandidates) {
        const QString found = QStandardPaths::findExecutable(candidate);
        if (!found.isEmpty()) {
            return QDir::toNativeSeparators(found);
        }
    }

    for (const QString &candidate : absoluteCandidates) {
        const QString resolved = ComicStoragePaths::absoluteExistingFilePath(candidate);
        if (!resolved.isEmpty()) {
            return resolved;
        }
    }

    return {};
}

QSet<QString> parseSevenZipExtensionsFromIndexOutput(const QString &output)
{
    QSet<QString> extensions;
    if (output.trimmed().isEmpty()) return extensions;

    bool inFormatsSection = false;
    const QStringList lines = output.split(QLatin1Char('\n'));
    const QRegularExpression rowPattern(
        QStringLiteral("^\\s*[0-9]{0,3}\\s*[A-Z\\.]{0,8}\\s*[A-Z\\.]{0,8}\\s+[^\\s]+\\s+(.+?)\\s*$"),
        QRegularExpression::CaseInsensitiveOption
    );
    const QRegularExpression tokenCleaner(QStringLiteral("[^a-z0-9+\\-.]"));
    const QRegularExpression validTokenPattern(QStringLiteral("^[a-z0-9][a-z0-9+\\-]{0,31}$"));

    for (const QString &rawLine : lines) {
        const QString trimmed = rawLine.trimmed();
        if (trimmed.isEmpty()) continue;

        if (!inFormatsSection) {
            if (trimmed.compare(QStringLiteral("Formats:"), Qt::CaseInsensitive) == 0) {
                inFormatsSection = true;
            }
            continue;
        }

        if (trimmed.endsWith(QLatin1Char(':'))
            && trimmed.compare(QStringLiteral("Formats:"), Qt::CaseInsensitive) != 0) {
            break;
        }

        const QRegularExpressionMatch rowMatch = rowPattern.match(rawLine);
        if (!rowMatch.hasMatch()) continue;

        const QString extChunk = rowMatch.captured(1);
        const QStringList rawTokens = extChunk.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
        for (const QString &rawToken : rawTokens) {
            QString token = rawToken.trimmed().toLower();
            if (token.startsWith(QLatin1Char('.'))) {
                token = token.mid(1);
            }
            token.remove(tokenCleaner);
            if (!validTokenPattern.match(token).hasMatch()) continue;
            extensions.insert(token);
        }
    }

    return extensions;
}

const QStringList &sevenZipExecutableNames()
{
    static const QStringList names = {
        QStringLiteral("7z.exe"),
        QStringLiteral("7z"),
        QStringLiteral("7za.exe"),
        QStringLiteral("7za")
    };
    return names;
}

const QStringList &djvuExecutableNames()
{
    static const QStringList names = {
        QStringLiteral("ddjvu.exe"),
        QStringLiteral("ddjvu")
    };
    return names;
}

QStringList sevenZipBundledCandidates()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    return {
        QDir(appDir).filePath(QStringLiteral("7z.exe")),
        QDir(appDir).filePath(QStringLiteral("7za.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/7zip/7z.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/7zip/7za.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/7zip/7z.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/7zip/7za.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/7zip/7z.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/7zip/7za.exe")),
        QDir(currentDir).filePath(QStringLiteral("7z.exe")),
        QDir(currentDir).filePath(QStringLiteral("7za.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/7zip/7z.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/7zip/7za.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/7zip/7z.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/7zip/7za.exe"))
    };
}

QStringList djvuBundledCandidates()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    return {
        QDir(appDir).filePath(QStringLiteral("ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/djvulibre/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("tools/djvulibre/runtime/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/djvulibre/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../tools/djvulibre/runtime/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/djvulibre/ddjvu.exe")),
        QDir(appDir).filePath(QStringLiteral("../../tools/djvulibre/runtime/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/djvulibre/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("tools/djvulibre/runtime/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/djvulibre/ddjvu.exe")),
        QDir(currentDir).filePath(QStringLiteral("../tools/djvulibre/runtime/ddjvu.exe"))
    };
}

} // namespace

namespace ComicArchiveSupport {

QString normalizeArchiveExtension(const QString &pathOrExtension)
{
    QString value = pathOrExtension.trimmed().toLower();
    if (value.isEmpty()) return {};
    if (value.contains(QLatin1Char('/')) || value.contains(QLatin1Char('\\'))) {
        value = QFileInfo(value).suffix().toLower();
    }
    if (value.startsWith(QLatin1Char('.'))) {
        value = value.mid(1);
    }
    return value.trimmed();
}

QString sevenZipMissingMessage()
{
    return QStringLiteral("Archive support component (7z) is missing. Reinstall/repair Comic Pile or set a custom 7z path.");
}

QString djvuMissingMessage()
{
    return QStringLiteral("DJVU import component (ddjvu) is missing. Reinstall/repair Comic Pile or set a custom DjVuLibre path.");
}

QString resolve7ZipExecutableFromHint(const QString &hintPath)
{
    return resolveExecutableFromHint(hintPath, sevenZipExecutableNames());
}

QString resolve7ZipExecutable()
{
    return resolveExecutable(
        { QStringLiteral("COMIC_PILE_7ZIP_PATH"), QStringLiteral("SEVENZIP_PATH") },
        sevenZipBundledCandidates(),
        sevenZipExecutableNames(),
        {
            QStringLiteral("C:/Program Files/7-Zip/7z.exe"),
            QStringLiteral("C:/Program Files (x86)/7-Zip/7z.exe")
        },
        sevenZipExecutableNames()
    );
}

QString resolveDjVuExecutableFromHint(const QString &hintPath)
{
    return resolveExecutableFromHint(hintPath, djvuExecutableNames());
}

QString resolveDjVuExecutable()
{
    return resolveExecutable(
        { QStringLiteral("COMIC_PILE_DJVU_PATH"), QStringLiteral("DJVU_PATH") },
        djvuBundledCandidates(),
        djvuExecutableNames(),
        {},
        djvuExecutableNames()
    );
}

bool runSevenZipProcess(
    const QStringList &arguments,
    QByteArray &stdOut,
    QByteArray &stdErr,
    QString &errorText,
    int timeoutMs,
    bool pumpUiEvents,
    const QString &operationLabel,
    int *exitCodeOut
)
{
    const QString sevenZip = resolve7ZipExecutable();
    if (sevenZip.isEmpty()) {
        if (exitCodeOut) {
            *exitCodeOut = 0;
        }
        errorText = sevenZipMissingMessage();
        stdOut.clear();
        stdErr.clear();
        return false;
    }

    const QString label = operationLabel.trimmed().isEmpty()
        ? QStringLiteral("7-Zip operation")
        : operationLabel.trimmed();
    return ComicArchiveProcess::runExternalProcess(
        sevenZip,
        arguments,
        stdOut,
        stdErr,
        errorText,
        timeoutMs,
        pumpUiEvents,
        label,
        exitCodeOut
    );
}

bool runDjVuProcess(
    const QStringList &arguments,
    QByteArray &stdOut,
    QByteArray &stdErr,
    QString &errorText,
    int timeoutMs,
    bool pumpUiEvents,
    const QString &operationLabel,
    int *exitCodeOut
)
{
    const QString ddjvu = resolveDjVuExecutable();
    if (ddjvu.isEmpty()) {
        if (exitCodeOut) {
            *exitCodeOut = 0;
        }
        errorText = djvuMissingMessage();
        stdOut.clear();
        stdErr.clear();
        return false;
    }

    const QString label = operationLabel.trimmed().isEmpty()
        ? QStringLiteral("DJVU operation")
        : operationLabel.trimmed();
    return ComicArchiveProcess::runExternalProcess(
        ddjvu,
        arguments,
        stdOut,
        stdErr,
        errorText,
        timeoutMs,
        pumpUiEvents,
        label,
        exitCodeOut
    );
}

const QSet<QString> &nativeImportArchiveExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("cbz"),
        QStringLiteral("zip")
    };
    return extensions;
}

const QSet<QString> &documentImportArchiveExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("pdf"),
        QStringLiteral("djvu"),
        QStringLiteral("djv")
    };
    return extensions;
}

const QSet<QString> &documentImportExtensions()
{
    return documentImportArchiveExtensions();
}

const QSet<QString> &fallbackSevenZipArchiveExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("7z"),
        QStringLiteral("apk"),
        QStringLiteral("ar"),
        QStringLiteral("arj"),
        QStringLiteral("bz2"),
        QStringLiteral("cab"),
        QStringLiteral("cb7"),
        QStringLiteral("cbr"),
        QStringLiteral("chm"),
        QStringLiteral("cpio"),
        QStringLiteral("deb"),
        QStringLiteral("dmg"),
        QStringLiteral("ear"),
        QStringLiteral("epub"),
        QStringLiteral("gz"),
        QStringLiteral("iso"),
        QStringLiteral("jar"),
        QStringLiteral("lha"),
        QStringLiteral("lzh"),
        QStringLiteral("lz"),
        QStringLiteral("lzma"),
        QStringLiteral("msi"),
        QStringLiteral("nupkg"),
        QStringLiteral("pkg"),
        QStringLiteral("qcow"),
        QStringLiteral("qcow2"),
        QStringLiteral("rar"),
        QStringLiteral("rpm"),
        QStringLiteral("squashfs"),
        QStringLiteral("tar"),
        QStringLiteral("taz"),
        QStringLiteral("tbz"),
        QStringLiteral("tbz2"),
        QStringLiteral("tgz"),
        QStringLiteral("txz"),
        QStringLiteral("udf"),
        QStringLiteral("vdi"),
        QStringLiteral("vhd"),
        QStringLiteral("vhdx"),
        QStringLiteral("vmdk"),
        QStringLiteral("war"),
        QStringLiteral("wim"),
        QStringLiteral("xar"),
        QStringLiteral("xz"),
        QStringLiteral("z"),
        QStringLiteral("zipx"),
        QStringLiteral("zst"),
        QStringLiteral("tzst")
    };
    return extensions;
}

const QSet<QString> &declaredImportArchiveExtensions()
{
    static const QSet<QString> extensions = {
        QStringLiteral("cbz"),
        QStringLiteral("zip"),
        QStringLiteral("pdf"),
        QStringLiteral("djvu"),
        QStringLiteral("djv"),
        QStringLiteral("cbr"),
        QStringLiteral("rar"),
        QStringLiteral("cb7"),
        QStringLiteral("7z"),
        QStringLiteral("cbt"),
        QStringLiteral("tar")
    };
    return extensions;
}

QSet<QString> resolvedSevenZipArchiveExtensions()
{
    static QString cachedExecutable;
    static QSet<QString> cachedExtensions = fallbackSevenZipArchiveExtensions();

    const QString executable = resolve7ZipExecutable();
    if (!cachedExecutable.isEmpty()
        && executable.compare(cachedExecutable, Qt::CaseInsensitive) == 0) {
        return cachedExtensions;
    }

    cachedExecutable = executable;
    cachedExtensions = fallbackSevenZipArchiveExtensions();

    if (executable.isEmpty()) {
        return cachedExtensions;
    }

    QByteArray stdOutBytes;
    QByteArray stdErrBytes;
    QString errorText;
    if (!runSevenZipProcess(
            { QStringLiteral("i") },
            stdOutBytes,
            stdErrBytes,
            errorText,
            15000,
            false,
            QStringLiteral("7-Zip support scan"))) {
        return cachedExtensions;
    }

    const QString stdOut = QString::fromUtf8(stdOutBytes);
    const QSet<QString> parsed = parseSevenZipExtensionsFromIndexOutput(stdOut);
    if (!parsed.isEmpty()) {
        cachedExtensions.unite(parsed);
    }
    return cachedExtensions;
}

bool isPdfExtension(const QString &extension)
{
    return normalizeArchiveExtension(extension) == QStringLiteral("pdf");
}

bool isDjvuExtension(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    return normalized == QStringLiteral("djvu") || normalized == QStringLiteral("djv");
}

bool isDeclaredImportArchiveExtensionSupported(const QString &extension)
{
    return declaredImportArchiveExtensions().contains(normalizeArchiveExtension(extension));
}

bool isDeclaredSevenZipExtension(const QString &extension)
{
    const QString normalized = normalizeArchiveExtension(extension);
    if (normalized.isEmpty()) return false;
    if (nativeImportArchiveExtensions().contains(normalized)) {
        return false;
    }
    if (documentImportExtensions().contains(normalized)) {
        return false;
    }
    return declaredImportArchiveExtensions().contains(normalized);
}

bool isDeclaredSupportedArchivePath(const QString &path)
{
    return isDeclaredImportArchiveExtensionSupported(normalizeArchiveExtension(path));
}

QStringList sortedDeclaredImportArchiveExtensions()
{
    QStringList out = declaredImportArchiveExtensions().values();
    std::sort(out.begin(), out.end(), [](const QString &left, const QString &right) {
        return compareNaturalText(left, right) < 0;
    });
    return out;
}

QString formatDeclaredSupportedArchiveList()
{
    QStringList tokens;
    const QStringList extensions = sortedDeclaredImportArchiveExtensions();
    tokens.reserve(extensions.size());
    for (const QString &ext : extensions) {
        tokens.push_back(QStringLiteral(".%1").arg(ext));
    }
    return tokens.join(QStringLiteral(", "));
}

QString buildDeclaredImportArchiveDialogFilter()
{
    QStringList wildcards;
    const QStringList extensions = sortedDeclaredImportArchiveExtensions();
    wildcards.reserve(extensions.size());
    for (const QString &ext : extensions) {
        wildcards.push_back(QStringLiteral("*.%1").arg(ext));
    }
    return QStringLiteral("Comic files (%1);;All files (*)").arg(wildcards.join(QStringLiteral(" ")));
}

} // namespace ComicArchiveSupport
