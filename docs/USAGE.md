# Usage

## Requirements

- `sh` and core utilities — the flow-state gate, receipt runner, and plan lint are shell scripts.
- `git` when the work is versioned (receipts record `git-head` opportunistically; `check-receipt --head` is opt-in).
- `gh` for `sk-pr` only.

## Install

### Claude Code plugin

```bash
claude plugin marketplace add YogliB/ai
claude plugin install slash-kit@ai
```

Installs the slash-kit plugin: the skills plus `/sk-*` slash commands.

### Devin plugin

```bash
devin plugins install YogliB/ai#plugins/slash-kit
```

Installs all skills as one plugin from `plugins/slash-kit/`. Requires access to Devin's plugin beta.

### Global skills

```bash
npx skills add YogliB/ai -g
```

Installs the skills globally for every agent the skills CLI supports. Requires `npx`.

### Cursor (plugin)

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/scripts/install.sh
```

Copies the repo's Cursor plugin (`.cursor-plugin/` manifest, `skills/`, `rules/`) into `~/.cursor/plugins/local/slash-kit`. Restart Cursor or run **Developer: Reload Window** to load it.

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

### Claude Code plugin

```bash
claude plugin uninstall slash-kit@ai
claude plugin marketplace remove ai
```

### Devin plugin

```bash
devin plugins remove slash-kit
```

### Cursor (plugin)

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/scripts/uninstall.sh
```

Removes `~/.cursor/plugins/local/slash-kit`.

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
Use the sk-implement skill to implement the plan.
Use the sk-review skill on the current diff (say "fix" for fix mode).
Use the sk-pr skill to open a pull request.
```

| Skill                                                               | Use when                                                  |
| ------------------------------------------------------------------- | --------------------------------------------------------- |
| [sk-explore](../skills/sk-explore/SKILL.md)                         | You need to understand the repo first.                    |
| [sk-alternatives](../skills/sk-alternatives/SKILL.md)               | You want options before deciding.                         |
| [sk-review-alternatives](../skills/sk-review-alternatives/SKILL.md) | You are reviewing a list of alternatives.                 |
| [sk-planning](../skills/sk-planning/SKILL.md)                       | You want an executable plan.                              |
| [sk-review-plan](../skills/sk-review-plan/SKILL.md)                 | You want a second opinion on a plan.                      |
| [sk-implement](../skills/sk-implement/SKILL.md)                     | You have an approved plan to execute.                     |
| [sk-review](../skills/sk-review/SKILL.md)                           | You want a diff reviewed; say "fix" to also fix it.       |
| [sk-pr](../skills/sk-pr/SKILL.md)                                   | You want a PR.                                            |
| [sk-verify](../skills/sk-verify/SKILL.md)                           | You want to verify changes.                               |
| [sk-project-docs](../skills/sk-project-docs/SKILL.md)               | You want to scaffold a project's docs structure.          |
| [sk-ai-toolbelt](../skills/sk-ai-toolbelt/SKILL.md)                 | You want pointers to recommended external tools and MCPs. |
| [sk-flow](../skills/sk-flow/SKILL.md)                               | You want the full workflow.                               |

### In Claude Code

Plugin skills are namespaced:

```text
/slash-kit:sk-explore add-user-auth
/slash-kit:sk-alternatives for caching API responses
/slash-kit:sk-planning add-user-auth
/slash-kit:sk-review fix my branch
/slash-kit:sk-pr
/slash-kit:sk-flow
```

Installed a skill individually with `npx skills add`? Drop the `/slash-kit:` prefix (`/sk-planning`).

| Slash command                 | What happens                                                                              |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| `/slash-kit:/sk-explore`      | Invoke `sk-explore` and write `0 - EXPLORE.md` to `.agents/flows/sk-<slug>/`.             |
| `/slash-kit:/sk-alternatives` | Invoke `sk-alternatives` and write `1 - ALTERNATIVES.md`.                                 |
| `/slash-kit:/sk-planning`     | Invoke `sk-planning` and write `2 - PLANNING.md`.                                         |
| `/slash-kit:/sk-review`       | Invoke `sk-review` on the current diff.                                                   |
| `/slash-kit:/sk-pr`           | Invoke `sk-pr` to create or update a PR.                                                  |
| `/slash-kit:/sk-flow [mode]`  | Run the full workflow. `auto` runs without confirmation; `manual` asks before each phase. |

### In Devin

With the plugin installed, prefix the skill name with `/slash-kit:`:

```text
/slash-kit:sk-explore add-user-auth
/slash-kit:sk-planning add-user-auth
/slash-kit:sk-implement
/slash-kit:sk-review fix
/slash-kit:sk-pr
/slash-kit:sk-flow
```

## Run the workflow

```text
sk-explore → sk-alternatives → sk-review-alternatives → sk-planning → sk-review-plan → sk-implement → sk-review (fix mode) → sk-verify → sk-pr
```

Each phase is a self-contained skill: run the whole flow via `sk-flow`, or pick just the step you need. In the full flow each phase runs in its own subagent, and the worker prompt names the skill to invoke plus its inputs (goal, slug, mode) — never paraphrase a phase into an artifact checklist, since that drops the mandatory steps inside the skill.

### When to use the full flow

Use it for non-trivial work when you want to explore options before committing, write a durable reviewable plan, implement in focused testable steps, review the implementation against the plan, and open a PR with the evidence in the body.

`sk-flow` triages size first: a small change (at most 3 files, ~50 lines, no new dependency, interface, schema or security-sensitive code, obvious approach) takes the light path with `size: light` in the runbook — explore, alternatives, and the reviews are skipped; a short plan, implementation, verify with receipts, and a PR remain. Skip the flow entirely only for hotfixes.

Prerequisites: a clean git tree or feature branch, write access to `.agents/flows/`, and an authenticated `gh` for the PR step.

### Flow folder

Every flow lives in its own folder:

```text
.agents/flows/sk-<slug>/
├── runbook
├── receipts/
├── 0 - EXPLORE.md
├── 1 - ALTERNATIVES.md
├── 2 - PLANNING.md
├── 3 - IMPLEMENTATION.md
├── 4 - REVIEW.md
├── 5 - VERIFY.md
└── 6 - PR.md
```

`runbook` is the mandatory state file — flat `key: value` lines where `at` is the cursor and `f.<row>.*` records what each `advance` captured. Agents mutate it only via `skills/sk-flow/scripts/flow-state.sh` (`init`, `advance`, `note`, `set`); see [ARCHITECTURE.md](ARCHITECTURE.md) for the validation contract. `init` writes `.agents/.gitignore` so flows stay private; remove that line to commit flows.

### Phases

| #   | Skill             | Output                  | Required before the row is `done`                                                       |
| --- | ----------------- | ----------------------- | --------------------------------------------------------------------------------------- |
| 0   | `sk-explore`      | `0 - EXPLORE.md`        | Recommends `sk-alternatives` (approach unclear) or `sk-planning`.                       |
| 1   | `sk-alternatives` | `1 - ALTERNATIVES.md`   | `sk-review-alternatives` runs (row `1r`); the user picks an option.                     |
| 2   | `sk-planning`     | `2 - PLANNING.md`       | `sk-review-plan` loop until no `valid` findings (row `2r`).                             |
| 3   | `sk-implement`    | `3 - IMPLEMENTATION.md` | Atomic TODOs with checks and commits; plan gaps stop work, not improv.                  |
| 4   | `sk-review`       | `4 - REVIEW.md`         | Fix mode in `sk-flow`: fix every valid finding before moving on.                        |
| 5   | `sk-verify`       | `5 - VERIFY.md`         | `advance --result=pass --receipts=<a,b>`; if blocked, `advance --skip --note=<reason>`. |
| 6   | `sk-pr`           | `6 - PR.md`             | `advance` completes the flow (`at: done`, `status: completed`).                         |

### Single skills and standalone entry

Every skill is self-contained and usable alone — including a single-skill install (`npx skills add YogliB/ai --skill sk-planning`): when `../sk-flow/scripts/flow-state.sh` is absent, the skill skips every gate call and works flow-less. When it is present, standalone-capable skills (`sk-explore`, `sk-alternatives`, `sk-planning`) create the flow folder and runbook when missing via `init <dir> --slug=<slug> --goal=<goal> --at=<row>`; `--at` marks earlier rows skipped with a `standalone entry` note. Downstream skills (`sk-implement`, `sk-verify`, `sk-pr`) require the prior phase's artifact, so they run inside an existing flow; `sk-review` can also run flow-less.

### Rollback

- **Before implementation:** edit `2 - PLANNING.md` and re-run the plan review.
- **During implementation:** split a too-big TODO into smaller TODOs in the plan and continue.
- **After review:** if a valid finding means the plan itself is wrong, revise the plan and re-implement.
- **After PR:** close or update the PR; do not force-merge.

### Agents without skills

If your agent cannot load skills, read the phase list above and open the relevant `skills/sk-*/SKILL.md` manually before each step.

## Configuration

- Plans live in `.agents/flows/sk-<slug>/2 - PLANNING.md`.
- Shared rules live in `rules/*.md` and ship inside the Cursor and Devin plugins.
- The Devin plugin lives in `plugins/slash-kit/` (see the install section above); `scripts/sync-devin-plugin.sh` syncs `skills/` and `rules/` into it.
- The Cursor plugin is the repo root: `.cursor-plugin/plugin.json` plus `skills/` and `rules/`.
- Claude Code has no plugin rules channel: `scripts/install-claude-rules.sh` copies `rules/*.md` (frontmatter stripped) into `~/.claude/slashkit/` and appends `@slashkit/<file>` imports to `~/.claude/CLAUDE.md`.
- Per-flow state lives in `.agents/flows/sk-<slug>/runbook`, created and mutated only via `sh skills/sk-flow/scripts/flow-state.sh`.

## Example session

```text
/sk-planning add-auth-token
# Claude writes .agents/flows/sk-add-auth-token/2 - PLANNING.md

# Implement the plan, then:
/sk-review fix
# Claude reviews and fixes issues.

/sk-pr
# Claude opens the PR.
```

## More docs

- [README.md](../README.md) — high-level overview.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common problems.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — setup and PR flow.
