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

    It 'skips directory-contents location when cleanup root is a reparse point' {
        if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
            Write-Output 'Skipped: junction creation requires Windows'
            return
        }
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-reparse-root-" + [guid]::NewGuid().ToString())
        $externalTarget = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-reparse-ext-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts') -Force | Out-Null
        New-Item -ItemType Directory -Path $externalTarget -Force | Out-Null
        $junctionPath = Join-Path $tempRoot 'scripts\setups'

        try {
            Set-Content -Path (Join-Path $externalTarget 'victim.txt') -Value 'keep-me'
            New-Item -ItemType Junction -Path $junctionPath -Target $externalTarget | Out-Null

            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot

            $skippedRoot = @($plan.Skipped | Where-Object { $_.location_id -eq 'setup-cache' -and $_.reason -eq 'reparse-point' })
            $skippedRoot.Count | Should Be 1
            ($skippedRoot[0].path) | Should Be $junctionPath
            @($plan.Candidates | Where-Object { $_.location_id -eq 'setup-cache' }).Count | Should Be 0
        } finally {
            if (Test-Path -LiteralPath $junctionPath) {
                [System.IO.Directory]::Delete($junctionPath)
            }
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
            if (Test-Path -LiteralPath $externalTarget) {
                Remove-Item -LiteralPath $externalTarget -Recurse -Force
            }
        }
    }

    It 'skips container candidates that contain nested reparse points' {
        if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
            Write-Output 'Skipped: junction creation requires Windows'
            return
        }
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-reparse-nested-" + [guid]::NewGuid().ToString())
        $externalTarget = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-reparse-nested-ext-" + [guid]::NewGuid().ToString())
        $containerPath = Join-Path $tempRoot 'scripts\setups\cache-dir'
        $junctionPath = Join-Path $containerPath 'linked'
        New-Item -ItemType Directory -Path $containerPath -Force | Out-Null
        New-Item -ItemType Directory -Path $externalTarget -Force | Out-Null

        try {
            Set-Content -Path (Join-Path $containerPath 'local.txt') -Value 'keep'
            Set-Content -Path (Join-Path $externalTarget 'victim.txt') -Value 'keep-me'
            New-Item -ItemType Junction -Path $junctionPath -Target $externalTarget | Out-Null

            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot

            @($plan.Candidates | Where-Object { $_.path -eq $containerPath }).Count | Should Be 0
            @($plan.Skipped | Where-Object { $_.path -eq $containerPath -and $_.reason -eq 'contains-reparse-point' }).Count | Should Be 1
            (Test-Path -LiteralPath (Join-Path $externalTarget 'victim.txt') -PathType Leaf) | Should Be $true
        } finally {
            if (Test-Path -LiteralPath $junctionPath) {
                [System.IO.Directory]::Delete($junctionPath)
            }
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
            if (Test-Path -LiteralPath $externalTarget) {
                Remove-Item -LiteralPath $externalTarget -Recurse -Force
            }
        }
    }
}

Describe 'Invoke-SandboxDownloadCleanup' {
    It 'preserves tracked setup-cache placeholder files' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-clean-placeholder-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts\setups') -Force | Out-Null

        try {
            $placeholderPath = Join-Path $tempRoot 'scripts\setups\.gitkeep'
            $cachePath = Join-Path $tempRoot 'scripts\setups\tool-a.exe'
            Set-Content -Path $placeholderPath -Value ''
            Set-Content -Path $cachePath -Value 'a'

            $plan = Get-SandboxDownloadCleanupPlan -RepoRoot $tempRoot
            $result = Invoke-SandboxDownloadCleanup -CleanupPlan $plan

            $result.Success | Should Be $true
            (Test-Path -LiteralPath $placeholderPath -PathType Leaf) | Should Be $true
            (Test-Path -LiteralPath $cachePath -PathType Leaf) | Should Be $false
            @($result.Skipped | Where-Object { $_.reason -eq 'tracked-placeholder' -and $_.path -eq $placeholderPath }).Count | Should Be 1
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

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
            $lines = Get-SandboxDownloadCleanupSummary -CleanupResult $result

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
                if ($IsContainer) {
                    Remove-Item -LiteralPath $Path -Recurse -Force
                } else {
                    Remove-Item -LiteralPath $Path -Force
                }
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
