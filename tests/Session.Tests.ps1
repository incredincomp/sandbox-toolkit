Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Session.ps1')

Describe 'New-SandboxSessionManifestData' {
    It 'returns expected profile and tools payload' {
        $tools = @(
            [pscustomobject]@{ id = 'tool-a'; display_name = 'Tool A' },
            [pscustomobject]@{ id = 'tool-b'; display_name = 'Tool B' }
        )

        $manifest = New-SandboxSessionManifestData -SandboxProfile 'minimal' -Tools $tools

        $manifest.profile | Should Be 'minimal'
        $manifest.tools.Count | Should Be 2
        $manifest.tools[0].id | Should Be 'tool-a'
        $manifest.generated_at | Should Not BeNullOrEmpty
    }
}

Describe 'Write-SandboxSessionManifest' {
    It 'writes install-manifest JSON at requested path' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-session-tests-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $manifestPath = Join-Path $tempRoot 'install-manifest.json'
            $tools = @([pscustomobject]@{ id = 'tool-a'; display_name = 'Tool A' })

            $resultPath = Write-SandboxSessionManifest -SandboxProfile 'full' -Tools $tools -ManifestPath $manifestPath
            $written = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json

            $resultPath | Should Be $manifestPath
            $written.profile | Should Be 'full'
            $written.tools.Count | Should Be 1
            $written.tools[0].id | Should Be 'tool-a'
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }
}
