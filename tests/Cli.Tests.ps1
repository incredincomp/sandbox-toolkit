Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Manifest.ps1')
. (Join-Path $repoRoot 'src\Cli.ps1')

Describe 'Resolve-StartSandboxCommandMode' {
    function Get-ErrorMessage {
        param([scriptblock]$Script)
        try {
            & $Script
            return $null
        } catch {
            return $_.Exception.Message
        }
    }

    It 'returns Run by default' {
        Resolve-StartSandboxCommandMode | Should Be 'Run'
    }

    It 'returns DryRun when -DryRun is specified' {
        Resolve-StartSandboxCommandMode -DryRun | Should Be 'DryRun'
    }

    It 'returns Validate when -Validate is specified' {
        Resolve-StartSandboxCommandMode -Validate | Should Be 'Validate'
    }

    It 'returns List when -ListTools is specified' {
        Resolve-StartSandboxCommandMode -ListTools | Should Be 'List'
    }

    It 'rejects -DryRun with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListTools:$true -DryRun:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-DryRun cannot be combined'
    }

    It 'rejects shared-folder options with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListProfiles:$true -UseDefaultSharedFolder:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match 'Shared-folder options cannot be combined'
    }

    It 'rejects -Force with -DryRun' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -DryRun:$true -Force:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-Force cannot be combined with -DryRun'
    }

    It 'rejects -Validate with -DryRun' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -Validate:$true -DryRun:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-Validate cannot be combined with -DryRun'
    }

    It 'rejects -Validate with -ListTools' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -Validate:$true -ListTools:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-Validate cannot be combined with -ListTools'
    }

    It 'rejects -Validate with -NoLaunch' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -Validate:$true -NoLaunch:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-NoLaunch cannot be combined with -Validate'
    }
}

Describe 'Get-StartSandboxModePlan' {
    It 'disables downloads/artifacts/launch for Validate mode' {
        $plan = Get-StartSandboxModePlan -CommandMode 'Validate'

        $plan.CheckPrerequisites | Should Be $true
        $plan.DownloadTools | Should Be $false
        $plan.GenerateArtifacts | Should Be $false
        $plan.LaunchSandbox | Should Be $false
    }

    It 'keeps DryRun non-destructive for launch but allows artifact generation' {
        $plan = Get-StartSandboxModePlan -CommandMode 'DryRun'

        $plan.DownloadTools | Should Be $false
        $plan.GenerateArtifacts | Should Be $true
        $plan.LaunchSandbox | Should Be $false
    }
}

Describe 'Manifest-backed listing helpers' {
    $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')

    It 'Get-ManifestProfile returns supported profiles present in tools.json' {
        $profiles = Get-ManifestProfile -Manifest $manifest

        (($profiles -contains 'minimal')) | Should Be $true
        (($profiles -contains 'reverse-engineering')) | Should Be $true
        (($profiles -contains 'network-analysis')) | Should Be $true
        (($profiles -contains 'full')) | Should Be $true
    }

    It 'Get-ManifestToolCatalog is sourced from manifest tools' {
        $catalog = Get-ManifestToolCatalog -Manifest $manifest
        $expectedCount = ($manifest.tools | Measure-Object).Count

        $catalog.Count | Should Be $expectedCount
        $catalogIds = @($catalog | Select-Object -ExpandProperty id)
        (($catalogIds -contains 'ghidra')) | Should Be $true
        (($catalogIds -contains 'npcap')) | Should Be $true
    }
}

Describe 'Invoke-SandboxLaunch' {
    It 'does not invoke launcher for dry-run' {
        $env:SANDBOX_TOOLKIT_TEST_LAUNCH = ''
        $result = Invoke-SandboxLaunch -WsbPath 'C:\temp\sandbox.wsb' -DryRun -Launcher {
            param($Path)
            $env:SANDBOX_TOOLKIT_TEST_LAUNCH = "1|$Path"
        }

        $result.Launched | Should Be $false
        $result.Reason | Should Be 'DryRun'
        $env:SANDBOX_TOOLKIT_TEST_LAUNCH | Should Be ''
    }

    It 'invokes launcher for normal run' {
        $env:SANDBOX_TOOLKIT_TEST_LAUNCH = ''
        $result = Invoke-SandboxLaunch -WsbPath 'C:\temp\sandbox.wsb' -Launcher {
            param($Path)
            $env:SANDBOX_TOOLKIT_TEST_LAUNCH = "1|$Path"
        }

        $result.Launched | Should Be $true
        $result.Reason | Should Be 'Launched'
        $env:SANDBOX_TOOLKIT_TEST_LAUNCH | Should Match '^1\|'
    }
}
