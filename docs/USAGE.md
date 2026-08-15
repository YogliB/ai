# Usage

## Install

### Global

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh
```

Installs skills to `~/.agents/skills` and registers the Claude Code plugin. Requires `npx` and the `claude` CLI.

### Per-project

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh /path/to/your/repo
```

Copies skills, editor rules, the runbook, and a flow directory into the target project.

### Specific skills

```bash
# Pick skills interactively
npx skills add YogliB/ai

# Install one directly
npx skills add YogliB/ai --skill sk-planning

# Install multiple skills globally
npx skills add YogliB/ai --skill sk-planning --skill sk-verify -g
```

Run `npx skills add YogliB/ai --list` to see the list.

## Uninstall

Global and per-project use the same `uninstall.sh` script. Pass a path for per-project.

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/uninstall.sh
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/uninstall.sh /path/to/your/repo
```

## Use the skills

### By name (any editor)

```text
Use the sk-explore skill to understand the repo.
Use the sk-alternatives skill for caching API responses.
Use the sk-planning skill to write a plan for pagination.
Use the sk-review-and-fix skill on the current diff.
Use the sk-pr skill to open a pull request.
```

| Skill                                                                       | Use when                                                  |
| --------------------------------------------------------------------------- | --------------------------------------------------------- |
| [sk-explore](../.agents/skills/sk-explore/SKILL.md)                         | You need to understand the repo first.                    |
| [sk-alternatives](../.agents/skills/sk-alternatives/SKILL.md)               | You want options before deciding.                         |
| [sk-review-alternatives](../.agents/skills/sk-review-alternatives/SKILL.md) | You are reviewing a list of alternatives.                 |
| [sk-planning](../.agents/skills/sk-planning/SKILL.md)                       | You want an executable plan.                              |
| [sk-review-and-fix](../.agents/skills/sk-review-and-fix/SKILL.md)           | You want a diff reviewed and fixed.                       |
| [sk-review-dont-fix](../.agents/skills/sk-review-dont-fix/SKILL.md)         | You want a read-only review.                              |
| [sk-pr](../.agents/skills/sk-pr/SKILL.md)                                   | You want a PR.                                            |
| [sk-verify](../.agents/skills/sk-verify/SKILL.md)                           | You want to verify changes.                               |
| [sk-project-docs](../.agents/skills/sk-project-docs/SKILL.md)               | You want to scaffold a project's docs structure.          |
| [sk-ai-toolbelt](../.agents/skills/sk-ai-toolbelt/SKILL.md)                 | You want pointers to recommended external tools and MCPs. |
| [sk-flow](../.agents/skills/sk-flow/SKILL.md)                               | You want the full workflow.                               |

### With Claude Code shortcuts

When the `slash-kit` plugin is installed:

```text
/explore add-user-auth
/alternatives for caching API responses
/plan add-user-auth
/review my branch
/pr
/flow
```

| Shortcut        | What happens                                                                              |
| --------------- | ----------------------------------------------------------------------------------------- |
| `/explore`      | Invoke `sk-explore` and write `0 - EXPLORE.md` to `.agents/sk-flows/<slug>/`.             |
| `/alternatives` | Invoke `sk-alternatives` and write `1 - ALTERNATIVES.md`.                                 |
| `/plan`         | Invoke `sk-planning` and write `2 - PLANNING.md`.                                         |
| `/review`       | Invoke `sk-review-and-fix` on the current diff.                                           |
| `/pr`           | Invoke `sk-pr` to create or update a PR.                                                  |
| `/flow [mode]`  | Run the full workflow. `auto` runs without confirmation; `manual` asks before each phase. |

Shortcuts only work in Claude Code.

## Run the workflow

```text
sk-explore → sk-alternatives → sk-planning → implementation → sk-review-and-fix → optional sk-verify → sk-pr
```

Each step can run in its own subagent. The [runbook](../RUNBOOK.md) has the full procedure.

## Configuration

- Plans live in `.agents/sk-flows/<slug>/2 - PLANNING.md`.
- Claude rules live in `.claude/rules/*.md` and are loaded by `CLAUDE.md`.
- Cursor rules live in `.cursor/rules/*.mdc`.
- Devin rules live in `.devin/rules/*.md`.
- The runbook is in [RUNBOOK.md](../RUNBOOK.md).

## Example session

```text
/plan add-auth-token
# Claude writes .agents/sk-flows/add-auth-token/2 - PLANNING.md

# Implement the plan, then:
/review
# Claude reviews and fixes issues.

/pr
# Claude opens the PR.
```

## More docs

- [README.md](../README.md) — high-level overview.
- [RUNBOOK.md](../RUNBOOK.md) — end-to-end workflow.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common problems.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — setup and PR flow.
