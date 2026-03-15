# Install Profiles

## Overview

Profiles control which tools are downloaded and installed, and what sandbox settings apply
(networking, etc.). Choose the profile that matches your analysis task.

---

## `minimal`

**Use when:** You want a fast sandbox with basic editors and Sysinternals. No RE tools.

**Networking:** ❌ Disabled

| Tool | Category |
|---|---|
| 7-Zip | Utility |
| Visual Studio Code | Editor |
| Notepad++ | Editor |
| Python 3 | Runtime |
| Sysinternals Suite | Sysanalysis |

```powershell
.\Start-Sandbox.ps1 -Profile minimal
```

---

## `reverse-engineering` *(default)*

**Use when:** Analyzing malware, PE files, .NET assemblies, packed binaries.

**Networking:** ❌ Disabled (safe for detonation / static analysis)

All tools from `minimal`, plus:

| Tool | Category | Purpose |
|---|---|---|
| Amazon Corretto JDK 21 | Runtime | Required by Ghidra |
| Visual C++ Redist x64 | Runtime | Required by PE-bear |
| Ghidra | Reversing | Disassembler/decompiler (NSA) |
| x64dbg | Reversing | Dynamic debugger |
| dnSpyEx | Reversing | .NET decompiler and debugger |
| Detect-It-Easy | Reversing | Packer/protector identification |
| UPX | Reversing | Packer/unpacker |
| PE-bear | Reversing | PE file editor/viewer |
| pestudio | Reversing | PE static analysis |
| HxD | Reversing | Hex editor |
| FLARE FLOSS | Reversing | Obfuscated string extraction |

```powershell
.\Start-Sandbox.ps1 -Profile reverse-engineering
```

---

## `network-analysis`

**Use when:** Capturing and analyzing network traffic from a sample.

**Networking:** ✅ Enabled — understand the risks in [SAFETY.md](SAFETY.md).

All tools from `reverse-engineering`, plus:

| Tool | Category | Notes |
|---|---|---|
| Wireshark | Network | Packet capture and analysis |
| Npcap | Network | **Manual install required** (no silent install) |

> **Note on Npcap:** Npcap's installer does not support silent/unattended installation.
> After the sandbox starts, run `npcap.exe` from `%TEMP%` manually.

```powershell
.\Start-Sandbox.ps1 -Profile network-analysis
```

---

## `full`

**Use when:** You want everything installed.

**Networking:** ✅ Enabled

All tools from `network-analysis` (i.e., everything in the manifest).

```powershell
.\Start-Sandbox.ps1 -Profile full
```

---

## Adding a new tool to a profile

Edit `tools.json` and add the profile name to the tool's `profiles` array:

```json
{
  "id": "mytool",
  "profiles": ["reverse-engineering", "full"],
  ...
}
```

The CI will validate your change automatically on push.
