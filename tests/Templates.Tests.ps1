Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'src\Manifest.ps1')
. (Join-Path $repoRoot 'src\Session.ps1')
. (Join-Path $repoRoot 'src\SharedFolderValidation.ps1')
. (Join-Path $repoRoot 'src\Validation.ps1')
. (Join-Path $repoRoot 'src\Templates.ps1')

Describe 'Template store helpers' {
    It 'returns default store when local store file does not exist' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-template-store-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $storePath = Join-Path $tempRoot 'saved-sessions.local.json'
            $store = Import-SandboxTemplateStore -TemplateStorePath $storePath

            $store.schema_version | Should Be '1.0'
            $store.templates.Count | Should Be 0
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'fails on malformed template store shape' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-template-store-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $storePath = Join-Path $tempRoot 'saved-sessions.local.json'
            '{ "schema_version": "1.0" }' | Set-Content -Path $storePath -Encoding UTF8
            {
                Import-SandboxTemplateStore -TemplateStorePath $storePath | Out-Null
            } | Should Throw "missing required 'templates' property"
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    It 'upserts templates and emits a sorted catalog' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sandbox-toolkit-template-store-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $storePath = Join-Path $tempRoot 'saved-sessions.local.json'
            $first = Get-SandboxTemplateDefinition -TemplateName 'zeta' -SandboxProfile 'minimal'
            $second = Get-SandboxTemplateDefinition -TemplateName 'alpha' -SandboxProfile 'reverse-engineering'
            Save-SandboxTemplateDefinition -TemplateStorePath $storePath -TemplateDefinition $first | Out-Null
            Save-SandboxTemplateDefinition -TemplateStorePath $storePath -TemplateDefinition $second | Out-Null

            $store = Import-SandboxTemplateStore -TemplateStorePath $storePath
            $catalog = Get-SandboxTemplateCatalog -TemplateStore $store

            $store.templates.Count | Should Be 2
            $catalog[0].name | Should Be 'alpha'
            $catalog[1].name | Should Be 'zeta'
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }
}

Describe 'Template definition and resolution' {
    It 'rejects invalid template names' {
        {
            Get-SandboxTemplateDefinition -TemplateName 'bad name' -SandboxProfile 'minimal' | Out-Null
        } | Should Throw 'Template name'
    }

    It 'resolves invocation defaults from template and runtime overrides explicitly' {
        $template = Get-SandboxTemplateDefinition `
            -TemplateName 'lab-default' `
            -SandboxProfile 'minimal' `
            -AddTools @('ghidra') `
            -RemoveTools @('notepadpp') `
            -UseDefaultSharedFolder `
            -DisableClipboard `
            -SessionMode Warm `
            -UseWslHelper `
            -WslDistro 'Ubuntu'

        $resolved = Resolve-SandboxTemplateInvocation `
            -TemplateDefinition $template `
            -BoundParameters @{ SandboxProfile = $true; SharedFolder = $true; SessionMode = $true } `
            -SandboxProfile 'reverse-engineering' `
            -AddTools @('wireshark') `
            -RemoveTools @('ghidra') `
            -SharedFolder 'C:\Lab\Ingress' `
            -SessionMode 'Fresh'

        $resolved.SandboxProfile | Should Be 'reverse-engineering'
        ($resolved.TemplateAddTools -join ',') | Should Be 'ghidra'
        ($resolved.TemplateRemoveTools -join ',') | Should Be 'notepadpp'
        ($resolved.RuntimeAddTools -join ',') | Should Be 'wireshark'
        ($resolved.RuntimeRemoveTools -join ',') | Should Be 'ghidra'
        $resolved.SharedFolder | Should Be 'C:\Lab\Ingress'
        $resolved.UseDefaultSharedFolder | Should Be $false
        $resolved.DisableClipboard | Should Be $true
        $resolved.SessionMode | Should Be 'Fresh'
        $resolved.UseWslHelper | Should Be $true
    }
}

Describe 'Template readiness validation' {
    It 'fails clearly for unknown profile references' {
        $template = Get-SandboxTemplateDefinition -TemplateName 'bad-profile' -SandboxProfile 'no-such-profile'

        {
            Test-SandboxTemplateDefinitionReadiness `
                -TemplateDefinition $template `
                -RepoRoot $repoRoot `
                -ManifestPath (Join-Path $repoRoot 'tools.json') `
                -CustomProfilePath (Join-Path $repoRoot 'custom-profiles.local.json')
        } | Should Throw "Unknown profile 'no-such-profile'"
    }

    It 'fails clearly for unknown tool references in template deltas' {
        $template = Get-SandboxTemplateDefinition -TemplateName 'bad-tools' -SandboxProfile 'minimal' -AddTools @('not-a-real-tool')

        {
            Test-SandboxTemplateDefinitionReadiness `
                -TemplateDefinition $template `
                -RepoRoot $repoRoot `
                -ManifestPath (Join-Path $repoRoot 'tools.json') `
                -CustomProfilePath (Join-Path $repoRoot 'custom-profiles.local.json')
        } | Should Throw "Unknown tool id 'not-a-real-tool' in -TemplateAddTools"
    }

    It 'fails clearly for unsafe shared-folder references' {
        $template = Get-SandboxTemplateDefinition -TemplateName 'bad-shared' -SandboxProfile 'minimal' -SharedFolder $repoRoot

        {
            Test-SandboxTemplateDefinitionReadiness `
                -TemplateDefinition $template `
                -RepoRoot $repoRoot `
                -ManifestPath (Join-Path $repoRoot 'tools.json') `
                -CustomProfilePath (Join-Path $repoRoot 'custom-profiles.local.json')
        } | Should Throw 'Shared folder path is not allowed'
    }
}
