Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$scriptPath = Join-Path $repoRoot 'Start-Sandbox.ps1'
$manifestOut = Join-Path $repoRoot 'scripts\install-manifest.json'
$wsbOut = Join-Path $repoRoot 'sandbox.wsb'

Describe 'Start-Sandbox dry-run effective selection output' {
    It 'shows final effective tool selection after runtime overrides' {
        try {
            $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -DryRun `
                -SkipPrereqCheck `
                -Profile minimal `
                -AddTools wireshark `
                -RemoveTools notepadpp 2>&1 | Out-String

            $output | Should Match 'Runtime add: wireshark'
            $output | Should Match 'Runtime remove: notepadpp'
            $output | Should Match '\* Wireshark'
            $output | Should Not Match '\* Notepad\+\+'
        } finally {
            if (Test-Path -LiteralPath $manifestOut -PathType Leaf) {
                Remove-Item -LiteralPath $manifestOut -Force
            }
            if (Test-Path -LiteralPath $wsbOut -PathType Leaf) {
                Remove-Item -LiteralPath $wsbOut -Force
            }
        }
    }
}
