Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path $repoRoot 'Start-Sandbox.ps1'
$manifestOut = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbOut = Join-Path $repoRoot 'sandbox.wsb'

function Invoke-StartSandboxAuditRaw {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1 | Out-String
    return [pscustomobject]@{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

function Invoke-StartSandboxAuditJson {
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

Describe 'Start-Sandbox audit mode' {
    AfterEach {
        if (Test-Path -LiteralPath $manifestOut -PathType Leaf) {
            Remove-Item -LiteralPath $manifestOut -Force
        }
        if (Test-Path -LiteralPath $wsbOut -PathType Leaf) {
            Remove-Item -LiteralPath $wsbOut -Force
        }
    }

    It 'is non-destructive: no download queue run and no launch stage execution' {
        $result = Invoke-StartSandboxAuditRaw -Arguments @('-Audit', '-SkipPrereqCheck', '-Profile', 'minimal')

        $result.ExitCode | Should Be 0
        $result.Output | Should Match '\[3/5\] Download stage \(audit\)'
        $result.Output | Should Not Match '\[3/5\] Downloading tools'
        $result.Output | Should Match '\[5/5\] Audit'
        $result.Output | Should Not Match '\[5/5\] Launch'
        (Test-Path -LiteralPath $manifestOut -PathType Leaf) | Should Be $true
        (Test-Path -LiteralPath $wsbOut -PathType Leaf) | Should Be $true
    }

    It 'returns parseable audit JSON with explicit trust-boundary wording' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-audit-int-tests-" + [guid]::NewGuid().ToString())
        $sharedPath = Join-Path $tempRoot 'lab\ingress'
        New-Item -ItemType Directory -Path $sharedPath -Force | Out-Null

        try {
            $result = Invoke-StartSandboxAuditJson -Arguments @(
                '-Audit',
                '-SkipPrereqCheck',
                '-OutputJson',
                '-Profile', 'minimal',
                '-SharedFolder', $sharedPath,
                '-SharedFolderWritable'
            )

            $result.ExitCode | Should Be 0
            $result.Json.command.mode | Should Be 'audit'
            $result.Json.overall_status | Should Be 'WARN'
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-shared-folder' -and $_.status -eq 'WARN' }).Count) | Should Be 1
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-networking' })[0].summary) | Should Match 'configured/requested'
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-networking' })[0].summary) | Should Match 'not runtime-verified'
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'rejects incompatible mode combinations for audit mode' {
        $result = Invoke-StartSandboxAuditRaw -Arguments @('-Audit', '-DryRun')

        $result.ExitCode | Should Be 1
        $result.Output | Should Match '-Audit cannot be combined with -DryRun'
    }
}
