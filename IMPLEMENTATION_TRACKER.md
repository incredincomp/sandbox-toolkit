# IMPLEMENTATION_TRACKER.md

Live state file for **sandbox-toolkit**.
Update this file at every milestone boundary. Do not let it go stale.

---

## Current phase

**Phase: Initial discovery**

---

## Objective

Provide a manifest-driven Windows Sandbox toolkit that automates downloading and installing a curated set of analysis tools into a disposable sandbox, with profiles controlling networking and installed components.

---

## Milestone status

| # | Milestone | Status | Notes |
|---|-----------|--------|-------|
| 1 | Initial discovery | ✅ Complete | Performed repo structure & tooling analysis, created discovery artifacts and docs. |
| 2 | Define development workflow | ⏳ Pending | Establish standard commands, validation checks, and development guidance. |

---

## Decisions made

| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Use PowerShell/Pester for tests and linting | Repository is primarily PowerShell; CI already uses PSScriptAnalyzer and Pester | Introduce a different test framework (not needed for current scope) |

---

## Files created or modified

### Discovery run (Milestone 1)
- `AGENTS.md` — execution contract
- `IMPLEMENTATION_TRACKER.md` — this file
- `docs/ai/REPO_MAP.md` — repository map
- `docs/ai/SOURCE_REFRESH.md` — source refresh instructions
- `docs/ai/AI_AGENT_VENDOR_KNOWLEDGE_BASE.md` — vendor knowledge
- `artifacts/ai/repo_discovery.json` — discovery artifact

---

## Validation status

| Check | Result | Method | Date |
|-------|--------|--------|------|
| Required bootstrap files present | ✅ | manual inspection | 2026-03-14 |
| No unfilled placeholders | ✅ | `grep -rn '{{' AGENTS.md IMPLEMENTATION_TRACKER.md docs/ai/ bootstrap/ artifacts/ai/` | 2026-03-14 |
| `artifacts/ai/repo_discovery.json` valid JSON | ✅ | `python -m json.tool artifacts/ai/repo_discovery.json` | 2026-03-14 |
| Tests passing | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |

---

## Open improvements

- [ ] Add a LICENSE file to clarify usage and redistribution terms.
- [ ] Define a clear development workflow (commands for lint/test/run) in docs.

---

## Handoff notes

**Session summary:** Completed repository discovery and populated agent-facing artifacts. Identified key entry points, CI setup, and documentation state.

**State at closeout:** Discovery artifacts updated; no application code modified; tests executed and passing.

**How to resume:**
1. Read `AGENTS.md` to understand the execution contract.
2. Read this file to understand the current phase and next milestone.
3. Read `docs/ai/REPO_MAP.md` to understand the repository structure.
4. Read `artifacts/ai/repo_discovery.json` for the latest discovery findings.

---

## Next strongest bounded milestone

**Milestone 2 — Define development workflow**

Scope:
- Document and validate standard commands for linting, testing, and running locally.
- Ensure CI steps are repeatable locally and documented.

Acceptance criteria:
- Clear commands exist for lint/test/run.
- Running the full validation suite succeeds locally.

Estimated size: Small (1–2 files)

---

## 2026-03-15 Session log (tool update/versioning pass)

### Scope
- Add a bounded, read-only tool update visibility workflow without redesigning package management.
- Extend manifest metadata/schema for maintainable update-source definitions.
- Add deterministic adapter seams and tests for update detection behavior.

### Decisions made
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add optional per-tool `update` metadata block in `tools.json` (`strategy`, source details, confidence) | Least disruptive way to layer update checks onto existing manifest model | Separate external config store (unnecessary complexity for current scope) |
| Implement `-CheckForUpdates` as read-only command mode that reuses existing profile/custom/template/override selection resolution | Keeps one effective-config path; avoids drift from run/validate/dry-run behavior | Build a parallel "all-tools updater" flow |
| Centralize source-specific behavior in `src/Updates.ps1` adapters (`github_release`, `rss`, `static`, `unsupported`) | Deterministic seam for tests and future optional bump mode | Inline source lookups inside `Start-Sandbox.ps1` |
| Treat discovery failures as per-tool `unknown` status (not fatal mode failure) | Prevent brittle network/source behavior from breaking whole report mode | Hard-fail command on first source lookup error |
| Keep bumping/version mutation out of scope in this release | Requirement is read-only visibility first | Add auto-bump mode in same pass |

### Files modified
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Manifest.ps1`
- `src/Output.ps1`
- `src/Updates.ps1` (new)
- `schemas/tools.schema.json`
- `tools.json`
- `tests/Cli.Tests.ps1`
- `tests/Manifest.Tests.ps1`
- `tests/Output.Tests.ps1`
- `tests/StartSandboxCliIntegration.Tests.ps1`
- `tests/StartSandboxJson.Tests.ps1`
- `tests/Updates.Tests.ps1` (new)
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`

### Validation
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer (Error,Warning) | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

---

## 2026-03-15 Session log (curated tooling expansion pass)

### Scope
- Add a bounded curated first wave of analysis/developer tool entries using existing manifest/profile/update model.
- Add built-in profile packs for triage, Windows reversing, behavior+network tracing, and developer workflows.
- Keep uncertain tools explicit as manual/advanced instead of fake automation.

### Decisions made
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `dependencies` as automated GitHub-release portable tool with update metadata | High-confidence release source and deterministic adapter compatibility | Mark as manual despite reliable source |
| Model `api-monitor`, `procdot`, `visual-studio-community`, and `windows-sdk` as `source_type: manual` + `installer_type: manual` | Packaging/install/update paths are interactive or weakly standardized for this repo’s non-flaky automation goals | Pretend full unattended install support |
| Add explicit host-side handling for `source_type: manual` in download flow | Schema already allowed manual source; runtime previously threw for this shape | Keep schema/runtime mismatch and avoid manual-source entries |
| Keep new curated profile packs narrowly scoped and include only required bootstrap helper (`7zip`) | Preserves bounded scope and deterministic install ordering | Expand each new profile into broad kitchen-sink bundles |
| Document REMnux and VirusTotal uploader as intentionally deferred | Aligns with scope constraints and avoids misleading first-class claims | Add speculative/unsupported integration stubs |

### Files modified
- `Start-Sandbox.ps1`
- `src/Manifest.ps1`
- `src/SandboxConfig.ps1`
- `src/Download.ps1`
- `scripts/Install-Tools.ps1`
- `tools.json`
- `schemas/tools.schema.json`
- `tests/Download.Tests.ps1` (new)
- `tests/Cli.Tests.ps1`
- `tests/Session.Tests.ps1`
- `tests/StartSandboxCliIntegration.Tests.ps1`
- `tests/Updates.Tests.ps1`
- `.github/workflows/validate.yml`
- `README.md`
- `docs/QUICKSTART.md`
- `docs/PROFILES.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Full test suite | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer (Error,Warning) | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

---

## 2026-03-15 Session log (release cut v2.1.0)

### Scope
- Verify release convention/remotes/tag history.
- Confirm integration hardening coverage and deterministic CI seams.
- Cut and publish release `v2.1.0` with annotated tag and release notes.

### Decisions made
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Use `v2.1.0` as the release tag/version | Changelog already defines 2.1.0 user-facing feature set and prior published tag is `v2.0.7` | Backfill separate `v2.0.8`/`v2.0.9` tags |
| Keep release mechanism as annotated git tag + GitHub release object | Existing repo history uses annotated tags and GitHub remote is available with authenticated `gh` CLI | Changelog-only release without tag/release object |
| Publish consolidated release notes artifact at `artifacts/releases/v2.1.0.md` | Deterministic local handoff artifact even if remote release APIs fail later | Depend only on changelog excerpts |

### Files modified
- `artifacts/releases/v2.1.0.md` (new)
- `IMPLEMENTATION_TRACKER.md`

### Validation
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Full test suite | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer (Error,Warning) | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |
| Remote health/reachability | ✅ | `git ls-remote --heads origin` / `git ls-remote --tags origin` | 2026-03-15 |

---

## 2026-03-15 Session log (release automation workflow)

### Scope
- Add a bounded tag-triggered release workflow so `v*` tags automatically publish/update GitHub release objects.

### Decisions made
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `.github/workflows/release.yml` triggered by `push.tags: v*` | Aligns with existing tag-based release convention and keeps manual release steps minimal | Manual `gh release create` for every tag |
| Use `gh release` CLI in workflow to create-or-edit release object idempotently | Keeps behavior explicit and avoids duplicate-release failures on reruns | Fail job when release already exists |
| Prefer `artifacts/releases/<version>.md` notes and generate fallback notes when missing | Preserves current release-note artifact pattern while keeping tag automation resilient | Hard-fail if notes file is missing |

### Files modified
- `.github/workflows/release.yml` (new)
- `README.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Full test suite | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer (Error,Warning) | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

---

## 2026-03-15 Session log (release hardening follow-up)

### Scope
- Run bounded integration hardening for dry-run/validate/list/cleanup command surfaces.
- Tighten deterministic CI smoke/exit-code coverage for release readiness.
- Align release docs/changelog with confirmed behavior.

### Decisions made
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add characterization tests for list-mode invalid combinations and cleanup scope against local config surfaces | Required release-hardening combinations should be proven end-to-end, not only in unit tests | Keep only existing unit-level CLI combination tests |
| Standardize non-JSON fatal handling to concise `Write-Error` + exit `1` | Improves user-facing consistency for fatal errors while preserving deterministic exit behavior | Preserve raw exception rethrow output |
| Extend CI smoke + exit-code contract with check-for-updates and list invalid-combo cases | Keep release confidence aligned with documented command/exit behavior | Rely only on Pester suites for this coverage |

### Files modified
- `tests/StartSandboxReleaseHardening.Tests.ps1`
- `Start-Sandbox.ps1`
- `.github/workflows/validate.yml`
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Release hardening characterization tests | ✅ | `Invoke-Pester -Path tests/StartSandboxReleaseHardening.Tests.ps1` | 2026-03-15 |
| CLI integration tests | ✅ | `Invoke-Pester -Path tests/StartSandboxCliIntegration.Tests.ps1` | 2026-03-15 |
| JSON mode tests | ✅ | `Invoke-Pester -Path tests/StartSandboxJson.Tests.ps1` | 2026-03-15 |
| Full test suite | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer (Error,Warning) | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

---

## 2026-03-14 Session log (CLI foundation pass)

### Scope
- Isolate selection/config artifact generation seams required for upcoming `-DryRun` support.

### Decisions made
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `src/Session.ps1` for session manifest + `.wsb` artifact generation helpers | Reuse exact generation logic across real launch and dry-run flows with minimal churn | Keep artifact generation inline in `Start-Sandbox.ps1` (would duplicate logic for dry-run) |

### Files modified
- `src/Session.ps1` (new)
- `Start-Sandbox.ps1`
- `tests/Session.Tests.ps1` (new)

### Validation
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |

### Scope (feature pass)
- Add CLI discovery and simulation switches: `-ListTools`, `-ListProfiles`, `-DryRun`.
- Keep normal launch behavior unchanged.

### Decisions made (feature pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `src/Cli.ps1` for invocation-mode validation and launch suppression helper | Keeps command-mode decisions testable outside top-level script flow | Keep all mode branching inline in `Start-Sandbox.ps1` |
| `-DryRun` writes install-manifest and `.wsb`, but skips downloads and launch | Provides actionable output for CI/debugging while avoiding network/download side effects | Perform full download queue in dry-run (too heavy and mutative) |
| List modes reject execution/shared-folder switches | Prevent ambiguous invocations and accidental side effects | Silently ignore unrelated switches |

### Files modified (feature pass)
- `Start-Sandbox.ps1`
- `src/Cli.ps1` (new)
- `src/Manifest.ps1`
- `src/SandboxConfig.ps1`
- `src/Session.ps1`
- `tests/Cli.Tests.ps1` (new)
- `tests/Session.Tests.ps1`

### Validation (feature pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (docs pass)
- Document `-ListTools`, `-ListProfiles`, and `-DryRun` in user-facing quick workflows.

### Files modified (docs pass)
- `README.md`
- `docs/QUICKSTART.md`

### Validation (docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (validation refactor pass)
- Centralize non-destructive preflight checks into a reusable validation seam.
- Add manifest dependency-reference integrity validation.

### Decisions made (validation refactor pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `src/Validation.ps1` with structured check objects (`PASS`/`WARN`/`FAIL`) | Keep `-Validate` logic testable and separate from console rendering | Keep preflight checks inline in `Start-Sandbox.ps1` |
| Keep shared-folder preflight non-mutating by warning when default `shared/` does not exist | Preserve no-mutation guarantee for future `-Validate` mode | Reuse `Resolve-SharedFolderRequest` directly (would auto-create `shared/`) |
| Add dependency-id existence checks in `Test-ManifestIntegrity` | Surface invalid tool references early in selection/preflight | Rely only on runtime install-order failures |

### Files modified (validation refactor pass)
- `src/Manifest.ps1`
- `src/Validation.ps1` (new)
- `tests/Manifest.Tests.ps1` (new)
- `tests/Validation.Tests.ps1` (new)

### Validation (validation refactor pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (validate feature pass)
- Add `-Validate` as a first-class non-destructive command mode.
- Ensure validate mode checks readiness but skips downloads, artifact generation, and launch.

### Decisions made (validate feature pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Introduce `Get-StartSandboxModePlan` and `Validate` command mode in `src/Cli.ps1` | Deterministic stage gating makes non-destructive behavior testable | Inline conditional checks scattered in `Start-Sandbox.ps1` |
| Route `-Validate` through `Invoke-SandboxPreflightValidation` and exit via `Get-SandboxValidationExitCode` | Provides structured PASS/WARN/FAIL output and deterministic exit semantics | Reuse `-DryRun` path (would generate artifacts and blur semantics) |
| Reuse `Test-SandboxHostPrerequisite` in normal runtime prerequisite stage | Reduces drift between launch-time and validate-time prerequisite checks | Keep separate prerequisite implementations |

### Files modified (validate feature pass)
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Manifest.ps1`
- `tests/Cli.Tests.ps1`
- `tests/Validation.Tests.ps1`

### Validation (validate feature pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (validate docs pass)
- Document `-Validate` behavior, limits, examples, and remediation guidance.

### Files modified (validate docs pass)
- `README.md`
- `docs/QUICKSTART.md`

### Validation (validate docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (profiles refactor pass)
- Centralize effective tool-selection ordering/deduplication into reusable helper logic.
- Add characterization test coverage to preserve built-in selection behavior.

### Decisions made (profiles refactor pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `Resolve-SandboxEffectiveToolSelection` in `src/Session.ps1` and route built-in profile selection through it | Create one deterministic ordering/dedupe seam for upcoming custom-profile and runtime-override layering | Keep profile selection inline with repeated ordering logic |

### Files modified (profiles refactor pass)
- `src/Session.ps1`
- `tests/Session.Tests.ps1`

### Validation (profiles refactor pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (custom profile feature pass)
- Add optional local custom profile config support.
- Validate custom profile config shape, base-profile references, and tool-id references.
- Surface built-in and custom profiles together for profile listing and selection.

### Decisions made (custom profile feature pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Use optional repo-local `custom-profiles.local.json` for user-defined profiles | Enables reusable local profiles without requiring manifest edits or repo forking | Extend `tools.json` schema with custom profile definitions |
| Require custom profiles to reference a built-in `base_profile` and optional `add_tools`/`remove_tools` | Keeps networking/config behavior stable and reuses built-in profile semantics | Permit fully arbitrary custom profile definitions in this pass |
| Validate custom profile config before selection/listing usage | Fail fast with actionable errors when user config is malformed | Defer errors to later runtime stages |

### Files modified (custom profile feature pass)
- `Start-Sandbox.ps1`
- `src/Manifest.ps1`
- `src/Session.ps1`
- `src/Validation.ps1`
- `tests/Cli.Tests.ps1`
- `tests/Manifest.Tests.ps1`
- `tests/Session.Tests.ps1`
- `tests/Validation.Tests.ps1`
- `tests/fixtures/custom-profiles.valid.json` (new)
- `tests/fixtures/custom-profiles.invalid-shape.json` (new)
- `tests/fixtures/custom-profiles.unknown-tool.json` (new)

### Validation (custom profile feature pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (runtime override feature pass)
- Add `-AddTools` and `-RemoveTools` runtime override options.
- Apply override precedence consistently across run, dry-run, and validate flows.
- Document custom-profile and override usage.

### Decisions made (runtime override feature pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Validate override tool IDs in authoritative selection seam (`Resolve-SandboxSessionSelection`) | Ensures one source of truth for run/validate/dry-run behavior | Validate overrides separately in each command mode |
| Runtime precedence is add-then-remove | Deterministic conflict resolution and explicit “remove wins last” semantics | Reject add/remove overlap as hard error |
| Keep `-RemoveTools` harmless for valid but absent IDs | Supports additive/removal workflows without brittle failures | Fail when removing a valid but currently-unselected tool |

### Files modified (runtime override feature pass)
- `.gitignore`
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Session.ps1`
- `src/Validation.ps1`
- `tests/Cli.Tests.ps1`
- `tests/Session.Tests.ps1`
- `tests/StartSandboxDryRun.Tests.ps1` (new)
- `tests/Validation.Tests.ps1`
- `README.md`
- `docs/QUICKSTART.md`

### Validation (runtime override feature pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (json output refactor pass)
- Centralize machine-readable projection for validate/dry-run into thin output helpers.

### Decisions made (json output refactor pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `src/Output.ps1` projection helpers instead of serializing inline in `Start-Sandbox.ps1` | Keeps rendering separate from selection/validation business logic and reusable in tests | Build JSON dictionaries directly in command handlers |

### Files modified (json output refactor pass)
- `src/Output.ps1` (new)
- `tests/Output.Tests.ps1` (new)

### Validation (json output refactor pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (json output feature pass)
- Add `-OutputJson` support for `-Validate` and `-DryRun`.
- Preserve default human-readable output and existing exit semantics.

### Decisions made (json output feature pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Restrict `-OutputJson` to `-Validate` and `-DryRun` | Keeps mode semantics explicit and avoids mixed-output ambiguity | Support all command modes in this pass |
| Suppress human status lines in JSON mode via `Write-StatusLine` gate | Prevents mixed text + JSON output and keeps automation output parseable | Maintain existing text output and append JSON blob |
| Emit structured JSON error envelope for fatal JSON-mode failures | Keeps invalid selection/override failures machine-readable | Let unhandled exceptions print text errors in JSON mode |

### Files modified (json output feature pass)
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `tests/Cli.Tests.ps1`
- `tests/StartSandboxJson.Tests.ps1` (new)

### Validation (json output feature pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (json output docs pass)
- Document `-OutputJson` usage and JSON contract expectations for automation workflows.

### Files modified (json output docs pass)
- `README.md`
- `docs/QUICKSTART.md`

### Validation (json output docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer ... }` | 2026-03-14 |

### Scope (list json output completion pass)
- Extend `-OutputJson` support to list discovery modes: `-ListTools` and `-ListProfiles`.
- Preserve default human-readable list output.

### Decisions made (list json output completion pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add list-mode JSON projection helpers in `src/Output.ps1` | Keep output rendering thin and aligned with existing validate/dry-run JSON projection pattern | Build list JSON inline in `Start-Sandbox.ps1` |
| Reject `-OutputJson` when both `-ListTools` and `-ListProfiles` are passed together | Avoid ambiguous JSON payload shape for automation consumers | Emit combined mixed list payload in a single response object |
| Reuse existing manifest/custom-profile catalog helpers for JSON list data | Prevent duplicated parsing/selection logic in output layer | Rebuild catalogs independently for JSON rendering |

### Files modified (list json output completion pass)
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Output.ps1`
- `tests/Cli.Tests.ps1`
- `tests/Output.Tests.ps1`
- `tests/StartSandboxJson.Tests.ps1`
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (list json output completion pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (output projections) | ✅ | `Invoke-Pester -Path tests/Output.Tests.ps1` | 2026-03-14 |
| Pester tests (CLI rules) | ✅ | `Invoke-Pester -Path tests/Cli.Tests.ps1` | 2026-03-14 |
| Pester tests (JSON integration) | ✅ | `Invoke-Pester -Path tests/StartSandboxJson.Tests.ps1` | 2026-03-14 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (maintenance cleanup pass)
- Add bounded `-CleanDownloads` mode for safe removal of repo-owned disposable download/session artifacts.

### Decisions made (maintenance cleanup pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Limit cleanup scope to `scripts/setups/*`, `scripts/install-manifest.json`, and `sandbox.wsb` | These are toolkit-generated/owned and safely regenerable | Broad recursive cleanup heuristics based on filename patterns |
| Add dedicated `src/Maintenance.ps1` helpers for discovery, execution, and summary rendering | Keeps cleanup behavior testable and separate from command handler flow | Inline cleanup logic in `Start-Sandbox.ps1` |
| Skip reparse-point entries under setup cache during candidate discovery | Avoid ambiguous ownership and accidental traversal risk | Recursively delete all entries including reparse points |
| Return success when nothing exists to clean; return non-zero on partial deletion failures | Deterministic maintenance semantics and actionable failure reporting | Treat missing paths as failures |

### Files modified (maintenance cleanup pass)
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Maintenance.ps1` (new)
- `tests/Cli.Tests.ps1`
- `tests/Maintenance.Tests.ps1` (new)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (maintenance cleanup pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (cleanup helpers) | ✅ | `Invoke-Pester -Path tests/Maintenance.Tests.ps1` | 2026-03-14 |
| Pester tests (CLI rules) | ✅ | `Invoke-Pester -Path tests/Cli.Tests.ps1` | 2026-03-14 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (audit mode pass)
- Add a distinct non-destructive `-Audit` mode focused on host-side/config-side sanity checks over generated artifacts.
- Keep existing run/list/dry-run/validate/output/cleanup behavior intact.

### Decisions made (audit mode pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `src/Audit.ps1` with dedicated artifact read-back + check computation seam | Keeps audit logic testable and separate from CLI rendering/wiring | Extend `src/Validation.ps1` directly (would blur readiness vs artifact sanity responsibilities) |
| Keep `-Audit` distinct from `-Validate` and run artifact generation path before checks | Audit must inspect generated `sandbox.wsb` / install manifest evidence, not just preflight state | Reuse `-Validate` only (insufficient for generated-artifact mismatch detection) |
| Include `-OutputJson` support for audit mode | Existing output projection layer made this low-risk and reviewable | Defer audit JSON despite minimal incremental complexity |
| Use explicit configured/requested wording with "not runtime-verified" in trust-sensitive checks | Prevent overclaiming sandbox/runtime enforcement | Report checks as if they prove runtime isolation |

### Files modified (audit mode pass)
- `Start-Sandbox.ps1`
- `src/Audit.ps1` (new)
- `src/Cli.ps1`
- `src/Output.ps1`
- `tests/Audit.Tests.ps1` (new)
- `tests/Cli.Tests.ps1`
- `tests/Output.Tests.ps1`
- `tests/StartSandboxAudit.Tests.ps1` (new)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (audit mode pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (audit unit seam) | ✅ | `Invoke-Pester -Path tests/Audit.Tests.ps1` | 2026-03-14 |
| Pester tests (audit integration) | ✅ | `Invoke-Pester -Path tests/StartSandboxAudit.Tests.ps1` | 2026-03-14 |
| Pester tests (CLI rules) | ✅ | `Invoke-Pester -Path tests/Cli.Tests.ps1` | 2026-03-14 |
| Pester tests (output projections) | ✅ | `Invoke-Pester -Path tests/Output.Tests.ps1` | 2026-03-14 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (audit JSON contract lock pass)
- Lock `-Audit -OutputJson` contract expectations for automation consumers.
- Document stable fields and trust-boundary semantics in authoritative docs.

### Decisions made (audit JSON contract lock pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Keep current audit JSON shape unchanged; add contract tests instead of normalizing fields | Existing output shape is already coherent and in active use | Introduce unnecessary output-field renames that would risk compatibility |
| Add focused shape assertions in output and integration tests | Prevent accidental schema drift without brittle full-payload snapshots | Snapshot whole JSON payloads (too brittle for additive evolution) |
| Add README example payload with parser guard in tests | Keep docs and real contract aligned over time with minimal overhead | Document contract only in prose without executable drift detection |

### Files modified (audit JSON contract lock pass)
- `tests/Output.Tests.ps1`
- `tests/StartSandboxAudit.Tests.ps1`
- `tests/AuditJsonContract.Tests.ps1` (new)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (audit JSON contract lock pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (output contract) | ✅ | `Invoke-Pester -Path tests/Output.Tests.ps1` | 2026-03-14 |
| Pester tests (audit integration contract) | ✅ | `Invoke-Pester -Path tests/StartSandboxAudit.Tests.ps1` | 2026-03-14 |
| Pester tests (README example contract) | ✅ | `Invoke-Pester -Path tests/AuditJsonContract.Tests.ps1` | 2026-03-14 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (audit JSON release-note pass)
- Record audit JSON contract stability for automation consumers in release-history surface.

### Decisions made (audit JSON release-note pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add a concise changelog note under a new patch section | Existing repo convention already uses versioned changelog entries | Spread this update across multiple docs without release-history discoverability |
| Keep pass documentation-only with no output/test behavior changes | Goal is release communication and downstream discoverability | Reopen output or test contract logic in this pass |

### Files modified (audit JSON release-note pass)
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (audit JSON release-note pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (contributor guardrail pass)
- Add a minimal contributor/reviewer checklist guardrail for breaking documented JSON contract changes.

### Decisions made (contributor guardrail pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `.github/pull_request_template.md` with a focused JSON-contract checklist | No existing PR template or `CONTRIBUTING.md` surface was present; this is the smallest conventional review hook | Create a larger `CONTRIBUTING.md` process guide (unnecessary scope expansion) |
| Keep checklist wording narrow to breaking documented contract fields/shapes and additive-vs-breaking distinction | Avoid overclassifying all JSON changes as breaking while preserving changelog discipline | Generic “update changelog for all JSON changes” wording (too broad) |

### Files modified (contributor guardrail pass)
- `.github/pull_request_template.md` (new)
- `IMPLEMENTATION_TRACKER.md`

### Validation (contributor guardrail pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (custom profile authoring pass)
- Add a copyable custom profile example and document local authoring rules for `custom-profiles.local.json`.
- Add focused test coverage to keep the example aligned with real loader/validator rules.

### Decisions made (custom profile authoring pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add one authoritative sample at repo root: `custom-profiles.example.json` | Matches the local-file location users actually copy to (`custom-profiles.local.json`) and keeps discovery simple | Introduce a new examples directory pattern for a single sample |
| Validate sample through real `Import-CustomProfileConfig` + `Test-CustomProfileConfigIntegrity` path | Ensures sample drifts are caught by existing validation semantics | Text-level snapshot assertions on sample file contents |
| Keep runtime behavior unchanged; improve docs only | Scope is authoring ergonomics and guardrails, not selection semantics | Add broader schema tooling or runtime validation changes |

### Files modified (custom profile authoring pass)
- `custom-profiles.example.json` (new)
- `tests/Manifest.Tests.ps1`
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (custom profile authoring pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (custom profile sample guard) | ✅ | `Invoke-Pester -Path tests/Manifest.Tests.ps1` | 2026-03-14 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (custom profile troubleshooting docs pass)
- Add concise troubleshooting guidance for local custom-profile authoring failures.

### Decisions made (custom profile troubleshooting docs pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Keep this pass documentation-only in README/QUICKSTART | Existing validator behavior already enforces needed categories; user friction was interpretation | Change validation logic or error text in code |
| Ground troubleshooting items only in real validator categories | Avoid inventing non-existent failure modes | Generic FAQ entries not tied to actual checks |

### Files modified (custom profile troubleshooting docs pass)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (custom profile troubleshooting docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (recommended workflow docs pass)
- Add one compact end-to-end recommended usage workflow spanning discovery, custom profile setup, validate, dry-run, audit, and run.

### Decisions made (recommended workflow docs pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add primary workflow section in README and concise mirrored section in QUICKSTART | Keeps one authoritative flow while preserving quick-start discoverability | Create a new standalone workflow doc (unnecessary duplication) |
| Keep commands limited to existing supported surfaces and profile examples | Avoid inventing capabilities or drift from implemented CLI modes | Broad recipe catalog with mode permutations |

### Files modified (recommended workflow docs pass)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (recommended workflow docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (workflow drift guardrail pass)
- Add a PR-template reminder to review workflow docs when user-facing command-mode flow changes.

### Decisions made (workflow drift guardrail pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Extend existing `.github/pull_request_template.md` with a narrow workflow-doc impact checklist | Existing PR template is the primary contributor-review surface; smallest change with highest coverage | Add separate contributor doc surface or automation |
| Keep wording scoped to user-facing command-mode behavior/ordering changes only | Prevent checklist noise for internal-only changes | Broad “always update docs” guidance |

### Files modified (workflow drift guardrail pass)
- `.github/pull_request_template.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (workflow drift guardrail pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (host interaction policy pass)
- Add bounded host-interaction policy controls for generated `sandbox.wsb`:
  - `-DisableClipboard`
  - `-DisableAudioInput` (explicit idempotent request; default already disabled)
  - `-DisableStartupCommands`
- Centralize effective host-interaction policy state and wire it through run/validate/dry-run/audit generation paths.
- Extend audit and JSON projections additively to expose configured/requested policy state with trust-boundary wording.

### Decisions made (host interaction policy pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Introduce `Get-SandboxHostInteractionPolicy` as one authoritative policy seam | Prevent drift across CLI/session/WSB rendering/validation/audit/output surfaces | Scatter independent booleans across command handlers and renderers |
| Keep audio input default disabled and treat `-DisableAudioInput` as explicit/idempotent | Preserve existing behavior while still giving users an explicit safety control | Change defaults or add broader audio-policy redesign |
| Implement startup suppression as conditional `LogonCommand` emission with validation warning | Bounded and honest control over existing autostart injection concept | Broader startup-policy abstractions or runtime claims |

### Files modified (host interaction policy pass)
- `Start-Sandbox.ps1`
- `src/SandboxConfig.ps1`
- `src/Session.ps1`
- `src/Cli.ps1`
- `src/Validation.ps1`
- `src/Audit.ps1`
- `src/Output.ps1`
- `tests/Cli.Tests.ps1`
- `tests/Validation.Tests.ps1`
- `tests/Session.Tests.ps1`
- `tests/Audit.Tests.ps1`
- `tests/Output.Tests.ps1`
- `tests/StartSandboxJson.Tests.ps1`
- `tests/StartSandboxAudit.Tests.ps1`
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (host interaction policy pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (fresh/warm lifecycle + WSL helper sidecar pass)
- Add bounded session lifecycle selection (`Fresh` default, opt-in `Warm`) with deterministic support handling.
- Add bounded optional WSL helper sidecar (`-UseWslHelper`, distro/stage-path options) for helper staging/metadata only.
- Extend validate/dry-run/audit and JSON surfaces additively with lifecycle/helper state.
- Preserve explicit trust boundaries: WSL helper convenience layer vs Windows Sandbox execution boundary.

### Decisions made (fresh/warm + WSL helper pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `src/Workflow.ps1` as centralized lifecycle/helper state and execution seam | Keep launch backend, helper state, and command execution wrappers testable and non-duplicated | Scatter warm/helper booleans and shell invocations across `Start-Sandbox.ps1` |
| Keep `Fresh` as default and require explicit opt-in for `Warm` (`-SessionMode Warm`) | Preserve cleanliness-first default posture | Auto-select warm behavior |
| Gate warm mode on detected Windows Sandbox CLI (`wsb`) support and fail deterministically when unsupported | Avoid pretending warm reuse exists on unsupported hosts | Silent fallback to fresh when warm is explicitly requested |
| Keep WSL helper bounded to optional staging/metadata tasks (no direct distro mutation) | Maintain scope discipline and avoid invasive host-side changes | Automatic in-place edits to live `/etc/wsl.conf` |
| Validate/audit helper hardening as configured/requested evidence only | Prevent overclaiming runtime enforcement | Treat helper config checks as runtime proof |

### External references consulted
- Microsoft Learn: Windows Sandbox CLI (`windows-sandbox-cli`) — command surface and Windows 11 24H2 availability note.
- Microsoft Learn: Windows Sandbox `.wsb` configuration (`windows-sandbox-configure-using-wsb-file`) — supported config schema.
- Microsoft Learn: WSL advanced settings (`wsl-config`) — supported `wsl.conf` sections/keys (`automount`, `interop`, `appendWindowsPath`).

### Files modified (fresh/warm + WSL helper pass)
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Validation.ps1`
- `src/Audit.ps1`
- `src/Output.ps1`
- `src/Workflow.ps1` (new)
- `tests/Cli.Tests.ps1`
- `tests/Validation.Tests.ps1`
- `tests/Output.Tests.ps1`
- `tests/Audit.Tests.ps1`
- `tests/Workflow.Tests.ps1` (new)
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Deferred items
- Direct mutation of existing WSL distro `/etc/wsl.conf` was deferred to avoid surprising/invasive host changes in this pass.
- Warm-mode compatibility checks are intentionally bounded to host CLI support + running-session discoverability; deep runtime compatibility probing is deferred.

### Validation (fresh/warm + WSL helper pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (warm-session parser hardening pass)
- Harden `wsb list --raw` warm-session discovery with one authoritative normalization seam.
- Keep warm/fresh semantics unchanged while making malformed/unsupported raw output handling deterministic.
- Add parser fixtures and focused tests for supported/empty/malformed/missing-field cases.

### Decisions made (warm-session parser hardening pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add `ConvertFrom-SandboxWsbRawSessionList` in `src/Workflow.ps1` and route discovery through it | Single normalization seam prevents ad hoc raw parsing drift | Keep inline parsing in `Get-SandboxWarmSessionInventory` |
| Treat `id` and `status` as required normalized fields | Warm reuse logic needs deterministic identity and running-state evaluation | Tolerate missing status and silently skip records |
| Fail on unsupported JSON shape and malformed JSON with explicit errors | Warm mode must be honest/deterministic on unsupported CLI output | Silent fallback to empty inventory for all parse issues |

### Files modified (warm-session parser hardening pass)
- `src/Workflow.ps1`
- `tests/Workflow.Tests.ps1`
- `tests/Validation.Tests.ps1`
- `tests/fixtures/wsb-list-raw.array.json` (new)
- `tests/fixtures/wsb-list-raw.sessions.json` (new)
- `tests/fixtures/wsb-list-raw.missing-id.json` (new)
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (warm-session parser hardening pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (warm-session parser contract docs pass)
- Add a compact maintainer-facing parser contract note for accepted `wsb list --raw` shapes and normalization mapping.
- Keep this pass documentation-only with no runtime/parser behavior changes.

### Decisions made (warm-session parser contract docs pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Make README the authoritative home for raw-shape parser contract details | README already hosts warm-mode lifecycle behavior and trust-boundary statements | Duplicate full parser contract details in QUICKSTART |
| Add only a short QUICKSTART cross-reference to README section | Preserve discoverability without doc duplication drift | Repeat full shape/field table in QUICKSTART |

### Files modified (warm-session parser contract docs pass)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (warm-session parser contract docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (contributor guardrail for warm raw shape drift)
- Add one narrow PR-template checklist guardrail for future additions of accepted `wsb list --raw` envelope shapes.

### Decisions made (contributor guardrail for warm raw shape drift)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Update existing `.github/pull_request_template.md` instead of adding a new contributor doc surface | Repo already uses PR template as primary review gate; smallest change with least drift risk | Introduce new `CONTRIBUTING.md` only for this note |
| Keep wording shape-scoped (fixtures + tests + README warm parser contract) | Prevent broad/noisy checklist impact on unrelated parser/workflow changes | Generic parser checklist that over-applies to all workflow changes |

### Files modified (contributor guardrail for warm raw shape drift)
- `.github/pull_request_template.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (contributor guardrail for warm raw shape drift)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (non-invasive WSL helper hardening guidance pass)
- Add one tracked sample `wsl.conf` for dedicated helper-distro use.
- Keep runtime behavior unchanged; clarify manual helper hardening workflow and boundaries in docs.
- Add focused guard test to keep sample aligned with helper hardening detection expectations.

### Decisions made (non-invasive WSL helper hardening guidance pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add single authoritative sample at repo root: `wsl-helper.example.wsl.conf` | Matches existing tracked-example pattern (`custom-profiles.example.json`) and keeps copy/review workflow obvious | Introduce a new examples directory pattern for one file |
| Keep sample minimal to `automount` + `interop` keys only | These are already consumed by current helper hardening checks and are directly relevant to helper-side risk reduction | Add broader WSL tuning knobs outside current helper detection scope |
| Keep toolkit non-invasive (no `/etc/wsl.conf` mutation/restart automation) and document manual per-distro application | Avoid surprising host/distro changes and preserve explicit trust-boundary wording | Add automatic `sudo tee /etc/wsl.conf` or distro restart behavior |

### External references consulted
- Microsoft Learn: WSL advanced settings (`wsl-config`) — confirms `/etc/wsl.conf` is per distro and documents supported `automount.enabled`, `interop.enabled`, and `interop.appendWindowsPath` keys.

### Files modified (non-invasive WSL helper hardening guidance pass)
- `wsl-helper.example.wsl.conf` (new)
- `tests/Validation.Tests.ps1`
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (non-invasive WSL helper hardening guidance pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (WSL helper troubleshooting docs pass)
- Add a compact troubleshooting note for helper hardening confusion after manual `wsl.conf` edits.
- Keep this pass documentation-only with no runtime/validation behavior changes.

### Decisions made (WSL helper troubleshooting docs pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add troubleshooting bullets inline in existing WSL helper sections of README/QUICKSTART | Smallest authoritative surface with lowest doc drift risk | Create separate troubleshooting doc section/file |
| Focus only on two symptoms (`/mnt/*` still mounted, interop still enabled) | Matches highest-friction post-edit confusion and requested bounded scope | Broaden into general WSL FAQ |
| Use Microsoft-documented restart semantics (`wsl --list --running`, `wsl --terminate <distro>`, optional `wsl --shutdown`) | Grounds remediation in official behavior and avoids ambiguous “restart” wording | Generic “close and reopen shell” guidance only |

### External references consulted
- Microsoft Learn: WSL advanced settings (`wsl-config`) — confirms `wsl.conf` is per-distro and that config changes require fully stopping/restarting distro instances; documents `wsl --terminate <distro>` and `wsl --shutdown` behavior.

### Files modified (WSL helper troubleshooting docs pass)
- `README.md`
- `docs/QUICKSTART.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (WSL helper troubleshooting docs pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (WSL helper troubleshooting discoverability pass)
- Add a concise cross-link from primary troubleshooting docs to existing WSL helper troubleshooting guidance.
- Keep this pass documentation-only with no CLI/runtime/validation behavior changes.

### Decisions made (WSL helper troubleshooting discoverability pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add one navigational note to `docs/TROUBLESHOOTING.md` and link to existing README/QUICKSTART WSL helper sections | `docs/TROUBLESHOOTING.md` is the repo's broad troubleshooting entry point; this closes discoverability gap without duplication | Copy full symptom/cause/fix bullets into `docs/TROUBLESHOOTING.md` |
| Keep wording trust-boundary explicit and reuse existing validation command | Preserve current conservative security posture and operational flow | Add new helper checks or restart automation guidance |

### Files modified (WSL helper troubleshooting discoverability pass)
- `docs/TROUBLESHOOTING.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (WSL helper troubleshooting discoverability pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-14 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-14 |

### Scope (release hardening pass: integration characterization)
- Add bounded Start-Sandbox integration coverage for CLI/config feature combinations:
  - `-DryRun` with built-in/custom profiles and runtime add/remove overrides.
  - `-Validate` with built-in/custom profiles and invalid profile/tool/custom-config inputs.
  - invalid parameter-combination and unsafe shared-folder failures.
  - `-ListTools` / `-ListProfiles` state reflection.
  - `-CleanDownloads` cleanup scope boundaries.

### Decisions made (release hardening pass: integration characterization)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add one new end-to-end Pester suite that invokes `Start-Sandbox.ps1` directly | Verifies integrated command surfaces and precedence using real script entrypoint behavior | Add only more unit tests around helper functions |
| Prefer JSON-mode assertions for validate/dry-run/list checks | Reduces fragility while still validating user-facing semantics | Match full human-readable output text |
| Keep cleanup-scope check bounded with a disposable sentinel file | Proves non-cache surfaces are not mutated without broad filesystem side effects | Attempt broad recursive host-state assertions |

### Files modified (release hardening pass: integration characterization)
- `tests/StartSandboxCliIntegration.Tests.ps1` (new)
- `IMPLEMENTATION_TRACKER.md`

### Validation (release hardening pass: integration characterization)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (new integration suite) | ✅ | `Invoke-Pester -Path tests/StartSandboxCliIntegration.Tests.ps1` | 2026-03-15 |

### Scope (release hardening pass: integrated flow fixes)
- Harden integrated CLI/config behavior with bounded fixes:
  - preserve tracked `scripts/setups/.gitkeep` during `-CleanDownloads`.
  - normalize user-facing error categories (`Unknown profile`, `Unknown tool id`, malformed custom profile parsing/shape).
  - standardize invalid parameter-combination phrasing with a shared prefix.
  - normalize JSON fatal error `command.mode` names to match successful mode contracts (`dry-run`, `list-profiles`, etc.).

### Decisions made (release hardening pass: integrated flow fixes)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Treat `scripts/setups/.gitkeep` as a tracked placeholder to skip during cleanup | Prevents release prep/working tree drift from maintenance mode while preserving cache cleanup behavior | Keep deleting all setup-cache children including tracked placeholders |
| Keep error standardization bounded to existing failure seams (manifest/session/CLI validation) | Improves consistency without redesigning command behavior | Broad exception-wrapper refactor across all modules |
| Map JSON error mode names to public contract mode strings | Removes mode-name drift between successful and fatal JSON responses | Keep internal enum names (`DryRun`, `List`) in error payloads |

### Files modified (release hardening pass: integrated flow fixes)
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Maintenance.ps1`
- `src/Manifest.ps1`
- `src/Output.ps1`
- `src/Session.ps1`
- `tests/Maintenance.Tests.ps1`
- `tests/Session.Tests.ps1`
- `tests/StartSandboxCliIntegration.Tests.ps1`
- `tests/StartSandboxJson.Tests.ps1`
- `tests/Validation.Tests.ps1`
- `IMPLEMENTATION_TRACKER.md`

### Validation (release hardening pass: integrated flow fixes)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (targeted integration + affected suites) | ✅ | `Invoke-Pester -Path tests/Maintenance.Tests.ps1,tests/Session.Tests.ps1,tests/Validation.Tests.ps1,tests/StartSandboxJson.Tests.ps1,tests/StartSandboxCliIntegration.Tests.ps1,tests/Cli.Tests.ps1,tests/StartSandboxAudit.Tests.ps1` | 2026-03-15 |

### Scope (release hardening pass: CI/docs/release prep)
- Add CI coverage for release readiness:
  - Pester job on Windows.
  - deterministic CLI smoke matrix for list/validate/dry-run/custom-profile/cleanup seams.
- Align docs/help with confirmed behavior:
  - explicit release "What changed" summary.
  - precedence and exit-code semantics.
  - updated help links/examples for custom-profile validation context.
- Record release notes in changelog.

### Decisions made (release hardening pass: CI/docs/release prep)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add both Pester and direct CLI smoke jobs in CI | Combines broad regression detection with realistic command-surface checks | Add only one of test or smoke jobs |
| Keep smoke commands non-destructive/deterministic (`-SkipPrereqCheck`, JSON seams, bounded cleanup) | Avoid flaky host-dependent sandbox execution in CI while still covering integrated command paths | Attempt real Windows Sandbox launch behavior in CI |
| Document exit-code semantics centrally in README/QUICKSTART | Makes automation/release expectations explicit and consistent with implemented behavior | Leave behavior implicit in tests only |

### Files modified (release hardening pass: CI/docs/release prep)
- `.github/workflows/validate.yml`
- `Start-Sandbox.ps1`
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (release hardening pass: CI/docs/release prep)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

### Scope (release contract follow-up pass)
- Add lightweight CI assertion for documented exit-code contract examples using a table-driven case list.
- Add a compact JSON error-envelope contract test for fatal failures across JSON-capable command modes.

### Decisions made (release contract follow-up pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Implement exit-code contract checks as a single table-driven workflow step | Keeps CI logic concise while covering multiple documented examples | Add one CI job per command example |
| Add JSON error-envelope contract assertions in Pester integration tests | Keeps envelope schema checks close to command behavior and reusable under existing CI Pester job | Add a separate external schema-validation script only in CI |
| Use deterministic fatal triggers per mode (unknown tool, malformed custom profile, malformed manifest) | Avoids flaky host/environment dependencies while exercising real error paths | Trigger runtime/environment-specific failures |

### Files modified (release contract follow-up pass)
- `.github/workflows/validate.yml`
- `tests/StartSandboxJson.Tests.ps1`
- `IMPLEMENTATION_TRACKER.md`

### Validation (release contract follow-up pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (JSON contract suite) | ✅ | `Invoke-Pester -Path tests/StartSandboxJson.Tests.ps1` | 2026-03-15 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

### Scope (release cut pass: v2.0.5)
- Finalize release-hardening additions for this cycle and cut an actual release for CLI/config features.
- Include explicit CI exit-code contract assertions and JSON error-envelope contract checks in the release notes.
- Execute release actions: release prep commit, annotated tag, remote push, and GitHub release object (if available).

### Decisions made (release cut pass: v2.0.5)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Keep release version at `2.0.5` | Existing docs/changelog already consolidate this CLI/config feature cycle under `2.0.5`; no prior tags/releases exist to contradict this cut | Introduce `2.0.6` solely for final release execution mechanics |
| Use tag format `v2.0.5` | Matches conservative/common semver tag style and requested example format | Untagged changelog-only release |
| Create GitHub release object via `gh` after successful push | Remote is reachable and `gh` is authenticated/configured in this environment | Defer to manual release object creation |

### Files modified (release cut pass: v2.0.5)
- `.github/workflows/validate.yml`
- `tests/StartSandboxJson.Tests.ps1`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Scope (saved template/session workflow pass)
- Add a bounded saved-template persistence layer for repeat sandbox invocations.
- Add CLI surfaces for save/list/show/use-template while preserving existing run/validate/dry-run/audit execution seams.
- Keep effective-selection precedence deterministic across template defaults, profile/custom-profile resolution, and runtime overrides.

### Decisions made (saved template/session workflow pass)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Use repo-local `saved-sessions.local.json` store instead of a template-per-file directory | Aligns with existing repo-local config pattern (`custom-profiles.local.json`) and keeps implementation/review scope small | Create a new templates directory with one file per entry |
| Add `src/Templates.ps1` as a dedicated persistence/validation/resolution seam | Prevents template logic from leaking into command handlers and keeps behavior testable | Inline template read/merge logic in `Start-Sandbox.ps1` |
| Extend `Resolve-SandboxSessionSelection` with optional template add/remove layers | Reuses authoritative selection path and preserves dry-run/validate/audit parity | Build a separate template execution selection path |
| Revalidate template references at both save time and execution time | Prevents stale or malformed templates from bypassing current manifest/profile/path checks | Validate only when saving templates |

### Files modified (saved template/session workflow pass)
- `.gitignore`
- `Start-Sandbox.ps1`
- `src/Cli.ps1`
- `src/Session.ps1`
- `src/Templates.ps1` (new)
- `src/Validation.ps1`
- `tests/Cli.Tests.ps1`
- `tests/Session.Tests.ps1`
- `tests/Templates.Tests.ps1` (new)
- `tests/StartSandboxCliIntegration.Tests.ps1`
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (saved template/session workflow pass)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (targeted affected suites) | ✅ | `Invoke-Pester -Path tests/Cli.Tests.ps1,tests/Session.Tests.ps1,tests/Templates.Tests.ps1,tests/Validation.Tests.ps1,tests/StartSandboxJson.Tests.ps1,tests/StartSandboxCliIntegration.Tests.ps1` | 2026-03-15 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |

### Scope (release hardening pass: integrated CLI/config coherence)
- Re-characterize integrated non-destructive command surfaces for release confidence (`-DryRun`, `-Validate`, list modes, cleanup scope).
- Tighten remaining parameter-combination drift in list mode.
- Expand deterministic CI smoke coverage and align release-facing docs/changelog for tag readiness.

### Decisions made (release hardening pass: integrated CLI/config coherence)
| Decision | Reason | Alternative considered |
|----------|--------|----------------------|
| Add a dedicated release-hardening integration characterization suite | Keeps required combinations explicit and reviewable without coupling to existing broad suites | Continue relying only on previously accumulated integration tests |
| Reject `-NoLaunch` / `-SkipPrereqCheck` in list mode | Aligns list-mode contract with other irrelevant-switch rejections and removes ambiguous no-op flags | Continue accepting irrelevant list-mode switches silently |
| Expand CI smoke matrix only with deterministic dry-run/validate seams | Increases confidence without introducing environment-dependent launch flakiness | Add real sandbox-launch checks in CI |

### Files modified (release hardening pass: integrated CLI/config coherence)
- `tests/StartSandboxReleaseHardening.Tests.ps1` (new)
- `src/Cli.ps1`
- `tests/Cli.Tests.ps1`
- `.github/workflows/validate.yml`
- `README.md`
- `docs/QUICKSTART.md`
- `CHANGELOG.md`
- `IMPLEMENTATION_TRACKER.md`

### Validation (release hardening pass: integrated CLI/config coherence)
| Check | Result | Method | Date |
|-------|--------|--------|------|
| Pester tests (new hardening suite) | ✅ | `Invoke-Pester -Path tests/StartSandboxReleaseHardening.Tests.ps1` | 2026-03-15 |
| Pester tests (CLI + hardening suite) | ✅ | `Invoke-Pester -Path tests/Cli.Tests.ps1,tests/StartSandboxReleaseHardening.Tests.ps1` | 2026-03-15 |
| Pester tests (full suite) | ✅ | `Invoke-Pester -Path tests` | 2026-03-15 |
| PSScriptAnalyzer lint | ✅ | `Get-ChildItem -Recurse -Filter '*.ps1' \| ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }` | 2026-03-15 |
