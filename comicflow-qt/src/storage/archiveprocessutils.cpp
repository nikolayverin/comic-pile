#include "storage/archiveprocessutils.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QProcess>
#include <QtGlobal>

namespace {

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
    int timeoutMs
)
{
    stdOut.clear();
    stdErr.clear();
    errorText.clear();

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
        errorText = QStringLiteral("Failed to start PowerShell process.");
        return false;
    }

    if (!waitForProcessToFinish(
            process,
            timeoutMs,
            true,
            errorText,
            QStringLiteral("PowerShell operation timed out."))) {
        return false;
    }

    stdOut = QString::fromUtf8(process.readAllStandardOutput());
    stdErr = QString::fromUtf8(process.readAllStandardError());

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        errorText = QStringLiteral("PowerShell exited with code %1.").arg(process.exitCode());
        const QString trimmedErr = stdErr.trimmed();
        if (!trimmedErr.isEmpty()) {
            errorText += QStringLiteral(" %1").arg(trimmedErr);
        }
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
    bool pumpUiEvents
)
{
    stdOut.clear();
    stdErr.clear();
    errorText.clear();

    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.start();

    if (!process.waitForStarted(15000)) {
        errorText = QStringLiteral("Failed to start process: %1").arg(program);
        return false;
    }

    if (!waitForProcessToFinish(
            process,
            timeoutMs,
            pumpUiEvents,
            errorText,
            QStringLiteral("Process timed out: %1").arg(program))) {
        return false;
    }

    stdOut = process.readAllStandardOutput();
    stdErr = process.readAllStandardError();

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        errorText = QStringLiteral("Process failed (%1), exit code %2.").arg(program).arg(process.exitCode());
        const QString trimmedErr = QString::fromUtf8(stdErr).trimmed();
        if (!trimmedErr.isEmpty()) {
            errorText += QStringLiteral(" %1").arg(trimmedErr);
        }
        return false;
    }

    return true;
}

} // namespace ComicArchiveProcess
