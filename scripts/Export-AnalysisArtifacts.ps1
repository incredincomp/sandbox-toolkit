Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [string]$ArtifactRoot = 'C:\Users\WDAGUtilityAccount\Desktop\analysis-artifacts',
    [string]$SharedRoot = 'C:\Users\WDAGUtilityAccount\Desktop\shared',
    [string]$BundleName = ''
)

if ([string]::IsNullOrWhiteSpace($BundleName)) {
    $BundleName = 'analysis-artifacts-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
}

if (-not (Test-Path -LiteralPath $ArtifactRoot -PathType Container)) {
    throw "Artifact directory not found: $ArtifactRoot"
}

$exportDir = Join-Path $SharedRoot 'exports'
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null

$stagingDir = Join-Path $env:TEMP $BundleName
if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

Copy-Item -Path (Join-Path $ArtifactRoot '*') -Destination $stagingDir -Recurse -Force
$installLog = 'C:\Users\WDAGUtilityAccount\Desktop\install-log.txt'
if (Test-Path -LiteralPath $installLog -PathType Leaf) {
    Copy-Item -LiteralPath $installLog -Destination (Join-Path $stagingDir 'install-log.txt') -Force
}

$zipPath = Join-Path $exportDir ($BundleName + '.zip')
if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

Write-Output $zipPath
