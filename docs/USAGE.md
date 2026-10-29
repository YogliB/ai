# Usage

Everything runs on `sh` and core utilities — no runtimes to install. `git` helps (receipts record `git-head` when they can), and `gh` matters only to `snail-pr`.

## Install

### Claude Code

```bash
claude plugin marketplace add YogliB/snail
claude plugin install snail@snail
sh scripts/install-claude-rules.sh   # one-time: rules into ~/.claude
```

### Devin

```bash
devin plugins install YogliB/snail#plugins/snail
```

### Cursor

```bash
npx degit YogliB/snail /tmp/snail && sh /tmp/snail/scripts/install.sh
```

Copies the plugin into `~/.cursor/plugins/local/snail`. Reload the window to load it.

### Just the skills, any agent

```bash
npx skills add YogliB/snail -g                    # all skills, global
npx skills add YogliB/snail --skill snail-planning   # or just one
npx skills add YogliB/snail --list                # browse first
```

## Uninstall

```bash
claude plugin uninstall snail@snail
devin plugins remove snail
sh /tmp/snail/scripts/uninstall.sh     # cursor
npx skills remove snail-planning          # one skill
```

## Use it

Name the skill — works in any editor:

```text
Use the snail-explore skill to understand the repo.
Use the snail-alternatives skill for caching API responses.
Use the snail-planning skill to write a plan for pagination.
Use the snail-implement skill to implement the plan.
Use the snail-review skill on the current diff (say "fix" to also fix it).
Use the snail-pr skill to open a pull request.
```

| Skill                                                                     | Use when                              |
| ------------------------------------------------------------------------- | ------------------------------------- |
| [snail-explore](../skills/snail-explore/SKILL.md)                         | Understand the repo first.            |
| [snail-alternatives](../skills/snail-alternatives/SKILL.md)               | You want options before deciding.     |
| [snail-review-alternatives](../skills/snail-review-alternatives/SKILL.md) | Review a list of alternatives.        |
| [snail-planning](../skills/snail-planning/SKILL.md)                       | You want an executable plan.          |
| [snail-review-plan](../skills/snail-review-plan/SKILL.md)                 | A second opinion on a plan.           |
| [snail-implement](../skills/snail-implement/SKILL.md)                     | You have an approved plan to execute. |
| [snail-review](../skills/snail-review/SKILL.md)                           | Diff review; "fix" also fixes.        |
| [snail-verify](../skills/snail-verify/SKILL.md)                           | Prove the changes work.               |
| [snail-pr](../skills/snail-pr/SKILL.md)                                   | You want a PR.                        |
| [snail-project-docs](../skills/snail-project-docs/SKILL.md)               | Scaffold a project's docs.            |
| [snail-ai-toolbelt](../skills/snail-ai-toolbelt/SKILL.md)                 | Pointers to external tools and MCPs.  |
| [snail-flow](../skills/snail-flow/SKILL.md)                               | The full workflow, end to end.        |

### Slash commands

In Claude Code and Devin the plugin namespaces commands with `/snail:`:

```text
/snail:snail-explore add-user-auth
/snail:snail-planning add-user-auth
/snail:snail-review fix my branch
/snail:snail-pr
/snail:snail-flow auto
```

Installed a single skill with `npx skills add`? Drop the prefix: `/snail-planning`.

## The flow

```text
snail-explore → snail-alternatives → snail-planning → snail-implement → snail-review → snail-verify → snail-pr
```

`snail-flow` runs it end to end: `auto` skips confirmations, `manual` asks before each phase. Every phase is also a standalone skill — take the one you need and leave the rest.

`snail-flow` sizes the work first. A small change (a few files, no new dependency, interface, or security-sensitive code, obvious approach) takes the light path — plan, implement, verify, PR — with explore, alternatives, and the review rows skipped. Hotfix? Skip the flow entirely.

Prerequisites: a clean git tree or feature branch, write access to `.agents/flows/`, and an authenticated `gh` for the PR step.

### Flow folder

Every flow is a self-contained folder:

```text
.agents/flows/snail-<slug>/
├── runbook          # state: flat key: value lines, `at` is the cursor
├── receipts/        # proof a check ran and passed
├── 0 - EXPLORE.md
├── 1 - ALTERNATIVES.md
├── 2 - PLANNING.md
├── 3 - IMPLEMENTATION.md
├── 4 - REVIEW.md
├── 5 - VERIFY.md
└── 6 - PR.md
```

`init` writes `.agents/.gitignore` containing `flows/` — flows stay private unless you delete that line. Agents mutate `runbook` only via `skills/snail-flow/scripts/flow-state.sh`; the contract lives in [ARCHITECTURE.md](ARCHITECTURE.md).

### Phases

| #   | Skill                | Output                  | Gate                                                             |
| --- | -------------------- | ----------------------- | ---------------------------------------------------------------- |
| 0   | `snail-explore`      | `0 - EXPLORE.md`        | Artifact exists.                                                 |
| 1   | `snail-alternatives` | `1 - ALTERNATIVES.md`   | `snail-review-alternatives` runs clean; user picks an option.    |
| 2   | `snail-planning`     | `2 - PLANNING.md`       | `snail-review-plan` converges (`valid=0`), decision `proceed`.   |
| 3   | `snail-implement`    | `3 - IMPLEMENTATION.md` | Passing receipts for the per-step checks.                        |
| 4   | `snail-review`       | `4 - REVIEW.md`         | Valid findings resolved (`valid=0`).                             |
| 5   | `snail-verify`       | `5 - VERIFY.md`         | `--result=pass` + receipts; `--skip --note=<reason>` if blocked. |
| 6   | `snail-pr`           | `6 - PR.md`             | `advance` writes `at: done`, `status: completed`.                |

### Standalone entry

Every skill works alone — even a single-skill install. When `../snail-flow/scripts/flow-state.sh` is absent, skills skip every gate call and run flow-less. When it is present, `snail-explore`, `snail-alternatives`, and `snail-planning` self-start a flow via `init <dir> --slug=<s> --goal=<g> --at=<row>`; earlier rows are marked skipped with a `standalone entry` note. Downstream skills (`snail-implement`, `snail-verify`, `snail-pr`) need the previous phase's artifact, so they join a flow already in progress. `snail-review` runs flow-less either way.

### Rollback

- **Before implementation:** edit `2 - PLANNING.md` and re-run the plan review.
- **Mid-implementation:** split a too-big TODO in the plan and keep going.
- **After review:** if the plan itself is wrong, revise it and re-implement — don't patch code against a bad plan.
- **After PR:** close or update it. No force-merges.

### Agents without skills

Read the phase table, then open the matching `skills/snail-*/SKILL.md` by hand before each step.

## Layout

- Plans and flow docs live in `.agents/flows/snail-<slug>/`.
- Shared rules live in `rules/` and ship inside the Cursor and Devin plugins.
- The Devin plugin lives in `plugins/snail/`; `scripts/sync-devin-plugin.sh` syncs `skills/` and `rules/` into it.
- The Cursor plugin is the repo root: `.cursor-plugin/plugin.json` plus `skills/` and `rules/`.
- Claude Code has no plugin rules channel — `scripts/install-claude-rules.sh` copies rules into `~/.claude/snail/` and `@`-imports them from `~/.claude/CLAUDE.md`.

## Example session

```text
/snail-planning add-auth-token      # writes .agents/flows/snail-add-auth-token/2 - PLANNING.md
/snail-review fix                   # reviews and fixes the diff
/snail-pr                           # opens the PR
```

## More docs

- [README.md](../README.md) — high-level overview.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when it breaks.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — hack on it.
