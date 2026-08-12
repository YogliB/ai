# AI — Agent Skills and Workflows

Reusable agent skills and an optional end-to-end workflow for Claude, Cursor, and Devin.

The skills work independently. Use one skill or run the full flow.

## Before you start

You need:

- A supported agent: **Claude Code**, **Cursor**, or **Devin**.
- **Node.js** (for `npx skills` and the Claude Code `UserPromptSubmit` hook).
- For the install script: `bash`, `cp`, and a writable home directory.

## Install

### Global install (all agents)

```bash
./install.sh
```

This installs the skills into each agent's global skills directory using `npx skills`, and registers the repo as a Claude Code marketplace so the plugin (shortcuts/hooks) can be installed.

Requirements: `npx` and, for the Claude plugin, the `claude` CLI.

### Per-project install

```bash
./install.sh /path/to/your/repo
```

This copies rules, skills, and the runbook into the target project. It is the same command for Claude, Cursor, and Devin; the difference is which rules each editor reads.

### Manual install

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details on copying skills and rules by hand.

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

| Shortcut        | What happens                                                                              |
| --------------- | ----------------------------------------------------------------------------------------- |
| `/explore`      | Gather context and write a structured report to `.agents/reports/<slug>.md`.              |
| `/alternatives` | Generate and review up to 3 options, then recommend one.                                  |
| `/plan`         | Write an executable plan to `.agents/plans/<slug>.md`.                                    |
| `/review`       | Review the current diff and fix issues.                                                   |
| `/pr`           | Create or update a GitHub PR.                                                             |
| `/flow`         | Run the full `explore → alternatives → planning → implementation → review → PR` workflow. |

### Skills (any editor)

Name the skill in a prompt. For example:

```text
Use the planning skill to write a plan for adding pagination.
Use the review-and-fix skill on the current diff.
Use the pr skill to open a pull request.
```

| Skill                                                              | File                                          | Use when                                           |
| ------------------------------------------------------------------ | --------------------------------------------- | -------------------------------------------------- |
| [explore](.agents/skills/explore/SKILL.md)                         | `.agents/skills/explore/SKILL.md`             | You need to understand the problem and repo first. |
| [alternatives](.agents/skills/alternatives/SKILL.md)               | `.agents/skills/alternatives/SKILL.md`        | You want options before committing.                |
| [review-alternatives](.agents/skills/review-alternatives/SKILL.md) | `.agents/skills/review-alternatives/SKILL.md` | Reviewing a list of alternatives.                  |
| [planning](.agents/skills/planning/SKILL.md)                       | `.agents/skills/planning/SKILL.md`            | Writing an executable plan.                        |
| [review-and-fix](.agents/skills/review-and-fix/SKILL.md)           | `.agents/skills/review-and-fix/SKILL.md`      | Reviewing and fixing code.                         |
| [review-dont-fix](.agents/skills/review-dont-fix/SKILL.md)         | `.agents/skills/review-dont-fix/SKILL.md`     | Read-only review.                                  |
| [pr](.agents/skills/pr/SKILL.md)                                   | `.agents/skills/pr/SKILL.md`                  | Creating or updating a PR.                         |
| [verify](.agents/skills/verify/SKILL.md)                           | `.agents/skills/verify/SKILL.md`              | Verifying changes work and have no regressions.    |
| [ai-toolbelt](.agents/skills/ai-toolbelt/SKILL.md)                 | `.agents/skills/ai-toolbelt/SKILL.md`         | Recommended external AI tools.                     |

### Example session

```text
/plan add-auth-token
# Claude writes .agents/plans/add-auth-token.md

# Implement the plan, then:
/review
# Claude reviews the diff and fixes issues.

/pr
# Claude opens the PR.
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
explore → alternatives (optional) → planning → implementation → review → PR
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
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)       | How the pieces fit together  |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)       | Setup and PR flow            |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems              |
| [docs/SECURITY.md](docs/SECURITY.md)               | Reporting vulnerabilities    |
| [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md) | Community expectations       |

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
