# Version Matrix

| Component | Version strategy | Current value | Notes |
|---|---|---|---|
| Toolkit manifest schema | pinned | 1.0 | `tools.json` + `schemas/tools.schema.json` |
| 7-Zip | pinned static | 24.09 | bootstrap dependency |
| Python | pinned static | 3.13.2 | removes legacy/EOL runtime drift |
| Wireshark | pinned static | 4.4.6 | network-enabled profiles only |
| Npcap | pinned static/manual | 1.82 | manual in-sandbox install |
| Sysinternals | floating latest | latest | vendor zip |
| Ghidra | floating latest | latest | GitHub release resolver |
| x64dbg | floating latest | latest | SourceForge latest |
| dnSpyEx | floating latest | latest | GitHub release resolver |
| Detect-It-Easy | floating latest | latest | GitHub release resolver |
| Dependencies | floating latest | latest | GitHub release resolver |
| FLOSS | floating latest | latest | GitHub release resolver |

## Profile policy matrix

| Profile | Networking | vGPU | Primary use |
|---|---|---|---|
| minimal | Disable | Disable | low-risk baseline |
| reverse-engineering | Disable | Default | offline reversing |
| network-analysis | Enable | Default | packet capture/lab network workflows |
| analysis | Enable | Default | internet-enabled analyst workstation |
| detonation | Disable | Disable | restricted detonation |
| forensics | Disable | Disable | static/offline forensics |
| triage-plus | Enable | Default | lightweight rapid triage |
| reverse-windows | Disable | Default | Windows runtime tracing |
| behavior-net | Enable | Default | behavior + network correlation |
| dev-windows | Disable | Default | debug/dev workflow |
| full | Enable | Default | complete catalog |
