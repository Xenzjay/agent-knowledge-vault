# Repository Guide

This repository defines a configurable knowledge-workspace information architecture and its Obsidian/Agent conventions.

## Source of truth

- `manifest/vault-manifest.json` defines system areas, domain areas, second-level categories and optional subgroups.
- `manifest/routing-rules.yaml` maps incoming material to a destination.
- `scripts/bootstrap.ps1` generates directories from the JSON manifest. Do not duplicate the category tree in the script.
- `vault/AGENTS.md` contains the generated workspace's operating conventions.

## Change rules

1. Keep the taxonomy domain-oriented and configurable; avoid assumptions tied to one person's identity or workflow.
2. If a category changes, update routing examples and architecture documentation in the same change.
3. Keep second-level categories in the default scaffold. Generate optional subgroups only when requested.
4. Use metadata for transient states instead of creating folders for each state.
5. Use PowerShell 7+ for scripts and verification.
6. Run `pwsh -NoProfile -File .\scripts\validate.ps1` after edits.
