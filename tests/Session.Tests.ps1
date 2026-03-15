Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Manifest.ps1')
. (Join-Path $repoRoot 'src\Session.ps1')
. (Join-Path $repoRoot 'src\SandboxConfig.ps1')

function Write-StatusLine {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )

    $null = $Message
    $null = $ForegroundColor
}

Describe 'Get-SandboxSessionManifestData' {
    It 'returns expected profile and tools payload' {
        $tools = @(
            [pscustomobject]@{ id = 'tool-a'; display_name = 'Tool A' },
            [pscustomobject]@{ id = 'tool-b'; display_name = 'Tool B' }
        )

        $manifest = Get-SandboxSessionManifestData -SandboxProfile 'minimal' -Tools $tools

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

Describe 'Resolve-SandboxSessionSelection' {
    $fixtureDir = Join-Path $PSScriptRoot 'fixtures'

    It 'uses profile selection logic from manifest helpers' {
        $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
        $selection = Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal'
        $expected = Get-ToolsForProfile -Manifest $manifest -SandboxProfile 'minimal'

        $selection.Profile | Should Be 'minimal'
        $selection.Tools.Count | Should Be $expected.Count
        ($selection.Tools | Select-Object -ExpandProperty id) -join ',' | Should Be (($expected | Select-Object -ExpandProperty id) -join ',')
    }

    It 'resolves custom profile selections from valid custom config' {
        $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
        $config = Import-CustomProfileConfig -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.valid.json')
        Test-CustomProfileConfigIntegrity -CustomProfileConfig $config -Manifest $manifest

        $selection = Resolve-SandboxSessionSelection `
            -Manifest $manifest `
            -SandboxProfile 'net-re-lite' `
            -CustomProfileConfig $config
        $selectionIds = @($selection.Tools | Select-Object -ExpandProperty id)

        $selection.ProfileType | Should Be 'custom'
        $selection.BaseProfile | Should Be 'reverse-engineering'
        (($selectionIds -contains 'wireshark')) | Should Be $true
        (($selectionIds -contains 'ghidra')) | Should Be $false
    }

    It 'applies runtime add/remove overrides deterministically' {
        $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
        $selection = Resolve-SandboxSessionSelection `
            -Manifest $manifest `
            -SandboxProfile 'minimal' `
            -AddTools @('wireshark', 'ghidra', 'wireshark') `
            -RemoveTools @('notepadpp')
        $selectionIds = @($selection.Tools | Select-Object -ExpandProperty id)

        (($selectionIds -contains 'wireshark')) | Should Be $true
        (($selectionIds -contains 'ghidra')) | Should Be $true
        (($selectionIds -contains 'notepadpp')) | Should Be $false
        ($selectionIds -join ',') | Should Match 'ghidra'
    }

    It 'fails clearly when runtime overrides reference unknown tool IDs' {
        $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
        $message = $null
        try {
            Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal' -AddTools @('does-not-exist') | Out-Null
        } catch {
            $message = $_.Exception.Message
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "Unknown tool id 'does-not-exist' in -AddTools"
    }
}

Describe 'Resolve-SandboxEffectiveToolSelection' {
    It 'deduplicates IDs and keeps deterministic install_order ordering' {
        $manifest = [pscustomobject]@{
            tools = @(
                [pscustomobject]@{ id = 'b'; install_order = 20; display_name = 'B' },
                [pscustomobject]@{ id = 'a'; install_order = 10; display_name = 'A' },
                [pscustomobject]@{ id = 'c'; install_order = 30; display_name = 'C' }
            )
        }

        $tools = Resolve-SandboxEffectiveToolSelection -Manifest $manifest -ToolIds @('c', 'a', 'a')
        ($tools | Select-Object -ExpandProperty id) -join ',' | Should Be 'a,c'
    }
}

Describe 'Invoke-SandboxSessionArtifactGeneration' {
    It 'writes host-interaction policy settings into generated sandbox.wsb' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-session-artifacts-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
            $selection = Resolve-SandboxSessionSelection -Manifest $manifest -SandboxProfile 'minimal'
            $policy = Get-SandboxHostInteractionPolicy -DisableClipboard -DisableStartupCommands
            $artifacts = Invoke-SandboxSessionArtifactGeneration `
                -RepoRoot $repoRoot `
                -SandboxProfile $selection.BaseProfile `
                -Tools $selection.Tools `
                -InstallManifestPath (Join-Path $tempRoot 'install-manifest.json') `
                -WsbPath (Join-Path $tempRoot 'sandbox.wsb') `
                -HostInteractionPolicy $policy

            $wsb = [xml](Get-Content -Raw -Path $artifacts.WsbPath)
            [string]$wsb.Configuration.ClipboardRedirection | Should Be 'Disable'
            [string]$wsb.Configuration.AudioInput | Should Be 'Disable'
            ($wsb.Configuration.PSObject.Properties['LogonCommand']) | Should BeNullOrEmpty
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }
}
