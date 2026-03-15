# src/Output.ps1
# Thin projection helpers for machine-readable JSON output.

function Get-SandboxCheckStatusSummary {
    <#
    .SYNOPSIS
        Returns aggregate status for a list of checks.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Checks
    )

    if (@($Checks | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0) {
        return 'FAIL'
    }

    if (@($Checks | Where-Object { $_.Status -eq 'WARN' }).Count -gt 0) {
        return 'WARN'
    }

    return 'PASS'
}

function Get-SandboxValidateJsonResult {
    <#
    .SYNOPSIS
        Projects preflight validation results into stable JSON contract shape.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$PreflightResult,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [Parameter(Mandatory)][int]$ExitCode,
        [switch]$SkipPrereqCheck,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [PSCustomObject]$HostInteractionPolicy
    )

    return [ordered]@{
        command = [ordered]@{
            mode = 'validate'
        }
        overall_status = Get-SandboxCheckStatusSummary -Checks $PreflightResult.Checks
        exit_code      = $ExitCode
        profile        = [ordered]@{
            selected = $SandboxProfile
            resolved_type = if ($PreflightResult.Selection) { $PreflightResult.Selection.ProfileType } else { $null }
            base_profile = if ($PreflightResult.Selection) { $PreflightResult.Selection.BaseProfile } else { $null }
        }
        checks = @(
            $PreflightResult.Checks | ForEach-Object {
                [ordered]@{
                    id          = $_.Name
                    status      = $_.Status
                    summary     = $_.Message
                    remediation = $_.Remediation
                }
            }
        )
        context = [ordered]@{
            skip_prereq_check = [bool]$SkipPrereqCheck
            requested_shared_folder = if ($UseDefaultSharedFolder) { 'default' } else { $SharedFolder }
            resolved_shared_folder  = $PreflightResult.SharedHostFolder
            shared_folder_writable  = [bool]$PreflightResult.SharedFolderWritable
            host_interaction_requested = [ordered]@{
                disable_clipboard = [bool]$HostInteractionPolicy.RequestedDisableClipboard
                disable_audio_input = [bool]$HostInteractionPolicy.RequestedDisableAudioInput
                disable_startup_commands = [bool]$HostInteractionPolicy.RequestedDisableStartupCommands
            }
            host_interaction_effective = [ordered]@{
                clipboard_redirection = $HostInteractionPolicy.ClipboardRedirection
                audio_input = $HostInteractionPolicy.AudioInput
                startup_commands_enabled = [bool]$HostInteractionPolicy.StartupCommandsEnabled
            }
        }
    }
}

function Get-SandboxDryRunJsonResult {
    <#
    .SYNOPSIS
        Projects dry-run execution state into stable JSON contract shape.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Selection,
        [Parameter(Mandatory)][string]$NetworkingMode,
        [Parameter(Mandatory)][object[]]$SetupState,
        [Parameter(Mandatory)][PSCustomObject]$Artifacts,
        [object[]]$PrerequisiteChecks,
        [switch]$SkipPrereqCheck,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [string]$ResolvedSharedFolder,
        [switch]$SharedFolderWritable,
        [Parameter(Mandatory)][PSCustomObject]$HostInteractionPolicy
    )

    return [ordered]@{
        command = [ordered]@{
            mode = 'dry-run'
        }
        profile = [ordered]@{
            selected = $Selection.Profile
            resolved_type = $Selection.ProfileType
            base_profile = $Selection.BaseProfile
        }
        overrides = [ordered]@{
            add_tools = @($Selection.RuntimeAddTools)
            remove_tools = @($Selection.RuntimeRemoveTools)
        }
        effective = [ordered]@{
            networking = $NetworkingMode
            host_interaction = [ordered]@{
                clipboard_redirection = $HostInteractionPolicy.ClipboardRedirection
                audio_input = $HostInteractionPolicy.AudioInput
                startup_commands_enabled = [bool]$HostInteractionPolicy.StartupCommandsEnabled
            }
            tools = @(
                $Selection.Tools | ForEach-Object {
                    [ordered]@{
                        id = $_.id
                        display_name = $_.display_name
                        installer_type = $_.installer_type
                        install_order = $_.install_order
                    }
                }
            )
        }
        stages = [ordered]@{
            download = [ordered]@{
                executed = $false
                skipped = $true
                reason = 'dry-run'
                setup_state = @($SetupState)
            }
            launch = [ordered]@{
                executed = $false
                skipped = $true
                reason = 'dry-run'
            }
        }
        artifacts = [ordered]@{
            install_manifest_path = $Artifacts.InstallManifestPath
            wsb_path = $Artifacts.WsbPath
        }
        context = [ordered]@{
            skip_prereq_check = [bool]$SkipPrereqCheck
            prerequisite_checks = @($PrerequisiteChecks)
            requested_shared_folder = if ($UseDefaultSharedFolder) { 'default' } else { $SharedFolder }
            resolved_shared_folder = $ResolvedSharedFolder
            shared_folder_writable = [bool]$SharedFolderWritable
            host_interaction_requested = [ordered]@{
                disable_clipboard = [bool]$HostInteractionPolicy.RequestedDisableClipboard
                disable_audio_input = [bool]$HostInteractionPolicy.RequestedDisableAudioInput
                disable_startup_commands = [bool]$HostInteractionPolicy.RequestedDisableStartupCommands
            }
        }
    }
}

function Get-SandboxAuditJsonResult {
    <#
    .SYNOPSIS
        Projects audit execution state and checks into stable JSON contract shape.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$AuditResult,
        [Parameter(Mandatory)][PSCustomObject]$Selection,
        [Parameter(Mandatory)][string]$NetworkingMode,
        [Parameter(Mandatory)][PSCustomObject]$Artifacts,
        [Parameter(Mandatory)][int]$ExitCode,
        [switch]$SkipPrereqCheck,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [string]$ResolvedSharedFolder,
        [switch]$SharedFolderWritable,
        [Parameter(Mandatory)][PSCustomObject]$HostInteractionPolicy
    )

    return [ordered]@{
        command = [ordered]@{
            mode = 'audit'
        }
        overall_status = Get-SandboxCheckStatusSummary -Checks $AuditResult.Checks
        exit_code = $ExitCode
        profile = [ordered]@{
            selected = $Selection.Profile
            resolved_type = $Selection.ProfileType
            base_profile = $Selection.BaseProfile
        }
        overrides = [ordered]@{
            add_tools = @($Selection.RuntimeAddTools)
            remove_tools = @($Selection.RuntimeRemoveTools)
        }
        effective = [ordered]@{
            networking_requested = $NetworkingMode
            host_interaction_requested = [ordered]@{
                clipboard_redirection = $HostInteractionPolicy.ClipboardRedirection
                audio_input = $HostInteractionPolicy.AudioInput
                startup_commands_enabled = [bool]$HostInteractionPolicy.StartupCommandsEnabled
            }
            tools = @(
                $Selection.Tools | ForEach-Object {
                    [ordered]@{
                        id = $_.id
                        display_name = $_.display_name
                        installer_type = $_.installer_type
                        install_order = $_.install_order
                    }
                }
            )
        }
        artifacts = [ordered]@{
            install_manifest_path = $Artifacts.InstallManifestPath
            wsb_path = $Artifacts.WsbPath
        }
        checks = @(
            $AuditResult.Checks | ForEach-Object {
                [ordered]@{
                    id = $_.Name
                    status = $_.Status
                    summary = $_.Message
                    remediation = $_.Remediation
                }
            }
        )
        context = [ordered]@{
            skip_prereq_check = [bool]$SkipPrereqCheck
            requested_shared_folder = if ($UseDefaultSharedFolder) { 'default' } else { $SharedFolder }
            resolved_shared_folder = $ResolvedSharedFolder
            shared_folder_writable = [bool]$SharedFolderWritable
            runtime_verification = 'not_performed'
            host_interaction_requested = [ordered]@{
                disable_clipboard = [bool]$HostInteractionPolicy.RequestedDisableClipboard
                disable_audio_input = [bool]$HostInteractionPolicy.RequestedDisableAudioInput
                disable_startup_commands = [bool]$HostInteractionPolicy.RequestedDisableStartupCommands
            }
        }
    }
}

function Get-SandboxListToolsJsonResult {
    <#
    .SYNOPSIS
        Projects list-tools catalog into stable JSON contract shape.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Tools
    )

    return [ordered]@{
        command = [ordered]@{
            mode = 'list-tools'
        }
        tools = @(
            $Tools | ForEach-Object {
                [ordered]@{
                    id = $_.id
                    display_name = $_.display_name
                    installer_type = $_.installer_type
                    install_order = $_.install_order
                    category = $_.category
                    profiles = @($_.profiles)
                }
            }
        )
    }
}

function Get-SandboxListProfilesJsonResult {
    <#
    .SYNOPSIS
        Projects list-profiles catalog into stable JSON contract shape.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Profiles
    )

    return [ordered]@{
        command = [ordered]@{
            mode = 'list-profiles'
        }
        profiles = @(
            $Profiles | ForEach-Object {
                [ordered]@{
                    name = $_.name
                    type = $_.profile_type
                    base_profile = $_.base_profile
                }
            }
        )
    }
}

function Get-SandboxErrorJsonResult {
    <#
    .SYNOPSIS
        Projects fatal script errors for JSON output mode.
    #>
    param(
        [Parameter(Mandatory)][string]$CommandMode,
        [Parameter(Mandatory)][string]$Message
    )

    return [ordered]@{
        command = [ordered]@{
            mode = $CommandMode
        }
        overall_status = 'FAIL'
        exit_code = 1
        error = [ordered]@{
            summary = $Message
        }
    }
}

function Write-SandboxJsonOutput {
    <#
    .SYNOPSIS
        Emits compact JSON to stdout for automation consumption.
    #>
    param(
        [Parameter(Mandatory)][object]$Data
    )

    [Console]::Out.WriteLine(($Data | ConvertTo-Json -Depth 20))
}
