# Quick Start

## Prerequisites

1. **Windows 10/11 Pro, Enterprise, or Education** (Windows Sandbox is not available on Home editions).
2. **Virtualization enabled** in BIOS/UEFI.
3. **Windows Sandbox feature enabled**:
   ```powershell
   # Run as Administrator
   Enable-WindowsOptionalFeature -FeatureName Containers-DisposableClientVM -Online
   # Reboot when prompted
   ```
4. **PowerShell 5.1+** (included with Windows 10/11).
5. **Internet access** from the host (for initial downloads).

---

## Steps

### 1. Clone the repository

```powershell
git clone https://github.com/incredincomp/sandbox-toolkit.git
cd sandbox-toolkit
```

### 2. Run `Start-Sandbox.ps1`

Open **PowerShell** (no admin required) in the repo directory:

```powershell
.\Start-Sandbox.ps1
```

This will:
- ✅ Verify prerequisites
- ⬇️ Download all tools for the `reverse-engineering` profile (~600 MB first run)
- 🛠️ Generate `sandbox.wsb` with networking disabled
- 🚀 Launch Windows Sandbox

### 3. Wait for installation to complete

Inside the sandbox, a PowerShell window will open and install all tools automatically.
Progress is logged to `install-log.txt` on the sandbox Desktop.

**First run takes 5–10 minutes** depending on your system speed.

---

## Choosing a profile

```powershell
# Minimal — fastest, editors + Sysinternals only
.\Start-Sandbox.ps1 -Profile minimal

# Reverse engineering (default) — full RE toolkit, no network
.\Start-Sandbox.ps1 -Profile reverse-engineering

# Network analysis — RE toolkit + Wireshark, networking ENABLED
.\Start-Sandbox.ps1 -Profile network-analysis

# Full — everything
.\Start-Sandbox.ps1 -Profile full
```

See [PROFILES.md](PROFILES.md) for what each profile includes.

---

## Common options

```powershell
# Print discoverability lists from current manifest
.\Start-Sandbox.ps1 -ListProfiles
.\Start-Sandbox.ps1 -ListTools

# Validate host/input readiness without running setup
.\Start-Sandbox.ps1 -Validate
.\Start-Sandbox.ps1 -Validate -Profile network-analysis -SharedFolder "C:\Lab\Ingress"

# Simulate selection/config generation without downloading or launching
.\Start-Sandbox.ps1 -DryRun -Profile reverse-engineering -SkipPrereqCheck
.\Start-Sandbox.ps1 -DryRun -Profile net-re-lite -AddTools floss -OutputJson

# Runtime tool overrides
.\Start-Sandbox.ps1 -Profile minimal -AddTools ghidra,wireshark
.\Start-Sandbox.ps1 -Profile reverse-engineering -RemoveTools ghidra,hxd

# Machine-readable output for CI/automation
.\Start-Sandbox.ps1 -Validate -OutputJson
.\Start-Sandbox.ps1 -Validate -Profile net-re-lite -OutputJson
.\Start-Sandbox.ps1 -ListTools -OutputJson
.\Start-Sandbox.ps1 -ListProfiles -OutputJson

# Download tools without launching (prepare cache for offline use)
.\Start-Sandbox.ps1 -NoLaunch

# Force re-download of all files
.\Start-Sandbox.ps1 -Force

# Skip Windows Sandbox feature check (CI/offline)
.\Start-Sandbox.ps1 -SkipPrereqCheck -NoLaunch

# Verbose output
.\Start-Sandbox.ps1 -Verbose
```

`-Validate` vs `-DryRun`:
- `-Validate` answers: "Can I safely/run this on this host now?" It does not download, generate artifacts, or launch.
- `-DryRun` answers: "What would be selected/generated?" It still writes generated host artifacts (`install-manifest.json`, `sandbox.wsb`) but skips download and launch.
- Add `-OutputJson` to `-Validate`, `-DryRun`, `-ListTools`, or `-ListProfiles` when automation needs stable machine-readable output from stdout.

Common `-Validate` remediations:
- Shared-folder path rejected: choose a dedicated local non-reparse ingress path (for example `C:\Lab\Ingress`).
- Windows Sandbox feature not enabled: run `Enable-WindowsOptionalFeature -FeatureName Containers-DisposableClientVM -Online` as Administrator and reboot.
- Prerequisite check warning due limited host visibility: re-run without `-SkipPrereqCheck` and with sufficient privileges.

---

## Custom profiles

Create optional `custom-profiles.local.json` in repo root:

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

Usage:

```powershell
.\Start-Sandbox.ps1 -Profile net-re-lite
.\Start-Sandbox.ps1 -Validate -Profile net-re-lite
.\Start-Sandbox.ps1 -DryRun -Profile net-re-lite -AddTools floss
```

Selection precedence:
1. Built-in profile, or custom profile `base_profile`.
2. Custom profile `add_tools`, then `remove_tools`.
3. Runtime `-AddTools`, then `-RemoveTools`.

Notes:
- Unknown profile names and unknown tool IDs fail fast with actionable errors.
- `-ListProfiles` shows both built-in and custom profiles distinctly.
- Custom profiles in this pass inherit networking behavior from their built-in `base_profile`.
- JSON output mode is intentionally excluded from normal launch mode (`Run`).

---

## Optional shared folder for file transfer

Use this when you need to stage files from host into sandbox. No extra mapping is added unless you opt in.

- Default mode is read-only.
- Writable mode requires explicit `-SharedFolderWritable` plus `-SharedFolder` or `-UseDefaultSharedFolder`.
- Files appear in the sandbox at `C:\Users\WDAGUtilityAccount\Desktop\shared`.
- Reparse-point/junction-backed shared-folder targets are blocked, and parent-chain traversal through reparse/junction paths is blocked.

```powershell
.\Start-Sandbox.ps1 -UseDefaultSharedFolder
.\Start-Sandbox.ps1 -SharedFolder "C:\Lab\Ingress"
.\Start-Sandbox.ps1 -SharedFolder "C:\Lab\Ingress" -SharedFolderWritable
```

`-UseDefaultSharedFolder` creates repo-local `shared/` if needed and keeps it gitignored.
Avoid broad or sensitive host folders (repo root, `C:\`, `%WINDIR%`, Program Files roots, `%USERPROFILE%`, Desktop, Documents, Downloads).
Some synced/managed paths (including some OneDrive-backed or redirected locations) can be rejected by design if their ancestry includes reparse points/junctions. This includes `-UseDefaultSharedFolder` when the repo is in such a location. Prefer a plain local, non-synced ingress folder.
Clipboard and drag/drop may work on some hosts, but this mapped folder workflow should be your primary transfer path.
For troubleshooting, add `-SharedFolderValidationDiagnostics` to print ancestry segments checked during validation.

---

## Subsequent runs

Downloaded files are cached in `scripts/setups/` and are **not re-downloaded** unless you use `-Force`.

The sandbox is fully disposable — close it to discard all changes. The next launch starts from scratch.

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
