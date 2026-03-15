# src/Cli.ps1
# CLI mode and output helpers for Start-Sandbox.ps1.

function Get-StartSandboxParameterCombinationError {
    param(
        [Parameter(Mandatory)][string]$Message
    )

    return "Invalid parameter combination: $Message"
}

function Resolve-StartSandboxCommandMode {
    <#
    .SYNOPSIS
        Resolves Start-Sandbox invocation mode and validates incompatible combinations.
    #>
    param(
        [string]$Template,
        [string]$SaveTemplate,
        [switch]$ListTemplates,
        [string]$ShowTemplate,
        [switch]$CleanDownloads,
        [switch]$ListTools,
        [switch]$ListProfiles,
        [switch]$CheckForUpdates,
        [switch]$Validate,
        [switch]$Audit,
        [switch]$DryRun,
        [switch]$Force,
        [switch]$NoLaunch,
        [switch]$OutputJson,
        [string[]]$AddTools,
        [string[]]$RemoveTools,
        [switch]$SkipPrereqCheck,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [switch]$SharedFolderValidationDiagnostics,
        [switch]$DisableClipboard,
        [switch]$DisableAudioInput,
        [switch]$DisableStartupCommands,
        [ValidateSet('Fresh', 'Warm')][string]$SessionMode = 'Fresh',
        [switch]$UseWslHelper,
        [switch]$ExplicitWslDistro,
        [switch]$ExplicitWslHelperStagePath,
        [switch]$ExplicitSandboxProfile
    )

    if ($Template) {
        if ($SaveTemplate -or $ListTemplates -or $ShowTemplate) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Template cannot be combined with -SaveTemplate, -ListTemplates, or -ShowTemplate.')
        }
        if ($ListTools -or $ListProfiles) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Template cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($CleanDownloads) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Template cannot be combined with -CleanDownloads.')
        }
    }

    if ($SaveTemplate) {
        if ($ListTemplates -or $ShowTemplate) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SaveTemplate cannot be combined with -ListTemplates or -ShowTemplate.')
        }
        if ($CleanDownloads -or $ListTools -or $ListProfiles -or $CheckForUpdates -or $Validate -or $Audit -or $DryRun) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SaveTemplate cannot be combined with command-mode switches.')
        }
        if ($Force -or $NoLaunch -or $OutputJson) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SaveTemplate cannot be combined with -Force, -NoLaunch, or -OutputJson.')
        }
    }

    if ($ListTemplates) {
        if ($ShowTemplate) {
            throw (Get-StartSandboxParameterCombinationError -Message '-ListTemplates cannot be combined with -ShowTemplate.')
        }
        if ($SaveTemplate -or $CleanDownloads -or $ListTools -or $ListProfiles -or $CheckForUpdates -or $Validate -or $Audit -or $DryRun) {
            throw (Get-StartSandboxParameterCombinationError -Message '-ListTemplates cannot be combined with other command-mode switches.')
        }
        if ($Force -or $NoLaunch -or $OutputJson) {
            throw (Get-StartSandboxParameterCombinationError -Message '-ListTemplates cannot be combined with -Force, -NoLaunch, or -OutputJson.')
        }
    }

    if ($ShowTemplate) {
        if ($SaveTemplate -or $ListTemplates -or $CleanDownloads -or $ListTools -or $ListProfiles -or $CheckForUpdates -or $Validate -or $Audit -or $DryRun) {
            throw (Get-StartSandboxParameterCombinationError -Message '-ShowTemplate cannot be combined with other command-mode switches.')
        }
        if ($Force -or $NoLaunch -or $OutputJson) {
            throw (Get-StartSandboxParameterCombinationError -Message '-ShowTemplate cannot be combined with -Force, -NoLaunch, or -OutputJson.')
        }
    }

    if ($CleanDownloads) {
        if ($ListTools -or $ListProfiles) {
            throw (Get-StartSandboxParameterCombinationError -Message '-CleanDownloads cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($Validate) {
            throw (Get-StartSandboxParameterCombinationError -Message '-CleanDownloads cannot be combined with -Validate.')
        }
        if ($Audit) {
            throw (Get-StartSandboxParameterCombinationError -Message '-CleanDownloads cannot be combined with -Audit.')
        }
        if ($DryRun) {
            throw (Get-StartSandboxParameterCombinationError -Message '-CleanDownloads cannot be combined with -DryRun.')
        }
        if ($Force) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Force cannot be combined with -CleanDownloads.')
        }
        if ($NoLaunch) {
            throw (Get-StartSandboxParameterCombinationError -Message '-NoLaunch cannot be combined with -CleanDownloads.')
        }
        if ($OutputJson) {
            throw (Get-StartSandboxParameterCombinationError -Message '-OutputJson cannot be combined with -CleanDownloads.')
        }
        if ($AddTools -or $RemoveTools) {
            throw (Get-StartSandboxParameterCombinationError -Message '-AddTools and -RemoveTools cannot be combined with -CleanDownloads.')
        }
        if ($SkipPrereqCheck) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SkipPrereqCheck cannot be combined with -CleanDownloads.')
        }
        if ($SharedFolder -or $UseDefaultSharedFolder -or $SharedFolderWritable -or $SharedFolderValidationDiagnostics) {
            throw (Get-StartSandboxParameterCombinationError -Message 'Shared-folder options cannot be combined with -CleanDownloads.')
        }
        if ($DisableClipboard -or $DisableAudioInput -or $DisableStartupCommands) {
            throw (Get-StartSandboxParameterCombinationError -Message 'Host-interaction policy options cannot be combined with -CleanDownloads.')
        }
        if ($SessionMode -ne 'Fresh') {
            throw (Get-StartSandboxParameterCombinationError -Message '-SessionMode cannot be specified with -CleanDownloads.')
        }
        if ($UseWslHelper -or $ExplicitWslDistro -or $ExplicitWslHelperStagePath) {
            throw (Get-StartSandboxParameterCombinationError -Message 'WSL helper options cannot be combined with -CleanDownloads.')
        }
        if ($ExplicitSandboxProfile) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SandboxProfile cannot be specified with -CleanDownloads.')
        }
    }

    $isListMode = $ListTools -or $ListProfiles
    if ($isListMode) {
        if ($Validate) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Validate cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($Audit) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Audit cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($DryRun) {
            throw (Get-StartSandboxParameterCombinationError -Message '-DryRun cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($Force) {
            throw (Get-StartSandboxParameterCombinationError -Message '-Force cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($NoLaunch) {
            throw (Get-StartSandboxParameterCombinationError -Message '-NoLaunch cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($SkipPrereqCheck) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SkipPrereqCheck cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($SharedFolder -or $UseDefaultSharedFolder -or $SharedFolderWritable -or $SharedFolderValidationDiagnostics) {
            throw (Get-StartSandboxParameterCombinationError -Message 'Shared-folder options cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($DisableClipboard -or $DisableAudioInput -or $DisableStartupCommands) {
            throw (Get-StartSandboxParameterCombinationError -Message 'Host-interaction policy options cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($SessionMode -ne 'Fresh') {
            throw (Get-StartSandboxParameterCombinationError -Message '-SessionMode cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($UseWslHelper -or $ExplicitWslDistro -or $ExplicitWslHelperStagePath) {
            throw (Get-StartSandboxParameterCombinationError -Message 'WSL helper options cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($AddTools -or $RemoveTools) {
            throw (Get-StartSandboxParameterCombinationError -Message '-AddTools and -RemoveTools cannot be combined with -ListTools or -ListProfiles.')
        }
        if ($ExplicitSandboxProfile) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SandboxProfile cannot be specified with -ListTools or -ListProfiles.')
        }
    }

    if ($CheckForUpdates) {
        if ($CleanDownloads -or $ListTools -or $ListProfiles -or $Validate -or $Audit -or $DryRun) {
            throw (Get-StartSandboxParameterCombinationError -Message '-CheckForUpdates cannot be combined with other command-mode switches.')
        }
        if ($Force -or $NoLaunch) {
            throw (Get-StartSandboxParameterCombinationError -Message '-CheckForUpdates cannot be combined with -Force or -NoLaunch.')
        }
        if ($SkipPrereqCheck) {
            throw (Get-StartSandboxParameterCombinationError -Message '-SkipPrereqCheck cannot be combined with -CheckForUpdates.')
        }
        if ($SharedFolder -or $UseDefaultSharedFolder -or $SharedFolderWritable -or $SharedFolderValidationDiagnostics) {
            throw (Get-StartSandboxParameterCombinationError -Message 'Shared-folder options cannot be combined with -CheckForUpdates.')
        }
        if ($DisableClipboard -or $DisableAudioInput -or $DisableStartupCommands) {
            throw (Get-StartSandboxParameterCombinationError -Message 'Host-interaction policy options cannot be combined with -CheckForUpdates.')
        }
        if ($SessionMode -ne 'Fresh') {
            throw (Get-StartSandboxParameterCombinationError -Message '-SessionMode cannot be combined with -CheckForUpdates.')
        }
        if ($UseWslHelper -or $ExplicitWslDistro -or $ExplicitWslHelperStagePath) {
            throw (Get-StartSandboxParameterCombinationError -Message 'WSL helper options cannot be combined with -CheckForUpdates.')
        }
    }

    if ($DryRun -and $Force) {
        throw (Get-StartSandboxParameterCombinationError -Message '-Force cannot be combined with -DryRun.')
    }

    if ($Validate -and $DryRun) {
        throw (Get-StartSandboxParameterCombinationError -Message '-Validate cannot be combined with -DryRun.')
    }
    if ($Validate -and $Audit) {
        throw (Get-StartSandboxParameterCombinationError -Message '-Validate cannot be combined with -Audit.')
    }
    if ($Validate -and $Force) {
        throw (Get-StartSandboxParameterCombinationError -Message '-Force cannot be combined with -Validate.')
    }
    if ($Validate -and $NoLaunch) {
        throw (Get-StartSandboxParameterCombinationError -Message '-NoLaunch cannot be combined with -Validate.')
    }
    if ($Audit -and $DryRun) {
        throw (Get-StartSandboxParameterCombinationError -Message '-Audit cannot be combined with -DryRun.')
    }
    if ($Audit -and $Force) {
        throw (Get-StartSandboxParameterCombinationError -Message '-Force cannot be combined with -Audit.')
    }
    if ($Audit -and $NoLaunch) {
        throw (Get-StartSandboxParameterCombinationError -Message '-NoLaunch cannot be combined with -Audit.')
    }
    if ($OutputJson -and $ListTools -and $ListProfiles) {
        throw (Get-StartSandboxParameterCombinationError -Message '-OutputJson cannot be combined with both -ListTools and -ListProfiles. Choose one list mode.')
    }
    if ($OutputJson -and -not ($Validate -or $Audit -or $DryRun -or $CheckForUpdates -or $isListMode)) {
        throw (Get-StartSandboxParameterCombinationError -Message '-OutputJson is supported only with -Validate, -Audit, -DryRun, -CheckForUpdates, -ListTools, or -ListProfiles.')
    }
    if (-not $UseWslHelper -and ($ExplicitWslDistro -or $ExplicitWslHelperStagePath)) {
        throw (Get-StartSandboxParameterCombinationError -Message '-WslDistro and -WslHelperStagePath require -UseWslHelper.')
    }

    if ($CleanDownloads) {
        return 'CleanDownloads'
    }
    if ($SaveTemplate) {
        return 'SaveTemplate'
    }
    if ($ListTemplates) {
        return 'ListTemplates'
    }
    if ($ShowTemplate) {
        return 'ShowTemplate'
    }
    if ($isListMode) {
        return 'List'
    }
    if ($CheckForUpdates) {
        return 'CheckForUpdates'
    }
    if ($Validate) {
        return 'Validate'
    }
    if ($Audit) {
        return 'Audit'
    }
    if ($DryRun) {
        return 'DryRun'
    }
    return 'Run'
}

function Get-StartSandboxModePlan {
    <#
    .SYNOPSIS
        Returns stage execution flags for each command mode.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('CleanDownloads', 'SaveTemplate', 'ListTemplates', 'ShowTemplate', 'List', 'CheckForUpdates', 'Validate', 'Audit', 'DryRun', 'Run')][string]$CommandMode
    )

    switch ($CommandMode) {
        'CleanDownloads' {
            return [pscustomobject]@{
                CheckPrerequisites = $false
                ResolveSharedFolder = $false
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'SaveTemplate' {
            return [pscustomobject]@{
                CheckPrerequisites = $false
                ResolveSharedFolder = $false
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'ListTemplates' {
            return [pscustomobject]@{
                CheckPrerequisites = $false
                ResolveSharedFolder = $false
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'ShowTemplate' {
            return [pscustomobject]@{
                CheckPrerequisites = $false
                ResolveSharedFolder = $false
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'List' {
            return [pscustomobject]@{
                CheckPrerequisites = $false
                ResolveSharedFolder = $false
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'CheckForUpdates' {
            return [pscustomobject]@{
                CheckPrerequisites = $false
                ResolveSharedFolder = $false
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'Validate' {
            return [pscustomobject]@{
                CheckPrerequisites = $true
                ResolveSharedFolder = $true
                DownloadTools = $false
                GenerateArtifacts = $false
                LaunchSandbox = $false
            }
        }
        'DryRun' {
            return [pscustomobject]@{
                CheckPrerequisites = $true
                ResolveSharedFolder = $true
                DownloadTools = $false
                GenerateArtifacts = $true
                LaunchSandbox = $false
            }
        }
        'Audit' {
            return [pscustomobject]@{
                CheckPrerequisites = $true
                ResolveSharedFolder = $true
                DownloadTools = $false
                GenerateArtifacts = $true
                LaunchSandbox = $false
            }
        }
        default {
            return [pscustomobject]@{
                CheckPrerequisites = $true
                ResolveSharedFolder = $true
                DownloadTools = $true
                GenerateArtifacts = $true
                LaunchSandbox = $true
            }
        }
    }
}

function Get-ManifestToolCatalog {
    <#
    .SYNOPSIS
        Returns a stable, sorted tool catalog from the manifest.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest
    )

    return @(
        $Manifest.tools |
            Sort-Object install_order |
            ForEach-Object {
                [pscustomobject]@{
                    id            = $_.id
                    display_name  = $_.display_name
                    category      = $_.category
                    profiles      = @($_.profiles)
                    installer_type = $_.installer_type
                    source_type   = $_.source_type
                    install_order = $_.install_order
                    filename      = $_.filename
                }
            }
    )
}

function Get-ToolSetupState {
    <#
    .SYNOPSIS
        Returns setup cache state for selected tools.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Tools,
        [Parameter(Mandatory)][string]$SetupDir
    )

    return @(
        $Tools | ForEach-Object {
            $setupPath = Join-Path $SetupDir $_.filename
            [pscustomobject]@{
                id        = $_.id
                display_name = $_.display_name
                filename  = $_.filename
                setup_path = $setupPath
                cached    = [bool](Test-Path -LiteralPath $setupPath -PathType Leaf)
            }
        }
    )
}

function Invoke-SandboxLaunch {
    <#
    .SYNOPSIS
        Launches Windows Sandbox unless launch is intentionally suppressed.
    #>
    param(
        [Parameter(Mandatory)][string]$WsbPath,
        [switch]$NoLaunch,
        [switch]$DryRun,
        [ScriptBlock]$Launcher
    )

    if (-not $Launcher) {
        $Launcher = {
            param($Path)
            Start-Process -FilePath $Path
        }
    }

    if ($DryRun) {
        return [pscustomobject]@{
            Launched = $false
            Reason   = 'DryRun'
        }
    }

    if ($NoLaunch) {
        return [pscustomobject]@{
            Launched = $false
            Reason   = 'NoLaunch'
        }
    }

    & $Launcher $WsbPath

    return [pscustomobject]@{
        Launched = $true
        Reason   = 'Launched'
    }
}
