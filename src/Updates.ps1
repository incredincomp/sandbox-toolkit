# src/Updates.ps1
# Read-only tool update/version discovery helpers.

function Get-SandboxObjectPropertyValue {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$PropertyName
    )

    if (-not $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if (-not $property) {
        return $null
    }

    return $property.Value
}

function Get-SandboxToolUpdateConfig {
    param(
        [Parameter(Mandatory)][PSCustomObject]$Tool
    )

    $updateProperty = $Tool.PSObject.Properties['update']
    if (-not $updateProperty) {
        return $null
    }

    return $updateProperty.Value
}

function Get-SandboxVersionComparisonTuple {
    param(
        [AllowEmptyString()][string]$Version
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        return $null
    }

    $normalized = $Version.Trim()
    if ($normalized -match '^[vV](.+)$') {
        $normalized = $matches[1]
    }

    $versionMatches = [regex]::Matches($normalized, '\d+')
    if ($versionMatches.Count -eq 0) {
        return $null
    }

    $parts = [System.Collections.Generic.List[int]]::new()
    foreach ($match in $versionMatches) {
        [void]$parts.Add([int]$match.Value)
    }
    return @($parts)
}

function Compare-SandboxVersion {
    param(
        [AllowEmptyString()][string]$ConfiguredVersion,
        [AllowEmptyString()][string]$LatestVersion
    )

    if ([string]::IsNullOrWhiteSpace($ConfiguredVersion) -or [string]::IsNullOrWhiteSpace($LatestVersion)) {
        return $null
    }

    if ($ConfiguredVersion.Trim().ToLowerInvariant() -eq 'latest') {
        return 0
    }

    $configuredParts = Get-SandboxVersionComparisonTuple -Version $ConfiguredVersion
    $latestParts = Get-SandboxVersionComparisonTuple -Version $LatestVersion
    if (-not $configuredParts -or -not $latestParts) {
        return $null
    }

    $max = [Math]::Max($configuredParts.Count, $latestParts.Count)
    for ($index = 0; $index -lt $max; $index++) {
        $left = if ($index -lt $configuredParts.Count) { $configuredParts[$index] } else { 0 }
        $right = if ($index -lt $latestParts.Count) { $latestParts[$index] } else { 0 }
        if ($left -lt $right) {
            return -1
        }
        if ($left -gt $right) {
            return 1
        }
    }

    return 0
}

function Resolve-SandboxGitHubLatestVersion {
    param(
        [Parameter(Mandatory)][string]$Repo,
        [string]$AssetPattern
    )

    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    $headers = @{ 'User-Agent' = 'sandbox-toolkit/1.0' }
    if ($env:GITHUB_TOKEN) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
    $tagName = [string](Get-SandboxObjectPropertyValue -InputObject $release -PropertyName 'tag_name')
    if (-not $tagName) {
        throw "GitHub latest release response for '$Repo' did not include tag_name."
    }

    if ($AssetPattern) {
        $assets = @((Get-SandboxObjectPropertyValue -InputObject $release -PropertyName 'assets'))
        if ($assets.Count -eq 0) {
            throw "GitHub latest release for '$Repo' did not include assets."
        }

        $asset = $assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
        if (-not $asset) {
            throw "GitHub latest release for '$Repo' did not include an asset matching '$AssetPattern'."
        }
    }

    return [pscustomobject]@{
        LatestVersion = $tagName
        SourceType = 'github_release'
    }
}

function Get-SandboxRssCandidateEntryText {
    param(
        [Parameter(Mandatory)][object]$FeedResponse
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    $rssItems = @()
    $atomEntries = @()

    if ($FeedResponse -is [xml]) {
        $rssNode = Get-SandboxObjectPropertyValue -InputObject $FeedResponse -PropertyName 'rss'
        $feedNode = Get-SandboxObjectPropertyValue -InputObject $FeedResponse -PropertyName 'feed'
        if ($rssNode) {
            $rssItems = @($rssNode.channel.item)
        }
        if ($feedNode) {
            $atomEntries = @($feedNode.entry)
        }
    } else {
        $hasStructuredRss = $FeedResponse.PSObject.Properties['rss'] -or $FeedResponse.PSObject.Properties['feed']
        if ($hasStructuredRss) {
            $rssNode = Get-SandboxObjectPropertyValue -InputObject $FeedResponse -PropertyName 'rss'
            $feedNode = Get-SandboxObjectPropertyValue -InputObject $FeedResponse -PropertyName 'feed'
            if ($rssNode) {
                $rssItems = @($rssNode.channel.item)
            }
            if ($feedNode) {
                $atomEntries = @($feedNode.entry)
            }
        } else {
            $raw = [string]$FeedResponse
            if ([string]::IsNullOrWhiteSpace($raw)) {
                return @()
            }

            $xml = [xml]$raw
            $rssNode = Get-SandboxObjectPropertyValue -InputObject $xml -PropertyName 'rss'
            $feedNode = Get-SandboxObjectPropertyValue -InputObject $xml -PropertyName 'feed'
            if ($rssNode) {
                $rssItems = @($rssNode.channel.item)
            }
            if ($feedNode) {
                $atomEntries = @($feedNode.entry)
            }
        }
    }

    foreach ($item in $rssItems) {
        $title = [string](Get-SandboxObjectPropertyValue -InputObject $item -PropertyName 'title')
        $link = [string](Get-SandboxObjectPropertyValue -InputObject $item -PropertyName 'link')
        $description = [string](Get-SandboxObjectPropertyValue -InputObject $item -PropertyName 'description')
        $parts = @(
            $title,
            $link,
            $description
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($parts.Count -gt 0) {
            $candidates.Add(($parts -join ' '))
        }
    }

    foreach ($entry in $atomEntries) {
        $title = ''
        $entryTitle = Get-SandboxObjectPropertyValue -InputObject $entry -PropertyName 'title'
        if ($entryTitle) {
            $titleHashText = Get-SandboxObjectPropertyValue -InputObject $entryTitle -PropertyName '#text'
            $title = [string]$titleHashText
            if ([string]::IsNullOrWhiteSpace($title)) {
                $title = [string]$entryTitle
            }
        }
        $summary = [string](Get-SandboxObjectPropertyValue -InputObject $entry -PropertyName 'summary')
        $content = [string](Get-SandboxObjectPropertyValue -InputObject $entry -PropertyName 'content')
        $parts = @($title, $summary, $content) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($parts.Count -gt 0) {
            $candidates.Add(($parts -join ' '))
        }
    }

    return @($candidates)
}

function Resolve-SandboxRssLatestVersion {
    param(
        [Parameter(Mandatory)][string]$FeedUrl,
        [Parameter(Mandatory)][string]$VersionRegex
    )

    $headers = @{ 'User-Agent' = 'sandbox-toolkit/1.0' }
    $feedResponse = Invoke-RestMethod -Uri $FeedUrl -Headers $headers -ErrorAction Stop
    $candidateTexts = @(Get-SandboxRssCandidateEntryText -FeedResponse $feedResponse)
    if ($candidateTexts.Count -eq 0) {
        throw "RSS/Atom feed '$FeedUrl' did not include parseable entries."
    }

    foreach ($candidate in $candidateTexts) {
        $match = [regex]::Match($candidate, $VersionRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success -and $match.Groups.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($match.Groups[1].Value)) {
            return [pscustomobject]@{
                LatestVersion = $match.Groups[1].Value
                SourceType = 'rss'
            }
        }
    }

    throw "No version match found in RSS/Atom feed '$FeedUrl' using regex '$VersionRegex'."
}

function Resolve-SandboxStaticLatestVersion {
    param(
        [Parameter(Mandatory)][string]$LatestVersion
    )

    return [pscustomobject]@{
        LatestVersion = $LatestVersion
        SourceType = 'static'
    }
}

function Get-SandboxToolUpdateConfidence {
    param(
        [string]$ConfiguredConfidence,
        [Parameter(Mandatory)][string]$SourceType
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredConfidence)) {
        return $ConfiguredConfidence
    }

    switch ($SourceType) {
        'github_release' { return 'high' }
        'rss' { return 'medium' }
        'static' { return 'low' }
        default { return 'low' }
    }
}

function Invoke-SandboxToolUpdateCheck {
    param(
        [Parameter(Mandatory)][PSCustomObject]$Tool
    )

    $configuredVersion = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'version')
    $updateMetadata = Get-SandboxToolUpdateConfig -Tool $Tool
    if (-not $updateMetadata) {
        return [pscustomobject]@{
            id = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'id')
            display_name = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'display_name')
            configured_version = $configuredVersion
            latest_version = $null
            status = 'unsupported-for-checking'
            source_type = $null
            source_confidence = 'low'
            message = 'No update metadata is configured for this tool.'
        }
    }

    $strategy = [string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'strategy')
    $confidence = Get-SandboxToolUpdateConfidence `
        -ConfiguredConfidence ([string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'source_confidence')) `
        -SourceType $strategy
    if ($strategy -eq 'unsupported') {
        $unsupportedNotes = [string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'notes')
        $unsupportedMessage = if ($unsupportedNotes) { $unsupportedNotes } else { 'Tool is marked unsupported for automated update checks.' }
        return [pscustomobject]@{
            id = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'id')
            display_name = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'display_name')
            configured_version = $configuredVersion
            latest_version = $null
            status = 'unsupported-for-checking'
            source_type = $strategy
            source_confidence = $confidence
            message = $unsupportedMessage
        }
    }

    $latestVersion = $null
    $message = ''
    try {
        $resolution = switch ($strategy) {
            'github_release' {
                $repo = [string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'github_repo')
                if ([string]::IsNullOrWhiteSpace($repo)) {
                    $repo = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'github_repo')
                }
                $assetPattern = [string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'asset_pattern')
                if ([string]::IsNullOrWhiteSpace($assetPattern)) {
                    $assetPattern = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'asset_pattern')
                }
                Resolve-SandboxGitHubLatestVersion -Repo $repo -AssetPattern $assetPattern
            }
            'rss' {
                Resolve-SandboxRssLatestVersion `
                    -FeedUrl ([string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'rss_url')) `
                    -VersionRegex ([string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'version_regex'))
            }
            'static' {
                Resolve-SandboxStaticLatestVersion `
                    -LatestVersion ([string](Get-SandboxObjectPropertyValue -InputObject $updateMetadata -PropertyName 'static_latest_version'))
            }
            default {
                throw "Unsupported update strategy '$strategy'."
            }
        }

        $latestVersion = [string]$resolution.LatestVersion
    } catch {
        return [pscustomobject]@{
            id = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'id')
            display_name = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'display_name')
            configured_version = $configuredVersion
            latest_version = $null
            status = 'unknown'
            source_type = $strategy
            source_confidence = $confidence
            message = "Could not determine latest version: $($_.Exception.Message)"
        }
    }

    $comparison = Compare-SandboxVersion -ConfiguredVersion $configuredVersion -LatestVersion $latestVersion
    $status = 'unknown'
    if ($configuredVersion -and $configuredVersion.Trim().ToLowerInvariant() -eq 'latest') {
        $status = 'up-to-date'
        $message = "Configured version is rolling ('latest'); source reports latest as '$latestVersion'."
    } elseif ($comparison -eq -1) {
        $status = 'outdated'
        $message = "Configured version '$configuredVersion' is behind latest '$latestVersion'."
    } elseif ($comparison -eq 0) {
        $status = 'up-to-date'
        $message = "Configured version '$configuredVersion' matches latest '$latestVersion'."
    } elseif ($comparison -eq 1) {
        $status = 'unknown'
        $message = "Configured version '$configuredVersion' appears newer than discovered '$latestVersion'."
    } else {
        $status = 'unknown'
        $message = "Version comparison is inconclusive for configured '$configuredVersion' and latest '$latestVersion'."
    }

    return [pscustomobject]@{
        id = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'id')
        display_name = [string](Get-SandboxObjectPropertyValue -InputObject $Tool -PropertyName 'display_name')
        configured_version = $configuredVersion
        latest_version = $latestVersion
        status = $status
        source_type = $strategy
        source_confidence = $confidence
        message = $message
    }
}

function Invoke-SandboxToolUpdateCatalog {
    param(
        [Parameter(Mandatory)][object[]]$Tools
    )

    return @(
        $Tools | ForEach-Object { Invoke-SandboxToolUpdateCheck -Tool $_ }
    )
}

function Get-SandboxToolUpdateSummary {
    param(
        [Parameter(Mandatory)][object[]]$Results
    )

    return [pscustomobject]@{
        total = @($Results).Count
        up_to_date = @($Results | Where-Object { $_.status -eq 'up-to-date' }).Count
        outdated = @($Results | Where-Object { $_.status -eq 'outdated' }).Count
        unknown = @($Results | Where-Object { $_.status -eq 'unknown' }).Count
        unsupported = @($Results | Where-Object { $_.status -eq 'unsupported-for-checking' }).Count
    }
}
