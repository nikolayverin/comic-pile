#include "updates/bundledreleasenotes.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStringList>
#include <QVariantMap>
#include <QVector>
#include <algorithm>

namespace {

constexpr auto kBundledReleaseNotesDir = ":/qt/qml/ComicPile/release/WhatsNew";
constexpr auto kActiveReleaseNotesBaseName = "whats-new-patch-notes";
constexpr auto kFallbackReleaseNotesLanguage = "en";

QString normalizeReleaseNotesVersion(const QString &version)
{
    QString normalized = version.trimmed();
    normalized.remove(QRegularExpression(QStringLiteral("^[vV]+")));
    return normalized.trimmed();
}

QVector<int> parseReleaseVersionParts(const QString &version)
{
    QVector<int> parts;
    const QString normalized = normalizeReleaseNotesVersion(version);
    const QStringList tokens = normalized.split(QLatin1Char('.'), Qt::SkipEmptyParts);
    parts.reserve(tokens.size());
    for (const QString &token : tokens) {
        bool ok = false;
        const int value = token.toInt(&ok);
        parts.push_back(ok ? value : 0);
    }
    return parts;
}

int compareReleaseVersionsDescending(const QString &leftVersion, const QString &rightVersion)
{
    const QVector<int> leftParts = parseReleaseVersionParts(leftVersion);
    const QVector<int> rightParts = parseReleaseVersionParts(rightVersion);
    const int count = qMax(leftParts.size(), rightParts.size());
    for (int index = 0; index < count; index += 1) {
        const int leftValue = index < leftParts.size() ? leftParts.at(index) : 0;
        const int rightValue = index < rightParts.size() ? rightParts.at(index) : 0;
        if (leftValue == rightValue) {
            continue;
        }
        return leftValue > rightValue ? -1 : 1;
    }
    return 0;
}

QString bundledReleaseNotesResourcePathForFileName(const QString &fileName)
{
    const QString trimmedFileName = fileName.trimmed();
    if (trimmedFileName.isEmpty()) {
        return {};
    }
    return QString::fromLatin1(kBundledReleaseNotesDir) + QLatin1Char('/') + trimmedFileName;
}

QStringList supportedReleaseNotesLanguages()
{
    return {
        QStringLiteral("en"),
        QStringLiteral("es"),
        QStringLiteral("de"),
        QStringLiteral("fr"),
        QStringLiteral("ja"),
        QStringLiteral("ko"),
        QStringLiteral("zh-Hans"),
        QStringLiteral("zh-Hant")
    };
}

QString releaseNotesLanguageFromBaseName(const QString &fileBaseName)
{
    const QString baseName = fileBaseName.trimmed();
    for (const QString &language : supportedReleaseNotesLanguages()) {
        if (baseName.endsWith(QStringLiteral(".") + language, Qt::CaseInsensitive)) {
            return language;
        }
    }
    return QString::fromLatin1(kFallbackReleaseNotesLanguage);
}

QString releaseNotesCanonicalBaseName(const QString &fileBaseName)
{
    QString baseName = fileBaseName.trimmed();
    for (const QString &language : supportedReleaseNotesLanguages()) {
        const QString suffix = QStringLiteral(".") + language;
        if (baseName.endsWith(suffix, Qt::CaseInsensitive)) {
            baseName.chop(suffix.size());
            return baseName.trimmed();
        }
    }
    return baseName;
}

QString activeReleaseNotesFileNameForLanguage(const QString &language)
{
    const QString normalizedLanguage = language.trimmed().isEmpty()
        ? QString::fromLatin1(kFallbackReleaseNotesLanguage)
        : language.trimmed();
    return QString::fromLatin1(kActiveReleaseNotesBaseName)
        + QLatin1Char('.')
        + normalizedLanguage
        + QStringLiteral(".md");
}

QString readBundledReleaseNotesFile(const QString &resourcePath)
{
    if (resourcePath.isEmpty()) {
        return {};
    }

    QFile file(resourcePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    return QString::fromUtf8(file.readAll()).trimmed();
}

QString bundledReleaseNotesResourcePathForVersion(const QString &version)
{
    const QString normalizedVersion = normalizeReleaseNotesVersion(version);
    if (normalizedVersion.isEmpty()) {
        return bundledReleaseNotesResourcePathForFileName(
            activeReleaseNotesFileNameForLanguage(QString::fromLatin1(kFallbackReleaseNotesLanguage)));
    }

    const QString versionedFileName = normalizedVersion
        + QLatin1Char('.')
        + QString::fromLatin1(kFallbackReleaseNotesLanguage)
        + QStringLiteral(".md");
    const QString versionedPath = bundledReleaseNotesResourcePathForFileName(versionedFileName);
    if (QFile::exists(versionedPath)) {
        return versionedPath;
    }

    const QString legacyVersionedPath = bundledReleaseNotesResourcePathForFileName(normalizedVersion + QStringLiteral(".md"));
    if (QFile::exists(legacyVersionedPath)) {
        return legacyVersionedPath;
    }

    const QString activePath = bundledReleaseNotesResourcePathForFileName(
        activeReleaseNotesFileNameForLanguage(QString::fromLatin1(kFallbackReleaseNotesLanguage)));
    if (QFile::exists(activePath)) {
        return activePath;
    }

    return bundledReleaseNotesResourcePathForFileName(QStringLiteral("whats-new-patch-notes.md"));
}

QVariantMap buildBundledReleaseNotesEntry(
    const QString &fileName,
    const QString &currentVersion,
    const QString &notesText)
{
    const QString fileBaseName = QFileInfo(fileName).completeBaseName().trimmed();
    const QString canonicalBaseName = releaseNotesCanonicalBaseName(fileBaseName);
    const QString language = releaseNotesLanguageFromBaseName(fileBaseName);
    const bool activeEntry = canonicalBaseName.compare(QString::fromLatin1(kActiveReleaseNotesBaseName), Qt::CaseInsensitive) == 0;
    const QString entryVersion = activeEntry
        ? normalizeReleaseNotesVersion(currentVersion)
        : normalizeReleaseNotesVersion(canonicalBaseName);
    const QString labelText = entryVersion.isEmpty()
        ? QStringLiteral("Patch notes")
        : QStringLiteral("Patch v%1").arg(entryVersion);

    QVariantMap entry;
    entry.insert(QStringLiteral("entryKey"), activeEntry ? QStringLiteral("current") : canonicalBaseName);
    entry.insert(QStringLiteral("fileName"), fileName);
    entry.insert(QStringLiteral("language"), language);
    entry.insert(QStringLiteral("version"), entryVersion);
    entry.insert(QStringLiteral("label"), labelText);
    entry.insert(QStringLiteral("title"), labelText);
    entry.insert(QStringLiteral("notes"), notesText);
    entry.insert(QStringLiteral("current"), activeEntry);
    return entry;
}

}

QString bundledReleaseNotesTextForVersion(const QString &version)
{
    return readBundledReleaseNotesFile(bundledReleaseNotesResourcePathForVersion(version));
}

QVariantList bundledReleaseNotesEntries(const QString &currentVersion)
{
    const QString normalizedCurrentVersion = normalizeReleaseNotesVersion(currentVersion);
    QDir directory(QString::fromLatin1(kBundledReleaseNotesDir));
    const QStringList fileNames = directory.entryList(QStringList() << QStringLiteral("*.md"), QDir::Files, QDir::Name);

    QVector<QVariantMap> entries;
    entries.reserve(fileNames.size());

    for (const QString &fileName : fileNames) {
        const QString resourcePath = bundledReleaseNotesResourcePathForFileName(fileName);
        const QString notesText = readBundledReleaseNotesFile(resourcePath);
        if (notesText.isEmpty()) {
            continue;
        }
        entries.push_back(buildBundledReleaseNotesEntry(fileName, normalizedCurrentVersion, notesText));
    }

    std::sort(entries.begin(), entries.end(), [](const QVariantMap &left, const QVariantMap &right) {
        const bool leftCurrent = left.value(QStringLiteral("current")).toBool();
        const bool rightCurrent = right.value(QStringLiteral("current")).toBool();
        if (leftCurrent != rightCurrent) {
            return leftCurrent;
        }

        const QString leftVersion = left.value(QStringLiteral("version")).toString();
        const QString rightVersion = right.value(QStringLiteral("version")).toString();
        const int versionCompare = compareReleaseVersionsDescending(leftVersion, rightVersion);
        if (versionCompare != 0) {
            return versionCompare < 0;
        }

        return left.value(QStringLiteral("fileName")).toString().compare(
            right.value(QStringLiteral("fileName")).toString(),
            Qt::CaseInsensitive
        ) < 0;
    });

    QVariantList result;
    result.reserve(entries.size());
    for (const QVariantMap &entry : entries) {
        result.push_back(entry);
    }
    return result;
}
