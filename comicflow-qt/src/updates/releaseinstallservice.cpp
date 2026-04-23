#include "updates/releaseinstallservice.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

namespace {

QString invalidPackagePathErrorText()
{
    return QStringLiteral("Comic Pile couldn't find the downloaded update package.");
}

QString invalidPackageTypeErrorText()
{
    return QStringLiteral("Comic Pile can only install downloaded .zip update packages.");
}

QString invalidInstallFolderErrorText()
{
    return QStringLiteral("Comic Pile couldn't find the current app folder for installing the update.");
}

QString missingPowerShellErrorText()
{
    return QStringLiteral("Comic Pile couldn't start the update helper because PowerShell is not available.");
}

QString helperFolderErrorText()
{
    return QStringLiteral("Comic Pile couldn't prepare the temporary update helper files.");
}

QString helperScriptErrorText()
{
    return QStringLiteral("Comic Pile couldn't write the temporary update helper script.");
}

QString helperLaunchErrorText()
{
    return QStringLiteral("Comic Pile couldn't start the update helper.");
}

QString updateHelperRootPath()
{
    return QDir(QDir::tempPath()).filePath(QStringLiteral("ComicPile/update-install"));
}

} // namespace

ReleaseInstallService::ReleaseInstallService(QObject *parent)
    : QObject(parent)
{
}

QString ReleaseInstallService::installDownloadedRelease(const QString &packagePath)
{
    const QString validationError = validateInstallRequest(packagePath);
    if (!validationError.isEmpty()) {
        return validationError;
    }

    const QString powerShellPath = QStandardPaths::findExecutable(QStringLiteral("powershell.exe"));
    if (powerShellPath.isEmpty()) {
        return missingPowerShellErrorText();
    }

    QString helperRootPath;
    const QString helperRootError = ensureHelperRoot(helperRootPath);
    if (!helperRootError.isEmpty()) {
        return helperRootError;
    }

    const QString helperScriptPath = writeHelperScript(helperRootPath);
    if (helperScriptPath.isEmpty()) {
        return helperScriptErrorText();
    }

    const QString installDirPath = QCoreApplication::applicationDirPath();
    const QString exePath = QCoreApplication::applicationFilePath();
    const QString normalizedPackagePath = QFileInfo(packagePath).absoluteFilePath();
    const QString currentPidText = QString::number(QCoreApplication::applicationPid());

    const QStringList arguments = {
        QStringLiteral("-NoProfile"),
        QStringLiteral("-NonInteractive"),
        QStringLiteral("-ExecutionPolicy"),
        QStringLiteral("Bypass"),
        QStringLiteral("-WindowStyle"),
        QStringLiteral("Hidden"),
        QStringLiteral("-File"),
        helperScriptPath,
        currentPidText,
        normalizedPackagePath,
        installDirPath,
        exePath,
        helperRootPath
    };

    if (!QProcess::startDetached(powerShellPath, arguments, helperRootPath)) {
        return helperLaunchErrorText();
    }

    if (QObject *appInstance = QCoreApplication::instance()) {
        QTimer::singleShot(0, appInstance, []() {
            QCoreApplication::quit();
        });
    }
    return {};
}

QString ReleaseInstallService::validateInstallRequest(const QString &packagePath) const
{
    const QFileInfo packageInfo(QString(packagePath).trimmed());
    if (!packageInfo.exists() || !packageInfo.isFile()) {
        return invalidPackagePathErrorText();
    }
    if (!packageInfo.fileName().endsWith(QStringLiteral(".zip"), Qt::CaseInsensitive)) {
        return invalidPackageTypeErrorText();
    }

    const QFileInfo installDirInfo(QCoreApplication::applicationDirPath());
    if (!installDirInfo.exists() || !installDirInfo.isDir()) {
        return invalidInstallFolderErrorText();
    }

    const QFileInfo exeInfo(QCoreApplication::applicationFilePath());
    if (!exeInfo.exists() || !exeInfo.isFile()) {
        return invalidInstallFolderErrorText();
    }

    return {};
}

QString ReleaseInstallService::ensureHelperRoot(QString &helperRootOut) const
{
    const QString baseRootPath = updateHelperRootPath();
    if (!QDir().mkpath(baseRootPath)) {
        return helperFolderErrorText();
    }

    const QString uniqueFolderName = QStringLiteral("run-%1")
        .arg(QString::number(QDateTime::currentMSecsSinceEpoch()));
    const QString helperRootPath = QDir(baseRootPath).filePath(uniqueFolderName);
    if (!QDir().mkpath(helperRootPath)) {
        return helperFolderErrorText();
    }

    helperRootOut = helperRootPath;
    return {};
}

QString ReleaseInstallService::writeHelperScript(const QString &helperRootPath) const
{
    const QString scriptPath = QDir(helperRootPath).filePath(QStringLiteral("install-update.ps1"));
    QSaveFile scriptFile(scriptPath);
    if (!scriptFile.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return {};
    }

    const QByteArray payload = helperScriptBody().toUtf8();
    if (scriptFile.write(payload) != payload.size()) {
        scriptFile.cancelWriting();
        return {};
    }

    if (!scriptFile.commit()) {
        return {};
    }

    return scriptPath;
}

QString ReleaseInstallService::helperScriptBody() const
{
    return QString::fromLatin1(R"(param(
    [string]$AppPidText,
    [string]$ZipPath,
    [string]$InstallDir,
    [string]$ExePath,
    [string]$HelperRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Windows.Forms

function Show-InstallError([string]$MessageText) {
    [System.Windows.Forms.MessageBox]::Show(
        $MessageText,
        'Comic Pile update',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

$ManifestName = '.comicpile-update-manifest.txt'
$ProtectedRootNames = @('Database', 'ComicPile.ini', $ManifestName)

function Convert-ToRelativeInstallPath([string]$RootDir, [string]$FullName) {
    $rootPath = [System.IO.Path]::GetFullPath($RootDir)
    $fullPath = [System.IO.Path]::GetFullPath($FullName)
    if (-not $rootPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootPath = $rootPath + [System.IO.Path]::DirectorySeparatorChar
    }
    if (-not $fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ''
    }
    return $fullPath.Substring($rootPath.Length).Replace('\', '/')
}

function Test-ProtectedRootRelativePath([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return $true
    }
    $rootName = $RelativePath -split '[\\/]', 2 | Select-Object -First 1
    foreach ($protectedName in $ProtectedRootNames) {
        if ($rootName -ieq $protectedName) {
            return $true
        }
    }
    return $false
}

function Get-PackageFileManifest([string]$PackageRoot) {
    $manifestEntries = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath $PackageRoot -File -Recurse -Force | ForEach-Object {
        $relativePath = Convert-ToRelativeInstallPath $PackageRoot $_.FullName
        if (-not [string]::IsNullOrWhiteSpace($relativePath)
            -and -not (Test-ProtectedRootRelativePath $relativePath)) {
            $manifestEntries.Add($relativePath)
        }
    }
    return $manifestEntries | Sort-Object -Unique
}

function Remove-StaleInstalledFiles([string]$InstallDir, [string[]]$NewManifestEntries) {
    $manifestPath = Join-Path $InstallDir $ManifestName
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return
    }

    $newManifestLookup = @{}
    foreach ($relativePath in $NewManifestEntries) {
        if (-not [string]::IsNullOrWhiteSpace($relativePath)) {
            $newManifestLookup[$relativePath] = $true
        }
    }

    $candidateDirs = New-Object System.Collections.Generic.List[string]
    Get-Content -LiteralPath $manifestPath | ForEach-Object {
        $relativePath = [string]$_
        if (-not [string]::IsNullOrWhiteSpace($relativePath)
            -and -not (Test-ProtectedRootRelativePath $relativePath)
            -and -not ($newManifestLookup.ContainsKey($relativePath))) {
            $targetPath = Join-Path $InstallDir ($relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
                Remove-Item -LiteralPath $targetPath -Force
                $parentDir = Split-Path -Parent $targetPath
                if (-not [string]::IsNullOrWhiteSpace($parentDir)) {
                    $candidateDirs.Add($parentDir)
                }
            }
        }
    }

    $candidateDirs |
        Sort-Object { $_.Length } -Descending -Unique |
        ForEach-Object {
            if ((Test-Path -LiteralPath $_ -PathType Container)
                -and -not (Get-ChildItem -LiteralPath $_ -Force | Select-Object -First 1)) {
                Remove-Item -LiteralPath $_ -Force
            }
        }
}

function Write-InstallManifest([string]$InstallDir, [string[]]$ManifestEntries) {
    $manifestPath = Join-Path $InstallDir $ManifestName
    $ManifestEntries | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

function Copy-DirectoryContent([string]$SourceDir, [string]$DestinationDir) {
    if (-not (Test-Path -LiteralPath $DestinationDir -PathType Container)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        $destinationPath = Join-Path $DestinationDir $_.Name
        if ($_.PSIsContainer) {
            Copy-DirectoryContent $_.FullName $destinationPath
            return
        }

        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
    }
}

try {
    $appPid = 0
    [void][int]::TryParse($AppPidText, [ref]$appPid)
    if ($appPid -gt 0) {
        Wait-Process -Id $appPid -Timeout 30 -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600
    }

    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw 'The downloaded update package is no longer available.'
    }
    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
        throw 'The current Comic Pile app folder could not be found.'
    }

    $extractRoot = Join-Path $HelperRoot 'extracted'
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

    Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractRoot -Force

    $packageRoot = $null
    if (Test-Path -LiteralPath (Join-Path $extractRoot 'Comic Pile.exe') -PathType Leaf) {
        $packageRoot = Get-Item -LiteralPath $extractRoot
    } else {
        $packageRoot = Get-ChildItem -LiteralPath $extractRoot -Directory -Recurse -Force |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'Comic Pile.exe') -PathType Leaf } |
            Select-Object -First 1
    }

    if ($null -eq $packageRoot) {
        throw 'The downloaded update package does not contain Comic Pile.exe.'
    }

    $newManifestEntries = @(Get-PackageFileManifest $packageRoot.FullName)
    Remove-StaleInstalledFiles $InstallDir $newManifestEntries

    Get-ChildItem -LiteralPath $packageRoot.FullName -Force | Where-Object {
        $ProtectedRootNames -notcontains $_.Name
    } | ForEach-Object {
        $destinationPath = Join-Path $InstallDir $_.Name
        if ($_.PSIsContainer) {
            Copy-DirectoryContent $_.FullName $destinationPath
            return
        }

        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
    }

    Write-InstallManifest $InstallDir $newManifestEntries

    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        throw 'Comic Pile.exe was not found after the update files were copied.'
    }

    Start-Process -FilePath $ExePath -WorkingDirectory $InstallDir | Out-Null
    exit 0
} catch {
    $details = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($details)) {
        $details = 'The update helper failed unexpectedly.'
    }
    Show-InstallError("Comic Pile couldn't install the downloaded update.`n`n$details")
    exit 1
}
)");
}
