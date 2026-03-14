# Troubleshooting

## Windows Sandbox won't start

**Error:** "Windows Sandbox is not enabled on this system."

```powershell
# Run as Administrator
Enable-WindowsOptionalFeature -FeatureName Containers-DisposableClientVM -Online
```

Reboot when prompted and re-run `Start-Sandbox.ps1`.

---

**Error:** "Virtualization not enabled."

Enable virtualization (VT-x / AMD-V) in your BIOS/UEFI settings.

---

**Error:** "Windows Sandbox requires Windows 10 Pro/Enterprise/Education."

Windows Sandbox is not available on Home editions. Consider using a local VM instead.

---

## Download failures

**Symptom:** `Start-Sandbox.ps1` exits with a download error.

- Check your internet connection.
- GitHub release URLs are resolved at runtime; a GitHub API outage will cause failures.
- Re-run `Start-Sandbox.ps1` — downloads are retried 3 times and already-downloaded files are skipped.
- Use `.\Start-Sandbox.ps1 -Force` to re-download a specific tool if a partial file was saved.

---

**Symptom:** GitHub API rate limit exceeded.

The manifest resolves `github_release` tools via the public GitHub API (60 req/hr unauthenticated).
If you hit rate limits:
- Wait an hour and retry, or
- Set a `GITHUB_TOKEN` environment variable — `Start-Sandbox.ps1` passes it automatically:
  ```powershell
  $env:GITHUB_TOKEN = 'ghp_...'
  .\Start-Sandbox.ps1
  ```

---

## Installation fails inside the sandbox

**Symptom:** Tools are not on the Desktop after the sandbox starts.

Check `install-log.txt` on the sandbox Desktop for details.

**Common causes:**
- 7-Zip failed to install (install_order=1). All zip-based tools will fail as a consequence.
  Check that `scripts/setups/7zip.msi` exists and is not zero bytes.
- Corretto failed — Ghidra will not extract correctly.
- A download was corrupted — re-run `.\Start-Sandbox.ps1 -Force`.

---

## `autostart.cmd` does not run

**Symptom:** Sandbox opens but no installation window appears.

- Verify that `scripts/autostart.cmd` exists and is a 3-line file.
- Verify the mapped folder path in `sandbox.wsb` matches your actual `scripts/` directory.
- Try regenerating: `.\Start-Sandbox.ps1 -NoLaunch` then open `sandbox.wsb` manually.

---

## Npcap does not install silently

This is by design. Npcap's installer requires user interaction.
After the sandbox starts, run:

```
%TEMP%\npcap.exe
```

and click through the wizard. This is noted in `tools.json` as a `manual` install.

---

## PSScriptAnalyzer errors in CI

Run locally before pushing:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning
```

---

## tools.json schema validation fails

```bash
pip install jsonschema
python -c "
import json, jsonschema
with open('tools.json') as f:
    manifest = json.load(f)
with open('schemas/tools.schema.json') as f:
    schema = json.load(f)
schema.pop('\$schema', None)
jsonschema.validate(manifest, schema)
print('OK')
"
```
