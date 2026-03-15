Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Manifest.ps1')
. (Join-Path $repoRoot 'src\Session.ps1')
. (Join-Path $repoRoot 'src\SandboxConfig.ps1')
. (Join-Path $repoRoot 'src\SharedFolderValidation.ps1')
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
    It 'fails cleanly when selection prerequisites are invalid' {
        $missingManifest = Join-Path $repoRoot 'does-not-exist-tools.json'

        $result = Invoke-SandboxPreflightValidation `
            -RepoRoot $repoRoot `
            -ManifestPath $missingManifest `
            -SandboxProfile 'minimal' `
            -SkipPrereqCheck

        $result.HasFailures | Should Be $true
        (@($result.Checks | Where-Object { $_.Name -eq 'selection' -and $_.Status -eq 'FAIL' }).Count) | Should Be 1
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
