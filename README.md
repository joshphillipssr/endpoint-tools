# endpoint-tools

Consolidated endpoint/admin automation scripts migrated from:

- `Public-Scripts`
- `powershell`
- `windows-update-reset`
- `Teams-Cleanup`
- `RDS-Sanitization`
- `screenconnect-install`
- `Dell-Laptops`
- `Dell-Command-Update`
- `clear-last-logged-in-user`
- `SCCM` (migrated as `ad-group-sync`)
- `Private-Scripts` (curated subset)

## Layout

- `tools/public-scripts/`
- `tools/powershell/`
- `tools/windows-update-reset/`
- `tools/teams-cleanup/`
- `tools/rds-sanitization/`
- `tools/screenconnect-install/`
- `tools/dell-laptops/`
- `tools/dell-command-update/`
- `tools/clear-last-logged-in-user/`
- `tools/ad-group-sync/`
- `tools/private-scripts/`

## Usage Note

Run scripts only in environments and systems you own or are explicitly authorized to administer.

## Public-Safe Boundary

This repo is the public canonical for reusable endpoint automation. Keep live hostnames, UNC paths, inventory, tenant bindings, usernames, passwords, and other environment-specific wrappers outside the tracked tree.

The `tools/private-scripts/` directory name is a legacy migration label from the source repos. Treat anything committed there as public-safe and sanitized before publish.

## Sanitization Check

Run the repo-local guardrail before publishing changes:

```bash
bash scripts/sanitize_check.sh
```
