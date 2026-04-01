#Requires -Version 5.1
<#
.SYNOPSIS
    Runs Pester tests with auto-install of the module.
.DESCRIPTION
    Checks if Pester 5.x is available, installs if needed,
    and executes all .Tests.ps1 in tests/pester/.
.EXAMPLE
    .\tests\run-pester.ps1
    .\tests\run-pester.ps1 -Verbosity Detailed
#>
param(
    [ValidateSet('None','Normal','Detailed','Diagnostic')]
    [string]$Verbosity = 'Detailed'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# PS 5.1 reads files without BOM as ANSI -- force UTF-8 for accented output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$PesterDir = Join-Path $PSScriptRoot 'pester'

# ---- Pester 5.x auto-install ----
$minVersion = [version]'5.0.0'
$pester = Get-Module Pester -ListAvailable | Where-Object { $_.Version -ge $minVersion } | Select-Object -First 1

if (-not $pester) {
    Write-Host '==> Pester 5.x not found. Installing...' -ForegroundColor Cyan
    # Remove Pester 3.x built-in from path (PS 5.1 ships with 3.4.0)
    $builtinPath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\Pester'
    if (Test-Path $builtinPath) {
        $env:PSModulePath = ($env:PSModulePath -split ';' | Where-Object { $_ -notlike "*Pester*" }) -join ';'
    }
    Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
    $pester = Get-Module Pester -ListAvailable | Where-Object { $_.Version -ge $minVersion } | Select-Object -First 1
    if (-not $pester) {
        Write-Error 'Failed to install Pester 5.x. Run manually: Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force'
        exit 1
    }
    Write-Host "[OK] Pester $($pester.Version) installed" -ForegroundColor Green
} else {
    Write-Host "==> Pester $($pester.Version) found" -ForegroundColor Cyan
}

Import-Module Pester -MinimumVersion 5.0.0 -Force

# ---- Execution ----
Write-Host "==> Running tests in $PesterDir" -ForegroundColor Cyan
$config = New-PesterConfiguration
$config.Run.Path = $PesterDir
$config.Output.Verbosity = $Verbosity
$config.Run.Exit = $true

Invoke-Pester -Configuration $config
