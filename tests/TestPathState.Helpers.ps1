Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-TestPathSnapshot {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not $PSCmdlet.ShouldProcess($Path, 'Create path snapshot')) {
        return $null
    }

    $backupRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-path-snapshot-" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $exists = Test-Path -LiteralPath $Path
    $backupPath = $null
    $isContainer = $false

    if ($exists) {
        $item = Get-Item -LiteralPath $Path -Force
        $isContainer = [bool]$item.PSIsContainer
        $backupPath = Join-Path $backupRoot $item.Name
        if ($isContainer) {
            Copy-Item -LiteralPath $Path -Destination $backupPath -Recurse -Force
        } else {
            Copy-Item -LiteralPath $Path -Destination $backupPath -Force
        }
    }

    return [pscustomobject]@{
        Path = $Path
        Exists = [bool]$exists
        IsContainer = $isContainer
        BackupRoot = $backupRoot
        BackupPath = $backupPath
    }
}

function Reset-TestPath {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Remove test path state')) {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    } else {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Restore-TestPathSnapshot {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Snapshot
    )

    if (-not $PSCmdlet.ShouldProcess($Snapshot.Path, 'Restore path snapshot')) {
        return
    }

    Reset-TestPath -Path $Snapshot.Path

    if ($Snapshot.Exists -and $Snapshot.BackupPath) {
        $parentPath = Split-Path -Parent $Snapshot.Path
        if (-not (Test-Path -LiteralPath $parentPath)) {
            New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
        }

        if ($Snapshot.IsContainer) {
            Copy-Item -LiteralPath $Snapshot.BackupPath -Destination $parentPath -Recurse -Force
        } else {
            Copy-Item -LiteralPath $Snapshot.BackupPath -Destination $Snapshot.Path -Force
        }
    }

    if (Test-Path -LiteralPath $Snapshot.BackupRoot) {
        Remove-Item -LiteralPath $Snapshot.BackupRoot -Recurse -Force
    }
}
