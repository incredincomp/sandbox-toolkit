# src/SandboxConfig.ps1
# Generates sandbox.wsb from a profile-driven template.
# Runtime variables are networking and mapped host folders.

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
    .PARAMETER SharedHostFolder
        Optional extra host folder mapped into the sandbox at Desktop\shared.
    .PARAMETER SharedFolderWritable
        If set, the optional shared folder is writable from inside the sandbox.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [string]$OutputPath,
        [string]$SharedHostFolder,
        [switch]$SharedFolderWritable
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

    # Use a here-string: networking and mapped folders vary per run.
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
${mappedFoldersXml}
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
