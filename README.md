# AI — Cursor Rules, Skills, and Workflows

Public repository containing reusable Cursor IDE rules, skills, and subagent workflows.

## What's in the repo

| Path                                 | What it is                                    |
| ------------------------------------ | --------------------------------------------- |
| [`AGENTS.md`](AGENTS.md)             | Always-on rules (built from `.agents/rules/`) |
| [`.agents/skills/`](.agents/skills/) | On-demand agent skills                        |
| [`.agents/rules/`](.agents/rules/)   | Rule source files                             |
| [`.cursor/agents/`](.cursor/agents/) | Cavecrew and chore subagent prompts           |
| [`archive/`](archive/)               | Historical rules and workflow references      |

## Quick start

```bash
npm install
npm run prepare-agents
```

## Rules

Source files in `.agents/rules/`:

- **agent-artifacts.md**: Storage locations for non-repo deliverables (plans, HLDs, specs).
- **apfel.md**: macOS Apple Intelligence CLI integration.
- **caveman.md**: Concise communication mode.
- **comments.md**: Strict no-comments source code policy.
- **ponytail.md**: Anti-overengineering principles.
- **rtk.md**: Rust Token Killer CLI proxy.
- **subagents.md**: Subagent routing policy.

## Skills

On-demand workflows in `.agents/skills/`:

- **alternatives**: Compare up to 3 options before coding.
- **apfel**: On-device AI execution via Apple Intelligence.
- **planning**: Self-contained executable technical plans.
- **review-and-fix**: Closed-loop code review and fix pass via Task subagents.
- **review-dont-fix**: One-shot read-only code review.

## Subagents

Custom subagent prompts in `.cursor/agents/`:

- **cavecrew-builder**: Bounded 1-2 file surgical edits.
- **cavecrew-investigator**: Read-only code locator and symbol finder.
- **cavecrew-reviewer**: Read-only diff and code reviewer.
- **chore-runner**: Fast read-only information gathering and CLI tasks.
