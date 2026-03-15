Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$fixtureDir = Join-Path $PSScriptRoot 'fixtures'
. (Join-Path $repoRoot 'src\Workflow.ps1')

Describe 'ConvertFrom-SandboxWsbRawSessionList' {
    It 'normalizes supported raw array shape' {
        $raw = Get-Content -Raw -Path (Join-Path $fixtureDir 'wsb-list-raw.array.json')
        $sessions = ConvertFrom-SandboxWsbRawSessionList -RawOutput $raw

        $sessions.Count | Should Be 2
        $sessions[0].Id | Should Be '11111111-1111-1111-1111-111111111111'
        $sessions[0].Status | Should Be 'running'
        $sessions[1].Status | Should Be 'stopped'
    }

    It 'normalizes supported wrapped sessions shape' {
        $raw = Get-Content -Raw -Path (Join-Path $fixtureDir 'wsb-list-raw.sessions.json')
        $sessions = ConvertFrom-SandboxWsbRawSessionList -RawOutput $raw

        $sessions.Count | Should Be 1
        $sessions[0].Id | Should Be 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'
        $sessions[0].Status | Should Be 'running'
    }

    It 'returns deterministic empty list for blank raw output' {
        $sessions = ConvertFrom-SandboxWsbRawSessionList -RawOutput ''
        @($sessions).Count | Should Be 0
    }

    It 'fails deterministically on malformed JSON' {
        $thrown = $null
        try {
            ConvertFrom-SandboxWsbRawSessionList -RawOutput '{not-json' | Out-Null
        } catch {
            $thrown = $_
        }

        $thrown | Should Not BeNullOrEmpty
        $thrown.Exception.Message | Should Match 'could not be parsed as JSON'
    }

    It 'fails deterministically when required session id is missing' {
        $raw = Get-Content -Raw -Path (Join-Path $fixtureDir 'wsb-list-raw.missing-id.json')
        $thrown = $null
        try {
            ConvertFrom-SandboxWsbRawSessionList -RawOutput $raw | Out-Null
        } catch {
            $thrown = $_
        }

        $thrown | Should Not BeNullOrEmpty
        $thrown.Exception.Message | Should Match 'missing required field'
    }

    It 'fails deterministically on unsupported JSON shape' {
        $thrown = $null
        try {
            ConvertFrom-SandboxWsbRawSessionList -RawOutput '{"unexpected":"shape"}' | Out-Null
        } catch {
            $thrown = $_
        }

        $thrown | Should Not BeNullOrEmpty
        $thrown.Exception.Message | Should Match 'unsupported JSON shape'
    }
}

Describe 'Get-SandboxWarmSessionInventory' {
    It 'uses normalized parser helper for wsb list raw output' {
        Mock Invoke-SandboxWsbCliCommand {
            [pscustomobject]@{
                ExitCode = 0
                Output = '[]'
            }
        }
        Mock ConvertFrom-SandboxWsbRawSessionList {
            @([pscustomobject]@{ Id = 'abc'; Status = 'running'; Uptime = '00:00:10' })
        }

        $sessions = Get-SandboxWarmSessionInventory
        Assert-MockCalled ConvertFrom-SandboxWsbRawSessionList -Times 1 -Exactly
        $sessions.Count | Should Be 1
        $sessions[0].Status | Should Be 'running'
    }
}

Describe 'Get-SandboxSessionLifecycleState' {
    It 'keeps fresh as default requested/effective mode' {
        $state = Get-SandboxSessionLifecycleState

        $state.RequestedMode | Should Be 'Fresh'
        $state.EffectiveMode | Should Be 'Fresh'
    }

    It 'captures unsupported warm-session support state deterministically' {
        Mock Test-SandboxWarmSessionSupport {
            [pscustomobject]@{
                Supported = $false
                Reason = 'wsb not found'
                CommandPath = $null
            }
        }

        $state = Get-SandboxSessionLifecycleState -SessionMode 'Warm'
        $state.RequestedMode | Should Be 'Warm'
        $state.WarmSupport.Supported | Should Be $false
        $state.WarmSupport.Reason | Should Match 'wsb not found'
    }

    It 'captures parser/discovery errors deterministically for warm mode' {
        Mock Test-SandboxWarmSessionSupport {
            [pscustomobject]@{
                Supported = $true
                Reason = 'wsb available'
                CommandPath = 'C:\Windows\System32\wsb.exe'
            }
        }
        Mock Get-SandboxWarmSessionInventory {
            throw 'raw output unsupported'
        }

        $state = Get-SandboxSessionLifecycleState -SessionMode 'Warm'
        $state.InventoryError | Should Match 'raw output unsupported'
        $state.RunningSessionCount | Should Be 0
    }
}

Describe 'Invoke-SandboxSessionLaunch' {
    It 'reuses running warm session when discovered' {
        Mock Get-SandboxWarmSessionInventory {
            @([pscustomobject]@{ Id = 'abc'; Status = 'running'; Uptime = '00:01:00' })
        }
        Mock Invoke-SandboxWsbCliCommand {
            [pscustomobject]@{ ExitCode = 0; Output = '' }
        }

        $result = Invoke-SandboxSessionLaunch `
            -WsbPath 'C:\repo\sandbox.wsb' `
            -SessionLifecycleState ([pscustomobject]@{
                EffectiveMode = 'Warm'
                WarmSupport = [pscustomobject]@{ Supported = $true; Reason = 'ok' }
            })

        $result.Launched | Should Be $true
        $result.Reason | Should Be 'WarmReusedSession'
        $result.WarmAction | Should Be 'reused'
        $result.WarmSessionId | Should Be 'abc'
    }

    It 'creates warm session when none are running' {
        Mock Get-SandboxWarmSessionInventory { @() }
        Mock Get-Content { '<Configuration><Networking>Disable</Networking></Configuration>' }
        Mock Invoke-SandboxWsbCliCommand {
            [pscustomobject]@{ ExitCode = 0; Output = '' }
        }

        $result = Invoke-SandboxSessionLaunch `
            -WsbPath 'C:\repo\sandbox.wsb' `
            -SessionLifecycleState ([pscustomobject]@{
                EffectiveMode = 'Warm'
                WarmSupport = [pscustomobject]@{ Supported = $true; Reason = 'ok' }
            })

        $result.Launched | Should Be $true
        $result.Reason | Should Be 'WarmCreatedSession'
        $result.WarmAction | Should Be 'created'
    }

    It 'throws when warm mode is requested but unsupported' {
        $thrown = $null
        try {
            Invoke-SandboxSessionLaunch `
                -WsbPath 'C:\repo\sandbox.wsb' `
                -SessionLifecycleState ([pscustomobject]@{
                    EffectiveMode = 'Warm'
                    WarmSupport = [pscustomobject]@{ Supported = $false; Reason = 'no cli' }
                })
        } catch {
            $thrown = $_
        }

        $thrown | Should Not BeNullOrEmpty
        $thrown.Exception.Message | Should Match 'unsupported'
    }
}

Describe 'Get-SandboxWslHelperState' {
    It 'returns disabled state when helper is not requested' {
        $state = Get-SandboxWslHelperState
        $state.Enabled | Should Be $false
        $state.SupportReason | Should Match 'not requested'
    }

    It 'returns unavailable state when requested distro does not exist' {
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\Windows\System32\wsl.exe' } } -ParameterFilter { $Name -eq 'wsl.exe' }
        Mock Get-SandboxWslDistroCatalog { @('Ubuntu', 'Debian') }

        $state = Get-SandboxWslHelperState -UseWslHelper -WslDistro 'MissingDistro'
        $state.Enabled | Should Be $true
        $state.DistroAvailable | Should Be $false
        $state.SupportReason | Should Match 'not found'
    }
}
