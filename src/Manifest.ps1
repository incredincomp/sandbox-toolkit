# src/Manifest.ps1
# Loads and filters the tools.json manifest.

$script:SupportedSandboxProfiles = @(
    'minimal',
    'reverse-engineering',
    'network-analysis',
    'full',
    'triage-plus',
    'reverse-windows',
    'behavior-net',
    'dev-windows'
)

function Get-SandboxProfileSupport {
    <#
    .SYNOPSIS
        Returns profiles supported by Start-Sandbox.ps1.
    #>
    return @($script:SupportedSandboxProfiles)
}

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

    $validProfiles = Get-SandboxProfileSupport
    if ($SandboxProfile -notin $validProfiles) {
        throw "Unknown profile '$SandboxProfile'. Valid built-in profiles: $($validProfiles -join ', ')"
    }

    $tools = $Manifest.tools | Where-Object { $SandboxProfile -in $_.profiles }
    return $tools | Sort-Object install_order
}

function Import-CustomProfileConfig {
    <#
    .SYNOPSIS
        Loads optional local custom profile configuration.
    #>
    param(
        [Parameter(Mandatory)][string]$CustomProfilePath
    )

    if (-not (Test-Path -LiteralPath $CustomProfilePath -PathType Leaf)) {
        return [pscustomobject]@{
            schema_version = '1.0'
            profiles       = @()
        }
    }

    try {
        $config = Get-Content -Raw -Path $CustomProfilePath | ConvertFrom-Json
    } catch {
        throw "Malformed custom profile config '$CustomProfilePath': $($_.Exception.Message)"
    }

    if (-not $config.PSObject.Properties['profiles']) {
        throw "Malformed custom profile config '$CustomProfilePath': missing required 'profiles' property."
    }

    if (-not $config.profiles) {
        $config | Add-Member -MemberType NoteProperty -Name profiles -Value @() -Force
    }

    return $config
}

function Get-ManifestProfile {
    <#
    .SYNOPSIS
        Returns built-in profiles present in the manifest today.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest
    )

    $manifestProfiles = $Manifest.tools |
        ForEach-Object { $_.profiles } |
        Where-Object { $_ } |
        Select-Object -Unique

    return @(
        Get-SandboxProfileSupport | Where-Object { $_ -in $manifestProfiles }
    )
}

function Get-CustomProfileEntry {
    <#
    .SYNOPSIS
        Returns custom profile entries from parsed custom config.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$CustomProfileConfig
    )

    return @($CustomProfileConfig.profiles)
}

function Get-SandboxProfileCatalog {
    <#
    .SYNOPSIS
        Returns built-in and custom profile catalog entries.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Manifest,
        [Parameter(Mandatory)][PSCustomObject]$CustomProfileConfig
    )

    $catalog = [System.Collections.Generic.List[object]]::new()
    foreach ($profileEntry in (Get-ManifestProfile -Manifest $Manifest)) {
        $catalog.Add([pscustomobject]@{
            name         = $profileEntry
            profile_type = 'built-in'
            base_profile = $profileEntry
        })
    }

    foreach ($profileEntry in (Get-CustomProfileEntry -CustomProfileConfig $CustomProfileConfig)) {
        $catalog.Add([pscustomobject]@{
            name         = $profileEntry.name
            profile_type = 'custom'
            base_profile = $profileEntry.base_profile
        })
    }

    return @($catalog)
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

        $updateProperty = $tool.PSObject.Properties['update']
        if ($updateProperty -and $updateProperty.Value) {
            $update = $updateProperty.Value
            $strategyProperty = $update.PSObject.Properties['strategy']
            $strategy = if ($strategyProperty) { [string]$strategyProperty.Value } else { '' }
            if ([string]::IsNullOrWhiteSpace($strategy)) {
                $errors += "Tool '$($tool.id)': update metadata requires non-empty 'strategy'."
            } else {
                switch ($strategy) {
                    'github_release' {
                        $updateRepoProperty = $update.PSObject.Properties['github_repo']
                        $toolRepoProperty = $tool.PSObject.Properties['github_repo']
                        $updateRepo = if ($updateRepoProperty) { [string]$updateRepoProperty.Value } else { '' }
                        $toolRepo = if ($toolRepoProperty) { [string]$toolRepoProperty.Value } else { '' }
                        if ([string]::IsNullOrWhiteSpace($updateRepo) -and [string]::IsNullOrWhiteSpace($toolRepo)) {
                            $errors += "Tool '$($tool.id)': update strategy 'github_release' requires update.github_repo or tool.github_repo."
                        }
                    }
                    'rss' {
                        $rssUrlProperty = $update.PSObject.Properties['rss_url']
                        $versionRegexProperty = $update.PSObject.Properties['version_regex']
                        $rssUrl = if ($rssUrlProperty) { [string]$rssUrlProperty.Value } else { '' }
                        $versionRegex = if ($versionRegexProperty) { [string]$versionRegexProperty.Value } else { '' }
                        if ([string]::IsNullOrWhiteSpace($rssUrl)) {
                            $errors += "Tool '$($tool.id)': update strategy 'rss' requires 'rss_url'."
                        }
                        if ([string]::IsNullOrWhiteSpace($versionRegex)) {
                            $errors += "Tool '$($tool.id)': update strategy 'rss' requires 'version_regex'."
                        }
                    }
                    'static' {
                        $latestProperty = $update.PSObject.Properties['static_latest_version']
                        $latestVersion = if ($latestProperty) { [string]$latestProperty.Value } else { '' }
                        if ([string]::IsNullOrWhiteSpace($latestVersion)) {
                            $errors += "Tool '$($tool.id)': update strategy 'static' requires 'static_latest_version'."
                        }
                    }
                    'unsupported' { }
                    default {
                        $errors += "Tool '$($tool.id)': update strategy '$strategy' is unsupported."
                    }
                }
            }
        }
    }

    foreach ($tool in $Manifest.tools) {
        $dependencyProperty = $tool.PSObject.Properties['dependencies']
        if (-not $dependencyProperty -or -not $dependencyProperty.Value) {
            continue
        }

        foreach ($dependencyId in $dependencyProperty.Value) {
            if (-not $ids.ContainsKey($dependencyId)) {
                $errors += "Tool '$($tool.id)': dependency '$dependencyId' does not reference an existing tool id."
            }
        }
    }

    if ($errors.Count -gt 0) {
        throw "Manifest validation failed:`n  " + ($errors -join "`n  ")
    }

    Write-Verbose "Manifest integrity OK: $($Manifest.tools.Count) tools."
}

function Test-CustomProfileConfigIntegrity {
    <#
    .SYNOPSIS
        Validates custom profile config shape and tool references.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$CustomProfileConfig,
        [Parameter(Mandatory)][PSCustomObject]$Manifest
    )

    $errors = @()
    $toolIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($tool in $Manifest.tools) {
        [void]$toolIdSet.Add($tool.id)
    }

    $builtInProfileSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($profileEntry in (Get-SandboxProfileSupport)) {
        [void]$builtInProfileSet.Add($profileEntry)
    }

    $seenCustomNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($profileEntry in (Get-CustomProfileEntry -CustomProfileConfig $CustomProfileConfig)) {
        if (-not $profileEntry.PSObject.Properties['name'] -or [string]::IsNullOrWhiteSpace($profileEntry.name)) {
            $errors += 'Custom profile entry is missing required non-empty "name".'
            continue
        }

        if ($builtInProfileSet.Contains($profileEntry.name)) {
            $errors += "Custom profile '$($profileEntry.name)' conflicts with built-in profile name."
        }

        if (-not $seenCustomNames.Add($profileEntry.name)) {
            $errors += "Duplicate custom profile name: '$($profileEntry.name)'."
        }

        if (-not $profileEntry.PSObject.Properties['base_profile'] -or [string]::IsNullOrWhiteSpace($profileEntry.base_profile)) {
            $errors += "Custom profile '$($profileEntry.name)' is missing required 'base_profile'."
        } elseif (-not $builtInProfileSet.Contains($profileEntry.base_profile)) {
            $errors += "Custom profile '$($profileEntry.name)' references unknown base_profile '$($profileEntry.base_profile)'."
        }

        foreach ($fieldName in @('add_tools', 'remove_tools')) {
            if (-not $profileEntry.PSObject.Properties[$fieldName]) {
                continue
            }

            $ids = @($profileEntry.$fieldName)
            foreach ($toolId in $ids) {
                if ([string]::IsNullOrWhiteSpace($toolId)) {
                    $errors += "Custom profile '$($profileEntry.name)' contains empty tool id in '$fieldName'."
                    continue
                }
                if (-not $toolIdSet.Contains($toolId)) {
                    $errors += "Custom profile '$($profileEntry.name)' references unknown tool id '$toolId' in '$fieldName'."
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        throw "Custom profile validation failed:`n  " + ($errors -join "`n  ")
    }
}
