Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path $repoRoot 'Start-Sandbox.ps1'
$manifestOut = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbOut = Join-Path $repoRoot 'sandbox.wsb'
$customProfilesPath = Join-Path $repoRoot 'custom-profiles.local.json'

function Invoke-StartSandboxJsonHardening {
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

function Invoke-StartSandboxRawHardening {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1 | Out-String
    return [pscustomobject]@{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

Describe 'Release hardening command-surface characterization' {
    BeforeAll {
        @'
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "release-hardening-custom",
      "base_profile": "reverse-engineering",
      "add_tools": ["wireshark"],
      "remove_tools": ["ghidra"]
    }
  ]
}
'@ | Set-Content -Path $customProfilesPath -Encoding UTF8
    }

    AfterEach {
        if (Test-Path -LiteralPath $manifestOut -PathType Leaf) {
            Remove-Item -LiteralPath $manifestOut -Force
        }
        if (Test-Path -LiteralPath $wsbOut -PathType Leaf) {
            Remove-Item -LiteralPath $wsbOut -Force
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $customProfilesPath -PathType Leaf) {
            Remove-Item -LiteralPath $customProfilesPath -Force
        }
    }

    It 'covers required dry-run combinations for built-in/custom/add/remove flows' {
        $cases = @(
            [pscustomobject]@{
                Name = 'dryrun-built-in'
                Arguments = @('-DryRun', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')
                ExpectedPresent = @('notepadpp')
                ExpectedAbsent = @()
            }
            [pscustomobject]@{
                Name = 'dryrun-custom'
                Arguments = @('-DryRun', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'release-hardening-custom')
                ExpectedPresent = @('wireshark')
                ExpectedAbsent = @('ghidra')
            }
            [pscustomobject]@{
                Name = 'dryrun-addtools'
                Arguments = @('-DryRun', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal', '-AddTools', 'wireshark')
                ExpectedPresent = @('wireshark')
                ExpectedAbsent = @()
            }
            [pscustomobject]@{
                Name = 'dryrun-removetools'
                Arguments = @('-DryRun', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal', '-RemoveTools', 'notepadpp')
                ExpectedPresent = @()
                ExpectedAbsent = @('notepadpp')
            }
        )

        foreach ($case in $cases) {
            $result = Invoke-StartSandboxJsonHardening -Arguments $case.Arguments
            $toolIds = @($result.Json.effective.tools | Select-Object -ExpandProperty id)

            $result.ExitCode | Should Be 0
            $result.Json.command.mode | Should Be 'dry-run'
            foreach ($toolId in $case.ExpectedPresent) {
                (($toolIds -contains $toolId)) | Should Be $true
            }
            foreach ($toolId in $case.ExpectedAbsent) {
                (($toolIds -contains $toolId)) | Should Be $false
            }
        }
    }

    It 'covers required validate combinations for built-in/custom/invalid profile/invalid tool flows' {
        $validBuiltIn = Invoke-StartSandboxJsonHardening -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')
        $validCustom = Invoke-StartSandboxJsonHardening -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'release-hardening-custom')
        $invalidProfile = Invoke-StartSandboxJsonHardening -Arguments @('-Validate', '-OutputJson', '-Profile', 'not-a-profile')
        $invalidTool = Invoke-StartSandboxJsonHardening -Arguments @('-Validate', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal', '-AddTools', 'not-a-real-tool')

        $validBuiltIn.ExitCode | Should Be 0
        $validBuiltIn.Json.command.mode | Should Be 'validate'
        (($validBuiltIn.Json.checks | Where-Object { $_.id -eq 'selection' -and $_.status -eq 'PASS' }).Count) | Should Be 1

        $validCustom.ExitCode | Should Be 0
        $validCustom.Json.profile.selected | Should Be 'release-hardening-custom'
        $validCustom.Json.profile.resolved_type | Should Be 'custom'

        $invalidProfile.ExitCode | Should Be 1
        (($invalidProfile.Json.checks | Where-Object { $_.id -eq 'selection' })[0].summary) | Should Match 'Unknown profile'

        $invalidTool.ExitCode | Should Be 1
        (($invalidTool.Json.checks | Where-Object { $_.id -eq 'selection' })[0].summary) | Should Match 'Unknown tool id'
    }

    It 'keeps list state and cleanup scope aligned with actual config/runtime surfaces' {
        $listProfiles = Invoke-StartSandboxJsonHardening -Arguments @('-ListProfiles', '-OutputJson')
        $listTools = Invoke-StartSandboxJsonHardening -Arguments @('-ListTools', '-OutputJson')

        $listProfiles.ExitCode | Should Be 0
        (($listProfiles.Json.profiles | Where-Object { $_.name -eq 'release-hardening-custom' -and $_.type -eq 'custom' }).Count) | Should Be 1
        $listTools.ExitCode | Should Be 0
        (($listTools.Json.tools | Where-Object { $_.id -eq 'ghidra' }).Count) | Should Be 1

        $setupCacheItem = Join-Path $repoRoot 'scripts\setups\release-hardening-cleanup.tmp'
        $sentinelPath = Join-Path $repoRoot 'scripts\release-hardening-sentinel.keep'
        New-Item -ItemType Directory -Path (Split-Path -Parent $setupCacheItem) -Force | Out-Null
        Set-Content -Path $setupCacheItem -Value 'cache'
        Set-Content -Path $manifestOut -Value '{}'
        Set-Content -Path $wsbOut -Value '<Configuration />'
        Set-Content -Path $sentinelPath -Value 'keep'

        try {
            $cleanup = Invoke-StartSandboxRawHardening -Arguments @('-CleanDownloads')

            $cleanup.ExitCode | Should Be 0
            (Test-Path -LiteralPath $setupCacheItem -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $manifestOut -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $wsbOut -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $sentinelPath -PathType Leaf) | Should Be $true
        } finally {
            if (Test-Path -LiteralPath $sentinelPath -PathType Leaf) {
                Remove-Item -LiteralPath $sentinelPath -Force
            }
        }
    }
}
