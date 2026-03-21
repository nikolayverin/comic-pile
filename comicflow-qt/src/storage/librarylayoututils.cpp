#include "storage/librarylayoututils.h"

#include "storage/deletestagingops.h"

#include <algorithm>

#include <QFileInfo>
#include <QRegularExpression>

namespace {

QString sanitizeSeriesFolderName(const QString &seriesName)
{
    QString name = seriesName.normalized(QString::NormalizationForm_KC).trimmed();
    if (name.isEmpty()) {
        name = QStringLiteral("Unknown Series");
    }

    name.replace(QRegularExpression(QStringLiteral("[<>:\"/\\\\|?*]")), QStringLiteral(" "));
    name.replace(QRegularExpression(QStringLiteral("[\\x00-\\x1F]")), QStringLiteral(" "));
    name.replace(QRegularExpression(QStringLiteral("\\s+")), QStringLiteral(" "));
    name = name.trimmed();
    while (name.endsWith(QLatin1Char('.')) || name.endsWith(QLatin1Char(' '))) {
        name.chop(1);
    }

    if (name.isEmpty()) {
        name = QStringLiteral("Unknown Series");
    }

    static const QSet<QString> reservedNames = {
        QStringLiteral("con"),
        QStringLiteral("prn"),
        QStringLiteral("aux"),
        QStringLiteral("nul"),
        QStringLiteral("com1"),
        QStringLiteral("com2"),
        QStringLiteral("com3"),
        QStringLiteral("com4"),
        QStringLiteral("com5"),
        QStringLiteral("com6"),
        QStringLiteral("com7"),
        QStringLiteral("com8"),
        QStringLiteral("com9"),
        QStringLiteral("lpt1"),
        QStringLiteral("lpt2"),
        QStringLiteral("lpt3"),
        QStringLiteral("lpt4"),
        QStringLiteral("lpt5"),
        QStringLiteral("lpt6"),
        QStringLiteral("lpt7"),
        QStringLiteral("lpt8"),
        QStringLiteral("lpt9")
    };
    if (reservedNames.contains(name.toLower())) {
        name.prepend(QStringLiteral("_"));
    }

    constexpr int kMaxFolderLen = 96;
    if (name.size() > kMaxFolderLen) {
        name = name.left(kMaxFolderLen).trimmed();
        while (name.endsWith(QLatin1Char('.')) || name.endsWith(QLatin1Char(' '))) {
            name.chop(1);
        }
        if (name.isEmpty()) {
            name = QStringLiteral("Series");
        }
    }

    return name;
}

QString folderKey(const QString &folderName)
{
    return QDir::cleanPath(folderName).toLower();
}

bool isPathInsideDirectory(const QString &candidatePath, const QString &directoryPath)
{
    const QString base = ComicLibraryLayout::normalizedPathForCompare(directoryPath);
    const QString candidate = ComicLibraryLayout::normalizedPathForCompare(candidatePath);
    if (base.isEmpty() || candidate.isEmpty()) return false;
    if (candidate == base) return true;
    return candidate.startsWith(base + QStringLiteral("/"));
}

} // namespace

namespace ComicLibraryLayout {

QString makeUniqueFilename(const QDir &dir, const QString &filename)
{
    QString candidate = filename;
    const QFileInfo info(filename);
    const QString baseName = info.completeBaseName();
    const QString suffix = info.suffix();

    int index = 2;
    while (QFileInfo(dir.filePath(candidate)).exists()) {
        if (suffix.isEmpty()) {
            candidate = QStringLiteral("%1 (%2)").arg(baseName).arg(index);
        } else {
            candidate = QStringLiteral("%1 (%2).%3").arg(baseName).arg(index).arg(suffix);
        }
        index += 1;
    }

    return candidate;
}

QString normalizedPathForCompare(const QString &path)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(QFileInfo(path).absoluteFilePath())).toLower();
}

QString relativeDirUnderRoot(const QString &rootPath, const QString &filePath)
{
    const QDir root(rootPath);
    const QFileInfo info(filePath);
    if (!info.exists()) return {};

    const QString absoluteDir = info.absolutePath();
    if (!isPathInsideDirectory(absoluteDir, root.absolutePath())) return {};

    const QString relative = root.relativeFilePath(absoluteDir).trimmed();
    if (relative == QStringLiteral(".") || relative.isEmpty()) return {};
    return QDir::cleanPath(relative);
}

void registerSeriesFolderAssignment(SeriesFolderState &state, const QString &seriesKey, const QString &folderName)
{
    const QString normalizedSeriesKey = seriesKey.trimmed().isEmpty()
        ? QStringLiteral("unknown-series")
        : seriesKey.trimmed();
    const QString cleanedFolder = QDir::cleanPath(folderName.trimmed());
    if (cleanedFolder.isEmpty()) return;

    const QString key = folderKey(cleanedFolder);
    state.displayFolderByFolderKey.insert(key, cleanedFolder);
    state.seriesKeysByFolderKey[key].insert(normalizedSeriesKey);
    if (!state.folderBySeriesKey.contains(normalizedSeriesKey)) {
        state.folderBySeriesKey.insert(normalizedSeriesKey, cleanedFolder);
    }
}

QString assignSeriesFolderName(
    SeriesFolderState &state,
    const QString &seriesKey,
    const QString &seriesName
)
{
    const QString normalizedSeriesKey = seriesKey.trimmed().isEmpty()
        ? QStringLiteral("unknown-series")
        : seriesKey.trimmed();
    const auto existing = state.folderBySeriesKey.constFind(normalizedSeriesKey);
    if (existing != state.folderBySeriesKey.constEnd()) {
        return existing.value();
    }

    const QString baseFolder = sanitizeSeriesFolderName(seriesName);
    QString candidate = baseFolder;
    int suffix = 2;
    while (true) {
        const QString candidateKey = folderKey(candidate);
        const QSet<QString> usedBy = state.seriesKeysByFolderKey.value(candidateKey);
        const bool available = usedBy.isEmpty() || (usedBy.size() == 1 && usedBy.contains(normalizedSeriesKey));
        if (available) {
            registerSeriesFolderAssignment(state, normalizedSeriesKey, candidate);
            return state.folderBySeriesKey.value(normalizedSeriesKey);
        }
        candidate = QStringLiteral("%1 (%2)").arg(baseFolder).arg(suffix);
        suffix += 1;
    }
}

bool moveFileWithFallback(const QString &sourcePath, const QString &targetPath, QString &errorText)
{
    return ComicDeleteOps::moveFileWithFallback(sourcePath, targetPath, errorText);
}

} // namespace ComicLibraryLayout
