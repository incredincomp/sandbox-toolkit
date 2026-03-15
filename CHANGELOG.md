# Changelog

All notable changes to this project will be documented here.

---

## [2.0.7] — 2026-03-15

### Hardening

- Added bounded integration characterization coverage for release readiness:
  - `-DryRun` with built-in/custom profiles plus add/remove runtime override combinations.
  - `-Validate` with built-in/custom profiles plus invalid profile/tool combinations.
  - list-mode reflection against current manifest/custom profile state.
  - cleanup-scope behavior ensuring `-CleanDownloads` does not mutate non-cache surfaces.
- Tightened list-mode parameter validation:
  - `-NoLaunch` now fails with `-ListTools` / `-ListProfiles`.
  - `-SkipPrereqCheck` now fails with `-ListTools` / `-ListProfiles`.

### CI / Release readiness

- Expanded deterministic Windows CI smoke matrix with:
  - validate custom-profile success path.
  - validate invalid-tool failure path.
  - dry-run built-in remove-only path.

## [2.0.6] — 2026-03-15

### Features

- Added saved session/template workflows:
  - `-SaveTemplate <name>`
  - `-ListTemplates`
  - `-ShowTemplate <name>`
  - `-Template <name>` for run/validate/dry-run/audit execution.
- Added repo-local template persistence at `saved-sessions.local.json` (gitignored), using deterministic human-readable JSON.
- Reused existing selection/validation pipeline for template execution by layering template tool deltas before runtime overrides.
- Added execute/save-time validation for template profile/tool/shared-folder references.

### Precedence

- Defined deterministic precedence for template-driven runs:
  1. template base values
  2. profile/custom-profile resolution
  3. template `add_tools` / `remove_tools`
  4. runtime `-AddTools` / `-RemoveTools`
  5. explicit command-line flags overriding matching template defaults

### Testing

- Added unit coverage for template store parsing, malformed content handling, name validation, invocation resolution, and readiness checks.
- Added integrated CLI coverage for save/list/show/template execution via `-DryRun`/`-Validate`, plus malformed/unknown template failures.

## [2.0.5] — 2026-03-15

### Hardening

- Added integrated CLI characterization coverage for:
  - `-DryRun` with built-in/custom profiles and runtime add/remove overrides.
  - `-Validate` with built-in/custom profiles and invalid profile/tool/custom-config inputs.
  - list-mode state reflection and cleanup-scope behavior.
- Preserved tracked `scripts/setups/.gitkeep` during `-CleanDownloads` while keeping disposable cache/session cleanup behavior.
- Standardized key user-facing error categories:
  - unknown profile
  - unknown tool id
  - malformed custom profile config
  - invalid parameter combinations
- Normalized JSON fatal error mode naming to align with successful mode contracts (`dry-run`, `list-tools`, `list-profiles`, etc.).

### CI / Release readiness

- Added CI Pester execution on Windows.
- Added deterministic CLI smoke matrix for realistic non-destructive command combinations using `-SkipPrereqCheck`, JSON seams, and cleanup mode.
- Added a table-driven CI assertion for documented exit-code contract examples.
- Added JSON error-envelope contract coverage for fatal failures across JSON-capable modes.

---

## [2.0.4] — 2026-03-14

### Reliability

- Hardened warm-session discovery by centralizing `wsb list --raw` parsing into one normalization helper.
- Added deterministic handling for malformed/unsupported raw JSON output and records missing required warm-session fields.
- Added parser-focused fixtures/tests to reduce warm-mode fragility against bounded CLI output drift.

---

## [2.0.3] — 2026-03-14

### Features

- Added sandbox lifecycle selection with `-SessionMode Fresh|Warm`:
  - `Fresh` remains default and disposable.
  - `Warm` uses Windows Sandbox CLI surfaces (`wsb`) to reuse running sessions when available, otherwise creates CLI-managed sessions on supported hosts.
- Added optional bounded WSL helper sidecar workflow:
  - `-UseWslHelper`
  - `-WslDistro`
  - `-WslHelperStagePath`
  - helper-side staging + metadata artifacts only (no trust-boundary escalation claims).
- Extended `-Validate`, `-DryRun`, and `-Audit` (including JSON output) with additive lifecycle/helper context:
  - session mode request/effective state and warm-support visibility.
  - WSL helper request/effective state and helper hardening guidance checks.

### Documentation

- Documented fresh vs warm lifecycle tradeoffs and host support boundaries.
- Documented WSL helper scope and explicit trust-boundary wording (helper layer vs sandbox execution boundary).
- Added WSL helper hardening recommendations for `/etc/wsl.conf` (`automount`, `interop`, `appendWindowsPath`).

---

## [2.0.2] — 2026-03-14

### Features

- Added host-interaction policy switches for generated sandbox configuration:
  - `-DisableClipboard` (requests `ClipboardRedirection=Disable`)
  - `-DisableAudioInput` (explicitly requests `AudioInput=Disable`)
  - `-DisableStartupCommands` (suppresses generated `LogonCommand` startup injection)
- Extended `-Validate`, `-DryRun`, and `-Audit` (including JSON output) to surface configured/requested host-interaction policy state.
- Preserved existing default behavior when new switches are not used.

---

## [2.0.1] — 2026-03-14

### Documentation

- Marked the `-Audit -OutputJson` contract as stable for automation consumers.
- Stable means required documented contract fields are expected to remain compatible unless a breaking change is explicitly called out.
- Additive fields may be introduced without being considered breaking.
- Human-readable check summary prose is informational and not the contract surface.
- See [README Audit JSON contract](README.md#audit-json-contract) for the current stable field set and semantics.

---

## [2.0.0] — 2026-03-14

### Architecture

- **Complete rewrite** from manual scripts to a manifest-driven, profile-aware toolkit.
- Introduced `tools.json` as the single source of truth for all tool metadata: versions,
  download URLs, install arguments, and profile membership.
- Added `schemas/tools.schema.json` for manifest validation.
- Replaced `downloadFiles.ps1` and `createSandboxConfig.ps1` with `Start-Sandbox.ps1`,
  a single entry point that handles prerequisites, downloads, config generation, and launch.
- Replaced the monolithic `scripts/autostart.cmd` install chain with a PowerShell-based
  `scripts/Install-Tools.ps1` that reads the session manifest and installs tools in order.
- Added `src/Manifest.ps1`, `src/Download.ps1`, `src/SandboxConfig.ps1` as reusable modules.

### Tools

- **Added FLARE FLOSS** — MANDIANT obfuscated string extraction tool.
- **Replaced dnSpy** with **dnSpyEx** — the actively maintained fork (dnSpy archived 2022).
- **Updated 7-Zip** 19.0 → 24.09.
- **Updated Notepad++** 8.1.1 → latest (GitHub release resolution).
- **Updated Ghidra** 9.2 → latest (GitHub release resolution). Now requires JDK 21.
- **Updated Corretto JDK** 11 → 21 (required for Ghidra 11.x).
- **Updated Python 3** 3.9.1 → 3.13.2.
- **Updated UPX** 3.96 → latest (GitHub release resolution).
- **Updated Detect-It-Easy** 3.02 → latest (GitHub release resolution).
- **Updated PE-bear** 0.5.4 → latest (GitHub release resolution).
- **Updated Wireshark** 3.4.6 → 4.4.6.
- **Updated npcap** 1.10 → 1.82.
- **Updated vcredist** VS2019 → VS2022 URL.
- **Removed Python 2** — EOL January 2020.
- **Removed DosBox** — not relevant to malware analysis workflows.
- **Removed Sublime Text** — redundant with VSCode and Notepad++.
- **Removed AutoIT Extractor** — sourced from unverified GitLab CI artifact, no stable release.

### Profiles

- Added install profiles: `minimal`, `reverse-engineering` (default), `network-analysis`, `full`.

### Safety

- **Networking disabled by default** (was enabled). Only `network-analysis` and `full` enable it.
- Host folder mapped read-only (was already the case; now enforced in generated .wsb).
- `.wsb` is now generated programmatically, not by brittle string replacement.

### Developer experience

- Added GitHub Actions CI: PSScriptAnalyzer linting + manifest schema validation.
- Added `.editorconfig`.
- Added `scripts/setups/` to `.gitignore` (populated at runtime, not committed).
- Added `README.md`, `QUICKSTART.md`, `PROFILES.md`, `TROUBLESHOOTING.md`, `SAFETY.md`.
- Install log written to `%USERPROFILE%\Desktop\install-log.txt` inside sandbox.
- Downloads use retry logic (3 attempts) and skip already-cached files.

---

## [1.x] — Prior to 2026-03-14

Legacy single-script approach. See git history for details.
