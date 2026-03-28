#include "storage/comicinfoops.h"

#include "storage/comicinfoarchive.h"
#include "storage/sqliteconnectionutils.h"
#include "storage/storedpathutils.h"

#include "common/scopedsqlconnectionremoval.h"

#include <QFileInfo>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QVariant>

namespace {

QString trimOrEmpty(const QVariant &value)
{
    return value.toString().trimmed();
}

QString resolvedArchivePathOrStoredPath(
    const QString &dbPath,
    const QString &archivePathOverride,
    const QVariant &storedFilePathValue,
    const QVariant &storedFilenameValue
)
{
    const QString archivePath = archivePathOverride.trimmed();
    if (!archivePath.isEmpty()) {
        return archivePath;
    }

    const QString storedFilePath = trimOrEmpty(storedFilePathValue);
    const QString storedFilename = trimOrEmpty(storedFilenameValue);
    const QString dataRoot = QFileInfo(dbPath).absolutePath();
    const QString resolvedArchivePath = ComicStoragePaths::resolveStoredArchivePath(
        dataRoot,
        storedFilePath,
        storedFilename
    );
    if (!resolvedArchivePath.isEmpty()) {
        return resolvedArchivePath;
    }

    return ComicStoragePaths::normalizePathInput(storedFilePath);
}

} // namespace

namespace ComicInfoOps {

QVariantMap exportComicInfoXml(const QString &dbPath, int comicId, const QString &archivePathOverride)
{
    if (comicId < 1) {
        return {
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        };
    }

    const QString connectionName = QStringLiteral("comic_pile_export_comicinfo_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    QVariantMap values;

    {
        QSqlDatabase db;
        if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
            return {
                { QStringLiteral("error"), openError }
            };
        }

        QSqlQuery query(db);
        const QString sql = QStringLiteral(
            "SELECT "
            "file_path, filename, "
            "COALESCE(series, ''), COALESCE(volume, ''), COALESCE(issue_number, issue, ''), "
            "COALESCE(title, ''), COALESCE(publisher, ''), "
            "year, month, "
            "COALESCE(writer, ''), COALESCE(penciller, ''), COALESCE(inker, ''), COALESCE(colorist, ''), "
            "COALESCE(letterer, ''), COALESCE(cover_artist, ''), COALESCE(editor, ''), "
            "COALESCE(story_arc, ''), COALESCE(summary, ''), COALESCE(characters, ''), "
            "COALESCE(genres, ''), COALESCE(age_rating, ''), "
            "COALESCE(read_status, 'unread'), current_page "
            "FROM comics WHERE id = %1 LIMIT 1"
        ).arg(comicId);
        if (!query.exec(sql)) {
            const QString error = QStringLiteral("Failed to read issue for ComicInfo export: %1").arg(query.lastError().text());
            db.close();
            return {
                { QStringLiteral("error"), error }
            };
        }

        if (!query.next()) {
            db.close();
            return {
                { QStringLiteral("error"), QStringLiteral("Issue id %1 not found.").arg(comicId) }
            };
        }

        values.insert(
            QStringLiteral("archivePath"),
            resolvedArchivePathOrStoredPath(dbPath, archivePathOverride, query.value(0), query.value(1))
        );
        values.insert(QStringLiteral("filename"), trimOrEmpty(query.value(1)));
        values.insert(QStringLiteral("series"), trimOrEmpty(query.value(2)));
        values.insert(QStringLiteral("volume"), trimOrEmpty(query.value(3)));
        values.insert(QStringLiteral("issue"), trimOrEmpty(query.value(4)));
        values.insert(QStringLiteral("title"), trimOrEmpty(query.value(5)));
        values.insert(QStringLiteral("publisher"), trimOrEmpty(query.value(6)));
        values.insert(QStringLiteral("year"), query.value(7));
        values.insert(QStringLiteral("month"), query.value(8));
        values.insert(QStringLiteral("writer"), trimOrEmpty(query.value(9)));
        values.insert(QStringLiteral("penciller"), trimOrEmpty(query.value(10)));
        values.insert(QStringLiteral("inker"), trimOrEmpty(query.value(11)));
        values.insert(QStringLiteral("colorist"), trimOrEmpty(query.value(12)));
        values.insert(QStringLiteral("letterer"), trimOrEmpty(query.value(13)));
        values.insert(QStringLiteral("cover_artist"), trimOrEmpty(query.value(14)));
        values.insert(QStringLiteral("editor"), trimOrEmpty(query.value(15)));
        values.insert(QStringLiteral("story_arc"), trimOrEmpty(query.value(16)));
        values.insert(QStringLiteral("summary"), trimOrEmpty(query.value(17)));
        values.insert(QStringLiteral("characters"), trimOrEmpty(query.value(18)));
        values.insert(QStringLiteral("genres"), trimOrEmpty(query.value(19)));
        values.insert(QStringLiteral("age_rating"), trimOrEmpty(query.value(20)));
        values.insert(QStringLiteral("page_count"), 0);
        values.insert(QStringLiteral("read_status"), trimOrEmpty(query.value(21)));
        values.insert(QStringLiteral("current_page"), query.value(22));

        db.close();
    }

    const QString xml = ComicInfoArchive::buildComicInfoXmlFromMap(values);
    if (xml.trimmed().isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("Failed to build ComicInfo.xml.") }
        };
    }

    return {
        { QStringLiteral("comicId"), comicId },
        { QStringLiteral("archivePath"), values.value(QStringLiteral("archivePath")) },
        { QStringLiteral("xml"), xml }
    };
}

QString syncComicInfoToArchive(const QString &dbPath, int comicId, const QString &archivePathOverride)
{
    const QVariantMap exported = exportComicInfoXml(dbPath, comicId, archivePathOverride);
    if (exported.contains(QStringLiteral("error"))) {
        return exported.value(QStringLiteral("error")).toString();
    }

    const QString archivePath = trimOrEmpty(exported.value(QStringLiteral("archivePath")));
    if (archivePath.isEmpty()) {
        return QStringLiteral("Archive path is missing for issue id %1.").arg(comicId);
    }

    const QString xml = exported.value(QStringLiteral("xml")).toString();
    if (xml.trimmed().isEmpty()) {
        return QStringLiteral("Generated ComicInfo.xml is empty.");
    }

    QString errorText;
    if (!ComicInfoArchive::writeComicInfoXmlToArchive(archivePath, xml, errorText)) {
        return errorText;
    }

    return {};
}

QVariantMap readComicInfoIdentityHints(const QString &archivePath)
{
    const QString normalizedArchivePath = ComicStoragePaths::normalizePathInput(archivePath);
    if (normalizedArchivePath.isEmpty()) {
        return {};
    }

    QString xml;
    QString readError;
    if (!ComicInfoArchive::readComicInfoXmlFromArchive(normalizedArchivePath, xml, readError)) {
        Q_UNUSED(readError);
        return {};
    }

    QString parseError;
    const QVariantMap parsed = ComicInfoArchive::parseComicInfoXml(xml, parseError);
    if (!parseError.isEmpty()) {
        return {};
    }

    QVariantMap hints;
    auto copyField = [&](const char *sourceKey, const char *targetKey = nullptr) {
        const QString value = trimOrEmpty(parsed.value(QString::fromLatin1(sourceKey)));
        if (value.isEmpty()) return;
        hints.insert(QString::fromLatin1(targetKey ? targetKey : sourceKey), value);
    };

    copyField("series");
    copyField("volume");
    copyField("issue", "issueNumber");
    copyField("title");
    return hints;
}

QVariantMap buildComicInfoImportPatch(
    const QString &dbPath,
    int comicId,
    const QString &mode,
    const QString &archivePathOverride
)
{
    if (comicId < 1) {
        return {
            { QStringLiteral("error"), QStringLiteral("Invalid issue id.") }
        };
    }

    const QString normalizedMode = mode.trimmed().toLower();
    const bool isMerge = normalizedMode.isEmpty() || normalizedMode == QStringLiteral("merge");
    const bool isReplace = normalizedMode == QStringLiteral("replace");
    if (!isMerge && !isReplace) {
        return {
            { QStringLiteral("error"), QStringLiteral("Unsupported ComicInfo import mode: %1").arg(mode) }
        };
    }

    QString archivePath;
    QString filename;
    const QString connectionName = QStringLiteral("comic_pile_import_comicinfo_%1")
        .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const ScopedSqlConnectionRemoval cleanupConnection(connectionName);
    QString openError;
    {
        QSqlDatabase db;
        if (!ComicStorageSqlite::openDatabaseConnection(db, dbPath, connectionName, openError)) {
            return {
                { QStringLiteral("error"), openError }
            };
        }

        QSqlQuery query(db);
        query.prepare(QStringLiteral("SELECT file_path, filename FROM comics WHERE id = ? LIMIT 1"));
        query.addBindValue(comicId);
        if (!query.exec()) {
            const QString error = QStringLiteral("Failed to read issue for ComicInfo import: %1").arg(query.lastError().text());
            db.close();
            return {
                { QStringLiteral("error"), error }
            };
        }
        if (!query.next()) {
            db.close();
            return {
                { QStringLiteral("error"), QStringLiteral("Issue id %1 not found.").arg(comicId) }
            };
        }

        archivePath = resolvedArchivePathOrStoredPath(dbPath, archivePathOverride, query.value(0), query.value(1));
        filename = trimOrEmpty(query.value(1));
        db.close();
    }

    if (archivePath.isEmpty()) {
        return {
            { QStringLiteral("error"), QStringLiteral("Archive path is missing for issue id %1.").arg(comicId) }
        };
    }

    QString xml;
    QString readError;
    if (!ComicInfoArchive::readComicInfoXmlFromArchive(archivePath, xml, readError)) {
        if (!filename.isEmpty() && readError.contains(QStringLiteral("not found"), Qt::CaseInsensitive)) {
            return {
                { QStringLiteral("error"), QStringLiteral("ComicInfo.xml not found in archive: %1").arg(filename) }
            };
        }
        return {
            { QStringLiteral("error"), readError }
        };
    }

    QString parseError;
    const QVariantMap metadata = ComicInfoArchive::parseComicInfoXml(xml, parseError);
    if (!parseError.isEmpty()) {
        return {
            { QStringLiteral("error"), parseError }
        };
    }

    QVariantMap values;
    QVariantMap applyMap;

    auto applyText = [&](const QString &sourceKey, const QString &targetKey) {
        if (isReplace) {
            applyMap.insert(targetKey, true);
            const QVariant raw = metadata.value(sourceKey);
            if (!raw.isValid() || raw.isNull()) {
                values.insert(targetKey, QString());
                return;
            }
            values.insert(targetKey, raw.toString().trimmed());
            return;
        }

        if (!metadata.contains(sourceKey)) {
            applyMap.insert(targetKey, false);
            return;
        }

        const QVariant raw = metadata.value(sourceKey);
        if (!raw.isValid() || raw.isNull()) {
            applyMap.insert(targetKey, false);
            return;
        }

        const QString text = raw.toString().trimmed();
        if (text.isEmpty()) {
            applyMap.insert(targetKey, false);
            return;
        }

        applyMap.insert(targetKey, true);
        values.insert(targetKey, text);
    };

    auto applyNumber = [&](const QString &sourceKey, const QString &targetKey) {
        if (isReplace) {
            applyMap.insert(targetKey, true);
            const QVariant raw = metadata.value(sourceKey);
            if (!raw.isValid() || raw.isNull()) {
                values.insert(targetKey, QString());
                return;
            }
            values.insert(targetKey, raw);
            return;
        }

        if (!metadata.contains(sourceKey)) {
            applyMap.insert(targetKey, false);
            return;
        }

        const QVariant raw = metadata.value(sourceKey);
        if (!raw.isValid() || raw.isNull()) {
            applyMap.insert(targetKey, false);
            return;
        }

        applyMap.insert(targetKey, true);
        values.insert(targetKey, raw);
    };

    applyText(QStringLiteral("series"), QStringLiteral("series"));
    applyText(QStringLiteral("volume"), QStringLiteral("volume"));
    applyText(QStringLiteral("title"), QStringLiteral("title"));
    applyText(QStringLiteral("issue"), QStringLiteral("issueNumber"));
    applyText(QStringLiteral("publisher"), QStringLiteral("publisher"));
    applyNumber(QStringLiteral("year"), QStringLiteral("year"));
    applyNumber(QStringLiteral("month"), QStringLiteral("month"));
    applyText(QStringLiteral("writer"), QStringLiteral("writer"));
    applyText(QStringLiteral("penciller"), QStringLiteral("penciller"));
    applyText(QStringLiteral("inker"), QStringLiteral("inker"));
    applyText(QStringLiteral("colorist"), QStringLiteral("colorist"));
    applyText(QStringLiteral("letterer"), QStringLiteral("letterer"));
    applyText(QStringLiteral("cover_artist"), QStringLiteral("coverArtist"));
    applyText(QStringLiteral("editor"), QStringLiteral("editor"));
    applyText(QStringLiteral("story_arc"), QStringLiteral("storyArc"));
    applyText(QStringLiteral("summary"), QStringLiteral("summary"));
    applyText(QStringLiteral("characters"), QStringLiteral("characters"));
    applyText(QStringLiteral("genres"), QStringLiteral("genres"));
    applyText(QStringLiteral("age_rating"), QStringLiteral("ageRating"));
    applyText(QStringLiteral("read_status"), QStringLiteral("readStatus"));
    applyNumber(QStringLiteral("current_page"), QStringLiteral("currentPage"));

    if (isMerge) {
        bool hasAnyUpdate = false;
        for (auto it = applyMap.constBegin(); it != applyMap.constEnd(); ++it) {
            if (it.value().toBool()) {
                hasAnyUpdate = true;
                break;
            }
        }
        if (!hasAnyUpdate) {
            return {};
        }
    }

    return {
        { QStringLiteral("values"), values },
        { QStringLiteral("applyMap"), applyMap }
    };
}

} // namespace ComicInfoOps
