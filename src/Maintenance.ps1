# src/Maintenance.ps1
# Helpers for repo-owned disposable download/session artifact cleanup.

function Get-SandboxDisposableDownloadLocationCatalog {
    <#
    .SYNOPSIS
        Returns known repo-owned disposable artifact locations.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $setupCachePath = Join-Path $RepoRoot 'scripts\setups'
    $installManifestPath = Join-Path $RepoRoot 'scripts\install-manifest.json'
    $wsbPath = Join-Path $RepoRoot 'sandbox.wsb'

    return @(
        [pscustomobject]@{
            id = 'setup-cache'
            type = 'directory-contents'
            path = $setupCachePath
        },
        [pscustomobject]@{
            id = 'install-manifest'
            type = 'file'
            path = $installManifestPath
        },
        [pscustomobject]@{
            id = 'sandbox-config'
            type = 'file'
            path = $wsbPath
        }
    )
}

function Test-SandboxPathWithinRoot {
    <#
    .SYNOPSIS
        Returns true when Path is within RootPath.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RootPath
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($RootPath)
    if (-not $fullRoot.EndsWith('\')) {
        $fullRoot = "$fullRoot\"
    }

    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-SandboxDownloadCleanupPlan {
    <#
    .SYNOPSIS
        Discovers cleanup candidates from known repo-owned disposable locations.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $locations = @(Get-SandboxDisposableDownloadLocationCatalog -RepoRoot $RepoRoot)
    $candidates = [System.Collections.Generic.List[object]]::new()
    $skipped = [System.Collections.Generic.List[object]]::new()
    $inspected = [System.Collections.Generic.List[object]]::new()

    foreach ($location in $locations) {
        $locationPath = $location.path
        $locationExists = Test-Path -LiteralPath $locationPath
        $inspected.Add([pscustomobject]@{
            location_id = $location.id
            location_type = $location.type
            path = $locationPath
            exists = [bool]$locationExists
        })

        if (-not $locationExists) {
            continue
        }

        if ($location.type -eq 'file') {
            $candidates.Add([pscustomobject]@{
                location_id = $location.id
                path = $locationPath
                is_container = $false
            })
            continue
        }

        $children = @(Get-ChildItem -LiteralPath $locationPath -Force)
        foreach ($child in $children) {
            $childPath = $child.FullName
            if ($location.id -eq 'setup-cache' -and -not $child.PSIsContainer -and $child.Name -ieq '.gitkeep') {
                $skipped.Add([pscustomobject]@{
                    location_id = $location.id
                    path = $childPath
                    reason = 'tracked-placeholder'
                })
                continue
            }

            if (-not (Test-SandboxPathWithinRoot -Path $childPath -RootPath $locationPath)) {
                $skipped.Add([pscustomobject]@{
                    location_id = $location.id
                    path = $childPath
                    reason = 'outside-location-root'
                })
                continue
            }

            if ($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $skipped.Add([pscustomobject]@{
                    location_id = $location.id
                    path = $childPath
                    reason = 'reparse-point'
                })
                continue
            }

            $candidates.Add([pscustomobject]@{
                location_id = $location.id
                path = $childPath
                is_container = [bool]$child.PSIsContainer
            })
        }
    }

    return [pscustomobject]@{
        InspectedLocations = @($inspected)
        Candidates = @($candidates)
        Skipped = @($skipped)
    }
}

function Invoke-SandboxDownloadCleanup {
    <#
    .SYNOPSIS
        Executes cleanup plan against discovered candidates.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$CleanupPlan,
        [ScriptBlock]$RemoveAction
    )

    if (-not $RemoveAction) {
        $RemoveAction = {
            param($Path, $IsContainer)
            if ($IsContainer) {
                Remove-Item -LiteralPath $Path -Recurse -Force
            } else {
                Remove-Item -LiteralPath $Path -Force
            }
        }
    }

    $removed = [System.Collections.Generic.List[object]]::new()
    $failed = [System.Collections.Generic.List[object]]::new()

    foreach ($candidate in @($CleanupPlan.Candidates)) {
        try {
            & $RemoveAction $candidate.path $candidate.is_container
            $removed.Add([pscustomobject]@{
                location_id = $candidate.location_id
                path = $candidate.path
            })
        } catch {
            $failed.Add([pscustomobject]@{
                location_id = $candidate.location_id
                path = $candidate.path
                message = $_.Exception.Message
            })
        }
    }

    return [pscustomobject]@{
        InspectedLocations = @($CleanupPlan.InspectedLocations)
        Skipped = @($CleanupPlan.Skipped)
        Removed = @($removed)
        Failed = @($failed)
        CandidateCount = @($CleanupPlan.Candidates).Count
        RemovedCount = $removed.Count
        FailedCount = $failed.Count
        Success = ($failed.Count -eq 0)
        NothingToClean = (@($CleanupPlan.Candidates).Count -eq 0)
    }
}

function Get-SandboxDownloadCleanupSummary {
    <#
    .SYNOPSIS
        Returns human-readable summary lines for cleanup results.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$CleanupResult
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('[Cleanup] Download/session artifact cleanup')

    $lines.Add('[Cleanup] Inspected locations:')
    foreach ($location in @($CleanupResult.InspectedLocations)) {
        $state = if ($location.exists) { 'present' } else { 'missing' }
        $lines.Add("  - $($location.location_id): $($location.path) [$state]")
    }

    if ($CleanupResult.NothingToClean) {
        $lines.Add('[Cleanup] Nothing to clean.')
    } else {
        $lines.Add("[Cleanup] Removed: $($CleanupResult.RemovedCount) item(s).")
        foreach ($entry in @($CleanupResult.Removed)) {
            $lines.Add("  - removed: $($entry.path)")
        }
    }

    if (@($CleanupResult.Skipped).Count -gt 0) {
        $lines.Add("[Cleanup] Skipped: $(@($CleanupResult.Skipped).Count) item(s).")
        foreach ($entry in @($CleanupResult.Skipped)) {
            $lines.Add("  - skipped ($($entry.reason)): $($entry.path)")
        }
    }

    if ($CleanupResult.FailedCount -gt 0) {
        $lines.Add("[Cleanup] Failures: $($CleanupResult.FailedCount) item(s).")
        foreach ($entry in @($CleanupResult.Failed)) {
            $lines.Add("  - failed: $($entry.path) :: $($entry.message)")
        }
    } else {
        $lines.Add('[Cleanup] Completed without deletion failures.')
    }

    return @($lines)
}
