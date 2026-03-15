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
    return [pscustomobject]@{
        Output = $output
        ExitCode = $LASTEXITCODE
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

Describe 'Start-Sandbox integrated command combinations' {
    BeforeAll {
        $script:manifest = Get-Content -Raw -Path (Join-Path $repoRoot 'tools.json') | ConvertFrom-Json
    }

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

    It 'supports -DryRun with a built-in profile' {
        $result = Invoke-StartSandboxJson -Arguments @('-DryRun', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')

        $result.ExitCode | Should Be 0
        $result.Json.command.mode | Should Be 'dry-run'
        $result.Json.profile.selected | Should Be 'minimal'
        $result.Json.profile.resolved_type | Should Be 'built-in'
        (($result.Json.effective.tools | Select-Object -ExpandProperty id) -contains 'notepadpp') | Should Be $true
    }

    It 'applies profile precedence deterministically for custom profile plus runtime overrides' {
        @'
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "precedence-check",
      "base_profile": "minimal",
      "add_tools": ["ghidra"],
      "remove_tools": ["notepadpp"]
    }
  ]
}
'@ | Set-Content -Path $customProfilesPath -Encoding UTF8

        $result = Invoke-StartSandboxJson -Arguments @(
            '-DryRun',
            '-SkipPrereqCheck',
            '-OutputJson',
            '-Profile', 'precedence-check',
            '-AddTools', 'notepadpp',
            '-RemoveTools', 'ghidra'
        )

        $toolIds = @($result.Json.effective.tools | Select-Object -ExpandProperty id)
        $result.ExitCode | Should Be 0
        $result.Json.profile.resolved_type | Should Be 'custom'
        (($toolIds -contains 'notepadpp')) | Should Be $true
        (($toolIds -contains 'ghidra')) | Should Be $false
    }

    It 'supports -DryRun with runtime add/remove overrides on built-in profile' {
        $result = Invoke-StartSandboxJson -Arguments @(
            '-DryRun',
            '-SkipPrereqCheck',
            '-OutputJson',
            '-Profile', 'minimal',
            '-AddTools', 'wireshark',
            '-RemoveTools', 'notepadpp'
        )

        $toolIds = @($result.Json.effective.tools | Select-Object -ExpandProperty id)
        $result.ExitCode | Should Be 0
        (($toolIds -contains 'wireshark')) | Should Be $true
        (($toolIds -contains 'notepadpp')) | Should Be $false
    }

    It 'supports -Validate with built-in profile selection' {
        $result = Invoke-StartSandboxJson -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')

        $result.ExitCode | Should Be 0
        $result.Json.command.mode | Should Be 'validate'
        (($result.Json.checks | Where-Object { $_.id -eq 'selection' -and $_.status -eq 'PASS' }).Count) | Should Be 1
    }

    It 'supports -Validate with custom profile selection' {
        @'
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "validate-custom",
      "base_profile": "reverse-engineering",
      "add_tools": ["wireshark"],
      "remove_tools": ["ghidra"]
    }
  ]
}
'@ | Set-Content -Path $customProfilesPath -Encoding UTF8

        $result = Invoke-StartSandboxJson -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'validate-custom')

        $result.ExitCode | Should Be 0
        $result.Json.profile.selected | Should Be 'validate-custom'
        $result.Json.profile.resolved_type | Should Be 'custom'
        $result.Json.profile.base_profile | Should Be 'reverse-engineering'
    }

    It 'fails -Validate for unknown profile/tool and malformed custom profile input' {
        $unknownProfile = Invoke-StartSandboxJson -Arguments @('-Validate', '-OutputJson', '-Profile', 'not-a-profile')
        $unknownProfile.ExitCode | Should Be 1
        (($unknownProfile.Json.checks | Where-Object { $_.id -eq 'selection' -and $_.status -eq 'FAIL' }).Count) | Should Be 1
        (($unknownProfile.Json.checks | Where-Object { $_.id -eq 'selection' })[0].summary) | Should Match 'Unknown profile'

        $unknownTool = Invoke-StartSandboxJson -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal', '-AddTools', 'not-a-real-tool')
        $unknownTool.ExitCode | Should Be 1
        (($unknownTool.Json.checks | Where-Object { $_.id -eq 'selection' })[0].summary) | Should Match 'Unknown tool id'

        '{ "schema_version": "1.0" }' | Set-Content -Path $customProfilesPath -Encoding UTF8
        $malformedCustom = Invoke-StartSandboxJson -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')
        $malformedCustom.ExitCode | Should Be 1
        (($malformedCustom.Json.checks | Where-Object { $_.id -eq 'selection' })[0].summary) | Should Match "missing required 'profiles' property"
    }

    It 'fails clearly for invalid parameter combinations and unsafe shared-folder input' {
        $invalidCombo = Invoke-StartSandboxRaw -Arguments @('-Validate', '-DryRun')
        $invalidCombo.ExitCode | Should Be 1
        $invalidCombo.Output | Should Match 'cannot be combined'

        $unsafeSharedFolder = Invoke-StartSandboxJson -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-SharedFolder', $repoRoot)
        $unsafeSharedFolder.ExitCode | Should Be 1
        (($unsafeSharedFolder.Json.checks | Where-Object { $_.id -eq 'shared-folder' })[0].summary) | Should Match 'Shared folder path is not allowed'
    }

    It 'keeps list output aligned to manifest/custom profile state' {
        @'
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "list-state-check",
      "base_profile": "minimal"
    }
  ]
}
'@ | Set-Content -Path $customProfilesPath -Encoding UTF8

        $listProfiles = Invoke-StartSandboxJson -Arguments @('-ListProfiles', '-OutputJson')
        $listTools = Invoke-StartSandboxJson -Arguments @('-ListTools', '-OutputJson')

        $listProfiles.ExitCode | Should Be 0
        (($listProfiles.Json.profiles | Where-Object { $_.name -eq 'list-state-check' -and $_.type -eq 'custom' }).Count) | Should Be 1
        $listTools.ExitCode | Should Be 0
        $listTools.Json.tools.Count | Should Be $script:manifest.tools.Count
    }

    It 'keeps -CleanDownloads scoped to disposable cache/session surfaces' {
        $setupCacheItem = Join-Path $repoRoot 'scripts\setups\integration-cleanup-scope.tmp'
        $placeholderPath = Join-Path $repoRoot 'scripts\setups\.gitkeep'
        $placeholderExists = Test-Path -LiteralPath $placeholderPath -PathType Leaf
        $sentinelPath = Join-Path $repoRoot 'scripts\integration-sentinel.keep'
        New-Item -ItemType Directory -Path (Split-Path -Parent $setupCacheItem) -Force | Out-Null
        Set-Content -Path $setupCacheItem -Value 'cache'
        Set-Content -Path $manifestOut -Value '{}'
        Set-Content -Path $wsbOut -Value '<Configuration />'
        Set-Content -Path $sentinelPath -Value 'keep'

        try {
            $result = Invoke-StartSandboxRaw -Arguments @('-CleanDownloads')

            $result.ExitCode | Should Be 0
            (Test-Path -LiteralPath $setupCacheItem -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $manifestOut -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $wsbOut -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $sentinelPath -PathType Leaf) | Should Be $true
            if ($placeholderExists) {
                (Test-Path -LiteralPath $placeholderPath -PathType Leaf) | Should Be $true
            }
        } finally {
            if (Test-Path -LiteralPath $sentinelPath -PathType Leaf) {
                Remove-Item -LiteralPath $sentinelPath -Force
            }
        }
    }
}
