# Windows Sandbox Toolkit

A manifest-driven, profile-aware Windows Sandbox environment for **defensive malware analysis and reverse engineering**.

> **Safety first.** Networking is disabled by default. The sandbox is disposable by design.
> See [SAFETY.md](docs/SAFETY.md) before enabling networking or mapping additional host folders.

---

## Standalone project

This repository is maintained as a standalone project under `incredincomp/sandbox-toolkit`.
It is manifest-driven (`tools.json`), profile-aware (`minimal`, `reverse-engineering`, `network-analysis`, `full`), and built for defensive malware analysis, reverse engineering, and sample triage.
The default posture is safer-by-default: disposable sandbox sessions, read-only mapped scripts, and networking disabled unless a networked profile is explicitly selected.

---

## Opt-in shared folder workflow

Use this when you need to transfer files from host to sandbox for triage.

- Opt-in only: no extra folder is mapped unless you pass `-UseDefaultSharedFolder` or `-SharedFolder`.
- Default access is read-only (safer).
- Writable mapping requires explicit `-SharedFolderWritable` plus one shared-folder selection switch.
- In-sandbox destination is fixed: `C:\Users\WDAGUtilityAccount\Desktop\shared`.
- Reparse-point/junction-backed targets are rejected, and paths that traverse reparse/junction parent ancestry are also rejected.

```powershell
.\Start-Sandbox.ps1 -UseDefaultSharedFolder
.\Start-Sandbox.ps1 -SharedFolder "C:\Lab\Ingress"
.\Start-Sandbox.ps1 -SharedFolder "C:\Lab\Ingress" -SharedFolderWritable
```

The default shared folder is repo-local `shared/` (auto-created, gitignored).
Do not map broad/sensitive host paths such as repo root, `C:\`, `%WINDIR%`, Program Files roots, `%USERPROFILE%`, Desktop, Documents, or Downloads.
Some synced/managed host locations (for example OneDrive-backed or redirected folders) may be rejected if their path chain uses reparse points/junctions. This also applies to `-UseDefaultSharedFolder` when the repo itself is under such a path. Prefer a plain local, non-synced ingress folder.

Clipboard paste and drag/drop support can vary by environment and policy. Treat the mapped shared folder as the primary transfer path.
For supportability, you can add `-SharedFolderValidationDiagnostics` to print ancestry segments checked during shared-folder validation.

---

## Quick start

```powershell
# 1. Clone the repo
git clone https://github.com/incredincomp/sandbox-toolkit.git
cd sandbox-toolkit

# 2. Run the setup (default profile: reverse-engineering)
.\Start-Sandbox.ps1

# 3. Windows Sandbox opens and installs all tools automatically
```

See [QUICKSTART.md](docs/QUICKSTART.md) for a step-by-step guide including prerequisites.

### Recommended workflow

Use this sequence for the safest host-side workflow:

1. Discover available profiles and tools.
   ```powershell
   .\Start-Sandbox.ps1 -ListProfiles
   .\Start-Sandbox.ps1 -ListTools
   ```
2. If you need a custom profile, start from the tracked example and edit locally.
   ```powershell
   Copy-Item .\custom-profiles.example.json .\custom-profiles.local.json
   ```
3. Confirm your custom profile is discoverable.
   ```powershell
   .\Start-Sandbox.ps1 -ListProfiles
   ```
4. Run preflight readiness checks (`-Validate` = input/host readiness; no artifact generation or launch).
   ```powershell
   .\Start-Sandbox.ps1 -Validate -Profile net-re-lite
   ```
5. Run generation preview (`-DryRun` = effective selection + generated artifacts; no download or launch).
   ```powershell
   .\Start-Sandbox.ps1 -DryRun -Profile net-re-lite
   ```
6. Run host-side sanity audit (`-Audit` = configured/requested artifact evidence and trust signals; not runtime enforcement proof).
   ```powershell
   .\Start-Sandbox.ps1 -Audit -Profile net-re-lite
   ```
7. Execute the actual sandbox run.
   ```powershell
   .\Start-Sandbox.ps1 -Profile net-re-lite
   ```

Automation note: use `-OutputJson` with `-Validate`, `-DryRun`, or `-Audit` in CI/wrappers.

### Discoverability and dry-run

```powershell
# Show built-in profiles/tools from current tools.json
.\Start-Sandbox.ps1 -ListProfiles
.\Start-Sandbox.ps1 -ListTools

# Simulate profile selection + config generation without downloading or launching
.\Start-Sandbox.ps1 -DryRun -Profile network-analysis -SkipPrereqCheck

# Audit generated artifacts and configured/requested settings without launching
.\Start-Sandbox.ps1 -Audit -Profile minimal -SharedFolder "C:\Lab\Ingress"

# Remove repo-owned disposable download/session artifacts
.\Start-Sandbox.ps1 -CleanDownloads
```

`-CleanDownloads` removes only toolkit-owned disposable artifacts:
- cached setup payloads under `scripts/setups/`
- generated `scripts/install-manifest.json`
- generated `sandbox.wsb`

`-CleanDownloads` does not remove:
- `tools.json`, custom profiles, docs/tests, or source files
- optional shared folder content
- any paths outside the repository-owned locations above

If nothing exists yet, cleanup succeeds and reports "Nothing to clean."

### Validate readiness (non-destructive)

```powershell
# Preflight checks only (no downloads, no .wsb/install-manifest generation, no launch)
.\Start-Sandbox.ps1 -Validate

# Validate a specific profile and shared-folder input
.\Start-Sandbox.ps1 -Validate -Profile network-analysis -SharedFolder "C:\Lab\Ingress"
```

`-Validate` checks:
- CLI compatibility for the current invocation.
- Manifest/profile/tool-selection readiness.
- Shared-folder safety using the same hardened path rules.
- Host prerequisite checks (PowerShell version, Windows Sandbox feature state when detectable).

`-Validate` does not check:
- In-sandbox runtime behavior (installer success, clipboard/audio policy behavior, sample behavior).
- Download/source availability.
- Generated artifact contents (use `-DryRun` for generation-preview workflows).

Exit behavior:
- `0`: validation passed (warnings may still be present).
- `1`: one or more validation checks failed.

### Audit generated configuration (non-destructive)

```powershell
# Generate artifacts and audit host-visible/config-visible evidence (no downloads, no launch)
.\Start-Sandbox.ps1 -Audit
.\Start-Sandbox.ps1 -Audit -Profile reverse-engineering
.\Start-Sandbox.ps1 -Audit -Profile minimal -SharedFolder "C:\Lab\Ingress"
.\Start-Sandbox.ps1 -Audit -OutputJson
```

`-Audit` checks:
- Effective request context (selected/base profile, effective tools, requested networking mode).
- Generated artifact presence and parseability (`scripts/install-manifest.json`, `sandbox.wsb`).
- Requested vs generated `sandbox.wsb` settings (networking, logon command, mapped folder/read-only state).
- Shared-folder mapping intent versus generated mapping.

`-Audit` does not prove runtime enforcement:
- Checks are host-side/config-side evidence only.
- Findings are reported as configured/requested and present in generated artifacts.
- Runtime sandbox behavior is not verified unless explicitly stated.

### Machine-readable JSON output

Use `-OutputJson` with `-Validate`, `-Audit`, `-DryRun`, `-ListTools`, or `-ListProfiles` to emit JSON to stdout for CI/automation.
Human-readable console output remains the default.

```powershell
.\Start-Sandbox.ps1 -Validate -OutputJson
.\Start-Sandbox.ps1 -Validate -Profile net-re-lite -OutputJson
.\Start-Sandbox.ps1 -Audit -Profile minimal -OutputJson
.\Start-Sandbox.ps1 -DryRun -Profile net-re-lite -AddTools floss -OutputJson
.\Start-Sandbox.ps1 -ListTools -OutputJson
.\Start-Sandbox.ps1 -ListProfiles -OutputJson
```

Supported modes:
- `-Validate -OutputJson`
- `-Audit -OutputJson`
- `-DryRun -OutputJson`
- `-ListTools -OutputJson`
- `-ListProfiles -OutputJson`

Intentional exclusions:
- `-OutputJson` is not enabled for normal launch mode.

JSON stability notes:
- Validate JSON includes stable `checks[]` records (`id`, `status`, `summary`, `remediation`) plus overall status and `exit_code`.
- Audit JSON includes effective request context, generated artifact paths, and audit checks over configured/requested artifact evidence.
- Dry-run JSON includes profile resolution, runtime overrides, final effective tool list, effective networking, stage skip details, and generated artifact paths.
- List-tools JSON includes `command.mode` and `tools[]` with stable catalog fields (`id`, `display_name`, `installer_type`, `install_order`, `category`, `profiles`).
- List-profiles JSON includes `command.mode` and `profiles[]` with explicit `type` (`built-in` or `custom`) and `base_profile`.

### Audit JSON contract

Invoke with:

```powershell
.\Start-Sandbox.ps1 -Audit -OutputJson
```

Stable top-level fields (automation-safe):
- `command.mode` (`audit`)
- `overall_status` (`PASS`, `WARN`, `FAIL`)
- `exit_code` (`0` or `1`)
- `profile` (`selected`, `resolved_type`, `base_profile`)
- `overrides` (`add_tools`, `remove_tools`)
- `effective` (`networking_requested`, `tools[]`)
- `artifacts` (`install_manifest_path`, `wsb_path`)
- `checks[]` (required per-check fields: `id`, `status`, `summary`, `remediation`)
- `context` (`skip_prereq_check`, `requested_shared_folder`, `resolved_shared_folder`, `shared_folder_writable`, `runtime_verification`)

Trust-boundary semantics:
- Audit evidence is host-side/config-side and reflects configured/requested artifact state.
- `context.runtime_verification` is currently `not_performed`.
- Check summaries may include wording like `configured/requested` and `not runtime-verified`.

Stability guidance:
- Breaking changes: renaming/removing stable fields above, changing their object/array shape, or changing `exit_code`/`overall_status` semantics.
- Additive changes: adding new top-level fields, adding optional nested fields, adding new check IDs, and extending human-readable summary text.

Example payload:
<!-- audit-json-example:start -->
```json
{
  "command": {
    "mode": "audit"
  },
  "overall_status": "WARN",
  "exit_code": 0,
  "profile": {
    "selected": "minimal",
    "resolved_type": "built-in",
    "base_profile": "minimal"
  },
  "overrides": {
    "add_tools": [],
    "remove_tools": []
  },
  "effective": {
    "networking_requested": "Disable",
    "tools": [
      {
        "id": "vscode",
        "display_name": "Visual Studio Code",
        "installer_type": "exe",
        "install_order": 20
      }
    ]
  },
  "artifacts": {
    "install_manifest_path": "C:\\repo\\scripts\\install-manifest.json",
    "wsb_path": "C:\\repo\\sandbox.wsb"
  },
  "checks": [
    {
      "id": "wsb-networking",
      "status": "PASS",
      "summary": "Networking setting 'Disable' is present in generated artifact as requested (configured/requested, not runtime-verified).",
      "remediation": null
    }
  ],
  "context": {
    "skip_prereq_check": true,
    "requested_shared_folder": null,
    "resolved_shared_folder": null,
    "shared_folder_writable": false,
    "runtime_verification": "not_performed"
  }
}
```
<!-- audit-json-example:end -->

### Custom profiles and runtime overrides

User-defined profiles live in optional repo-local `custom-profiles.local.json`.

Start from the tracked example:

```powershell
Copy-Item .\custom-profiles.example.json .\custom-profiles.local.json
```

Example source: `custom-profiles.example.json`.

Supported custom-profile shape:
- Top-level `profiles` array is required when the file exists.
- Each profile entry requires:
  - `name` (non-empty, unique, must not conflict with built-in profile names)
  - `base_profile` (one of built-in profiles: `minimal`, `reverse-engineering`, `network-analysis`, `full`)
- Optional per-profile arrays:
  - `add_tools` (tool IDs to add)
  - `remove_tools` (tool IDs to remove)

```json
{
  "schema_version": "1.0",
  "profiles": [
    {
      "name": "net-re-lite",
      "base_profile": "reverse-engineering",
      "add_tools": ["wireshark"],
      "remove_tools": ["ghidra"]
    }
  ]
}
```

Common authoring mistakes:
- Unknown `base_profile` value.
- Unknown tool IDs in `add_tools` or `remove_tools`.
- Missing `profiles` property or malformed array/object shapes.
- Duplicate custom profile names or a custom `name` that matches a built-in profile.

The example is illustrative. Runtime validation (`Import-CustomProfileConfig` + `Test-CustomProfileConfigIntegrity`) remains the source of truth.

Custom profile troubleshooting:
- Symptom: `-ListProfiles` or `-Validate` fails after editing local custom profiles.
  Likely cause: malformed JSON or missing required top-level `profiles` property.
  Fix: start from `custom-profiles.example.json` again and reapply edits incrementally.
- Symptom: validation reports unknown `base_profile`.
  Likely cause: `base_profile` is not one of built-in profiles.
  Fix: use one of `minimal`, `reverse-engineering`, `network-analysis`, or `full`.
- Symptom: validation reports unknown tool IDs in `add_tools` / `remove_tools`.
  Likely cause: typo or unsupported tool ID.
  Fix: run `.\Start-Sandbox.ps1 -ListTools` and copy exact IDs.
- Symptom: validation reports duplicate or conflicting custom profile names.
  Likely cause: repeated `name` values or `name` matching a built-in profile.
  Fix: ensure each custom profile name is unique and not one of the built-in names.
- Symptom: profile does not appear in `-ListProfiles`.
  Likely cause: local file is malformed or not loaded from repo root.
  Fix: confirm file path/name is exactly `.\custom-profiles.local.json` and rerun `-ListProfiles` to surface load/validation errors.

Recommended authoring workflow:

```powershell
Copy-Item .\custom-profiles.example.json .\custom-profiles.local.json
.\Start-Sandbox.ps1 -ListProfiles
.\Start-Sandbox.ps1 -Validate -Profile net-re-lite
.\Start-Sandbox.ps1 -DryRun -Profile net-re-lite
```

Runtime override parameters:
- `-AddTools <id[]>`
- `-RemoveTools <id[]>`

Precedence rules:
1. Start with selected built-in profile, or custom profile `base_profile`.
2. Apply custom profile `add_tools`, then custom profile `remove_tools`.
3. Apply runtime `-AddTools`, then runtime `-RemoveTools`.
4. Final selection is deduplicated and ordered by manifest `install_order`.

Examples:

```powershell
# Built-in profile + add tools
.\Start-Sandbox.ps1 -Profile minimal -AddTools ghidra,wireshark

# Built-in profile + remove tools
.\Start-Sandbox.ps1 -Profile reverse-engineering -RemoveTools ghidra,hxd

# Custom profile run
.\Start-Sandbox.ps1 -Profile net-re-lite

# Custom profile validate
.\Start-Sandbox.ps1 -Validate -Profile net-re-lite

# Custom profile dry-run
.\Start-Sandbox.ps1 -DryRun -Profile net-re-lite -AddTools floss
```

---

## Profiles

| Profile | Networking | Tools |
|---|---|---|
| `minimal` | ❌ Disabled | VSCode, Notepad++, Python 3, Sysinternals |
| `reverse-engineering` *(default)* | ❌ Disabled | + Ghidra, x64dbg, dnSpyEx, DIE, UPX, PE-bear, pestudio, HxD, FLOSS |
| `network-analysis` | ✅ Enabled | + Wireshark, Npcap |
| `full` | ✅ Enabled | All tools |

```powershell
.\Start-Sandbox.ps1 -Profile minimal
.\Start-Sandbox.ps1 -Profile network-analysis
```

See [PROFILES.md](docs/PROFILES.md) for full details.

---

## Tools installed

| Tool | Category | Source | Notes |
|---|---|---|---|
| [7-Zip](https://www.7-zip.org/) | Utility | Vendor | Required; extracts all zip tools |
| [Visual Studio Code](https://code.visualstudio.com/) | Editor | Vendor | Latest stable |
| [Notepad++](https://notepad-plus-plus.org/) | Editor | GitHub | Latest stable |
| [Python 3](https://www.python.org/) | Runtime | Vendor | 3.13.2 |
| [Amazon Corretto JDK 21](https://aws.amazon.com/corretto/) | Runtime | Vendor | Required for Ghidra 11.x |
| [Visual C++ Redist x64](https://aka.ms/vs/17/release/vc_redist.x64.exe) | Runtime | Vendor | Required for PE-bear |
| [Sysinternals Suite](https://docs.microsoft.com/sysinternals/) | Sysanalysis | Vendor | Always latest |
| [Ghidra](https://ghidra-sre.org/) | Reversing | GitHub | Latest stable |
| [x64dbg](https://x64dbg.com/) | Reversing | SourceForge | Latest snapshot |
| [dnSpyEx](https://github.com/dnSpyEx/dnSpy) | Reversing | GitHub | Active fork of archived dnSpy |
| [Detect-It-Easy](https://github.com/horsicq/DIE-engine) | Reversing | GitHub | Latest stable |
| [UPX](https://upx.github.io/) | Reversing | GitHub | Latest stable |
| [PE-bear](https://github.com/hasherezade/pe-bear) | Reversing | GitHub | Latest stable |
| [pestudio](https://www.winitor.com/) | Reversing | Vendor | Latest |
| [HxD](https://mh-nexus.de/en/hxd/) | Reversing | Vendor | Latest |
| [FLARE FLOSS](https://github.com/mandiant/flare-floss) | Reversing | GitHub | Latest stable |
| [Wireshark](https://www.wireshark.org/) | Network | Vendor | network-analysis/full only |
| [Npcap](https://npcap.com/) | Network | Vendor | **Manual install** (no silent mode) |

### Removed tools in 2.0

| Tool | Reason |
|---|---|
| Python 2 | EOL since January 2020. |
| DosBox | Not relevant to malware analysis workflows. |
| Sublime Text | Redundant with VSCode and Notepad++. |
| AutoIT Extractor | Sourced from unverified GitLab CI artifact; no stable release. |
| dnSpy (original) | Archived by original author in 2022. Replaced by dnSpyEx. |

---

## Repository structure

```
sandbox-toolkit/
├── Start-Sandbox.ps1          # Main entry point — run this on the host
├── tools.json                 # Tool manifest: versions, URLs, profiles, install behavior
├── sandbox.wsb.template       # Reference template (actual .wsb is generated)
├── src/
│   ├── Manifest.ps1           # Manifest loading and profile filtering
│   ├── Download.ps1           # Download with retry and GitHub release resolution
│   └── SandboxConfig.ps1      # .wsb generation
├── scripts/
│   ├── autostart.cmd          # Thin launcher (runs on sandbox startup)
│   ├── Install-Tools.ps1      # In-sandbox install orchestrator
│   └── setups/                # Downloaded files (gitignored, populated at runtime)
├── shared/                    # Optional ingress folder (gitignored, created on demand)
├── schemas/
│   └── tools.schema.json      # JSON Schema for tools.json validation
├── .github/
│   └── workflows/
│       └── validate.yml       # CI: PSScriptAnalyzer + manifest validation
├── README.md
├── docs/
│   ├── QUICKSTART.md
│   ├── PROFILES.md
│   ├── TROUBLESHOOTING.md
│   └── SAFETY.md
└── CHANGELOG.md
```

---

## How it works

1. **`Start-Sandbox.ps1`** runs on your host:
   - Checks that Windows Sandbox is enabled.
   - Loads `tools.json` and filters tools to the selected profile.
   - Downloads missing tool installers to `scripts/setups/` (with retry).
   - Writes `scripts/install-manifest.json` (ephemeral session file).
   - Generates `sandbox.wsb` with profile-appropriate settings (networking, etc.).
   - Launches Windows Sandbox.

2. **`scripts/autostart.cmd`** runs automatically on sandbox startup, invoking
   **`scripts/Install-Tools.ps1`** (in-sandbox):
   - Reads `install-manifest.json` from the read-only mapped scripts folder.
   - Installs all tools in dependency order.
   - Writes a detailed log to `%USERPROFILE%\Desktop\install-log.txt`.

---

## Safety posture

- Networking is **disabled by default** (all profiles except `network-analysis` and `full`).
- The `scripts/` host folder is mapped **read-only**.
- An optional extra shared folder can be mapped at `Desktop\shared` (read-only by default).
- No samples from the host are auto-executed.
- The sandbox is fully disposable; nothing persists after it closes.

See [SAFETY.md](docs/SAFETY.md) for full safety guidance.

---

## Contributing

- Tool version bumps: edit `tools.json`. The CI validates the manifest on every push.
- New tools: add an entry following the schema in `schemas/tools.schema.json`.
- Profiles: update the `profiles` array on each relevant tool entry.

---

## License

See [LICENSE](LICENSE) if present, or check the repository root.
