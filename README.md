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

### Discoverability and dry-run

```powershell
# Show built-in profiles/tools from current tools.json
.\Start-Sandbox.ps1 -ListProfiles
.\Start-Sandbox.ps1 -ListTools

# Simulate profile selection + config generation without downloading or launching
.\Start-Sandbox.ps1 -DryRun -Profile network-analysis -SkipPrereqCheck
```

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
