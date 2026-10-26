# Usage

## Requirements

- `node` ≥18 on `PATH` (the flow-state gate, `skills/sk-flow/scripts/flow-state.mjs`, is Node stdlib only).
- `sh` for the receipt and plan-lint scripts.
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

Copies the repo's Cursor plugin (`.cursor-plugin/` manifest, `skills/`, `rules/`, `hooks/`) into `~/.cursor/plugins/local/slash-kit`. Restart Cursor or run **Developer: Reload Window** to load it. Pass a repo path (`scripts/install.sh /path/to/repo`) to also seed `RUNBOOK.md` into that project.

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

Each step runs in its own subagent; the prompt names the skill to invoke rather than paraphrasing it. The [runbook](../RUNBOOK.md) has the full procedure.

## Configuration

- Plans live in `.agents/flows/sk-<slug>/2 - PLANNING.md`.
- Shared rules live in `rules/*.md` and ship inside the Cursor and Devin plugins.
- The Devin plugin lives in `plugins/slash-kit/` (see the install section above); `scripts/sync-devin-plugin.sh` syncs `skills/`, `rules/`, and `hooks/*.py` into it.
- The Cursor plugin is the repo root: `.cursor-plugin/plugin.json` plus `skills/`, `rules/`, and `hooks/`.
- `hooks/inject-rules.py` injects the no-comments and terse-output rules where plugin rules can't reach: `sessionStart` adds them to session context (this is how Claude Code sessions get the rules — Claude plugins have no rules channel), and `preToolUse` prepends them to subagent prompts (Claude `Task`, Cursor `Task`, Devin `run_subagent`). The canonical script lives at the repo root; the Devin plugin carries a synced copy.
- The workflow doc is in [RUNBOOK.md](../RUNBOOK.md); per-flow state lives in `.agents/flows/sk-<slug>/runbook.json`, created and mutated only via `node skills/sk-flow/scripts/flow-state.mjs`.

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
- [RUNBOOK.md](../RUNBOOK.md) — end-to-end workflow.
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — common problems.
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — setup and PR flow.
