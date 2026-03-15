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

function Assert-AuditJsonContractShape {
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
    $Json.context.runtime_verification | Should Be 'not_performed'
    $Json.checks | Should Not BeNullOrEmpty
    $checkFields = @($Json.checks[0].psobject.Properties.Name)
    (($checkFields -contains 'id')) | Should Be $true
    (($checkFields -contains 'status')) | Should Be $true
    (($checkFields -contains 'summary')) | Should Be $true
    (($checkFields -contains 'remediation')) | Should Be $true
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
            $result.Output.TrimStart() | Should Match '^\{'
            Assert-AuditJsonContractShape -Json $result.Json
            $result.Json.overall_status | Should Be 'WARN'
            $result.Json.exit_code | Should Be $result.ExitCode
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-shared-folder' -and $_.status -eq 'WARN' }).Count) | Should Be 1
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-networking' })[0].summary) | Should Match 'configured/requested'
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-networking' })[0].summary) | Should Match 'not runtime-verified'
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-clipboard-redirection' -and $_.status -eq 'PASS' }).Count) | Should Be 1
            (($result.Json.checks | Where-Object { $_.id -eq 'wsb-audio-input' -and $_.status -eq 'PASS' }).Count) | Should Be 1
            $result.Json.effective.host_interaction_requested.clipboard_redirection | Should Be 'Enable'
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'reflects startup-command suppression request in audit checks and JSON' {
        $result = Invoke-StartSandboxAuditJson -Arguments @(
            '-Audit',
            '-SkipPrereqCheck',
            '-OutputJson',
            '-Profile', 'minimal',
            '-DisableStartupCommands',
            '-DisableClipboard'
        )

        $result.ExitCode | Should Be 0
        (($result.Json.checks | Where-Object { $_.id -eq 'wsb-logon-command' -and $_.status -eq 'PASS' }).Count) | Should Be 1
        (($result.Json.checks | Where-Object { $_.id -eq 'wsb-logon-command' })[0].summary) | Should Match 'omitted'
        $result.Json.effective.host_interaction_requested.startup_commands_enabled | Should Be $false
        $result.Json.effective.host_interaction_requested.clipboard_redirection | Should Be 'Disable'
    }

    It 'rejects incompatible mode combinations for audit mode' {
        $result = Invoke-StartSandboxAuditRaw -Arguments @('-Audit', '-DryRun')

        $result.ExitCode | Should Be 1
        $result.Output | Should Match '-Audit cannot be combined with -DryRun'
    }
}
