# AGENTS.md — Execution Contract for sandbox-toolkit

This file is the operating contract for AI agents working in **this repository**.
Read it before taking any action. Deviate from it only with explicit justification recorded in `IMPLEMENTATION_TRACKER.md`.

---

## Repo mission

Provide a manifest-driven Windows Sandbox toolkit that automates downloading and installing a curated set of analysis tools into a disposable sandbox environment, with selectable profiles controlling networking and tool selection.

---

## Technology stack

- **Language(s):** PowerShell (primary), JSON, Markdown
- **Build system:** None (PowerShell scripts executed directly)
- **Package manager:** None (tools are downloaded directly via manifest)
- **Test framework:** Pester (PowerShell) + PSScriptAnalyzer linting
- **Runtime version:** Windows PowerShell 5.1+ (Windows 10/11)

---

## Scope of this repository

In scope:
- Scripts and modules used to generate and launch Windows Sandbox environments.
- Manifest-driven tool download and installation (tools.json, installer orchestration).
- Documentation, profiles, and safety guidance.
- CI validation (PowerShell linting, manifest schema checks).

Out of scope:
- The actual third-party tool installers and binaries downloaded at runtime.
- Malware samples, payload analysis, or reverse engineering work performed inside the sandbox.
- Infrastructure provisioning (cloud, Kubernetes, etc.).

---

## Authoritative files

These files define the state and rules of this repository:

| File | Role |
|------|------|
| `AGENTS.md` | This file — execution contract |
| `IMPLEMENTATION_TRACKER.md` | Live state, milestones, decisions |
| `tools.json` | Tool manifest defining downloads, versions, profiles |
| `.github/workflows/validate.yml` | CI validation workflow |

---

## Key commands

```powershell
# Run lint + manifest validation (same as CI)
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning }
python -c "import json, jsonschema, sys; ..." # see .github/workflows/validate.yml for full script

# Run tests
Invoke-Pester -Path tests

# Run locally
.\Start-Sandbox.ps1
```

---

## Forbidden actions

Do not:
- Modify files outside the declared milestone scope without recording the decision.
- Add or upgrade dependencies without recording the rationale in the tracker.
- Remove or rename authoritative files without updating all cross-references.
- Mark milestones complete without running validation.
- Invent repo history, architecture, or decisions not supported by evidence.
- Commit downloaded tool installers or other large binaries.
- Modify `tools.json` without ensuring CI validation passes.

---

## Change discipline

Before making any change:
1. Confirm the change is within the declared milestone scope.
2. Read the files you plan to modify.
3. Record significant decisions in `IMPLEMENTATION_TRACKER.md`.

After making any change:
1. Update `IMPLEMENTATION_TRACKER.md`.
2. Run the test suite for the affected area.
3. Confirm no unrelated tests were broken.

---

## Validation expectations

Every agent session must:
- Run the test suite (`Invoke-Pester -Path tests`) before declaring work complete.
- Run the lint checks (PSScriptAnalyzer) and resolve any new warnings.
- Confirm `IMPLEMENTATION_TRACKER.md` is updated.
- Note validation results in the tracker.

---

## How to handle uncertainty

1. Consult `IMPLEMENTATION_TRACKER.md` for prior decisions.
2. Consult `docs/ai/REPO_MAP.md` for structure guidance.
3. If still uncertain, record the uncertainty in the tracker rather than guessing.
4. Label recommendations as recommendations, not confirmed facts.

---

## Loop-breaking expectations

If you repeat the same failed approach more than twice:
1. Stop.
2. Choose a simpler path.
3. Record the loop-break decision in `IMPLEMENTATION_TRACKER.md`.

Prefer stable, working changes over clever ones.
