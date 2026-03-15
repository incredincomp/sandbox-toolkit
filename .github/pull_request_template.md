## Summary

- [ ] Describe the change and its intent.

## Validation

- [ ] `Invoke-Pester -Path tests`
- [ ] PSScriptAnalyzer (`Error,Warning`)

## JSON Contract Impact

- [ ] I reviewed whether this PR changes any documented JSON automation contract fields/shapes.
- [ ] If this PR introduces a breaking change to documented JSON contract fields/shapes, I added an explicit `CHANGELOG.md` note.
- [ ] If JSON changes are additive-only (for example, new optional fields), I confirmed they are documented as additive and non-breaking.
- [ ] I did not treat human-readable output prose as the JSON automation contract surface.

Reference: `README.md` section `Audit JSON contract`.

## Workflow Docs Impact

- [ ] I reviewed whether this PR changes user-facing command-mode behavior or recommended command ordering.
- [ ] If discovery/validation/dry-run/audit/run workflow changed, I updated workflow guidance in `README.md` and `docs/QUICKSTART.md`.
- [ ] No workflow-doc update is needed for internal-only changes that do not alter user-facing flow.

Reference: `README.md` section `Recommended workflow`.
