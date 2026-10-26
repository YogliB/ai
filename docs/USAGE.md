# Usage

Everything runs on `sh` and core utilities — no runtimes to install. `git` helps (receipts record `git-head` when they can), and `gh` matters only to `sk-pr`.

## Install

### Claude Code

```bash
claude plugin marketplace add YogliB/ai
claude plugin install slash-kit@ai
sh scripts/install-claude-rules.sh   # one-time: rules into ~/.claude
```

### Devin

```bash
devin plugins install YogliB/ai#plugins/slash-kit
```

### Cursor

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/scripts/install.sh
```

Copies the plugin into `~/.cursor/plugins/local/slash-kit`. Reload the window to load it.

### Just the skills, any agent

```bash
npx skills add YogliB/ai -g                    # all skills, global
npx skills add YogliB/ai --skill sk-planning   # or just one
npx skills add YogliB/ai --list                # browse first
```

## Uninstall

```bash
claude plugin uninstall slash-kit@ai
devin plugins remove slash-kit
sh /tmp/ai/scripts/uninstall.sh        # cursor
npx skills remove sk-planning          # one skill
```

## Use it

Name the skill — works in any editor:

```text
Use the sk-explore skill to understand the repo.
Use the sk-alternatives skill for caching API responses.
Use the sk-planning skill to write a plan for pagination.
Use the sk-implement skill to implement the plan.
Use the sk-review skill on the current diff (say "fix" to also fix it).
Use the sk-pr skill to open a pull request.
```

| Skill                                                               | Use when                              |
| ------------------------------------------------------------------- | ------------------------------------- |
| [sk-explore](../skills/sk-explore/SKILL.md)                         | Understand the repo first.            |
| [sk-alternatives](../skills/sk-alternatives/SKILL.md)               | You want options before deciding.     |
| [sk-review-alternatives](../skills/sk-review-alternatives/SKILL.md) | Review a list of alternatives.        |
| [sk-planning](../skills/sk-planning/SKILL.md)                       | You want an executable plan.          |
| [sk-review-plan](../skills/sk-review-plan/SKILL.md)                 | A second opinion on a plan.           |
| [sk-implement](../skills/sk-implement/SKILL.md)                     | You have an approved plan to execute. |
| [sk-review](../skills/sk-review/SKILL.md)                           | Diff review; "fix" also fixes.        |
| [sk-verify](../skills/sk-verify/SKILL.md)                           | Prove the changes work.               |
| [sk-pr](../skills/sk-pr/SKILL.md)                                   | You want a PR.                        |
| [sk-project-docs](../skills/sk-project-docs/SKILL.md)               | Scaffold a project's docs.            |
| [sk-ai-toolbelt](../skills/sk-ai-toolbelt/SKILL.md)                 | Pointers to external tools and MCPs.  |
| [sk-flow](../skills/sk-flow/SKILL.md)                               | The full workflow, end to end.        |

### Slash commands

In Claude Code and Devin the plugin namespaces commands with `/slash-kit:`:

```text
/slash-kit:sk-explore add-user-auth
/slash-kit:sk-planning add-user-auth
/slash-kit:sk-review fix my branch
/slash-kit:sk-pr
/slash-kit:sk-flow auto
```

Installed a single skill with `npx skills add`? Drop the prefix: `/sk-planning`.

## The flow

```text
sk-explore → sk-alternatives → sk-planning → sk-implement → sk-review → sk-verify → sk-pr
```

`sk-flow` runs it end to end: `auto` skips confirmations, `manual` asks before each phase. Every phase is also a standalone skill — take the one you need and leave the rest.

`sk-flow` sizes the work first. A small change (a few files, no new dependency, interface, or security-sensitive code, obvious approach) takes the light path — plan, implement, verify, PR — with explore, alternatives, and the review rows skipped. Hotfix? Skip the flow entirely.

Prerequisites: a clean git tree or feature branch, write access to `.agents/flows/`, and an authenticated `gh` for the PR step.

### Flow folder

Every flow is a self-contained folder:

```text
.agents/flows/sk-<slug>/
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

`init` writes `.agents/.gitignore` containing `flows/` — flows stay private unless you delete that line. Agents mutate `runbook` only via `skills/sk-flow/scripts/flow-state.sh`; the contract lives in [ARCHITECTURE.md](ARCHITECTURE.md).

### Phases

| #   | Skill             | Output                  | Gate                                                             |
| --- | ----------------- | ----------------------- | ---------------------------------------------------------------- |
| 0   | `sk-explore`      | `0 - EXPLORE.md`        | Artifact exists.                                                 |
| 1   | `sk-alternatives` | `1 - ALTERNATIVES.md`   | `sk-review-alternatives` runs clean; user picks an option.       |
| 2   | `sk-planning`     | `2 - PLANNING.md`       | `sk-review-plan` converges (`valid=0`), decision `proceed`.      |
| 3   | `sk-implement`    | `3 - IMPLEMENTATION.md` | Passing receipts for the per-step checks.                        |
| 4   | `sk-review`       | `4 - REVIEW.md`         | Valid findings resolved (`valid=0`).                             |
| 5   | `sk-verify`       | `5 - VERIFY.md`         | `--result=pass` + receipts; `--skip --note=<reason>` if blocked. |
| 6   | `sk-pr`           | `6 - PR.md`             | `advance` writes `at: done`, `status: completed`.                |

### Standalone entry

Every skill works alone — even a single-skill install. When `../sk-flow/scripts/flow-state.sh` is absent, skills skip every gate call and run flow-less. When it is present, `sk-explore`, `sk-alternatives`, and `sk-planning` self-start a flow via `init <dir> --slug=<s> --goal=<g> --at=<row>`; earlier rows are marked skipped with a `standalone entry` note. Downstream skills (`sk-implement`, `sk-verify`, `sk-pr`) need the previous phase's artifact, so they join a flow already in progress. `sk-review` runs flow-less either way.

### Rollback

- **Before implementation:** edit `2 - PLANNING.md` and re-run the plan review.
- **Mid-implementation:** split a too-big TODO in the plan and keep going.
- **After review:** if the plan itself is wrong, revise it and re-implement — don't patch code against a bad plan.
- **After PR:** close or update it. No force-merges.

### Agents without skills

Read the phase table, then open the matching `skills/sk-*/SKILL.md` by hand before each step.

## Layout

- Plans and flow docs live in `.agents/flows/sk-<slug>/`.
- Shared rules live in `rules/` and ship inside the Cursor and Devin plugins.
- The Devin plugin lives in `plugins/slash-kit/`; `scripts/sync-devin-plugin.sh` syncs `skills/` and `rules/` into it.
- The Cursor plugin is the repo root: `.cursor-plugin/plugin.json` plus `skills/` and `rules/`.
- Claude Code has no plugin rules channel — `scripts/install-claude-rules.sh` copies rules into `~/.claude/slashkit/` and `@`-imports them from `~/.claude/CLAUDE.md`.

## Example session

```text
/sk-planning add-auth-token      # writes .agents/flows/sk-add-auth-token/2 - PLANNING.md
/sk-review fix                   # reviews and fixes the diff
/sk-pr                           # opens the PR
```

## More docs

- [README.md](../README.md) — high-level overview.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when it breaks.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — hack on it.
