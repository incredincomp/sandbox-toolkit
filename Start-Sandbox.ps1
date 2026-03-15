<#
.SYNOPSIS
    Bootstrap, download, configure, and optionally launch the Windows Sandbox malware-research toolkit.

.DESCRIPTION
    Start-Sandbox.ps1 is the single entry point for setting up the sandbox.

    Workflow:
      1. Check prerequisites (Windows Sandbox feature, PowerShell version).
      2. Load and validate tools.json; filter to selected profile.
      3. Download missing tool installers to scripts\setups\.
      4. Write session manifest and generate sandbox.wsb.
      5. Optionally launch Windows Sandbox.

    Profiles:
      minimal            -- editors, Python, Sysinternals only.
      reverse-engineering -- adds Ghidra, x64dbg, dnSpyEx, DIE, UPX, PE-bear, pestudio, HxD, FLOSS.
      network-analysis   -- reverse-engineering plus Wireshark/Npcap (networking enabled).
      full               -- all tools (networking enabled).

.PARAMETER Profile
    Install profile to use (built-in or custom). Default: reverse-engineering.

.PARAMETER Force
    Re-download all files even if they already exist locally.

.PARAMETER NoLaunch
    Download and configure only; do not launch Windows Sandbox.

.PARAMETER DryRun
    Resolve profile/tool selection and generate session artifacts without downloads or launch.

.PARAMETER Validate
    Run non-destructive preflight checks and report PASS/WARN/FAIL readiness.

.PARAMETER Audit
    Run host-side audit checks against generated sandbox artifacts to verify configured/requested settings.

.PARAMETER CleanDownloads
    Remove repo-owned disposable download/session artifacts and exit.

.PARAMETER ListTools
    Print all available tools from tools.json and exit.

.PARAMETER ListProfiles
    Print supported profiles present in tools.json and exit.

.PARAMETER AddTools
    Optional tool IDs to add to the selected profile at runtime.

.PARAMETER RemoveTools
    Optional tool IDs to remove from the selected profile at runtime.

.PARAMETER OutputJson
    Emit machine-readable JSON for -Validate, -Audit, -DryRun, -ListTools, or -ListProfiles modes.

.PARAMETER SkipPrereqCheck
    Skip the Windows Sandbox feature check (useful for CI or offline use).

.PARAMETER SharedFolder
    Optional existing host folder to map into sandbox at Desktop\shared.
    Read-only by default unless -SharedFolderWritable is set.

.PARAMETER UseDefaultSharedFolder
    Create/use repo-local .\shared as the optional mapped shared folder.
    Read-only by default unless -SharedFolderWritable is set.

.PARAMETER SharedFolderWritable
    Make the optional shared folder writable from inside the sandbox.
    Requires -SharedFolder or -UseDefaultSharedFolder.
    Use with caution for untrusted samples.

.PARAMETER SharedFolderValidationDiagnostics
    Emit verbose diagnostics for shared-folder ancestry checks.
    Helpful for troubleshooting reparse/junction validation failures.

.PARAMETER DisableClipboard
    Request `<ClipboardRedirection>Disable</ClipboardRedirection>` in generated sandbox.wsb.

.PARAMETER DisableAudioInput
    Request audio input disabled in generated sandbox.wsb.
    Audio input is already disabled by default; this switch is explicit and idempotent.

.PARAMETER DisableStartupCommands
    Suppress generated `<LogonCommand>` startup automation in sandbox.wsb.
    When set, scripts/autostart.cmd is not auto-invoked on sandbox startup.

.PARAMETER SessionMode
    Sandbox lifecycle mode. Fresh starts a clean disposable session; Warm attempts to reuse an existing session via Windows Sandbox CLI.

.PARAMETER UseWslHelper
    Enable optional WSL helper sidecar tasks for staging and helper metadata.

.PARAMETER WslDistro
    Optional WSL distro to use with -UseWslHelper. Defaults to the current WSL default distro.

.PARAMETER WslHelperStagePath
    Optional Linux-side staging directory path used by the WSL helper sidecar.

.EXAMPLE
    .\Start-Sandbox.ps1
    # Downloads tools for the default 'reverse-engineering' profile and launches.

.EXAMPLE
    .\Start-Sandbox.ps1 -Profile minimal -NoLaunch
    # Downloads minimal tools without launching.

.EXAMPLE
    .\Start-Sandbox.ps1 -DryRun -Profile network-analysis -SkipPrereqCheck
    # Shows effective network/tool configuration and generated artifact paths without launch.

.EXAMPLE
    .\Start-Sandbox.ps1 -Validate -Profile minimal
    # Runs preflight checks without downloading, generating artifacts, or launching.

.EXAMPLE
    .\Start-Sandbox.ps1 -Profile minimal -AddTools ghidra,wireshark -RemoveTools notepadpp
    # Starts from minimal profile, adds/removes tools at runtime, then launches.

.EXAMPLE
    .\Start-Sandbox.ps1 -Validate -OutputJson
    # Emits preflight validation as JSON for automation.

.EXAMPLE
    .\Start-Sandbox.ps1 -Audit -Profile minimal
    # Generates artifacts and audits configured/requested settings without launch.

.EXAMPLE
    .\Start-Sandbox.ps1 -CleanDownloads
    # Removes repo-owned setup cache and generated session artifacts.

.EXAMPLE
    .\Start-Sandbox.ps1 -ListProfiles
    # Prints supported profiles from the current manifest.

.EXAMPLE
    .\Start-Sandbox.ps1 -ListTools
    # Prints available tools from the current manifest.

.EXAMPLE
    .\Start-Sandbox.ps1 -Profile network-analysis -Force
    # Re-downloads all network-analysis tools and launches.

.EXAMPLE
.\Start-Sandbox.ps1 -UseDefaultSharedFolder
    # Maps .\shared into sandbox at Desktop\shared (read-only by default).

.EXAMPLE
.\Start-Sandbox.ps1 -DryRun -Profile minimal -DisableClipboard -DisableStartupCommands
    # Previews artifact generation with tighter host-interaction policy settings.

.EXAMPLE
.\Start-Sandbox.ps1 -SessionMode Warm -Profile minimal
    # Attempts warm-session reuse via Windows Sandbox CLI, otherwise creates a session through CLI on supported hosts.

.EXAMPLE
.\Start-Sandbox.ps1 -DryRun -UseWslHelper -WslDistro Ubuntu
    # Validates and previews optional WSL helper sidecar usage with selected distro.

.LINK
    QUICKSTART.md, PROFILES.md, SAFETY.md
#>

[CmdletBinding()]
param(
    [Alias('Profile')]
    [string]$SandboxProfile = 'reverse-engineering',

    [switch]$Force,
    [switch]$NoLaunch,
    [switch]$DryRun,
    [switch]$Validate,
    [switch]$Audit,
    [switch]$CleanDownloads,
    [switch]$ListTools,
    [switch]$ListProfiles,
    [string[]]$AddTools,
    [string[]]$RemoveTools,
    [switch]$OutputJson,
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
    [string]$WslDistro,
    [string]$WslHelperStagePath = '~/.sandbox-toolkit-helper'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Output helper -------------------------------------------------------------
# Write-Host is avoided (PSAvoidUsingWriteHost). This thin wrapper delegates to
# $Host.UI.WriteLine which supports colors and works in all standard PS hosts.

function Write-StatusLine {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    if (-not $script:EmitHumanOutput) {
        return
    }
    $Host.UI.WriteLine($ForegroundColor, $Host.UI.RawUI.BackgroundColor, $Message)
}

# -- Paths --------------------------------------------------------------------

$repoRoot            = $PSScriptRoot
$srcDir              = Join-Path $repoRoot 'src'
$manifestPath        = Join-Path $repoRoot 'tools.json'
$customProfilePath   = Join-Path $repoRoot 'custom-profiles.local.json'
$setupDir            = Join-Path $repoRoot 'scripts\setups'
$installManifestPath = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbPath             = Join-Path $repoRoot 'sandbox.wsb'
$resolvedSharedFolder = $null

# -- Load helper modules -------------------------------------------------------

foreach ($module in @('Manifest.ps1', 'Download.ps1', 'SandboxConfig.ps1', 'SharedFolderValidation.ps1', 'Session.ps1', 'Workflow.ps1', 'Validation.ps1', 'Audit.ps1', 'Output.ps1', 'Maintenance.ps1', 'Cli.ps1')) {
    . (Join-Path $srcDir $module)
}

$commandMode = Resolve-StartSandboxCommandMode `
    -CleanDownloads:$CleanDownloads `
    -ListTools:$ListTools `
    -ListProfiles:$ListProfiles `
    -Validate:$Validate `
    -Audit:$Audit `
    -DryRun:$DryRun `
    -Force:$Force `
    -NoLaunch:$NoLaunch `
    -OutputJson:$OutputJson `
    -AddTools $AddTools `
    -RemoveTools $RemoveTools `
    -SkipPrereqCheck:$SkipPrereqCheck `
    -SharedFolder $SharedFolder `
    -UseDefaultSharedFolder:$UseDefaultSharedFolder `
    -SharedFolderWritable:$SharedFolderWritable `
    -SharedFolderValidationDiagnostics:$SharedFolderValidationDiagnostics `
    -DisableClipboard:$DisableClipboard `
    -DisableAudioInput:$DisableAudioInput `
    -DisableStartupCommands:$DisableStartupCommands `
    -SessionMode $SessionMode `
    -UseWslHelper:$UseWslHelper `
    -ExplicitWslDistro:$($PSBoundParameters.ContainsKey('WslDistro')) `
    -ExplicitWslHelperStagePath:$($PSBoundParameters.ContainsKey('WslHelperStagePath')) `
    -ExplicitSandboxProfile:$($PSBoundParameters.ContainsKey('SandboxProfile'))
$modePlan = Get-StartSandboxModePlan -CommandMode $commandMode
$script:EmitHumanOutput = -not $OutputJson
$hostInteractionPolicy = Get-SandboxHostInteractionPolicy `
    -DisableClipboard:$DisableClipboard `
    -DisableAudioInput:$DisableAudioInput `
    -DisableStartupCommands:$DisableStartupCommands
$sessionLifecycleState = Get-SandboxSessionLifecycleState -SessionMode $SessionMode
$wslHelperState = Get-SandboxWslHelperState `
    -UseWslHelper:$UseWslHelper `
    -WslDistro $WslDistro `
    -WslHelperStagePath $WslHelperStagePath

$setupState = @()
$artifacts = $null
$prerequisiteChecks = @()
$wslHelperResult = $null

try {

if ($commandMode -eq 'List') {
    $manifest = Import-ToolManifest -ManifestPath $manifestPath
    Test-ManifestIntegrity -Manifest $manifest
    $customProfileConfig = $null
    $toolCatalog = $null
    $profileCatalog = $null

    if ($ListProfiles) {
        $customProfileConfig = Import-CustomProfileConfig -CustomProfilePath $customProfilePath
        Test-CustomProfileConfigIntegrity -CustomProfileConfig $customProfileConfig -Manifest $manifest
        $profileCatalog = @(Get-SandboxProfileCatalog -Manifest $manifest -CustomProfileConfig $customProfileConfig)
    }

    if ($ListTools) {
        $toolCatalog = @(Get-ManifestToolCatalog -Manifest $manifest)
    }

    if ($OutputJson) {
        if ($ListProfiles) {
            $listProfilesJsonResult = Get-SandboxListProfilesJsonResult -Profiles $profileCatalog
            Write-SandboxJsonOutput -Data $listProfilesJsonResult
            return
        }

        if ($ListTools) {
            $listToolsJsonResult = Get-SandboxListToolsJsonResult -Tools $toolCatalog
            Write-SandboxJsonOutput -Data $listToolsJsonResult
            return
        }
    }

    if ($ListProfiles) {
        Write-StatusLine ''
        Write-StatusLine 'Available profiles:' -ForegroundColor Cyan
        $profileCatalog | ForEach-Object {
            if ($_.profile_type -eq 'custom') {
                Write-StatusLine "  - $($_.name) (custom; base=$($_.base_profile))" -ForegroundColor White
            } else {
                Write-StatusLine "  - $($_.name) (built-in)" -ForegroundColor White
            }
        }
    }

    if ($ListTools) {
        Write-StatusLine ''
        Write-StatusLine 'Available tools:' -ForegroundColor Cyan
        $toolCatalog | ForEach-Object {
            $profiles = $_.profiles -join ', '
            Write-StatusLine ("  - {0,-15} | {1} [{2}] (profiles: {3})" -f $_.id, $_.display_name, $_.installer_type, $profiles) -ForegroundColor White
        }
    }

    Write-StatusLine ''
    return
}

if ($commandMode -eq 'CleanDownloads') {
    $cleanupPlan = Get-SandboxDownloadCleanupPlan -RepoRoot $repoRoot
    $cleanupResult = Invoke-SandboxDownloadCleanup -CleanupPlan $cleanupPlan
    $summaryLines = @(Get-SandboxDownloadCleanupSummary -CleanupResult $cleanupResult)

    Write-StatusLine ''
    foreach ($line in $summaryLines) {
        $color = [ConsoleColor]::White
        if ($line -match 'Failures:') {
            $color = [ConsoleColor]::Red
        } elseif ($line -match 'Nothing to clean|Completed without deletion failures') {
            $color = [ConsoleColor]::Green
        } elseif ($line -match 'Inspected locations|Removed:|Skipped:') {
            $color = [ConsoleColor]::Cyan
        }

        Write-StatusLine $line -ForegroundColor $color
    }
    Write-StatusLine ''

    if (-not $cleanupResult.Success) {
        exit 1
    }
    return
}

# -- Banner -------------------------------------------------------------------

Write-StatusLine ''
Write-StatusLine '  Windows Sandbox Toolkit' -ForegroundColor Cyan
Write-StatusLine '  -----------------------------------------' -ForegroundColor DarkGray
Write-StatusLine "  Profile : $SandboxProfile" -ForegroundColor White
Write-StatusLine "  Mode    : $commandMode" -ForegroundColor White
Write-StatusLine "  Session : $($sessionLifecycleState.RequestedMode)" -ForegroundColor White
$helperStateLabel = if ($wslHelperState.Enabled) { 'enabled' } else { 'disabled' }
Write-StatusLine ("  Helper  : WSL {0}" -f $helperStateLabel) -ForegroundColor White
Write-StatusLine "  Repo    : $repoRoot" -ForegroundColor DarkGray
Write-StatusLine ''

if ($commandMode -eq 'Validate') {
    $preflightResult = Invoke-SandboxPreflightValidation `
        -RepoRoot $repoRoot `
        -ManifestPath $manifestPath `
        -CustomProfilePath $customProfilePath `
        -SandboxProfile $SandboxProfile `
        -AddTools $AddTools `
        -RemoveTools $RemoveTools `
        -SkipPrereqCheck:$SkipPrereqCheck `
        -SharedFolder $SharedFolder `
        -UseDefaultSharedFolder:$UseDefaultSharedFolder `
        -SharedFolderWritable:$SharedFolderWritable `
        -SharedFolderValidationDiagnostics:$SharedFolderValidationDiagnostics `
        -HostInteractionPolicy $hostInteractionPolicy `
        -SessionLifecycleState $sessionLifecycleState `
        -WslHelperState $wslHelperState

    $validationExitCode = Get-SandboxValidationExitCode -PreflightResult $preflightResult
    if ($OutputJson) {
        $validateJsonResult = Get-SandboxValidateJsonResult `
            -PreflightResult $preflightResult `
            -SandboxProfile $SandboxProfile `
            -ExitCode $validationExitCode `
            -SkipPrereqCheck:$SkipPrereqCheck `
            -SharedFolder $SharedFolder `
            -UseDefaultSharedFolder:$UseDefaultSharedFolder `
            -HostInteractionPolicy $hostInteractionPolicy `
            -SessionLifecycleState $sessionLifecycleState `
            -WslHelperState $wslHelperState
        Write-SandboxJsonOutput -Data $validateJsonResult
    } else {
        Write-SandboxPreflightReport -PreflightResult $preflightResult
        Write-StatusLine ''
    }

    if ($validationExitCode -ne 0) {
        exit $validationExitCode
    }
    return
}

$sharedFolderRequest = Resolve-SharedFolderRequest `
    -RepoRoot $repoRoot `
    -SharedFolder $SharedFolder `
    -UseDefaultSharedFolder:$UseDefaultSharedFolder `
    -SharedFolderWritable:$SharedFolderWritable `
    -SharedFolderValidationDiagnostics:$SharedFolderValidationDiagnostics `
    -OnDefaultSharedFolderCreated {
        param($Path)
        Write-StatusLine "  [OK]  Created default shared folder: $Path" -ForegroundColor Green
    }

$resolvedSharedFolder = $sharedFolderRequest.SharedHostFolder

# -- [1/5] Prerequisites -------------------------------------------------------

if ($modePlan.CheckPrerequisites) {
    Write-StatusLine '[1/5] Checking prerequisites...' -ForegroundColor Yellow

    $prerequisiteChecks = @(Test-SandboxHostPrerequisite -SkipPrereqCheck:$SkipPrereqCheck)
    foreach ($check in $prerequisiteChecks) {
        switch ($check.Status) {
            'PASS' {
                Write-StatusLine "  [OK]  $($check.Message)" -ForegroundColor Green
            }
            'WARN' {
                if ($script:EmitHumanOutput) {
                    Write-Warning $check.Message
                    if ($check.Remediation) {
                        Write-Warning $check.Remediation
                    }
                }
            }
            'FAIL' {
                if ($OutputJson) {
                    $preflightResult = [pscustomobject]@{
                        Checks = @($prerequisiteChecks)
                        Selection = $null
                        SharedHostFolder = $resolvedSharedFolder
                        SharedFolderWritable = [bool]$SharedFolderWritable
                    }
                    if ($commandMode -eq 'Audit') {
                        Write-StatusLine "  [FAIL] $($check.Message)" -ForegroundColor Red
                        if ($check.Remediation) {
                            Write-StatusLine "         Remediation: $($check.Remediation)" -ForegroundColor DarkGray
                        }
                    } else {
                        $validateJsonResult = Get-SandboxValidateJsonResult `
                            -PreflightResult $preflightResult `
                            -SandboxProfile $SandboxProfile `
                            -ExitCode 1 `
                            -SkipPrereqCheck:$SkipPrereqCheck `
                            -SharedFolder $SharedFolder `
                            -UseDefaultSharedFolder:$UseDefaultSharedFolder `
                            -HostInteractionPolicy $hostInteractionPolicy
                        Write-SandboxJsonOutput -Data $validateJsonResult
                    }
                } else {
                    if ($commandMode -eq 'Audit') {
                        Write-StatusLine "  [FAIL] $($check.Message)" -ForegroundColor Red
                        if ($check.Remediation) {
                            Write-StatusLine "         Remediation: $($check.Remediation)" -ForegroundColor DarkGray
                        }
                    } else {
                        Write-Error $check.Message
                        if ($check.Remediation) {
                            Write-StatusLine "  Remediation: $($check.Remediation)" -ForegroundColor Yellow
                        }
                    }
                }
                if ($commandMode -ne 'Audit') {
                    exit 1
                }
            }
        }
    }
    Write-StatusLine ''
}

# -- [2/5] Load manifest -------------------------------------------------------

Write-StatusLine '[2/5] Loading manifest...' -ForegroundColor Yellow

$manifest = Import-ToolManifest -ManifestPath $manifestPath
Test-ManifestIntegrity -Manifest $manifest
$customProfileConfig = Import-CustomProfileConfig -CustomProfilePath $customProfilePath
Test-CustomProfileConfigIntegrity -CustomProfileConfig $customProfileConfig -Manifest $manifest
$selection = Resolve-SandboxSessionSelection `
    -Manifest $manifest `
    -SandboxProfile $SandboxProfile `
    -CustomProfileConfig $customProfileConfig `
    -AddTools $AddTools `
    -RemoveTools $RemoveTools
$tools      = $selection.Tools
$networkingMode = Get-SandboxNetworkingMode -SandboxProfile $selection.BaseProfile

Write-StatusLine "  [OK]  $($tools.Count) tool(s) selected for profile '$SandboxProfile'." -ForegroundColor Green
if ($selection.ProfileType -eq 'custom') {
    Write-StatusLine "        Base profile: $($selection.BaseProfile)" -ForegroundColor DarkGray
}
if ($selection.RuntimeAddTools.Count -gt 0) {
    Write-StatusLine "        Runtime add: $($selection.RuntimeAddTools -join ', ')" -ForegroundColor DarkGray
}
if ($selection.RuntimeRemoveTools.Count -gt 0) {
    Write-StatusLine "        Runtime remove: $($selection.RuntimeRemoveTools -join ', ')" -ForegroundColor DarkGray
}
Write-StatusLine "        Networking: $networkingMode" -ForegroundColor DarkGray
if ($sessionLifecycleState.RequestedMode -eq 'Warm') {
    Write-StatusLine ("        Session lifecycle: warm_requested; warm_supported={0}; running_sessions={1}" -f `
            $sessionLifecycleState.WarmSupport.Supported, `
            $sessionLifecycleState.RunningSessionCount) -ForegroundColor DarkGray
}
Write-StatusLine ("        Host interaction: clipboard={0}; audio_input={1}; startup_commands_enabled={2}" -f `
        $hostInteractionPolicy.ClipboardRedirection, `
        $hostInteractionPolicy.AudioInput, `
        $hostInteractionPolicy.StartupCommandsEnabled) -ForegroundColor DarkGray
if ($wslHelperState.Enabled) {
    $effectiveDistroLabel = if ($wslHelperState.EffectiveDistro) { $wslHelperState.EffectiveDistro } else { '(default)' }
    Write-StatusLine ("        WSL helper: enabled; distro={0}; stage_path={1}" -f $effectiveDistroLabel, $wslHelperState.StagePath) -ForegroundColor DarkGray
}
$tools | ForEach-Object {
    $tag = if ($_.installer_type -eq 'manual') { '  [manual]' } else { '' }
    Write-StatusLine "        * $($_.display_name)$tag" -ForegroundColor DarkGray
}
Write-StatusLine ''

# -- [3/5] Download ------------------------------------------------------------

if ($commandMode -eq 'DryRun' -or $commandMode -eq 'Audit') {
    if ($commandMode -eq 'Audit') {
        Write-StatusLine '[3/5] Download stage (audit)...' -ForegroundColor Yellow
    } else {
        Write-StatusLine '[3/5] Download plan (dry-run)...' -ForegroundColor Yellow
    }
    Write-StatusLine "  [PLAN] Setup directory: $setupDir" -ForegroundColor DarkGray
    $setupState = @(Get-ToolSetupState -Tools $tools -SetupDir $setupDir)
    $setupState | ForEach-Object {
        $state = if ($_.cached) { 'cached' } else { 'missing' }
        Write-StatusLine "  [PLAN] $($_.filename) -- $state" -ForegroundColor DarkGray
    }
} else {
    Write-StatusLine '[3/5] Downloading tools...' -ForegroundColor Yellow

    if (-not (Test-Path $setupDir)) {
        New-Item -ItemType Directory -Path $setupDir -Force | Out-Null
    }

    try {
        Invoke-DownloadQueue -Tools $tools -SetupDir $setupDir -Force:$Force
    } catch {
        Write-StatusLine ''
        Write-Error "Download failed: $_"
        exit 1
    }
}

Write-StatusLine ''

if ($sessionLifecycleState.RequestedMode -eq 'Warm' -and -not $sessionLifecycleState.WarmSupport.Supported) {
    throw "Warm session mode is unsupported on this host. $($sessionLifecycleState.WarmSupport.Reason)"
}

if ($wslHelperState.Enabled) {
    Write-StatusLine '[3.5/5] WSL helper sidecar...' -ForegroundColor Yellow
    $wslHelperResult = Invoke-SandboxWslHelperSidecar `
        -WslHelperState $wslHelperState `
        -Selection $selection `
        -NetworkingMode $networkingMode `
        -SessionLifecycleState $sessionLifecycleState
    $effectiveHelperDistro = if ($wslHelperState.EffectiveDistro) { $wslHelperState.EffectiveDistro } else { '(default)' }
    Write-StatusLine ("  [OK]  WSL helper staged metadata in distro '{0}' at '{1}'." -f $effectiveHelperDistro, $wslHelperResult.StagePath) -ForegroundColor Green
    Write-StatusLine ("        Payload hash: {0}" -f $wslHelperResult.PayloadHash) -ForegroundColor DarkGray
    Write-StatusLine ''
}

# -- [4/5] Configure -----------------------------------------------------------

Write-StatusLine '[4/5] Configuring...' -ForegroundColor Yellow

$artifacts = Invoke-SandboxSessionArtifactGeneration `
    -RepoRoot $repoRoot `
    -SandboxProfile $selection.BaseProfile `
    -Tools $tools `
    -InstallManifestPath $installManifestPath `
    -WsbPath $wsbPath `
    -SharedHostFolder $resolvedSharedFolder `
    -SharedFolderWritable:$SharedFolderWritable `
    -HostInteractionPolicy $hostInteractionPolicy

Write-StatusLine "  [OK]  Install manifest: $($artifacts.InstallManifestPath)" -ForegroundColor Green
Write-StatusLine "  [OK]  Sandbox config: $($artifacts.WsbPath)" -ForegroundColor Green

if ($resolvedSharedFolder) {
    $access = if ($SharedFolderWritable) { 'writable' } else { 'read-only' }
    Write-StatusLine "  [OK]  Shared folder mapped: $resolvedSharedFolder ($access)" -ForegroundColor Green
    Write-StatusLine '        In sandbox: C:\Users\WDAGUtilityAccount\Desktop\shared' -ForegroundColor DarkGray
}
Write-StatusLine ''

if ($commandMode -eq 'Audit') {
    Write-StatusLine '[5/5] Audit...' -ForegroundColor Yellow
    $auditResult = Invoke-SandboxArtifactAudit `
        -RepoRoot $repoRoot `
        -Selection $selection `
        -NetworkingMode $networkingMode `
        -SessionLifecycleState $sessionLifecycleState `
        -WslHelperState $wslHelperState `
        -HostInteractionPolicy $hostInteractionPolicy `
        -Artifacts $artifacts `
        -SharedHostFolder $resolvedSharedFolder `
        -SharedFolderWritable:$SharedFolderWritable `
        -SkipPrereqCheck:$SkipPrereqCheck `
        -PrerequisiteChecks $prerequisiteChecks

    $auditExitCode = Get-SandboxAuditExitCode -AuditResult $auditResult
    if ($OutputJson) {
        $auditJsonResult = Get-SandboxAuditJsonResult `
            -AuditResult $auditResult `
            -Selection $selection `
            -NetworkingMode $networkingMode `
            -Artifacts $artifacts `
            -ExitCode $auditExitCode `
            -SkipPrereqCheck:$SkipPrereqCheck `
            -SharedFolder $SharedFolder `
            -UseDefaultSharedFolder:$UseDefaultSharedFolder `
            -ResolvedSharedFolder $resolvedSharedFolder `
            -SharedFolderWritable:$SharedFolderWritable `
            -HostInteractionPolicy $hostInteractionPolicy `
            -SessionLifecycleState $sessionLifecycleState `
            -WslHelperState $wslHelperState
        Write-SandboxJsonOutput -Data $auditJsonResult
    } else {
        Write-SandboxAuditReport -AuditResult $auditResult
        Write-StatusLine ''
    }

    if ($auditExitCode -ne 0) {
        exit $auditExitCode
    }
    return
}

# -- [5/5] Launch --------------------------------------------------------------

Write-StatusLine '[5/5] Launch...' -ForegroundColor Yellow
try {
    $launchResult = Invoke-SandboxSessionLaunch `
        -WsbPath $wsbPath `
        -SessionLifecycleState $sessionLifecycleState `
        -NoLaunch:$NoLaunch `
        -DryRun:($commandMode -eq 'DryRun')
    if ($launchResult.Reason -eq 'DryRun') {
        Write-StatusLine '  [SKIP] -DryRun specified; sandbox launch suppressed.' -ForegroundColor DarkGray
        Write-StatusLine "         Generated files remain on host: $installManifestPath, $wsbPath" -ForegroundColor DarkGray
    } elseif ($launchResult.Reason -eq 'NoLaunch') {
        Write-StatusLine '  [SKIP] -NoLaunch specified.' -ForegroundColor DarkGray
        Write-StatusLine "         To start manually: $wsbPath" -ForegroundColor DarkGray
    } elseif ($launchResult.Reason -eq 'WarmReusedSession') {
        Write-StatusLine ("  [OK]   Reused warm sandbox session: {0}" -f $launchResult.WarmSessionId) -ForegroundColor Green
        Write-StatusLine '         Connected to existing sandbox session using Windows Sandbox CLI.' -ForegroundColor DarkGray
    } elseif ($launchResult.Reason -eq 'WarmCreatedSession') {
        Write-StatusLine '  [OK]   Warm mode requested and no running session was found; created a new CLI-managed sandbox session.' -ForegroundColor Green
        Write-StatusLine '         Startup automation follows generated sandbox.wsb configuration.' -ForegroundColor DarkGray
    } else {
        Write-StatusLine '  [OK]   Windows Sandbox launched.' -ForegroundColor Green
        Write-StatusLine '         Setup runs automatically. Check install-log.txt on the sandbox Desktop.' -ForegroundColor DarkGray
    }
} catch {
    Write-Warning "Could not launch sandbox: $_"
    Write-StatusLine "  Open manually: $wsbPath" -ForegroundColor Yellow
}

if ($OutputJson -and $commandMode -eq 'DryRun') {
    $dryRunJsonResult = Get-SandboxDryRunJsonResult `
        -Selection $selection `
        -NetworkingMode $networkingMode `
        -SetupState $setupState `
        -Artifacts $artifacts `
        -PrerequisiteChecks $prerequisiteChecks `
        -SkipPrereqCheck:$SkipPrereqCheck `
        -SharedFolder $SharedFolder `
        -UseDefaultSharedFolder:$UseDefaultSharedFolder `
        -ResolvedSharedFolder $resolvedSharedFolder `
        -SharedFolderWritable:$SharedFolderWritable `
        -HostInteractionPolicy $hostInteractionPolicy `
        -SessionLifecycleState $sessionLifecycleState `
        -WslHelperState $wslHelperState `
        -WslHelperResult $wslHelperResult
    Write-SandboxJsonOutput -Data $dryRunJsonResult
}

Write-StatusLine ''
} catch {
    if ($OutputJson) {
        $errorJsonResult = Get-SandboxErrorJsonResult `
            -CommandMode $commandMode `
            -ListTools:$ListTools `
            -ListProfiles:$ListProfiles `
            -Message $_.Exception.Message
        Write-SandboxJsonOutput -Data $errorJsonResult
        exit 1
    }

    throw
}
