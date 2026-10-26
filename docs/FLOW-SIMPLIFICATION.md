# Flow simplification

Status: **implemented.** `flow-state.mjs` ~1100 lines → `flow-state.sh` ~350 lines of `sh`. Initiative mode was deleted (multi-PR = one flow per PR, sequenced by the masterplan). Below is the design record.

## What the gate must guarantee (keep these, nothing else)

1. Phases run in fixed order.
2. A phase counts as done only when its artifact file exists.
3. Review cannot close with unresolved findings; verify cannot close without a passing receipt.
4. A receipt records the commit it ran on when git is present (`git-head` is evidence, not a gate input).

## Current design and its cost

- `runbook.json` carries a 9-row `phases` matrix: 6 states + `reopened` + per-row `agent`/`input`/`head`/`summary`/`note`.
- Artifacts carry gate metadata as JSON inside an HTML comment at byte 0 of each `.md` (frontmatter).
- 9 `.schema.json` files + a hand-rolled JSON Schema subset validator.
- `set`/`pr` mutate arbitrary state, so each write is guarded by clone → validate → diff error strings → refuse.
- Initiative mode: `prs` table with deps, order, cycle detection, masterplan order cross-check (~40% of the file).
- Two receipt validators: `check-receipt.sh` and `receiptPasses` in mjs — already diverged (check-receipt reads fields from the output tail; receiptPasses stops at `--- output`).
- Write-only fields nobody reads: row `agent`, `input`, `head`, `summary`, `divergences[]`.

## Target design

`runbook.json` becomes a flat `key: value` runbook (same format as receipts — `sh`-readable, no JSON parser):

```text
runbook-version: 3
slug: x
goal: g
at: 3
size: light|full
note: free-form line, repeatable
```

Four commands, one mutation:

| Command   | Does                                                                                                                                                              |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `init`    | Create runbook + dir.                                                                                                                                             |
| `check`   | Validate runbook + passed-phase artifacts + receipts; print next.                                                                                                 |
| `advance` | Only mutation: move `at` one step after current artifact validates. Takes gate fields as flags: `--result=`, `--valid=`, `--receipts=`, `--decision=`, `--note=`. |
| `note`    | Append to `notes[]` (divergence, blocked reason, reopen reason).                                                                                                  |

Deleted by this move:

- `phases` matrix, `reopened`, `skipped`/`blocked`/`diverged`/`in-progress` states (all become cursor position + notes).
- `frontmatter()` parser, `FILE_SCHEMA`, per-file schema dispatch, slug-match check.
- The error-diff-and-refuse machinery (`prior`/`after`) — arbitrary writes no longer exist.
- `--agent/--input/--head/--summary` write-only fields.
- `receiptPasses` in mjs — keep `check-receipt.sh` (fix its `get()` to stop at `--- output`), the sh gate calls it like it already calls `git`.

Optional big cut — initiative mode: delete `prs`/`deps`/`order`/cycle detection/`pr` command; multi-PR work = a directory of normal flows plus an order list. If initiatives are real for you, keep `prs` as an ordered list only.

## Light mode

Not a state mask: an allowed-cursor table (`LIGHT = [2,3,5,6]`). A jump outside it is refused by the same ordering rule. Receipts required on rows 3 and 5 always — simpler and stricter than today's light-only requirement.

## Artifacts

Bodies stay pure markdown — they are work product for humans and the next phase. Frontmatter dies; the `<!-- ... -->` block leaves all 7 templates. For human readability the body can state `## Result: pass` as unvalidated prose — stale prose cannot break a gate it does not feed.

`lint-plan.sh` degrades from gate to optional quality checklist once `decision` moves to a flag; keep it only if it still catches real drift.

## Required-field forcing is preserved

`advance` refuses until every required flag for that row is present and prints which are missing — same checklist as schema `required`, but atomic with the transition (today: artifact written, then `set` refused = drift; flags: no flags, no advance). Neither format forces honesty — the strongest evidence is a real receipt file inside the flow dir, recording a real command's pass/fail.

## Honest costs

- A detached `4 - REVIEW.md` no longer states its verdict to other tools (metadata stops traveling with the file).
- `check <file>` standalone mode dies — nothing left in a file to validate.
- One escape hatch kept: `set <dir> <key>=<value>` (e.g. `set <dir> at=<n>`) for hand-repairing a wedged runbook.

## Contained flows + zero runtime deps (decided)

- Receipts live inside the flow dir: `.agents/flows/sk-<slug>/receipts/`. The flow becomes one self-contained bundle; `resolveReceipt`'s upward walk and repo-root discovery are deleted — receipt paths resolve relative to the flow dir.
- `init` writes `.agents/.gitignore` containing `flows/` so flow state is gitignored by default. Opt-out: user deletes the line, or agent-instruction files (`AGENTS.md`) tell the agent to commit flows. Never touch the user's root `.gitignore`.
- Runtime deps: **`sh` + coreutils only.** Node and python existed only to touch JSON; with a flat KV runbook and flag-based `advance`, no JSON is left for scripts. Agents read anything natively — script-facing files are KV, agent-facing files stay markdown.
- `runbook.json` becomes flat `key: value` (same format as receipts) — rename the file to `runbook`, since `.json` would lie. Format break: bump `runbook-version` to 3 or read-both once.
- `git` becomes optional everywhere: `git-head`/`git-branch` recorded when present (`|| echo none` already exists), validators check ancestry only when a head was recorded, `check-receipt --head` skips with a warning without git.
- Rule injection **dropped** (decided): no `hooks/`, no `inject-rules.py`, no `python3`. Rules are plain files per channel — `rules/` ships inside the Cursor and Devin plugins; for Claude Code, `scripts/install-claude-rules.sh` copies `rules/*.md` (frontmatter stripped) into `~/.claude/slashkit/` and appends `@slashkit/<file>` imports to `~/.claude/CLAUDE.md`. Imported memory reaches subagent context natively, so the prompt-rewriting hook and its JSON parsing are gone. Runtime is `sh` + coreutils, `git` opportunistic — zero required interpreters beyond the shell.

## Open questions before cutting

- Does anyone actually run initiative mode? Check `.agents/flows/` history.
- Do any external tools read artifact frontmatter (dashboards, indexers, the Devin plugin at runtime)?
