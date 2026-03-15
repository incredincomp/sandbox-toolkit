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

Describe 'Test-ManifestIntegrity update metadata checks' {
    It 'fails when github update strategy has no repository reference' {
        $manifest = [pscustomobject]@{
            schema_version = '1.0'
            tools = @(
                [pscustomobject]@{
                    id = 'tool-github'
                    source_type = 'vendor'
                    source_url = 'https://example.com/tool.exe'
                    version = '1.0.0'
                    filename = 'tool.exe'
                    installer_type = 'exe'
                    install_order = 1
                    update = [pscustomobject]@{
                        strategy = 'github_release'
                    }
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
        $message | Should Match "requires update.github_repo or tool.github_repo"
    }

    It 'fails when rss update strategy is missing required fields' {
        $manifest = [pscustomobject]@{
            schema_version = '1.0'
            tools = @(
                [pscustomobject]@{
                    id = 'tool-rss'
                    source_type = 'vendor'
                    source_url = 'https://example.com/tool.zip'
                    version = '1.0.0'
                    filename = 'tool.zip'
                    installer_type = 'zip'
                    install_order = 1
                    update = [pscustomobject]@{
                        strategy = 'rss'
                    }
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
        $message | Should Match "requires 'rss_url'"
        $message | Should Match "requires 'version_regex'"
    }

    It 'fails when static update strategy is missing latest marker' {
        $manifest = [pscustomobject]@{
            schema_version = '1.0'
            tools = @(
                [pscustomobject]@{
                    id = 'tool-static'
                    source_type = 'vendor'
                    source_url = 'https://example.com/tool.msi'
                    version = '1.0.0'
                    filename = 'tool.msi'
                    installer_type = 'msi'
                    install_order = 1
                    update = [pscustomobject]@{
                        strategy = 'static'
                    }
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
        $message | Should Match "requires 'static_latest_version'"
    }
}

Describe 'Custom profile config integrity' {
    $manifest = Import-ToolManifest -ManifestPath (Join-Path $repoRoot 'tools.json')
    $fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    $examplePath = Join-Path $repoRoot 'custom-profiles.example.json'

    It 'loads valid custom profile definitions' {
        $configPath = Join-Path $fixtureDir 'custom-profiles.valid.json'
        $config = Import-CustomProfileConfig -CustomProfilePath $configPath

        { Test-CustomProfileConfigIntegrity -CustomProfileConfig $config -Manifest $manifest } | Should Not Throw
        (Get-CustomProfileEntry -CustomProfileConfig $config).Count | Should Be 1
    }

    It 'fails clearly for malformed custom profile shape' {
        $configPath = Join-Path $fixtureDir 'custom-profiles.invalid-shape.json'
        $message = $null
        try {
            Import-CustomProfileConfig -CustomProfilePath $configPath | Out-Null
        } catch {
            $message = $_.Exception.Message
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "missing required 'profiles' property"
    }

    It 'fails clearly for unknown custom tool references' {
        $configPath = Join-Path $fixtureDir 'custom-profiles.unknown-tool.json'
        $config = Import-CustomProfileConfig -CustomProfilePath $configPath
        $message = $null
        try {
            Test-CustomProfileConfigIntegrity -CustomProfileConfig $config -Manifest $manifest
        } catch {
            $message = $_.Exception.Message
        }

        $message | Should Not BeNullOrEmpty
        $message | Should Match "unknown tool id 'tool-does-not-exist'"
    }

    It 'keeps the repository custom profile example valid against real loader/integrity rules' {
        $config = Import-CustomProfileConfig -CustomProfilePath $examplePath

        { Test-CustomProfileConfigIntegrity -CustomProfileConfig $config -Manifest $manifest } | Should Not Throw
        @($config.profiles).Count | Should BeGreaterThan 0
        @($config.profiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_.base_profile) }).Count | Should BeGreaterThan 0
    }
}
