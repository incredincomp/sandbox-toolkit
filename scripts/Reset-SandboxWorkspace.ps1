<#
.SYNOPSIS
    Removes toolkit-generated analyst workspace artifacts from the sandbox desktop.

.DESCRIPTION
    Deletes analysis artifact folders and common generated files so operators can reset
    the sandbox workspace between samples without recreating the whole environment.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$targets = @(
    'C:\Users\WDAGUtilityAccount\Desktop\analysis-artifacts',
    'C:\Users\WDAGUtilityAccount\Desktop\install-log.txt',
    'C:\Users\WDAGUtilityAccount\Desktop\install-timeline.csv',
    'C:\Users\WDAGUtilityAccount\Desktop\triage-summary.json'
)

$results = [System.Collections.Generic.List[object]]::new()
foreach ($target in $targets) {
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
        $results.Add([pscustomobject]@{ path = $target; removed = $true })
    } else {
        $results.Add([pscustomobject]@{ path = $target; removed = $false })
    }
}

$results | ConvertTo-Json -Depth 4
