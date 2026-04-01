# tests/pester/cmd-fastpath.Tests.ps1 -- Tests for dropwsl.cmd fast-path
# Requires Pester 5.x
#
# NOTE: these tests MUST be run from a native Windows path
# (e.g. powershell.exe -ExecutionPolicy Bypass -File tests\run-pester.ps1).
# When run via WSL interop (powershell.exe called from bash), the CWD
# is a UNC path (\\wsl.localhost\...) that cmd.exe does not support, causing
# --version and --help tests to fail. This is a cmd.exe limitation,
# not a bug in the code under test.

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $script:CmdFile = Join-Path $script:RepoRoot 'dropwsl.cmd'
    $script:VersionFile = Join-Path $script:RepoRoot 'VERSION'
}

Describe 'dropwsl.cmd --version' {
    It 'returns version from VERSION file' {
        $expectedVersion = (Get-Content $script:VersionFile -Raw).Trim()
        $output = & cmd.exe /c "`"$($script:CmdFile)`" --version" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match "v$([regex]::Escape($expectedVersion))"
    }

    It 'accepts -v as alias' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" -v" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match 'dropwsl v'
    }

    It 'accepts version without --' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" version" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join ''
        $outputStr.Trim() | Should -Match 'dropwsl v'
    }
}

Describe 'dropwsl.cmd --help' {
    It 'shows usage' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Uso|Usage'
    }

    It 'accepts -h as alias' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" -h" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Uso|Usage'
    }

    It 'shows help when called with no arguments' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`"" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Uso|Usage'
    }

    It 'accepts -? as alias' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" -?" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Uso|Usage'
    }
}

Describe 'VERSION file format' {
    It 'contains a single line in semver format' {
        $content = @(Get-Content $script:VersionFile)
        $content.Count | Should -Be 1
        $content[0].Trim() | Should -Match '^\d+\.\d+\.\d+'
    }

    It 'does not contain embedded CRLF in version string' {
        $raw = Get-Content $script:VersionFile -Raw
        # May have trailing \r\n (CRLF), but no \r inside the version itself
        $version = $raw.Trim()
        $version | Should -Not -Match '\r'
    }
}

Describe 'dropwsl.cmd install delegation' {
    It 'delegates install to install.cmd (shows Installer help)' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" install --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Installer'
        $outputStr | Should -Match 'install\.cmd'
    }

    It 'delegates --install to install.cmd' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" --install --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Installer'
    }
}

Describe 'dropwsl.cmd uninstall delegation' {
    It 'delegates uninstall to uninstall.cmd (shows Uninstaller help)' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" uninstall --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Uninstaller'
        $outputStr | Should -Match '--tools'
    }

    It 'delegates --uninstall to uninstall.cmd' {
        $output = & cmd.exe /c "`"$($script:CmdFile)`" --uninstall --help" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Uninstaller'
    }
}

Describe 'DROPWSL_DIR resilience across CWD' {
    It 'help works when called from a different directory' {
        $output = & cmd.exe /c "pushd %TEMP% && `"$($script:CmdFile)`" --help && popd" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'Usage'
    }

    It 'version works when called from a different directory' {
        $output = & cmd.exe /c "pushd %TEMP% && `"$($script:CmdFile)`" --version && popd" 2>&1
        $outputStr = ($output | Where-Object { $_ -is [string] }) -join "`n"
        $outputStr | Should -Match 'dropwsl v'
    }
}

Describe '.cmd file line endings (CRLF)' {
    It 'all .cmd files must have CRLF line endings' {
        $cmdFiles = Get-ChildItem $script:RepoRoot -Filter '*.cmd' -Recurse
        $cmdFiles.Count | Should -BeGreaterThan 0
        foreach ($file in $cmdFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $lfOnly = 0
            for ($i = 0; $i -lt $bytes.Length; $i++) {
                if ($bytes[$i] -eq 0x0A -and ($i -eq 0 -or $bytes[$i - 1] -ne 0x0D)) {
                    $lfOnly++
                }
            }
            $lfOnly | Should -Be 0 -Because "$($file.Name) must have CRLF, not LF (cmd.exe requires CRLF)"
        }
    }
}

Describe '.cmd file encoding (ASCII-only)' {
    It 'all .cmd files must contain only ASCII characters' {
        $cmdFiles = Get-ChildItem $script:RepoRoot -Filter '*.cmd' -Recurse
        $cmdFiles.Count | Should -BeGreaterThan 0
        foreach ($file in $cmdFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $nonAscii = @()
            for ($i = 0; $i -lt $bytes.Length; $i++) {
                if ($bytes[$i] -gt 127) {
                    $nonAscii += $i
                }
            }
            $nonAscii.Count | Should -Be 0 -Because "$($file.Name) must be ASCII-only (cmd.exe reads ANSI, not UTF-8)"
        }
    }
}
