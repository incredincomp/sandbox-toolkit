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
            New-Item -ItemType Directory -Path $downloadsPath -Force | Out-Null
        }

        $message = Invoke-AndCaptureErrorMessage {
            Assert-SafeSharedFolderPath -Path $downloadsPath -RepoRoot $policyTestRepo
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "blocked category 'Downloads root'"
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
        } finally {
            if (Test-Path -LiteralPath $reparseRepo) {
                Remove-Item -LiteralPath $reparseRepo -Recurse -Force
            }
        }
    }
}
