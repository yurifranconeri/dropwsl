# tests/pester/wsl-helpers.Tests.ps1 -- Pester tests for lib/wsl-helpers.ps1
# Requires Pester 5.x: Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser

BeforeAll {
    # Dot-source the module (reset guard clause)
    Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
    . "$PSScriptRoot\..\..\lib\wsl-helpers.ps1"
    $script:FixturesDir = Join-Path $PSScriptRoot '..\fixtures'
}

Describe 'Write-Step / Write-Warn / Write-Ok' {
    It 'Write-Step emits output with ==>' {
        $output = Write-Step 'Test message' 6>&1
        $output | Should -Match '==> Test message'
    }

    It 'Write-Warn emits output with [WARN]' {
        $output = Write-Warn 'Warning msg' 6>&1
        $output | Should -Match '\[WARN\]'
    }

    It 'Write-Ok emits output with [OK]' {
        $output = Write-Ok 'Success' 6>&1
        $output | Should -Match '\[OK\]'
    }
}

Describe 'Get-YamlSection' {
    It 'returns lines from the tools section' {
        $file = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        $lines = Get-YamlSection -FilePath $file -SectionName 'core'
        $lines | Should -Not -BeNullOrEmpty
        ($lines -join "`n") | Should -Match 'docker|kubectl|kind'
    }

    It 'returns empty array for nonexistent file' {
        $lines = @(Get-YamlSection -FilePath 'C:\nonexistent\file.yaml' -SectionName 'tools')
        $lines.Count | Should -Be 0
    }

    It 'returns empty array for nonexistent section' {
        $file = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        $lines = @(Get-YamlSection -FilePath $file -SectionName 'nonexistent_section')
        $lines.Count | Should -Be 0
    }

    It 'stops reading when another root section is found' {
        $file = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        $lines = Get-YamlSection -FilePath $file -SectionName 'tools'
        # No line should contain keys from other root sections
        foreach ($line in $lines) {
            $line | Should -Not -Match '^distros\s*:|^vscode\s*:|^git\s*:'
        }
    }
}

Describe 'Test-Admin' {
    It 'returns boolean' {
        $result = Test-Admin
        $result | Should -BeOfType [bool]
    }
}

Describe 'Get-UserConfig' {
    It 'returns defaults when file does not exist' {
        $cfg = Get-UserConfig -ConfigFile 'C:\nonexistent.yaml'
        $cfg.CreatePasswordless | Should -Be $true
        $cfg.SudoNopasswd | Should -Be $true
    }

    It 'reads config from valid file' {
        $tmpFile = Join-Path $TestDrive 'user_config.yaml'
        @"
user:
  create_passwordless: false
  sudo_nopasswd: false
"@ | Set-Content -Path $tmpFile -Encoding UTF8
        $cfg = Get-UserConfig -ConfigFile $tmpFile
        $cfg.CreatePasswordless | Should -Be $false
        $cfg.SudoNopasswd | Should -Be $false
    }

    It 'DROPWSL_PASSWORD overrides create_passwordless' {
        $tmpFile = Join-Path $TestDrive 'user_config2.yaml'
        @"
user:
  create_passwordless: true
"@ | Set-Content -Path $tmpFile -Encoding UTF8
        $env:DROPWSL_PASSWORD = 'test'
        try {
            $cfg = Get-UserConfig -ConfigFile $tmpFile
            $cfg.CreatePasswordless | Should -Be $false
        }
        finally {
            Remove-Item env:DROPWSL_PASSWORD -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Sync-WslConfig' {
    It 'creates .wslconfig when it does not exist' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig'
        $configFile = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        $result = Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath
        $result | Should -Be $true
        Test-Path $wslConfigPath | Should -Be $true
        $content = Get-Content $wslConfigPath -Raw
        $content | Should -Match '\[wsl2\]'
        $content | Should -Match 'networkingMode='
    }

    It 'is idempotent -- returns $false on second call' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig2'
        $configFile = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath | Out-Null
        $result = Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath
        $result | Should -Be $false
    }

    It 'preserves user sections' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig3'
        @"
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
localhostForwarding=true
[interop]
enabled=true
"@ | Set-Content -Path $wslConfigPath -Encoding UTF8
        $configFile = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath | Out-Null
        $content = Get-Content $wslConfigPath -Raw
        $content | Should -Match 'localhostForwarding=true'
        $content | Should -Match '\[interop\]'
    }

    It 'updates existing value without duplicating' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig4'
        @"
[wsl2]
networkingMode=nat
dnsTunneling=false
autoProxy=false
"@ | Set-Content -Path $wslConfigPath -Encoding UTF8
        $configFile = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        $result = Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath
        $result | Should -Be $true
        $content = Get-Content $wslConfigPath -Raw
        $content | Should -Match 'networkingMode=mirrored'
        # Must have only 1 occurrence of each key
        ($content | Select-String -Pattern 'networkingMode' -AllMatches).Matches.Count | Should -Be 1
    }

    It 'includes resource keys (processors, memory, swap) on new file' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig_resources'
        $configFile = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath | Out-Null
        $content = Get-Content $wslConfigPath -Raw
        $content | Should -Match 'processors='
        $content | Should -Match 'memory='
        $content | Should -Match 'swap='
    }

    It 'preserves user resource keys when merging' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig_merge_res'
        @"
[wsl2]
networkingMode=mirrored
dnsTunneling=false
autoProxy=true
processors=4
memory=8GB
swap=1GB
customKey=myvalue
"@ | Set-Content -Path $wslConfigPath -Encoding UTF8
        $configFile = Join-Path $script:FixturesDir 'config_all_enabled.yaml'
        Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath | Out-Null
        $content = Get-Content $wslConfigPath -Raw
        $content | Should -Match 'customKey=myvalue'
    }
}

Describe 'Resolve-WslResourceValue' {
    It 'returns explicit value unchanged for processors' {
        Resolve-WslResourceValue -Key 'processors' -Value '4' | Should -Be '4'
    }

    It 'returns explicit value unchanged for memory' {
        Resolve-WslResourceValue -Key 'memory' -Value '8GB' | Should -Be '8GB'
    }

    It 'resolves auto for processors to at least 2' {
        $result = Resolve-WslResourceValue -Key 'processors' -Value 'auto'
        [int]$result | Should -BeGreaterOrEqual 2
    }

    It 'resolves auto for processors to less than total cores' {
        $totalCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        $result = Resolve-WslResourceValue -Key 'processors' -Value 'auto'
        [int]$result | Should -BeLessOrEqual $totalCores
    }

    It 'resolves auto for processors reserving at least 25% of cores' {
        $totalCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        $result = Resolve-WslResourceValue -Key 'processors' -Value 'auto'
        $maxAllowed = [Math]::Max(2, $totalCores - [Math]::Max(2, [Math]::Floor($totalCores * 0.25)))
        [int]$result | Should -BeLessOrEqual $maxAllowed
        [int]$result | Should -Be $maxAllowed
    }

    It 'resolves auto for memory to value between 4GB and 16GB' {
        $result = Resolve-WslResourceValue -Key 'memory' -Value 'auto'
        $result | Should -Match '^\d+GB$'
        $num = [int]($result -replace 'GB', '')
        $num | Should -BeGreaterOrEqual 4
        $num | Should -BeLessOrEqual 16
    }

    It 'passes through unknown keys with auto unchanged' {
        Resolve-WslResourceValue -Key 'unknownKey' -Value 'auto' | Should -Be 'auto'
    }
}

Describe 'ConvertTo-WslPath' {
    BeforeAll {
        # Mock wsl.exe to simulate wslpath output
        function wsl.exe { $script:MockWslOutput }
    }

    It 'returns trimmed path from wslpath output' {
        $script:MockWslOutput = "/mnt/c/Users/test/Source/project`n"
        $result = ConvertTo-WslPath -DistrName 'Ubuntu' -WindowsPath 'C:\Users\test\Source\project'
        $result | Should -Be '/mnt/c/Users/test/Source/project'
    }

    It 'extracts last non-empty line when wslpath emits warnings' {
        $script:MockWslOutput = @("WARNING: something noisy", "", "/mnt/c/Users/test/project")
        $result = ConvertTo-WslPath -DistrName 'Ubuntu' -WindowsPath 'C:\Users\test\project'
        $result | Should -Be '/mnt/c/Users/test/project'
    }

    It 'returns $null when wslpath returns empty' {
        $script:MockWslOutput = ''
        $result = ConvertTo-WslPath -DistrName 'Ubuntu' -WindowsPath 'C:\bad\path'
        $result | Should -BeNullOrEmpty
    }

    It 'returns $null when wslpath returns only whitespace' {
        $script:MockWslOutput = "   `n   `n"
        $result = ConvertTo-WslPath -DistrName 'Ubuntu' -WindowsPath 'C:\bad\path'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'DefaultDistro from config.yaml' {
    It 'reads distro.default from config_all_enabled fixture' {
        # Re-source with a custom config that has distro.default
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        $origPSScriptRoot = $PSScriptRoot
        # wsl-helpers.ps1 reads ..\\config.yaml relative to its own location
        # The fixture is at tests/fixtures/ but we need it at the parent of lib/
        # So we create a temp config.yaml
        $tmpDir = Join-Path $TestDrive 'distro-test'
        $tmpLib = Join-Path $tmpDir 'lib'
        New-Item -ItemType Directory -Path $tmpLib -Force | Out-Null
        @"
distro:
  default: "Debian-12"
  supported:
    - debian
"@ | Set-Content -Path (Join-Path $tmpDir 'config.yaml') -Encoding UTF8
        # Copy wsl-helpers.ps1 to tmpLib
        Copy-Item "$PSScriptRoot\..\..\lib\wsl-helpers.ps1" $tmpLib
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        . "$tmpLib\wsl-helpers.ps1"
        $script:DefaultDistro | Should -Be 'Debian-12'
        # Re-source the original
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        . "$PSScriptRoot\..\..\lib\wsl-helpers.ps1"
    }

    It 'falls back to Ubuntu-24.04 when config has no distro.default' {
        $tmpDir = Join-Path $TestDrive 'distro-test2'
        $tmpLib = Join-Path $tmpDir 'lib'
        New-Item -ItemType Directory -Path $tmpLib -Force | Out-Null
        @"
distro:
  supported:
    - ubuntu
"@ | Set-Content -Path (Join-Path $tmpDir 'config.yaml') -Encoding UTF8
        Copy-Item "$PSScriptRoot\..\..\lib\wsl-helpers.ps1" $tmpLib
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        . "$tmpLib\wsl-helpers.ps1"
        $script:DefaultDistro | Should -Be 'Ubuntu-24.04'
        # Re-source the original
        Remove-Variable -Name '_WSL_HELPERS_LOADED' -Scope Script -ErrorAction SilentlyContinue
        . "$PSScriptRoot\..\..\lib\wsl-helpers.ps1"
    }
}

Describe 'Sync-WslConfig dnsTunneling default' {
    It 'defaults dnsTunneling to false when config has no wslconfig section' {
        $wslConfigPath = Join-Path $TestDrive '.wslconfig_dns'
        $configFile = Join-Path $TestDrive 'config_no_wsl.yaml'
        @"
distro:
  supported:
    - ubuntu
"@ | Set-Content -Path $configFile -Encoding UTF8
        Sync-WslConfig -ConfigFile $configFile -WslConfigPath $wslConfigPath | Out-Null
        $content = Get-Content $wslConfigPath -Raw
        $content | Should -Match 'dnsTunneling=false'
    }
}
