# Contributing

## Setup

```bash
nub install
```

## Common Commands

| Command          | Purpose                                |
| ---------------- | -------------------------------------- |
| `nub run format` | Format Markdown and JSON with `oxfmt`. |
| `nub run lint`   | Run the pre-commit lint step.          |

## Project Layout

- `.agents/skills/` — Skills (source of truth for all agents).
- `.claude/rules/` — Claude rule modules.
- `.cursor/rules/` — Cursor project rules.
- `.devin/rules/` — Devin project rules.
- `.claude-plugin/` — Claude Code plugin manifest.
- `src/hooks/` — Claude Code `UserPromptSubmit` hook.
- `install.sh` — Install globally or into another project.
- `README.md` — Human-facing overview.
- `AGENTS.md` — Agent-facing index.
- `RUNBOOK.md` — Optional end-to-end workflow.
- `docs/` — Contributor and user documentation.

## Documentation Sync

Keep these files aligned:

- `README.md` — user-facing install, usage, and caveats
- `AGENTS.md` — agent index and setup commands
- `CLAUDE.md` — Claude rule `@` includes
- `.claude/rules/`, `.cursor/rules/`, and `.devin/rules/` — cross-agent rules
- `RUNBOOK.md` — optional full workflow
- `.agents/plans/README.md` — plan file conventions

## Pull Requests

- Keep changes focused on one concern.
- Run `nub run format` before committing.
- Squash to a single commit with a Conventional Commit message.
- Do not add a `CHANGELOG.md` entry; this project does not keep a changelog.
