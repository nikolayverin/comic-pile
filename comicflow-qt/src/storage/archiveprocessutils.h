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
    int timeoutMs = 120000,
    const QString &operationLabel = QString(),
    int *exitCodeOut = nullptr
);

bool runExternalProcess(
    const QString &program,
    const QStringList &arguments,
    QByteArray &stdOut,
    QByteArray &stdErr,
    QString &errorText,
    int timeoutMs = 120000,
    bool pumpUiEvents = false,
    const QString &operationLabel = QString(),
    int *exitCodeOut = nullptr
);

} // namespace ComicArchiveProcess
