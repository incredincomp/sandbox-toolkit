Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Manifest.ps1')
. (Join-Path $repoRoot 'src\Session.ps1')
. (Join-Path $repoRoot 'src\SandboxConfig.ps1')
. (Join-Path $repoRoot 'src\Validation.ps1')
. (Join-Path $repoRoot 'src\Audit.ps1')

function Write-StatusLine {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
}

Describe 'Invoke-SandboxArtifactAudit' {
    It 'passes key generated-artifact checks for a baseline dry configuration' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-audit-tests-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
            $selection = Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal'
            $artifacts = Invoke-SandboxSessionArtifactGeneration `
                -RepoRoot $repoRoot `
                -SandboxProfile $selection.BaseProfile `
                -Tools $selection.Tools `
                -InstallManifestPath (Join-Path $tempRoot 'install-manifest.json') `
                -WsbPath (Join-Path $tempRoot 'sandbox.wsb')

            $result = Invoke-SandboxArtifactAudit `
                -RepoRoot $repoRoot `
                -Selection $selection `
                -NetworkingMode (Get-SandboxNetworkingMode -SandboxProfile $selection.BaseProfile) `
                -Artifacts $artifacts

            $result.HasFailures | Should Be $false
            @($result.Checks | Where-Object { $_.Name -eq 'wsb-networking' -and $_.Status -eq 'PASS' }).Count | Should Be 1
            @($result.Checks | Where-Object { $_.Name -eq 'install-manifest-artifact' -and $_.Status -eq 'PASS' }).Count | Should Be 1
            @($result.Checks | Where-Object { $_.Name -eq 'wsb-scripts-mapping' -and $_.Status -eq 'PASS' }).Count | Should Be 1
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'fails deterministically when generated networking setting mismatches expected selection' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-audit-tests-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
            $selection = Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal'
            $artifacts = Invoke-SandboxSessionArtifactGeneration `
                -RepoRoot $repoRoot `
                -SandboxProfile $selection.BaseProfile `
                -Tools $selection.Tools `
                -InstallManifestPath (Join-Path $tempRoot 'install-manifest.json') `
                -WsbPath (Join-Path $tempRoot 'sandbox.wsb')

            (Get-Content -Raw -Path $artifacts.WsbPath).Replace('<Networking>Disable</Networking>', '<Networking>Enable</Networking>') |
                Set-Content -Path $artifacts.WsbPath -Encoding UTF8

            $result = Invoke-SandboxArtifactAudit `
                -RepoRoot $repoRoot `
                -Selection $selection `
                -NetworkingMode 'Disable' `
                -Artifacts $artifacts

            $result.HasFailures | Should Be $true
            @($result.Checks | Where-Object { $_.Name -eq 'wsb-networking' -and $_.Status -eq 'FAIL' }).Count | Should Be 1
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'warns when generated shared-folder mapping is writable by request' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-audit-tests-" + [guid]::NewGuid().ToString())
        $sharedRoot = Join-Path $tempRoot 'lab\ingress'
        New-Item -ItemType Directory -Path $sharedRoot -Force | Out-Null

        try {
            $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
            $selection = Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal'
            $artifacts = Invoke-SandboxSessionArtifactGeneration `
                -RepoRoot $repoRoot `
                -SandboxProfile $selection.BaseProfile `
                -Tools $selection.Tools `
                -InstallManifestPath (Join-Path $tempRoot 'install-manifest.json') `
                -WsbPath (Join-Path $tempRoot 'sandbox.wsb') `
                -SharedHostFolder $sharedRoot `
                -SharedFolderWritable

            $result = Invoke-SandboxArtifactAudit `
                -RepoRoot $repoRoot `
                -Selection $selection `
                -NetworkingMode (Get-SandboxNetworkingMode -SandboxProfile $selection.BaseProfile) `
                -Artifacts $artifacts `
                -SharedHostFolder $sharedRoot `
                -SharedFolderWritable

            @($result.Checks | Where-Object { $_.Name -eq 'wsb-shared-folder' -and $_.Status -eq 'WARN' }).Count | Should Be 1
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'uses explicit configured/requested wording in trust-boundary-sensitive checks' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-audit-tests-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
            $selection = Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal'
            $artifacts = Invoke-SandboxSessionArtifactGeneration `
                -RepoRoot $repoRoot `
                -SandboxProfile $selection.BaseProfile `
                -Tools $selection.Tools `
                -InstallManifestPath (Join-Path $tempRoot 'install-manifest.json') `
                -WsbPath (Join-Path $tempRoot 'sandbox.wsb')

            $result = Invoke-SandboxArtifactAudit `
                -RepoRoot $repoRoot `
                -Selection $selection `
                -NetworkingMode (Get-SandboxNetworkingMode -SandboxProfile $selection.BaseProfile) `
                -Artifacts $artifacts

            $networkingMessage = (@($result.Checks | Where-Object { $_.Name -eq 'wsb-networking' })[0]).Message
            $networkingMessage | Should Match 'configured/requested'
            $networkingMessage | Should Match 'not runtime-verified'
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }
}
