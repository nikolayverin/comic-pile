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
constexpr auto kActiveReleaseNotesFileName = "whats-new-patch-notes.md";

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
        return bundledReleaseNotesResourcePathForFileName(QString::fromLatin1(kActiveReleaseNotesFileName));
    }

    const QString versionedFileName = normalizedVersion + QStringLiteral(".md");
    const QString versionedPath = bundledReleaseNotesResourcePathForFileName(versionedFileName);
    if (QFile::exists(versionedPath)) {
        return versionedPath;
    }
    return bundledReleaseNotesResourcePathForFileName(QString::fromLatin1(kActiveReleaseNotesFileName));
}

QVariantMap buildBundledReleaseNotesEntry(
    const QString &fileName,
    const QString &currentVersion,
    const QString &notesText)
{
    const bool activeEntry = fileName.compare(QString::fromLatin1(kActiveReleaseNotesFileName), Qt::CaseInsensitive) == 0;
    const QString fileBaseName = QFileInfo(fileName).completeBaseName().trimmed();
    const QString entryVersion = activeEntry
        ? normalizeReleaseNotesVersion(currentVersion)
        : normalizeReleaseNotesVersion(fileBaseName);
    const QString labelText = entryVersion.isEmpty()
        ? QStringLiteral("Patch notes")
        : QStringLiteral("Patch v%1").arg(entryVersion);

    QVariantMap entry;
    entry.insert(QStringLiteral("entryKey"), activeEntry ? QStringLiteral("current") : fileBaseName);
    entry.insert(QStringLiteral("fileName"), fileName);
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
