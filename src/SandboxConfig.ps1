# src/SandboxConfig.ps1
# Generates sandbox.wsb from a profile-driven here-string template.
# The only runtime variables are: HostFolder path and Networking setting.

# Networking defaults per profile. All profiles except those needing live capture use Disable.
$script:NetworkingByProfile = @{
    'minimal'             = 'Disable'
    'reverse-engineering' = 'Disable'
    'network-analysis'    = 'Enable'   # Required for Wireshark capture. See SAFETY.md.
    'full'                = 'Enable'   # Networking enabled -- use with caution.
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
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path $RepoRoot 'sandbox.wsb'
    }

    $networking = $script:NetworkingByProfile[$SandboxProfile]
    if (-not $networking) {
        throw "No sandbox settings defined for profile '$SandboxProfile'."
    }

    $scriptsHostPath = Join-Path $RepoRoot 'scripts'
    if (-not (Test-Path $scriptsHostPath)) {
        throw "Scripts directory not found: $scriptsHostPath"
    }

    # Use a here-string: only Networking and HostFolder vary per run.
    $wsbContent = @"
<Configuration>
  <VGpu>Disable</VGpu>
  <Networking>$networking</Networking>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <ProtectedClient>True</ProtectedClient>
  <PrinterRedirection>Disable</PrinterRedirection>
  <ClipboardRedirection>Enable</ClipboardRedirection>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$scriptsHostPath</HostFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>C:\Users\WDAGUtilityAccount\Desktop\scripts\autostart.cmd</Command>
  </LogonCommand>
</Configuration>
"@

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write sandbox configuration')) {
        Set-Content -Path $OutputPath -Value $wsbContent.TrimStart() -Encoding UTF8
        Write-StatusLine "  [WSB]  Generated: $OutputPath" -ForegroundColor Green
        Write-StatusLine "         Profile: $SandboxProfile  |  Networking: $networking" -ForegroundColor DarkGray
    }
    return $OutputPath
}
