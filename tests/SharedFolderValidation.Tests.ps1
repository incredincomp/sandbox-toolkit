Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\SharedFolderValidation.ps1')

function Invoke-AndCaptureErrorMessage {
    param(
        [Parameter(Mandatory)][ScriptBlock]$Script
    )

    try {
        & $Script
        return $null
    } catch {
        return $_.Exception.Message
    }
}

Describe 'Resolve-SharedFolderRequest' {
    It 'uses repo-local shared folder with -UseDefaultSharedFolder' {
        $testRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-tests-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testRepo -Force | Out-Null

        try {
            $result = Resolve-SharedFolderRequest -RepoRoot $testRepo -UseDefaultSharedFolder
            $expectedPath = Join-Path $testRepo 'shared'

            $result.SharedHostFolder | Should Be (Get-NormalizedFullPath -Path $expectedPath)
            (Test-Path -LiteralPath $expectedPath -PathType Container) | Should Be $true
            $result.SharedFolderWritable | Should Be $false
        } finally {
            if (Test-Path -LiteralPath $testRepo) {
                Remove-Item -LiteralPath $testRepo -Recurse -Force
            }
        }
    }

    It 'accepts an explicit -SharedFolder path' {
        $testRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-tests-" + [guid]::NewGuid().ToString())
        $ingressPath = Join-Path $testRepo 'lab\ingress'
        New-Item -ItemType Directory -Path $ingressPath -Force | Out-Null

        try {
            $result = Resolve-SharedFolderRequest -RepoRoot $testRepo -SharedFolder $ingressPath

            $result.SharedHostFolder | Should Be (Get-NormalizedFullPath -Path $ingressPath)
            $result.SharedFolderWritable | Should Be $false
        } finally {
            if (Test-Path -LiteralPath $testRepo) {
                Remove-Item -LiteralPath $testRepo -Recurse -Force
            }
        }
    }

    It 'keeps shared folder read-only unless -SharedFolderWritable is provided' {
        $testRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-tests-" + [guid]::NewGuid().ToString())
        $ingressPath = Join-Path $testRepo 'lab\ingress'
        New-Item -ItemType Directory -Path $ingressPath -Force | Out-Null

        try {
            $defaultResult = Resolve-SharedFolderRequest -RepoRoot $testRepo -SharedFolder $ingressPath
            $writableResult = Resolve-SharedFolderRequest -RepoRoot $testRepo -SharedFolder $ingressPath -SharedFolderWritable

            $defaultResult.SharedFolderWritable | Should Be $false
            $writableResult.SharedFolderWritable | Should Be $true
        } finally {
            if (Test-Path -LiteralPath $testRepo) {
                Remove-Item -LiteralPath $testRepo -Recurse -Force
            }
        }
    }

    It 'fails clearly when -SharedFolderWritable is provided without a shared-folder selector' {
        $testRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-tests-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testRepo -Force | Out-Null

        try {
            $message = Invoke-AndCaptureErrorMessage {
                Resolve-SharedFolderRequest -RepoRoot $testRepo -SharedFolderWritable
            }

            $message | Should Not BeNullOrEmpty
            $message | Should Match '-SharedFolderWritable requires -SharedFolder or -UseDefaultSharedFolder'
        } finally {
            if (Test-Path -LiteralPath $testRepo) {
                Remove-Item -LiteralPath $testRepo -Recurse -Force
            }
        }
    }

    It 'fails clearly when -SharedFolder and -UseDefaultSharedFolder are used together' {
        $testRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-tests-" + [guid]::NewGuid().ToString())
        $ingressPath = Join-Path $testRepo 'lab\ingress'
        New-Item -ItemType Directory -Path $ingressPath -Force | Out-Null

        try {
            $message = Invoke-AndCaptureErrorMessage {
                Resolve-SharedFolderRequest -RepoRoot $testRepo -SharedFolder $ingressPath -UseDefaultSharedFolder
            }

            $message | Should Not BeNullOrEmpty
            $message | Should Match 'Use either -SharedFolder or -UseDefaultSharedFolder, not both'
        } finally {
            if (Test-Path -LiteralPath $testRepo) {
                Remove-Item -LiteralPath $testRepo -Recurse -Force
            }
        }
    }

    It 'rejects -UseDefaultSharedFolder when repo root traverses a junction ancestry' {
        $basePath = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-default-shared-junction-" + [guid]::NewGuid().ToString())
        $realRepoPath = Join-Path $basePath 'real-repo'
        $junctionRepoPath = Join-Path $basePath 'repo-junction'
        New-Item -ItemType Directory -Path $realRepoPath -Force | Out-Null

        try {
            try {
                New-Item -ItemType Junction -Path $junctionRepoPath -Target $realRepoPath -ErrorAction Stop | Out-Null
            } catch {
                Set-TestInconclusive -Message "Could not create repo junction for default shared-folder test: $($_.Exception.Message)"
                return
            }

            $message = Invoke-AndCaptureErrorMessage {
                Resolve-SharedFolderRequest -RepoRoot $junctionRepoPath -UseDefaultSharedFolder
            }

            $message | Should Not BeNullOrEmpty
            $message | Should Match 'traverses a reparse point or junction'
            $message | Should Match 'Choose a non-reparse local folder instead'
        } finally {
            if (Test-Path -LiteralPath $basePath) {
                Remove-Item -LiteralPath $basePath -Recurse -Force
            }
        }
    }
}

Describe 'Assert-SafeSharedFolderPath blocked-path policy' {
    $policyTestRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-policy-tests-" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $policyTestRepo -Force | Out-Null

    It 'rejects repository root with clear error' {
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $policyTestRepo -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'repository root'"
    }

    It 'rejects drive root with clear error' {
        $driveRoot = [System.IO.Path]::GetPathRoot($policyTestRepo)
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $driveRoot -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'drive root'"
    }

    It 'rejects Windows directory with clear error' {
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $env:windir -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'Windows directory'"
    }

    It 'rejects Program Files with clear error' {
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $env:ProgramFiles -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'Program Files'"
    }

    It 'rejects user profile root with clear error' {
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $env:USERPROFILE -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'user profile root'"
    }

    It 'rejects Desktop root with clear error' {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $desktopPath -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'Desktop root'"
    }

    It 'rejects Documents root with clear error' {
        $documentsPath = [Environment]::GetFolderPath('MyDocuments')
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $documentsPath -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'Documents root'"
    }

    It 'rejects Downloads root with clear error' {
        $downloadsPath = Join-Path $env:USERPROFILE 'Downloads'
        if (-not (Test-Path -LiteralPath $downloadsPath -PathType Container)) {
            Set-TestInconclusive -Message "Downloads path does not exist on this host: $downloadsPath"
            return
        }

        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $downloadsPath -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'Downloads root'"
    }

    It 'rejects non-existent paths with clear error' {
        $missingPath = Join-Path $policyTestRepo 'does-not-exist'
        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $missingPath -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match 'must exist and be a directory'
    }

    It 'rejects file paths with clear error' {
        $filePath = Join-Path $policyTestRepo 'not-a-directory.txt'
        Set-Content -Path $filePath -Value 'x' -Encoding UTF8

        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $filePath -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match 'must exist and be a directory'
    }

    if (Test-Path -LiteralPath $policyTestRepo) {
        Remove-Item -LiteralPath $policyTestRepo -Recurse -Force
    }
}

Describe 'Assert-SafeSharedFolderPath reparse-point rejection' {
    It 'rejects junction-backed target path with clear error' {
        $reparseRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-reparse-tests-" + [guid]::NewGuid().ToString())
        $targetPath = Join-Path $reparseRepo 'real-target'
        $junctionPath = Join-Path $reparseRepo 'junction-target'
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

        try {
            try {
                New-Item -ItemType Junction -Path $junctionPath -Target $targetPath -ErrorAction Stop | Out-Null
            } catch {
                Set-TestInconclusive -Message "Could not create junction for test: $($_.Exception.Message)"
                return
            }

            $message = Invoke-AndCaptureErrorMessage {
                Assert-SafeSharedFolderPath -Path $junctionPath -RepoRoot $reparseRepo
            }

            $message | Should Not BeNullOrEmpty
            $message | Should Match 'reparse point or junction'
            $message | Should Match 'blocks reparse/junction paths for safety'
        } finally {
            if (Test-Path -LiteralPath $reparseRepo) {
                Remove-Item -LiteralPath $reparseRepo -Recurse -Force
            }
        }
    }
}

Describe 'Assert-SafeSharedFolderPath ancestry reparse traversal rejection' {
    It 'accepts a path with no reparse point in ancestry when otherwise valid' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-ancestry-ok-" + [guid]::NewGuid().ToString())
        $candidatePath = Join-Path $repoRoot 'lab\ingress'
        New-Item -ItemType Directory -Path $candidatePath -Force | Out-Null

        try {
            $resolved = Assert-SafeSharedFolderPath -Path $candidatePath -RepoRoot $repoRoot

            $resolved | Should Be (Get-NormalizedFullPath -Path $candidatePath)
        } finally {
            if (Test-Path -LiteralPath $repoRoot) {
                Remove-Item -LiteralPath $repoRoot -Recurse -Force
            }
        }
    }

    It 'rejects a normal target path when parent chain traverses a junction' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-ancestry-reject-" + [guid]::NewGuid().ToString())
        $realParent = Join-Path $repoRoot 'real-parent'
        $junctionParent = Join-Path $repoRoot 'junction-parent'
        New-Item -ItemType Directory -Path $realParent -Force | Out-Null

        try {
            try {
                New-Item -ItemType Junction -Path $junctionParent -Target $realParent -ErrorAction Stop | Out-Null
            } catch {
                Set-TestInconclusive -Message "Could not create parent junction for test: $($_.Exception.Message)"
                return
            }

            $targetUnderJunction = Join-Path $junctionParent 'ingress'
            New-Item -ItemType Directory -Path $targetUnderJunction -Force | Out-Null
            $message = Invoke-AndCaptureErrorMessage {
                Assert-SafeSharedFolderPath -Path $targetUnderJunction -RepoRoot $repoRoot
            }

            $message | Should Not BeNullOrEmpty
            $message | Should Match 'traverses a reparse point or junction'
            $message | Should Match 'blocks reparse/junction ancestry traversal for safety'
        } finally {
            if (Test-Path -LiteralPath $repoRoot) {
                Remove-Item -LiteralPath $repoRoot -Recurse -Force
            }
        }
    }

    It 'rejects simulated synced/managed-style path when ancestry includes a junction' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-synced-sim-" + [guid]::NewGuid().ToString())
        $localBackedPath = Join-Path $repoRoot 'local-backed'
        $simulatedSyncedRoot = Join-Path $repoRoot 'OneDrive-Sim'
        New-Item -ItemType Directory -Path $localBackedPath -Force | Out-Null

        try {
            try {
                New-Item -ItemType Junction -Path $simulatedSyncedRoot -Target $localBackedPath -ErrorAction Stop | Out-Null
            } catch {
                Set-TestInconclusive -Message "Could not create simulated synced root junction: $($_.Exception.Message)"
                return
            }

            $simulatedIngressPath = Join-Path $simulatedSyncedRoot 'samples\ingress'
            New-Item -ItemType Directory -Path $simulatedIngressPath -Force | Out-Null
            $message = Invoke-AndCaptureErrorMessage {
                Assert-SafeSharedFolderPath -Path $simulatedIngressPath -RepoRoot $repoRoot
            }

            $message | Should Not BeNullOrEmpty
            $message | Should Match 'traverses a reparse point or junction'
        } finally {
            if (Test-Path -LiteralPath $repoRoot) {
                Remove-Item -LiteralPath $repoRoot -Recurse -Force
            }
        }
    }

    It 'emits ancestry diagnostics when diagnostics mode is enabled' {
        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-diag-" + [guid]::NewGuid().ToString())
        $candidatePath = Join-Path $repoRoot 'lab\ingress'
        New-Item -ItemType Directory -Path $candidatePath -Force | Out-Null

        try {
            $verboseRecords = & {
                Assert-SafeSharedFolderPath -Path $candidatePath -RepoRoot $repoRoot -Diagnostics
            } 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            ($verboseRecords | Measure-Object).Count | Should BeGreaterThan 0
            ($verboseRecords | ForEach-Object { $_.Message }) -join "`n" | Should Match 'Shared-folder ancestry segment checked'
        } finally {
            if (Test-Path -LiteralPath $repoRoot) {
                Remove-Item -LiteralPath $repoRoot -Recurse -Force
            }
        }
    }

    It 'conditionally validates provider-style reparse roots when present on host' {
        if ($env:OS -ne 'Windows_NT') {
            Set-TestInconclusive -Message 'Provider-style reparse root validation is Windows-specific.'
            return
        }

        $providerRoots = @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial) |
            Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
            Select-Object -Unique

        if (-not $providerRoots) {
            Set-TestInconclusive -Message 'No provider-style roots detected (OneDrive env vars not present).'
            return
        }

        $reparseProviderRoot = $null
        foreach ($providerRoot in $providerRoots) {
            try {
                $rootItem = Get-Item -LiteralPath $providerRoot -Force -ErrorAction Stop
                if ($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    $reparseProviderRoot = $providerRoot
                    break
                }
            } catch {
                continue
            }
        }

        if (-not $reparseProviderRoot) {
            Set-TestInconclusive -Message 'No provider-style root with a reparse tag was found on this host.'
            return
        }

        $candidatePath = Get-ChildItem -LiteralPath $reparseProviderRoot -Directory -Force -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName -First 1
        if (-not $candidatePath) {
            Set-TestInconclusive -Message "Provider root has no accessible child directory to validate: $reparseProviderRoot"
            return
        }

        $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-provider-reparse-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null

        try {
            $message = Invoke-AndCaptureErrorMessage {
                Assert-SafeSharedFolderPath -Path $candidatePath -RepoRoot $repoRoot
            }

            $message | Should Not BeNullOrEmpty
            if ($message -notmatch 'traverses a reparse point or junction' -and $message -notmatch 'is a reparse point or junction') {
                throw "Expected reparse-point rejection message for provider-style path, got: $message"
            }
        } finally {
            if (Test-Path -LiteralPath $repoRoot) {
                Remove-Item -LiteralPath $repoRoot -Recurse -Force
            }
        }
    }
}
