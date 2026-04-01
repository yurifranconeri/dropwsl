# tests/pester/uninstall.Tests.ps1 -- Unit tests for uninstall.ps1 (non-destructive)
# Requires Pester 5.x

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $script:UninstallScript = Join-Path $script:RepoRoot 'uninstall.ps1'
    $script:UninstallCmd = Join-Path $script:RepoRoot 'uninstall.cmd'
    $script:VersionFile = Join-Path $script:RepoRoot 'VERSION'

    # Source helpers (Write-Step, Write-Warn, Write-Ok, etc.)
    Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
    . (Join-Path $script:RepoRoot 'lib\wsl-helpers.ps1')
}

Describe 'uninstall.ps1 syntax and parsing' {
    It 'parses without errors' {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $script:UninstallScript -Raw), [ref]$errors
        )
        $errors | Should -BeNullOrEmpty
    }

    It 'has valid comment-based help' {
        # Get-Help cannot parse comment-based help when #Requires precedes it (PS 5.1 bug).
        # Validate by checking raw content for the required markers.
        $content = Get-Content $script:UninstallScript -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.PARAMETER'
        $content | Should -Match '\.EXAMPLE'
    }

    It 'documents all parameters' {
        $content = Get-Content $script:UninstallScript -Raw
        $content | Should -Match '\.PARAMETER\s+Distro'
        $content | Should -Match '\.PARAMETER\s+Tools'
        $content | Should -Match '\.PARAMETER\s+Unregister'
        $content | Should -Match '\.PARAMETER\s+Purge'
        $content | Should -Match '\.PARAMETER\s+KeepWslConfig'
        $content | Should -Match '\.PARAMETER\s+Force'
    }

    It 'contains no non-ASCII in Write-Host/Write-Error/Write-Warning calls' {
        $content = Get-Content $script:UninstallScript -Raw
        $matches = [regex]::Matches($content, '(?m)Write-(Host|Error|Warning|Warn|Ok|Step)\s+.*[^\x00-\x7F]')
        $matches.Count | Should -Be 0 -Because 'output strings must be ASCII-only (PS 5.1 compat)'
    }
}

Describe 'Invoke-CleanSoft function' {
    BeforeAll {
        # Extract functions from the script without executing Main
        $content = Get-Content $script:UninstallScript -Raw
        # Grab everything between "# ---- Steps" and "# ---- Main"
        $fnBlock = [regex]::Match($content, '(?s)(# ---- Steps.*?)# ---- Main').Groups[1].Value
        Invoke-Expression $fnBlock
    }

    It 'is defined' {
        Get-Command Invoke-CleanSoft -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'has required parameters' {
        $params = (Get-Command Invoke-CleanSoft).Parameters
        $params.Keys | Should -Contain 'Distro'
        $params.Keys | Should -Contain 'ScriptRoot'
        $params.Keys | Should -Contain 'Cmdlet'
    }
}

Describe 'Invoke-CleanSoft behavior' {
    BeforeAll {
        $content = Get-Content $script:UninstallScript -Raw
        $fnBlock = [regex]::Match($content, '(?s)(# ---- Steps.*?)# ---- Main').Groups[1].Value

        # Create a mock PSCmdlet that always approves ShouldProcess
        $script:MockCmdlet = [PSCustomObject]@{}
        $script:MockCmdlet | Add-Member -MemberType ScriptMethod -Name 'ShouldProcess' -Value { return $true }

        # Relax PSCmdlet type to [object] so PSCustomObject mock can be passed
        $fnBlock = $fnBlock -replace '\[System\.Management\.Automation\.PSCmdlet\]', '[object]'

        # Store original function block for per-test modifications
        $script:OriginalFnBlock = $fnBlock
    }

    It 'returns $false when wslpath returns empty' {
        $fn = $script:OriginalFnBlock
        # Mock wsl.exe calls: wslpath returns empty, ConvertTo-UnixLineEndings is no-op
        $fn = $fn -replace 'wsl\.exe -d \$Distro -- wslpath -u "\$winPath" 2>\$null', "''"
        $fn = $fn -replace 'ConvertTo-UnixLineEndings[^\r\n]+', '# no-op'
        $fn = $fn -replace 'wsl\.exe -d \$Distro -- bash -c \$cmd', '# no-op'
        Invoke-Expression $fn

        $result = Invoke-CleanSoft -Distro 'TestDistro' -ScriptRoot $TestDrive -Cmdlet $script:MockCmdlet
        $result | Should -Be $false
    }

    It 'returns $false when dropwsl.sh exits non-zero' {
        $fn = $script:OriginalFnBlock
        # wslpath returns a valid path
        $fn = $fn -replace 'wsl\.exe -d \$Distro -- wslpath -u "\$winPath" 2>\$null', "'/mnt/c/test'"
        $fn = $fn -replace 'ConvertTo-UnixLineEndings[^\r\n]+', '# no-op'
        # bash -c fails (simulate exit 1)
        $fn = $fn -replace 'wsl\.exe -d \$Distro -- bash -c \$cmd', 'cmd.exe /c "exit 1"'
        Invoke-Expression $fn

        $result = Invoke-CleanSoft -Distro 'TestDistro' -ScriptRoot $TestDrive -Cmdlet $script:MockCmdlet
        $result | Should -Be $false
    }

    It 'returns $true when dropwsl.sh exits zero' {
        $fn = $script:OriginalFnBlock
        $fn = $fn -replace 'wsl\.exe -d \$Distro -- wslpath -u "\$winPath" 2>\$null', "'/mnt/c/test'"
        $fn = $fn -replace 'ConvertTo-UnixLineEndings[^\r\n]+', '# no-op'
        $fn = $fn -replace 'wsl\.exe -d \$Distro -- bash -c \$cmd', 'cmd.exe /c "exit 0"'
        Invoke-Expression $fn

        $result = Invoke-CleanSoft -Distro 'TestDistro' -ScriptRoot $TestDrive -Cmdlet $script:MockCmdlet
        $result | Should -Be $true
    }

    It 'returns $false without calling wsl when ShouldProcess declines' {
        $fn = $script:OriginalFnBlock
        # Replace wsl.exe with something that would fail loudly if called
        $fn = $fn -replace 'wsl\.exe', 'Write-Error "wsl.exe should not be called"'
        Invoke-Expression $fn

        $noCmdlet = [PSCustomObject]@{}
        $noCmdlet | Add-Member -MemberType ScriptMethod -Name 'ShouldProcess' -Value { return $false }

        $result = Invoke-CleanSoft -Distro 'TestDistro' -ScriptRoot $TestDrive -Cmdlet $noCmdlet
        $result | Should -Be $false
    }
}

Describe 'Invoke-DistroUnregister function' {
    BeforeAll {
        $content = Get-Content $script:UninstallScript -Raw
        $fnBlock = [regex]::Match($content, '(?s)(# ---- Steps.*?)# ---- Main').Groups[1].Value
        Invoke-Expression $fnBlock
    }

    It 'is defined' {
        Get-Command Invoke-DistroUnregister -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'has required parameters' {
        $params = (Get-Command Invoke-DistroUnregister).Parameters
        $params.Keys | Should -Contain 'Distro'
        $params.Keys | Should -Contain 'ForceConfirm'
        $params.Keys | Should -Contain 'Cmdlet'
    }
}

Describe 'Invoke-DistroUnregister wsl-vpnkit note' {
    It 'outputs wsl-vpnkit preservation note after unregister' {
        $content = Get-Content $script:UninstallScript -Raw
        # The note must appear inside Invoke-DistroUnregister after the unregister call
        $fnBody = [regex]::Match($content, '(?s)function Invoke-DistroUnregister\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match 'wsl-vpnkit distro preserved'
        $fnBody | Should -Match 'wsl --unregister wsl-vpnkit'
    }
}

Describe 'Purge wsl-vpnkit distro removal (step 6)' {
    It 'purge section checks for wsl-vpnkit distro before wsl --uninstall' {
        $content = Get-Content $script:UninstallScript -Raw
        # The wsl-vpnkit unregister block must appear BEFORE wsl --uninstall
        $purgeSection = [regex]::Match($content, '(?s)# 6\. Purge.*?# 7\.').Groups[0].Value
        $vpnkitPos = $purgeSection.IndexOf('wsl-vpnkit')
        $uninstallPos = $purgeSection.IndexOf('wsl --uninstall')
        $vpnkitPos | Should -BeLessThan $uninstallPos -Because 'wsl-vpnkit must be removed before wsl --uninstall'
    }

    It 'purge uses ShouldProcess for wsl-vpnkit unregister' {
        $content = Get-Content $script:UninstallScript -Raw
        $purgeSection = [regex]::Match($content, '(?s)# 6\. Purge.*?# 7\.').Groups[0].Value
        $purgeSection | Should -Match "ShouldProcess\('wsl-vpnkit'"
    }

    It 'purge filters wsl.exe -l -q output to detect wsl-vpnkit' {
        $content = Get-Content $script:UninstallScript -Raw
        $purgeSection = [regex]::Match($content, '(?s)# 6\. Purge.*?# 7\.').Groups[0].Value
        # Must strip null bytes and trim
        $purgeSection | Should -Match "replace '\\0'"
        $purgeSection | Should -Match "Trim\(\)"
        $purgeSection | Should -Match "'wsl-vpnkit'"
    }

    It 'purge does not attempt wsl-vpnkit unregister when distro not found' {
        # Verify the conditional: only unregister if $vpnkitExists is truthy
        $content = Get-Content $script:UninstallScript -Raw
        $purgeSection = [regex]::Match($content, '(?s)# 6\. Purge.*?# 7\.').Groups[0].Value
        $purgeSection | Should -Match 'if \(\$vpnkitExists\)'
    }
}

Describe 'PATH cleanup logic (step 7)' {
    It 'removes repo dir from PATH-like string' {
        $repoDir = 'C:\Users\test\dropwsl'
        $originalPath = "C:\Windows;$repoDir;C:\Tools"
        $pathParts = $originalPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = $repoDir.TrimEnd('\')
        $newPath = ($pathParts | Where-Object { $_ -ne $repoDirNorm }) -join ';'
        $newPath | Should -Be 'C:\Windows;C:\Tools'
    }

    It 'is idempotent when dir not in PATH' {
        $originalPath = 'C:\Windows;C:\Tools'
        $pathParts = $originalPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = 'C:\Users\test\dropwsl'
        $newPath = ($pathParts | Where-Object { $_ -ne $repoDirNorm }) -join ';'
        $newPath | Should -Be $originalPath
    }

    It 'handles trailing backslash' {
        $repoDir = 'C:\Users\test\dropwsl\'
        $originalPath = "C:\Windows;C:\Users\test\dropwsl;C:\Tools"
        $pathParts = $originalPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = $repoDir.TrimEnd('\')
        $newPath = ($pathParts | Where-Object { $_ -ne $repoDirNorm }) -join ';'
        $newPath | Should -Be 'C:\Windows;C:\Tools'
    }

    It 'is gated behind $Unregister (tools-only preserves PATH)' {
        $content = Get-Content (Join-Path $script:RepoRoot 'uninstall.ps1') -Raw
        # Step 7 should be inside an "if ($Unregister)" block
        $content | Should -Match '(?s)# 7\. Remove from user PATH.*?if \(\$Unregister\)'
    }
}

Describe 'Single-quote escape for bash paths' {
    It 'escapes apostrophe in wslPath using close-backslash-open pattern' {
        $path = "/mnt/c/Users/O'Brien/Source"
        $safe = $path -replace "'", "'\''";
        # Result should be: /mnt/c/Users/O'\''Brien/Source
        $safe | Should -Be "/mnt/c/Users/O'\''Brien/Source"
        # When wrapped in single quotes, bash sees: cd '/mnt/c/Users/O'\''Brien/Source'
        # which is: '/mnt/c/Users/O' + \' + 'Brien/Source' -- valid bash
    }

    It 'leaves paths without apostrophe unchanged' {
        $path = '/mnt/c/Users/Normal/Source'
        $safe = $path -replace "'", "'\''";
        $safe | Should -Be $path
    }
}

Describe 'Summary branch coverage' {
    BeforeAll {
        $content = Get-Content $script:UninstallScript -Raw
        # Extract the summary section as a scriptblock for testing
        $summaryBlock = [regex]::Match($content,
            '(?s)(# Summary -- based on what was ACTUALLY executed.*?)(?=\r?\n\})').Groups[1].Value
        # Wrap in a testable function
        $script:SummaryFn = @"
function Test-Summary {
    param(
        [bool]`$didCleanSoft    = `$false,
        [bool]`$didUnregister   = `$false,
        [bool]`$didUninstallWsl = `$false,
        [bool]`$didDefender     = `$false,
        [bool]`$didWslConfig    = `$false,
        [bool]`$didPath         = `$false,
        [string]`$Distro        = 'Ubuntu-24.04'
    )
    $summaryBlock
}
"@
        Invoke-Expression $script:SummaryFn
    }

    It 'shows purge message when didUninstallWsl is true' {
        $output = Test-Summary -didUninstallWsl $true 6>&1 | Out-String
        $output | Should -Match 'Removal complete'
        $output | Should -Match 'WSL2 platform'
    }

    It 'shows unregister message when didUnregister is true' {
        $output = Test-Summary -didUnregister $true 6>&1 | Out-String
        $output | Should -Match 'destroyed'
    }

    It 'shows soft message when didCleanSoft is true' {
        $output = Test-Summary -didCleanSoft $true 6>&1 | Out-String
        $output | Should -Match 'tools removed'
    }

    It 'shows cleanup complete for wslconfig-only' {
        $output = Test-Summary -didWslConfig $true 6>&1 | Out-String
        $output | Should -Match 'Cleanup complete'
    }

    It 'shows cleanup complete for path-only' {
        $output = Test-Summary -didPath $true 6>&1 | Out-String
        $output | Should -Match 'Cleanup complete'
    }

    It 'shows cleanup complete for defender-only' {
        $output = Test-Summary -didDefender $true 6>&1 | Out-String
        $output | Should -Match 'Cleanup complete'
    }

    It 'shows no actions when nothing was done' {
        $output = Test-Summary 6>&1 | Out-String
        $output | Should -Match 'No actions performed'
    }
}

Describe '.wslconfig guard clauses (step 4)' {
    It 'detects existing .wslconfig' {
        $tmpFile = Join-Path $TestDrive '.wslconfig'
        '[wsl2]' | Set-Content $tmpFile
        Test-Path $tmpFile | Should -Be $true
    }

    It 'detects missing .wslconfig' {
        $missing = Join-Path $TestDrive '.wslconfig-nonexistent'
        Test-Path $missing | Should -Be $false
    }
}

Describe 'Tools parameter exists' {
    It 'has [switch]$Tools in param block' {
        $content = Get-Content $script:UninstallScript -Raw
        $content | Should -Match '\[switch\]\$Tools'
    }
}

Describe 'No-action guard clause' {
    It 'Main checks for -Tools/-Unregister/-Purge before proceeding' {
        $content = Get-Content $script:UninstallScript -Raw
        $mainBody = [regex]::Match($content, '(?s)function Main\s*\{(.+?)\n\}').Groups[1].Value
        $mainBody | Should -Match 'not \$Tools.*-and.*not \$Unregister.*-and.*not \$Purge'
    }

    It 'shows error message when no action specified' {
        $content = Get-Content $script:UninstallScript -Raw
        $mainBody = [regex]::Match($content, '(?s)function Main\s*\{(.+?)\n\}').Groups[1].Value
        $mainBody | Should -Match 'No action specified'
    }
}

Describe 'uninstall.cmd no-args shows help' {
    It 'shows help when called with no arguments' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`"" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
        $outputStr | Should -Match '--tools'
    }
}

Describe 'uninstall.cmd --help shows --tools' {
    It 'help text includes --tools mode' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match '--tools'
        $outputStr | Should -Match '-Tools'
    }
}

Describe 'uninstall.cmd --version fast-path' {
    It 'returns version from VERSION file' {
        $expectedVersion = (Get-Content $script:VersionFile -Raw).Trim()
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" --version" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match "v$([regex]::Escape($expectedVersion))"
    }

    It 'accepts -v as alias' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" -v" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match 'dropwsl v'
    }
}

Describe 'uninstall.cmd --help fast-path' {
    It 'shows usage with modes' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
        $outputStr | Should -Match 'Unregister'
        $outputStr | Should -Match 'Purge'
    }

    It 'accepts -h as alias' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" -h" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
    }

    It 'accepts -? as alias' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" -?" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
    }

    It 'shows both --flag and -Flag syntax' {
        $output = & cmd.exe /c "`"$($script:UninstallCmd)`" --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match '--tools'
        $outputStr | Should -Match '-Tools'
        $outputStr | Should -Match '--unregister'
        $outputStr | Should -Match '-Unregister'
        $outputStr | Should -Match '--force'
        $outputStr | Should -Match '-Force'
    }
}
