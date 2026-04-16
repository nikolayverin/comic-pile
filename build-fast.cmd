@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "SRC_DIR=%ROOT%\comicflow-qt"
set "BUILD_DIR=%ROOT%\_build\comicflow-qt-mingw"
set "BUILD_TARGET=comic_pile_qt"
set "APP_BASENAME=Comic Pile"
set "APP_EXE=%BUILD_DIR%\%APP_BASENAME%.exe"
set "BUILD_LOG=%BUILD_DIR%\build-fast.log"
set "BUILD_META_DIR=%BUILD_DIR%\generated\build_meta"
set "BUILD_ITERATION_FILE=%BUILD_META_DIR%\build_iteration_state.txt"
set "SUCCESSFUL_BUILD_ITERATION_FILE=%BUILD_META_DIR%\successful_build_iteration.txt"

set "QT_ROOT=C:\Qt\6.10.2\mingw_64"
set "QT_BIN=%QT_ROOT%\bin"
set "MINGW_BIN=C:\Qt\Tools\mingw1310_64\bin"
set "NINJA_EXE=C:\Qt\Tools\Ninja\ninja.exe"
set "CMAKE_EXE=C:\Qt\Tools\CMake_64\bin\cmake.exe"
set "WINDEPLOYQT=%QT_BIN%\windeployqt.exe"

set "QT_LABS_SETTINGS_SRC=%QT_ROOT%\qml\Qt\labs\settings"
set "QT_LABS_SETTINGS_DST=%BUILD_DIR%\qml\Qt\labs\settings"
set "QT_LABS_SETTINGS_DLL_SRC=%QT_BIN%\Qt6LabsSettings.dll"
set "QT_LABS_SETTINGS_DLL_DST=%BUILD_DIR%\Qt6LabsSettings.dll"
set "BUNDLED_7Z_DIR=%ROOT%\tools\7zip"
set "BUNDLED_QWEBP_DLL=%ROOT%\tools\qt-imageformats\6.10.2\mingw_64\plugins\imageformats\qwebp.dll"
set "IMAGEFORMATS_DIR=%BUILD_DIR%\imageformats"
set "SYSTEM_7Z_EXE=C:\Program Files\7-Zip\7z.exe"
set "SYSTEM_7Z_DLL=C:\Program Files\7-Zip\7z.dll"

set "PATH=%QT_BIN%;%MINGW_BIN%;C:\Qt\Tools\Ninja;%PATH%"

call :requireFile "%SRC_DIR%\CMakeLists.txt" "Project source"
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

echo [Comic Pile] Fast build start
echo Root: %ROOT%
echo Build: %BUILD_DIR%

echo [1/5] Check running app...
tasklist /FI "IMAGENAME eq %APP_BASENAME%.exe" | find /I "%APP_BASENAME%.exe" >nul
if not errorlevel 1 (
    echo [INFO] %APP_BASENAME%.exe is running. Stopping it before build...
    taskkill /F /IM "%APP_BASENAME%.exe" >nul 2>nul
    if errorlevel 1 (
        echo [FAIL] Could not stop running %APP_BASENAME%.exe. Close the app and run build-fast.cmd again.
        exit /b 1
    )
)

if not exist "%ROOT%\_build" mkdir "%ROOT%\_build" >nul 2>nul
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%" >nul 2>nul
if exist "%BUILD_LOG%" del /F /Q "%BUILD_LOG%" >nul 2>nul

echo [2/5] Configure build directory...
"%CMAKE_EXE%" -S "%SRC_DIR%" -B "%BUILD_DIR%" -G Ninja ^
  -DCMAKE_MAKE_PROGRAM=%NINJA_EXE% ^
  -DCMAKE_CXX_COMPILER=%MINGW_BIN%\g++.exe ^
  -DCMAKE_PREFIX_PATH=%QT_ROOT% ^
  -DCOMICPILE_FAST_DEV_BUILD=ON
if errorlevel 1 goto :fail

echo [3/5] Build target %BUILD_TARGET%...
"%CMAKE_EXE%" --build "%BUILD_DIR%" --target %BUILD_TARGET% --parallel > "%BUILD_LOG%" 2>&1
set "BUILD_RC=%ERRORLEVEL%"
if exist "%BUILD_LOG%" type "%BUILD_LOG%"
if not "%BUILD_RC%"=="0" goto :fail

if not exist "%APP_EXE%" (
    echo [FAIL] Build finished but %APP_EXE% was not produced.
    exit /b 1
)

echo [4/5] Deploy Qt runtime...
if exist "%WINDEPLOYQT%" (
    "%WINDEPLOYQT%" --dir "%BUILD_DIR%" --qmldir "%SRC_DIR%\qml" --no-translations "%APP_EXE%" >> "%BUILD_LOG%" 2>&1
    if errorlevel 1 (
        echo [FAIL] windeployqt failed.
        if exist "%BUILD_LOG%" type "%BUILD_LOG%"
        exit /b 1
    )
) else (
    echo [FAIL] windeployqt.exe was not found: %WINDEPLOYQT%
    exit /b 1
)

if exist "%QT_LABS_SETTINGS_SRC%\qmldir" (
    if not exist "%BUILD_DIR%\qml\Qt\labs" mkdir "%BUILD_DIR%\qml\Qt\labs" >nul 2>nul
    xcopy /E /I /Y "%QT_LABS_SETTINGS_SRC%" "%QT_LABS_SETTINGS_DST%" >nul 2>nul
)
if exist "%QT_LABS_SETTINGS_DLL_SRC%" (
    copy /Y "%QT_LABS_SETTINGS_DLL_SRC%" "%QT_LABS_SETTINGS_DLL_DST%" >nul 2>nul
)
if exist "%BUNDLED_QWEBP_DLL%" (
    if not exist "%IMAGEFORMATS_DIR%" mkdir "%IMAGEFORMATS_DIR%" >nul 2>nul
    copy /Y "%BUNDLED_QWEBP_DLL%" "%IMAGEFORMATS_DIR%\qwebp.dll" >nul 2>nul
)

echo [5/5] Copy bundled tools...
if exist "%BUNDLED_7Z_DIR%\7z.exe" (
    copy /Y "%BUNDLED_7Z_DIR%\7z.exe" "%BUILD_DIR%\7z.exe" >nul 2>nul
) else if exist "%SYSTEM_7Z_EXE%" (
    copy /Y "%SYSTEM_7Z_EXE%" "%BUILD_DIR%\7z.exe" >nul 2>nul
)
if exist "%BUNDLED_7Z_DIR%\7z.dll" (
    copy /Y "%BUNDLED_7Z_DIR%\7z.dll" "%BUILD_DIR%\7z.dll" >nul 2>nul
) else if exist "%SYSTEM_7Z_DLL%" (
    copy /Y "%SYSTEM_7Z_DLL%" "%BUILD_DIR%\7z.dll" >nul 2>nul
)

if not exist "%BUILD_META_DIR%" mkdir "%BUILD_META_DIR%" >nul 2>nul
if not exist "%BUILD_ITERATION_FILE%" (
    echo [FAIL] Build iteration source file was not found: %BUILD_ITERATION_FILE%
    exit /b 1
)
copy /Y "%BUILD_ITERATION_FILE%" "%SUCCESSFUL_BUILD_ITERATION_FILE%" >nul 2>nul
if errorlevel 1 (
    echo [FAIL] Could not write successful build stamp: %SUCCESSFUL_BUILD_ITERATION_FILE%
    exit /b 1
)

echo.
echo [OK] Build finished.
echo EXE: %APP_EXE%
echo BUILD STAMP: %SUCCESSFUL_BUILD_ITERATION_FILE%
exit /b 0

:requireFile
if exist "%~1" exit /b 0
echo [FAIL] %~2 was not found: %~1
exit /b 1

:fail
echo.
echo [FAIL] Build failed.
echo Check log: %BUILD_LOG%
exit /b 1
