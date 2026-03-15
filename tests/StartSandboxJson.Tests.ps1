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
            '-RemoveTools', 'pestudio'
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
        $result.Json.command.mode | Should Be 'DryRun'
        $result.Json.overall_status | Should Be 'FAIL'
        $result.Json.error.summary | Should Match '-AddTools contains unknown tool id'
    }
}
