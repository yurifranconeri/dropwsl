@echo off
setlocal
chcp 65001 >nul 2>&1

:: Fast-path: help and version (no PowerShell needed)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-?" goto :show_help
if /i "%~1"=="--version" goto :show_version
if /i "%~1"=="-v" goto :show_version

:: Bootstrap: if install.ps1 is missing, download the full repo as zip
if exist "%~dp0install.ps1" goto :run_install

echo.
echo   dropwsl -- Bootstrapping (downloading repository)...
echo.

set "DROPWSL_ZIP=%TEMP%\dropwsl.zip"
set "DROPWSL_EXTRACT=%TEMP%\dropwsl-extract"
set "DROPWSL_DIR=C:\dropwsl"
set "DROPWSL_REPO_ZIP=https://github.com/yurifranconeri/dropwsl/archive/main.zip"

:: Clean previous extract
if exist "%DROPWSL_EXTRACT%" rd /s /q "%DROPWSL_EXTRACT%" >nul 2>&1

:: Download zip using curl.exe (built-in since Windows 10 1803)
curl.exe -fsSL "%DROPWSL_REPO_ZIP%" -o "%DROPWSL_ZIP%"
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to download dropwsl. Check your internet connection.
    exit /b 1
)

:: Extract zip using tar.exe (built-in since Windows 10 1803)
mkdir "%DROPWSL_EXTRACT%" >nul 2>&1
tar.exe -xf "%DROPWSL_ZIP%" -C "%DROPWSL_EXTRACT%"
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to extract archive.
    exit /b 1
)

:: Copy to C:\dropwsl
if not exist "%DROPWSL_DIR%" mkdir "%DROPWSL_DIR%"
xcopy /E /I /Y /Q "%DROPWSL_EXTRACT%\dropwsl-main\*" "%DROPWSL_DIR%" >nul
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to copy files to %DROPWSL_DIR%.
    exit /b 1
)

:: Fix line endings: GitHub zip serves LF, but cmd.exe requires CRLF.
:: type reads in text mode (LF) and > writes in text mode (CRLF).
for %%F in ("%DROPWSL_DIR%\*.cmd") do (
    move /y "%%F" "%%F.tmp" >nul
    type "%%F.tmp" > "%%F"
    del "%%F.tmp" >nul
)

:: Cleanup temp files
del /q "%DROPWSL_ZIP%" >nul 2>&1
rd /s /q "%DROPWSL_EXTRACT%" >nul 2>&1

echo   Repository downloaded to %DROPWSL_DIR%
echo.

:: Re-invoke from the extracted copy
"%DROPWSL_DIR%\install.cmd" %*
exit /b %ERRORLEVEL%

:run_install
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
exit /b %ERRORLEVEL%

:show_version
setlocal enabledelayedexpansion
for /f "usebackq tokens=*" %%A in ("%~dp0VERSION") do set "VER=%%A"
echo dropwsl v!VER!
endlocal
goto :eof

:show_help
setlocal enabledelayedexpansion
for /f "usebackq tokens=*" %%A in ("%~dp0VERSION") do set "VER=%%A"
echo.
echo        _                             _
echo     __^| ^|_ __ ___  _ ____      __ __^| ^|
echo    / _` ^| '__/ _ \^| '_ \ \ /\ / / __^| ^|
echo   ^| ^(_^| ^| ^| ^| ^(_^) ^| ^|_^) \ V  V /\__ \ ^|___
echo    \__,_^|_^|  \___/^| .__/ \_/\_/ ^|___/_____^|
echo                   ^|_^|
echo.
echo   dropwsl v!VER! -- Installer
echo.
echo   Usage:
echo     install.cmd [options]
echo.
echo   What it does:
echo     1. Installs WSL if not present
echo     2. Installs the distro (default: Ubuntu-24.04)
echo     3. Configures .wslconfig (networking, resource limits)
echo     4. Provisions a Linux user (same as Windows username)
echo     5. Runs dropwsl.sh inside WSL (installs Docker, kubectl, kind, etc.)
echo     6. Adds repo to user PATH
echo.
echo   Options:
echo     --distro / -Distro ^<name^>           WSL distro name (default: Ubuntu-24.04)
echo     --skip-wsl-config / -SkipWslConfig  Skip .wslconfig creation/update
echo     --dropwsl-args / -DropwslArgs ^<args^> Extra args for dropwsl.sh
echo.
echo   Examples:
echo     install.cmd                                       # full installation
echo     install.cmd --distro Debian                       # install with Debian
echo     install.cmd --dropwsl-args "--validate"           # validate only
echo     install.cmd --skip-wsl-config                     # skip .wslconfig
echo.
echo   Requires: Administrator privileges (right-click ^> Run as Administrator)
echo.
endlocal
goto :eof
