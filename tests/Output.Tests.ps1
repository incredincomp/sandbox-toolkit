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

Describe 'Get-SandboxAuditJsonResult' {
    It 'projects audit checks and effective request context to stable JSON fields' {
        $selection = [pscustomobject]@{
            Profile = 'minimal'
            ProfileType = 'built-in'
            BaseProfile = 'minimal'
            RuntimeAddTools = @('wireshark')
            RuntimeRemoveTools = @()
            Tools = @(
                [pscustomobject]@{
                    id = 'wireshark'
                    display_name = 'Wireshark'
                    installer_type = 'exe'
                    install_order = 70
                }
            )
        }
        $auditResult = [pscustomobject]@{
            Checks = @(
                [pscustomobject]@{ Name = 'wsb-networking'; Status = 'PASS'; Message = 'configured/requested'; Remediation = $null },
                [pscustomobject]@{ Name = 'wsb-shared-folder'; Status = 'WARN'; Message = 'writable mapping'; Remediation = 'prefer read-only' }
            )
        }
        $artifacts = [pscustomobject]@{
            InstallManifestPath = 'C:\repo\scripts\install-manifest.json'
            WsbPath = 'C:\repo\sandbox.wsb'
        }

        $result = Get-SandboxAuditJsonResult `
            -AuditResult $auditResult `
            -Selection $selection `
            -NetworkingMode 'Disable' `
            -Artifacts $artifacts `
            -ExitCode 0 `
            -SharedFolder 'C:\Lab\Ingress'

        $result.command.mode | Should Be 'audit'
        $result.overall_status | Should Be 'WARN'
        $result.profile.selected | Should Be 'minimal'
        $result.checks.Count | Should Be 2
        @($result.checks | Where-Object { $_.id -eq 'wsb-shared-folder' -and $_.status -eq 'WARN' }).Count | Should Be 1
    }
}

Describe 'Get-SandboxListToolsJsonResult' {
    It 'projects list-tools catalog entries to stable JSON fields' {
        $result = Get-SandboxListToolsJsonResult -Tools @(
            [pscustomobject]@{
                id = 'ghidra'
                display_name = 'Ghidra'
                installer_type = 'zip'
                install_order = 50
                category = 'reversing'
                profiles = @('reverse-engineering', 'network-analysis')
                source_type = 'github_release'
                filename = 'ghidra.zip'
            }
        )

        $result.command.mode | Should Be 'list-tools'
        $result.tools.Count | Should Be 1
        $result.tools[0].id | Should Be 'ghidra'
        $result.tools[0].installer_type | Should Be 'zip'
        $result.tools[0].install_order | Should Be 50
        (($result.tools[0].profiles -contains 'network-analysis')) | Should Be $true
    }
}

Describe 'Get-SandboxListProfilesJsonResult' {
    It 'projects built-in and custom profile entries with explicit type and base_profile' {
        $result = Get-SandboxListProfilesJsonResult -Profiles @(
            [pscustomobject]@{
                name = 'minimal'
                profile_type = 'built-in'
                base_profile = 'minimal'
            },
            [pscustomobject]@{
                name = 'net-re-lite'
                profile_type = 'custom'
                base_profile = 'reverse-engineering'
            }
        )

        $result.command.mode | Should Be 'list-profiles'
        $result.profiles.Count | Should Be 2
        @($result.profiles | Where-Object { $_.name -eq 'minimal' -and $_.type -eq 'built-in' }).Count | Should Be 1
        @($result.profiles | Where-Object { $_.name -eq 'net-re-lite' -and $_.type -eq 'custom' -and $_.base_profile -eq 'reverse-engineering' }).Count | Should Be 1
    }
}
