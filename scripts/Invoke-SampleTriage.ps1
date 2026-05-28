<#
.SYNOPSIS
    Builds quick triage metadata for one sample or a folder of staged samples.

.DESCRIPTION
    Computes SHA256 hashes, basic file metadata, and a bounded printable-string preview
    for each input sample, then writes a deterministic JSON summary artifact.
#>
param(
    [string]$InputPath = 'C:\Users\WDAGUtilityAccount\Desktop\shared\incoming',
    [string]$OutputRoot = 'C:\Users\WDAGUtilityAccount\Desktop\analysis-artifacts\triage',
    [switch]$Recurse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TriageStringPreview {
    <#
    .SYNOPSIS
        Extracts bounded printable-string preview data from a sample file.

    .DESCRIPTION
        Scans raw bytes and emits ASCII-like strings for fast operator triage.
        This is metadata-only output and is intentionally capped for speed/safety.
        Reads at most MaxBytes bytes to avoid OOM on large samples.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MinLength = 6,
        [int]$MaxItems = 200,
        [int]$MaxBytes = 5MB
    )

    $builder = New-Object System.Text.StringBuilder
    $results = New-Object System.Collections.Generic.List[string]
    $buffer = New-Object byte[] 65536
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $totalRead = 0
        $done = $false
        while (-not $done) {
            $toRead = [Math]::Min($buffer.Length, $MaxBytes - $totalRead)
            if ($toRead -le 0) { break }
            $read = $stream.Read($buffer, 0, $toRead)
            if ($read -eq 0) { break }
            $totalRead += $read
            for ($i = 0; $i -lt $read; $i++) {
                $byte = $buffer[$i]
                if (($byte -ge 32 -and $byte -le 126) -or $byte -eq 9) {
                    [void]$builder.Append([char]$byte)
                } else {
                    if ($builder.Length -ge $MinLength) {
                        $results.Add($builder.ToString())
                        if ($results.Count -ge $MaxItems) {
                            $done = $true
                            break
                        }
                    }
                    [void]$builder.Clear()
                }
            }
        }
    } finally {
        $stream.Dispose()
    }

    if ($results.Count -lt $MaxItems -and $builder.Length -ge $MinLength) {
        $results.Add($builder.ToString())
    }

    return @($results)
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input path not found: $InputPath"
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

$items = @()
if (Test-Path -LiteralPath $InputPath -PathType Container) {
    if ($Recurse) {
        $items = @(Get-ChildItem -LiteralPath $InputPath -File -Recurse)
    } else {
        $items = @(Get-ChildItem -LiteralPath $InputPath -File)
    }
} else {
    $items = @((Get-Item -LiteralPath $InputPath))
}

$report = [ordered]@{
    generated_at = (Get-Date -Format 'o')
    input_path = $InputPath
    sample_count = $items.Count
    samples = @()
}

foreach ($item in $items) {
    $hashSha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    $strings = Get-TriageStringPreview -Path $item.FullName

    $sampleRecord = [ordered]@{
        name = $item.Name
        full_path = $item.FullName
        size_bytes = $item.Length
        created_utc = $item.CreationTimeUtc.ToString('o')
        modified_utc = $item.LastWriteTimeUtc.ToString('o')
        hashes = [ordered]@{
            sha256 = $hashSha256
        }
        strings_preview = @($strings)
    }

    $report.samples += [pscustomobject]$sampleRecord
}

$outputPath = Join-Path $OutputRoot 'triage-summary.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outputPath -Encoding UTF8
Write-Output $outputPath
