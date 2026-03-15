# Safety & Security

## Design principles

This toolkit is designed for **defensive** malware analysis and reverse engineering in an isolated
Windows Sandbox environment. The following defaults reflect a least-privilege, least-exposure posture.

---

## Networking

**Networking is disabled by default** in all profiles except `network-analysis` and `full`.

**Why:** A sandbox used for detonation or static analysis does not need network access.
Disabling networking prevents any sample from exfiltrating data, phoning home, or
downloading second-stage payloads during analysis.

**When to enable:** Only enable networking in the `network-analysis` or `full` profile
when you specifically need to observe or capture network traffic. Be aware:

- The sandbox shares your host's network interface.
- Malware detonated with networking enabled can attempt connections over your real network.
- Consider using a dedicated isolated network (e.g., a separate VLAN or physical NIC) for
  network-analysis sessions.
- Capture traffic with Wireshark and disconnect from your main network first if possible.

---

## Host folder mapping

The `scripts/` folder is mapped **read-only** into the sandbox. This means:

- The sandbox can read downloaded tools from the host.
- The sandbox **cannot write back** to your host filesystem via this mapping.
- No other host folders are mapped unless you explicitly opt in.

Optional shared-folder mapping is available for sample transfer:

- `.\Start-Sandbox.ps1 -UseDefaultSharedFolder` creates/maps repo-local `shared/`.
- `.\Start-Sandbox.ps1 -SharedFolder <path>` maps one explicit existing folder.
- Shared-folder mapping is **read-only by default**.
- Writable mode requires explicit `-SharedFolderWritable` with a shared-folder option and increases host risk.
- In sandbox, the mapped path is `C:\Users\WDAGUtilityAccount\Desktop\shared`.

Avoid mapping broad or sensitive host paths (drive root, Windows folders, Program Files,
profile root, Desktop, Documents, Downloads).

**Do not map** additional writable host folders when working with untrusted samples.

---

## Sample handling

- **Do not auto-execute samples** from the host. If you need to analyze a sample,
  use the opt-in mapped shared folder workflow as the primary transfer path.
- Samples are isolated inside the sandbox and are discarded when the sandbox closes.
- Clipboard and drag/drop behavior may vary by policy/host; do not rely on these paths.
- Do not enable ClipboardRedirection if you are pasting from a session where you have
  handled malicious content.

---

## Tool sources and integrity

All tools are sourced from official vendor sites or their official GitHub repositories.
The manifest (`tools.json`) documents source URLs and version pins for every tool.

**Removed tools with integrity concerns:**
- AutoIT Extractor was removed because it was sourced from an unverified GitLab CI artifact
  with no stable release URL or checksum.

**Checksum verification:** The current manifest does not include SHA256 checksums for all tools
because several tools use dynamic "latest" URLs that change with each release. Future work should
add checksum pinning for tools with stable, versioned URLs.

---

## Offensive capability boundary

This toolkit is strictly limited to **defensive analysis and reverse engineering**:

- No offensive tools, exploit frameworks, or payload staging helpers are included.
- No persistence mechanisms (the sandbox is disposable by design).
- No credential harvesting tools.
- No remote access tooling.
- No malware evasion features.

Additions that would materially facilitate malware deployment, evasion, or concealment
will not be accepted.

---

## Windows Sandbox security model

Windows Sandbox uses hardware-based virtualization isolation. It is **not a substitute**
for a properly isolated network environment or a dedicated analysis machine for high-risk
samples. For advanced threat actors or samples with known sandbox-evasion capabilities,
consider:

- A dedicated bare-metal analysis machine.
- A fully isolated network segment.
- Snapshot-capable hypervisors (VMware, Hyper-V, VirtualBox) with network isolation.

---

## Reporting security issues

If you discover a security issue in this toolkit, please open a GitHub issue or contact
the maintainer directly. Do not include sensitive information in public issues.
