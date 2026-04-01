@echo off
setlocal
chcp 65001 >nul 2>&1

:: Save script directory BEFORE any shift or goto (shift corrupts %~dp0)
set "DROPWSL_DIR=%~dp0"

:: Fast-path: help and version (no PowerShell needed)
if "%~1"=="" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-?" goto :show_help
if /i "%~1"=="--version" goto :show_version
if /i "%~1"=="-v" goto :show_version
if /i "%~1"=="version" goto :show_version

:: Install/Uninstall are Windows-side operations -- delegate to their .cmd
if /i "%~1"=="install" goto :delegate_install
if /i "%~1"=="--install" goto :delegate_install
if /i "%~1"=="uninstall" goto :delegate_uninstall
if /i "%~1"=="--uninstall" goto :delegate_uninstall

:: All other commands -> PowerShell proxy
powershell -ExecutionPolicy Bypass -File "%DROPWSL_DIR%dropwsl.ps1" %*
exit /b %ERRORLEVEL%

:delegate_install
:: Shift off the "install" arg and pass the rest to install.cmd
set "INSTALL_ARGS="
shift
:install_loop
if "%~1"=="" goto :install_exec
set "INSTALL_ARGS=%INSTALL_ARGS% %1"
shift
goto :install_loop
:install_exec
"%DROPWSL_DIR%install.cmd"%INSTALL_ARGS%
exit /b %ERRORLEVEL%

:delegate_uninstall
:: Shift off the "uninstall" arg and pass the rest to uninstall.cmd
set "UNINSTALL_ARGS="
shift
:uninstall_loop
if "%~1"=="" goto :uninstall_exec
set "UNINSTALL_ARGS=%UNINSTALL_ARGS% %1"
shift
goto :uninstall_loop
:uninstall_exec
"%DROPWSL_DIR%uninstall.cmd"%UNINSTALL_ARGS%
exit /b %ERRORLEVEL%

:show_version
setlocal enabledelayedexpansion
for /f "usebackq tokens=*" %%A in ("%DROPWSL_DIR%VERSION") do set "VER=%%A"
echo dropwsl v!VER!
endlocal
goto :eof

:show_help
setlocal enabledelayedexpansion
for /f "usebackq tokens=*" %%A in ("%DROPWSL_DIR%VERSION") do set "VER=%%A"
echo.
echo        _                             _
echo     __^| ^|_ __ ___  _ ____      __ __^| ^|
echo    / _` ^| '__/ _ \^| '_ \ \ /\ / / __^| ^|
echo   ^| ^(_^| ^| ^| ^| ^(_^) ^| ^|_^) \ V  V /\__ \ ^|___
echo    \__,_^|_^|  \___/^| .__/ \_/\_/ ^|___/_____^|
echo                   ^|_^|
echo.
echo   dropwsl v!VER! -- Cloud-Native dev environment
echo.
echo   Usage:
echo     dropwsl ^<command^> [flags]
echo.
echo   Commands:
echo     validate                                # validate installation
echo     doctor                                  # proactive environment diagnostics
echo     config                                  # show effective configuration
echo     new my-svc python --with src,fastapi    # create project
echo     layers                                  # list available layers
echo     scaffold python                         # scaffold .devcontainer/
echo     update                                  # update everything (WSL + extensions + repo)
echo     uninstall --tools                       # remove tools (preserves distro)
echo     uninstall --unregister                  # destroy distro (wsl --unregister)
echo     uninstall --unregister --force           # no confirmation
echo     uninstall --purge                       # nuclear (removes WSL from Windows)
echo.
echo   Flags:
echo     -q, --quiet    Suppress verbose apt output
echo     -y, --yes      Skip interactive confirmations
echo     -h, --help     This message
echo     -v, --version  Show version
echo.
echo   Parameters:
echo     --distro / -Distro ^<name^>  WSL distro (default: Ubuntu-24.04)
echo.
echo   This proxy forwards commands to dropwsl inside WSL.
echo   To install/uninstall WSL itself, use install.cmd / uninstall.cmd.
echo.
endlocal
goto :eof
