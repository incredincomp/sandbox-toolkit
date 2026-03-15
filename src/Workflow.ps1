# src/Workflow.ps1
# Session lifecycle and optional WSL helper sidecar state/execution helpers.

function Invoke-SandboxWsbCliCommand {
    <#
    .SYNOPSIS
        Executes a Windows Sandbox CLI command and returns combined output.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$IgnoreExitCode
    )

    $output = & wsb @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "wsb $($Arguments -join ' ') failed with exit code ${exitCode}: $output"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output.Trim()
    }
}

function Invoke-SandboxWslCommand {
    <#
    .SYNOPSIS
        Executes a WSL command and returns combined output.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$IgnoreExitCode
    )

    $output = & wsl.exe @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "wsl.exe $($Arguments -join ' ') failed with exit code ${exitCode}: $output"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output.Trim()
    }
}

function Test-SandboxWarmSessionSupport {
    <#
    .SYNOPSIS
        Detects whether Windows Sandbox CLI warm-session controls are available.
    #>
    $wsbCommand = Get-Command -Name 'wsb' -ErrorAction SilentlyContinue
    if (-not $wsbCommand) {
        return [pscustomobject]@{
            Supported = $false
            Reason    = "Windows Sandbox CLI command 'wsb' was not found on this host."
            CommandPath = $null
        }
    }

    return [pscustomobject]@{
        Supported = $true
        Reason    = "Windows Sandbox CLI command 'wsb' is available."
        CommandPath = $wsbCommand.Source
    }
}

function Get-SandboxWarmSessionInventory {
    <#
    .SYNOPSIS
        Returns current Windows Sandbox session inventory from CLI.
    #>
    $result = Invoke-SandboxWsbCliCommand -Arguments @('list', '--raw')
    if ([string]::IsNullOrWhiteSpace($result.Output)) {
        return @()
    }

    $parsed = $result.Output | ConvertFrom-Json
    $sessionCandidates = @()

    if ($parsed -is [System.Array]) {
        $sessionCandidates = @($parsed)
    } elseif ($parsed.PSObject.Properties['sessions']) {
        $sessionCandidates = @($parsed.sessions)
    } elseif ($parsed.PSObject.Properties['items']) {
        $sessionCandidates = @($parsed.items)
    } elseif ($parsed.PSObject.Properties['id'] -or $parsed.PSObject.Properties['ID']) {
        $sessionCandidates = @($parsed)
    }

    return @(
        $sessionCandidates | ForEach-Object {
            [pscustomobject]@{
                Id = if ($_.id) { [string]$_.id } else { [string]$_.ID }
                Status = if ($_.status) { [string]$_.status } else { [string]$_.State }
                Uptime = if ($_.uptime) { [string]$_.uptime } else { [string]$_.Uptime }
            }
        }
    )
}

function Get-SandboxSessionLifecycleState {
    <#
    .SYNOPSIS
        Builds centralized session lifecycle state for fresh/warm mode handling.
    #>
    param(
        [ValidateSet('Fresh', 'Warm')][string]$SessionMode = 'Fresh'
    )

    $warmSupport = Test-SandboxWarmSessionSupport
    $inventory = @()
    $inventoryError = $null

    if ($SessionMode -eq 'Warm' -and $warmSupport.Supported) {
        try {
            $inventory = @(Get-SandboxWarmSessionInventory)
        } catch {
            $inventoryError = $_.Exception.Message
        }
    }

    $runningSessions = @($inventory | Where-Object { $_.Status -match 'running' })

    return [pscustomobject]@{
        RequestedMode = $SessionMode
        EffectiveMode = $SessionMode
        WarmSupport = $warmSupport
        SessionInventory = @($inventory)
        RunningSessionCount = $runningSessions.Count
        InventoryError = $inventoryError
    }
}

function Invoke-SandboxSessionLaunch {
    <#
    .SYNOPSIS
        Launches sandbox according to requested session lifecycle mode.
    #>
    param(
        [Parameter(Mandatory)][string]$WsbPath,
        [Parameter(Mandatory)][PSCustomObject]$SessionLifecycleState,
        [switch]$NoLaunch,
        [switch]$DryRun,
        [ScriptBlock]$FreshLauncher
    )

    if (-not $FreshLauncher) {
        $FreshLauncher = {
            param($Path)
            Start-Process -FilePath $Path
        }
    }

    if ($DryRun) {
        return [pscustomobject]@{
            Launched = $false
            Reason = 'DryRun'
            SessionMode = $SessionLifecycleState.EffectiveMode
            WarmAction = 'none'
            WarmSessionId = $null
        }
    }

    if ($NoLaunch) {
        return [pscustomobject]@{
            Launched = $false
            Reason = 'NoLaunch'
            SessionMode = $SessionLifecycleState.EffectiveMode
            WarmAction = 'none'
            WarmSessionId = $null
        }
    }

    if ($SessionLifecycleState.EffectiveMode -eq 'Fresh') {
        & $FreshLauncher $WsbPath
        return [pscustomobject]@{
            Launched = $true
            Reason = 'FreshLaunch'
            SessionMode = 'Fresh'
            WarmAction = 'none'
            WarmSessionId = $null
        }
    }

    if (-not $SessionLifecycleState.WarmSupport.Supported) {
        throw "Warm session mode was requested but is unsupported on this host. $($SessionLifecycleState.WarmSupport.Reason)"
    }

    $sessions = @(Get-SandboxWarmSessionInventory)
    $runningSession = $sessions | Where-Object { $_.Status -match 'running' } | Select-Object -First 1
    if ($runningSession) {
        Invoke-SandboxWsbCliCommand -Arguments @('connect', '--id', $runningSession.Id) | Out-Null
        return [pscustomobject]@{
            Launched = $true
            Reason = 'WarmReusedSession'
            SessionMode = 'Warm'
            WarmAction = 'reused'
            WarmSessionId = $runningSession.Id
        }
    }

    $wsbConfigContent = (Get-Content -Raw -Path $WsbPath).Trim()
    Invoke-SandboxWsbCliCommand -Arguments @('start', '--config', $wsbConfigContent) | Out-Null
    return [pscustomobject]@{
        Launched = $true
        Reason = 'WarmCreatedSession'
        SessionMode = 'Warm'
        WarmAction = 'created'
        WarmSessionId = $null
    }
}

function Get-SandboxWslDistroCatalog {
    <#
    .SYNOPSIS
        Returns installed WSL distro names.
    #>
    try {
        $result = Invoke-SandboxWslCommand -Arguments @('-l', '-q')
        return @(
            $result.Output -split "(`r`n|`n|`r)" |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    } catch {
        return @()
    }
}

function ConvertFrom-SandboxIniContent {
    <#
    .SYNOPSIS
        Parses simple ini-style key/value content into nested hashtables.
    #>
    param(
        [Parameter(Mandatory)][string]$Content
    )

    $result = @{}
    $currentSection = ''
    foreach ($line in ($Content -split "(`r`n|`n|`r)")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }

        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $matches[1].Trim().ToLowerInvariant()
            if (-not $result.ContainsKey($currentSection)) {
                $result[$currentSection] = @{}
            }
            continue
        }

        if ($trimmed -match '^([^=]+)=(.*)$') {
            if ([string]::IsNullOrWhiteSpace($currentSection)) {
                continue
            }

            $key = $matches[1].Trim().ToLowerInvariant()
            $value = $matches[2].Trim()
            $result[$currentSection][$key] = $value
        }
    }

    return $result
}

function Get-SandboxWslHardeningState {
    <#
    .SYNOPSIS
        Reads and evaluates /etc/wsl.conf hardening hints in a helper distro.
    #>
    param(
        [string]$WslDistro
    )

    $arguments = @()
    if ($WslDistro) {
        $arguments += @('-d', $WslDistro)
    }
    $arguments += @('--', 'cat', '/etc/wsl.conf')

    try {
        $result = Invoke-SandboxWslCommand -Arguments $arguments
    } catch {
        return [pscustomobject]@{
            Available = $false
            Source = '/etc/wsl.conf'
            Error = $_.Exception.Message
            AutomountEnabled = $null
            InteropEnabled = $null
            AppendWindowsPath = $null
        }
    }

    $ini = ConvertFrom-SandboxIniContent -Content $result.Output
    $automountEnabled = $null
    $interopEnabled = $null
    $appendWindowsPath = $null

    if ($ini.ContainsKey('automount') -and $ini['automount'].ContainsKey('enabled')) {
        $automountEnabled = $ini['automount']['enabled']
    }
    if ($ini.ContainsKey('interop') -and $ini['interop'].ContainsKey('enabled')) {
        $interopEnabled = $ini['interop']['enabled']
    }
    if ($ini.ContainsKey('interop') -and $ini['interop'].ContainsKey('appendwindowspath')) {
        $appendWindowsPath = $ini['interop']['appendwindowspath']
    }

    return [pscustomobject]@{
        Available = $true
        Source = '/etc/wsl.conf'
        Error = $null
        AutomountEnabled = $automountEnabled
        InteropEnabled = $interopEnabled
        AppendWindowsPath = $appendWindowsPath
    }
}

function Get-SandboxWslHelperState {
    <#
    .SYNOPSIS
        Builds centralized optional WSL helper state.
    #>
    param(
        [switch]$UseWslHelper,
        [string]$WslDistro,
        [string]$WslHelperStagePath = '~/.sandbox-toolkit-helper'
    )

    if (-not $UseWslHelper) {
        return [pscustomobject]@{
            Enabled = $false
            RequestedDistro = $WslDistro
            EffectiveDistro = $null
            StagePath = $WslHelperStagePath
            WslCommandAvailable = $false
            Distros = @()
            DistroAvailable = $false
            SupportReason = 'WSL helper sidecar not requested.'
            Hardening = $null
        }
    }

    $wslCommand = Get-Command -Name 'wsl.exe' -ErrorAction SilentlyContinue
    if (-not $wslCommand) {
        return [pscustomobject]@{
            Enabled = $true
            RequestedDistro = $WslDistro
            EffectiveDistro = $null
            StagePath = $WslHelperStagePath
            WslCommandAvailable = $false
            Distros = @()
            DistroAvailable = $false
            SupportReason = "WSL command 'wsl.exe' was not found."
            Hardening = $null
        }
    }

    $distros = @(Get-SandboxWslDistroCatalog)
    if ($distros.Count -eq 0) {
        return [pscustomobject]@{
            Enabled = $true
            RequestedDistro = $WslDistro
            EffectiveDistro = $null
            StagePath = $WslHelperStagePath
            WslCommandAvailable = $true
            Distros = @()
            DistroAvailable = $false
            SupportReason = 'No installed WSL distributions were found.'
            Hardening = $null
        }
    }

    $effectiveDistro = $WslDistro
    if ([string]::IsNullOrWhiteSpace($effectiveDistro)) {
        $effectiveDistro = $null
    }

    if ($effectiveDistro -and ($effectiveDistro -notin $distros)) {
        return [pscustomobject]@{
            Enabled = $true
            RequestedDistro = $WslDistro
            EffectiveDistro = $effectiveDistro
            StagePath = $WslHelperStagePath
            WslCommandAvailable = $true
            Distros = @($distros)
            DistroAvailable = $false
            SupportReason = "Requested WSL distro '$effectiveDistro' was not found."
            Hardening = $null
        }
    }

    $hardening = Get-SandboxWslHardeningState -WslDistro $effectiveDistro

    return [pscustomobject]@{
        Enabled = $true
        RequestedDistro = $WslDistro
        EffectiveDistro = $effectiveDistro
        StagePath = $WslHelperStagePath
        WslCommandAvailable = $true
        Distros = @($distros)
        DistroAvailable = $true
        SupportReason = 'WSL helper sidecar prerequisites are available.'
        Hardening = $hardening
    }
}

function Get-SandboxWslHelperPayloadHash {
    param(
        [Parameter(Mandatory)][string]$Payload
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Payload)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($bytes)
    } finally {
        $sha256.Dispose()
    }

    return ([System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant())
}

function Invoke-SandboxWslHelperSidecar {
    <#
    .SYNOPSIS
        Runs bounded helper-side staging + metadata tasks inside WSL.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$WslHelperState,
        [Parameter(Mandatory)][PSCustomObject]$Selection,
        [Parameter(Mandatory)][string]$NetworkingMode,
        [Parameter(Mandatory)][PSCustomObject]$SessionLifecycleState
    )

    if (-not $WslHelperState.Enabled) {
        return [pscustomobject]@{
            Executed = $false
            Reason = 'NotRequested'
            StagePath = $WslHelperState.StagePath
            PayloadHash = $null
            Distro = $WslHelperState.EffectiveDistro
        }
    }

    if (-not $WslHelperState.WslCommandAvailable -or -not $WslHelperState.DistroAvailable) {
        throw "WSL helper sidecar is unavailable: $($WslHelperState.SupportReason)"
    }

    $payloadObject = [ordered]@{
        generated_at = (Get-Date -Format 'o')
        profile = $Selection.Profile
        base_profile = $Selection.BaseProfile
        profile_type = $Selection.ProfileType
        networking = $NetworkingMode
        session_mode = $SessionLifecycleState.EffectiveMode
        tools = @($Selection.Tools | ForEach-Object { $_.id })
    }
    $payloadJson = $payloadObject | ConvertTo-Json -Depth 10 -Compress
    $payloadHash = Get-SandboxWslHelperPayloadHash -Payload $payloadJson
    $escapedPayload = $payloadJson.Replace("'", "'""'""'")
    $escapedStagePath = $WslHelperState.StagePath.Replace("'", "'""'""'")

    $shellScript = @(
        'set -eu',
        "stage_path='$escapedStagePath'",
        'mkdir -p "$stage_path"',
        "printf '%s' '$escapedPayload' > ""$stage_path/selection.json""",
        "printf '%s`n' '$payloadHash' > ""$stage_path/selection.sha256""",
        'uname -srmo > "$stage_path/uname.txt"',
        'printf "stage_path=%s`npayload_sha256=%s`n" "$stage_path" "' + $payloadHash + '"'
    ) -join '; '

    $arguments = @()
    if ($WslHelperState.EffectiveDistro) {
        $arguments += @('-d', $WslHelperState.EffectiveDistro)
    }
    $arguments += @('--', 'sh', '-lc', $shellScript)

    $result = Invoke-SandboxWslCommand -Arguments $arguments

    return [pscustomobject]@{
        Executed = $true
        Reason = 'Executed'
        StagePath = $WslHelperState.StagePath
        PayloadHash = $payloadHash
        Distro = $WslHelperState.EffectiveDistro
        Output = $result.Output
    }
}
