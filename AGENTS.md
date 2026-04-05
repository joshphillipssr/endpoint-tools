# AGENTS Instructions: endpoint-tools

This repository is the public canonical for the Phase 5 Wave 1 B3 rollout.

Repo rules:
- Keep the tracked tree limited to reusable endpoint automation and generic examples.
- Do not commit live hostnames, UNC paths, tenant bindings, inventory, usernames, passwords, enrollment tokens, or other environment-specific wrappers.
- The `tools/private-scripts/` directory name is a legacy migration label. Treat its contents as public-safe only.
- If you change tracked defaults, placeholders, or setup instructions, update `README.md` and `scripts/sanitize_check.sh` in the same change.
- Run `bash scripts/sanitize_check.sh` before handoff.