# tests/pester/dropwsl-proxy.Tests.ps1 -- Pester tests for dropwsl.ps1
# Requires Pester 5.x

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $script:ScriptPath = Join-Path $script:RepoRoot 'dropwsl.ps1'
    $script:FixturesDir = Join-Path $PSScriptRoot '..\fixtures'
}

Describe 'dropwsl.ps1 syntax and parsing' {
    It 'parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'has UTF-8 BOM' {
        $bytes = [System.IO.File]::ReadAllBytes($script:ScriptPath)
        $bytes[0] | Should -Be 0xEF
        $bytes[1] | Should -Be 0xBB
        $bytes[2] | Should -Be 0xBF
    }

    It 'has no non-ASCII characters in Write-Host/Write-Error/Write-Warn/Write-Ok/Write-Step strings' {
        $content = Get-Content $script:ScriptPath -Raw
        $matches = [regex]::Matches($content, "(?i)(Write-Host|Write-Error|Write-Warn|Write-Ok|Write-Step)\s+['""]([^'""]*)['""]")
        foreach ($m in $matches) {
            $str = $m.Groups[2].Value
            foreach ($char in $str.ToCharArray()) {
                [int]$char | Should -BeLessOrEqual 127 -Because "char '$char' (U+$("{0:X4}" -f [int]$char)) in: $($m.Value)"
            }
        }
    }
}

Describe 'Get-ConfigExtensions' {
    BeforeAll {
        # Cannot dot-source dropwsl.ps1 (has Main + param), so extract the function.
        $scriptContent = Get-Content $script:ScriptPath -Raw

        # Source helpers first (Get-YamlSection is used by Get-ConfigExtensions)
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        . (Join-Path $script:RepoRoot 'lib\wsl-helpers.ps1')

        # Extract and define Get-ConfigExtensions + DefaultExtensions
        $fnBlock = [regex]::Match($scriptContent, '(?s)(\$script:DefaultExtensions\s*=\s*@\([^)]+\))').Groups[1].Value
        Invoke-Expression $fnBlock

        # $PSScriptRoot is empty inside Invoke-Expression -- inject repo root via variable
        $script:TestConfigRoot = "$($script:RepoRoot)"
        $fnDef = [regex]::Match($scriptContent, '(?s)(function Get-ConfigExtensions\s*\{.+?\n\})').Groups[1].Value
        $fnDef = $fnDef -replace '\$PSScriptRoot', '$script:TestConfigRoot'
        Invoke-Expression $fnDef
    }

    It 'returns extensions from real config.yaml' {
        $exts = Get-ConfigExtensions
        $exts | Should -Not -BeNullOrEmpty
        $exts | Should -Contain 'ms-vscode-remote.remote-wsl'
    }

    It 'returns fallback extensions including essentials' {
        $exts = Get-ConfigExtensions
        $exts | Should -Contain 'ms-vscode-remote.remote-containers'
    }

    It 'returns fallback when config.yaml has no vscode section' {
        # Re-define Get-ConfigExtensions pointing to fixture without vscode section
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $fnDef = [regex]::Match($scriptContent, '(?s)(function Get-ConfigExtensions\s*\{.+?\n\})').Groups[1].Value
        $fnDef = $fnDef -replace '\$PSScriptRoot', "'$($script:FixturesDir -replace "'","''")'"
        # The fixture dir has config_minimal.yaml but not config.yaml -- function will use fallback
        $script:TestConfigRoot_NoVscode = $script:FixturesDir
        $fnDef2 = [regex]::Match($scriptContent, '(?s)(function Get-ConfigExtensions\s*\{.+?\n\})').Groups[1].Value
        $fnDef2 = $fnDef2 -replace '\$PSScriptRoot', '$script:TestConfigRoot_NoVscode'
        Invoke-Expression $fnDef2
        $exts = Get-ConfigExtensions
        $exts | Should -HaveCount 3
        $exts | Should -Contain 'ms-vscode-remote.remote-wsl'
        # Restore original
        $fnDef3 = [regex]::Match($scriptContent, '(?s)(function Get-ConfigExtensions\s*\{.+?\n\})').Groups[1].Value
        $fnDef3 = $fnDef3 -replace '\$PSScriptRoot', '$script:TestConfigRoot'
        Invoke-Expression $fnDef3
    }
}

Describe 'Normalize-WithArgs' {
    BeforeAll {
        # Extract Normalize-WithArgs from dropwsl.ps1
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $fnDef = [regex]::Match($scriptContent, '(?s)(function Normalize-WithArgs\s*\{.+?\n\})').Groups[1].Value
        Invoke-Expression $fnDef
    }

    It 'joins loose tokens after commas into single value' {
        $result = Normalize-WithArgs -InputArgs @('--new', 'test', 'python', '--with', 'src,', 'mypy,', 'fastapi')
        $result | Should -Contain 'src,mypy,fastapi'
    }

    It 'keeps already-joined --with value unchanged' {
        $result = Normalize-WithArgs -InputArgs @('--new', 'test', 'python', '--with', 'src,mypy,fastapi')
        $result | Should -Contain 'src,mypy,fastapi'
    }

    It 'stops collecting when a flag appears after --with tokens' {
        $result = Normalize-WithArgs -InputArgs @('--with', 'src,', '--quiet')
        $result | Should -Contain 'src'
        $result | Should -Contain '--quiet'
    }

    It 'passes through args when no --with is present' {
        $result = Normalize-WithArgs -InputArgs @('validate', '--quiet')
        $result | Should -HaveCount 2
        $result[0] | Should -Be 'validate'
        $result[1] | Should -Be '--quiet'
    }

    It 'keeps --with in result when it is the last arg without value' {
        $result = Normalize-WithArgs -InputArgs @('new', 'test', 'python', '--with')
        $result | Should -Contain '--with'
        $result | Should -HaveCount 4
    }

    It 'stops collecting on single-dash -y (not treated as layer)' {
        $result = Normalize-WithArgs -InputArgs @('new', 'test', 'python', '--with', 'src', '-y')
        $result | Should -Contain 'src'
        $result | Should -Contain '-y'
        # -y must NOT be joined into the layer value
        $layerEntry = $result | Where-Object { $_ -notmatch '^-' -and $_ -notin @('new','test','python','--with') }
        $layerEntry | Should -Be 'src'
    }

    It 'stops collecting on single-dash -q (not treated as layer)' {
        $result = Normalize-WithArgs -InputArgs @('new', 'test', 'python', '--with', 'fastapi,', 'src', '-q')
        $result | Should -Contain '-q'
        # Layers should be joined as fastapi,src (without -q)
        $layerEntry = $result | Where-Object { $_ -match ',' -or ($_ -notmatch '^-' -and $_ -notin @('new','test','python','--with')) }
        $layerEntry | Should -Not -Contain '-q'
    }
}

Describe 'Invoke-Update uses return not exit (bug #103 regression)' {
    It 'Invoke-Update function body does not contain exit keyword' {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $fnBody = [regex]::Match($scriptContent, '(?s)function Invoke-Update\s*\{(.+?)\n\}').Groups[1].Value
        # exit inside the function body would kill the host PowerShell session
        $fnBody | Should -Not -Match '\bexit\b'
    }
}

Describe 'Invoke-WslCommand pipes output to host (not pipeline)' {
    It 'wsl.exe output is piped through Out-Host to avoid being swallowed by caller assignment' {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $fnBody = [regex]::Match($scriptContent, '(?s)function Invoke-WslCommand\s*\{(.+?)\n\}').Groups[1].Value
        # The wsl.exe call MUST pipe to Out-Host so that output flows directly
        # to the console and is not captured by "$exitCode = Invoke-ProxyForward ...".
        $fnBody | Should -Match 'wsl\.exe .+\|\s*Out-Host'
    }
}

Describe 'Restart-WslIfTransientFailure' {
    BeforeAll {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        # Extract function -- replace wsl.exe and Start-Sleep with no-ops for unit testing
        $fnDef = [regex]::Match($scriptContent, '(?s)(function Restart-WslIfTransientFailure\s*\{.+?\n\})').Groups[1].Value
        $fnDef = $fnDef -replace 'wsl\.exe --shutdown 2>\$null', '# mocked out'
        $fnDef = $fnDef -replace 'Start-Sleep -Seconds 3', '# mocked out'
        # Also remove Write-Warn calls to avoid noise in test output
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        . (Join-Path $script:RepoRoot 'lib\wsl-helpers.ps1')
        Invoke-Expression $fnDef
    }

    It 'returns $true for known transient failure patterns' {
        $patterns = @(
            'WslRegisterDistribution failed with error 0x80070005',
            'Catastrophic failure',
            'Failed to start the WSL service',
            'Process cannot access the file because it is being used',
            'HResult 0x80041002',
            'E_INVALIDARG'
        )
        foreach ($p in $patterns) {
            $result = Restart-WslIfTransientFailure -DistrName 'Test' -Output $p
            $result | Should -Be $true -Because "pattern: $p"
        }
    }

    It 'returns $false for benign output' {
        $result = Restart-WslIfTransientFailure -DistrName 'Test' -Output 'ok'
        $result | Should -Be $false
    }

    It 'returns $false for empty string' {
        $result = Restart-WslIfTransientFailure -DistrName 'Test' -Output ''
        $result | Should -Be $false
    }
}

Describe 'Uninstall flag mapping' {
    BeforeAll {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        # Extract the flag mapping lines from Main function
        $script:FlagMappingCode = $scriptContent
    }

    It 'maps --full and --unregister to Unregister key' {
        $script:FlagMappingCode | Should -Match "--full.*-in.*PassArgs.*-or.*--unregister.*Unregister"
    }

    It 'maps --remove-wsl and --purge to Purge key' {
        $script:FlagMappingCode | Should -Match "--remove-wsl.*-in.*PassArgs.*-or.*--purge.*Purge"
    }

    It 'maps --force to Force key' {
        $script:FlagMappingCode | Should -Match "--force.*Force"
    }

    It 'maps --keep-wslconfig and --keep-wsl-config to KeepWslConfig key' {
        $script:FlagMappingCode | Should -Match "--keep-wslconfig.*-or.*--keep-wsl-config.*KeepWslConfig"
    }

    It 'does not map to obsolete parameter names (Full, RemoveWsl)' {
        # Ensure no mapping to old param names that would silently fail
        $mappingSection = [regex]::Match($script:FlagMappingCode, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
        $mappingSection | Should -Not -Match "uninstallArgs\['Full'\]"
        $mappingSection | Should -Not -Match "uninstallArgs\['RemoveWsl'\]"
    }

    It 'shows help when uninstall explicitly requests help' {
        $mappingSection = [regex]::Match($script:FlagMappingCode, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
            $mappingSection | Should -Match '''--help''\s*-in\s*\$PassArgs\s*-or\s*''-h''\s*-in\s*\$PassArgs'
        $mappingSection | Should -Match 'uninstall\.cmd'
        $mappingSection | Should -Match 'cmd\.exe /c'
        $mappingSection | Should -Match '--help'
    }
}

Describe 'Proxy arg escaping' {
    # Replicates the escape + conditional quoting logic from Main proxy section
    BeforeAll {
        function Test-ProxyEscape {
            param([string[]]$InputArgs)
            $argString = ($InputArgs | ForEach-Object {
                $escaped = $_ -replace "'", "'\''"
                if ($escaped -match '[\s$`!\\;&#|()<>~]') { "'$escaped'" } else { $escaped }
            }) -join ' '
            return $argString
        }
    }

    It 'passes simple flags unchanged' {
        Test-ProxyEscape @('--validate', '--quiet') | Should -Be '--validate --quiet'
    }

    It 'quotes args with spaces' {
        Test-ProxyEscape @('--with', 'hello world') | Should -Be "--with 'hello world'"
    }

    It 'quotes args with special bash chars' {
        Test-ProxyEscape @('arg;rm', 'a&b') | Should -Be "'arg;rm' 'a&b'"
    }

    It 'escapes single quotes within args' {
        $result = Test-ProxyEscape @("it's")
        # The escaped string it'\''s contains \, which matches the special-chars regex,
        # so it gets wrapped in outer quotes: 'it'\''s' — valid bash.
        $result | Should -Be "'it'\''s'"
    }

    It 'escapes and quotes args with both quotes and spaces' {
        $result = Test-ProxyEscape @("it's a test")
        $result | Should -Be "'it'\''s a test'"
    }
}

Describe 'Admin check uses Test-Admin (DRY)' {
    It 'uninstall intercept calls Test-Admin not inline check' {
        $content = Get-Content $script:ScriptPath -Raw
        $section = [regex]::Match($content, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
        $section | Should -Match '\$isAdmin\s*=\s*Test-Admin'
        $section | Should -Not -Match 'WindowsPrincipal.*IsInRole'
    }
}

Describe 'DropwslBinPath constant (DRY)' {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It 'defines $script:DropwslBinPath at module scope' {
        $script:Content | Should -Match '\$script:DropwslBinPath\s*=\s*''~/.local/bin/dropwsl'''
    }

    It 'Invoke-Update uses $script:DropwslBinPath not local $dropwslPath' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Invoke-Update\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match '\$script:DropwslBinPath'
        $fnBody | Should -Not -Match '\$dropwslPath'
    }

    It 'Invoke-ProxyForward uses $script:DropwslBinPath not local $dropwslPath' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Invoke-ProxyForward\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match '\$script:DropwslBinPath'
        $fnBody | Should -Not -Match '\$dropwslPath'
    }

    It 'Main does not define local $dropwslPath' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Main\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Not -Match '\$dropwslPath\s*='
    }
}

Describe 'Invoke-Update dead code removal' {
    It 'Invoke-Update param block does not accept $DropwslPath' {
        $content = Get-Content $script:ScriptPath -Raw
        $fnDef = [regex]::Match($content, '(?s)function Invoke-Update\s*\{[^}]*param\(([^)]*)\)').Groups[1].Value
        $fnDef | Should -Not -Match 'DropwslPath'
    }

    It 'Invoke-Update includes preflight with Restart-WslIfTransientFailure' {
        $content = Get-Content $script:ScriptPath -Raw
        $fnBody = [regex]::Match($content, '(?s)function Invoke-Update\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match 'Restart-WslIfTransientFailure'
        $fnBody | Should -Match 'return 1'
    }
}

Describe 'Invoke-UninstallProxy extraction' {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It 'function exists as standalone' {
        $script:Content | Should -Match 'function Invoke-UninstallProxy\s*\{'
    }

    It 'maps --full/--unregister to Unregister key' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match "--full.*-in.*PassArgs.*-or.*--unregister.*Unregister"
    }

    It 'maps --remove-wsl/--purge to Purge key' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match "--remove-wsl.*-or.*--purge.*Purge"
    }

    It 'checks Admin via Test-Admin' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
        $fnBody | Should -Match '\$isAdmin\s*=\s*Test-Admin'
    }

    It 'does not contain exit on happy path (uses return)' {
        $fnBody = [regex]::Match($script:Content, '(?s)function Invoke-UninstallProxy\s*\{(.+?)\n\}').Groups[1].Value
        # exit is allowed for error paths (missing script, no admin) but the final & call uses return
        $fnBody | Should -Match '& \$uninstallScript @uninstallArgs'
        # The function ends with & not exit
        $lastLine = ($fnBody -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1).Trim()
        $lastLine | Should -Be '& $uninstallScript @uninstallArgs'
    }
}

Describe 'Invoke-ProxyForward extraction' {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
        $script:FnBody = [regex]::Match($script:Content, '(?s)function Invoke-ProxyForward\s*\{(.+?)\n\}').Groups[1].Value
    }

    It 'function exists with DistrName and ArgsToForward params' {
        $script:FnBody | Should -Match '\$DistrName'
        $script:FnBody | Should -Match '\$ArgsToForward'
    }

    It 'calls Normalize-WithArgs' {
        $script:FnBody | Should -Match 'Normalize-WithArgs\s*-InputArgs\s*\$ArgsToForward'
    }

    It 'calls Invoke-WslCommand' {
        $script:FnBody | Should -Match 'Invoke-WslCommand\s*-DistrName\s*\$DistrName'
    }

    It 'forwards generic commands to WSL in batch mode' {
        $script:FnBody | Should -Match 'DROPWSL_BATCH=1'
    }

    It 'calls Restart-WslIfTransientFailure on error path' {
        $script:FnBody | Should -Match 'Restart-WslIfTransientFailure'
    }

    It 'returns exit code (not exit)' {
        $script:FnBody | Should -Match 'return \$wslExitCode'
        # Must NOT contain bare 'exit' in code -- only 'return' for propagation
        # Filter out comments (which may legitimately use the word 'exit')
        $codeOnly = ($script:FnBody -split "`n" | Where-Object { $_.Trim() -notmatch '^\s*#' }) -join "`n"
        $codeOnly | Should -Not -Match '\bexit\b'
    }
}

Describe 'Main is a clean dispatcher' {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
        $script:MainBody = [regex]::Match($script:Content, '(?s)function Main\s*\{(.+?)\n\}').Groups[1].Value
        $script:MainLines = ($script:MainBody -split "`n" | Where-Object { $_.Trim() -and $_.Trim() -notmatch '^\s*#' }).Count
    }

    It 'Main body is under 50 lines of code (excluding comments)' {
        $script:MainLines | Should -BeLessOrEqual 50
    }

    It 'Main delegates to Invoke-UninstallProxy' {
        $script:MainBody | Should -Match 'Invoke-UninstallProxy'
    }

    It 'Main delegates to Invoke-Update' {
        $script:MainBody | Should -Match 'Invoke-Update\s*-DistrName'
    }

    It 'Main delegates to Invoke-ProxyForward' {
        $script:MainBody | Should -Match 'Invoke-ProxyForward\s*-DistrName'
    }

    It 'Main does not contain flag mapping logic (extracted to Invoke-UninstallProxy)' {
        $script:MainBody | Should -Not -Match "uninstallArgs\["
    }

    It 'Main does not contain arg escaping logic (extracted to Invoke-ProxyForward)' {
        $script:MainBody | Should -Not -Match "Normalize-WithArgs"
        $script:MainBody | Should -Not -Match "argString"
    }
}

Describe 'Error messages use styled Write-Host not Write-Error' {
    It 'no Write-Error calls in the script' {
        $content = Get-Content $script:ScriptPath -Raw
        # Write-Error produces ugly PS formatting. All errors should use styled Write-Host.
        $content | Should -Not -Match '\bWrite-Error\b'
    }
}
