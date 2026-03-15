# src/Session.ps1
# Shared helpers for session data and generated artifacts.

function Get-SandboxSessionManifestData {
    <#
    .SYNOPSIS
        Builds the install-manifest payload consumed by scripts/Install-Tools.ps1.
    #>
    param(
        [Parameter(Mandatory)][string]$SandboxProfile,
        [Parameter(Mandatory)][object[]]$Tools
    )

    return [ordered]@{
        generated_at = (Get-Date -Format 'o')
        profile      = $SandboxProfile
        tools        = @($Tools)
    }
}

function Resolve-SandboxSessionSelection {
    <#
    .SYNOPSIS
        Resolves effective tool selection for a profile.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest,
        [Parameter(Mandatory)][string]$SandboxProfile
    )

    $tools = Resolve-SandboxEffectiveToolSelection `
        -Manifest $Manifest `
        -ToolIds (Get-ToolsForProfile -Manifest $Manifest -SandboxProfile $SandboxProfile | Select-Object -ExpandProperty id)

    return [pscustomobject]@{
        Profile = $SandboxProfile
        Tools   = @($tools)
    }
}

function Resolve-SandboxEffectiveToolSelection {
    <#
    .SYNOPSIS
        Resolves a deterministic ordered tool list from an ID set.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest,
        [Parameter(Mandatory)][string[]]$ToolIds
    )

    $selectedToolIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($toolId in $ToolIds) {
        if (-not [string]::IsNullOrWhiteSpace($toolId)) {
            [void]$selectedToolIds.Add($toolId)
        }
    }

    return @(
        $Manifest.tools |
            Sort-Object install_order |
            Where-Object { $selectedToolIds.Contains($_.id) }
    )
}

function Write-SandboxSessionManifest {
    <#
    .SYNOPSIS
        Writes the install-manifest.json file for in-sandbox setup.
    #>
    param(
        [Parameter(Mandatory)][string]$SandboxProfile,
        [Parameter(Mandatory)][object[]]$Tools,
        [Parameter(Mandatory)][string]$ManifestPath
    )

    $sessionManifest = Get-SandboxSessionManifestData -SandboxProfile $SandboxProfile -Tools $Tools
    $sessionManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath -Encoding UTF8
    return $ManifestPath
}

function Invoke-SandboxSessionArtifactGeneration {
    <#
    .SYNOPSIS
        Writes session artifacts required by launch and dry-run flows.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [Parameter(Mandatory)][object[]]$Tools,
        [Parameter(Mandatory)][string]$InstallManifestPath,
        [Parameter(Mandatory)][string]$WsbPath,
        [string]$SharedHostFolder,
        [switch]$SharedFolderWritable
    )

    $writtenManifestPath = Write-SandboxSessionManifest `
        -SandboxProfile $SandboxProfile `
        -Tools $Tools `
        -ManifestPath $InstallManifestPath

    $writtenWsbPath = New-SandboxConfig `
        -RepoRoot $RepoRoot `
        -SandboxProfile $SandboxProfile `
        -OutputPath $WsbPath `
        -SharedHostFolder $SharedHostFolder `
        -SharedFolderWritable:$SharedFolderWritable

    return [pscustomobject]@{
        InstallManifestPath = $writtenManifestPath
        WsbPath             = $writtenWsbPath
    }
}
