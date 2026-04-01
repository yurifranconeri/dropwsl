#Requires -Version 5.1
<#
.SYNOPSIS
    dropwsl -- Windows uninstaller.
    Removes WSL tools, .wslconfig and optionally the distro/WSL itself.

.DESCRIPTION
    This script is the inverse of install.ps1. Three levels:
      -Tools         -- removes tools inside WSL + .wslconfig (distro preserved)
      -Unregister    -- destroys the distro (wsl --unregister). Skips tool removal.
      -Purge         -- destroys the distro + uninstalls WSL from Windows. Implies -Unregister.

.PARAMETER Distro
    WSL distro name. Default: Ubuntu-24.04

.PARAMETER Tools
    Removes installed tools inside WSL + .wslconfig. Distro is preserved.

.PARAMETER Unregister
    Destroys the entire distro (wsl --unregister). DATA LOSS.

.PARAMETER Purge
    Destroys the distro + uninstalls WSL from Windows. Implies -Unregister.

.PARAMETER KeepWslConfig
    Preserves the .wslconfig file (does not remove it).

.PARAMETER Force
    Skips all confirmation prompts.

.EXAMPLE
    # Dry-run -- shows what would be done without executing
    .\uninstall.cmd -WhatIf

.EXAMPLE
    # Remove tools + .wslconfig (distro preserved)
    .\uninstall.cmd --tools

.EXAMPLE
    # Destroy the distro
    .\uninstall.cmd -Unregister

.EXAMPLE
    # Destroy the distro without prompts
    .\uninstall.cmd -Unregister -Force

.EXAMPLE
    # Nuclear -- also uninstalls WSL from Windows
    .\uninstall.cmd -Purge -Force
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$Distro = '',
    [switch]$Tools,
    [switch]$Unregister,
    [switch]$Purge,
    [switch]$KeepWslConfig,
    [switch]$Force
)

Set-StrictMode -Version Latest

# ---- Helpers ----
. "$PSScriptRoot\lib\wsl-helpers.ps1"
if (-not $Distro) { $Distro = $script:DefaultDistro }

# ---- Steps (extracted for readability) ----

# Runs dropwsl.sh --clean-soft inside WSL to remove installed tools.
# Returns $true on success, $false on failure or WhatIf.
function Invoke-CleanSoft {
    param(
        [string]$Distro,
        [string]$ScriptRoot,
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    if (-not $Cmdlet.ShouldProcess("Distro '$Distro'", 'Run dropwsl.sh --clean-soft -y')) {
        return $false
    }

    Write-Host '  Connecting to WSL...' -ForegroundColor DarkGray
    $wslPath = ConvertTo-WslPath -DistrName $Distro -WindowsPath $ScriptRoot

    if (-not $wslPath) {
        Write-Warn 'Failed to resolve WSL path. Skipping clean-soft.'
        return $false
    }
    ConvertTo-UnixLineEndings -DistrName $Distro -WslPath $wslPath

    # Escape single quotes for bash (e.g. usernames like O'Brien)
    $wslPathSafe = $wslPath -replace "'", "'\''" 
    $cmd = "cd '$wslPathSafe' && DROPWSL_BATCH=1 bash dropwsl.sh --clean-soft -y"
    $prevEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    wsl.exe -d $Distro -- bash -c $cmd | Out-Host
    $cleanExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    [Console]::OutputEncoding = $prevEncoding
    Write-Host ''  # ensure newline after WSL output

    if ($cleanExit -ne 0) {
        Write-Warn "dropwsl.sh --clean-soft failed (exit code: $cleanExit). Continuing..."
        return $false
    }

    Write-Ok 'Tools removed from WSL'
    return $true
}

# Confirms and executes wsl --unregister.
# Returns $true on success, $false on WhatIf/Confirm-No, $null if user cancelled.
# On unregister failure: Write-Error + exit 1 (never returns).
function Invoke-DistroUnregister {
    param(
        [string]$Distro,
        [bool]$ForceConfirm,
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    Write-Host ''
    Write-Host '  +------------------------------------------------------+' -ForegroundColor Red
    Write-Host '  |  WARNING: wsl --unregister DESTROYS all data in the   |' -ForegroundColor Red
    Write-Host '  |  distro. This action CANNOT be undone.                |' -ForegroundColor Red
    Write-Host '  +------------------------------------------------------+' -ForegroundColor Red
    Write-Host ''

    $confirmed = $ForceConfirm
    if (-not $confirmed) {
        $response = Read-Host "  Type 'YES' (uppercase) to confirm removal of '$Distro'"
        $confirmed = ($response -ceq 'YES')
    }

    if (-not $confirmed) {
        Write-Warn 'Distro removal cancelled by user.'
        return $null
    }

    Write-Step "Stopping WSL processes to avoid locks"
    if ($Cmdlet.ShouldProcess('WSL processes', 'taskkill + wsl --shutdown')) {
        # Derive distro executable name (e.g. Ubuntu-24.04 -> ubuntu2404.exe)
        $distroExe = ($Distro.ToLower() -replace '[.\-]', '') + '.exe'

        foreach ($proc in @('wslservice.exe', 'wsl.exe', 'bash.exe', $distroExe)) {
            $null = taskkill.exe /F /IM $proc 2>$null
        }
        wsl.exe --shutdown 2>$null
        Start-Sleep -Seconds 2
    }

    Write-Step "Removing distro '$Distro' (wsl --unregister)"
    if ($Cmdlet.ShouldProcess("Distro '$Distro'", 'wsl --unregister')) {
        wsl.exe --unregister $Distro
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to remove distro '$Distro'."
            exit 1
        }
        Write-Ok "Distro '$Distro' removed"
        Write-Host '  Note: wsl-vpnkit distro preserved (shared by all WSL distros).' -ForegroundColor DarkGray
        Write-Host '  To remove: wsl --unregister wsl-vpnkit' -ForegroundColor DarkGray
        return $true
    }

    # ShouldProcess declined (WhatIf / Confirm-No) -- not an error
    return $false
}

# ---- Main ----
function Main {
    Write-Banner -Subtitle 'Uninstaller'

    # Require explicit action flag
    if (-not $Tools -and -not $Unregister -and -not $Purge) {
        Write-Host '  [ERROR] No action specified.' -ForegroundColor Red
        Write-Host ''
        Write-Host '  Available modes:' -ForegroundColor Yellow
        Write-Host '    uninstall.cmd --tools                Remove tools (preserves distro)' -ForegroundColor White
        Write-Host '    uninstall.cmd --unregister           Destroy distro (DATA LOSS)' -ForegroundColor White
        Write-Host '    uninstall.cmd --purge                Destroy distro + uninstall WSL' -ForegroundColor White
        Write-Host ''
        Write-Host '  Run "uninstall.cmd --help" for details.' -ForegroundColor Yellow
        Write-Host ''
        exit 1
    }

    # -Purge implies -Unregister
    if ($Purge) { $Unregister = $true }

    # -Force suppresses ShouldProcess (Confirm)
    if ($Force) { $ConfirmPreference = 'None' }

    # Determine level
    $level = 'tools'
    if ($Unregister) { $level = 'unregister' }
    if ($Purge)      { $level = 'purge' }

    Write-Host "  Mode: $level | Distro: $Distro" -ForegroundColor White
    Write-Host ''

    # Track what was actually executed
    $didCleanSoft    = $false
    $didUnregister   = $false
    $didUninstallWsl = $false
    $didDefender     = $false
    $didWslConfig    = $false
    $didPath         = $false

    # 1. Check Admin (only required for -Unregister / -Purge)
    if ($Unregister -or $Purge) {
        if (-not (Test-Admin)) {
            Write-Host ''
            Write-Host '  [ERROR] This operation requires Administrator privileges.' -ForegroundColor Red
            Write-Host ''
            Write-Host '  Open the terminal as Admin and run again:' -ForegroundColor Yellow
            Write-Host "    uninstall.cmd --unregister --force" -ForegroundColor White
            Write-Host ''
            exit 1
        }
    }

    # 2. Check WSL
    if (-not (Test-WslInstalled)) {
        Write-Warn 'WSL is not installed. Nothing to remove.'
        return
    }

    # 3. Soft -- clean-soft inside WSL (only makes sense if distro will survive)
    $distroExists = Test-DistroInstalled -Name $Distro
    if ($Unregister) {
        Write-Step "Skipping clean-soft (distro will be destroyed)"
    }
    elseif ($distroExists) {
        Write-Step "Removing tools inside WSL ($Distro)"
        $didCleanSoft = Invoke-CleanSoft -Distro $Distro -ScriptRoot $PSScriptRoot -Cmdlet $PSCmdlet
    }
    else {
        Write-Warn "Distro '$Distro' not found. Skipping clean-soft."
    }

    # 4. Remove .wslconfig
    $wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
    if ($KeepWslConfig) {
        Write-Step '.wslconfig preserved (-KeepWslConfig)'
    }
    elseif (-not (Test-Path $wslConfigPath)) {
        Write-Step '.wslconfig does not exist -- nothing to remove'
    }
    else {
        Write-Step "Removing $wslConfigPath"
        if ($PSCmdlet.ShouldProcess($wslConfigPath, 'Remove .wslconfig')) {
            try {
                Remove-Item -Path $wslConfigPath -Force -ErrorAction Stop
                Write-Ok '.wslconfig removed'
                $didWslConfig = $true
            }
            catch {
                Write-Warn "Failed to remove .wslconfig: $_"
            }
        }
    }

    # 5. Unregister distro
    if ($Unregister -and $distroExists) {
        $result = Invoke-DistroUnregister -Distro $Distro -ForceConfirm ([bool]$Force) -Cmdlet $PSCmdlet
        if ($null -eq $result) { return }       # user cancelled
        if ($result) { $didUnregister = $true } # false = WhatIf/Confirm-No (error exits inside function)
    }
    elseif ($Unregister -and -not $distroExists) {
        Write-Warn "Distro '$Distro' not found -- already destroyed or never installed."
    }

    # 6. Purge -- uninstall WSL
    if ($Purge) {
        # Remove wsl-vpnkit distro before uninstalling WSL platform
        $vpnkitExists = wsl.exe -l -q 2>$null | ForEach-Object { $_ -replace '\0','' } |
                        Where-Object { $_.Trim() -eq 'wsl-vpnkit' }
        if ($vpnkitExists) {
            Write-Step 'Removing wsl-vpnkit distro'
            if ($PSCmdlet.ShouldProcess('wsl-vpnkit', 'wsl --unregister')) {
                wsl.exe --unregister wsl-vpnkit 2>$null
                Write-Ok 'wsl-vpnkit distro removed'
            }
        }

        Write-Step 'Uninstalling WSL from Windows'
        if ($PSCmdlet.ShouldProcess('WSL', 'wsl --uninstall')) {
            wsl.exe --uninstall
            if ($LASTEXITCODE -ne 0) {
                Write-Error 'Failed to uninstall WSL.'
                exit 1
            }
            Write-Ok 'WSL platform removed'
            $didUninstallWsl = $true
        }
    }

    # 7. Remove from user PATH (only on --unregister / --purge -- tools-only preserves dropwsl)
    if ($Unregister) {
        $repoDir = $PSScriptRoot
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $pathParts = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = $repoDir.TrimEnd('\')
        if ($repoDirNorm -in $pathParts) {
            $newPath = ($pathParts | Where-Object { $_ -ne $repoDirNorm }) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-Ok "Removed from user PATH: $repoDir"
            $didPath = $true
        }
        else {
            Write-Step 'User PATH already clean (repo dir not found)'
        }
    }
    else {
        Write-Step 'Preserving user PATH (tools-only mode)'
    }

    # 8. Remove Defender Exclusions (only if any managed exclusions exist)
    if (Test-Admin) {
        try {
            $currentProcs = (Get-MpPreference).ExclusionProcess
            $hasExclusions = $false
            foreach ($proc in $script:DefenderManagedProcesses) {
                if ($currentProcs -and $proc -in $currentProcs) { $hasExclusions = $true; break }
            }
        }
        catch { $hasExclusions = $false }

        if ($hasExclusions) {
            Write-Step 'Removing Windows Defender exclusions'
            if ($PSCmdlet.ShouldProcess('Windows Defender', 'Remove process exclusions')) {
                Remove-DefenderExclusions
                Write-Ok 'Windows Defender exclusions removed'
                $didDefender = $true
            }
        }
        else {
            Write-Step 'Windows Defender exclusions already clean'
        }
    }
    else {
        Write-Step 'Defender exclusions skipped (requires Admin)'
    }

    # Summary -- based on what was ACTUALLY executed
    Write-Host ''

    $anyAction = $didCleanSoft -or $didUnregister -or $didUninstallWsl -or $didDefender -or $didWslConfig -or $didPath

    if ($didUninstallWsl) {
        Write-Host '  Removal complete' -ForegroundColor Green
        Write-Host ''
        Write-Host '  What was removed:' -ForegroundColor White
        Write-Host "    - Distro '$Distro' (all data)" -ForegroundColor White
        Write-Host '    - Linux kernel and WSL2 platform' -ForegroundColor White
        Write-Host ''
        Write-Host '  To reinstall from scratch: install.cmd (as Admin)' -ForegroundColor White
    }
    elseif ($didUnregister) {
        Write-Host '  Removal complete' -ForegroundColor Green
        Write-Host ''
        Write-Host "  Distro '$Distro' destroyed (all data). WSL platform preserved." -ForegroundColor White
        Write-Host '  To reinstall: install.cmd' -ForegroundColor White
    }
    elseif ($didCleanSoft) {
        Write-Host '  Removal complete' -ForegroundColor Green
        Write-Host ''
        Write-Host '  dropwsl tools removed. Distro and WSL preserved.' -ForegroundColor White
        Write-Host '  To reinstall: install.cmd' -ForegroundColor White
    }
    elseif ($anyAction) {
        Write-Host '  Cleanup complete' -ForegroundColor Green
    }
    else {
        Write-Host '  No actions performed.' -ForegroundColor Yellow
    }
    Write-Host ''
}

Main
