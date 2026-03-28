#pragma once

#include <QByteArray>
#include <QString>
#include <QStringList>

namespace ComicArchiveProcess {

QString quotePowerShellLiteral(const QString &value);

bool runPowerShellScript(
    const QString &script,
    QString &stdOut,
    QString &stdErr,
    QString &errorText,
    int timeoutMs = 120000
);

bool runExternalProcess(
    const QString &program,
    const QStringList &arguments,
    QByteArray &stdOut,
    QByteArray &stdErr,
    QString &errorText,
    int timeoutMs = 120000,
    bool pumpUiEvents = false
);

} // namespace ComicArchiveProcess
