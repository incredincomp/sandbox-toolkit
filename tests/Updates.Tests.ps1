Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Updates.ps1')

Describe 'Compare-SandboxVersion' {
    It 'treats configured latest as up-to-date by policy' {
        Compare-SandboxVersion -ConfiguredVersion 'latest' -LatestVersion '2.3.4' | Should Be 0
    }

    It 'compares semantic-like versions with v-prefix support' {
        Compare-SandboxVersion -ConfiguredVersion 'v1.2.3' -LatestVersion '1.3.0' | Should Be -1
        Compare-SandboxVersion -ConfiguredVersion '1.3.0' -LatestVersion 'v1.3.0' | Should Be 0
        Compare-SandboxVersion -ConfiguredVersion '1.4.0' -LatestVersion '1.3.9' | Should Be 1
    }
}

Describe 'Invoke-SandboxToolUpdateCheck adapters' {
    It 'checks github releases with mocked API response' {
        Mock Invoke-RestMethod -ParameterFilter { $Uri -like 'https://api.github.com/repos/*/releases/latest' } {
            return [pscustomobject]@{
                tag_name = 'v2.0.0'
                assets = @(
                    [pscustomobject]@{ name = 'tool-v2.0.0-x64.zip' }
                )
            }
        }

        $tool = [pscustomobject]@{
            id = 'github-tool'
            display_name = 'GitHub Tool'
            version = '1.9.0'
            github_repo = 'owner/repo'
            asset_pattern = '*x64.zip'
            update = [pscustomobject]@{
                strategy = 'github_release'
                source_confidence = 'high'
            }
        }

        $result = Invoke-SandboxToolUpdateCheck -Tool $tool

        $result.status | Should Be 'outdated'
        $result.latest_version | Should Be 'v2.0.0'
        $result.source_type | Should Be 'github_release'
        Assert-MockCalled Invoke-RestMethod -Exactly 1 -Scope It
    }

    It 'resolves rss feed versions with mocked feed response' {
        Mock Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://example.invalid/feed.xml' } {
            return [xml]@'
<rss version="2.0">
  <channel>
    <item>
      <title>Release v3.4.5 available</title>
      <link>https://example.invalid/releases/v3.4.5</link>
    </item>
  </channel>
</rss>
'@
        }

        $resolved = Resolve-SandboxRssLatestVersion -FeedUrl 'https://example.invalid/feed.xml' -VersionRegex 'v(\d+\.\d+\.\d+)'

        $resolved.LatestVersion | Should Be '3.4.5'
        $resolved.SourceType | Should Be 'rss'
        Assert-MockCalled Invoke-RestMethod -Exactly 1 -Scope It
    }

    It 'supports static version markers without network calls' {
        Mock Invoke-RestMethod -ParameterFilter { $true } { throw 'network should not be called' }

        $tool = [pscustomobject]@{
            id = 'static-tool'
            display_name = 'Static Tool'
            version = '1.2.3'
            update = [pscustomobject]@{
                strategy = 'static'
                static_latest_version = '1.2.3'
            }
        }

        $result = Invoke-SandboxToolUpdateCheck -Tool $tool

        $result.status | Should Be 'up-to-date'
        $result.latest_version | Should Be '1.2.3'
        Assert-MockCalled Invoke-RestMethod -Exactly 0 -Scope It
    }

    It 'returns unsupported-for-checking when no metadata exists' {
        $tool = [pscustomobject]@{
            id = 'no-update'
            display_name = 'No Update Tool'
            version = '1.0.0'
        }

        $result = Invoke-SandboxToolUpdateCheck -Tool $tool
        $result.status | Should Be 'unsupported-for-checking'
    }

    It 'returns unknown when source lookup fails' {
        Mock Invoke-RestMethod -ParameterFilter { $Uri -like 'https://api.github.com/repos/*/releases/latest' } { throw 'rate limited' }

        $tool = [pscustomobject]@{
            id = 'github-fail'
            display_name = 'GitHub Fail'
            version = '1.0.0'
            github_repo = 'owner/repo'
            asset_pattern = '*.zip'
            update = [pscustomobject]@{
                strategy = 'github_release'
            }
        }

        $result = Invoke-SandboxToolUpdateCheck -Tool $tool
        $result.status | Should Be 'unknown'
        $result.message | Should Match 'Could not determine latest version'
    }
}
