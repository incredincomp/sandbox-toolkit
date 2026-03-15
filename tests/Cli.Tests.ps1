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

    It 'returns Audit when -Audit is specified' {
        Resolve-StartSandboxCommandMode -Audit | Should Be 'Audit'
    }

    It 'returns List when -ListTools is specified' {
        Resolve-StartSandboxCommandMode -ListTools | Should Be 'List'
    }

    It 'returns CleanDownloads when -CleanDownloads is specified' {
        Resolve-StartSandboxCommandMode -CleanDownloads | Should Be 'CleanDownloads'
    }

    It 'returns SaveTemplate when -SaveTemplate is specified' {
        Resolve-StartSandboxCommandMode -SaveTemplate 'daily-re' | Should Be 'SaveTemplate'
    }

    It 'returns ListTemplates when -ListTemplates is specified' {
        Resolve-StartSandboxCommandMode -ListTemplates | Should Be 'ListTemplates'
    }

    It 'returns ShowTemplate when -ShowTemplate is specified' {
        Resolve-StartSandboxCommandMode -ShowTemplate 'daily-re' | Should Be 'ShowTemplate'
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

    It 'rejects host-interaction policy options with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListTools:$true -DisableClipboard:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match 'Host-interaction policy options cannot be combined'
    }

    It 'rejects -NoLaunch with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListProfiles:$true -NoLaunch:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-NoLaunch cannot be combined with -ListTools or -ListProfiles'
    }

    It 'rejects -SkipPrereqCheck with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListTools:$true -SkipPrereqCheck:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-SkipPrereqCheck cannot be combined with -ListTools or -ListProfiles'
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

    It 'rejects -Audit with -DryRun' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -Audit:$true -DryRun:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-Audit cannot be combined with -DryRun'
    }

    It 'rejects -Audit with -NoLaunch' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -Audit:$true -NoLaunch:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-NoLaunch cannot be combined with -Audit'
    }

    It 'rejects -AddTools with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListProfiles:$true -AddTools @('ghidra') }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-AddTools and -RemoveTools cannot be combined'
    }

    It 'accepts -OutputJson with -ListTools' {
        Resolve-StartSandboxCommandMode -ListTools:$true -OutputJson:$true | Should Be 'List'
    }

    It 'accepts -OutputJson with -ListProfiles' {
        Resolve-StartSandboxCommandMode -ListProfiles:$true -OutputJson:$true | Should Be 'List'
    }

    It 'rejects -OutputJson with both list switches' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -OutputJson:$true -ListTools:$true -ListProfiles:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-OutputJson cannot be combined with both -ListTools and -ListProfiles'
    }

    It 'rejects -OutputJson without a JSON-capable mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -OutputJson:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-OutputJson is supported only with -Validate, -Audit, -DryRun, -ListTools, or -ListProfiles'
    }

    It 'accepts -OutputJson with -Audit' {
        Resolve-StartSandboxCommandMode -Audit:$true -OutputJson:$true | Should Be 'Audit'
    }

    It 'rejects -Validate with -CleanDownloads' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -CleanDownloads:$true -Validate:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-CleanDownloads cannot be combined with -Validate'
    }

    It 'rejects -OutputJson with -CleanDownloads' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -CleanDownloads:$true -OutputJson:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-OutputJson cannot be combined with -CleanDownloads'
    }

    It 'rejects host-interaction policy options with clean mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -CleanDownloads:$true -DisableStartupCommands:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match 'Host-interaction policy options cannot be combined'
    }

    It 'keeps existing dry-run mode unaffected' {
        Resolve-StartSandboxCommandMode -DryRun:$true -SkipPrereqCheck:$true | Should Be 'DryRun'
    }

    It 'rejects -SessionMode with list mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -ListTools:$true -SessionMode 'Warm' }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-SessionMode cannot be combined'
    }

    It 'rejects WSL helper options with clean mode' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -CleanDownloads:$true -UseWslHelper:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match 'WSL helper options cannot be combined'
    }

    It 'requires -UseWslHelper when -WslDistro is specified' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -DryRun:$true -WslDistro 'Ubuntu' -ExplicitWslDistro:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match 'require -UseWslHelper'
    }

    It 'rejects -Template with list mode switches' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -Template 'daily-re' -ListTools:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-Template cannot be combined with -ListTools or -ListProfiles'
    }

    It 'rejects -SaveTemplate with output mode switches' {
        $message = Get-ErrorMessage { Resolve-StartSandboxCommandMode -SaveTemplate 'daily-re' -OutputJson:$true }
        $message | Should Not BeNullOrEmpty
        $message | Should Match '-SaveTemplate cannot be combined with -Force, -NoLaunch, or -OutputJson'
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

    It 'keeps Audit non-destructive while still generating artifacts for inspection' {
        $plan = Get-StartSandboxModePlan -CommandMode 'Audit'

        $plan.CheckPrerequisites | Should Be $true
        $plan.DownloadTools | Should Be $false
        $plan.GenerateArtifacts | Should Be $true
        $plan.LaunchSandbox | Should Be $false
    }

    It 'disables all execution stages for CleanDownloads mode' {
        $plan = Get-StartSandboxModePlan -CommandMode 'CleanDownloads'

        $plan.CheckPrerequisites | Should Be $false
        $plan.DownloadTools | Should Be $false
        $plan.GenerateArtifacts | Should Be $false
        $plan.LaunchSandbox | Should Be $false
    }

    It 'disables all execution stages for SaveTemplate mode' {
        $plan = Get-StartSandboxModePlan -CommandMode 'SaveTemplate'

        $plan.CheckPrerequisites | Should Be $false
        $plan.DownloadTools | Should Be $false
        $plan.GenerateArtifacts | Should Be $false
        $plan.LaunchSandbox | Should Be $false
    }
}

Describe 'Manifest-backed listing helpers' {
    $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
    $fixtureDir = Join-Path $PSScriptRoot 'fixtures'

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

    It 'Get-SandboxProfileCatalog includes built-in and custom profiles clearly' {
        $customConfig = Import-CustomProfileConfig -CustomProfilePath (Join-Path $fixtureDir 'custom-profiles.valid.json')
        Test-CustomProfileConfigIntegrity -CustomProfileConfig $customConfig -Manifest $manifest
        $catalog = Get-SandboxProfileCatalog -Manifest $manifest -CustomProfileConfig $customConfig

        @($catalog | Where-Object { $_.name -eq 'minimal' -and $_.profile_type -eq 'built-in' }).Count | Should Be 1
        @($catalog | Where-Object { $_.name -eq 'net-re-lite' -and $_.profile_type -eq 'custom' -and $_.base_profile -eq 'reverse-engineering' }).Count | Should Be 1
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
