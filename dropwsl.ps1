#Requires -Version 5.1
<#
.SYNOPSIS
    dropwsl -- PowerShell proxy.
    Runs dropwsl.sh commands directly from PowerShell without opening WSL manually.

.DESCRIPTION
    Thin proxy that forwards all arguments to the `dropwsl` command
    inside the WSL distro. Does not require elevation (Admin).

    The --update command is handled specially: updates Windows-side components
    (WSL platform, VS Code extensions, .wslconfig) and then syncs the
    dropwsl repository into WSL.

    Prerequisite: WSL installed + dropwsl.sh already executed (dropwsl in WSL PATH).

.PARAMETER Distro
    WSL distro name. Default: Ubuntu-24.04

.PARAMETER PassArgs
    Arguments forwarded to dropwsl (e.g. --validate, --new my-svc python).

.EXAMPLE
    # Validate the installation
    dropwsl --validate

.EXAMPLE
    # Create a new project
    dropwsl --new my-service python --with src,fastapi

.EXAMPLE
    # Scaffold in the current directory (converts Windows path to WSL)
    dropwsl --scaffold python

.EXAMPLE
    # Update everything (WSL platform + extensions + .wslconfig + repo)
    dropwsl --update

.EXAMPLE
    # Show help
    dropwsl --help

.EXAMPLE
    # Use a different distro
    dropwsl -Distro Debian --validate
#>
[CmdletBinding(PositionalBinding=$false)]
param(
    [string]$Distro = '',
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$PassArgs
)

Set-StrictMode -Version Latest

# ---- Helpers ----
. "$PSScriptRoot\lib\wsl-helpers.ps1"
if (-not $Distro) { $Distro = $script:DefaultDistro }

# Canonical path for the dropwsl binary inside WSL (used by update + proxy paths)
$script:DropwslBinPath = '~/.local/bin/dropwsl'

# Read repo.install_dir from config.yaml (single source of truth)
function Get-ConfigInstallDir {
    $configFile = Join-Path $PSScriptRoot 'config.yaml'
    if (Test-Path $configFile) {
        foreach ($line in Get-YamlSection -FilePath $configFile -SectionName 'repo') {
            if ($line -match '^\s+install_dir\s*:\s*"?([^"#]+)"?') {
                return $Matches[1].Trim().Trim("'")
            }
        }
    }
    return '~/.local/share/dropwsl'
}

# Fallback extensions when config.yaml has no vscode.extensions section
# NOTE: keep in sync with config.yaml (resilience fallback)
$script:DefaultExtensions = @('ms-vscode-remote.remote-wsl', 'ms-vscode-remote.remote-containers', 'ms-azuretools.vscode-docker')

# Read extensions from config.yaml
function Get-ConfigExtensions {
    $configFile = Join-Path $PSScriptRoot 'config.yaml'
    $extensions = @()
    if (-not (Test-Path $configFile)) { return $script:DefaultExtensions }
    $inVscode = $false; $inExtensions = $false
    foreach ($line in Get-Content $configFile) {
        # Strip inline comments
        $line = ($line -replace '#.*$', '').TrimEnd()
        if ($line -match '^\s*vscode\s*:') { $inVscode = $true; continue }
        if ($inVscode -and $line -match '^\S') { $inVscode = $false; $inExtensions = $false }
        if ($inVscode -and $line -match '^\s+extensions\s*:') { $inExtensions = $true; continue }
        if ($inExtensions -and $line -match '^\s+-\s+(.+)') { $extensions += $Matches[1].Trim().Trim('"').Trim("'") }
        elseif ($inExtensions -and $line -match '^\s+\S' -and $line -notmatch '^\s+-') { $inExtensions = $false }
    }
    if ($extensions.Count -eq 0) { return $script:DefaultExtensions }
    return $extensions
}

# Sync .wslconfig from config.yaml
function Update-WslConfigFromYaml {
    $configFile = Join-Path $PSScriptRoot 'config.yaml'
    $wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
    $changed = Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath
    if ($changed) { Write-Ok '.wslconfig updated' }
    else { Write-Ok '.wslconfig already up to date' }
}

# Detect transient WSL failure and restart.
# Returns $true if restarted (caller should retry), $false if not transient.
function Restart-WslIfTransientFailure {
    param([string]$DistrName, [string]$Output)
    # Known transient WSL failure patterns
    if ($Output -match 'systemd|Failed to start|Catastrophic|0x80070005|0x800701bc|0x80041002|0x80370102|E_INVALIDARG|WslRegisterDistribution|cannot access|HResult') {
        Write-Warn 'WSL in bad state -- restarting...'
        Write-Warn "  Detail: $($Output.Trim())"
        wsl.exe --shutdown 2>$null
        Start-Sleep -Seconds 3
        return $true
    }
    return $false
}

# Run a WSL command with proper encoding setup/teardown.
# Streams stdout/stderr to the console. Stores exit code in $script:WslExitCode.
# SilentlyContinue prevents PS 5.1 from creating NativeCommandError for stderr lines
# (Defender plugin noise). Bash errors (die/die_hint) write to stdout so they're visible.
function Invoke-WslCommand {
    param([string]$DistrName, [string]$BashCommand)
    $prevEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    wsl.exe -d $DistrName -- bash -c "$BashCommand" | Out-Host
    $script:WslExitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    [Console]::OutputEncoding = $prevEncoding
    Write-Host ''  # ensure newline after WSL output
}

# Normalize --with args: join loose tokens caused by spaces after commas.
# E.g.: @('--with', 'src,', 'mypy,', 'fastapi') -> @('--with', 'src,mypy,fastapi')
function Normalize-WithArgs {
    param([string[]]$InputArgs)
    $result = @()
    $collectingWith = $false
    foreach ($a in $InputArgs) {
        # Start collecting after --with
        if ($a -eq '--with') {
            $result += $a
            $collectingWith = $true
            continue
        }
        # Not collecting -- pass through unchanged
        if (-not $collectingWith) {
            $result += $a
            continue
        }
        # Strip surrounding commas and whitespace
        $clean = $a.Trim().TrimEnd(',').TrimStart(',')
        if (-not $clean) { continue }
        # A flag interrupts layer collection
        if ($clean.StartsWith('-')) {
            $collectingWith = $false
            $result += $a
            continue
        }
        # Append to previous layer value (comma-separated) or start new entry
        $lastIdx = $result.Count - 1
        if ($lastIdx -ge 0 -and $result[$lastIdx] -ne '--with' -and $result[$lastIdx] -notmatch '^--') {
            $result[$lastIdx] += ',' + $clean
        } else {
            $result += $clean
        }
        # Last item when argument does not end with trailing comma
        if (-not $a.EndsWith(',')) { $collectingWith = $false }
    }
    return $result
}

# --update: update Windows components + forward to WSL
function Invoke-Update {
    param([string]$DistrName)

    # Preflight: ensure dropwsl is installed in WSL before doing Windows-side work
    $preflight = (wsl.exe -d $DistrName -- bash -c "test -x $($script:DropwslBinPath) && echo ok" 2>$null) -join ''
    if ($preflight -notmatch 'ok') {
        if (Restart-WslIfTransientFailure -DistrName $DistrName -Output "$preflight") {
            $preflight = (wsl.exe -d $DistrName -- bash -c "test -x $($script:DropwslBinPath) && echo ok" 2>$null) -join ''
        }
        if ($preflight -notmatch 'ok') {
            Write-Host "  [ERROR] Command 'dropwsl' not found inside WSL ($DistrName)." -ForegroundColor Red
            Write-Host '  To provision from scratch, run as Administrator:' -ForegroundColor Yellow
            Write-Host '    install.cmd' -ForegroundColor White
            Write-Host ''
            return 1
        }
    }

    # 1. WSL platform
    Write-Step 'Updating WSL platform (wsl --update)'
    wsl.exe --update 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Ok 'WSL platform updated' }
    else { Write-Warn 'wsl --update failed (may require Admin on Win10)' }

    # 2. VS Code extensions (no --force: skip if already installed, avoids re-download)
    Write-Step 'Updating VS Code extensions'
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd) {
        $extensions = Get-ConfigExtensions
        $extTotal = $extensions.Count
        $extIdx = 0
        foreach ($ext in $extensions) {
            $extIdx++
            Write-Host "    [$extIdx/$extTotal] $ext" -NoNewline -ForegroundColor Gray
            $null = code --install-extension $ext 2>$null
            if ($LASTEXITCODE -eq 0) { Write-Host ' OK' -ForegroundColor Green }
            else { Write-Host ' FAIL' -ForegroundColor Yellow }
        }
    } else {
        Write-Warn 'VS Code (code) not found in PATH -- extensions not updated'
    }

    # 3. .wslconfig
    Write-Step 'Syncing .wslconfig'
    Update-WslConfigFromYaml

    # 4. Re-copy repo from Windows to INSTALL_DIR in WSL
    # Source of truth is the Windows checkout -- cp -a syncs to WSL.
    # Does not call dropwsl --update (git pull) -- redundant and may conflict.

    # If no .git (zip install), re-download latest zip to update Windows copy first
    $gitDir = Join-Path $PSScriptRoot '.git'
    if (-not (Test-Path $gitDir)) {
        Write-Step 'Downloading latest version (no git repo detected)'
        $zipUrl = 'https://github.com/yurifranconeri/dropwsl/archive/main.zip'
        $zipPath = Join-Path $env:TEMP 'dropwsl-update.zip'
        $extractPath = Join-Path $env:TEMP 'dropwsl-update-extract'
        try {
            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            $srcDir = Join-Path $extractPath 'dropwsl-main'
            # Sync files (exclude .git if present, keep user customizations in config.yaml)
            Get-ChildItem $srcDir -Exclude 'config.yaml' | ForEach-Object {
                Copy-Item $_.FullName -Destination $PSScriptRoot -Recurse -Force
            }
            # Update config.yaml only if user has not customized it
            $srcConfig = Join-Path $srcDir 'config.yaml'
            $dstConfig = Join-Path $PSScriptRoot 'config.yaml'
            if (-not (Test-Path $dstConfig)) { Copy-Item $srcConfig $dstConfig }
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            $newVer = (Get-Content (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
            Write-Ok "Windows copy updated to v$newVer"
        } catch {
            Write-Warn "Failed to download update: $($_.Exception.Message)"
            Write-Warn 'Continuing with current local version'
        }
    } else {
        Write-Step 'Pulling latest changes (git)'
        Push-Location $PSScriptRoot
        $null = git pull --ff-only 2>$null
        Pop-Location
    }

    Write-Step 'Syncing dropwsl repository to WSL'
    $wslPath = ConvertTo-WslPath -DistrName $DistrName -WindowsPath $PSScriptRoot
    if ($wslPath) {
        $wslPath = $wslPath.Trim()
        # Fix CRLF in all text files (excludes .git and .old)
        ConvertTo-UnixLineEndings -DistrName $DistrName -WslPath $wslPath
        # Re-copy to INSTALL_DIR + symlink (excludes .git and .old)
        $installDir = Get-ConfigInstallDir
        # Escape single quotes for bash (e.g. paths with apostrophes)
        $wslPathSafe = $wslPath -replace "'", "'\''"
        $syncCmd = "mkdir -p $installDir && rsync -a --delete --exclude='.git' --exclude='.old' '$wslPathSafe/' $installDir/ && chmod +x $installDir/dropwsl.sh && ln -sf $installDir/dropwsl.sh ~/.local/bin/dropwsl && echo SYNC_OK"
        $syncOutput = (wsl.exe -d $DistrName -- bash -c $syncCmd 2>$null) -join ''
        if ($syncOutput -match 'SYNC_OK') {
            $ver = (wsl.exe -d $DistrName -- bash -c "tr -d '\r' < $installDir/VERSION 2>/dev/null || echo unknown" 2>$null) -join ''
            Write-Ok "WSL repository synced (v$($ver.Trim()))"
        } else {
            Write-Warn 'Failed to sync repository to WSL'
        }
    } else {
        Write-Warn 'Failed to convert Windows path to WSL path'
    }

    Write-Host ''
    Write-Step 'Update complete'
    Write-Host ''
    return 0
}

# Intercept uninstall: map CLI flags to uninstall.ps1 parameters, check Admin, invoke.
# Reads $PassArgs and $Distro from script scope (set by param block).
function Invoke-UninstallProxy {
    # Explicit help request -> show uninstall help
    if ('--help' -in $PassArgs -or '-h' -in $PassArgs) {
        $cmd = Join-Path $PSScriptRoot 'uninstall.cmd'
        & cmd.exe /c "`"$cmd`" --help"
        return
    }

    $uninstallScript = Join-Path $PSScriptRoot 'uninstall.ps1'
    if (-not (Test-Path $uninstallScript)) {
        Write-Host ''
        Write-Host "  [ERROR] uninstall.ps1 not found in $PSScriptRoot" -ForegroundColor Red
        Write-Host ''
        exit 1
    }
    $uninstallArgs = @{ Distro = $Distro }
    if ('--full'           -in $PassArgs -or '--unregister' -in $PassArgs) { $uninstallArgs['Unregister'] = $true }
    if ('--force'          -in $PassArgs) { $uninstallArgs['Force'] = $true }
    if ('--remove-wsl'     -in $PassArgs -or '--purge'      -in $PassArgs) { $uninstallArgs['Purge'] = $true }
    if ('--keep-wslconfig' -in $PassArgs -or '--keep-wsl-config' -in $PassArgs) { $uninstallArgs['KeepWslConfig'] = $true }

    if ($WhatIfPreference)    { $uninstallArgs['WhatIf'] = $true }
    if ($VerbosePreference -eq 'Continue') { $uninstallArgs['Verbose'] = $true }

    # --unregister and --purge require Admin (wsl --unregister / --uninstall)
    $needsAdmin = ('--full' -in $PassArgs) -or ('--unregister' -in $PassArgs) -or ('--remove-wsl' -in $PassArgs) -or ('--purge' -in $PassArgs)
    $isAdmin = Test-Admin

    if ($needsAdmin -and -not $isAdmin) {
        Write-Host ''
        Write-Host '  [ERROR] This operation requires Administrator privileges.' -ForegroundColor Red
        Write-Host ''
        Write-Host '  Open the terminal as Admin and run again:' -ForegroundColor Yellow
        $remainingArgs = if ($PassArgs.Count -gt 1) { $PassArgs[1..($PassArgs.Count-1)] -join ' ' } else { '--unregister' }
        Write-Host "    dropwsl uninstall $remainingArgs" -ForegroundColor White
        Write-Host ''
        exit 1
    }

    & $uninstallScript @uninstallArgs
}

# Forward command to WSL with normalize + escape + transient-failure retry.
# Returns exit code from WSL (0 = success).
function Invoke-ProxyForward {
    param([string]$DistrName, [string[]]$ArgsToForward)

    $normalized = Normalize-WithArgs -InputArgs $ArgsToForward
    $argString = ($normalized | ForEach-Object {
        # Escape single-quotes and wrap in quotes if it contains whitespace or special bash chars
        $escaped = $_ -replace "'", "'\''"
        if ($escaped -match '[\s$`!\\;&#|()<>~]') { "'$escaped'" } else { $escaped }
    }) -join ' '

    Write-Host "  Connecting to WSL ($DistrName)..." -ForegroundColor DarkGray
    $bashCmd = "test -x $($script:DropwslBinPath) && exec env DROPWSL_BATCH=1 $($script:DropwslBinPath) $argString"
    Invoke-WslCommand -DistrName $DistrName -BashCommand $bashCmd
    $wslExitCode = $script:WslExitCode

    if ($wslExitCode -ne 0) {
        # dropwsl may not exist or the command returned an error.
        # Diagnosis only happens on the error path (no extra WSL calls on success).
        $checkExists = (wsl.exe -d $DistrName -- bash -c "test -x $($script:DropwslBinPath) && echo ok" 2>$null) -join ''
        if ($checkExists -notmatch 'ok') {
            # May be a transient WSL failure (catastrophic failure, systemd crash, etc.)
            if (Restart-WslIfTransientFailure -DistrName $DistrName -Output "$checkExists") {
                Write-Host "  Reconnecting to WSL ($DistrName)..." -ForegroundColor DarkGray
                Invoke-WslCommand -DistrName $DistrName -BashCommand $bashCmd
                $wslExitCode = $script:WslExitCode
            } else {
                # Show captured output -- never swallow the error
                $diagOutput = "$checkExists".Trim()
                if ($diagOutput) { Write-Warn "WSL output: $diagOutput" }
                Write-Host ''
                Write-Host "  [ERROR] Command 'dropwsl' not found inside WSL ($DistrName)." -ForegroundColor Red
                Write-Host '  To provision from scratch, run as Administrator:' -ForegroundColor Yellow
                Write-Host '    install.cmd' -ForegroundColor White
                Write-Host ''
                return 1
            }
        }
        # If dropwsl exists but returned an error, the command already showed the error
        # in the terminal (stdout/stderr flow directly). Just propagate the exit code.
    }

    return $wslExitCode
}

# ---- Main ----
function Main {
    Write-Banner

    # help, version and no-args are handled by .cmd (instant).
    # If they arrived here by mistake, redirect to .cmd.
    if (-not $PassArgs -or $PassArgs.Count -eq 0 -or $PassArgs[0] -in @('--help', '-h', 'help', '--version', '-v', 'version')) {
        $cmd = Join-Path $PSScriptRoot 'dropwsl.cmd'
        $argLine = if ($PassArgs) { ($PassArgs -join ' ') } else { '--help' }
        & cmd.exe /c "`"$cmd`" $argLine"
        exit 0
    }

    # Intercept uninstall: map flags and call uninstall.ps1
    if ($PassArgs[0] -in @('uninstall', '--uninstall')) {
        Invoke-UninstallProxy
        exit 0
    }

    # Intercept update: update Windows side + forward to WSL
    if ($PassArgs[0] -in @('--update', 'update')) {
        $rc = Invoke-Update -DistrName $Distro
        # Invoke-Update returns 0 on success, 1 on preflight failure.
        # $LASTEXITCODE may be corrupted by Defender plugin -- use $rc.
        exit $(if ($rc) { $rc } else { 0 })
    }

    # Intercept install: requires distro to exist (otherwise redirect to install.cmd)
    if ($PassArgs[0] -in @('install', '--install')) {
        $distroCheck = wsl.exe --list --quiet 2>$null |
            ForEach-Object { ($_ -replace '\0','' -replace [char]0xFEFF,'' -replace '[^\x20-\x7E]','').Trim() } |
            Where-Object { $_ -ne '' }
        if ($distroCheck -notcontains $Distro) {
            Write-Host ''
            Write-Host "  Distro '$Distro' is not installed." -ForegroundColor Yellow
            Write-Host '  To provision from scratch, run as Administrator:' -ForegroundColor Yellow
            Write-Host '    install.cmd' -ForegroundColor White
            Write-Host ''
            exit 1
        }
    }

    # Proxy: forward command to WSL with transient-failure retry
    $exitCode = Invoke-ProxyForward -DistrName $Distro -ArgsToForward $PassArgs
    exit $exitCode
}

Main
