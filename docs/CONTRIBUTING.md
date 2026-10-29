# Contributing

## Setup

```bash
nub install
```

No nub? `npm ci` works too — the lockfile is a standard `package-lock.json`.

## Common Commands

| Command                                      | Purpose                                              |
| -------------------------------------------- | ---------------------------------------------------- |
| `nub run format`                             | Format Markdown and JSON with `oxfmt`.               |
| `nub run lint`                               | Run the pre-commit lint step.                        |
| `npm test`                                   | Run the `node --test` suite in `tests/`.             |
| `node scripts/sync-devin-plugin.mjs --check` | Fail if the Devin plugin copies differ from root.    |
| `node scripts/gen-skills-index.mjs --check`  | Fail if the skills index in rules/snail.md is stale. |
| `node scripts/vendor-js-yaml.mjs --check`    | Fail if a vendored js-yaml copy is stale.            |

## Project Layout

- `skills/` — Skills (source of truth for all agents).
- `.agents/flows/` — Flow output directory (actual flow dirs are `snail-*`, plus the runbook-less `snail-review/` standalone location).
- `rules/` — Shared rules shipped inside the Cursor and Devin plugins.
- `.cursor-plugin/` — Cursor plugin manifest (repo root is the plugin).
- `.claude-plugin/` — Claude Code plugin manifest.
- `plugins/snail/` — Devin plugin (manifest, `skills/` and `rules/` synced from root).
- `scripts/` — Repo scripts (install, uninstall, sync, index, vendoring), all Node.
- `tests/` — The `node --test` suite for the scripts and gates.
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
