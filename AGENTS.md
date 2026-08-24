# AGENTS.md

Agent-facing entry point. **Read the rules before doing any work here.** For the open format, see [agents.md](https://agents.md/).

## Rules

These rules are always-on. Read them before every task:

| Rule     | File                                                   | What it covers                  |
| -------- | ------------------------------------------------------ | ------------------------------- |
| slashkit | [.claude/rules/slashkit.md](.claude/rules/slashkit.md) | AI workflow toolkit conventions |
| caveman  | [.agents/rules/caveman.md](.agents/rules/caveman.md)   | Terse output mode               |
| ponytail | [.agents/rules/ponytail.md](.agents/rules/ponytail.md) | Lazy senior dev code mode       |
| rtk      | [.agents/rules/rtk.md](.agents/rules/rtk.md)           | Token-optimized CLI proxy       |

@.agents/rules/caveman.md
@.agents/rules/ponytail.md
@.agents/rules/rtk.md
@.claude/rules/slashkit.md
@RUNBOOK.md

## Docs index

| Doc                                                | Purpose                                  |
| -------------------------------------------------- | ---------------------------------------- |
| [README.md](README.md)                             | User-facing overview, install, and usage |
| [RUNBOOK.md](RUNBOOK.md)                           | End-to-end workflow                      |
| [docs/USAGE.md](docs/USAGE.md)                     | Install options and advanced usage       |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)       | Structure and data flow                  |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)       | Setup, conventions, and PRs              |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems                          |
| [docs/SECURITY.md](docs/SECURITY.md)               | Security policy                          |
| [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md) | Code of conduct                          |
| [LICENSE.md](LICENSE.md)                           | License                                  |

## Condensed docs

slashkit is a cross-agent AI workflow toolkit. Skills live in `.agents/skills/sk-*/SKILL.md` and are the source of truth for all agents.

### Setup

```bash
nub install
nub run format
```

### Conventions

- Keep `SKILL.md` files short, clear, and concise.
- Read a skill's `SKILL.md` before using it.
- Do not run `sk-flow` unless the user explicitly asks for it.
- Flow output goes to `.agents/flows/sk-<slug>/`, with numbered phase docs and a `RUNBOOK.md`.
- Run `nub run format` before committing.
- Squash to a single Conventional Commit.

### Common commands

| Command                        | Purpose                                          |
| ------------------------------ | ------------------------------------------------ |
| `./install.sh`                 | Install skills and Claude Code plugin globally   |
| `./install.sh /path/to/repo`   | Install skills and rules into a project          |
| `./uninstall.sh`               | Uninstall skills and Claude Code plugin globally |
| `./uninstall.sh /path/to/repo` | Uninstall skills and rules from a project        |
| `nub run format`               | Format with `oxfmt`                              |
| `nub run lint`                 | Run the pre-commit lint step                     |

### Project layout

- `.agents/skills/` — skills, source of truth for all agents.
- `.agents/flows/` — flow output directory (actual flow dirs are `sk-*`).
- `.agents/rules/` — shared always-on rules.
- `.claude/rules/` — Claude rule modules.
- `.cursor/rules/` — Cursor project rules.
- `.devin/rules/` — Devin project rules.
- `.claude-plugin/` — Claude Code plugin manifest.
- `install.sh` — install globally or into a project.
- `uninstall.sh` — uninstall globally or from a project.
- `RUNBOOK.md` — optional end-to-end workflow.
- `docs/` — contributor and user documentation.

## Documentation sync

Keep `README.md`, `AGENTS.md`, `CLAUDE.md`, rules, `RUNBOOK.md`, and `docs/` aligned when changing workflows or conventions.
