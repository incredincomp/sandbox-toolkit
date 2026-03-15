Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Download.ps1')

function Write-StatusLine {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )

    $null = $Message
    $null = $ForegroundColor
}

Describe 'Invoke-ToolDownload manual source handling' {
    It 'skips download cleanly when source_type is manual' {
        Mock Invoke-FileDownload {}
        Mock Resolve-GitHubReleaseAssetUrl {}

        $tool = [pscustomobject]@{
            id = 'manual-tool'
            display_name = 'Manual Tool'
            source_type = 'manual'
            filename = 'manual-tool.exe'
            installer_type = 'manual'
            notes = 'Manual acquisition required.'
        }

        { Invoke-ToolDownload -Tool $tool -SetupDir (Join-Path $repoRoot 'scripts\setups') } | Should Not Throw
        Assert-MockCalled Invoke-FileDownload -Exactly 0 -Scope It
        Assert-MockCalled Resolve-GitHubReleaseAssetUrl -Exactly 0 -Scope It
    }
}
