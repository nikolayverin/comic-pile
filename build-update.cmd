@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "SRC_DIR=%ROOT%\comicflow-qt"
set "UPDATE_ROOT=%ROOT%\_update_build"
set "BUILD_DIR=%UPDATE_ROOT%\_build\comicflow-qt-mingw"
set "STAGE_DIR=%UPDATE_ROOT%\Comics-Pile"
set "BUILD_TARGET=comic_pile_qt"
set "APP_BASENAME=Comic Pile"
set "APP_EXE=%BUILD_DIR%\%APP_BASENAME%.exe"
set "STAGE_EXE=%STAGE_DIR%\%APP_BASENAME%.exe"
set "BUILD_LOG=%BUILD_DIR%\build-update.log"

set "RELEASE_ASSETS_SRC=%ROOT%\release"
set "RELEASE_ASSETS_DST=%STAGE_DIR%"
set "UPDATE_MANIFEST=%STAGE_DIR%\.comicpile-update-manifest.txt"

set "QT_ROOT=C:\Qt\6.10.2\mingw_64"
set "QT_BIN=%QT_ROOT%\bin"
set "MINGW_BIN=C:\Qt\Tools\mingw1310_64\bin"
set "NINJA_EXE=C:\Qt\Tools\Ninja\ninja.exe"
set "CMAKE_EXE=C:\Qt\Tools\CMake_64\bin\cmake.exe"
set "WINDEPLOYQT=%QT_BIN%\windeployqt.exe"

set "QT_LABS_SETTINGS_SRC=%QT_ROOT%\qml\Qt\labs\settings"
set "QT_LABS_SETTINGS_DST=%STAGE_DIR%\qml\Qt\labs\settings"
set "QT_LABS_SETTINGS_DLL_SRC=%QT_BIN%\Qt6LabsSettings.dll"
set "QT_LABS_SETTINGS_DLL_DST=%STAGE_DIR%\Qt6LabsSettings.dll"
set "BUNDLED_7Z_DIR=%ROOT%\tools\7zip"
set "BUNDLED_DJVU_RUNTIME_DIR=%ROOT%\tools\djvulibre\runtime"
set "BUNDLED_DJVU_NOTICE=%ROOT%\tools\djvulibre\NOTICE.txt"
set "BUNDLED_DJVU_SOURCE_ARCHIVE=%ROOT%\tools\djvulibre\djvulibre-3.5.29.real.tar.gz"
set "DJVU_RUNTIME_DST=%STAGE_DIR%\tools\djvulibre"
set "BUNDLED_QWEBP_DLL=%ROOT%\tools\qt-imageformats\6.10.2\mingw_64\plugins\imageformats\qwebp.dll"
set "IMAGEFORMATS_DIR=%STAGE_DIR%\imageformats"
set "SYSTEM_7Z_EXE=C:\Program Files\7-Zip\7z.exe"
set "SYSTEM_7Z_DLL=C:\Program Files\7-Zip\7z.dll"

set "PATH=%QT_BIN%;%MINGW_BIN%;C:\Qt\Tools\Ninja;%PATH%"

call :requireFile "%SRC_DIR%\CMakeLists.txt" "Project source"
if errorlevel 1 exit /b 1
call :requireFile "%RELEASE_ASSETS_SRC%\README-update.txt" "Update README"
if errorlevel 1 exit /b 1
call :requireFile "%RELEASE_ASSETS_SRC%\License\00-COMIC-PILE-LICENSE.txt" "Release license bundle"
if errorlevel 1 exit /b 1
call :requireFile "%CMAKE_EXE%" "CMake"
if errorlevel 1 exit /b 1
call :requireFile "%NINJA_EXE%" "Ninja"
if errorlevel 1 exit /b 1
call :requireFile "%MINGW_BIN%\gcc.exe" "MinGW gcc"
if errorlevel 1 exit /b 1
call :requireFile "%MINGW_BIN%\g++.exe" "MinGW g++"
if errorlevel 1 exit /b 1
call :requireFile "%QT_BIN%\qmake.exe" "Qt runtime"
if errorlevel 1 exit /b 1
call :requireFile "%WINDEPLOYQT%" "windeployqt"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_RUNTIME_DIR%\ddjvu.exe" "DjVu runtime ddjvu"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_RUNTIME_DIR%\djvudump.exe" "DjVu runtime djvudump"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_RUNTIME_DIR%\djvused.exe" "DjVu runtime djvused"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_RUNTIME_DIR%\libdjvulibre.dll" "DjVu runtime library"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_RUNTIME_DIR%\COPYING.txt" "DjVu runtime license"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_NOTICE%" "DjVu runtime notice"
if errorlevel 1 exit /b 1
call :requireFile "%BUNDLED_DJVU_SOURCE_ARCHIVE%" "DjVu source archive"
if errorlevel 1 exit /b 1

for /f "tokens=3" %%V in ('findstr /B /C:"project(ComicPileQt VERSION" "%SRC_DIR%\CMakeLists.txt"') do set "APP_VERSION=%%V"
if "%APP_VERSION%"=="" (
    echo [FAIL] Could not read app version from %SRC_DIR%\CMakeLists.txt.
    exit /b 1
)
set "UPDATE_ZIP=%UPDATE_ROOT%\Comic-Pile-v%APP_VERSION%-win64-update.zip"

echo [Comic Pile] Update package build start
echo Root: %ROOT%
echo Build cache: %BUILD_DIR%
echo Update app: %STAGE_DIR%
echo Update zip: %UPDATE_ZIP%

if not exist "%UPDATE_ROOT%" mkdir "%UPDATE_ROOT%" >nul 2>nul
if not exist "%UPDATE_ROOT%\_build" mkdir "%UPDATE_ROOT%\_build" >nul 2>nul
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%" >nul 2>nul
if exist "%BUILD_LOG%" del /F /Q "%BUILD_LOG%" >nul 2>nul

echo [1/6] Configure release build directory...
"%CMAKE_EXE%" -S "%SRC_DIR%" -B "%BUILD_DIR%" -G Ninja ^
  -DCMAKE_MAKE_PROGRAM=%NINJA_EXE% ^
  -DCMAKE_CXX_COMPILER=%MINGW_BIN%\g++.exe ^
  -DCMAKE_PREFIX_PATH=%QT_ROOT% ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCOMICPILE_FAST_DEV_BUILD=OFF
if errorlevel 1 goto :fail

echo [2/6] Build target %BUILD_TARGET%...
"%CMAKE_EXE%" --build "%BUILD_DIR%" --target %BUILD_TARGET% --parallel > "%BUILD_LOG%" 2>&1
set "BUILD_RC=%ERRORLEVEL%"
if exist "%BUILD_LOG%" type "%BUILD_LOG%"
if not "%BUILD_RC%"=="0" goto :fail

if not exist "%APP_EXE%" (
    echo [FAIL] Build finished but %APP_EXE% was not produced.
    exit /b 1
)

echo [3/6] Prepare clean update folder...
if exist "%STAGE_DIR%" rmdir /S /Q "%STAGE_DIR%" >nul 2>nul
if exist "%STAGE_DIR%" (
    echo [FAIL] Could not clear update folder. Close any running app from %STAGE_DIR% and run build-update.cmd again.
    exit /b 1
)
mkdir "%STAGE_DIR%" >nul 2>nul
copy /Y "%APP_EXE%" "%STAGE_EXE%" >nul 2>nul
if errorlevel 1 (
    echo [FAIL] Could not copy %APP_EXE% to the update folder.
    exit /b 1
)

echo [4/6] Deploy update runtime...
"%WINDEPLOYQT%" --dir "%STAGE_DIR%" --qmldir "%SRC_DIR%\qml" --no-translations "%STAGE_EXE%" >> "%BUILD_LOG%" 2>&1
if errorlevel 1 (
    echo [FAIL] windeployqt failed.
    if exist "%BUILD_LOG%" type "%BUILD_LOG%"
    exit /b 1
)

if exist "%QT_LABS_SETTINGS_SRC%\qmldir" (
    if not exist "%STAGE_DIR%\qml\Qt\labs" mkdir "%STAGE_DIR%\qml\Qt\labs" >nul 2>nul
    xcopy /E /I /Y "%QT_LABS_SETTINGS_SRC%" "%QT_LABS_SETTINGS_DST%" >nul 2>nul
)
if exist "%QT_LABS_SETTINGS_DLL_SRC%" (
    copy /Y "%QT_LABS_SETTINGS_DLL_SRC%" "%QT_LABS_SETTINGS_DLL_DST%" >nul 2>nul
)
if exist "%BUNDLED_QWEBP_DLL%" (
    if not exist "%IMAGEFORMATS_DIR%" mkdir "%IMAGEFORMATS_DIR%" >nul 2>nul
    copy /Y "%BUNDLED_QWEBP_DLL%" "%IMAGEFORMATS_DIR%\qwebp.dll" >nul 2>nul
)
if exist "%BUNDLED_7Z_DIR%\7z.exe" (
    copy /Y "%BUNDLED_7Z_DIR%\7z.exe" "%STAGE_DIR%\7z.exe" >nul 2>nul
) else if exist "%SYSTEM_7Z_EXE%" (
    copy /Y "%SYSTEM_7Z_EXE%" "%STAGE_DIR%\7z.exe" >nul 2>nul
)
if exist "%BUNDLED_7Z_DIR%\7z.dll" (
    copy /Y "%BUNDLED_7Z_DIR%\7z.dll" "%STAGE_DIR%\7z.dll" >nul 2>nul
) else if exist "%SYSTEM_7Z_DLL%" (
    copy /Y "%SYSTEM_7Z_DLL%" "%STAGE_DIR%\7z.dll" >nul 2>nul
)
if not exist "%DJVU_RUNTIME_DST%" mkdir "%DJVU_RUNTIME_DST%" >nul 2>nul
robocopy "%BUNDLED_DJVU_RUNTIME_DIR%" "%DJVU_RUNTIME_DST%" ddjvu.exe djvudump.exe djvused.exe libdjvulibre.dll libjpeg.dll libtiff.dll libz.dll COPYING.txt >nul
set "ROBOCOPY_RC=%ERRORLEVEL%"
if %ROBOCOPY_RC% GEQ 8 (
    echo [FAIL] Could not copy DjVu runtime.
    exit /b 1
)
copy /Y "%BUNDLED_DJVU_NOTICE%" "%DJVU_RUNTIME_DST%\NOTICE.txt" >nul 2>nul
if errorlevel 1 (
    echo [FAIL] Could not copy DjVu notice.
    exit /b 1
)
copy /Y "%BUNDLED_DJVU_SOURCE_ARCHIVE%" "%DJVU_RUNTIME_DST%\djvulibre-3.5.29.tar.gz" >nul 2>nul
if errorlevel 1 (
    echo [FAIL] Could not copy DjVu source archive.
    exit /b 1
)
if exist "%STAGE_DIR%\qmltooling" rmdir /S /Q "%STAGE_DIR%\qmltooling" >nul 2>nul

echo [5/6] Copy update metadata...
copy /Y "%RELEASE_ASSETS_SRC%\README-update.txt" "%RELEASE_ASSETS_DST%\README.txt" >nul 2>nul
robocopy "%RELEASE_ASSETS_SRC%\License" "%RELEASE_ASSETS_DST%\License" /MIR >nul
set "ROBOCOPY_RC=%ERRORLEVEL%"
if %ROBOCOPY_RC% GEQ 8 (
    echo [FAIL] Could not copy release license bundle.
    exit /b 1
)

rem Keep user-owned state and runtime/debug logs out of update packages and manifests.
if exist "%STAGE_DIR%\Database" rmdir /S /Q "%STAGE_DIR%\Database" >nul 2>nul
if exist "%STAGE_DIR%\ComicPile.ini" del /F /Q "%STAGE_DIR%\ComicPile.ini" >nul 2>nul
del /S /Q "%STAGE_DIR%\*.log" >nul 2>nul
del /S /Q "%STAGE_DIR%\*.log.*" >nul 2>nul
del /S /Q "%STAGE_DIR%\startup-log.txt" >nul 2>nul
del /S /Q "%STAGE_DIR%\startup-debug-log.txt" >nul 2>nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$root=(Resolve-Path -LiteralPath '%STAGE_DIR%').Path; $manifest=[System.IO.Path]::GetFullPath('%UPDATE_MANIFEST%'); Get-ChildItem -LiteralPath $root -File -Recurse -Force | ForEach-Object { $relativePath=$_.FullName.Substring($root.Length).TrimStart('\') -replace '\\','/'; $rootName=($relativePath -split '/',2)[0]; if (@('Database','ComicPile.ini','.comicpile-update-manifest.txt') -notcontains $rootName) { $relativePath } } | Sort-Object -Unique | Set-Content -LiteralPath $manifest -Encoding UTF8"
if errorlevel 1 (
    echo [FAIL] Could not write update manifest.
    exit /b 1
)

echo [6/6] Create update zip...
if exist "%UPDATE_ZIP%" del /F /Q "%UPDATE_ZIP%" >nul 2>nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$source=(Resolve-Path -LiteralPath '%STAGE_DIR%').Path; $zip='%UPDATE_ZIP%'; Compress-Archive -Path (Join-Path $source '*') -DestinationPath $zip -Force"
if errorlevel 1 (
    echo [FAIL] Could not create update zip.
    exit /b 1
)

echo.
echo [OK] Update package build finished.
echo APP: %STAGE_DIR%
echo ZIP: %UPDATE_ZIP%
goto :success

:requireFile
if exist "%~1" exit /b 0
echo [FAIL] %~2 was not found: %~1
exit /b 1

:success
endlocal
exit /b 0

:fail
echo.
echo [FAIL] Update package build failed.
echo Check log: %BUILD_LOG%
endlocal
exit /b 1
