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
            -SharedFolder 'C:\Lab\Ingress' `
            -HostInteractionPolicy ([pscustomobject]@{
                RequestedDisableClipboard = $false
                RequestedDisableAudioInput = $false
                RequestedDisableStartupCommands = $false
                ClipboardRedirection = 'Enable'
                AudioInput = 'Disable'
                StartupCommandsEnabled = $true
            }) `
            -SessionLifecycleState ([pscustomobject]@{
                RequestedMode = 'Fresh'
                EffectiveMode = 'Fresh'
                WarmSupport = [pscustomobject]@{ Supported = $false; Reason = 'not-required' }
                RunningSessionCount = 0
            }) `
            -WslHelperState ([pscustomobject]@{
                Enabled = $false
                RequestedDistro = $null
                EffectiveDistro = $null
                StagePath = '~/.sandbox-toolkit-helper'
                WslCommandAvailable = $false
                DistroAvailable = $false
                SupportReason = 'not-requested'
            })

        $jsonObject.overall_status | Should Be 'WARN'
        $jsonObject.exit_code | Should Be 0
        $jsonObject.checks.Count | Should Be 2
        $jsonObject.profile.selected | Should Be 'minimal'
        $jsonObject.context.host_interaction_effective.clipboard_redirection | Should Be 'Enable'
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
            -SkipPrereqCheck `
            -HostInteractionPolicy ([pscustomobject]@{
                RequestedDisableClipboard = $true
                RequestedDisableAudioInput = $false
                RequestedDisableStartupCommands = $true
                ClipboardRedirection = 'Disable'
                AudioInput = 'Disable'
                StartupCommandsEnabled = $false
            }) `
            -SessionLifecycleState ([pscustomobject]@{
                RequestedMode = 'Warm'
                EffectiveMode = 'Warm'
                WarmSupport = [pscustomobject]@{ Supported = $true; Reason = 'cli-present' }
                RunningSessionCount = 1
            }) `
            -WslHelperState ([pscustomobject]@{
                Enabled = $true
                RequestedDistro = 'Ubuntu'
                EffectiveDistro = 'Ubuntu'
                StagePath = '~/.sandbox-toolkit-helper'
                WslCommandAvailable = $true
                DistroAvailable = $true
                SupportReason = 'ok'
            }) `
            -WslHelperResult ([pscustomobject]@{
                Executed = $true
                PayloadHash = 'abc123'
            })

        $result.command.mode | Should Be 'dry-run'
        $result.profile.resolved_type | Should Be 'custom'
        $result.effective.tools.Count | Should Be 1
        $result.effective.host_interaction.clipboard_redirection | Should Be 'Disable'
        $result.effective.host_interaction.startup_commands_enabled | Should Be $false
        $result.effective.session.requested_mode | Should Be 'Warm'
        $result.effective.session.warm_plan | Should Be 'reuse-existing-session'
        $result.stages.download.skipped | Should Be $true
        $result.stages.launch.skipped | Should Be $true
        $result.context.wsl_helper.enabled | Should Be $true
        $result.context.wsl_helper.payload_sha256 | Should Be 'abc123'
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
            -SharedFolder 'C:\Lab\Ingress' `
            -HostInteractionPolicy ([pscustomobject]@{
                RequestedDisableClipboard = $true
                RequestedDisableAudioInput = $true
                RequestedDisableStartupCommands = $false
                ClipboardRedirection = 'Disable'
                AudioInput = 'Disable'
                StartupCommandsEnabled = $true
            }) `
            -SessionLifecycleState ([pscustomobject]@{
                RequestedMode = 'Fresh'
                EffectiveMode = 'Fresh'
                WarmSupport = [pscustomobject]@{ Supported = $false; Reason = 'not-required' }
                RunningSessionCount = 0
            }) `
            -WslHelperState ([pscustomobject]@{
                Enabled = $false
                RequestedDistro = $null
                EffectiveDistro = $null
                StagePath = '~/.sandbox-toolkit-helper'
                WslCommandAvailable = $false
                DistroAvailable = $false
                SupportReason = 'not-requested'
            })

        $result.command.mode | Should Be 'audit'
        $result.overall_status | Should Be 'WARN'
        $result.exit_code | Should Be 0
        $result.profile.selected | Should Be 'minimal'
        $normalized = ($result | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $topLevel = @($normalized.psobject.Properties.Name)
        (($topLevel -contains 'command')) | Should Be $true
        (($topLevel -contains 'overall_status')) | Should Be $true
        (($topLevel -contains 'exit_code')) | Should Be $true
        (($topLevel -contains 'profile')) | Should Be $true
        (($topLevel -contains 'overrides')) | Should Be $true
        (($topLevel -contains 'effective')) | Should Be $true
        (($topLevel -contains 'artifacts')) | Should Be $true
        (($topLevel -contains 'checks')) | Should Be $true
        (($topLevel -contains 'context')) | Should Be $true
        $result.effective.networking_requested | Should Be 'Disable'
        $result.effective.host_interaction_requested.clipboard_redirection | Should Be 'Disable'
        $result.effective.session.requested_mode | Should Be 'Fresh'
        $result.context.runtime_verification | Should Be 'not_performed'
        $result.checks.Count | Should Be 2
        @($result.checks | Where-Object { $_.id -eq 'wsb-shared-folder' -and $_.status -eq 'WARN' }).Count | Should Be 1
        $checkFields = @($normalized.checks[0].psobject.Properties.Name)
        (($checkFields -contains 'id')) | Should Be $true
        (($checkFields -contains 'status')) | Should Be $true
        (($checkFields -contains 'summary')) | Should Be $true
        (($checkFields -contains 'remediation')) | Should Be $true
    }

    It 'keeps outcome fields deterministic for failure status' {
        $selection = [pscustomobject]@{
            Profile = 'minimal'
            ProfileType = 'built-in'
            BaseProfile = 'minimal'
            RuntimeAddTools = @()
            RuntimeRemoveTools = @()
            Tools = @()
        }
        $auditResult = [pscustomobject]@{
            Checks = @(
                [pscustomobject]@{ Name = 'wsb-networking'; Status = 'FAIL'; Message = 'mismatch'; Remediation = 'regenerate' }
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
            -ExitCode 1 `
            -HostInteractionPolicy ([pscustomobject]@{
                RequestedDisableClipboard = $false
                RequestedDisableAudioInput = $false
                RequestedDisableStartupCommands = $false
                ClipboardRedirection = 'Enable'
                AudioInput = 'Disable'
                StartupCommandsEnabled = $true
            }) `
            -SessionLifecycleState ([pscustomobject]@{
                RequestedMode = 'Fresh'
                EffectiveMode = 'Fresh'
                WarmSupport = [pscustomobject]@{ Supported = $false; Reason = 'not-required' }
                RunningSessionCount = 0
            }) `
            -WslHelperState ([pscustomobject]@{
                Enabled = $false
                RequestedDistro = $null
                EffectiveDistro = $null
                StagePath = '~/.sandbox-toolkit-helper'
                WslCommandAvailable = $false
                DistroAvailable = $false
                SupportReason = 'not-requested'
            })

        $result.overall_status | Should Be 'FAIL'
        $result.exit_code | Should Be 1
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
