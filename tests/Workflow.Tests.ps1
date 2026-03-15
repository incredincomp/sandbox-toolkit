Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Workflow.ps1')

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
