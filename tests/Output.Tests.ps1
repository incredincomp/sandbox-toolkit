Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Output.ps1')

Describe 'Get-SandboxValidateJsonResult' {
    It 'projects stable validate JSON structure with statuses' {
        $preflightResult = [pscustomobject]@{
            Checks = @(
                [pscustomobject]@{ Name = 'a'; Status = 'PASS'; Message = 'ok'; Remediation = $null },
                [pscustomobject]@{ Name = 'b'; Status = 'WARN'; Message = 'warn'; Remediation = 'do x' }
            )
            Selection = [pscustomobject]@{ ProfileType = 'built-in'; BaseProfile = 'minimal' }
            SharedHostFolder = 'C:\Lab\Ingress'
            SharedFolderWritable = $false
        }

        $jsonObject = Get-SandboxValidateJsonResult `
            -PreflightResult $preflightResult `
            -SandboxProfile 'minimal' `
            -ExitCode 0 `
            -SkipPrereqCheck `
            -SharedFolder 'C:\Lab\Ingress'

        $jsonObject.overall_status | Should Be 'WARN'
        $jsonObject.exit_code | Should Be 0
        $jsonObject.checks.Count | Should Be 2
        $jsonObject.profile.selected | Should Be 'minimal'
    }
}

Describe 'Get-SandboxDryRunJsonResult' {
    It 'projects effective dry-run selection and skipped stages' {
        $selection = [pscustomobject]@{
            Profile = 'net-re-lite'
            ProfileType = 'custom'
            BaseProfile = 'reverse-engineering'
            RuntimeAddTools = @('floss')
            RuntimeRemoveTools = @('ghidra')
            Tools = @(
                [pscustomobject]@{
                    id = 'floss'
                    display_name = 'FLARE FLOSS'
                    installer_type = 'zip'
                    install_order = 28
                }
            )
        }
        $artifacts = [pscustomobject]@{
            InstallManifestPath = 'C:\repo\scripts\install-manifest.json'
            WsbPath = 'C:\repo\sandbox.wsb'
        }

        $result = Get-SandboxDryRunJsonResult `
            -Selection $selection `
            -NetworkingMode 'Disable' `
            -SetupState @([pscustomobject]@{ id = 'floss'; cached = $false }) `
            -Artifacts $artifacts `
            -SkipPrereqCheck

        $result.command.mode | Should Be 'dry-run'
        $result.profile.resolved_type | Should Be 'custom'
        $result.effective.tools.Count | Should Be 1
        $result.stages.download.skipped | Should Be $true
        $result.stages.launch.skipped | Should Be $true
    }
}
