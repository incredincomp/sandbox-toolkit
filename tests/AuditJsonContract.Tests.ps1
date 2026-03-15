Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path $repoRoot 'Start-Sandbox.ps1'
$readmePath = Join-Path $repoRoot 'README.md'
$manifestOut = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbOut = Join-Path $repoRoot 'sandbox.wsb'

function Invoke-AuditJson {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1 | Out-String
    return [pscustomobject]@{
        Output = $output
        ExitCode = $LASTEXITCODE
        Json = ($output | ConvertFrom-Json)
    }
}

function Assert-AuditContractShape {
    param(
        [Parameter(Mandatory)][object]$Json
    )

    $topLevel = @($Json.psobject.Properties.Name)
    (($topLevel -contains 'command')) | Should Be $true
    (($topLevel -contains 'overall_status')) | Should Be $true
    (($topLevel -contains 'exit_code')) | Should Be $true
    (($topLevel -contains 'profile')) | Should Be $true
    (($topLevel -contains 'overrides')) | Should Be $true
    (($topLevel -contains 'effective')) | Should Be $true
    (($topLevel -contains 'artifacts')) | Should Be $true
    (($topLevel -contains 'checks')) | Should Be $true
    (($topLevel -contains 'context')) | Should Be $true

    $Json.command.mode | Should Be 'audit'
    ((@('PASS', 'WARN', 'FAIL') -contains $Json.overall_status)) | Should Be $true
    $checkFields = @($Json.checks[0].psobject.Properties.Name)
    (($checkFields -contains 'id')) | Should Be $true
    (($checkFields -contains 'status')) | Should Be $true
    (($checkFields -contains 'summary')) | Should Be $true
    (($checkFields -contains 'remediation')) | Should Be $true
    $Json.context.runtime_verification | Should Be 'not_performed'
}

Describe 'Audit JSON contract' {
    AfterEach {
        if (Test-Path -LiteralPath $manifestOut -PathType Leaf) {
            Remove-Item -LiteralPath $manifestOut -Force
        }
        if (Test-Path -LiteralPath $wsbOut -PathType Leaf) {
            Remove-Item -LiteralPath $wsbOut -Force
        }
    }

    It 'keeps required stable shape for -Audit -OutputJson results' {
        $result = Invoke-AuditJson -Arguments @('-Audit', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')

        $result.ExitCode | Should Be 0
        $result.Json.exit_code | Should Be $result.ExitCode
        Assert-AuditContractShape -Json $result.Json
    }

    It 'keeps trust-boundary semantics explicit in contract data' {
        $result = Invoke-AuditJson -Arguments @('-Audit', '-SkipPrereqCheck', '-OutputJson', '-Profile', 'minimal')
        $networkCheck = @($result.Json.checks | Where-Object { $_.id -eq 'wsb-networking' })[0]

        $networkCheck.summary | Should Match 'configured/requested'
        $networkCheck.summary | Should Match 'not runtime-verified'
        $result.Json.context.runtime_verification | Should Be 'not_performed'
    }

    It 'keeps README audit JSON example parseable and structurally aligned with contract keys' {
        $readme = Get-Content -Raw -Path $readmePath
        $match = [regex]::Match($readme, '(?s)<!-- audit-json-example:start -->\s*```json\s*(\{.*?\})\s*```\s*<!-- audit-json-example:end -->')

        $match.Success | Should Be $true
        $exampleJson = ($match.Groups[1].Value | ConvertFrom-Json)
        Assert-AuditContractShape -Json $exampleJson
    }
}
