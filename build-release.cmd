@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "SRC_DIR=%ROOT%\comicflow-qt"
set "BUILD_DIR=%ROOT%\_release_build\_build\comicflow-qt-mingw"
set "STAGE_DIR=%ROOT%\_release_build\Comics-Pile"
set "BUILD_TARGET=comic_pile_qt"
set "APP_BASENAME=Comic Pile"
set "APP_EXE=%BUILD_DIR%\%APP_BASENAME%.exe"
set "STAGE_EXE=%STAGE_DIR%\%APP_BASENAME%.exe"
set "BUILD_LOG=%BUILD_DIR%\build-release.log"

set "DATABASE_SRC=%ROOT%\release\Database"
set "DATABASE_DST=%STAGE_DIR%\Database"
set "RUNTIME_MARKER=library-storage-layout-migration-v1.done"
set "RELEASE_ASSETS_SRC=%ROOT%\release"
set "RELEASE_ASSETS_DST=%STAGE_DIR%"

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
set "BUNDLED_QWEBP_DLL=%ROOT%\tools\qt-imageformats\6.10.2\mingw_64\plugins\imageformats\qwebp.dll"
set "IMAGEFORMATS_DIR=%STAGE_DIR%\imageformats"
set "SYSTEM_7Z_EXE=C:\Program Files\7-Zip\7z.exe"
set "SYSTEM_7Z_DLL=C:\Program Files\7-Zip\7z.dll"

set "PATH=%QT_BIN%;%MINGW_BIN%;C:\Qt\Tools\Ninja;%PATH%"

call :requireFile "%SRC_DIR%\CMakeLists.txt" "Project source"
if errorlevel 1 exit /b 1
call :requireFile "%DATABASE_SRC%\library.db" "Release Database"
if errorlevel 1 exit /b 1
call :requireFile "%RELEASE_ASSETS_SRC%\README.txt" "Release README"
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

echo [Comic Pile] Release build start
echo Root: %ROOT%
echo Build cache: %BUILD_DIR%
echo Release app: %STAGE_DIR%

if not exist "%ROOT%\_release_build" mkdir "%ROOT%\_release_build" >nul 2>nul
if not exist "%ROOT%\_release_build\_build" mkdir "%ROOT%\_release_build\_build" >nul 2>nul
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%" >nul 2>nul
if exist "%BUILD_LOG%" del /F /Q "%BUILD_LOG%" >nul 2>nul

echo [1/5] Configure release build directory...
"%CMAKE_EXE%" -S "%SRC_DIR%" -B "%BUILD_DIR%" -G Ninja ^
  -DCMAKE_MAKE_PROGRAM=%NINJA_EXE% ^
  -DCMAKE_CXX_COMPILER=%MINGW_BIN%\g++.exe ^
  -DCMAKE_PREFIX_PATH=%QT_ROOT% ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCOMICPILE_FAST_DEV_BUILD=OFF
if errorlevel 1 goto :fail

echo [2/5] Build target %BUILD_TARGET%...
"%CMAKE_EXE%" --build "%BUILD_DIR%" --target %BUILD_TARGET% --parallel > "%BUILD_LOG%" 2>&1
set "BUILD_RC=%ERRORLEVEL%"
if exist "%BUILD_LOG%" type "%BUILD_LOG%"
if not "%BUILD_RC%"=="0" goto :fail

if not exist "%APP_EXE%" (
    echo [FAIL] Build finished but %APP_EXE% was not produced.
    exit /b 1
)

echo [3/5] Prepare clean release folder...
if exist "%STAGE_DIR%" rmdir /S /Q "%STAGE_DIR%" >nul 2>nul
if exist "%STAGE_DIR%" (
    echo [FAIL] Could not clear release folder. Close any running app from %STAGE_DIR% and run build-release.cmd again.
    exit /b 1
)
mkdir "%STAGE_DIR%" >nul 2>nul
copy /Y "%APP_EXE%" "%STAGE_EXE%" >nul 2>nul
if errorlevel 1 (
    echo [FAIL] Could not copy %APP_EXE% to the release folder.
    exit /b 1
)

echo [4/5] Deploy release runtime...
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
if exist "%STAGE_DIR%\qmltooling" rmdir /S /Q "%STAGE_DIR%\qmltooling" >nul 2>nul

echo [5/5] Copy release Database...
robocopy "%DATABASE_SRC%" "%DATABASE_DST%" /MIR /XD ".runtime" >nul
set "ROBOCOPY_RC=%ERRORLEVEL%"
if %ROBOCOPY_RC% GEQ 8 (
    echo [FAIL] Could not copy release Database.
    exit /b 1
)
if not exist "%DATABASE_DST%\.runtime" mkdir "%DATABASE_DST%\.runtime" >nul 2>nul
if exist "%DATABASE_SRC%\.runtime\%RUNTIME_MARKER%" (
    copy /Y "%DATABASE_SRC%\.runtime\%RUNTIME_MARKER%" "%DATABASE_DST%\.runtime\%RUNTIME_MARKER%" >nul 2>nul
)
copy /Y "%RELEASE_ASSETS_SRC%\README.txt" "%RELEASE_ASSETS_DST%\README.txt" >nul 2>nul
robocopy "%RELEASE_ASSETS_SRC%\License" "%RELEASE_ASSETS_DST%\License" /MIR >nul
set "ROBOCOPY_RC=%ERRORLEVEL%"
if %ROBOCOPY_RC% GEQ 8 (
    echo [FAIL] Could not copy release license bundle.
    exit /b 1
)

echo.
echo [OK] Release build finished.
echo APP: %STAGE_DIR%
echo EXE: %STAGE_EXE%
echo DATA: %DATABASE_DST%
exit /b 0

:requireFile
if exist "%~1" exit /b 0
echo [FAIL] %~2 was not found: %~1
exit /b 1

:fail
echo.
echo [FAIL] Release build failed.
echo Check log: %BUILD_LOG%
exit /b 1
