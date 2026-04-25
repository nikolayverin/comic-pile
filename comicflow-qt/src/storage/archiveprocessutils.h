#pragma once

#include <QByteArray>
#include <QString>
#include <QStringList>

namespace ComicArchiveProcess {

constexpr int kProcessStartTimeoutMs = 15000;
constexpr int kProcessKillWaitTimeoutMs = 5000;
constexpr int kUiPumpWaitSliceMs = 50;
constexpr int kSupportProbeTimeoutMs = 15000;
constexpr int kDefaultOperationTimeoutMs = 120000;
// DJVU page rendering can legitimately take several minutes for large books.
constexpr int kDocumentRenderTimeoutMs = 600000;

QString quotePowerShellLiteral(const QString &value);

bool runPowerShellScript(
    const QString &script,
    QString &stdOut,
    QString &stdErr,
    QString &errorText,
    int timeoutMs = kDefaultOperationTimeoutMs,
    const QString &operationLabel = QString(),
    int *exitCodeOut = nullptr
);

bool runExternalProcess(
    const QString &program,
    const QStringList &arguments,
    QByteArray &stdOut,
    QByteArray &stdErr,
    QString &errorText,
    int timeoutMs = kDefaultOperationTimeoutMs,
    bool pumpUiEvents = false,
    const QString &operationLabel = QString(),
    int *exitCodeOut = nullptr
);

} // namespace ComicArchiveProcess
