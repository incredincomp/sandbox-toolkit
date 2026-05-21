Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [string]$InputPath = 'C:\Users\WDAGUtilityAccount\Desktop\shared\incoming',
    [string]$OutputRoot = 'C:\Users\WDAGUtilityAccount\Desktop\analysis-artifacts\triage',
    [switch]$Recurse
)

function Get-TriageStrings {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MinLength = 6,
        [int]$MaxItems = 200
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $builder = New-Object System.Text.StringBuilder
    $results = New-Object System.Collections.Generic.List[string]

    foreach ($byte in $bytes) {
        if (($byte -ge 32 -and $byte -le 126) -or $byte -eq 9) {
            [void]$builder.Append([char]$byte)
        } else {
            if ($builder.Length -ge $MinLength) {
                $results.Add($builder.ToString())
                if ($results.Count -ge $MaxItems) {
                    break
                }
            }
            [void]$builder.Clear()
        }
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
    $hashMd5 = (Get-FileHash -LiteralPath $item.FullName -Algorithm MD5).Hash
    $strings = Get-TriageStrings -Path $item.FullName

    $sampleRecord = [ordered]@{
        name = $item.Name
        full_path = $item.FullName
        size_bytes = $item.Length
        created_utc = $item.CreationTimeUtc.ToString('o')
        modified_utc = $item.LastWriteTimeUtc.ToString('o')
        hashes = [ordered]@{
            sha256 = $hashSha256
            md5 = $hashMd5
        }
        strings_preview = @($strings)
    }

    $report.samples += [pscustomobject]$sampleRecord
}

$outputPath = Join-Path $OutputRoot 'triage-summary.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outputPath -Encoding UTF8
Write-Output $outputPath
