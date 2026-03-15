# REPO_MAP.md — Repository Map for sandbox-toolkit

**Last updated:** 2026-03-14
**Based on:** Discovery run / manual inspection

---

## Repository overview

`sandbox-toolkit` is a manifest-driven toolkit for launching a Windows Sandbox configured for defensive malware analysis and reverse engineering. It provides PowerShell orchestration to download and install a curated set of tools into a disposable sandbox, with selectable profiles controlling networking and installed components.

---

## Top-level structure

```
.
├── .github/                   # CI workflows
├── artifacts/                 # Generated artifacts (discovery output, etc.)
├── bootstrap/                 # Bootstrap/implementation metadata
├── docs/                      # Documentation, including AI agent docs
├── schemas/                   # JSON schemas (tool manifest validation)
├── scripts/                   # Sandbox startup & installer orchestration
├── src/                       # Core PowerShell modules for manifest, download, config
├── tests/                     # Pester test suite
├── AGENTS.md                  # Agent execution contract (template)
├── CHANGELOG.md              # Change log
├── IMPLEMENTATION_TRACKER.md  # Live state tracker (template)
├── PROFILES.md               # Profile documentation
├── QUICKSTART.md             # Getting started guide
├── README.md                 # Project overview and usage
├── SAFETY.md                 # Safety guidance for sandbox use
├── TROUBLESHOOTING.md        # Troubleshooting guidance
├── tools.json                # Tool manifest (installer definitions)
├── sandbox.wsb.template      # Windows Sandbox template reference
└── Start-Sandbox.ps1         # Primary script / main entry point
```

---

## Directory purposes

| Path | Purpose |
|------|---------|
| `.github/` | GitHub Actions workflows for linting and manifest validation |
| `artifacts/` | Generated artifacts for AI/automation (repo discovery output) |
| `bootstrap/` | Bootstrap implementation metadata and source tracking |
| `docs/` | Documentation, including AI agent operating docs |
| `schemas/` | JSON schema definitions for tool manifest validation |
| `scripts/` | In-sandbox install orchestration and autostart launcher |
| `src/` | Core PowerShell modules used by `Start-Sandbox.ps1` |
| `tests/` | Pester unit tests and validation scripts |

---

## Key files

| File | Purpose |
|------|---------|
| `Start-Sandbox.ps1` | Primary user-facing entry point to configure and launch the sandbox |
| `tools.json` | Declarative manifest of tools to install, versions, and install actions |
| `.github/workflows/validate.yml` | CI workflow that lints PowerShell and validates the manifest |

---

## Entry points

| Type | Path | Notes |
|------|------|-------|
| Application entry | `Start-Sandbox.ps1` | Runs on the host to prepare and launch Windows Sandbox |
| Sandbox install runner | `scripts/Install-Tools.ps1` | Runs inside sandbox via `autostart.cmd` to install tools |
| CI / validation | `.github/workflows/validate.yml` | Runs PSScriptAnalyzer and manifest schema checks |

---

## Test structure

- **Test directory:** `tests`
- **Test framework:** Pester (PowerShell)
- **Run command:** `Invoke-Pester -Path tests`
- **Test types present:** unit-style validation tests (shared folder validation)

---

## Configuration files

| File | Purpose | Format |
|------|---------|--------|
| `tools.json` | Tool manifest defining downloads, installs, and profiles | JSON |
| `schemas/tools.schema.json` | JSON Schema used to validate `tools.json` | JSON |

---

## CI/CD

- **CI provider:** GitHub Actions
- **Config location:** `.github/workflows/validate.yml`
- **Key pipelines/workflows:** `Validate` (PSScriptAnalyzer lint + tools manifest validation)

---

## Known complexity areas

- The `tools.json` manifest drives the entire tool installation behavior; changes must be validated with the CI schema check.
- Shared folder validation (`src/SharedFolderValidation.ps1`) contains detailed path policy logic to avoid unsafe host mappings.

---

## Staleness indicators

This map may be out of date if:
- New top-level directories were added.
- The build system or test framework changed.
- The entry point changed.
- More than 30 days have passed since `2026-03-14`.

When stale, re-run the discovery prompt to regenerate.
