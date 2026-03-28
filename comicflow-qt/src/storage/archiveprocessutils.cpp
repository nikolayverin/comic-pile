#include "storage/archiveprocessutils.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFileInfo>
#include <QProcess>
#include <QtGlobal>

namespace {

QString normalizedProcessDetail(const QString &detail)
{
    QString normalized = detail.trimmed();
    normalized.replace(QLatin1Char('\r'), QLatin1Char(' '));
    normalized.replace(QLatin1Char('\n'), QLatin1Char(' '));
    return normalized.trimmed();
}

QString appendProcessDetail(const QString &baseMessage, const QString &detail)
{
    const QString normalizedDetail = normalizedProcessDetail(detail);
    if (normalizedDetail.isEmpty()) {
        return baseMessage;
    }

    return QStringLiteral("%1 %2").arg(baseMessage, normalizedDetail);
}

QString resolvedOperationLabel(const QString &operationLabel, const QString &fallbackLabel)
{
    const QString trimmedLabel = operationLabel.trimmed();
    return trimmedLabel.isEmpty() ? fallbackLabel : trimmedLabel;
}

bool waitForProcessWithUiPumping(
    QProcess &process,
    int timeoutMs,
    QString &errorText,
    const QString &timeoutMessage
)
{
    QElapsedTimer timer;
    timer.start();

    while (process.state() != QProcess::NotRunning) {
        const int remainingMs = timeoutMs - static_cast<int>(timer.elapsed());
        if (remainingMs <= 0) {
            process.kill();
            process.waitForFinished(5000);
            errorText = timeoutMessage;
            return false;
        }

        const int waitSliceMs = qMin(50, remainingMs);
        if (process.waitForFinished(waitSliceMs)) {
            break;
        }

        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents, waitSliceMs);
    }

    return true;
}

bool waitForProcessToFinish(
    QProcess &process,
    int timeoutMs,
    bool pumpUiEvents,
    QString &errorText,
    const QString &timeoutMessage
)
{
    if (pumpUiEvents) {
        return waitForProcessWithUiPumping(process, timeoutMs, errorText, timeoutMessage);
    }

    if (process.waitForFinished(timeoutMs)) {
        return true;
    }

    process.kill();
    process.waitForFinished(5000);
    errorText = timeoutMessage;
    return false;
}

} // namespace

namespace ComicArchiveProcess {

QString quotePowerShellLiteral(const QString &value)
{
    QString escaped = value;
    escaped.replace(QLatin1Char('\''), QStringLiteral("''"));
    return escaped;
}

bool runPowerShellScript(
    const QString &script,
    QString &stdOut,
    QString &stdErr,
    QString &errorText,
    int timeoutMs,
    const QString &operationLabel,
    int *exitCodeOut
)
{
    stdOut.clear();
    stdErr.clear();
    errorText.clear();
    if (exitCodeOut) {
        *exitCodeOut = 0;
    }

    const QString label = resolvedOperationLabel(
        operationLabel,
        QStringLiteral("PowerShell operation")
    );

    QProcess process;
    process.setProgram(QStringLiteral("powershell.exe"));
    process.setArguments({
        QStringLiteral("-NoProfile"),
        QStringLiteral("-NonInteractive"),
        QStringLiteral("-ExecutionPolicy"), QStringLiteral("Bypass"),
        QStringLiteral("-Command"), script
    });

    process.start();
    if (!process.waitForStarted(15000)) {
        errorText = QStringLiteral("%1 failed to start.").arg(label);
        return false;
    }

    if (!waitForProcessToFinish(
            process,
            timeoutMs,
            true,
            errorText,
            QStringLiteral("%1 timed out.").arg(label))) {
        return false;
    }

    stdOut = QString::fromUtf8(process.readAllStandardOutput());
    stdErr = QString::fromUtf8(process.readAllStandardError());
    if (exitCodeOut) {
        *exitCodeOut = process.exitCode();
    }

    if (process.exitStatus() != QProcess::NormalExit) {
        errorText = appendProcessDetail(
            QStringLiteral("%1 ended unexpectedly.").arg(label),
            stdErr
        );
        return false;
    }

    if (process.exitCode() != 0) {
        errorText = appendProcessDetail(
            QStringLiteral("%1 failed with exit code %2.").arg(label).arg(process.exitCode()),
            stdErr
        );
        return false;
    }

    return true;
}

bool runExternalProcess(
    const QString &program,
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
    stdOut.clear();
    stdErr.clear();
    errorText.clear();
    if (exitCodeOut) {
        *exitCodeOut = 0;
    }

    QString fallbackLabel = QFileInfo(program).fileName().trimmed();
    if (fallbackLabel.isEmpty()) {
        fallbackLabel = QStringLiteral("External process");
    }
    const QString label = resolvedOperationLabel(operationLabel, fallbackLabel);

    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.start();

    if (!process.waitForStarted(15000)) {
        errorText = QStringLiteral("%1 failed to start.").arg(label);
        return false;
    }

    if (!waitForProcessToFinish(
            process,
            timeoutMs,
            pumpUiEvents,
            errorText,
            QStringLiteral("%1 timed out.").arg(label))) {
        return false;
    }

    stdOut = process.readAllStandardOutput();
    stdErr = process.readAllStandardError();
    if (exitCodeOut) {
        *exitCodeOut = process.exitCode();
    }

    const QString stdErrText = QString::fromUtf8(stdErr);
    if (process.exitStatus() != QProcess::NormalExit) {
        errorText = appendProcessDetail(
            QStringLiteral("%1 ended unexpectedly.").arg(label),
            stdErrText
        );
        return false;
    }

    if (process.exitCode() != 0) {
        errorText = appendProcessDetail(
            QStringLiteral("%1 failed with exit code %2.").arg(label).arg(process.exitCode()),
            stdErrText
        );
        return false;
    }

    return true;
}

} // namespace ComicArchiveProcess
