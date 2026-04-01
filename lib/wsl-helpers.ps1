# lib/wsl-helpers.ps1 -- Shared helpers across PowerShell scripts.
# Dot-source this file: . "$PSScriptRoot\lib\wsl-helpers.ps1"
if (Test-Path variable:script:_WSL_HELPERS_LOADED) { return }
$script:_WSL_HELPERS_LOADED = $true

# ---- Constants ----
# Default distro: read from config.yaml (distro.default), fallback to Ubuntu-24.04
$script:DefaultDistro = 'Ubuntu-24.04'
$_configPath = Join-Path $PSScriptRoot '..\config.yaml'
if (Test-Path $_configPath) {
    $_inDistro = $false
    foreach ($_line in Get-Content $_configPath) {
        if ($_line -match '^distro\s*:') { $_inDistro = $true; continue }
        if ($_inDistro -and $_line -match '^\S') { break }
        if ($_inDistro -and $_line -match '^\s+default\s*:\s*"?([^"#]+)"?') {
            $script:DefaultDistro = $Matches[1].Trim().Trim("'")
            break
        }
    }
}
Remove-Variable -Name '_configPath','_line','_inDistro' -ErrorAction SilentlyContinue

# ---- Logging ----
function Write-Step  { param([string]$Msg); Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Warn  { param([string]$Msg); Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Ok    { param([string]$Msg); Write-Host "[OK]   $Msg" -ForegroundColor Green }

# ---- Banner ----
function Write-Banner {
    param([string]$Subtitle)
    $ver = Get-DropwslVersion
    Write-Host ''
    Write-Host '       _                             _' -ForegroundColor Cyan
    Write-Host '    __| |_ __ ___  _ ____      __ __| |' -ForegroundColor Cyan
    Write-Host '   / _` | ''__/ _ \| ''_ \ \ /\ / / __| |' -ForegroundColor Cyan
    Write-Host '  | (_| | | | (_) | |_) \ V  V /\__ \ |___' -ForegroundColor Cyan
    Write-Host '   \__,_|_|  \___/| .__/ \_/\_/ |___/_____|' -ForegroundColor Cyan
    Write-Host '                  |_|' -ForegroundColor Cyan
    Write-Host ''
    if ($Subtitle) {
        Write-Host "  dropwsl v${ver} -- $Subtitle" -ForegroundColor Green
        Write-Host ('  ' + ('=' * (20 + $Subtitle.Length))) -ForegroundColor Green
    } else {
        Write-Host "  dropwsl v${ver}" -ForegroundColor Green
    }
    Write-Host ''
}

# ---- Version ----
function Get-DropwslVersion {
    $versionFile = Join-Path $PSScriptRoot '..\VERSION'
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -First 1).Trim()
    }
    return '0.0.0'
}

# Reads indented lines under a root section of a simple YAML.
# Returns array of strings (without the header line).
function Get-YamlSection {
    param([string]$FilePath, [string]$SectionName)
    if (-not (Test-Path $FilePath)) { return @() }
    $result = @()
    $inSection = $false
    $escapedName = [regex]::Escape($SectionName)
    foreach ($line in Get-Content $FilePath) {
        if ($line -match "^\s*${escapedName}\s*:") { $inSection = $true; continue }
        if ($inSection -and $line -match '^\S') { break }
        if ($inSection) { $result += $line }
    }
    return $result
}

# Converts a Windows path to a WSL path via wslpath.
# Returns $null if conversion fails (e.g. WSL not running).
# wslpath may emit warnings before the path; extracts only the last non-empty line.
function ConvertTo-WslPath {
    param([string]$DistrName, [string]$WindowsPath, [string]$User = '')
    $winFwd = $WindowsPath -replace '\\', '/'
    $wslArgs = @('-d', $DistrName)
    if ($User) { $wslArgs += '-u', $User }
    $wslArgs += '--', 'wslpath', '-u', $winFwd
    $raw = & wsl.exe @wslArgs 2>$null
    $result = ($raw -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    if ($result) { return $result.Trim() }
    return $null
}

function ConvertTo-UnixLineEndings {
    param([string]$DistrName, [string]$WslPath, [string]$User = '')
    $cmd = "find '$WslPath' -path '*/.git' -prune -o -path '*/.old' -prune -o -type f \( -name '*.sh' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.toml' -o -name '*.cfg' -o -name '*.txt' -o -name '*.md' -o -name '*.py' -o -name 'Dockerfile' -o -name '.dockerignore' -o -name '.gitignore' -o -name '.gitattributes' -o -name '.editorconfig' -o -name '.env' -o -name '.env.*' -o -name 'VERSION' \) -exec grep -rl $'\r' {} + 2>/dev/null | xargs -r sed -i 's/\r$//'"
    if ($User) { wsl.exe -d $DistrName -u $User -- bash -c $cmd 2>$null }
    else       { wsl.exe -d $DistrName -- bash -c $cmd 2>$null }
}

function Test-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WslInstalled {
    try {
        $null = Get-Command wsl.exe -ErrorAction Stop
        # wsl --status does not exist in older Win10 builds -- fallback to wsl --list
        $null = wsl.exe --status 2>$null
        if ($LASTEXITCODE -eq 0) { return $true }
        # Fallback: if --status failed, try --list (works on all versions)
        $null = wsl.exe --list --quiet 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch { return $false }
}

function Test-DistroInstalled {
    param([string]$Name)
    # wsl --list may return UTF-16LE with BOM on certain Windows builds.
    # Remove null bytes, BOM (U+FEFF) and non-ASCII for safe comparison.
    $bom = [char]0xFEFF
    $list = wsl.exe --list --quiet 2>$null |
        ForEach-Object { ($_ -replace '\0','' -replace $bom,'' -replace '[^\x20-\x7E]','').Trim() } |
        Where-Object { $_ -ne '' }
    return ($list -contains $Name)
}

function Get-UserConfig {
    param([string]$ConfigFile)
    $config = @{ CreatePasswordless = $true; SudoNopasswd = $true }

    if (Test-Path $ConfigFile) {
        foreach ($line in Get-YamlSection -FilePath $ConfigFile -SectionName 'user') {
            if ($line -match 'create_passwordless\s*:\s*(true|false)') {
                $config.CreatePasswordless = ($Matches[1] -eq 'true')
            }
            if ($line -match 'sudo_nopasswd\s*:\s*(true|false)') {
                $config.SudoNopasswd = ($Matches[1] -eq 'true')
            }
        }
    }

    # If DROPWSL_PASSWORD is defined, implies create_passwordless=false
    if ($env:DROPWSL_PASSWORD) {
        $config.CreatePasswordless = $false
    }

    return $config
}

# Resolves "auto" values for .wslconfig resource keys using machine specs.
# processors auto = total_cores - 1 (min 2)
# memory     auto = 50% RAM, rounded to GB (min 4GB, max 16GB)
# Other keys: "auto" is not supported — returns the value as-is.
function Resolve-WslResourceValue {
    param([string]$Key, [string]$Value)
    if ($Value -ne 'auto') { return $Value }

    switch ($Key) {
        'processors' {
            $cores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
            # Reserve at least 2 cores for Windows (or 25% on large machines)
            $reserved = [Math]::Max(2, [Math]::Floor($cores * 0.25))
            $result = [Math]::Max(2, $cores - $reserved)
            return [string]$result
        }
        'memory' {
            $totalBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
            $totalGB = [Math]::Round($totalBytes / 1GB, 0)
            $halfGB = [Math]::Floor($totalGB / 2)
            $clamped = [Math]::Max(4, [Math]::Min(16, $halfGB))
            return "${clamped}GB"
        }
        default { return $Value }
    }
}

function Sync-WslConfig {
    param([string]$ConfigFile, [string]$WslConfigPath)
    # Defaults match config.yaml wslconfig section
    $networkingMode = 'mirrored'; $dnsTunneling = 'false'; $autoProxy = 'true'
    $processors = 'auto'; $memory = 'auto'; $swap = '2GB'
    if (Test-Path $ConfigFile) {
        foreach ($line in Get-YamlSection -FilePath $ConfigFile -SectionName 'wslconfig') {
            if ($line -match '^\s+networkingMode\s*:\s*"?([^"#]+)"?') { $networkingMode = $Matches[1].Trim() }
            if ($line -match '^\s+dnsTunneling\s*:\s*"?([^"#]+)"?') { $dnsTunneling = $Matches[1].Trim() }
            if ($line -match '^\s+autoProxy\s*:\s*"?([^"#]+)"?') { $autoProxy = $Matches[1].Trim() }
            if ($line -match '^\s+processors\s*:\s*"?([^"#]+)"?') { $processors = $Matches[1].Trim() }
            if ($line -match '^\s+memory\s*:\s*"?([^"#]+)"?') { $memory = $Matches[1].Trim() }
            if ($line -match '^\s+swap\s*:\s*"?([^"#]+)"?') { $swap = $Matches[1].Trim() }
        }
    }

    # Resolve "auto" for resource keys (detects machine specs)
    $processors = Resolve-WslResourceValue -Key 'processors' -Value $processors
    $memory = Resolve-WslResourceValue -Key 'memory' -Value $memory

    # Keys managed by dropwsl (ordered for deterministic output)
    $managedKeys = [ordered]@{
        'networkingMode' = $networkingMode
        'dnsTunneling'   = $dnsTunneling
        'autoProxy'      = $autoProxy
        'processors'     = $processors
        'memory'         = $memory
        'swap'           = $swap
    }

    # If the file already exists, merge preserving user keys
    if (Test-Path $WslConfigPath) {
        $lines = [System.IO.File]::ReadAllLines($WslConfigPath)
        $inWsl2 = $false
        $wsl2Found = $false
        $changed = $false
        $remaining = [ordered]@{} + $managedKeys  # keys that still need to be written
        $result = [System.Collections.Generic.List[string]]::new()

        foreach ($l in $lines) {
            if ($l -match '^\[wsl2\]') {
                $inWsl2 = $true; $wsl2Found = $true
                $result.Add($l)
                continue
            }
            if ($l -match '^\[') { # another section
                # Before leaving [wsl2], insert missing keys
                if ($inWsl2) {
                    foreach ($k in @($remaining.Keys)) {
                        $result.Add("$k=$($remaining[$k])")
                        $changed = $true
                    }
                    $remaining.Clear()
                }
                $inWsl2 = $false
                $result.Add($l)
                continue
            }
            if ($inWsl2 -and $l -match '^(\w+)\s*=') {
                $key = $Matches[1]
                if ($managedKeys.Contains($key)) {
                    $expected = "$key=$($managedKeys[$key])"
                    if ($l.Trim() -ne $expected) { $changed = $true }
                    $result.Add($expected)
                    $remaining.Remove($key)
                    continue
                }
            }
            $result.Add($l)
        }
        # If [wsl2] was the last section, insert remaining keys
        if ($inWsl2 -and $remaining.Count -gt 0) {
            foreach ($k in @($remaining.Keys)) {
                $result.Add("$k=$($remaining[$k])")
                $changed = $true
            }
            $remaining.Clear()
        }
        # If [wsl2] was not found, create the entire section
        if (-not $wsl2Found) {
            $result.Add('[wsl2]')
            foreach ($k in $managedKeys.Keys) {
                $result.Add("$k=$($managedKeys[$k])")
            }
            $changed = $true
        }

        if ($changed) {
            [System.IO.File]::WriteAllLines($WslConfigPath, $result.ToArray())
            return $true
        }
        return $false
    }

    # File does not exist -- create from scratch (UTF-8 without BOM)
    $lines = @('[wsl2]')
    foreach ($k in $managedKeys.Keys) {
        $lines += "$k=$($managedKeys[$k])"
    }
    [System.IO.File]::WriteAllText($WslConfigPath, ($lines -join [Environment]::NewLine) + [Environment]::NewLine)
    return $true
}

# Processes managed by dropwsl Defender exclusions (install adds, uninstall removes).
# Current processes + legacy ones that older versions may have added.
$script:DefenderManagedProcesses = @('vmmem', 'wsl.exe', 'wslhost.exe', 'docker.exe', 'node.exe', 'python.exe', 'dotnet.exe')

function Sync-DefenderExclusions {
    param([string]$ConfigFile)

    # Reads toggle from config.yaml
    $enabled = $true
    if (Test-Path $ConfigFile) {
        foreach ($line in Get-YamlSection -FilePath $ConfigFile -SectionName 'windows') {
            if ($line -match 'defender_exclusions\s*:\s*(true|false)') {
                $enabled = ($Matches[1] -eq 'true')
            }
        }
    }

    if (-not $enabled) { return $false }

    # Only WSL processes -- the performance gain comes from excluding vmmem I/O.
    # Does NOT exclude paths (VHD, \\wsl$, \\wsl.localhost) -- that would be equivalent to
    # disabling Defender for all WSL content.
    $processes = @('vmmem', 'wsl.exe', 'wslhost.exe')
    $changed = $false

    # Process exclusions
    try {
        $currentProcs = (Get-MpPreference).ExclusionProcess
        foreach ($proc in $processes) {
            if (-not $currentProcs -or $proc -notin $currentProcs) {
                Add-MpPreference -ExclusionProcess $proc
                $changed = $true
            }
        }
    }
    catch {
        Write-Warn "Failed to add Defender process exclusion: $_"
    }

    return $changed
}

function Remove-DefenderExclusions {
    # Cleans up all path exclusions added by previous versions
    $legacyPaths = @('\\wsl.localhost', '\\wsl$', (Join-Path $env:USERPROFILE 'projects'))
    foreach ($root in @((Join-Path $env:LOCALAPPDATA 'Packages'), (Join-Path $env:LOCALAPPDATA 'wsl'))) {
        if (Test-Path $root) {
            $vhdDirs = Get-ChildItem -Path $root -Recurse -Filter 'ext4.vhdx' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty DirectoryName
            foreach ($d in $vhdDirs) { $legacyPaths += $d }
        }
    }

    try {
        $currentPaths = (Get-MpPreference).ExclusionPath
        foreach ($path in $legacyPaths) {
            if ($currentPaths -and $path -in $currentPaths) {
                Remove-MpPreference -ExclusionPath $path
            }
        }
    }
    catch { Write-Warn "Failed to remove Defender path exclusions: $_" }

    # Remove current + legacy processes
    $processes = $script:DefenderManagedProcesses

    try {
        $currentProcs = (Get-MpPreference).ExclusionProcess
        foreach ($proc in $processes) {
            if ($currentProcs -and $proc -in $currentProcs) {
                Remove-MpPreference -ExclusionProcess $proc
            }
        }
    }
    catch { Write-Warn "Failed to remove Defender process exclusions: $_" }
}
