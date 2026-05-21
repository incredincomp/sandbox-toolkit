# Migration Notes (2.2.0)

## What changed

1. New built-in profiles were added:
   - `analysis`
   - `detonation`
   - `forensics`
2. Sandbox policy defaults are now profile-driven for both networking and `vGPU`.
3. Analyst automation scripts were added:
   - `scripts/Invoke-SampleTriage.ps1`
   - `scripts/Export-AnalysisArtifacts.ps1`
   - `scripts/Reset-SandboxWorkspace.ps1`
4. In-sandbox installer now writes:
   - `analysis-artifacts/install-summary.json`
   - `analysis-artifacts/install-timeline.csv`

## Required maintainer actions

- If you maintain custom profile docs, include the new profile names where relevant.
- If you maintain wrappers around profile allow-lists, add `analysis`, `detonation`, and `forensics`.
- If you ingest audit output, account for the new `wsb-vgpu` audit check.

## Operator workflow changes

- Prefer `analysis` for daily internet-enabled malware triage.
- Prefer `detonation` for restrictive no-network execution workflows.
- Prefer `forensics` for offline metadata/static analysis.
- Use `Invoke-SampleTriage.ps1` before execution to create hash + string previews.
- Use `Export-AnalysisArtifacts.ps1` to export one zip bundle to the mapped shared folder.
