Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Manifest.ps1')

Describe 'Test-ManifestIntegrity dependency reference checks' {
    It 'fails when a dependency references a missing tool id' {
        $manifest = [pscustomobject]@{
            schema_version = '1.0'
            tools = @(
                [pscustomobject]@{
                    id = 'tool-a'
                    source_type = 'vendor'
                    source_url = 'https://example.com/a.exe'
                    installer_type = 'exe'
                    dependencies = @('missing-tool')
                }
            )
        }

        $message = $null
        try {
            Test-ManifestIntegrity -Manifest $manifest
        } catch {
            $message = $_.Exception.Message
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "dependency 'missing-tool' does not reference an existing tool id"
    }
}
