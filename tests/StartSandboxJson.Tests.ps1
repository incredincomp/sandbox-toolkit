Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path $repoRoot 'Start-Sandbox.ps1'
$manifestOut = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbOut = Join-Path $repoRoot 'sandbox.wsb'
$customProfilesPath = Join-Path $repoRoot 'custom-profiles.local.json'

function Invoke-StartSandboxJson {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{
        Output = $output
        ExitCode = $exitCode
        Json = ($output | ConvertFrom-Json)
    }
}

function Invoke-StartSandboxRaw {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1 | Out-String
    return [pscustomobject]@{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

Describe 'Start-Sandbox JSON output modes' {
    AfterEach {
        if (Test-Path -LiteralPath $manifestOut -PathType Leaf) {
            Remove-Item -LiteralPath $manifestOut -Force
        }
        if (Test-Path -LiteralPath $wsbOut -PathType Leaf) {
            Remove-Item -LiteralPath $wsbOut -Force
        }
        if (Test-Path -LiteralPath $customProfilesPath -PathType Leaf) {
            Remove-Item -LiteralPath $customProfilesPath -Force
        }
    }

    It 'returns parseable JSON for validate mode with deterministic status' {
        $result = Invoke-StartSandboxJson -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson')

        $result.ExitCode | Should Be 0
        $result.Json.command.mode | Should Be 'validate'
        $result.Json.overall_status | Should Be 'WARN'
        $result.Json.checks.Count | Should BeGreaterThan 0
        (($result.Json.checks | Where-Object { $_.status -eq 'WARN' }).Count) | Should BeGreaterThan 0
    }

    It 'returns validation failure JSON with exit code 1 and actionable check details' {
        $result = Invoke-StartSandboxJson -Arguments @('-Validate', '-OutputJson', '-Profile', 'not-a-profile')

        $result.ExitCode | Should Be 1
        $result.Json.command.mode | Should Be 'validate'
        $result.Json.overall_status | Should Be 'FAIL'
        $result.Json.exit_code | Should Be 1
        (($result.Json.checks | Where-Object { $_.id -eq 'selection' -and $_.status -eq 'FAIL' }).Count) | Should Be 1
        (($result.Json.checks | Where-Object { $_.id -eq 'selection' })[0].remediation) | Should Not BeNullOrEmpty
    }

    It 'returns parseable dry-run JSON with effective final selection and skipped stages' {
        @'
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "net-re-lite",
      "base_profile": "reverse-engineering",
      "add_tools": ["wireshark"],
      "remove_tools": ["ghidra"]
    }
  ]
}
'@ | Set-Content -Path $customProfilesPath -Encoding UTF8

        $result = Invoke-StartSandboxJson -Arguments @(
            '-DryRun',
            '-SkipPrereqCheck',
            '-OutputJson',
            '-Profile', 'net-re-lite',
            '-AddTools', 'floss',
            '-RemoveTools', 'pestudio',
            '-DisableClipboard',
            '-DisableStartupCommands'
        )

        $result.ExitCode | Should Be 0
        $result.Json.command.mode | Should Be 'dry-run'
        $result.Json.profile.selected | Should Be 'net-re-lite'
        $result.Json.profile.resolved_type | Should Be 'custom'
        $result.Json.profile.base_profile | Should Be 'reverse-engineering'
        (($result.Json.overrides.add_tools -contains 'floss')) | Should Be $true
        (($result.Json.overrides.remove_tools -contains 'pestudio')) | Should Be $true
        (($result.Json.effective.tools | Select-Object -ExpandProperty id) -contains 'wireshark') | Should Be $true
        (($result.Json.effective.tools | Select-Object -ExpandProperty id) -contains 'ghidra') | Should Be $false
        (($result.Json.effective.tools | Select-Object -ExpandProperty id) -contains 'pestudio') | Should Be $false
        $result.Json.effective.host_interaction.clipboard_redirection | Should Be 'Disable'
        $result.Json.effective.host_interaction.audio_input | Should Be 'Disable'
        $result.Json.effective.host_interaction.startup_commands_enabled | Should Be $false
        $result.Json.stages.download.skipped | Should Be $true
        $result.Json.stages.launch.skipped | Should Be $true
    }

    It 'surfaces invalid override failures as parseable dry-run JSON error output' {
        $result = Invoke-StartSandboxJson -Arguments @(
            '-DryRun',
            '-SkipPrereqCheck',
            '-OutputJson',
            '-AddTools', 'not-a-real-tool'
        )

        $result.ExitCode | Should Be 1
        $result.Json.command.mode | Should Be 'dry-run'
        $result.Json.overall_status | Should Be 'FAIL'
        $result.Json.error.summary | Should Match "Unknown tool id 'not-a-real-tool' in -AddTools"
    }

    It 'returns parseable JSON for list-tools mode with stable catalog fields' {
        $result = Invoke-StartSandboxJson -Arguments @('-ListTools', '-OutputJson')

        $result.ExitCode | Should Be 0
        $result.Json.command.mode | Should Be 'list-tools'
        $result.Json.tools.Count | Should BeGreaterThan 0
        (($result.Json.tools | Where-Object { $_.id -eq 'ghidra' }).Count) | Should Be 1
        (($result.Json.tools | Where-Object { $_.id -eq 'ghidra' })[0].install_order) | Should Not BeNullOrEmpty
    }

    It 'returns parseable JSON for list-profiles mode with built-in and custom distinctions' {
        @'
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "net-re-lite",
      "base_profile": "reverse-engineering",
      "add_tools": ["wireshark"],
      "remove_tools": ["ghidra"]
    }
  ]
}
'@ | Set-Content -Path $customProfilesPath -Encoding UTF8

        $result = Invoke-StartSandboxJson -Arguments @('-ListProfiles', '-OutputJson')

        $result.ExitCode | Should Be 0
        $result.Json.command.mode | Should Be 'list-profiles'
        (($result.Json.profiles | Where-Object { $_.name -eq 'minimal' -and $_.type -eq 'built-in' }).Count) | Should Be 1
        (($result.Json.profiles | Where-Object { $_.name -eq 'net-re-lite' -and $_.type -eq 'custom' -and $_.base_profile -eq 'reverse-engineering' }).Count) | Should Be 1
    }

    It 'keeps JSON error mode consistent for list-profiles failures' {
        '{ "schema_version": "1.0" }' | Set-Content -Path $customProfilesPath -Encoding UTF8
        $result = Invoke-StartSandboxJson -Arguments @('-ListProfiles', '-OutputJson')

        $result.ExitCode | Should Be 1
        $result.Json.command.mode | Should Be 'list-profiles'
        $result.Json.overall_status | Should Be 'FAIL'
        $result.Json.error.summary | Should Match 'Malformed custom profile config'
    }

    It 'preserves default human-readable list output when -OutputJson is not used' {
        $result = Invoke-StartSandboxRaw -Arguments @('-ListTools')

        $result.ExitCode | Should Be 0
        $result.Output | Should Match 'Available tools:'
        $result.Output | Should Match 'ghidra'
    }

    It 'keeps a stable JSON error envelope for fatal failures in JSON-capable modes' {
        $cases = @(
            [pscustomobject]@{
                Name = 'dry-run'
                Arguments = @('-DryRun', '-SkipPrereqCheck', '-OutputJson', '-AddTools', 'not-a-real-tool')
                Setup = $null
                Teardown = $null
                ExpectedMode = 'dry-run'
            },
            [pscustomobject]@{
                Name = 'audit'
                Arguments = @('-Audit', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')
                Setup = { '{ "schema_version": "1.0" }' | Set-Content -Path $customProfilesPath -Encoding UTF8 }
                Teardown = { if (Test-Path -LiteralPath $customProfilesPath -PathType Leaf) { Remove-Item -LiteralPath $customProfilesPath -Force } }
                ExpectedMode = 'audit'
            },
            [pscustomobject]@{
                Name = 'list-profiles'
                Arguments = @('-ListProfiles', '-OutputJson')
                Setup = { '{ "schema_version": "1.0" }' | Set-Content -Path $customProfilesPath -Encoding UTF8 }
                Teardown = { if (Test-Path -LiteralPath $customProfilesPath -PathType Leaf) { Remove-Item -LiteralPath $customProfilesPath -Force } }
                ExpectedMode = 'list-profiles'
            }
            [pscustomobject]@{
                Name = 'check-for-updates'
                Arguments = @('-CheckForUpdates', '-OutputJson', '-AddTools', 'not-a-real-tool')
                Setup = $null
                Teardown = $null
                ExpectedMode = 'check-for-updates'
            }
        )

        foreach ($case in $cases) {
            try {
                if ($case.Setup) {
                    & $case.Setup
                }

                $result = Invoke-StartSandboxJson -Arguments $case.Arguments
                $result.ExitCode | Should Be 1
                $result.Json.command.mode | Should Be $case.ExpectedMode
                $result.Json.overall_status | Should Be 'FAIL'
                $result.Json.exit_code | Should Be 1
                $result.Json.error | Should Not BeNullOrEmpty
                $result.Json.error.summary | Should Not BeNullOrEmpty
            } finally {
                if ($case.Teardown) {
                    & $case.Teardown
                }
            }
        }
    }
}
