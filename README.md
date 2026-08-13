# AI — Agent Skills and Workflows

Reusable agent skills and an optional end-to-end workflow for Claude, Cursor, and Devin.

The skills work independently. Use one skill or run the full flow.

## Quick install

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh /path/to/your/repo
```

This copies the workflow into the target project. For a global install or other options, see [Install](#install) below.

## Before you start

You need:

- A supported agent: **Claude Code**, **Cursor**, or **Devin**.
- **Node.js** (for `npx skills` and the Claude Code `UserPromptSubmit` hook).
- For the install script: `sh`, `cp`, and a writable home directory.
- For the uninstall script: `sh`, `rm`, `cmp`, `mktemp`, and a writable home directory.

## Install

### Global install (all agents)

```bash
./install.sh
```

This installs the skills into the universal `~/.agents/skills` directory using `npx skills`, and registers the repo as a Claude Code marketplace so the plugin (shortcuts/hooks) can be installed.

Requirements: `npx` and the `claude` CLI.

### Per-project install

```bash
./install.sh /path/to/your/repo
```

This copies rules, skills, and the runbook into the target project. It is the same command for Claude, Cursor, and Devin; the difference is which rules each editor reads.

## Uninstall

### Global uninstall

```bash
./uninstall.sh
```

This removes the skills from `~/.agents/skills`, uninstalls the `slash-kit` Claude Code plugin, and removes the `ai` marketplace.

### Per-project uninstall

```bash
./uninstall.sh /path/to/repo
```

This removes the copied skills, rules, runbook, and generated `AGENTS.md`/`CLAUDE.md` files from the target project. Existing files that were modified are left in place.

### Install specific skills

Want to install specific skills? `npx skills add YogliB/ai`

This prompts you to pick skills. To install one directly, use `npx skills add YogliB/ai --skill <skill-name>`. For all options, see [docs/USAGE.md](docs/USAGE.md).

## Usage

Once installed, you can use the shortcuts in Claude Code or ask the agent to follow the workflow in any editor.

### Shortcuts (Claude Code only)

When the plugin is active, these prompts expand into skill instructions:

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

### Skills (any editor)

Name the skill in a prompt. For example:

```text
Use the sk-planning skill to write a plan for adding pagination.
Use the sk-review-and-fix skill on the current diff.
Use the sk-pr skill to open a pull request.
```

| Skill                                                                    | File                                             | Use when                                           |
| ------------------------------------------------------------------------ | ------------------------------------------------ | -------------------------------------------------- |
| [sk-explore](.agents/skills/sk-explore/SKILL.md)                         | `.agents/skills/sk-explore/SKILL.md`             | You need to understand the problem and repo first. |
| [sk-alternatives](.agents/skills/sk-alternatives/SKILL.md)               | `.agents/skills/sk-alternatives/SKILL.md`        | You want options before committing.                |
| [sk-review-alternatives](.agents/skills/sk-review-alternatives/SKILL.md) | `.agents/skills/sk-review-alternatives/SKILL.md` | Reviewing a list of alternatives.                  |
| [sk-planning](.agents/skills/sk-planning/SKILL.md)                       | `.agents/skills/sk-planning/SKILL.md`            | Writing an executable plan.                        |
| [sk-review-and-fix](.agents/skills/sk-review-and-fix/SKILL.md)           | `.agents/skills/sk-review-and-fix/SKILL.md`      | Reviewing and fixing code.                         |
| [sk-review-dont-fix](.agents/skills/sk-review-dont-fix/SKILL.md)         | `.agents/skills/sk-review-dont-fix/SKILL.md`     | Read-only review.                                  |
| [sk-pr](.agents/skills/sk-pr/SKILL.md)                                   | `.agents/skills/sk-pr/SKILL.md`                  | Creating or updating a PR.                         |
| [sk-verify](.agents/skills/sk-verify/SKILL.md)                           | `.agents/skills/sk-verify/SKILL.md`              | Verifying changes work and have no regressions.    |
| [sk-project-docs](.agents/skills/sk-project-docs/SKILL.md)               | `.agents/skills/sk-project-docs/SKILL.md`        | Scaffolding or nudging a project's docs structure. |
| [sk-ai-toolbelt](.agents/skills/sk-ai-toolbelt/SKILL.md)                 | `.agents/skills/sk-ai-toolbelt/SKILL.md`         | Recommended external AI tools.                     |
| [sk-flow](.agents/skills/sk-flow/SKILL.md)                               | `.agents/skills/sk-flow/SKILL.md`                | Running the full end-to-end workflow.              |

### Example session

```text
/plan add-auth-token
# Claude invokes the sk-planning skill and writes .agents/plans/add-auth-token.md

# Implement the plan, then:
/review
# Claude invokes the sk-review-and-fix skill and fixes issues.

/pr
# Claude invokes the sk-pr skill and opens the PR.
```

## Configuration

- **Plan files** live in `.agents/plans/<slug>.md`. See [.agents/plans/README.md](.agents/plans/README.md).
- **Claude rules** live in `.claude/rules/*.md` and are loaded by `CLAUDE.md`.
- **Cursor rules** live in `.cursor/rules/*.mdc`.
- **Devin rules** live in `.devin/rules/*.md`.
- **Runbook** for the optional full flow is in [RUNBOOK.md](RUNBOOK.md).

## Workflow

The optional end-to-end flow is:

```text
sk-explore → sk-alternatives (optional) → sk-planning → implementation → sk-review-and-fix (or sk-review-dont-fix) → sk-pr
```

Each step can run in an independent subagent. The parent is a thin dispatcher. The [runbook](RUNBOOK.md) has the full procedure.

## Caveats

- **Shortcuts only work in Claude Code.** Cursor has no `UserPromptSubmit` hook equivalent; use the skill names directly or the runbook.
- **Cursor rules are project-scoped.** Install them into each repo where you want them.
- **Plan files are not committed by default.** Commit them only if your policy requires it.
- **Skills are modular.** Nothing runs the full workflow unless you explicitly ask for it.

## Documentation

| Doc                                                | Purpose                      |
| -------------------------------------------------- | ---------------------------- |
| [RUNBOOK.md](RUNBOOK.md)                           | Optional end-to-end workflow |
| [docs/USAGE.md](docs/USAGE.md)                     | Install and usage guide      |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)       | How the pieces fit together  |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)       | Setup and PR flow            |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems              |
| [docs/SECURITY.md](docs/SECURITY.md)               | Reporting vulnerabilities    |
| [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md) | Community expectations       |

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
