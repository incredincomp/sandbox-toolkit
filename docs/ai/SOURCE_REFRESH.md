# SOURCE_REFRESH.md — Agent Source Refresh Instructions for sandbox-toolkit

**Last updated:** 2026-03-14

This file tells an agent (or human) how to efficiently rebuild working knowledge of this repository from scratch, without relying on chat history.

---

## Read these files first (in order)

1. `AGENTS.md` — execution contract, scope, forbidden actions
2. `IMPLEMENTATION_TRACKER.md` — current phase, last milestone, next steps
3. `docs/ai/REPO_MAP.md` — repository structure map
4. `artifacts/ai/repo_discovery.json` — machine-readable discovery findings
5. `tools.json` — tool manifest driving downloads and install behavior

---

## How to build

This repository does not have a traditional build step. It is executed via PowerShell scripts.

```powershell
# Validate and lint (same as CI)
.
# (See .github/workflows/validate.yml for the exact commands run in CI)
```

---

## How to test

```powershell
# Run Pester tests
Invoke-Pester -Path tests

# Run PSScriptAnalyzer lint (same as CI)
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object {
  Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning
}
```

---

## How to run locally

```powershell
# Configure and launch Windows Sandbox (default profile: reverse-engineering)
.\.\Start-Sandbox.ps1
```

**Expected behavior:** Windows Sandbox launches and installs the selected toolset according to the chosen profile. The sandbox installs tools automatically and writes logs to the sandbox desktop.

---

## How to lint / format

```powershell
# Lint all PowerShell scripts using PSScriptAnalyzer
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object {
  Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning
}
```

---

## Detecting staleness

This source refresh document may be stale if:
- The CI workflow `.github/workflows/validate.yml` changes.
- New top-level directories are added.
- The entry point `Start-Sandbox.ps1` changes.
- The `IMPLEMENTATION_TRACKER.md` references files not mentioned here.

If any of these are true, re-run the discovery prompt to update this file.

---

## Key dependencies and integrations

| Dependency / Service | Role | Where configured |
|---------------------|------|-----------------|
| `tools.json` | Defines download sources and install instructions for all tools | `tools.json` |
| GitHub Actions | CI for linting and manifest validation | `.github/workflows/validate.yml` |

---

## Environment setup notes

- Requires Windows 10/11 with the Windows Sandbox feature enabled.
- No `.env` file is used; configuration is driven by `tools.json` and optional CLI parameters.
- CI relies on Python (for JSON Schema validation) and PowerShell modules (PSScriptAnalyzer).
