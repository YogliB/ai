# Project agent rules

Agent-facing entry point. **Read the rules before doing any work here.** For the open format, see [agents.md](https://agents.md/).

## Rules

These rules are always-on. Read them before every task:

| Rule                | Guideline                                                                                                                                                                   |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Skill format        | Keep `SKILL.md` files short, clear, and concise. Preserve output contracts, tag definitions, and subagent instructions; remove redundant prose and duplicated explanations. |
| Skill usage         | Before using a snail skill, read `skills/<skill>/SKILL.md`.                                                                                                                 |
| Workflow invocation | Do not run `snail-flow` unless the user explicitly asks for it.                                                                                                             |
| Workflow output     | Flow skills write numbered phase YAML artifacts to `.agents/flows/snail-<slug>/` and update `runbook.yaml` via `flow-state.mjs` (Node 24+ required).                        |
| Commits             | Run `nub run format` before committing. Squash to a single Conventional Commit.                                                                                             |

## Docs index

| Doc                                                | Purpose                                   |
| -------------------------------------------------- | ----------------------------------------- |
| [README.md](README.md)                             | User-facing overview, install, and usage  |
| [docs/USAGE.md](docs/USAGE.md)                     | Install options, workflow, advanced usage |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)       | Structure, data flow, and gates           |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)       | Setup, conventions, and PRs               |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems                           |
| [docs/SECURITY.md](docs/SECURITY.md)               | Security policy                           |
| [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md) | Code of conduct                           |
| [LICENSE.md](LICENSE.md)                           | License                                   |

## Condensed docs

snail is a cross-agent AI workflow toolkit. Skills live in `skills/snail-*/SKILL.md` and are the source of truth for all agents.

### Setup

```bash
nub install
nub run format
```

### Common commands

| Command                              | Purpose                                                             |
| ------------------------------------ | ------------------------------------------------------------------- |
| `node scripts/install.mjs`           | Install the Cursor plugin into `~/.cursor/plugins/local/`           |
| `node scripts/uninstall.mjs`         | Remove the Cursor plugin                                            |
| `node scripts/sync-devin-plugin.mjs` | Sync `skills/` and `rules/` into `plugins/snail/`                   |
| `node scripts/gen-skills-index.mjs`  | Regenerate the skill list in `rules/snail.md` (`--check` to verify) |
| `node scripts/vendor-js-yaml.mjs`    | Refresh vendored js-yaml copies (`--check` to verify)               |
| `nub run format`                     | Format with `oxfmt`                                                 |
| `nub run lint`                       | Run the pre-commit lint step                                        |
| `npm test`                           | Run the `node --test` suite in `tests/`                             |

### Project layout

- `skills/` — skills, source of truth for all agents.
- `rules/` — shared rules shipped inside the Cursor and Devin plugins.
- `.agents/flows/` — flow output directory (actual flow dirs are `snail-*`, plus the runbook-less `snail-review/` standalone location).
- `.cursor-plugin/` — Cursor plugin manifest; the repo root is the plugin.
- `.claude-plugin/` — Claude Code plugin manifest.
- `plugins/snail/` — Devin plugin (manifest, `skills/` and `rules/` synced from root).
- `scripts/` — repo scripts (install, uninstall, sync, index, vendoring), all Node 24+.
- `tests/` — the `node --test` suite for the scripts and gates.
- `docs/` — contributor and user documentation.

## Documentation sync

Keep `README.md`, `AGENTS.md`, `CLAUDE.md`, and `docs/` aligned when changing workflows or conventions.
