Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Maintenance.ps1')

Describe 'Get-SandboxDownloadCleanupPlan' {
    It 'discovers only repo-owned disposable artifact candidates' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-clean-tests-" + [guid]::NewGuid().ToString())
        $externalRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-clean-external-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts\setups') -Force | Out-Null
        New-Item -ItemType Directory -Path $externalRoot -Force | Out-Null

        try {
            Set-Content -Path (Join-Path $tempRoot 'scripts\setups\tool-a.exe') -Value 'a'
            Set-Content -Path (Join-Path $tempRoot 'scripts\install-manifest.json') -Value '{}'
            Set-Content -Path (Join-Path $tempRoot 'sandbox.wsb') -Value '<Configuration />'
            Set-Content -Path (Join-Path $externalRoot 'outside.txt') -Value 'keep'

            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot
            $candidatePaths = @($plan.Candidates | Select-Object -ExpandProperty path)

            $candidatePaths.Count | Should Be 3
            (($candidatePaths -contains (Join-Path $tempRoot 'scripts\setups\tool-a.exe'))) | Should Be $true
            (($candidatePaths -contains (Join-Path $tempRoot 'scripts\install-manifest.json'))) | Should Be $true
            (($candidatePaths -contains (Join-Path $tempRoot 'sandbox.wsb'))) | Should Be $true
            (($candidatePaths -contains (Join-Path $externalRoot 'outside.txt'))) | Should Be $false
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
            if (Test-Path -LiteralPath $externalRoot) {
                Remove-Item -LiteralPath $externalRoot -Recurse -Force
            }
        }
    }
}

Describe 'Invoke-SandboxDownloadCleanup' {
    It 'handles nothing-to-clean plans without failure' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-clean-empty-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot
            $result = Invoke-SandboxDownloadCleanup -CleanupPlan $plan

            $result.Success | Should Be $true
            $result.NothingToClean | Should Be $true
            $result.CandidateCount | Should Be 0
            $result.RemovedCount | Should Be 0
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'removes disposable artifacts and reports deterministic summary counts' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-clean-remove-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts\setups\subdir') -Force | Out-Null

        try {
            Set-Content -Path (Join-Path $tempRoot 'scripts\setups\tool-a.exe') -Value 'a'
            Set-Content -Path (Join-Path $tempRoot 'scripts\setups\subdir\inner.txt') -Value 'x'
            Set-Content -Path (Join-Path $tempRoot 'scripts\install-manifest.json') -Value '{}'
            Set-Content -Path (Join-Path $tempRoot 'sandbox.wsb') -Value '<Configuration />'

            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot
            $result = Invoke-SandboxDownloadCleanup -CleanupPlan $plan
            $lines = Get-SandboxDownloadCleanupSummaryLines -CleanupResult $result

            $result.Success | Should Be $true
            $result.NothingToClean | Should Be $false
            $result.CandidateCount | Should Be 4
            $result.RemovedCount | Should Be 4
            (Test-Path -LiteralPath (Join-Path $tempRoot 'scripts\setups\tool-a.exe')) | Should Be $false
            (Test-Path -LiteralPath (Join-Path $tempRoot 'scripts\setups\subdir')) | Should Be $false
            (Test-Path -LiteralPath (Join-Path $tempRoot 'scripts\install-manifest.json')) | Should Be $false
            (Test-Path -LiteralPath (Join-Path $tempRoot 'sandbox.wsb')) | Should Be $false
            @($lines | Where-Object { $_ -match 'Inspected locations' }).Count | Should Be 1
            @($lines | Where-Object { $_ -match 'Removed: 4 item\(s\)' }).Count | Should Be 1
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'surfaces partial deletion failures deterministically' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-clean-fail-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts\setups') -Force | Out-Null

        try {
            $keepPath = Join-Path $tempRoot 'scripts\setups\keep.exe'
            $failPath = Join-Path $tempRoot 'scripts\setups\fail.exe'
            Set-Content -Path $keepPath -Value 'k'
            Set-Content -Path $failPath -Value 'f'

            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot
            $result = Invoke-SandboxDownloadCleanup -CleanupPlan $plan -RemoveAction {
                param($Path, $IsContainer)
                if ($Path -eq $failPath) {
                    throw 'simulated delete failure'
                }
                Remove-Item -LiteralPath $Path -Force
            }

            $result.Success | Should Be $false
            $result.FailedCount | Should Be 1
            @($result.Failed | Where-Object { $_.path -eq $failPath }).Count | Should Be 1
            (@($result.Failed | Where-Object { $_.path -eq $failPath })[0].message) | Should Match 'simulated delete failure'
            (Test-Path -LiteralPath $keepPath -PathType Leaf) | Should Be $false
            (Test-Path -LiteralPath $failPath -PathType Leaf) | Should Be $true
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }
}
