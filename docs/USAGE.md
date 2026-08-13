# Usage

## Install

There are three ways to use the `ai` skills and workflow.

### Global install (all agents)

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh
```

This installs the skills into the universal `~/.agents/skills` directory using `npx skills`, and registers the repo as a Claude Code marketplace so the plugin (shortcuts and the `UserPromptSubmit` hook) can be installed.

Requirements: `npx` and the `claude` CLI.

### Per-project install

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh /path/to/your/repo
```

This copies skills, editor rules, the runbook, and a plan directory into the target project. It is the same command for Claude, Cursor, and Devin; the difference is which rules each editor reads.

## Uninstall

### Global uninstall

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/uninstall.sh
```

This removes the skills from `~/.agents/skills`, uninstalls the `slash-kit` Claude Code plugin, and removes the `ai` marketplace.

### Per-project uninstall

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/uninstall.sh /path/to/your/repo
```

This removes the copied skills, rules, runbook, and generated `AGENTS.md`/`CLAUDE.md` files from the target project. Existing files that were modified are left in place.

### Install specific skills

Want only the skills, not the full rules/plugin bundle? Use the `skills` CLI:

```bash
# Pick skills interactively
npx skills add YogliB/ai

# Install one skill directly
npx skills add YogliB/ai --skill sk-planning

# Install multiple skills globally for all agents
npx skills add YogliB/ai --skill sk-planning --skill sk-verify -g
```

Run `npx skills add YogliB/ai --list` to see available skills.

## Use the skills

### By name (any editor)

Name the skill in a prompt. For example:

```text
Use the sk-explore skill to understand the repo.
Use the sk-alternatives skill for caching API responses.
Use the sk-planning skill to write a plan for pagination.
Use the sk-review-and-fix skill on the current diff.
Use the sk-pr skill to open a pull request.
```

| Skill                                                                       | Use when                                                  |
| --------------------------------------------------------------------------- | --------------------------------------------------------- |
| [sk-explore](../.agents/skills/sk-explore/SKILL.md)                         | You need to understand the problem and repo first.        |
| [sk-alternatives](../.agents/skills/sk-alternatives/SKILL.md)               | You want options before committing.                       |
| [sk-review-alternatives](../.agents/skills/sk-review-alternatives/SKILL.md) | You are reviewing a list of alternatives.                 |
| [sk-planning](../.agents/skills/sk-planning/SKILL.md)                       | You want an executable plan written to a file.            |
| [sk-review-and-fix](../.agents/skills/sk-review-and-fix/SKILL.md)           | You want a diff reviewed and issues fixed.                |
| [sk-review-dont-fix](../.agents/skills/sk-review-dont-fix/SKILL.md)         | You want a read-only diff review.                         |
| [sk-pr](../.agents/skills/sk-pr/SKILL.md)                                   | You want to create or update a PR.                        |
| [sk-verify](../.agents/skills/sk-verify/SKILL.md)                           | You want to verify changes and catch regressions.         |
| [sk-project-docs](../.agents/skills/sk-project-docs/SKILL.md)               | You want to scaffold or nudge a project's docs structure. |
| [sk-ai-toolbelt](../.agents/skills/sk-ai-toolbelt/SKILL.md)                 | You want pointers to recommended external tools and MCPs. |
| [sk-flow](../.agents/skills/sk-flow/SKILL.md)                               | You want to run the full end-to-end workflow.             |

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

| Shortcut        | What happens                                                                                                                                                 |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/explore`      | Invoke the `sk-explore` skill to gather context and write a structured report to `.agents/reports/<slug>.md`.                                                |
| `/alternatives` | Invoke the `sk-alternatives` skill to generate and review up to 3 options, then recommend one.                                                               |
| `/plan`         | Invoke the `sk-planning` skill to write an executable plan to `.agents/plans/<slug>.md`.                                                                     |
| `/review`       | Invoke the `sk-review-and-fix` skill to review the current diff and fix issues.                                                                              |
| `/pr`           | Invoke the `sk-pr` skill to create or update a GitHub PR.                                                                                                    |
| `/flow [mode]`  | Invoke the `sk-flow` skill to run the full workflow. In `auto` mode, run all phases without confirmation; in `manual` mode, ask before each phase (default). |

Shortcuts only work in Claude Code because they rely on the `UserPromptSubmit` hook. In Cursor or Devin, use the skill names directly or the runbook.

## Run the workflow

The optional end-to-end flow is:

```text
sk-explore → sk-alternatives (optional) → sk-planning → implementation → sk-review-and-fix (or sk-review-dont-fix) → sk-pr
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
# Claude invokes the sk-planning skill and writes .agents/plans/add-auth-token.md

# Implement the plan, then:
/review
# Claude invokes the sk-review-and-fix skill and fixes issues.

/pr
# Claude invokes the sk-pr skill and opens the PR.
```

## More docs

- [README.md](../README.md) — high-level overview and install options.
- [RUNBOOK.md](../RUNBOOK.md) — optional end-to-end workflow.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common problems.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — setup and PR flow for this repo.
