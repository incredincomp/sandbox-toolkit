# src/Audit.ps1
# Host-side audit helpers for generated sandbox artifacts.

function Get-NormalizedAuditPath {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootPath = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath -ieq $rootPath) {
        return $rootPath
    }
    return $fullPath.TrimEnd('\')
}

function Get-SandboxAuditCheck {
    <#
    .SYNOPSIS
        Creates a structured audit check entry.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Remediation
    )

    return Get-SandboxValidationCheck -Name $Name -Status $Status -Message $Message -Remediation $Remediation
}

function Read-SandboxWsbArtifact {
    <#
    .SYNOPSIS
        Loads and parses generated sandbox.wsb content.
    #>
    param(
        [Parameter(Mandatory)][string]$WsbPath
    )

    if (-not (Test-Path -LiteralPath $WsbPath -PathType Leaf)) {
        return [pscustomobject]@{
            Exists = $false
            Xml    = $null
            Error  = $null
        }
    }

    try {
        $raw = Get-Content -Raw -Path $WsbPath
        $xml = [xml]$raw
        return [pscustomobject]@{
            Exists = $true
            Xml    = $xml
            Error  = $null
        }
    } catch {
        return [pscustomobject]@{
            Exists = $true
            Xml    = $null
            Error  = $_.Exception.Message
        }
    }
}

function Read-SandboxInstallManifestArtifact {
    <#
    .SYNOPSIS
        Loads and parses generated install-manifest.json content.
    #>
    param(
        [Parameter(Mandatory)][string]$InstallManifestPath
    )

    if (-not (Test-Path -LiteralPath $InstallManifestPath -PathType Leaf)) {
        return [pscustomobject]@{
            Exists = $false
            Data   = $null
            Error  = $null
        }
    }

    try {
        $data = Get-Content -Raw -Path $InstallManifestPath | ConvertFrom-Json
        return [pscustomobject]@{
            Exists = $true
            Data   = $data
            Error  = $null
        }
    } catch {
        return [pscustomobject]@{
            Exists = $true
            Data   = $null
            Error  = $_.Exception.Message
        }
    }
}

function Get-AuditObjectPropertyValue {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$PropertyName
    )

    if (-not $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if (-not $property) {
        return $null
    }

    return $property.Value
}

function Invoke-SandboxArtifactAudit {
    <#
    .SYNOPSIS
        Computes host-side audit checks from effective configuration and generated artifacts.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][PSCustomObject]$Selection,
        [Parameter(Mandatory)][string]$NetworkingMode,
        [Parameter(Mandatory)][PSCustomObject]$HostInteractionPolicy,
        [Parameter(Mandatory)][PSCustomObject]$Artifacts,
        [string]$SharedHostFolder,
        [switch]$SharedFolderWritable,
        [switch]$SkipPrereqCheck,
        [object[]]$PrerequisiteChecks
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $sandboxSharedPath = 'C:\Users\WDAGUtilityAccount\Desktop\shared'
    $expectedScriptsHostPath = Get-NormalizedAuditPath -Path (Join-Path $RepoRoot 'scripts')
    $expectedSharedHostPath = $null
    if ($SharedHostFolder) {
        $expectedSharedHostPath = Get-NormalizedAuditPath -Path $SharedHostFolder
    }

    $checks.Add((Get-SandboxAuditCheck `
        -Name 'selection-context' `
        -Status 'PASS' `
        -Message "Computed request: profile='$($Selection.Profile)' (base='$($Selection.BaseProfile)'; type=$($Selection.ProfileType)); tools=$($Selection.Tools.Count); networking_requested=$NetworkingMode (configured/requested, not runtime-verified)."))

    $prereqChecks = @($PrerequisiteChecks | Where-Object { $_ })

    if ($SkipPrereqCheck) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'prereq-assurance' `
            -Status 'WARN' `
            -Message 'Host prerequisite checks were skipped by -SkipPrereqCheck; audit evidence is reduced-assurance and not runtime-verified.' `
            -Remediation 'Re-run audit without -SkipPrereqCheck for stronger host-side confidence.'))
    } elseif (@($prereqChecks | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'prereq-assurance' `
            -Status 'FAIL' `
            -Message 'One or more host prerequisite checks failed; generated configuration evidence does not indicate a launch-ready host.' `
            -Remediation 'Resolve prerequisite failures and re-run -Audit.'))
    } elseif (@($prereqChecks | Where-Object { $_.Status -eq 'WARN' }).Count -gt 0) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'prereq-assurance' `
            -Status 'WARN' `
            -Message 'Host prerequisite checks reported warnings; generated configuration evidence remains configured/requested only and not runtime-verified.' `
            -Remediation 'Review warnings and re-run audit with sufficient host visibility.'))
    } else {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'prereq-assurance' `
            -Status 'PASS' `
            -Message 'Host prerequisites passed for this request (host-side evidence only; runtime enforcement not verified).'))
    }

    $manifestArtifact = Read-SandboxInstallManifestArtifact -InstallManifestPath $Artifacts.InstallManifestPath
    if (-not $manifestArtifact.Exists) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'install-manifest-artifact' `
            -Status 'FAIL' `
            -Message "Generated install manifest is missing: $($Artifacts.InstallManifestPath)" `
            -Remediation 'Re-run -Audit and verify the repository path is writable.'))
    } elseif ($manifestArtifact.Error) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'install-manifest-artifact' `
            -Status 'FAIL' `
            -Message "Generated install manifest could not be parsed: $($manifestArtifact.Error)" `
            -Remediation 'Regenerate artifacts and inspect scripts/install-manifest.json for corruption.'))
    } else {
        $manifestToolIds = @($manifestArtifact.Data.tools | ForEach-Object { $_.id })
        $expectedToolIds = @($Selection.Tools | ForEach-Object { $_.id })
        $manifestToolsMatch = (($manifestToolIds -join ',') -eq ($expectedToolIds -join ','))
        $manifestProfileMatch = ($manifestArtifact.Data.profile -eq $Selection.BaseProfile)

        if (-not $manifestProfileMatch -or -not $manifestToolsMatch) {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'install-manifest-artifact' `
                -Status 'FAIL' `
                -Message "Generated install manifest mismatch: profile='$($manifestArtifact.Data.profile)' tools=$($manifestToolIds.Count) (expected base='$($Selection.BaseProfile)' tools=$($expectedToolIds.Count))." `
                -Remediation 'Regenerate artifacts and ensure one authoritative selection path is used.'))
        } else {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'install-manifest-artifact' `
                -Status 'PASS' `
                -Message "Install manifest is present and matches computed selection (configured/requested artifact evidence, not runtime-verified): $($Artifacts.InstallManifestPath)"))
        }
    }

    $wsbArtifact = Read-SandboxWsbArtifact -WsbPath $Artifacts.WsbPath
    if (-not $wsbArtifact.Exists) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'wsb-artifact' `
            -Status 'FAIL' `
            -Message "Generated sandbox configuration is missing: $($Artifacts.WsbPath)" `
            -Remediation 'Re-run -Audit and verify repository permissions.'))
    } elseif ($wsbArtifact.Error) {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'wsb-artifact' `
            -Status 'FAIL' `
            -Message "Generated sandbox configuration is not valid XML: $($wsbArtifact.Error)" `
            -Remediation 'Regenerate sandbox.wsb and inspect file contents for invalid XML.'))
    } else {
        $checks.Add((Get-SandboxAuditCheck `
            -Name 'wsb-artifact' `
            -Status 'PASS' `
            -Message "sandbox.wsb is present and parseable: $($Artifacts.WsbPath) (host-side artifact evidence only)."))

        $wsbXml = $wsbArtifact.Xml
        $configuredNetworking = [string]$wsbXml.Configuration.Networking
        if ($configuredNetworking -eq $NetworkingMode) {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-networking' `
                -Status 'PASS' `
                -Message "Networking setting '$configuredNetworking' is present in generated artifact as requested (configured/requested, not runtime-verified)."))
        } else {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-networking' `
                -Status 'FAIL' `
                -Message "Networking mismatch in generated artifact: requested '$NetworkingMode' but sandbox.wsb contains '$configuredNetworking'." `
                -Remediation 'Inspect profile resolution and regenerate sandbox.wsb.'))
        }

        $configuredClipboard = [string]$wsbXml.Configuration.ClipboardRedirection
        if ($configuredClipboard -eq $HostInteractionPolicy.ClipboardRedirection) {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-clipboard-redirection' `
                -Status 'PASS' `
                -Message "Clipboard redirection setting '$configuredClipboard' is present in generated artifact as requested (configured/requested, not runtime-verified)."))
        } else {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-clipboard-redirection' `
                -Status 'FAIL' `
                -Message "Clipboard redirection mismatch in generated artifact: requested '$($HostInteractionPolicy.ClipboardRedirection)' but sandbox.wsb contains '$configuredClipboard'." `
                -Remediation 'Regenerate sandbox.wsb and verify host-interaction policy selection path.'))
        }

        $configuredAudioInput = [string]$wsbXml.Configuration.AudioInput
        if ($configuredAudioInput -eq $HostInteractionPolicy.AudioInput) {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-audio-input' `
                -Status 'PASS' `
                -Message "Audio input setting '$configuredAudioInput' is present in generated artifact as requested (configured/requested, not runtime-verified)."))
        } else {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-audio-input' `
                -Status 'FAIL' `
                -Message "Audio input mismatch in generated artifact: requested '$($HostInteractionPolicy.AudioInput)' but sandbox.wsb contains '$configuredAudioInput'." `
                -Remediation 'Regenerate sandbox.wsb and verify host-interaction policy selection path.'))
        }

        $logonCommandNode = Get-AuditObjectPropertyValue -InputObject $wsbXml.Configuration -PropertyName 'LogonCommand'
        $configuredLogonCommand = ''
        if ($logonCommandNode) {
            $configuredLogonCommand = [string](Get-AuditObjectPropertyValue -InputObject $logonCommandNode -PropertyName 'Command')
        }
        if ($HostInteractionPolicy.StartupCommandsEnabled) {
            if ($configuredLogonCommand -match 'autostart\.cmd$') {
                $checks.Add((Get-SandboxAuditCheck `
                    -Name 'wsb-logon-command' `
                    -Status 'PASS' `
                    -Message "Logon command is present in generated artifact: '$configuredLogonCommand' (configured/requested, not runtime-verified)."))
            } else {
                $checks.Add((Get-SandboxAuditCheck `
                    -Name 'wsb-logon-command' `
                    -Status 'FAIL' `
                    -Message "Generated artifact is missing expected startup command reference to autostart.cmd. Found: '$configuredLogonCommand'" `
                    -Remediation 'Regenerate sandbox.wsb and ensure scripts/autostart.cmd mapping remains intact.'))
            }
        } else {
            if ([string]::IsNullOrWhiteSpace($configuredLogonCommand)) {
                $checks.Add((Get-SandboxAuditCheck `
                    -Name 'wsb-logon-command' `
                    -Status 'PASS' `
                    -Message 'Logon command block is omitted in generated artifact as requested (configured/requested, not runtime-verified).'))
            } else {
                $checks.Add((Get-SandboxAuditCheck `
                    -Name 'wsb-logon-command' `
                    -Status 'FAIL' `
                    -Message "Startup command suppression was requested, but generated artifact still contains logon command '$configuredLogonCommand'." `
                    -Remediation 'Regenerate sandbox.wsb and verify -DisableStartupCommands wiring.'))
            }
        }

        $mappedFolders = @($wsbXml.Configuration.MappedFolders.MappedFolder)
        $scriptsMapping = $mappedFolders | Where-Object {
            $hostFolder = [string](Get-AuditObjectPropertyValue -InputObject $_ -PropertyName 'HostFolder')
            if (-not $hostFolder) {
                return $false
            }
            (Get-NormalizedAuditPath -Path $hostFolder) -ieq $expectedScriptsHostPath
        } | Select-Object -First 1

        if (-not $scriptsMapping) {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-scripts-mapping' `
                -Status 'FAIL' `
                -Message "Generated artifact is missing scripts host-folder mapping: expected '$expectedScriptsHostPath'." `
                -Remediation 'Regenerate sandbox.wsb and verify repository scripts/ path.'))
        } elseif ([string]$scriptsMapping.ReadOnly -ine 'true') {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-scripts-mapping' `
                -Status 'FAIL' `
                -Message 'Generated scripts mapping is not read-only; this increases host exposure risk.' `
                -Remediation 'Ensure scripts mapping uses <ReadOnly>true</ReadOnly> in sandbox.wsb generation.'))
        } else {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-scripts-mapping' `
                -Status 'PASS' `
                -Message "scripts/ host mapping is present and read-only in generated artifact (configured/requested, not runtime-verified)."))
        }

        $sharedMapping = $mappedFolders | Where-Object {
            $sandboxFolder = [string](Get-AuditObjectPropertyValue -InputObject $_ -PropertyName 'SandboxFolder')
            $sandboxFolder -ieq $sandboxSharedPath
        } | Select-Object -First 1

        if ($expectedSharedHostPath) {
            if (-not $sharedMapping) {
                $checks.Add((Get-SandboxAuditCheck `
                    -Name 'wsb-shared-folder' `
                    -Status 'FAIL' `
                    -Message "Shared folder was requested ('$expectedSharedHostPath') but generated artifact does not include Desktop\\shared mapping." `
                    -Remediation 'Regenerate sandbox.wsb and verify shared-folder parameters.'))
            } else {
                $actualSharedHostPath = Get-NormalizedAuditPath -Path ([string](Get-AuditObjectPropertyValue -InputObject $sharedMapping -PropertyName 'HostFolder'))
                $actualReadOnly = [string](Get-AuditObjectPropertyValue -InputObject $sharedMapping -PropertyName 'ReadOnly')
                $expectedReadOnly = if ($SharedFolderWritable) { 'false' } else { 'true' }

                if ($actualSharedHostPath -ine $expectedSharedHostPath) {
                    $checks.Add((Get-SandboxAuditCheck `
                        -Name 'wsb-shared-folder' `
                        -Status 'FAIL' `
                        -Message "Shared folder host path mismatch: requested '$expectedSharedHostPath' but artifact maps '$actualSharedHostPath'." `
                        -Remediation 'Regenerate sandbox.wsb and verify shared-folder selection path.'))
                } elseif ($actualReadOnly -ine $expectedReadOnly) {
                    $checks.Add((Get-SandboxAuditCheck `
                        -Name 'wsb-shared-folder' `
                        -Status 'FAIL' `
                        -Message "Shared folder read-only mismatch: requested ReadOnly='$expectedReadOnly' but artifact contains '$actualReadOnly'." `
                        -Remediation 'Regenerate sandbox.wsb and verify -SharedFolderWritable usage.'))
                } elseif ($SharedFolderWritable) {
                    $checks.Add((Get-SandboxAuditCheck `
                        -Name 'wsb-shared-folder' `
                        -Status 'WARN' `
                        -Message "Shared folder mapping is present and writable in generated artifact ('$expectedSharedHostPath'); this is configured/requested and not runtime-verified." `
                        -Remediation 'Prefer read-only mapping unless write-back is explicitly required.'))
                } else {
                    $checks.Add((Get-SandboxAuditCheck `
                        -Name 'wsb-shared-folder' `
                        -Status 'PASS' `
                        -Message "Shared folder mapping is present and read-only in generated artifact ('$expectedSharedHostPath') (configured/requested, not runtime-verified)."))
                }
            }
        } elseif ($sharedMapping) {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-shared-folder' `
                -Status 'WARN' `
                -Message 'Generated artifact includes optional shared-folder mapping even though no shared folder was requested.' `
                -Remediation 'Inspect sandbox.wsb generation path and remove unexpected shared mappings.'))
        } else {
            $checks.Add((Get-SandboxAuditCheck `
                -Name 'wsb-shared-folder' `
                -Status 'PASS' `
                -Message 'No optional shared-folder mapping present in generated artifact, matching requested configuration (host-side evidence only).'))
        }
    }

    $hasFailures = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0
    $hasWarnings = @($checks | Where-Object { $_.Status -eq 'WARN' }).Count -gt 0

    return [pscustomobject]@{
        Checks = @($checks)
        HasFailures = $hasFailures
        HasWarnings = $hasWarnings
    }
}

function Write-SandboxAuditReport {
    <#
    .SYNOPSIS
        Renders audit checks in PASS/WARN/FAIL format.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$AuditResult
    )

    Write-StatusLine '[Audit] Host-side sandbox request and artifact checks' -ForegroundColor Yellow
    foreach ($check in $AuditResult.Checks) {
        $color = switch ($check.Status) {
            'PASS' { [ConsoleColor]::Green }
            'WARN' { [ConsoleColor]::Yellow }
            default { [ConsoleColor]::Red }
        }

        Write-StatusLine ("  [{0}] {1}: {2}" -f $check.Status, $check.Name, $check.Message) -ForegroundColor $color
        if ($check.Remediation) {
            Write-StatusLine "         Remediation: $($check.Remediation)" -ForegroundColor DarkGray
        }
    }
}

function Get-SandboxAuditExitCode {
    <#
    .SYNOPSIS
        Returns deterministic process exit code for audit mode.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$AuditResult
    )

    if ($AuditResult.HasFailures) {
        return 1
    }
    return 0
}
