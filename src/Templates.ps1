# src/Templates.ps1
# Saved session/template persistence and resolution helpers.

function Get-SandboxTemplateStorePath {
    <#
    .SYNOPSIS
        Returns the repository-local template store path.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    return (Join-Path $RepoRoot 'saved-sessions.local.json')
}

function Assert-SandboxTemplateName {
    <#
    .SYNOPSIS
        Validates a saved template name.
    #>
    param(
        [Parameter(Mandatory)][string]$TemplateName
    )

    if ([string]::IsNullOrWhiteSpace($TemplateName)) {
        throw 'Template name is required.'
    }

    $trimmed = $TemplateName.Trim()
    if ($trimmed.Length -gt 64) {
        throw "Template name '$trimmed' is invalid. Maximum length is 64 characters."
    }

    if ($trimmed -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Template name '$trimmed' is invalid. Use letters, numbers, dot, underscore, or hyphen."
    }

    return $trimmed
}

function Get-SandboxTemplateStoreDefault {
    return [pscustomobject]@{
        schema_version = '1.0'
        templates      = @()
    }
}

function Test-SandboxTemplateValueArray {
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return $true
    }

    return ($Value -is [System.Array])
}

function ConvertTo-SandboxTemplateNormalizedEntry {
    param(
        [Parameter(Mandatory)][pscustomobject]$RawTemplate,
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][int]$Index
    )

    if (-not $RawTemplate.PSObject.Properties['name']) {
        throw "Malformed template config '$SourcePath': templates[$Index] is missing required 'name'."
    }
    if (-not $RawTemplate.PSObject.Properties['profile']) {
        throw "Malformed template config '$SourcePath': templates[$Index] is missing required 'profile'."
    }

    $name = Assert-SandboxTemplateName -TemplateName ([string]$RawTemplate.name)
    $profile = [string]$RawTemplate.profile
    if ([string]::IsNullOrWhiteSpace($profile)) {
        throw "Malformed template config '$SourcePath': templates[$Index] has empty 'profile'."
    }

    if (-not (Test-SandboxTemplateValueArray -Value $RawTemplate.add_tools)) {
        throw "Malformed template config '$SourcePath': templates[$Index].add_tools must be an array when provided."
    }
    if (-not (Test-SandboxTemplateValueArray -Value $RawTemplate.remove_tools)) {
        throw "Malformed template config '$SourcePath': templates[$Index].remove_tools must be an array when provided."
    }

    $sessionMode = 'Fresh'
    if ($RawTemplate.PSObject.Properties['session_mode']) {
        $sessionMode = [string]$RawTemplate.session_mode
        if ([string]::IsNullOrWhiteSpace($sessionMode)) {
            $sessionMode = 'Fresh'
        }
    }
    if ($sessionMode -notin @('Fresh', 'Warm')) {
        throw "Malformed template config '$SourcePath': templates[$Index].session_mode must be 'Fresh' or 'Warm'."
    }

    $useWslHelper = $false
    if ($RawTemplate.PSObject.Properties['use_wsl_helper']) {
        $useWslHelper = [bool]$RawTemplate.use_wsl_helper
    }

    $wslDistro = $null
    if ($RawTemplate.PSObject.Properties['wsl_distro']) {
        $wslDistro = [string]$RawTemplate.wsl_distro
        if ([string]::IsNullOrWhiteSpace($wslDistro)) {
            $wslDistro = $null
        }
    }

    $wslHelperStagePath = '~/.sandbox-toolkit-helper'
    if ($RawTemplate.PSObject.Properties['wsl_helper_stage_path']) {
        $wslHelperStagePath = [string]$RawTemplate.wsl_helper_stage_path
        if ([string]::IsNullOrWhiteSpace($wslHelperStagePath)) {
            $wslHelperStagePath = '~/.sandbox-toolkit-helper'
        }
    }

    if (-not $useWslHelper -and $wslDistro) {
        throw "Malformed template config '$SourcePath': templates[$Index].wsl_distro requires use_wsl_helper=true."
    }

    $sharedFolder = $null
    if ($RawTemplate.PSObject.Properties['shared_folder']) {
        $sharedFolder = [string]$RawTemplate.shared_folder
        if ([string]::IsNullOrWhiteSpace($sharedFolder)) {
            $sharedFolder = $null
        }
    }

    $useDefaultSharedFolder = $false
    if ($RawTemplate.PSObject.Properties['use_default_shared_folder']) {
        $useDefaultSharedFolder = [bool]$RawTemplate.use_default_shared_folder
    }

    if ($sharedFolder -and $useDefaultSharedFolder) {
        throw "Malformed template config '$SourcePath': templates[$Index] cannot set both shared_folder and use_default_shared_folder."
    }

    $addTools = @()
    if ($RawTemplate.PSObject.Properties['add_tools']) {
        $addTools = @($RawTemplate.add_tools | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $removeTools = @()
    if ($RawTemplate.PSObject.Properties['remove_tools']) {
        $removeTools = @($RawTemplate.remove_tools | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    return [pscustomobject]@{
        name                       = $name
        profile                    = $profile.Trim()
        add_tools                  = @($addTools)
        remove_tools               = @($removeTools)
        shared_folder              = $sharedFolder
        use_default_shared_folder  = [bool]$useDefaultSharedFolder
        shared_folder_writable     = [bool]$RawTemplate.shared_folder_writable
        disable_clipboard          = [bool]$RawTemplate.disable_clipboard
        disable_audio_input        = [bool]$RawTemplate.disable_audio_input
        disable_startup_commands   = [bool]$RawTemplate.disable_startup_commands
        session_mode               = $sessionMode
        use_wsl_helper             = [bool]$useWslHelper
        wsl_distro                 = $wslDistro
        wsl_helper_stage_path      = $wslHelperStagePath
        skip_prereq_check          = [bool]$RawTemplate.skip_prereq_check
        updated_at                 = if ($RawTemplate.PSObject.Properties['updated_at']) { [string]$RawTemplate.updated_at } else { $null }
    }
}

function Import-SandboxTemplateStore {
    <#
    .SYNOPSIS
        Loads saved template store from disk.
    #>
    param(
        [Parameter(Mandatory)][string]$TemplateStorePath
    )

    if (-not (Test-Path -LiteralPath $TemplateStorePath -PathType Leaf)) {
        return (Get-SandboxTemplateStoreDefault)
    }

    try {
        $store = Get-Content -Raw -Path $TemplateStorePath | ConvertFrom-Json
    } catch {
        throw "Malformed template config '$TemplateStorePath': $($_.Exception.Message)"
    }

    if (-not $store.PSObject.Properties['templates']) {
        throw "Malformed template config '$TemplateStorePath': missing required 'templates' property."
    }

    if (-not (Test-SandboxTemplateValueArray -Value $store.templates)) {
        throw "Malformed template config '$TemplateStorePath': 'templates' must be an array."
    }

    $normalized = [System.Collections.Generic.List[object]]::new()
    $seenNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $index = 0
    foreach ($rawTemplate in @($store.templates)) {
        if (-not $rawTemplate) {
            throw "Malformed template config '$TemplateStorePath': templates[$index] is null."
        }

        $entry = ConvertTo-SandboxTemplateNormalizedEntry -RawTemplate $rawTemplate -SourcePath $TemplateStorePath -Index $index
        if (-not $seenNames.Add($entry.name)) {
            throw "Malformed template config '$TemplateStorePath': duplicate template name '$($entry.name)'."
        }
        $normalized.Add($entry)
        $index++
    }

    return [pscustomobject]@{
        schema_version = if ($store.PSObject.Properties['schema_version']) { [string]$store.schema_version } else { '1.0' }
        templates      = @($normalized)
    }
}

function Write-SandboxTemplateStore {
    <#
    .SYNOPSIS
        Persists template store as deterministic JSON.
    #>
    param(
        [Parameter(Mandatory)][string]$TemplateStorePath,
        [Parameter(Mandatory)][PSCustomObject]$TemplateStore
    )

    $storeDirectory = Split-Path -Parent $TemplateStorePath
    if (-not (Test-Path -LiteralPath $storeDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $storeDirectory -Force | Out-Null
    }

    $TemplateStore | ConvertTo-Json -Depth 20 | Set-Content -Path $TemplateStorePath -Encoding UTF8
    return $TemplateStorePath
}

function Get-SandboxTemplateEntry {
    <#
    .SYNOPSIS
        Returns a saved template by name.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$TemplateStore,
        [Parameter(Mandatory)][string]$TemplateName
    )

    $resolvedName = Assert-SandboxTemplateName -TemplateName $TemplateName
    return @($TemplateStore.templates | Where-Object { $_.name -ieq $resolvedName } | Select-Object -First 1)
}

function Get-SandboxTemplateCatalog {
    <#
    .SYNOPSIS
        Returns stable saved template catalog rows.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$TemplateStore
    )

    return @(
        $TemplateStore.templates |
            Sort-Object name |
            ForEach-Object {
                [pscustomobject]@{
                    name        = $_.name
                    profile     = $_.profile
                    session_mode = $_.session_mode
                    use_wsl_helper = [bool]$_.use_wsl_helper
                    has_shared_folder = [bool]($_.shared_folder -or $_.use_default_shared_folder)
                    updated_at  = $_.updated_at
                }
            }
    )
}

function New-SandboxTemplateDefinition {
    <#
    .SYNOPSIS
        Creates normalized template definition payload from invocation values.
    #>
    param(
        [Parameter(Mandatory)][string]$TemplateName,
        [Parameter(Mandatory)][string]$SandboxProfile,
        [string[]]$AddTools,
        [string[]]$RemoveTools,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [switch]$DisableClipboard,
        [switch]$DisableAudioInput,
        [switch]$DisableStartupCommands,
        [ValidateSet('Fresh', 'Warm')][string]$SessionMode = 'Fresh',
        [switch]$UseWslHelper,
        [string]$WslDistro,
        [string]$WslHelperStagePath = '~/.sandbox-toolkit-helper',
        [switch]$SkipPrereqCheck
    )

    $resolvedName = Assert-SandboxTemplateName -TemplateName $TemplateName
    if ([string]::IsNullOrWhiteSpace($SandboxProfile)) {
        throw 'Template profile is required.'
    }

    if (-not $UseWslHelper -and -not [string]::IsNullOrWhiteSpace($WslDistro)) {
        throw 'Template WSL distro requires use_wsl_helper=true.'
    }
    if ($SharedFolder -and $UseDefaultSharedFolder) {
        throw 'Template cannot set both shared_folder and use_default_shared_folder.'
    }

    return [pscustomobject]@{
        name                       = $resolvedName
        profile                    = $SandboxProfile
        add_tools                  = @($AddTools)
        remove_tools               = @($RemoveTools)
        shared_folder              = if ([string]::IsNullOrWhiteSpace($SharedFolder)) { $null } else { $SharedFolder }
        use_default_shared_folder  = [bool]$UseDefaultSharedFolder
        shared_folder_writable     = [bool]$SharedFolderWritable
        disable_clipboard          = [bool]$DisableClipboard
        disable_audio_input        = [bool]$DisableAudioInput
        disable_startup_commands   = [bool]$DisableStartupCommands
        session_mode               = $SessionMode
        use_wsl_helper             = [bool]$UseWslHelper
        wsl_distro                 = if ([string]::IsNullOrWhiteSpace($WslDistro)) { $null } else { $WslDistro }
        wsl_helper_stage_path      = if ([string]::IsNullOrWhiteSpace($WslHelperStagePath)) { '~/.sandbox-toolkit-helper' } else { $WslHelperStagePath }
        skip_prereq_check          = [bool]$SkipPrereqCheck
        updated_at                 = (Get-Date -Format 'o')
    }
}

function Save-SandboxTemplateDefinition {
    <#
    .SYNOPSIS
        Upserts a template definition by name.
    #>
    param(
        [Parameter(Mandatory)][string]$TemplateStorePath,
        [Parameter(Mandatory)][PSCustomObject]$TemplateDefinition
    )

    $store = Import-SandboxTemplateStore -TemplateStorePath $TemplateStorePath
    $templates = [System.Collections.Generic.List[object]]::new()
    $updated = $false

    foreach ($existing in @($store.templates)) {
        if ($existing.name -ieq $TemplateDefinition.name) {
            $templates.Add($TemplateDefinition)
            $updated = $true
            continue
        }
        $templates.Add($existing)
    }

    if (-not $updated) {
        $templates.Add($TemplateDefinition)
    }

    $nextStore = [pscustomobject]@{
        schema_version = '1.0'
        templates      = @($templates | Sort-Object name)
    }

    Write-SandboxTemplateStore -TemplateStorePath $TemplateStorePath -TemplateStore $nextStore | Out-Null

    return [pscustomobject]@{
        Saved = $true
        Updated = $updated
        Path = $TemplateStorePath
        Template = $TemplateDefinition
    }
}

function Test-SandboxTemplateDefinitionReadiness {
    <#
    .SYNOPSIS
        Validates template references against current manifest/config state.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$TemplateDefinition,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$CustomProfilePath
    )

    $manifest = Import-ToolManifest -ManifestPath $ManifestPath
    Test-ManifestIntegrity -Manifest $manifest
    $customProfileConfig = Import-CustomProfileConfig -CustomProfilePath $CustomProfilePath
    Test-CustomProfileConfigIntegrity -CustomProfileConfig $customProfileConfig -Manifest $manifest

    try {
        Resolve-SandboxSessionSelection `
            -Manifest $manifest `
            -SandboxProfile $TemplateDefinition.profile `
            -CustomProfileConfig $customProfileConfig `
            -TemplateAddTools $TemplateDefinition.add_tools `
            -TemplateRemoveTools $TemplateDefinition.remove_tools | Out-Null
    } catch {
        throw "Template '$($TemplateDefinition.name)' is invalid: $($_.Exception.Message)"
    }

    $sharedFolderResult = Test-SandboxSharedFolderReadiness `
        -RepoRoot $RepoRoot `
        -SharedFolder $TemplateDefinition.shared_folder `
        -UseDefaultSharedFolder:$TemplateDefinition.use_default_shared_folder `
        -SharedFolderWritable:$TemplateDefinition.shared_folder_writable

    if ($sharedFolderResult.Check.Status -eq 'FAIL') {
        throw "Template '$($TemplateDefinition.name)' is invalid: $($sharedFolderResult.Check.Message)"
    }
}

function Resolve-SandboxTemplateInvocation {
    <#
    .SYNOPSIS
        Resolves effective invocation values from template defaults + explicit CLI overrides.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$TemplateDefinition,
        [Parameter(Mandatory)][hashtable]$BoundParameters,
        [string]$SandboxProfile,
        [string[]]$AddTools,
        [string[]]$RemoveTools,
        [switch]$SkipPrereqCheck,
        [string]$SharedFolder,
        [switch]$UseDefaultSharedFolder,
        [switch]$SharedFolderWritable,
        [switch]$SharedFolderValidationDiagnostics,
        [switch]$DisableClipboard,
        [switch]$DisableAudioInput,
        [switch]$DisableStartupCommands,
        [ValidateSet('Fresh', 'Warm')][string]$SessionMode = 'Fresh',
        [switch]$UseWslHelper,
        [string]$WslDistro,
        [string]$WslHelperStagePath = '~/.sandbox-toolkit-helper'
    )

    $effectiveProfile = if ($BoundParameters.ContainsKey('SandboxProfile')) { $SandboxProfile } else { [string]$TemplateDefinition.profile }
    $effectiveSessionMode = if ($BoundParameters.ContainsKey('SessionMode')) { $SessionMode } else { [string]$TemplateDefinition.session_mode }
    if ([string]::IsNullOrWhiteSpace($effectiveSessionMode)) {
        $effectiveSessionMode = 'Fresh'
    }

    $effectiveSharedFolder = $TemplateDefinition.shared_folder
    $effectiveUseDefaultSharedFolder = [bool]$TemplateDefinition.use_default_shared_folder
    if ($BoundParameters.ContainsKey('SharedFolder')) {
        $effectiveSharedFolder = $SharedFolder
        $effectiveUseDefaultSharedFolder = $false
    }
    if ($BoundParameters.ContainsKey('UseDefaultSharedFolder')) {
        $effectiveUseDefaultSharedFolder = [bool]$UseDefaultSharedFolder
        if ($UseDefaultSharedFolder) {
            $effectiveSharedFolder = $null
        }
    }

    $effectiveWslHelperStagePath = if ($BoundParameters.ContainsKey('WslHelperStagePath')) {
        $WslHelperStagePath
    } else {
        [string]$TemplateDefinition.wsl_helper_stage_path
    }
    if ([string]::IsNullOrWhiteSpace($effectiveWslHelperStagePath)) {
        $effectiveWslHelperStagePath = '~/.sandbox-toolkit-helper'
    }

    $effectiveWslDistro = if ($BoundParameters.ContainsKey('WslDistro')) { $WslDistro } else { [string]$TemplateDefinition.wsl_distro }
    $effectiveUseWslHelper = if ($BoundParameters.ContainsKey('UseWslHelper')) { [bool]$UseWslHelper } else { [bool]$TemplateDefinition.use_wsl_helper }

    $templateAddTools = @($TemplateDefinition.add_tools)
    $templateRemoveTools = @($TemplateDefinition.remove_tools)
    $runtimeAddTools = @($AddTools)
    $runtimeRemoveTools = @($RemoveTools)

    return [pscustomobject]@{
        TemplateName = $TemplateDefinition.name
        SandboxProfile = $effectiveProfile
        TemplateAddTools = @($templateAddTools)
        TemplateRemoveTools = @($templateRemoveTools)
        RuntimeAddTools = @($runtimeAddTools)
        RuntimeRemoveTools = @($runtimeRemoveTools)
        SkipPrereqCheck = if ($BoundParameters.ContainsKey('SkipPrereqCheck')) { [bool]$SkipPrereqCheck } else { [bool]$TemplateDefinition.skip_prereq_check }
        SharedFolder = $effectiveSharedFolder
        UseDefaultSharedFolder = [bool]$effectiveUseDefaultSharedFolder
        SharedFolderWritable = if ($BoundParameters.ContainsKey('SharedFolderWritable')) { [bool]$SharedFolderWritable } else { [bool]$TemplateDefinition.shared_folder_writable }
        SharedFolderValidationDiagnostics = [bool]$SharedFolderValidationDiagnostics
        DisableClipboard = if ($BoundParameters.ContainsKey('DisableClipboard')) { [bool]$DisableClipboard } else { [bool]$TemplateDefinition.disable_clipboard }
        DisableAudioInput = if ($BoundParameters.ContainsKey('DisableAudioInput')) { [bool]$DisableAudioInput } else { [bool]$TemplateDefinition.disable_audio_input }
        DisableStartupCommands = if ($BoundParameters.ContainsKey('DisableStartupCommands')) { [bool]$DisableStartupCommands } else { [bool]$TemplateDefinition.disable_startup_commands }
        SessionMode = $effectiveSessionMode
        UseWslHelper = [bool]$effectiveUseWslHelper
        WslDistro = if ([string]::IsNullOrWhiteSpace($effectiveWslDistro)) { $null } else { $effectiveWslDistro }
        WslHelperStagePath = $effectiveWslHelperStagePath
    }
}
