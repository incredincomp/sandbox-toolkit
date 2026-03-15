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
        [PSCustomObject]$HostInteractionPolicy,
        [PSCustomObject]$SessionLifecycleState,
        [PSCustomObject]$WslHelperState
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
            session = [ordered]@{
                requested_mode = if ($SessionLifecycleState) { $SessionLifecycleState.RequestedMode } else { 'Fresh' }
                effective_mode = if ($SessionLifecycleState) { $SessionLifecycleState.EffectiveMode } else { 'Fresh' }
                warm_support = [ordered]@{
                    supported = if ($SessionLifecycleState) { [bool]$SessionLifecycleState.WarmSupport.Supported } else { $false }
                    reason = if ($SessionLifecycleState) { $SessionLifecycleState.WarmSupport.Reason } else { $null }
                    running_session_count = if ($SessionLifecycleState) { $SessionLifecycleState.RunningSessionCount } else { 0 }
                }
            }
            wsl_helper = [ordered]@{
                enabled = if ($WslHelperState) { [bool]$WslHelperState.Enabled } else { $false }
                requested_distro = if ($WslHelperState) { $WslHelperState.RequestedDistro } else { $null }
                effective_distro = if ($WslHelperState) { $WslHelperState.EffectiveDistro } else { $null }
                stage_path = if ($WslHelperState) { $WslHelperState.StagePath } else { $null }
                supported = if ($WslHelperState) { [bool]($WslHelperState.WslCommandAvailable -and $WslHelperState.DistroAvailable) } else { $false }
                support_reason = if ($WslHelperState) { $WslHelperState.SupportReason } else { $null }
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
        [Parameter(Mandatory)][PSCustomObject]$HostInteractionPolicy,
        [Parameter(Mandatory)][PSCustomObject]$SessionLifecycleState,
        [Parameter(Mandatory)][PSCustomObject]$WslHelperState,
        [PSCustomObject]$WslHelperResult
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
            session = [ordered]@{
                requested_mode = $SessionLifecycleState.RequestedMode
                effective_mode = $SessionLifecycleState.EffectiveMode
                warm_support = [ordered]@{
                    supported = [bool]$SessionLifecycleState.WarmSupport.Supported
                    reason = $SessionLifecycleState.WarmSupport.Reason
                    running_session_count = $SessionLifecycleState.RunningSessionCount
                }
                warm_plan = if ($SessionLifecycleState.RequestedMode -eq 'Warm') {
                    if (-not $SessionLifecycleState.WarmSupport.Supported) {
                        'unsupported'
                    } elseif ($SessionLifecycleState.RunningSessionCount -gt 0) {
                        'reuse-existing-session'
                    } else {
                        'create-new-session'
                    }
                } else {
                    'fresh-launch'
                }
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
            wsl_helper = [ordered]@{
                enabled = [bool]$WslHelperState.Enabled
                requested_distro = $WslHelperState.RequestedDistro
                effective_distro = $WslHelperState.EffectiveDistro
                stage_path = $WslHelperState.StagePath
                supported = [bool]($WslHelperState.WslCommandAvailable -and $WslHelperState.DistroAvailable)
                support_reason = $WslHelperState.SupportReason
                executed = if ($WslHelperResult) { [bool]$WslHelperResult.Executed } else { $false }
                payload_sha256 = if ($WslHelperResult) { $WslHelperResult.PayloadHash } else { $null }
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
        [Parameter(Mandatory)][PSCustomObject]$HostInteractionPolicy,
        [Parameter(Mandatory)][PSCustomObject]$SessionLifecycleState,
        [Parameter(Mandatory)][PSCustomObject]$WslHelperState
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
            session = [ordered]@{
                requested_mode = $SessionLifecycleState.RequestedMode
                effective_mode = $SessionLifecycleState.EffectiveMode
                warm_support = [ordered]@{
                    supported = [bool]$SessionLifecycleState.WarmSupport.Supported
                    reason = $SessionLifecycleState.WarmSupport.Reason
                    running_session_count = $SessionLifecycleState.RunningSessionCount
                }
            }
            wsl_helper = [ordered]@{
                enabled = [bool]$WslHelperState.Enabled
                requested_distro = $WslHelperState.RequestedDistro
                effective_distro = $WslHelperState.EffectiveDistro
                stage_path = $WslHelperState.StagePath
                supported = [bool]($WslHelperState.WslCommandAvailable -and $WslHelperState.DistroAvailable)
                support_reason = $WslHelperState.SupportReason
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

function Get-SandboxCheckForUpdatesJsonResult {
    <#
    .SYNOPSIS
        Projects check-for-updates results into stable JSON contract shape.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Selection,
        [Parameter(Mandatory)][object[]]$Results
    )

    $summary = Get-SandboxToolUpdateSummary -Results $Results
    return [ordered]@{
        command = [ordered]@{
            mode = 'check-for-updates'
        }
        profile = [ordered]@{
            selected = $Selection.Profile
            resolved_type = $Selection.ProfileType
            base_profile = $Selection.BaseProfile
        }
        overrides = [ordered]@{
            template_add_tools = @($Selection.TemplateAddTools)
            template_remove_tools = @($Selection.TemplateRemoveTools)
            add_tools = @($Selection.RuntimeAddTools)
            remove_tools = @($Selection.RuntimeRemoveTools)
        }
        summary = [ordered]@{
            total = $summary.total
            up_to_date = $summary.up_to_date
            outdated = $summary.outdated
            unknown = $summary.unknown
            unsupported_for_checking = $summary.unsupported
        }
        tools = @(
            $Results | ForEach-Object {
                [ordered]@{
                    id = $_.id
                    display_name = $_.display_name
                    configured_version = $_.configured_version
                    latest_version = $_.latest_version
                    status = $_.status
                    source_type = $_.source_type
                    source_confidence = $_.source_confidence
                    message = $_.message
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
        [switch]$ListTools,
        [switch]$ListProfiles,
        [Parameter(Mandatory)][string]$Message
    )

    $resolvedMode = switch ($CommandMode) {
        'Validate' { 'validate' }
        'Audit' { 'audit' }
        'DryRun' { 'dry-run' }
        'Run' { 'run' }
        'List' {
            if ($ListProfiles) {
                'list-profiles'
            } elseif ($ListTools) {
                'list-tools'
            } else {
                'list'
            }
        }
        'CheckForUpdates' { 'check-for-updates' }
        'CleanDownloads' { 'clean-downloads' }
        default { $CommandMode }
    }

    return [ordered]@{
        command = [ordered]@{
            mode = $resolvedMode
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
