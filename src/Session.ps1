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
        [Parameter(Mandatory)][string]$SandboxProfile,
        [PSCustomObject]$CustomProfileConfig,
        [string[]]$TemplateAddTools,
        [string[]]$TemplateRemoveTools,
        [string[]]$AddTools,
        [string[]]$RemoveTools
    )

    if (-not $CustomProfileConfig) {
        $CustomProfileConfig = [pscustomobject]@{
            schema_version = '1.0'
            profiles       = @()
        }
    }

    $resolvedProfileType = 'built-in'
    $baseProfile = $SandboxProfile
    $customProfile = $null
    $templateAddToolIds = Resolve-SandboxKnownToolIdList -Manifest $Manifest -ToolIds $TemplateAddTools -ArgumentName 'TemplateAddTools'
    $templateRemoveToolIds = Resolve-SandboxKnownToolIdList -Manifest $Manifest -ToolIds $TemplateRemoveTools -ArgumentName 'TemplateRemoveTools'
    $runtimeAddToolIds = Resolve-SandboxKnownToolIdList -Manifest $Manifest -ToolIds $AddTools -ArgumentName 'AddTools'
    $runtimeRemoveToolIds = Resolve-SandboxKnownToolIdList -Manifest $Manifest -ToolIds $RemoveTools -ArgumentName 'RemoveTools'

    if ($SandboxProfile -notin (Get-SandboxProfileSupport)) {
        $customProfile = Get-CustomProfileEntry -CustomProfileConfig $CustomProfileConfig |
            Where-Object { $_.name -ieq $SandboxProfile } |
            Select-Object -First 1

        if (-not $customProfile) {
            $catalog = Get-SandboxProfileCatalog -Manifest $Manifest -CustomProfileConfig $CustomProfileConfig
            $names = @($catalog | Select-Object -ExpandProperty name) -join ', '
            throw "Unknown profile '$SandboxProfile'. Available profiles: $names. Run -ListProfiles to see valid names."
        }

        $resolvedProfileType = 'custom'
        $baseProfile = $customProfile.base_profile
    }

    $baseToolIds = @(
        Get-ToolsForProfile -Manifest $Manifest -SandboxProfile $baseProfile | Select-Object -ExpandProperty id
    )

    $effectiveToolIds = [System.Collections.Generic.List[string]]::new()
    foreach ($toolId in $baseToolIds) {
        $effectiveToolIds.Add($toolId)
    }

    # Precedence: base profile -> custom add/remove -> template add/remove -> runtime add/remove.
    if ($customProfile) {
        foreach ($toolId in @($customProfile.add_tools)) {
            $effectiveToolIds.Add($toolId)
        }

        foreach ($toolId in @($customProfile.remove_tools)) {
            $filteredToolIds = [System.Collections.Generic.List[string]]::new()
            foreach ($effectiveToolId in $effectiveToolIds) {
                if ($effectiveToolId -ine $toolId) {
                    $filteredToolIds.Add($effectiveToolId)
                }
            }
            $effectiveToolIds = $filteredToolIds
        }
    }

    foreach ($toolId in $templateAddToolIds) {
        $effectiveToolIds.Add($toolId)
    }

    foreach ($toolId in $templateRemoveToolIds) {
        $filteredToolIds = [System.Collections.Generic.List[string]]::new()
        foreach ($effectiveToolId in $effectiveToolIds) {
            if ($effectiveToolId -ine $toolId) {
                $filteredToolIds.Add($effectiveToolId)
            }
        }
        $effectiveToolIds = $filteredToolIds
    }

    foreach ($toolId in $runtimeAddToolIds) {
        $effectiveToolIds.Add($toolId)
    }

    foreach ($toolId in $runtimeRemoveToolIds) {
        $filteredToolIds = [System.Collections.Generic.List[string]]::new()
        foreach ($effectiveToolId in $effectiveToolIds) {
            if ($effectiveToolId -ine $toolId) {
                $filteredToolIds.Add($effectiveToolId)
            }
        }
        $effectiveToolIds = $filteredToolIds
    }

    $tools = Resolve-SandboxEffectiveToolSelection -Manifest $Manifest -ToolIds @($effectiveToolIds)

    return [pscustomobject]@{
        Profile = $SandboxProfile
        BaseProfile = $baseProfile
        ProfileType = $resolvedProfileType
        TemplateAddTools = @($templateAddToolIds)
        TemplateRemoveTools = @($templateRemoveToolIds)
        RuntimeAddTools = @($runtimeAddToolIds)
        RuntimeRemoveTools = @($runtimeRemoveToolIds)
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

function Resolve-SandboxKnownToolIdList {
    <#
    .SYNOPSIS
        Validates requested tool IDs against manifest and returns canonical IDs.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest,
        [string[]]$ToolIds,
        [Parameter(Mandatory)][string]$ArgumentName
    )

    $toolById = @{}
    foreach ($tool in $Manifest.tools) {
        $toolById[$tool.id.ToLowerInvariant()] = $tool.id
    }

    $canonical = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($toolId in @($ToolIds)) {
        if ([string]::IsNullOrWhiteSpace($toolId)) {
            continue
        }

        $lookupKey = $toolId.ToLowerInvariant()
        if (-not $toolById.ContainsKey($lookupKey)) {
            throw "Unknown tool id '$toolId' in -$ArgumentName. Run -ListTools to see valid IDs."
        }

        $resolvedId = $toolById[$lookupKey]
        if ($seen.Add($resolvedId)) {
            $canonical.Add($resolvedId)
        }
    }

    return @($canonical)
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
        [switch]$SharedFolderWritable,
        [PSCustomObject]$HostInteractionPolicy
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
        -SharedFolderWritable:$SharedFolderWritable `
        -HostInteractionPolicy $HostInteractionPolicy

    return [pscustomobject]@{
        InstallManifestPath = $writtenManifestPath
        WsbPath             = $writtenWsbPath
    }
}
