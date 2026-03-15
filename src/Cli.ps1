# src/Cli.ps1
# CLI mode and output helpers for Start-Sandbox.ps1.

function Resolve-StartSandboxCommandMode {
    <#
    .SYNOPSIS
        Resolves Start-Sandbox invocation mode and validates incompatible combinations.
    #>
    param(
        [switch]$CleanDownloads,
        [switch]$ListTools,
        [switch]$ListProfiles,
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

    if ($CleanDownloads) {
        if ($ListTools -or $ListProfiles) {
            throw "-CleanDownloads cannot be combined with -ListTools or -ListProfiles."
        }
        if ($Validate) {
            throw "-CleanDownloads cannot be combined with -Validate."
        }
        if ($Audit) {
            throw "-CleanDownloads cannot be combined with -Audit."
        }
        if ($DryRun) {
            throw "-CleanDownloads cannot be combined with -DryRun."
        }
        if ($Force) {
            throw "-Force cannot be combined with -CleanDownloads."
        }
        if ($NoLaunch) {
            throw "-NoLaunch cannot be combined with -CleanDownloads."
        }
        if ($OutputJson) {
            throw "-OutputJson cannot be combined with -CleanDownloads."
        }
        if ($AddTools -or $RemoveTools) {
            throw "-AddTools and -RemoveTools cannot be combined with -CleanDownloads."
        }
        if ($SkipPrereqCheck) {
            throw "-SkipPrereqCheck cannot be combined with -CleanDownloads."
        }
        if ($SharedFolder -or $UseDefaultSharedFolder -or $SharedFolderWritable -or $SharedFolderValidationDiagnostics) {
            throw "Shared-folder options cannot be combined with -CleanDownloads."
        }
        if ($DisableClipboard -or $DisableAudioInput -or $DisableStartupCommands) {
            throw "Host-interaction policy options cannot be combined with -CleanDownloads."
        }
        if ($SessionMode -ne 'Fresh') {
            throw "-SessionMode cannot be specified with -CleanDownloads."
        }
        if ($UseWslHelper -or $ExplicitWslDistro -or $ExplicitWslHelperStagePath) {
            throw "WSL helper options cannot be combined with -CleanDownloads."
        }
        if ($ExplicitSandboxProfile) {
            throw "-SandboxProfile cannot be specified with -CleanDownloads."
        }
    }

    $isListMode = $ListTools -or $ListProfiles
    if ($isListMode) {
        if ($Validate) {
            throw "-Validate cannot be combined with -ListTools or -ListProfiles."
        }
        if ($Audit) {
            throw "-Audit cannot be combined with -ListTools or -ListProfiles."
        }
        if ($DryRun) {
            throw "-DryRun cannot be combined with -ListTools or -ListProfiles."
        }
        if ($Force) {
            throw "-Force cannot be combined with -ListTools or -ListProfiles."
        }
        if ($SharedFolder -or $UseDefaultSharedFolder -or $SharedFolderWritable -or $SharedFolderValidationDiagnostics) {
            throw "Shared-folder options cannot be combined with -ListTools or -ListProfiles."
        }
        if ($DisableClipboard -or $DisableAudioInput -or $DisableStartupCommands) {
            throw "Host-interaction policy options cannot be combined with -ListTools or -ListProfiles."
        }
        if ($SessionMode -ne 'Fresh') {
            throw "-SessionMode cannot be combined with -ListTools or -ListProfiles."
        }
        if ($UseWslHelper -or $ExplicitWslDistro -or $ExplicitWslHelperStagePath) {
            throw "WSL helper options cannot be combined with -ListTools or -ListProfiles."
        }
        if ($AddTools -or $RemoveTools) {
            throw "-AddTools and -RemoveTools cannot be combined with -ListTools or -ListProfiles."
        }
        if ($ExplicitSandboxProfile) {
            throw "-SandboxProfile cannot be specified with -ListTools or -ListProfiles."
        }
    }

    if ($DryRun -and $Force) {
        throw "-Force cannot be combined with -DryRun."
    }

    if ($Validate -and $DryRun) {
        throw "-Validate cannot be combined with -DryRun."
    }
    if ($Validate -and $Audit) {
        throw "-Validate cannot be combined with -Audit."
    }
    if ($Validate -and $Force) {
        throw "-Force cannot be combined with -Validate."
    }
    if ($Validate -and $NoLaunch) {
        throw "-NoLaunch cannot be combined with -Validate."
    }
    if ($Audit -and $DryRun) {
        throw "-Audit cannot be combined with -DryRun."
    }
    if ($Audit -and $Force) {
        throw "-Force cannot be combined with -Audit."
    }
    if ($Audit -and $NoLaunch) {
        throw "-NoLaunch cannot be combined with -Audit."
    }
    if ($OutputJson -and $ListTools -and $ListProfiles) {
        throw "-OutputJson cannot be combined with both -ListTools and -ListProfiles. Choose one list mode."
    }
    if ($OutputJson -and -not ($Validate -or $Audit -or $DryRun -or $isListMode)) {
        throw "-OutputJson is supported only with -Validate, -Audit, -DryRun, -ListTools, or -ListProfiles."
    }
    if (-not $UseWslHelper -and ($ExplicitWslDistro -or $ExplicitWslHelperStagePath)) {
        throw "-WslDistro and -WslHelperStagePath require -UseWslHelper."
    }

    if ($CleanDownloads) {
        return 'CleanDownloads'
    }
    if ($isListMode) {
        return 'List'
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
        [Parameter(Mandatory)][ValidateSet('CleanDownloads', 'List', 'Validate', 'Audit', 'DryRun', 'Run')][string]$CommandMode
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
        'List' {
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
