# src/Manifest.ps1
# Loads and filters the tools.json manifest.

function Import-ToolManifest {
    <#
    .SYNOPSIS
        Loads tools.json from the repository root and returns the full manifest object.
    #>
    param(
        [Parameter(Mandatory)][string]$ManifestPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    try {
        $manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
    } catch {
        throw "Failed to parse manifest '$ManifestPath': $_"
    }

    if (-not $manifest.schema_version) {
        throw "Manifest is missing 'schema_version'. Is this a valid tools.json?"
    }

    return $manifest
}

function Get-ToolsForProfile {
    <#
    .SYNOPSIS
        Filters the manifest tool list to only those included in the given profile.
    .PARAMETER Manifest
        The full manifest object returned by Import-ToolManifest.
    .PARAMETER SandboxProfile
        One of: minimal, reverse-engineering, network-analysis, full.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest,
        [Parameter(Mandatory)][string]$SandboxProfile
    )

    $validProfiles = @('minimal', 'reverse-engineering', 'network-analysis', 'full')
    if ($SandboxProfile -notin $validProfiles) {
        throw "Invalid profile '$SandboxProfile'. Valid profiles: $($validProfiles -join ', ')"
    }

    $tools = $Manifest.tools | Where-Object { $SandboxProfile -in $_.profiles }
    return $tools | Sort-Object install_order
}

function Test-ManifestIntegrity {
    <#
    .SYNOPSIS
        Performs basic integrity checks on the manifest: unique IDs, valid source types, required fields.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest
    )

    $errors = @()
    $ids = @{}

    foreach ($tool in $Manifest.tools) {
        if ($ids.ContainsKey($tool.id)) {
            $errors += "Duplicate tool id: '$($tool.id)'"
        }
        $ids[$tool.id] = $true

        if ($tool.source_type -eq 'github_release') {
            if (-not $tool.github_repo) {
                $errors += "Tool '$($tool.id)': source_type=github_release requires 'github_repo'."
            }
            if (-not $tool.asset_pattern) {
                $errors += "Tool '$($tool.id)': source_type=github_release requires 'asset_pattern'."
            }
        } elseif ($tool.source_type -ne 'manual') {
            if (-not $tool.source_url) {
                $errors += "Tool '$($tool.id)': source_type='$($tool.source_type)' requires 'source_url'."
            }
        }

        if ($tool.installer_type -eq 'zip_then_exe' -and -not $tool.inner_exe) {
            $errors += "Tool '$($tool.id)': installer_type=zip_then_exe requires 'inner_exe'."
        }
    }

    if ($errors.Count -gt 0) {
        throw "Manifest validation failed:`n  " + ($errors -join "`n  ")
    }

    Write-Verbose "Manifest integrity OK: $($Manifest.tools.Count) tools."
}
