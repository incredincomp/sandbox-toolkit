function Get-NormalizedFullPath {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $fullPath = [System.IO.Path]::GetFullPath($resolved.Path)
    return $fullPath.TrimEnd('\')
}

function Get-SharedFolderBlockedPathPolicy {
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $normalizedRepoRoot = Get-NormalizedFullPath -Path $RepoRoot

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $downloadsPath = $null
    if ($env:USERPROFILE) {
        $downloadsPath = Join-Path $env:USERPROFILE 'Downloads'
    }

    return @(
        [pscustomobject]@{
            Category  = 'repository root'
            Rationale = 'mapping the entire repository can expose unrelated files'
            Path      = $normalizedRepoRoot
        }
        [pscustomobject]@{
            Category  = 'Windows directory'
            Rationale = 'system directories are sensitive and overly broad'
            Path      = $env:windir
        }
        [pscustomobject]@{
            Category  = 'Program Files'
            Rationale = 'program install roots are broad and contain host binaries'
            Path      = $env:ProgramFiles
        }
        [pscustomobject]@{
            Category  = 'Program Files (x86)'
            Rationale = 'program install roots are broad and contain host binaries'
            Path      = ${env:ProgramFiles(x86)}
        }
        [pscustomobject]@{
            Category  = 'ProgramW6432'
            Rationale = 'program install roots are broad and contain host binaries'
            Path      = $env:ProgramW6432
        }
        [pscustomobject]@{
            Category  = 'user profile root'
            Rationale = 'profile root contains broad personal and application data'
            Path      = $env:USERPROFILE
        }
        [pscustomobject]@{
            Category  = 'Desktop root'
            Rationale = 'Desktop often contains user documents and active files'
            Path      = $desktopPath
        }
        [pscustomobject]@{
            Category  = 'Documents root'
            Rationale = 'Documents is a common location for sensitive personal files'
            Path      = $documentsPath
        }
        [pscustomobject]@{
            Category  = 'Downloads root'
            Rationale = 'Downloads is a broad ingress area for arbitrary host files'
            Path      = $downloadsPath
        }
    )
}

function Get-ResolvedSharedFolderBlockedPathPolicy {
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $resolvedPolicy = @()
    foreach ($entry in Get-SharedFolderBlockedPathPolicy -RepoRoot $RepoRoot) {
        if (-not $entry.Path) {
            continue
        }

        try {
            $resolvedPolicy += [pscustomobject]@{
                Category  = $entry.Category
                Rationale = $entry.Rationale
                Path      = Get-NormalizedFullPath -Path $entry.Path
            }
        } catch {
            Write-Verbose "Skipping non-resolvable blocked-path policy entry '$($entry.Category)': $($_.Exception.Message)"
        }
    }

    return $resolvedPolicy
}

function Assert-SharedFolderParameterUsage {
    param(
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable
    )

    if ($SharedFolder -and $UseDefaultSharedFolder) {
        throw "Use either -SharedFolder or -UseDefaultSharedFolder, not both."
    }

    if ($SharedFolderWritable -and -not ($SharedFolder -or $UseDefaultSharedFolder)) {
        throw "-SharedFolderWritable requires -SharedFolder or -UseDefaultSharedFolder."
    }
}

function Test-SharedFolderTargetIsReparsePoint {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    return [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Assert-SafeSharedFolderPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $normalizedPath = Get-NormalizedFullPath -Path $Path

    if (-not (Test-Path -LiteralPath $normalizedPath -PathType Container)) {
        throw "Shared folder path must exist and be a directory: $normalizedPath"
    }

    if (Test-SharedFolderTargetIsReparsePoint -Path $normalizedPath) {
        throw "Shared folder path is not allowed: '$normalizedPath' is a reparse point or junction. Use a real directory path."
    }

    foreach ($entry in Get-ResolvedSharedFolderBlockedPathPolicy -RepoRoot $RepoRoot) {
        if ($normalizedPath -ieq $entry.Path) {
            throw "Shared folder path is not allowed: '$normalizedPath' matches blocked category '$($entry.Category)' because $($entry.Rationale). Use a dedicated analysis ingress folder."
        }
    }

    $pathRoot = [System.IO.Path]::GetPathRoot($normalizedPath).TrimEnd('\')
    if ($normalizedPath -ieq $pathRoot) {
        throw "Shared folder path is not allowed: '$normalizedPath' matches blocked category 'drive root' because mapping a full drive is overly broad."
    }

    $relativeFromRoot = $normalizedPath.Substring([System.IO.Path]::GetPathRoot($normalizedPath).Length).Trim('\')
    if ($relativeFromRoot) {
        $segmentCount = ($relativeFromRoot -split '[\\/]').Count
        if ($segmentCount -lt 2) {
            throw "Shared folder path is too broad: use a deeper dedicated folder (for example, 'C:\Lab\Ingress' instead of '$normalizedPath')."
        }
    }

    return $normalizedPath
}

function Resolve-SharedFolderRequest {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [ScriptBlock]$OnDefaultSharedFolderCreated
    )

    Assert-SharedFolderParameterUsage `
        -SharedFolder $SharedFolder `
        -UseDefaultSharedFolder:$UseDefaultSharedFolder `
        -SharedFolderWritable:$SharedFolderWritable

    $defaultSharedFolder = Join-Path $RepoRoot 'shared'
    $requestedSharedFolder = $null

    if ($UseDefaultSharedFolder) {
        if (-not (Test-Path -LiteralPath $defaultSharedFolder -PathType Container)) {
            New-Item -ItemType Directory -Path $defaultSharedFolder -Force | Out-Null
            if ($OnDefaultSharedFolderCreated) {
                & $OnDefaultSharedFolderCreated $defaultSharedFolder
            }
        }
        $requestedSharedFolder = $defaultSharedFolder
    } elseif ($SharedFolder) {
        $requestedSharedFolder = $SharedFolder
    }

    $resolvedSharedFolder = $null
    if ($requestedSharedFolder) {
        $resolvedSharedFolder = Assert-SafeSharedFolderPath -Path $requestedSharedFolder -RepoRoot $RepoRoot
    }

    return [pscustomobject]@{
        SharedHostFolder = $resolvedSharedFolder
        SharedFolderWritable = [bool]$SharedFolderWritable
    }
}
