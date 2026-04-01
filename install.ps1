#Requires -Version 5.1
<#
.SYNOPSIS
    dropwsl -- Windows installer.
    Installs WSL + distro (if needed), configures .wslconfig and runs
    dropwsl.sh inside WSL.

.DESCRIPTION
    This script must be run on Windows (PowerShell as Administrator).
    1. Enables WSL if not installed.
    2. Installs the distro if not registered.
    3. Creates/updates %USERPROFILE%\.wslconfig with enterprise settings.
    4. Provisions a Linux user and runs dropwsl.sh inside the distro.

.PARAMETER Distro
    WSL distro name. Default: Ubuntu-24.04

.PARAMETER SkipWslConfig
    Skips .wslconfig creation/update.

.PARAMETER DropwslArgs
    Extra arguments passed to dropwsl.sh (e.g. --validate, --scaffold python).

.EXAMPLE
    # Full installation (Administrator)
    .\install.cmd

.EXAMPLE
    # Validate only
    .\install.cmd -DropwslArgs '--validate'

.EXAMPLE
    # Install with Debian
    .\install.cmd -Distro Debian
#>
[CmdletBinding()]
param(
    [string]$Distro = '',
    [switch]$SkipWslConfig,
    [string]$DropwslArgs = ''
)

Set-StrictMode -Version Latest

# ---- Helpers ----
. "$PSScriptRoot\lib\wsl-helpers.ps1"
if (-not $Distro) { $Distro = $script:DefaultDistro }

# ---- Provision Linux user ----

# Converts a SecureString to plain text, zeroing the BSTR after.
function ConvertFrom-SecurePassword {
    param([SecureString]$Secure)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# Sets the password for a Linux user. Three mutually exclusive paths:
#   1. Passwordless (default) — passwd -d
#   2. Env var DROPWSL_PASSWORD — CI/CD automation
#   3. Interactive prompt — 3 attempts, confirm, retry
function Set-LinuxPassword {
    param(
        [string]$DistrName,
        [string]$Username,
        [hashtable]$UserConfig,
        [bool]$PluginNoisy
    )

    # Path 1: passwordless (default config)
    if ($UserConfig.CreatePasswordless) {
        $null = wsl.exe -d $DistrName -u root -- bash -c "passwd -d '$Username' >/dev/null 2>&1" 2>$null
        return
    }

    # Path 2: env var (CI/CD automation, no prompt)
    if ($env:DROPWSL_PASSWORD) {
        $prevEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        "${Username}:$($env:DROPWSL_PASSWORD)" | wsl.exe -d $DistrName -u root -- chpasswd 2>$null
        [Console]::OutputEncoding = $prevEncoding
        if ($LASTEXITCODE -ne 0 -and -not $PluginNoisy) {
            Write-Warn 'Failed to set password via DROPWSL_PASSWORD'
        }
        return
    }

    # Path 3: interactive prompt (3 attempts)
    Write-Host ''
    Write-Host "  Set the password for Linux user '$Username':" -ForegroundColor Yellow
    $passwordSet = $false
    foreach ($i in 1..3) {
        $passPlain = ConvertFrom-SecurePassword (Read-Host '  Password' -AsSecureString)
        $confirmPlain = ConvertFrom-SecurePassword (Read-Host '  Confirm password' -AsSecureString)

        if ($passPlain -ne $confirmPlain) {
            Write-Warn 'Passwords do not match. Try again.'
            $passPlain = $null; $confirmPlain = $null
            continue
        }
        if ([string]::IsNullOrWhiteSpace($passPlain)) {
            Write-Warn 'Password cannot be empty. Try again.'
            $passPlain = $null; $confirmPlain = $null
            continue
        }

        "${Username}:${passPlain}" | wsl.exe -d $DistrName -u root -- chpasswd 2>$null | Out-Null
        $passPlain = $null; $confirmPlain = $null

        if ($LASTEXITCODE -eq 0 -or $PluginNoisy) {
            $passwordSet = $true
            break
        }
        Write-Warn 'Failed to set password. Try again.'
    }

    if (-not $passwordSet) {
        Write-Warn "Could not set password after 3 attempts -- user created without password"
        $null = wsl.exe -d $DistrName -u root -- bash -c "passwd -d '$Username' >/dev/null 2>&1" 2>$null
    }
}

# Writes a sudoers.d file for the user (NOPASSWD or password-required).
function Set-LinuxSudoers {
    param(
        [string]$DistrName,
        [string]$Username,
        [bool]$NoPassword
    )
    $line = if ($NoPassword) { "$Username ALL=(ALL) NOPASSWD:ALL" } else { "$Username ALL=(ALL:ALL) ALL" }
    $cmd = "echo '$line' > /etc/sudoers.d/'$Username' && chmod 0440 /etc/sudoers.d/'$Username' && test -f /etc/sudoers.d/'$Username' && echo SUDOERS_OK"
    $out = (wsl.exe -d $DistrName -u root -- bash -c "$cmd" 2>$null) -join ''
    if ($out -notmatch 'SUDOERS_OK') {
        Write-Warn "Failed to configure sudoers for '$Username'"
    }
}

# Sets the default user in /etc/wsl.conf and restarts the distro.
function Set-WslDefaultUser {
    param(
        [string]$DistrName,
        [string]$Username
    )

    # Already configured — skip
    $checkOut = (wsl.exe -d $DistrName -u root -- bash -c "grep -q 'default=$Username' /etc/wsl.conf 2>/dev/null && echo ALREADY_OK" 2>$null) -join ''
    if ($checkOut -match 'ALREADY_OK') { return }

    # Update or create [user] section
    $updateCmd = @(
        "if grep -q '^\[user\]' /etc/wsl.conf 2>/dev/null; then",
        "  if grep -q '^default=' /etc/wsl.conf 2>/dev/null; then",
        "    sed -i '/^\[user\]/,/^\[/{s/^default=.*/default=$Username/}' /etc/wsl.conf;",
        "  else",
        "    sed -i '/^\[user\]/a default=$Username' /etc/wsl.conf;",
        "  fi;",
        "else",
        "  printf '\n[user]\ndefault=$Username\n' >> /etc/wsl.conf;",
        "fi;",
        "grep -q 'default=$Username' /etc/wsl.conf 2>/dev/null && echo WSLCONF_OK"
    ) -join ' '
    $confOut = (wsl.exe -d $DistrName -u root -- bash -c "$updateCmd" 2>$null) -join ''
    if ($confOut -notmatch 'WSLCONF_OK') {
        Write-Warn 'Failed to configure default user in /etc/wsl.conf'
    }

    # Restart distro so default user takes effect
    $null = wsl.exe --terminate $DistrName 2>$null
    $waited = 0
    while ($waited -lt 10) {
        Start-Sleep -Seconds 1
        $waited++
        $probe = (wsl.exe -d $DistrName -- bash -c "echo ALIVE" 2>$null) -join ''
        if ($probe -match 'ALIVE') { break }
    }
}

# Orchestrator: creates user, sets password, sudoers, wsl.conf default.
# Returns @{ Username = '...'; PluginNoisy = $true/$false }
function New-LinuxUser {
    param(
        [string]$DistrName,
        [string]$ConfigFile
    )

    Write-Step 'Checking Linux user in distro'
    $linuxUser = $env:USERNAME.ToLower() -replace '[^a-z0-9_-]', ''
    if ([string]::IsNullOrWhiteSpace($linuxUser)) { $linuxUser = 'devuser' }
    if ($linuxUser.StartsWith('-')) { $linuxUser = "_$linuxUser" }
    if ($linuxUser -match '^\d') { $linuxUser = "_$linuxUser" }

    $userCheck = wsl.exe -d $DistrName -u root -- bash -c "id -u '$linuxUser' 2>/dev/null && echo EXISTS || echo MISSING" 2>&1
    $userExists = "$userCheck".Trim() -match 'EXISTS'

    # WSL plugins (e.g. Defender for Endpoint) can corrupt exit codes
    $pluginNoisy = ("$userCheck" -match 'DefenderforEndpointPlug-in|Plugin.*E_UNEXPECTED')
    if ($pluginNoisy) {
        Write-Warn 'Microsoft Defender for Endpoint WSL plugin reporting errors -- exit codes may be inaccurate. Verifying operations individually.'
    }

    $userConfig = Get-UserConfig -ConfigFile $ConfigFile

    if (-not $userExists) {
        Write-Step "Creating user '$linuxUser' in distro"
        $null = wsl.exe -d $DistrName -u root -- bash -c "useradd -m -s /bin/bash -G sudo,adm '$linuxUser' 2>/dev/null" 2>$null
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 9) {
            $recheck = (wsl.exe -d $DistrName -u root -- bash -c "id -u '$linuxUser' 2>/dev/null && echo EXISTS" 2>$null) -join ''
            if ($recheck -notmatch 'EXISTS') {
                Write-Warn "Failed to create user '$linuxUser' (useradd exit code: $LASTEXITCODE). Provisioning may fail."
            }
        }

        Set-LinuxPassword -DistrName $DistrName -Username $linuxUser -UserConfig $userConfig -PluginNoisy $pluginNoisy

        $sudoLabel = if ($userConfig.SudoNopasswd) { 'sudo passwordless' } else { 'sudo with password' }
        Write-Ok "User '$linuxUser' created with $sudoLabel"
    } else {
        Write-Step "User '$linuxUser' already exists"
    }

    # Sudoers + wsl.conf — always run (ensures config matches even for existing user)
    Set-LinuxSudoers -DistrName $DistrName -Username $linuxUser -NoPassword $userConfig.SudoNopasswd
    Set-WslDefaultUser -DistrName $DistrName -Username $linuxUser

    return @{ Username = $linuxUser; PluginNoisy = $pluginNoisy }
}

# ---- Main ----
function Main {
    Write-Banner -Subtitle 'Installer'

    # 1. Check Admin
    if (-not (Test-Admin)) {
        Write-Error 'This script requires Administrator privileges. Right-click PowerShell > Run as Administrator.'
        exit 1
    }

    # 2. Install WSL if needed
    Write-Step 'Checking WSL platform...'
    if (-not (Test-WslInstalled)) {
        Write-Step 'Installing WSL (wsl --install --no-distribution)'
        wsl.exe --install --no-distribution
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'Failed to install WSL. Check if virtualization is enabled in BIOS.'
            exit 1
        }
        Write-Host ''
        Write-Host '  Restart the computer and run again: install.cmd' -ForegroundColor Yellow
        Write-Host ''
        return
    }
    Write-Step 'WSL platform already installed'

    # 3. Install distro if needed
    if (-not (Test-DistroInstalled -Name $Distro)) {
        Write-Step "Installing distro '$Distro'"
        wsl.exe --install -d $Distro --no-launch
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install distro '$Distro'."
            exit 1
        }
        Write-Step "Distro '$Distro' installed"
    }
    else {
        Write-Step "Distro '$Distro' already registered"
    }

    # Config file shared by steps below
    $configFile = Join-Path $PSScriptRoot 'config.yaml'

    # 4. Configure .wslconfig (enterprise settings + resource limits)
    if (-not $SkipWslConfig) {
        $wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
        Write-Step "Configuring $wslConfigPath (enterprise settings + resource limits)"

        $changed = Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath
        if ($changed) {
            Write-Step '.wslconfig updated'
            # .wslconfig changes only take effect after the WSL VM stops completely.
            # --shutdown kills the lightweight VM; --terminate only kills one distro.
            Write-Step 'Shutting down WSL VM to apply .wslconfig changes'
            wsl.exe --shutdown 2>$null
            Start-Sleep -Seconds 2
        } else {
            Write-Step '.wslconfig already up to date'
        }
    }

    # 4b. Windows Defender exclusions (WSL processes)
    Write-Step 'Configuring Windows Defender exclusions'
    $defenderChanged = Sync-DefenderExclusions -ConfigFile $configFile
    if ($defenderChanged) {
        Write-Ok 'Windows Defender exclusions applied (WSL processes: vmmem, wsl.exe, wslhost.exe)'
    } else {
        Write-Step 'Windows Defender exclusions already configured'
    }

    # 4c. Provision Linux user (same username as Windows)
    $userResult = New-LinuxUser -DistrName $Distro -ConfigFile $configFile
    $linuxUser = $userResult.Username
    $wslPluginNoisy = $userResult.PluginNoisy

    # 5. Run dropwsl.sh inside WSL
    Write-Step 'Running dropwsl.sh inside WSL'

    # Convert Windows path to WSL path (uses the provisioned user)
    $wslPath = ConvertTo-WslPath -DistrName $Distro -WindowsPath $PSScriptRoot -User $linuxUser
    if (-not $wslPath) {
        Write-Error 'Failed to resolve WSL path.'
        exit 1
    }

    # Convert CRLF to LF in all repo text files (Windows mount has Windows line endings)
    ConvertTo-UnixLineEndings -DistrName $Distro -WslPath $wslPath -User $linuxUser

    # Escape args for bash (prevents command injection)
    $safeArgs = ''
    if ($DropwslArgs) {
        $safeArgs = ($DropwslArgs -split '\s+' | ForEach-Object {
            $escaped = $_ -replace "'", "'\''"  # escape single-quotes
            "'$escaped'"
        }) -join ' '
    }
    # Escape single quotes for bash (e.g. usernames like O'Brien)
    $wslPathSafe = $wslPath -replace "'", "'\''" 
    # Invoke via 'bash dropwsl.sh' -- chmod does not work on DrvFs (/mnt/c/...)
    # Redirect stderr to stdout (2>&1) inside bash so that die()/warn() output
    # is not swallowed by PS 5.1's SilentlyContinue (which eats ALL native stderr).
    if (-not $safeArgs) { $safeArgs = 'install' }
    $dropwslCmd = "cd '$wslPathSafe' && DROPWSL_BATCH=1 bash dropwsl.sh $safeArgs"
    # Force UTF-8 to decode WSL output (bash emits UTF-8, PS 5.1 uses console code page)
    $prevEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    # SilentlyContinue: WSL stderr (Defender plugin warnings) should not generate
    # NativeCommandError, but legitimate bash errors pass through to the console.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    wsl.exe -d $Distro -u $linuxUser -- bash -c $dropwslCmd
    $dropwslExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    [Console]::OutputEncoding = $prevEncoding
    Write-Host ''  # ensure newline after WSL output

    if ($dropwslExit -ne 0) {
        if ($wslPluginNoisy) {
            Write-Warn "dropwsl.sh returned exit code $dropwslExit (may be corrupted by Defender plugin)"
        } else {
            Write-Error "dropwsl.sh failed (exit code: $dropwslExit)."
            exit 1
        }
    }

    # 6. Add to user PATH (allows running dropwsl from any terminal)
    $repoDir = $PSScriptRoot
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathParts = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
    $repoDirNorm = $repoDir.TrimEnd('\')
    if ($repoDirNorm -notin $pathParts) {
        $newPath = if ([string]::IsNullOrEmpty($userPath)) { $repoDir } else { "$userPath;$repoDir" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Ok "Added to user PATH: $repoDir"
        Write-Warn 'Open a new terminal to use dropwsl globally'
    } else {
        Write-Step 'User PATH already contains the repo directory'
    }

    Write-Host ''
    Write-Step 'Installation complete'
    Write-Host ''
    Write-Host '  Next steps:' -ForegroundColor Green
    Write-Host '    1. Reopen WSL (for the docker group to take effect)' -ForegroundColor White
    Write-Host '    2. Test: docker run hello-world' -ForegroundColor White
    Write-Host '    3. Create a project: dropwsl new my-svc python' -ForegroundColor White
    Write-Host ''
    Write-Host '  Proxy (from any terminal):' -ForegroundColor Green
    Write-Host '    dropwsl validate' -ForegroundColor White
    Write-Host '    dropwsl new my-svc python --with src,fastapi' -ForegroundColor White
    Write-Host '    dropwsl --help' -ForegroundColor White
    Write-Host ''
}

Main
