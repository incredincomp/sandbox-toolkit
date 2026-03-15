# src/Validation.ps1
# Reusable non-destructive preflight checks for Start-Sandbox.ps1.

function Get-SandboxValidationCheck {
    <#
    .SYNOPSIS
        Creates a structured validation result entry.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Remediation
    )

    return [pscustomobject]@{
        Name        = $Name
        Status      = $Status
        Message     = $Message
        Remediation = $Remediation
    }
}

function Test-SandboxHostPrerequisite {
    <#
    .SYNOPSIS
        Checks host prerequisites used by the normal launch flow.
    #>
    param(
        [switch]$SkipPrereqCheck
    )

    $results = [System.Collections.Generic.List[object]]::new()

    if ($SkipPrereqCheck) {
        $results.Add((Get-SandboxValidationCheck `
            -Name 'prerequisites' `
            -Status 'WARN' `
            -Message 'Prerequisite checks skipped by -SkipPrereqCheck.' `
            -Remediation 'Run without -SkipPrereqCheck for full host validation.'))
        return @($results)
    }

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $results.Add((Get-SandboxValidationCheck `
            -Name 'powershell-version' `
            -Status 'FAIL' `
            -Message "PowerShell 5.1 or later is required. Found: $($PSVersionTable.PSVersion)" `
            -Remediation 'Install or run Windows PowerShell 5.1+ and retry.'))
        return @($results)
    }

    $results.Add((Get-SandboxValidationCheck `
        -Name 'powershell-version' `
        -Status 'PASS' `
        -Message "PowerShell version is supported: $($PSVersionTable.PSVersion)"))

    try {
        $feature = Get-WindowsOptionalFeature -FeatureName 'Containers-DisposableClientVM' -Online -ErrorAction Stop
        if ($feature.State -eq 'Enabled') {
            $results.Add((Get-SandboxValidationCheck `
                -Name 'windows-sandbox-feature' `
                -Status 'PASS' `
                -Message 'Windows Sandbox feature is enabled.'))
        } else {
            $results.Add((Get-SandboxValidationCheck `
                -Name 'windows-sandbox-feature' `
                -Status 'FAIL' `
                -Message "Windows Sandbox feature state is '$($feature.State)'." `
                -Remediation 'Run as Administrator: Enable-WindowsOptionalFeature -FeatureName Containers-DisposableClientVM -Online, then reboot.'))
        }
    } catch {
        $results.Add((Get-SandboxValidationCheck `
            -Name 'windows-sandbox-feature' `
            -Status 'WARN' `
            -Message "Could not verify Windows Sandbox feature: $($_.Exception.Message)" `
            -Remediation 'Verify the feature manually, or run with sufficient privileges.'))
    }

    return @($results)
}

function Test-SandboxSelectionReadiness {
    <#
    .SYNOPSIS
        Validates manifest/profile selection readiness.
    #>
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [Parameter(Mandatory)][string]$CustomProfilePath,
        [string[]]$AddTools,
        [string[]]$RemoveTools
    )

    try {
        $manifest = Import-ToolManifest -ManifestPath $ManifestPath
        Test-ManifestIntegrity -Manifest $manifest
        $customProfileConfig = Import-CustomProfileConfig -CustomProfilePath $CustomProfilePath
        Test-CustomProfileConfigIntegrity -CustomProfileConfig $customProfileConfig -Manifest $manifest
        $selection = Resolve-SandboxSessionSelection `
            -Manifest $manifest `
            -SandboxProfile $SandboxProfile `
            -CustomProfileConfig $customProfileConfig `
            -AddTools $AddTools `
            -RemoveTools $RemoveTools
        $networking = Get-SandboxNetworkingMode -SandboxProfile $selection.BaseProfile

        return [pscustomobject]@{
            Check = Get-SandboxValidationCheck `
                -Name 'selection' `
                -Status 'PASS' `
                -Message "Profile '$SandboxProfile' selected $($selection.Tools.Count) tool(s); base=$($selection.BaseProfile); networking=$networking; add=$(@($selection.RuntimeAddTools).Count); remove=$(@($selection.RuntimeRemoveTools).Count)."
            Manifest = $manifest
            Selection = $selection
            NetworkingMode = $networking
        }
    } catch {
        return [pscustomobject]@{
            Check = Get-SandboxValidationCheck `
                -Name 'selection' `
                -Status 'FAIL' `
                -Message "Selection validation failed: $($_.Exception.Message)" `
                -Remediation 'Confirm profile/manifest inputs are valid and retry.'
            Manifest = $null
            Selection = $null
            NetworkingMode = $null
        }
    }
}

function Test-SandboxSharedFolderReadiness {
    <#
    .SYNOPSIS
        Validates shared-folder arguments without creating or mutating host folders.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [switch]$SharedFolderValidationDiagnostics
    )

    try {
        Assert-SharedFolderParameterUsage `
            -SharedFolder $SharedFolder `
            -UseDefaultSharedFolder:$UseDefaultSharedFolder `
            -SharedFolderWritable:$SharedFolderWritable
    } catch {
        return [pscustomobject]@{
            Check = Get-SandboxValidationCheck `
                -Name 'shared-folder' `
                -Status 'FAIL' `
                -Message $_.Exception.Message `
                -Remediation 'Use only supported shared-folder flag combinations.'
            ResolvedSharedFolder = $null
            SharedFolderWritable = [bool]$SharedFolderWritable
        }
    }

    if (-not $SharedFolder -and -not $UseDefaultSharedFolder) {
        return [pscustomobject]@{
            Check = Get-SandboxValidationCheck `
                -Name 'shared-folder' `
                -Status 'PASS' `
                -Message 'No shared folder requested.'
            ResolvedSharedFolder = $null
            SharedFolderWritable = $false
        }
    }

    $requestedSharedFolder = $SharedFolder
    if ($UseDefaultSharedFolder) {
        $requestedSharedFolder = Join-Path $RepoRoot 'shared'
        if (-not (Test-Path -LiteralPath $requestedSharedFolder -PathType Container)) {
            return [pscustomobject]@{
                Check = Get-SandboxValidationCheck `
                    -Name 'shared-folder' `
                    -Status 'WARN' `
                    -Message "Default shared folder does not exist yet: $requestedSharedFolder" `
                    -Remediation "Create '$requestedSharedFolder' before re-running -Validate, or run without -Validate to let the toolkit create it."
                ResolvedSharedFolder = $null
                SharedFolderWritable = [bool]$SharedFolderWritable
            }
        }
    }

    try {
        $resolved = Assert-SafeSharedFolderPath `
            -Path $requestedSharedFolder `
            -RepoRoot $RepoRoot `
            -Diagnostics:$SharedFolderValidationDiagnostics

        return [pscustomobject]@{
            Check = Get-SandboxValidationCheck `
                -Name 'shared-folder' `
                -Status 'PASS' `
                -Message "Shared folder path is valid: $resolved"
            ResolvedSharedFolder = $resolved
            SharedFolderWritable = [bool]$SharedFolderWritable
        }
    } catch {
        return [pscustomobject]@{
            Check = Get-SandboxValidationCheck `
                -Name 'shared-folder' `
                -Status 'FAIL' `
                -Message $_.Exception.Message `
                -Remediation 'Choose a dedicated, local, non-reparse ingress folder.'
            ResolvedSharedFolder = $null
            SharedFolderWritable = [bool]$SharedFolderWritable
        }
    }
}

function Invoke-SandboxPreflightValidation {
    <#
    .SYNOPSIS
        Runs non-destructive validation checks used by -Validate.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$CustomProfilePath,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [string[]]$AddTools,
        [string[]]$RemoveTools,
        [switch]$SkipPrereqCheck,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [switch]$SharedFolderValidationDiagnostics
    )

    $checks = [System.Collections.Generic.List[object]]::new()

    foreach ($prereqCheck in (Test-SandboxHostPrerequisite -SkipPrereqCheck:$SkipPrereqCheck)) {
        $checks.Add($prereqCheck)
    }

    $selectionResult = Test-SandboxSelectionReadiness `
        -ManifestPath $ManifestPath `
        -SandboxProfile $SandboxProfile `
        -CustomProfilePath $CustomProfilePath `
        -AddTools $AddTools `
        -RemoveTools $RemoveTools
    $checks.Add($selectionResult.Check)

    $sharedFolderResult = Test-SandboxSharedFolderReadiness `
        -RepoRoot $RepoRoot `
        -SharedFolder $SharedFolder `
        -UseDefaultSharedFolder:$UseDefaultSharedFolder `
        -SharedFolderWritable:$SharedFolderWritable `
        -SharedFolderValidationDiagnostics:$SharedFolderValidationDiagnostics
    $checks.Add($sharedFolderResult.Check)

    $hasFailures = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0
    $hasWarnings = @($checks | Where-Object { $_.Status -eq 'WARN' }).Count -gt 0

    return [pscustomobject]@{
        Checks = @($checks)
        HasFailures = $hasFailures
        HasWarnings = $hasWarnings
        Selection = $selectionResult.Selection
        NetworkingMode = $selectionResult.NetworkingMode
        SharedHostFolder = $sharedFolderResult.ResolvedSharedFolder
        SharedFolderWritable = $sharedFolderResult.SharedFolderWritable
    }
}

function Write-SandboxPreflightReport {
    <#
    .SYNOPSIS
        Renders validation results in a readable PASS/WARN/FAIL format.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$PreflightResult
    )

    Write-StatusLine '[Validate] Preflight checks' -ForegroundColor Yellow
    foreach ($check in $PreflightResult.Checks) {
        $color = switch ($check.Status) {
            'PASS' { [ConsoleColor]::Green }
            'WARN' { [ConsoleColor]::Yellow }
            default { [ConsoleColor]::Red }
        }

        Write-StatusLine ("  [{0}] {1}: {2}" -f $check.Status, $check.Name, $check.Message) -ForegroundColor $color
        if ($check.Remediation) {
            Write-StatusLine "         Remediation: $($check.Remediation)" -ForegroundColor DarkGray
        }
    }

    if ($PreflightResult.Selection) {
        Write-StatusLine ("  [INFO] profile={0} tools={1} networking={2}" -f `
                $PreflightResult.Selection.Profile, `
                $PreflightResult.Selection.Tools.Count, `
                $PreflightResult.NetworkingMode) -ForegroundColor DarkGray
    }
}

function Get-SandboxValidationExitCode {
    <#
    .SYNOPSIS
        Returns deterministic process exit code for validation mode.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$PreflightResult
    )

    if ($PreflightResult.HasFailures) {
        return 1
    }
    return 0
}
