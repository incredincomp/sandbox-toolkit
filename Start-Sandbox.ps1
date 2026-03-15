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
    Install profile to use. Default: reverse-engineering.

.PARAMETER Force
    Re-download all files even if they already exist locally.

.PARAMETER NoLaunch
    Download and configure only; do not launch Windows Sandbox.

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

.EXAMPLE
    .\Start-Sandbox.ps1
    # Downloads tools for the default 'reverse-engineering' profile and launches.

.EXAMPLE
    .\Start-Sandbox.ps1 -Profile minimal -NoLaunch
    # Downloads minimal tools without launching.

.EXAMPLE
    .\Start-Sandbox.ps1 -Profile network-analysis -Force
    # Re-downloads all network-analysis tools and launches.

.EXAMPLE
    .\Start-Sandbox.ps1 -UseDefaultSharedFolder
    # Maps .\shared into sandbox at Desktop\shared (read-only by default).

.LINK
    QUICKSTART.md, PROFILES.md, SAFETY.md
#>

[CmdletBinding()]
param(
    [ValidateSet('minimal', 'reverse-engineering', 'network-analysis', 'full')]
    [Alias('Profile')]
    [string]$SandboxProfile = 'reverse-engineering',

    [switch]$Force,
    [switch]$NoLaunch,
    [switch]$SkipPrereqCheck,
    [string]$SharedFolder,
    [switch]$UseDefaultSharedFolder,
    [switch]$SharedFolderWritable,
    [switch]$SharedFolderValidationDiagnostics
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
    $Host.UI.WriteLine($ForegroundColor, $Host.UI.RawUI.BackgroundColor, $Message)
}

# -- Paths --------------------------------------------------------------------

$repoRoot            = $PSScriptRoot
$srcDir              = Join-Path $repoRoot 'src'
$manifestPath        = Join-Path $repoRoot 'tools.json'
$setupDir            = Join-Path $repoRoot 'scripts\setups'
$installManifestPath = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbPath             = Join-Path $repoRoot 'sandbox.wsb'
$resolvedSharedFolder = $null

# -- Load helper modules -------------------------------------------------------

foreach ($module in @('Manifest.ps1', 'Download.ps1', 'SandboxConfig.ps1', 'SharedFolderValidation.ps1')) {
    . (Join-Path $srcDir $module)
}

# -- Banner -------------------------------------------------------------------

Write-StatusLine ''
Write-StatusLine '  Windows Sandbox Toolkit' -ForegroundColor Cyan
Write-StatusLine '  -----------------------------------------' -ForegroundColor DarkGray
Write-StatusLine "  Profile : $SandboxProfile" -ForegroundColor White
Write-StatusLine "  Repo    : $repoRoot" -ForegroundColor DarkGray
Write-StatusLine ''

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

if (-not $SkipPrereqCheck) {
    Write-StatusLine '[1/5] Checking prerequisites...' -ForegroundColor Yellow

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 or later is required. Found: $($PSVersionTable.PSVersion)"
    }
    Write-StatusLine "  [OK]  PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

    try {
        $feature = Get-WindowsOptionalFeature -FeatureName 'Containers-DisposableClientVM' -Online -ErrorAction Stop
        if ($feature.State -ne 'Enabled') {
            Write-Warning @'
Windows Sandbox is not enabled.
Run the following as Administrator and reboot:
  Enable-WindowsOptionalFeature -FeatureName Containers-DisposableClientVM -Online
'@
            exit 1
        }
        Write-StatusLine '  [OK]  Windows Sandbox feature is enabled.' -ForegroundColor Green
    } catch {
        # CommandNotFoundException: running in a non-Windows or limited environment.
        # Access-denied: script was not run as Administrator.
        Write-Warning "Could not verify Windows Sandbox feature: $($_.Exception.Message)"
        Write-Warning 'Continuing anyway -- use -SkipPrereqCheck to suppress this warning.'
    }

    Write-StatusLine ''
}

# -- [2/5] Load manifest -------------------------------------------------------

Write-StatusLine '[2/5] Loading manifest...' -ForegroundColor Yellow

$manifest = Import-ToolManifest -ManifestPath $manifestPath
Test-ManifestIntegrity -Manifest $manifest
$tools    = Get-ToolsForProfile -Manifest $manifest -SandboxProfile $SandboxProfile

Write-StatusLine "  [OK]  $($tools.Count) tool(s) selected for profile '$SandboxProfile'." -ForegroundColor Green
$tools | ForEach-Object {
    $tag = if ($_.installer_type -eq 'manual') { '  [manual]' } else { '' }
    Write-StatusLine "        * $($_.display_name)$tag" -ForegroundColor DarkGray
}
Write-StatusLine ''

# -- [3/5] Download ------------------------------------------------------------

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

Write-StatusLine ''

# -- [4/5] Configure -----------------------------------------------------------

Write-StatusLine '[4/5] Configuring...' -ForegroundColor Yellow

# Write session manifest for the in-sandbox installer to consume
$sessionManifest = [ordered]@{
    generated_at = (Get-Date -Format 'o')
    profile      = $SandboxProfile
    tools        = @($tools)
}
$sessionManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $installManifestPath -Encoding UTF8
Write-StatusLine "  [OK]  Install manifest: $installManifestPath" -ForegroundColor Green

# Generate sandbox.wsb with profile-appropriate settings
New-SandboxConfig `
    -RepoRoot $repoRoot `
    -SandboxProfile $SandboxProfile `
    -OutputPath $wsbPath `
    -SharedHostFolder $resolvedSharedFolder `
    -SharedFolderWritable:$SharedFolderWritable

if ($resolvedSharedFolder) {
    $access = if ($SharedFolderWritable) { 'writable' } else { 'read-only' }
    Write-StatusLine "  [OK]  Shared folder mapped: $resolvedSharedFolder ($access)" -ForegroundColor Green
    Write-StatusLine '        In sandbox: C:\Users\WDAGUtilityAccount\Desktop\shared' -ForegroundColor DarkGray
}
Write-StatusLine ''

# -- [5/5] Launch --------------------------------------------------------------

Write-StatusLine '[5/5] Launch...' -ForegroundColor Yellow

if ($NoLaunch) {
    Write-StatusLine '  [SKIP] -NoLaunch specified.' -ForegroundColor DarkGray
    Write-StatusLine "         To start manually: $wsbPath" -ForegroundColor DarkGray
} else {
    try {
        Start-Process -FilePath $wsbPath
        Write-StatusLine '  [OK]   Windows Sandbox launched.' -ForegroundColor Green
        Write-StatusLine '         Setup runs automatically. Check install-log.txt on the sandbox Desktop.' -ForegroundColor DarkGray
    } catch {
        Write-Warning "Could not launch sandbox: $_"
        Write-StatusLine "  Open manually: $wsbPath" -ForegroundColor Yellow
    }
}

Write-StatusLine ''
