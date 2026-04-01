@echo off
setlocal
chcp 65001 >nul 2>&1

:: Fast-path: help and version (no PowerShell needed)
if "%~1"=="" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="help" goto :show_help
if /i "%~1"=="-?" goto :show_help
if /i "%~1"=="--version" goto :show_version
if /i "%~1"=="-v" goto :show_version

powershell -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
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
echo   dropwsl v!VER! -- Uninstaller
echo.
echo   Usage:
echo     uninstall.cmd ^<mode^> [options]
echo.
echo   Modes (one required):
echo     --tools / -Tools             Remove tools inside WSL + .wslconfig (distro preserved)
echo     --unregister / -Unregister   Destroy the distro (wsl --unregister). DATA LOSS.
echo     --purge / -Purge             Destroy distro + uninstall WSL from Windows.
echo.
echo   Options:
echo     --distro / -Distro ^<name^>    WSL distro name (default: Ubuntu-24.04)
echo     --keep-wsl-config / -KeepWslConfig   Preserve .wslconfig file
echo     --force / -Force             Skip all confirmation prompts
echo     --what-if / -WhatIf         Dry-run (show what would be done)
echo.
echo   Examples:
echo     uninstall.cmd --tools                        # remove tools (preserves distro)
echo     uninstall.cmd --unregister                   # destroy distro
echo     uninstall.cmd --unregister --force            # destroy distro without prompts
echo     uninstall.cmd --purge --force                # nuclear -- also removes WSL
echo     uninstall.cmd --what-if                      # dry-run
echo.
endlocal
goto :eof
