# AGENTS.md

Agent-facing index and condensed notes for this repo.

## Index

| Doc                                                                  | Purpose                                    |
| -------------------------------------------------------------------- | ------------------------------------------ |
| [README.md](README.md)                                               | Human-facing overview and quick start      |
| [CLAUDE.md](CLAUDE.md)                                               | Claude Code rules and workflow             |
| [RUNBOOK.md](RUNBOOK.md)                                             | Optional end-to-end workflow reference     |
| [.cursor/rules/ai-conventions.mdc](.cursor/rules/ai-conventions.mdc) | Cursor project rules (always on)           |
| [.cursor/rules/ai-workflow.mdc](.cursor/rules/ai-workflow.mdc)       | Cursor workflow rule (agent-requested)     |
| [.agents/skills/](.agents/skills/)                                   | On-demand agent skills                     |
| [.claude/rules/](.claude/rules/)                                     | Claude rule modules loaded by CLAUDE.md    |
| [install.sh](install.sh)                                             | Install skills and rules into another repo |

## Summary

Personal toolkit of reusable agent skills and an optional cross-IDE workflow.

- **Skills**: alternatives, review-alternatives, planning, review-and-fix, review-dont-fix, pr.
- **Convention**: plans are written to `.agents/plans/<slug>.md`.
- **Workflow**: alternatives → planning → implementation → review → PR.
- **Modular**: use one skill or the whole flow.
