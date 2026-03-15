# Install Profiles

## Overview

Profiles control tool selection and sandbox networking posture.

Notes:
- `7zip` is included as a bootstrap dependency for archive-based tools in all profiles.
- Some tools are intentionally marked manual/advanced in this pass instead of pretending full automation.

---

## `minimal`

**Use when:** Fast baseline with editors/runtime + Sysinternals.

**Networking:** ❌ Disabled

Core tools:
- 7-Zip
- Visual Studio Code
- Notepad++
- Python 3
- Sysinternals Suite

```powershell
.\Start-Sandbox.ps1 -Profile minimal
```

---

## `reverse-engineering` *(default)*

**Use when:** General malware RE/static analysis.

**Networking:** ❌ Disabled

Adds to `minimal`:
- Corretto 21
- Visual C++ Redist x64
- Ghidra
- x64dbg
- dnSpyEx
- Detect-It-Easy
- UPX
- PE-bear
- pestudio
- HxD
- FLARE FLOSS

```powershell
.\Start-Sandbox.ps1 -Profile reverse-engineering
```

---

## `network-analysis`

**Use when:** Network capture/inspection workflows.

**Networking:** ✅ Enabled

Adds to `reverse-engineering`:
- Wireshark
- Npcap (manual install)

```powershell
.\Start-Sandbox.ps1 -Profile network-analysis
```

---

## `triage-plus`

**Use when:** Rapid triage with lightweight static + network tooling.

**Networking:** ✅ Enabled

Core pack:
- Sysinternals Suite
- Detect-It-Easy
- Dependencies
- Wireshark

```powershell
.\Start-Sandbox.ps1 -Profile triage-plus
```

---

## `reverse-windows`

**Use when:** Windows-focused reverse/debug/runtime tracing.

**Networking:** ❌ Disabled

Core pack:
- x64dbg
- Detect-It-Easy
- Dependencies
- API Monitor (manual/advanced)
- ProcDOT (manual/advanced)

```powershell
.\Start-Sandbox.ps1 -Profile reverse-windows
```

---

## `behavior-net`

**Use when:** Behavior + network correlation workflows.

**Networking:** ✅ Enabled

Core pack:
- Sysinternals Suite
- Wireshark
- API Monitor (manual/advanced)
- ProcDOT (manual/advanced)

```powershell
.\Start-Sandbox.ps1 -Profile behavior-net
```

---

## `dev-windows`

**Use when:** Developer/debugger workstation inside sandbox.

**Networking:** ❌ Disabled

Core pack:
- Visual Studio Community (manual/heavy)
- Windows SDK (manual/workflow-coupled)
- Sysinternals Suite

```powershell
.\Start-Sandbox.ps1 -Profile dev-windows
```

---

## `full`

**Use when:** Entire catalog.

**Networking:** ✅ Enabled

Includes all tools in `tools.json`.

```powershell
.\Start-Sandbox.ps1 -Profile full
```

---

## Deferred In This Pass

- REMnux bundling (Linux/container-oriented; planned for later helper/container work).
- VirusTotal Windows uploader bundling (official uploader is no longer maintained by VirusTotal).
