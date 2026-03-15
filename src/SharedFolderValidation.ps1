function Get-NormalizedFullPath {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $fullPath = [System.IO.Path]::GetFullPath($resolved.Path)
    $rootPath = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath -ieq $rootPath) {
        return $rootPath
    }
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
            Category  = 'drive root'
            Rationale = 'mapping a full drive is overly broad'
            Kind      = 'drive-root'
            Path      = $null
        }
        [pscustomobject]@{
            Category  = 'repository root'
            Rationale = 'mapping the entire repository can expose unrelated files'
            Kind      = 'exact-path'
            Path      = $normalizedRepoRoot
        }
        [pscustomobject]@{
            Category  = 'Windows directory'
            Rationale = 'system directories are sensitive and overly broad'
            Kind      = 'exact-path'
            Path      = $env:windir
        }
        [pscustomobject]@{
            Category  = 'Program Files'
            Rationale = 'program install roots are broad and contain host binaries'
            Kind      = 'exact-path'
            Path      = $env:ProgramFiles
        }
        [pscustomobject]@{
            Category  = 'Program Files (x86)'
            Rationale = 'program install roots are broad and contain host binaries'
            Kind      = 'exact-path'
            Path      = ${env:ProgramFiles(x86)}
        }
        [pscustomobject]@{
            Category  = 'ProgramW6432'
            Rationale = 'program install roots are broad and contain host binaries'
            Kind      = 'exact-path'
            Path      = $env:ProgramW6432
        }
        [pscustomobject]@{
            Category  = 'user profile root'
            Rationale = 'profile root contains broad personal and application data'
            Kind      = 'exact-path'
            Path      = $env:USERPROFILE
        }
        [pscustomobject]@{
            Category  = 'Desktop root'
            Rationale = 'Desktop often contains user documents and active files'
            Kind      = 'exact-path'
            Path      = $desktopPath
        }
        [pscustomobject]@{
            Category  = 'Documents root'
            Rationale = 'Documents is a common location for sensitive personal files'
            Kind      = 'exact-path'
            Path      = $documentsPath
        }
        [pscustomobject]@{
            Category  = 'Downloads root'
            Rationale = 'Downloads is a broad ingress area for arbitrary host files'
            Kind      = 'exact-path'
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
        if ($entry.Kind -ne 'exact-path') {
            $resolvedPolicy += $entry
            continue
        }

        if (-not $entry.Path) {
            continue
        }

        try {
            $resolvedPolicy += [pscustomobject]@{
                Category  = $entry.Category
                Rationale = $entry.Rationale
                Kind      = $entry.Kind
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

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    return [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Get-NormalizedInputPath {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPath = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath -ieq $rootPath) {
        return $rootPath
    }
    return $fullPath.TrimEnd('\')
}

function Find-ReparsePointInPathAncestry {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$IncludeTarget
    )

    $currentPath = if ($IncludeTarget) { $Path } else { Split-Path -Path $Path -Parent }
    if ($currentPath) {
        $currentRoot = [System.IO.Path]::GetPathRoot($currentPath)
        if ($currentPath -ine $currentRoot) {
            $currentPath = $currentPath.TrimEnd('\')
        }
    }

    while ($currentPath) {
        try {
            $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction Stop
        } catch {
            throw "Shared folder path could not be validated safely: failed to inspect ancestry segment '$currentPath'. $($_.Exception.Message)"
        }

        if ($item.PSIsContainer -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            return $currentPath
        }

        $pathRoot = [System.IO.Path]::GetPathRoot($currentPath).TrimEnd('\')
        if ($currentPath.TrimEnd('\') -ieq $pathRoot) {
            break
        }

        $parentPath = Split-Path -Path $currentPath -Parent
        if ([string]::IsNullOrWhiteSpace($parentPath)) {
            break
        }
        $parentRoot = [System.IO.Path]::GetPathRoot($parentPath)
        if ($parentPath -ieq $parentRoot) {
            $currentPath = $parentRoot
            continue
        }
        $currentPath = $parentPath.TrimEnd('\')
    }

    return $null
}

function Assert-SafeSharedFolderPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Shared folder path must exist and be a directory: $Path"
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Shared folder path must exist and be a directory: $Path"
    }

    $normalizedInputPath = Get-NormalizedInputPath -Path $Path
    $normalizedPath = Get-NormalizedFullPath -Path $Path

    if (Test-SharedFolderTargetIsReparsePoint -Path $normalizedPath) {
        throw "Shared folder path is not allowed: '$normalizedPath' is a reparse point or junction. Use a real directory path."
    }

    $reparseAncestorPath = Find-ReparsePointInPathAncestry -Path $normalizedInputPath
    if ($reparseAncestorPath) {
        throw "Shared folder path is not allowed: '$normalizedInputPath' traverses a reparse point or junction at '$reparseAncestorPath' in its parent chain. The toolkit blocks reparse/junction ancestry traversal for safety. Choose a non-reparse local folder instead."
    }

    foreach ($entry in Get-ResolvedSharedFolderBlockedPathPolicy -RepoRoot $RepoRoot) {
        if ($entry.Kind -eq 'drive-root') {
            $pathRoot = [System.IO.Path]::GetPathRoot($normalizedPath).TrimEnd('\')
            if ($normalizedPath.TrimEnd('\') -ieq $pathRoot) {
                throw "Shared folder path is not allowed: '$normalizedPath' matches blocked category '$($entry.Category)' because $($entry.Rationale)."
            }
            continue
        }

        if ($normalizedPath -ieq $entry.Path) {
            throw "Shared folder path is not allowed: '$normalizedPath' matches blocked category '$($entry.Category)' because $($entry.Rationale). Use a dedicated analysis ingress folder."
        }
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
