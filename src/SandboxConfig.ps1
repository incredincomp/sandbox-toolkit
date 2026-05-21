# src/SandboxConfig.ps1
# Generates sandbox.wsb from a profile-driven template.
# Runtime variables are networking and mapped host folders.

# Per-profile sandbox policy defaults.
$script:SandboxProfileSettings = @{
    'minimal'             = [pscustomobject]@{ Networking = 'Disable'; VGpu = 'Disable' }
    'reverse-engineering' = [pscustomobject]@{ Networking = 'Disable'; VGpu = 'Default' }
    'network-analysis'    = [pscustomobject]@{ Networking = 'Enable';  VGpu = 'Default' } # Live capture workflow.
    'analysis'            = [pscustomobject]@{ Networking = 'Enable';  VGpu = 'Default' } # Internet-enabled analyst workflow.
    'detonation'          = [pscustomobject]@{ Networking = 'Disable'; VGpu = 'Disable' } # Restricted detonation workflow.
    'forensics'           = [pscustomobject]@{ Networking = 'Disable'; VGpu = 'Disable' } # Offline artifact-centric workflow.
    'full'                = [pscustomobject]@{ Networking = 'Enable';  VGpu = 'Default' }
    'triage-plus'         = [pscustomobject]@{ Networking = 'Enable';  VGpu = 'Default' }
    'reverse-windows'     = [pscustomobject]@{ Networking = 'Disable'; VGpu = 'Default' }
    'behavior-net'        = [pscustomobject]@{ Networking = 'Enable';  VGpu = 'Default' }
    'dev-windows'         = [pscustomobject]@{ Networking = 'Disable'; VGpu = 'Default' }
}

function Get-SandboxProfilePolicy {
    <#
    .SYNOPSIS
        Returns effective sandbox policy defaults configured for a profile.
    #>
    param(
        [Parameter(Mandatory)][string]$SandboxProfile
    )

    $settings = $script:SandboxProfileSettings[$SandboxProfile]
    if (-not $settings) {
        throw "No sandbox settings defined for profile '$SandboxProfile'."
    }
    return $settings
}

function Get-SandboxNetworkingMode {
    <#
    .SYNOPSIS
        Returns networking mode configured for a profile.
    #>
    param(
        [Parameter(Mandatory)][string]$SandboxProfile
    )

    return (Get-SandboxProfilePolicy -SandboxProfile $SandboxProfile).Networking
}

function Get-SandboxHostInteractionPolicy {
    <#
    .SYNOPSIS
        Resolves effective host-interaction policy for generated sandbox configuration.
    #>
    param(
        [switch]$DisableClipboard,
        [switch]$DisableAudioInput,
        [switch]$DisableStartupCommands
    )

    $effectiveAudioInput = 'Disable'
    if (-not $DisableAudioInput) {
        # Preserve existing default behavior: audio input remains disabled.
        $effectiveAudioInput = 'Disable'
    }

    return [pscustomobject]@{
        RequestedDisableClipboard      = [bool]$DisableClipboard
        RequestedDisableAudioInput     = [bool]$DisableAudioInput
        RequestedDisableStartupCommands = [bool]$DisableStartupCommands
        ClipboardRedirection           = if ($DisableClipboard) { 'Disable' } else { 'Enable' }
        AudioInput                     = $effectiveAudioInput
        StartupCommandsEnabled         = -not [bool]$DisableStartupCommands
    }
}

function New-SandboxConfig {
    <#
    .SYNOPSIS
        Generates a sandbox.wsb file for the given profile and host repo path.
    .PARAMETER RepoRoot
        Absolute path to the repository root on the host.
    .PARAMETER SandboxProfile
        The install profile (minimal, reverse-engineering, network-analysis, full).
    .PARAMETER OutputPath
        Where to write the generated .wsb file (default: <RepoRoot>\sandbox.wsb).
    .PARAMETER SharedHostFolder
        Optional extra host folder mapped into the sandbox at Desktop\shared.
    .PARAMETER SharedFolderWritable
        If set, the optional shared folder is writable from inside the sandbox.
    .PARAMETER HostInteractionPolicy
        Effective host-interaction policy object returned by Get-SandboxHostInteractionPolicy.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [string]$OutputPath,
        [string]$SharedHostFolder,
        [switch]$SharedFolderWritable,
        [PSCustomObject]$HostInteractionPolicy
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path $RepoRoot 'sandbox.wsb'
    }

    $profileSettings = Get-SandboxProfilePolicy -SandboxProfile $SandboxProfile
    $networking = $profileSettings.Networking
    $vGpu = $profileSettings.VGpu
    if (-not $HostInteractionPolicy) {
        $HostInteractionPolicy = Get-SandboxHostInteractionPolicy
    }

    $scriptsHostPath = Join-Path $RepoRoot 'scripts'
    if (-not (Test-Path $scriptsHostPath)) {
        throw "Scripts directory not found: $scriptsHostPath"
    }

    $xmlEscapedScriptsHostPath = [System.Security.SecurityElement]::Escape($scriptsHostPath)
    $mappedFolders = @(
@"
    <MappedFolder>
      <HostFolder>$xmlEscapedScriptsHostPath</HostFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
"@
    )

    if ($SharedHostFolder) {
        $xmlEscapedSharedHostPath = [System.Security.SecurityElement]::Escape($SharedHostFolder)
        $sharedReadOnly = if ($SharedFolderWritable) { 'false' } else { 'true' }
        $mappedFolders += @"
    <MappedFolder>
      <HostFolder>$xmlEscapedSharedHostPath</HostFolder>
      <SandboxFolder>C:\Users\WDAGUtilityAccount\Desktop\shared</SandboxFolder>
      <ReadOnly>$sharedReadOnly</ReadOnly>
    </MappedFolder>
"@
    }

    $mappedFoldersXml = ($mappedFolders -join [Environment]::NewLine)
    $logonCommandXml = ''
    if ($HostInteractionPolicy.StartupCommandsEnabled) {
        $logonCommandXml = @"
  <LogonCommand>
    <Command>C:\Users\WDAGUtilityAccount\Desktop\scripts\autostart.cmd</Command>
  </LogonCommand>
"@
    }

    # Use a here-string: networking and mapped folders vary per run.
    $wsbContent = @"
<Configuration>
  <VGpu>$vGpu</VGpu>
  <Networking>$networking</Networking>
  <AudioInput>$($HostInteractionPolicy.AudioInput)</AudioInput>
  <VideoInput>Disable</VideoInput>
  <ProtectedClient>True</ProtectedClient>
  <PrinterRedirection>Disable</PrinterRedirection>
  <ClipboardRedirection>$($HostInteractionPolicy.ClipboardRedirection)</ClipboardRedirection>
  <MappedFolders>
${mappedFoldersXml}
  </MappedFolders>
$logonCommandXml
</Configuration>
"@

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write sandbox configuration')) {
        Set-Content -Path $OutputPath -Value $wsbContent.TrimStart() -Encoding UTF8
        Write-StatusLine "  [WSB]  Generated: $OutputPath" -ForegroundColor Green
        Write-StatusLine "         Profile: $SandboxProfile  |  Networking: $networking  |  vGPU: $vGpu" -ForegroundColor DarkGray
    }
    return $OutputPath
}
