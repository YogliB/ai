# Contributing

## Setup

```bash
nub install
```

No nub? `npm ci` works too — the lockfile is a standard `package-lock.json`.

## Common Commands

| Command                                   | Purpose                                           |
| ----------------------------------------- | ------------------------------------------------- |
| `nub run format`                          | Format Markdown and JSON with `oxfmt`.            |
| `nub run lint`                            | Run the pre-commit lint step.                     |
| `sh scripts/sync-devin-plugin.sh --check` | Fail if the Devin plugin copies differ from root. |
| `sh scripts/test-flow-state.sh`           | Test the runbook state machine and validator.     |
| `sh scripts/test-lint-plan.sh`            | Test the plan-structure linter.                   |
| `sh scripts/test-receipts.sh`             | Test the check-receipt scripts.                   |

## Project Layout

- `skills/` — Skills (source of truth for all agents).
- `.agents/flows/` — Flow output directory (actual flow dirs are `sk-*`).
- `rules/` — Shared rules shipped inside the Cursor and Devin plugins.
- `.cursor-plugin/` — Cursor plugin manifest (repo root is the plugin).
- `.claude-plugin/` — Claude Code plugin manifest.
- `plugins/snail/` — Devin plugin (manifest, `skills/` and `rules/` synced from root).
- `scripts/install.sh` — Install the Cursor plugin.
- `scripts/uninstall.sh` — Remove the Cursor plugin.
- `README.md` — Human-facing overview.
- `AGENTS.md` — Agent-facing index.
- `docs/` — Contributor and user documentation.

## Documentation Sync

Keep these files aligned:

- `README.md` — user-facing install, usage, and caveats
- `AGENTS.md` — rules index, docs index, and condensed docs
- `CLAUDE.md` — Claude rule `@` includes
- `rules/` — cross-agent rules
- `docs/USAGE.md`, `docs/ARCHITECTURE.md`, `docs/CONTRIBUTING.md`, and `docs/TROUBLESHOOTING.md`

## Skill style

- Keep `SKILL.md` files short, clear, and concise.
- Preserve output contracts, tag definitions, and subagent instructions.
- Remove redundant prose and duplicated explanations; do not cut essential intent.

## Pull Requests

- Keep changes focused on one concern.
- Run `nub run format` before committing.
- Squash to a single commit with a Conventional Commit message.
- Do not add a `CHANGELOG.md` entry; this project does not keep a changelog.
