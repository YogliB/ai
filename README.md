# AI — Agent Skills and Workflows

Reusable agent skills and an optional end-to-end workflow.

The skills work independently. Use one skill or run the full flow.

## Quick start

```bash
nub install
nub run format
```

## Install

### Claude Code (plugin)

```bash
./install.sh
```

This copies the repo to `~/.claude/plugins/ai/` and makes the shortcuts available on the next Claude Code restart.

### Install into another project

```bash
./install.sh /path/to/your/repo
```

This copies skills, rules, and the runbook into the target project.

### Cursor

```bash
./install.sh /path/to/your/repo
```

Cursor will pick up the `.cursor/rules/*.mdc` files.

## Shortcuts

When the Claude Code plugin is active, these shortcuts expand into skill instructions:

- `/alternatives` — review up to 3 options and recommend one
- `/plan` — write an executable plan to `.agents/plans/<slug>.md`
- `/review` — review the current diff
- `/pr` — create or update a PR
- `/flow` — run the full workflow

## Skills

| Skill                                                              | Purpose                                               |
| ------------------------------------------------------------------ | ----------------------------------------------------- |
| [alternatives](.agents/skills/alternatives/SKILL.md)               | Generate and review up to 3 options before committing |
| [review-alternatives](.agents/skills/review-alternatives/SKILL.md) | Independent review of proposed alternatives           |
| [planning](.agents/skills/planning/SKILL.md)                       | Write a self-contained, executable plan to a file     |
| [review-and-fix](.agents/skills/review-and-fix/SKILL.md)           | Loop: review, triage, fix, re-review until clean      |
| [review-dont-fix](.agents/skills/review-dont-fix/SKILL.md)         | One-shot read-only review                             |
| [pr](.agents/skills/pr/SKILL.md)                                   | Create or update a GitHub PR                          |

## Workflow

The optional end-to-end flow is documented in [RUNBOOK.md](RUNBOOK.md):

```text
alternatives → planning → implementation → review → PR
```

Each step runs in an independent subagent when the platform supports it. The parent acts as a thin dispatcher.

## Plan files

Finalized plans are written to `.agents/plans/<slug>.md` so later phases can read them without depending on chat context. See [.agents/plans/README.md](.agents/plans/README.md).

## Repository structure

| Path                                   | Description                               |
| -------------------------------------- | ----------------------------------------- |
| [`.agents/skills/`](.agents/skills/)   | On-demand agent skills                    |
| [`.claude/rules/`](.claude/rules/)     | Claude rule modules loaded by `CLAUDE.md` |
| [`.cursor/rules/`](.cursor/rules/)     | Cursor project rules                      |
| [`.claude-plugin/`](.claude-plugin/)   | Claude Code plugin manifest               |
| [`RUNBOOK.md`](RUNBOOK.md)             | Optional end-to-end workflow reference    |
| [`install.sh`](install.sh)             | Install globally or into a project        |
| [`.claude/agents/`](.claude/agents/)   | Claude subagent prompts                   |
| [`.cursor/.agents/`](.cursor/.agents/) | Cursor subagent prompts                   |
