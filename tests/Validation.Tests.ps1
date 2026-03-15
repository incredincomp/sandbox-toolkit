Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$fixtureDir = Join-Path $PSScriptRoot 'fixtures'
. (Join-Path $repoRoot 'src\Manifest.ps1')
. (Join-Path $repoRoot 'src\Session.ps1')
. (Join-Path $repoRoot 'src\SandboxConfig.ps1')
. (Join-Path $repoRoot 'src\SharedFolderValidation.ps1')
. (Join-Path $repoRoot 'src\Workflow.ps1')
. (Join-Path $repoRoot 'src\Validation.ps1')

Describe 'Test-SandboxHostPrerequisite' {
    It 'returns PASS checks when feature is enabled' {
        Mock Get-WindowsOptionalFeature {
            [pscustomobject]@{ State = 'Enabled' }
        }

        $results = Test-SandboxHostPrerequisite

        (@($results | Where-Object { $_.Status -eq 'PASS' }).Count) | Should BeGreaterThan 0
        (@($results | Where-Object { $_.Name -eq 'windows-sandbox-feature' -and $_.Status -eq 'PASS' }).Count) | Should Be 1
    }

    It 'returns FAIL when sandbox feature is disabled' {
        Mock Get-WindowsOptionalFeature {
            [pscustomobject]@{ State = 'Disabled' }
        }

        $results = Test-SandboxHostPrerequisite
        $featureCheck = @($results | Where-Object { $_.Name -eq 'windows-sandbox-feature' })[0]

        $featureCheck.Status | Should Be 'FAIL'
        $featureCheck.Remediation | Should Match 'Enable-WindowsOptionalFeature'
    }

    It 'returns WARN when feature check throws' {
        Mock Get-WindowsOptionalFeature {
            throw 'not available'
        }

        $results = Test-SandboxHostPrerequisite
        $featureCheck = @($results | Where-Object { $_.Name -eq 'windows-sandbox-feature' })[0]

        $featureCheck.Status | Should Be 'WARN'
        $featureCheck.Message | Should Match 'Could not verify Windows Sandbox feature'
    }
}

Describe 'Test-SandboxSharedFolderReadiness' {
    It 'reuses Assert-SafeSharedFolderPath for explicit shared-folder validation' {
        $tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-validate-shared-" + [guid]::NewGuid().ToString())
        $ingress = Join-Path $tempRepo 'lab\ingress'
        New-Item -ItemType Directory -Path $ingress -Force | Out-Null

        try {
            $result = Test-SandboxSharedFolderReadiness -RepoRoot $tempRepo -SharedFolder $ingress

            $result.Check.Status | Should Be 'PASS'
            $result.ResolvedSharedFolder | Should Be (Get-NormalizedFullPath -Path $ingress)
        } finally {
            if (Test-Path -LiteralPath $tempRepo) {
                Remove-Item -LiteralPath $tempRepo -Recurse -Force
            }
        }
    }

    It 'does not create default shared folder during preflight' {
        $tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-validate-default-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null

        try {
            $defaultPath = Join-Path $tempRepo 'shared'
            $result = Test-SandboxSharedFolderReadiness -RepoRoot $tempRepo -UseDefaultSharedFolder

            $result.Check.Status | Should Be 'WARN'
            (Test-Path -LiteralPath $defaultPath) | Should Be $false
        } finally {
            if (Test-Path -LiteralPath $tempRepo) {
                Remove-Item -LiteralPath $tempRepo -Recurse -Force
            }
        }
    }
}

Describe 'Invoke-SandboxPreflightValidation' {
    It 'passes under healthy mocked prerequisites' {
        Mock Get-WindowsOptionalFeature {
            [pscustomobject]@{ State = 'Enabled' }
        }

        $result = Invoke-SandboxPreflightValidation `
            -RepoRoot $repoRoot `
            -ManifestPath (Join-Path $repoRoot 'tools.json') `
            -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.valid.json') `
            -SandboxProfile 'minimal' `
            -AddTools @('ghidra') `
            -RemoveTools @('notepadpp') `
            -HostInteractionPolicy (Get-SandboxHostInteractionPolicy) `
            -SessionLifecycleState ([pscustomobject]@{
                RequestedMode = 'Fresh'
                EffectiveMode = 'Fresh'
                WarmSupport = [pscustomobject]@{ Supported = $false; Reason = 'not-required' }
                RunningSessionCount = 0
                InventoryError = $null
            }) `
            -WslHelperState ([pscustomobject]@{
                Enabled = $false
                WslCommandAvailable = $false
                DistroAvailable = $false
                SupportReason = 'not-requested'
                StagePath = '~/.sandbox-toolkit-helper'
            })

        $result.HasFailures | Should Be $false
        (@($result.Checks | Where-Object { $_.Status -eq 'PASS' }).Count) | Should BeGreaterThan 0
    }

    It 'fails cleanly when selection prerequisites are invalid' {
        $missingManifest = Join-Path $repoRoot 'does-not-exist-tools.json'

        $result = Invoke-SandboxPreflightValidation `
            -RepoRoot $repoRoot `
            -ManifestPath $missingManifest `
            -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.valid.json') `
            -SandboxProfile 'minimal' `
            -SkipPrereqCheck `
            -HostInteractionPolicy (Get-SandboxHostInteractionPolicy) `
            -SessionLifecycleState ([pscustomobject]@{
                RequestedMode = 'Fresh'
                EffectiveMode = 'Fresh'
                WarmSupport = [pscustomobject]@{ Supported = $false; Reason = 'not-required' }
                RunningSessionCount = 0
                InventoryError = $null
            }) `
            -WslHelperState ([pscustomobject]@{
                Enabled = $false
                WslCommandAvailable = $false
                DistroAvailable = $false
                SupportReason = 'not-requested'
                StagePath = '~/.sandbox-toolkit-helper'
            })

        $result.HasFailures | Should Be $true
        (@($result.Checks | Where-Object { $_.Name -eq 'selection' -and $_.Status -eq 'FAIL' }).Count) | Should Be 1
    }
}

Describe 'Test-SandboxHostInteractionPolicyReadiness' {
    It 'returns warn when startup automation is explicitly disabled' {
        $checks = Test-SandboxHostInteractionPolicyReadiness `
            -HostInteractionPolicy (Get-SandboxHostInteractionPolicy -DisableStartupCommands)

        @($checks | Where-Object { $_.Name -eq 'host-interaction-policy' -and $_.Status -eq 'PASS' }).Count | Should Be 1
        @($checks | Where-Object { $_.Name -eq 'startup-command-automation' -and $_.Status -eq 'WARN' }).Count | Should Be 1
    }
}

Describe 'Test-SandboxSessionLifecycleReadiness' {
    It 'fails when warm mode is requested on unsupported host state' {
        $checks = Test-SandboxSessionLifecycleReadiness -SessionLifecycleState ([pscustomobject]@{
            RequestedMode = 'Warm'
            EffectiveMode = 'Warm'
            WarmSupport = [pscustomobject]@{
                Supported = $false
                Reason = 'wsb command not found'
            }
            RunningSessionCount = 0
            InventoryError = $null
        })

        @($checks | Where-Object { $_.Name -eq 'session-mode' -and $_.Status -eq 'FAIL' }).Count | Should Be 1
    }

    It 'warns when warm session discovery output cannot be parsed' {
        $checks = Test-SandboxSessionLifecycleReadiness -SessionLifecycleState ([pscustomobject]@{
            RequestedMode = 'Warm'
            EffectiveMode = 'Warm'
            WarmSupport = [pscustomobject]@{
                Supported = $true
                Reason = 'wsb available'
            }
            RunningSessionCount = 0
            InventoryError = 'unsupported JSON shape'
        })

        @($checks | Where-Object { $_.Name -eq 'session-mode' -and $_.Status -eq 'WARN' }).Count | Should Be 1
        (@($checks | Where-Object { $_.Name -eq 'session-mode' })[0].Message) | Should Match 'discovery failed'
    }
}

Describe 'Test-SandboxWslHelperReadiness' {
    It 'warns when helper hardening settings are missing expected values' {
        $checks = Test-SandboxWslHelperReadiness -WslHelperState ([pscustomobject]@{
            Enabled = $true
            WslCommandAvailable = $true
            DistroAvailable = $true
            SupportReason = 'ok'
            EffectiveDistro = 'Ubuntu'
            StagePath = '~/.sandbox-toolkit-helper'
            Hardening = [pscustomobject]@{
                Available = $true
                AutomountEnabled = 'true'
                InteropEnabled = 'true'
                AppendWindowsPath = 'true'
            }
        })

        @($checks | Where-Object { $_.Name -eq 'wsl-helper' -and $_.Status -eq 'PASS' }).Count | Should Be 1
        @($checks | Where-Object { $_.Name -eq 'wsl-helper-hardening' -and $_.Status -eq 'WARN' }).Count | Should Be 1
    }

    It 'keeps repository wsl helper sample aligned with expected hardening state' {
        $samplePath = Join-Path $repoRoot 'wsl-helper.example.wsl.conf'

        Test-Path -LiteralPath $samplePath | Should Be $true
        $content = Get-Content -Raw -Path $samplePath
        [string]::IsNullOrWhiteSpace($content) | Should Be $false

        $ini = ConvertFrom-SandboxIniContent -Content $content
        $checks = Test-SandboxWslHelperReadiness -WslHelperState ([pscustomobject]@{
            Enabled = $true
            WslCommandAvailable = $true
            DistroAvailable = $true
            SupportReason = 'ok'
            EffectiveDistro = 'Ubuntu'
            StagePath = '~/.sandbox-toolkit-helper'
            Hardening = [pscustomobject]@{
                Available = $true
                AutomountEnabled = $ini['automount']['enabled']
                InteropEnabled = $ini['interop']['enabled']
                AppendWindowsPath = $ini['interop']['appendwindowspath']
            }
        })

        @($checks | Where-Object { $_.Name -eq 'wsl-helper-hardening' -and $_.Status -eq 'PASS' }).Count | Should Be 1
    }
}

Describe 'Test-SandboxSelectionReadiness' {
    It 'surfaces invalid profile references clearly' {
        $result = Test-SandboxSelectionReadiness `
            -ManifestPath (Join-Path $repoRoot 'tools.json') `
            -SandboxProfile 'not-a-profile' `
            -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.valid.json')

        $result.Check.Status | Should Be 'FAIL'
        $result.Check.Message | Should Match 'Invalid profile'
    }

    It 'surfaces invalid custom profile config clearly' {
        $result = Test-SandboxSelectionReadiness `
            -ManifestPath (Join-Path $repoRoot 'tools.json') `
            -SandboxProfile 'minimal' `
            -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.invalid-shape.json')

        $result.Check.Status | Should Be 'FAIL'
        $result.Check.Message | Should Match "missing required 'profiles' property"
    }

    It 'surfaces invalid runtime override tool names clearly' {
        $result = Test-SandboxSelectionReadiness `
            -ManifestPath (Join-Path $repoRoot 'tools.json') `
            -SandboxProfile 'minimal' `
            -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.valid.json') `
            -AddTools @('not-a-real-tool')

        $result.Check.Status | Should Be 'FAIL'
        $result.Check.Message | Should Match '-AddTools contains unknown tool id'
    }
}

Describe 'Get-SandboxValidationExitCode' {
    It 'returns 0 when there are no failures' {
        $result = [pscustomobject]@{ HasFailures = $false }
        (Get-SandboxValidationExitCode -PreflightResult $result) | Should Be 0
    }

    It 'returns 1 when failures are present' {
        $result = [pscustomobject]@{ HasFailures = $true }
        (Get-SandboxValidationExitCode -PreflightResult $result) | Should Be 1
    }
}
