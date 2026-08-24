# Usage

## Install

### Global

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh
```

Installs skills to `~/.agents/skills` and registers the Claude Code plugin if `claude` is installed. Requires `npx`.

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

### Full install

If you used `install.sh`, use `uninstall.sh`:

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/uninstall.sh
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/uninstall.sh /path/to/your/repo
```

### Specific skills

If you used `npx skills add`, remove with `npx skills remove`:

```bash
npx skills remove sk-planning
npx skills remove -g sk-planning
npx skills remove --all
```

## Use the skills

### By name (any editor)

```text
Use the sk-explore skill to understand the repo.
Use the sk-alternatives skill for caching API responses.
Use the sk-planning skill to write a plan for pagination.
Use the sk-review-plan skill to review the plan.
Use the sk-review-and-fix skill on the current diff.
Use the sk-pr skill to open a pull request.
```

| Skill                                                                       | Use when                                                  |
| --------------------------------------------------------------------------- | --------------------------------------------------------- |
| [sk-explore](../.agents/skills/sk-explore/SKILL.md)                         | You need to understand the repo first.                    |
| [sk-alternatives](../.agents/skills/sk-alternatives/SKILL.md)               | You want options before deciding.                         |
| [sk-review-alternatives](../.agents/skills/sk-review-alternatives/SKILL.md) | You are reviewing a list of alternatives.                 |
| [sk-planning](../.agents/skills/sk-planning/SKILL.md)                       | You want an executable plan.                              |
| [sk-review-plan](../.agents/skills/sk-review-plan/SKILL.md)                 | You want a second opinion on a plan.                      |
| [sk-review-and-fix](../.agents/skills/sk-review-and-fix/SKILL.md)           | You want a diff reviewed and fixed.                       |
| [sk-review](../.agents/skills/sk-review/SKILL.md)                           | You want a read-only review.                              |
| [sk-pr](../.agents/skills/sk-pr/SKILL.md)                                   | You want a PR.                                            |
| [sk-verify](../.agents/skills/sk-verify/SKILL.md)                           | You want to verify changes.                               |
| [sk-project-docs](../.agents/skills/sk-project-docs/SKILL.md)               | You want to scaffold a project's docs structure.          |
| [sk-ai-toolbelt](../.agents/skills/sk-ai-toolbelt/SKILL.md)                 | You want pointers to recommended external tools and MCPs. |
| [sk-flow](../.agents/skills/sk-flow/SKILL.md)                               | You want the full workflow.                               |

### In Claude Code

Type the skill name as a slash command:

```text
/sk-explore add-user-auth
/sk-alternatives for caching API responses
/sk-planning add-user-auth
/sk-review-and-fix my branch
/sk-pr
/sk-flow
```

| Slash command        | What happens                                                                              |
| -------------------- | ----------------------------------------------------------------------------------------- |
| `/sk-explore`        | Invoke `sk-explore` and write `0 - EXPLORE.md` to `.agents/flows/sk-<slug>/`.             |
| `/sk-alternatives`   | Invoke `sk-alternatives` and write `1 - ALTERNATIVES.md`.                                 |
| `/sk-planning`       | Invoke `sk-planning` and write `2 - PLANNING.md`.                                         |
| `/sk-review-and-fix` | Invoke `sk-review-and-fix` on the current diff.                                           |
| `/sk-pr`             | Invoke `sk-pr` to create or update a PR.                                                  |
| `/sk-flow [mode]`    | Run the full workflow. `auto` runs without confirmation; `manual` asks before each phase. |

Slash commands only work in Claude Code.

## Run the workflow

```text
sk-explore → sk-alternatives → sk-planning → implementation → sk-review-and-fix → optional sk-verify → sk-pr
```

Each step can run in its own subagent. The [runbook](../RUNBOOK.md) has the full procedure.

## Configuration

- Plans live in `.agents/flows/sk-<slug>/2 - PLANNING.md`.
- Claude rules live in `.claude/rules/*.md` and are loaded by `CLAUDE.md`.
- Cursor rules live in `.cursor/rules/*.mdc`.
- Devin rules live in `.devin/rules/*.md`.
- The runbook is in [RUNBOOK.md](../RUNBOOK.md).

## Example session

```text
/sk-planning add-auth-token
# Claude writes .agents/flows/sk-add-auth-token/2 - PLANNING.md

# Implement the plan, then:
/sk-review-and-fix
# Claude reviews and fixes issues.

/sk-pr
# Claude opens the PR.
```

## More docs

- [README.md](../README.md) — high-level overview.
- [RUNBOOK.md](../RUNBOOK.md) — end-to-end workflow.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common problems.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — setup and PR flow.
