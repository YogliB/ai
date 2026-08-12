# Usage

## Install

There are three ways to use the `ai` skills and workflow.

### Global install (all agents)

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh
```

This installs the skills into each agent's global skills directory and registers the repo as a Claude Code marketplace so the plugin (shortcuts and the `UserPromptSubmit` hook) can be installed.

Requirements: `npx`, and for the Claude plugin, the `claude` CLI.

### Per-project install

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh /path/to/your/repo
```

This copies skills, editor rules, the runbook, and a plan directory into the target project. It is the same command for Claude, Cursor, and Devin; the difference is which rules each editor reads.

### Install specific skills

Want only the skills, not the full rules/plugin bundle? Use the `skills` CLI:

```bash
# Pick skills interactively
npx skills add YogliB/ai

# Install one skill directly
npx skills add YogliB/ai --skill planning

# Install multiple skills globally for all agents
npx skills add YogliB/ai --skill planning --skill verify -g
```

Run `npx skills add YogliB/ai --list` to see available skills.

## Use the skills

### By name (any editor)

Name the skill in a prompt. For example:

```text
Use the explore skill to understand the repo.
Use the alternatives skill for caching API responses.
Use the planning skill to write a plan for pagination.
Use the review-and-fix skill on the current diff.
Use the pr skill to open a pull request.
```

| Skill                                                                 | Use when                                                  |
| --------------------------------------------------------------------- | --------------------------------------------------------- |
| [explore](../.agents/skills/explore/SKILL.md)                         | You need to understand the problem and repo first.        |
| [alternatives](../.agents/skills/alternatives/SKILL.md)               | You want options before committing.                       |
| [review-alternatives](../.agents/skills/review-alternatives/SKILL.md) | You are reviewing a list of alternatives.                 |
| [planning](../.agents/skills/planning/SKILL.md)                       | You want an executable plan written to a file.            |
| [review-and-fix](../.agents/skills/review-and-fix/SKILL.md)           | You want a diff reviewed and issues fixed.                |
| [review-dont-fix](../.agents/skills/review-dont-fix/SKILL.md)         | You want a read-only diff review.                         |
| [pr](../.agents/skills/pr/SKILL.md)                                   | You want to create or update a PR.                        |
| [verify](../.agents/skills/verify/SKILL.md)                           | You want to verify changes and catch regressions.         |
| [project-docs](../.agents/skills/project-docs/SKILL.md)               | You want to scaffold or nudge a project's docs structure. |
| [ai-toolbelt](../.agents/skills/ai-toolbelt/SKILL.md)                 | You want pointers to recommended external tools and MCPs. |

### With Claude Code shortcuts

When the plugin is installed, type a shortcut at the start of a prompt:

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
| `/explore`      | Gather context and write a structured report to `.agents/reports/<slug>.md`.              |
| `/alternatives` | Generate and review up to 3 options, then recommend one.                                  |
| `/plan`         | Write an executable plan to `.agents/plans/<slug>.md`.                                    |
| `/review`       | Review the current diff and fix issues.                                                   |
| `/pr`           | Create or update a GitHub PR.                                                             |
| `/flow`         | Run the full `explore → alternatives → planning → implementation → review → PR` workflow. |

Shortcuts only work in Claude Code because they rely on the `UserPromptSubmit` hook. In Cursor or Devin, use the skill names directly or the runbook.

## Run the workflow

The optional end-to-end flow is:

```text
explore → alternatives (optional) → planning → implementation → review → PR
```

Each step can run in an independent subagent. The parent is a thin dispatcher. The [runbook](../RUNBOOK.md) has the full procedure.

## Configuration

- **Plan files** live in `.agents/plans/<slug>.md`. See [.agents/plans/README.md](../.agents/plans/README.md).
- **Claude rules** live in `.claude/rules/*.md` and are loaded by `CLAUDE.md`.
- **Cursor rules** live in `.cursor/rules/*.mdc`.
- **Devin rules** live in `.devin/rules/*.md`.
- **Runbook** for the optional full flow is in [RUNBOOK.md](../RUNBOOK.md).

## Example session

```text
/plan add-auth-token
# Claude writes .agents/plans/add-auth-token.md

# Implement the plan, then:
/review
# Claude reviews the diff and fixes issues.

/pr
# Claude opens the PR.
```

## More docs

- [README.md](../README.md) — high-level overview and install options.
- [RUNBOOK.md](../RUNBOOK.md) — optional end-to-end workflow.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common problems.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — setup and PR flow for this repo.
