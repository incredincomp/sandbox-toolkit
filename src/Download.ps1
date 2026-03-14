# src/Download.ps1
# Handles downloading tool installers with retry logic and GitHub release resolution.

function Resolve-GitHubReleaseAssetUrl {
    <#
    .SYNOPSIS
        Resolves the download URL for a release asset on GitHub using the public API.
        Honours GITHUB_TOKEN if set in the environment to avoid rate limits.
    .PARAMETER Repo
        GitHub repository in 'owner/repo' format.
    .PARAMETER AssetPattern
        Wildcard pattern to match the desired asset filename.
    #>
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$AssetPattern
    )

    $apiUrl  = "https://api.github.com/repos/$Repo/releases/latest"
    $headers = @{ 'User-Agent' = 'sandbox-toolkit/1.0' }

    # Use GITHUB_TOKEN if available to avoid the 60-req/hr unauthenticated rate limit.
    # Bearer is accepted by the GitHub REST API for both classic and fine-grained PATs.
    if ($env:GITHUB_TOKEN) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    Write-Verbose "Resolving latest release: $Repo"

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
    } catch {
        throw "Failed to query GitHub releases API for '$Repo': $_"
    }

    if (-not $release.assets -or $release.assets.Count -eq 0) {
        throw "No assets found in the latest release of '$Repo'."
    }

    $asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        $available = ($release.assets | ForEach-Object { $_.name }) -join ', '
        throw "No asset matching '$AssetPattern' in '$Repo' release '$($release.tag_name)'.`nAvailable: $available"
    }

    Write-Verbose "Resolved: $($asset.name) ($($release.tag_name))"
    return @{
        Url     = $asset.browser_download_url
        Version = $release.tag_name
        Name    = $asset.name
    }
}

function Invoke-FileDownload {
    <#
    .SYNOPSIS
        Downloads a file with retry logic. Skips if the file already exists and -Force is not set.
    .PARAMETER Url
        The URL to download from.
    .PARAMETER Destination
        Full path where the file should be saved.
    .PARAMETER UserAgent
        HTTP User-Agent string. Defaults to 'sandbox-toolkit/1.0'.
        SourceForge's "latest" redirect requires a Wget-style agent to resolve to the correct file.
    .PARAMETER MaxRetries
        Number of retry attempts on failure (default: 3).
    .PARAMETER Force
        Re-download even if the file already exists.
    #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination,
        [string]$UserAgent = 'sandbox-toolkit/1.0',
        [int]$MaxRetries = 3,
        [switch]$Force
    )

    if ((Test-Path $Destination) -and -not $Force) {
        $size = (Get-Item $Destination).Length
        Write-StatusLine "  [SKIP] $(Split-Path -Leaf $Destination) ($([math]::Round($size/1MB, 1)) MB cached)" -ForegroundColor DarkGray
        return
    }

    $dir = Split-Path $Destination
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $leaf = Split-Path -Leaf $Destination
    $attempt = 0

    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            Write-StatusLine "  [DOWN] $leaf (attempt $attempt/$MaxRetries)" -ForegroundColor Cyan
            Write-Verbose "         URL: $Url"

            $start = Get-Date

            # Invoke-WebRequest shows a progress bar in PS5.1 and cleans up on failure.
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing `
                -Headers @{ 'User-Agent' = $UserAgent } -ErrorAction Stop

            if (-not (Test-Path $Destination) -or (Get-Item $Destination).Length -eq 0) {
                throw "Download produced an empty file."
            }

            $elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
            $sizeMb  = [math]::Round((Get-Item $Destination).Length / 1MB, 2)
            Write-StatusLine "  [OK]   $leaf -- $sizeMb MB in $($elapsed)s" -ForegroundColor Green
            return

        } catch {
            Write-Warning "  Attempt $attempt failed for $leaf`: $_"
            if (Test-Path $Destination) { Remove-Item $Destination -Force }
            if ($attempt -ge $MaxRetries) {
                throw "Failed to download '$leaf' after $MaxRetries attempts: $_"
            }
            Start-Sleep -Seconds ($attempt * 3)
        }
    }
}

function Invoke-ToolDownload {
    <#
    .SYNOPSIS
        Downloads a single tool entry from the manifest to the setups directory.
    .PARAMETER Tool
        A tool object from the manifest.
    .PARAMETER SetupDir
        Directory where downloaded files are saved.
    .PARAMETER Force
        Re-download even if the file already exists.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Tool,
        [Parameter(Mandatory)][string]$SetupDir,
        [switch]$Force
    )

    if ($Tool.installer_type -eq 'manual') {
        Write-StatusLine "  [MANU] $($Tool.display_name) -- manual install required." -ForegroundColor Yellow
        if ($Tool.notes) {
            Write-StatusLine "         $($Tool.notes)" -ForegroundColor DarkYellow
        }
        # Still download the file into setups so it's available inside the sandbox.
    }

    $destination = Join-Path $SetupDir $Tool.filename

    # SourceForge "latest" redirects require a Wget-style User-Agent to resolve to the
    # correct platform binary rather than the download page HTML.
    $userAgent = if ($Tool.source_type -eq 'sourceforge') { 'Wget/1.21' } else { 'sandbox-toolkit/1.0' }

    $url = switch ($Tool.source_type) {
        'vendor'         { $Tool.source_url }
        'sourceforge'    { $Tool.source_url }
        'github_release' {
            $resolved = Resolve-GitHubReleaseAssetUrl -Repo $Tool.github_repo -AssetPattern $Tool.asset_pattern
            $resolved.Url
        }
        default { throw "Unknown source_type '$($Tool.source_type)' for tool '$($Tool.id)'." }
    }

    Invoke-FileDownload -Url $url -Destination $destination -UserAgent $userAgent -Force:$Force
}

function Invoke-DownloadQueue {
    <#
    .SYNOPSIS
        Downloads all tools in the filtered list to the setups directory.
    .PARAMETER Tools
        Ordered list of tool objects from Get-ToolsForProfile.
    .PARAMETER SetupDir
        Directory where downloaded files are saved (scripts/setups).
    .PARAMETER Force
        Re-download all files even if they exist.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Tools,
        [Parameter(Mandatory)][string]$SetupDir,
        [switch]$Force
    )

    $failed = [System.Collections.Generic.List[string]]::new()

    foreach ($tool in $Tools) {
        try {
            Invoke-ToolDownload -Tool $tool -SetupDir $SetupDir -Force:$Force
        } catch {
            Write-Warning "Failed to download '$($tool.id)': $_"
            $failed.Add($tool.id)
        }
    }

    if ($failed.Count -gt 0) {
        throw "Download failed for: $($failed -join ', '). Re-run to retry (cached files are skipped)."
    }
}
