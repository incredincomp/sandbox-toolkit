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
