#include "updates/bundledreleasenotes.h"

#include <QFile>
#include <QRegularExpression>

namespace {

QString normalizedReleaseNotesVersion(const QString &version)
{
    QString normalized = version.trimmed();
    normalized.remove(QRegularExpression(QStringLiteral("^[vV]+")));
    return normalized.trimmed();
}

QString bundledReleaseNotesResourcePathForVersion(const QString &version)
{
    Q_UNUSED(version)
    return QStringLiteral(":/qt/qml/ComicPile/release/WhatsNew/whats-new-patch-notes.md");
}

}

QString bundledReleaseNotesTextForVersion(const QString &version)
{
    const QString resourcePath = bundledReleaseNotesResourcePathForVersion(version);
    if (resourcePath.isEmpty()) {
        return {};
    }

    QFile file(resourcePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    return QString::fromUtf8(file.readAll()).trimmed();
}
