# src/Cli.ps1
# CLI mode and output helpers for Start-Sandbox.ps1.

function Resolve-StartSandboxCommandMode {
    <#
    .SYNOPSIS
        Resolves Start-Sandbox invocation mode and validates incompatible combinations.
    #>
    param(
        [switch]$ListTools,
        [switch]$ListProfiles,
        [switch]$Validate,
        [switch]$DryRun,
        [switch]$Force,
        [switch]$NoLaunch,
        [string[]]$AddTools,
        [string[]]$RemoveTools,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [switch]$SharedFolderValidationDiagnostics,
        [switch]$ExplicitSandboxProfile
    )

    $isListMode = $ListTools -or $ListProfiles
    if ($isListMode) {
        if ($Validate) {
            throw "-Validate cannot be combined with -ListTools or -ListProfiles."
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
    if ($Validate -and $Force) {
        throw "-Force cannot be combined with -Validate."
    }
    if ($Validate -and $NoLaunch) {
        throw "-NoLaunch cannot be combined with -Validate."
    }

    if ($isListMode) {
        return 'List'
    }
    if ($Validate) {
        return 'Validate'
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
        [Parameter(Mandatory)][ValidateSet('List', 'Validate', 'DryRun', 'Run')][string]$CommandMode
    )

    switch ($CommandMode) {
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
