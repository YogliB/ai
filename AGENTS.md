# AGENTS.md

Agent-facing entry point. For the open format, see [agents.md](https://agents.md/).

## Quick links

| Topic                                    | Where to look                                                                                                                        |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| User-facing overview, install, and usage | [README.md](README.md)                                                                                                               |
| Optional end-to-end workflow             | [RUNBOOK.md](RUNBOOK.md)                                                                                                             |
| Architecture and data flow               | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)                                                                                         |
| Contributing flow and setup              | [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)                                                                                         |
| Troubleshooting                          | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)                                                                                   |
| Security policy                          | [docs/SECURITY.md](docs/SECURITY.md)                                                                                                 |
| Code of conduct                          | [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md)                                                                                   |
| License                                  | [LICENSE.md](LICENSE.md)                                                                                                             |
| Skills                                   | [.agents/skills/](.agents/skills/)                                                                                                   |
| AI toolbelt                              | [.agents/skills/ai-toolbelt/SKILL.md](.agents/skills/ai-toolbelt/SKILL.md)                                                           |
| Project docs                             | [.agents/skills/project-docs/SKILL.md](.agents/skills/project-docs/SKILL.md)                                                         |
| Claude rules                             | [.claude/rules/conventions.md](.claude/rules/conventions.md), [.claude/rules/workflow.md](.claude/rules/workflow.md)                 |
| Cursor rules                             | [.cursor/rules/ai-conventions.mdc](.cursor/rules/ai-conventions.mdc), [.cursor/rules/ai-workflow.mdc](.cursor/rules/ai-workflow.mdc) |
| Devin rules                              | [.devin/rules/ai-conventions.md](.devin/rules/ai-conventions.md), [.devin/rules/ai-workflow.md](.devin/rules/ai-workflow.md)         |

@.claude/rules/conventions.md
@.claude/rules/workflow.md
@RUNBOOK.md

## Setup

```bash
nub install
nub run format
```

## Project Layout

- `.agents/skills/` — on-demand skills; source of truth for all agents.
- `.agents/plans/` — durable plan files.
- `.claude/rules/` — Claude rule modules loaded by `CLAUDE.md`.
- `.cursor/rules/` — Cursor project rules.
- `.devin/rules/` — Devin project rules.
- `.claude-plugin/` — Claude Code plugin manifest.
- `src/hooks/` — Claude Code `UserPromptSubmit` hook.
- `install.sh` — install globally or into a project.
- `RUNBOOK.md` — optional end-to-end workflow.
- `docs/` — contributor and user documentation.

## Common Commands

| Command                      | Purpose                                            |
| ---------------------------- | -------------------------------------------------- |
| `./install.sh`               | Install skills and plugin globally for all agents. |
| `./install.sh /path/to/repo` | Install skills and rules into a target project.    |
| `nub run format`             | Format with `oxfmt`.                               |
| `nub run lint`               | Run the pre-commit lint step.                      |

## Documentation Sync

Keep these aligned when changing workflows, conventions, or navigation:

- `README.md`, `AGENTS.md`, `CLAUDE.md`
- `.claude/rules/*.md`, `.cursor/rules/*.mdc`, and `.devin/rules/*.md`
- `RUNBOOK.md` and `.agents/plans/README.md`
- `docs/ARCHITECTURE.md`, `docs/CONTRIBUTING.md`, `docs/TROUBLESHOOTING.md`

## Pull Requests

- Run `nub run format` before committing.
- Keep changes focused.
- Squash to a single Conventional Commit.
