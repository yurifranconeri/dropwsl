# tests/pester/install.Tests.ps1 -- Unit tests for install.ps1 (non-destructive)
# Requires Pester 5.x

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $script:InstallScript = Join-Path $script:RepoRoot 'install.ps1'
    $script:InstallCmd = Join-Path $script:RepoRoot 'install.cmd'
    $script:VersionFile = Join-Path $script:RepoRoot 'VERSION'

    # Source helpers (Write-Step, Write-Warn, Write-Ok, Get-UserConfig, etc.)
    Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
    . (Join-Path $script:RepoRoot 'lib\wsl-helpers.ps1')

    # Extract functions from install.ps1 without executing Main.
    # Functions live between "# ---- Provision Linux user ----" and "# ---- Main ----"
    $content = Get-Content $script:InstallScript -Raw
    $fnBlock = [regex]::Match($content, '(?s)(# ---- Provision Linux user.*?)# ---- Main').Groups[1].Value
    Invoke-Expression $fnBlock
}

Describe 'install.ps1 syntax and parsing' {
    It 'parses without errors' {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $script:InstallScript -Raw), [ref]$errors
        )
        $errors | Should -BeNullOrEmpty
    }

    It 'has valid comment-based help' {
        # Get-Help cannot parse comment-based help when #Requires precedes it (PS 5.1 bug).
        # Validate by checking raw content for the required markers.
        $content = Get-Content $script:InstallScript -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.PARAMETER'
        $content | Should -Match '\.EXAMPLE'
    }

    It 'documents all parameters' {
        $content = Get-Content $script:InstallScript -Raw
        $content | Should -Match '\.PARAMETER\s+Distro'
        $content | Should -Match '\.PARAMETER\s+SkipWslConfig'
        $content | Should -Match '\.PARAMETER\s+DropwslArgs'
    }

    It 'contains no non-ASCII in Write-Host/Write-Error/Write-Warning calls' {
        $content = Get-Content $script:InstallScript -Raw
        $matches = [regex]::Matches($content, '(?m)Write-(Host|Error|Warning|Warn|Ok|Step)\s+.*[^\x00-\x7F]')
        $matches.Count | Should -Be 0 -Because 'output strings must be ASCII-only (PS 5.1 compat)'
    }
}

Describe 'ConvertFrom-SecurePassword function' {
    It 'is defined' {
        Get-Command ConvertFrom-SecurePassword -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'round-trips a known plain text' {
        $plain = 'Test@Pass!123'
        $secure = ConvertTo-SecureString $plain -AsPlainText -Force
        $result = ConvertFrom-SecurePassword -Secure $secure
        $result | Should -Be $plain
    }

    It 'handles empty SecureString (user presses Enter with no input)' {
        $secure = New-Object SecureString
        $result = ConvertFrom-SecurePassword -Secure $secure
        $result | Should -Be ''
    }
}

Describe 'Set-LinuxPassword function' {
    It 'is defined with required parameters' {
        $cmd = Get-Command Set-LinuxPassword -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain 'DistrName'
        $cmd.Parameters.Keys | Should -Contain 'Username'
        $cmd.Parameters.Keys | Should -Contain 'UserConfig'
        $cmd.Parameters.Keys | Should -Contain 'PluginNoisy'
    }
}

Describe 'Set-LinuxSudoers function' {
    It 'is defined with required parameters' {
        $cmd = Get-Command Set-LinuxSudoers -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain 'DistrName'
        $cmd.Parameters.Keys | Should -Contain 'Username'
        $cmd.Parameters.Keys | Should -Contain 'NoPassword'
    }
}

Describe 'Set-WslDefaultUser function' {
    It 'is defined with required parameters' {
        $cmd = Get-Command Set-WslDefaultUser -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain 'DistrName'
        $cmd.Parameters.Keys | Should -Contain 'Username'
    }
}

Describe 'New-LinuxUser function' {
    It 'is defined with required parameters' {
        $cmd = Get-Command New-LinuxUser -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.Parameters.Keys | Should -Contain 'DistrName'
        $cmd.Parameters.Keys | Should -Contain 'ConfigFile'
    }
}

Describe 'Username sanitization logic' {
    # Replicates the sanitization logic from New-LinuxUser to test edge cases
    # without requiring wsl.exe.
    BeforeAll {
        function Test-SanitizeUsername {
            param([string]$WindowsName)
            $linuxUser = $WindowsName.ToLower() -replace '[^a-z0-9_-]', ''
            if ([string]::IsNullOrWhiteSpace($linuxUser)) { $linuxUser = 'devuser' }
            if ($linuxUser.StartsWith('-')) { $linuxUser = "_$linuxUser" }
            if ($linuxUser -match '^\d') { $linuxUser = "_$linuxUser" }
            return $linuxUser
        }
    }

    It 'lowercases and strips special characters' {
        Test-SanitizeUsername 'John.Doe' | Should -Be 'johndoe'
    }

    It 'strips spaces' {
        Test-SanitizeUsername 'Ana Maria' | Should -Be 'anamaria'
    }

    It 'strips accented and unicode characters' {
        # PS 5.1 does not support \u escape; use [char] cast
        $name = "Jos$([char]0xE9) Silva"
        Test-SanitizeUsername $name | Should -Be 'jossilva'
    }

    It 'prefixes underscore when starting with digit' {
        Test-SanitizeUsername '1admin' | Should -Be '_1admin'
    }

    It 'prefixes underscore when starting with dash' {
        Test-SanitizeUsername '-user' | Should -Be '_-user'
    }

    It 'falls back to devuser when all chars are stripped' {
        Test-SanitizeUsername '!!@@##' | Should -Be 'devuser'
    }

    It 'falls back to devuser for empty string' {
        Test-SanitizeUsername '' | Should -Be 'devuser'
    }

    It 'preserves underscores and hyphens' {
        Test-SanitizeUsername 'my_user-name' | Should -Be 'my_user-name'
    }

    It 'handles typical Windows domain user' {
        # domain\user scenario -- backslash is stripped
        Test-SanitizeUsername 'CORP\jdoe' | Should -Be 'corpjdoe'
    }
}

Describe 'PATH add logic (step 6)' {
    It 'adds repo dir to PATH when not present' {
        $repoDir = 'C:\Users\test\dropwsl'
        $userPath = 'C:\Windows;C:\Tools'
        $pathParts = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = $repoDir.TrimEnd('\')
        $present = $repoDirNorm -in $pathParts
        $present | Should -Be $false
    }

    It 'detects repo dir already in PATH' {
        $repoDir = 'C:\Users\test\dropwsl'
        $userPath = "C:\Windows;$repoDir;C:\Tools"
        $pathParts = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = $repoDir.TrimEnd('\')
        $present = $repoDirNorm -in $pathParts
        $present | Should -Be $true
    }

    It 'handles trailing backslash in PATH entry' {
        $repoDir = 'C:\Users\test\dropwsl'
        $userPath = "C:\Windows;C:\Users\test\dropwsl\;C:\Tools"
        $pathParts = $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
        $repoDirNorm = $repoDir.TrimEnd('\')
        $present = $repoDirNorm -in $pathParts
        $present | Should -Be $true
    }
}

Describe 'DropwslArgs escape for bash' {
    # Replicates the escape logic from install.ps1 step 5
    BeforeAll {
        function Test-EscapeArgs {
            param([string]$RawArgs)
            $safeArgs = ''
            if ($RawArgs) {
                $safeArgs = ($RawArgs -split '\s+' | ForEach-Object {
                    $escaped = $_ -replace "'", "'\''"
                    "'$escaped'"
                }) -join ' '
            }
            return $safeArgs
        }
    }

    It 'wraps each arg in single quotes' {
        $result = Test-EscapeArgs '--validate'
        $result | Should -Be "'--validate'"
    }

    It 'wraps multiple args individually' {
        $result = Test-EscapeArgs '--validate --quiet'
        $result | Should -Be "'--validate' '--quiet'"
    }

    It 'escapes single quotes with close-backslash-open pattern' {
        $result = Test-EscapeArgs "it's"
        $result | Should -Be "'it'\''s'"
    }

    It 'returns empty string for empty input' {
        $result = Test-EscapeArgs ''
        $result | Should -Be ''
    }

    It 'handles --with flag with comma-separated values' {
        $result = Test-EscapeArgs '--with src,fastapi,mypy'
        $result | Should -Be "'--with' 'src,fastapi,mypy'"
    }
}

Describe 'install.cmd --version fast-path' {
    It 'returns version from VERSION file' {
        $expectedVersion = (Get-Content $script:VersionFile -Raw).Trim()
        $output = & cmd.exe /c "`"$($script:InstallCmd)`" --version" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match "v$([regex]::Escape($expectedVersion))"
    }

    It 'accepts -v as alias' {
        $output = & cmd.exe /c "`"$($script:InstallCmd)`" -v" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match 'dropwsl v'
    }
}

Describe 'install.cmd --help fast-path' {
    It 'shows usage and steps' {
        $output = & cmd.exe /c "`"$($script:InstallCmd)`" --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
        $outputStr | Should -Match 'Installs WSL'
        $outputStr | Should -Match 'dropwsl\.sh'
    }

    It 'shows options with dual syntax' {
        $output = & cmd.exe /c "`"$($script:InstallCmd)`" --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match '--distro'
        $outputStr | Should -Match '-Distro'
        $outputStr | Should -Match '--skip-wsl-config'
        $outputStr | Should -Match '-SkipWslConfig'
    }

    It 'accepts -h as alias' {
        $output = & cmd.exe /c "`"$($script:InstallCmd)`" -h" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
    }

    It 'accepts -? as alias' {
        $output = & cmd.exe /c "`"$($script:InstallCmd)`" -?" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
    }
}
