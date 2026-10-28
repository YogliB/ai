---
name: sk-flow
argument-hint: '[auto|manual]'
description: End-to-end snail workflow. Runs sk-explore, sk-alternatives, sk-planning, sk-implement, sk-review in fix mode, sk-verify, then sk-pr. Use when the user asks for /sk-flow, the full workflow, or "run the ai workflow".
---

# Flow

End-to-end flow: **Explore → Alternatives → Planning → Implementation → Review → Verify → PR**.

Only run this skill when the user explicitly asks for the workflow.

## The gate

The gate is `scripts/flow-state.sh`, resolved next to this SKILL.md (`sh scripts/flow-state.sh <command>`). It enforces three rules and nothing else:

1. Phases run in a fixed order.
2. A phase counts as done only when its artifact file exists and its required `advance` flags pass.
3. Implementation and verify must cite passing receipts that live inside the flow dir.

The runbook is `<dir>/runbook`, a flat `key: value` file (`at` is the cursor; `f.<row>.*` lines record what `advance` captured). Agents never hand-edit it: `init` creates it, `advance` moves the cursor, `note` appends a line, `set <dir> <key>=<value>` is the repair escape hatch.

## Size triage

Once this skill is invoked, the work runs on exactly one path: **light** or **full**. Never implement outside both. Assess size first, before any phase, by reading only what you need (no `0 - EXPLORE.md`).

Light only if **all** hold; otherwise full. When unsure, full.

- at most 3 files change and roughly 50 changed lines
- no new dependency, public interface, schema, migration, or security-sensitive code
- the approach is obvious (no real alternatives to weigh)

Pass the result to `init --size=<choice>` — or `set <dir> size=light|full` before any artifact exists, which resets the cursor to the new table's first row. Give the user one line of reasoning. In `manual` mode the user may override it. A light flow's rows are `2`, `3`, `5`, `6` — Explore, Alternatives, both review rows and Review are simply not part of the runbook.

## Modes

- **manual** (default): ask before each phase.
- **auto**: run phases sequentially; still ask for missing critical input like the slug.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. If no slug, look for a stuck flow: run `check` on each `.agents/flows/sk-*/` — `at` other than `done` means pending work. If one, suggest continuing its next phase. If several, list them and ask. If none, ask for a short kebab-case slug.
3. Start the flow: `sh scripts/flow-state.sh init .agents/flows/sk-<slug> --slug=<slug> --goal=<goal>` (`--size=light` when triage chose light). `init` also writes `.agents/.gitignore` so flows stay private; remove that line to commit flows. Pass the slug to each phase.

## State checks

`sh scripts/flow-state.sh check <dir>` prints `status: ok|error`, `at`, and `next-phase`. Run it before starting any phase and when looking for a stuck flow; act on its output. `status: error` means the recorded state contradicts this contract (missing artifacts, bad flag values, unexpected files) — repair via `set`/`note` or the files before continuing; never continue on guessed state. Never pick a phase by globbing artifacts or modification time.

## Phases

Rows run in order; `advance` refuses to move until the row's artifact exists and its flags pass.

| Row  | Phase               | Artifact                | Required `advance` flags                   |
| ---- | ------------------- | ----------------------- | ------------------------------------------ |
| `0`  | Explore             | `0 - EXPLORE.md`        | none                                       |
| `1`  | Alternatives        | `1 - ALTERNATIVES.md`   | none                                       |
| `1r` | Alternatives review | (same file)             | `--valid=0`                                |
| `2`  | Planning            | `2 - PLANNING.md`       | `--decision=proceed`                       |
| `2r` | Plan review         | (same file)             | `--valid=0`                                |
| `3`  | Implementation      | `3 - IMPLEMENTATION.md` | `--receipts=<a,b>`                         |
| `4`  | Review              | `4 - REVIEW.md`         | `--result=clean\|findings-fixed --valid=0` |
| `5`  | Verify              | `5 - VERIFY.md`         | `--result=pass --receipts=<a,b>`           |
| `6`  | PR                  | `6 - PR.md`             | none                                       |

- Receipts are written by `../sk-implement/scripts/run-with-receipt.sh <dir>/receipts <label> -- <command>` and cited relative to the flow dir (`receipts/<file>`). A check without a valid passing receipt did not happen.
- **Skip row 5** (verification blocked): `advance <dir> --skip --note=<reason>` — the only skippable row. Anything else needs `set` as a repair.
- **Redo a row**: `set <dir> at=<row>` (and `set <dir> status=in-progress` if the flow had completed). The next `advance` overwrites that row's recorded fields.
- **Multi-PR work**: no initiative machinery. Write the split in the plan, then run one normal flow per PR (`sk-<slug>` each); sequence them by hand.
- **Light path**: rows `2`, `3`, `5`, `6` only. A short `2 - PLANNING.md` (goal, files, steps, the check command per step) is enough — no `sk-planning` template or lint. The light path may run its phases inline in one worker.

## Dispatch metadata

Dispatch each phase to a fresh isolated worker. When the harness has a subagent/task mechanism this is mandatory, not optional — the light path is the one exception and may run inline.

## Delegating the flow or a phase

Delegate by reference, never by paraphrase. A worker prompt names the skill to invoke and carries only its inputs:

- Whole flow: the goal, the slug, the mode, and "invoke the `sk-flow` skill and follow it verbatim".
- One phase: the skill name (e.g. `sk-planning`), the slug, and the artifacts it consumes.

Never reduce a phase to "write `<N> - <NAME>.md`" or a checklist of artifacts. Artifacts are outputs, not instructions — a paraphrase silently drops every requirement that lives inside the skill (mandatory reviews, per-phase dispatch, receipts).

## Running a flow

1. **Explore** — `sk-explore`. Writes `0 - EXPLORE.md`; advances row `0`.
2. (manual) Ask to continue.
3. **Alternatives** — `sk-alternatives`, including its mandatory `sk-review-alternatives` pass. Writes `1 - ALTERNATIVES.md`; advances rows `1` and `1r`.
4. (manual) Ask to continue.
5. **Plan** — `sk-planning`, including its mandatory `sk-review-plan` loop. Writes `2 - PLANNING.md`; advances rows `2` and `2r`.
6. (manual) Ask to continue.
7. **Implement** — `sk-implement`. Writes `3 - IMPLEMENTATION.md`; advances row `3` with its receipts.
8. (manual) Ask to continue.
9. **Review** — `sk-review` in **fix mode**, called explicitly ("run sk-review in fix mode"); `sk-review` read-only only if the user asked for it. Writes `4 - REVIEW.md`; advances row `4`.
10. (manual) Ask to continue.
11. **Verify** — `sk-verify` is required unless the agent is blocked (e.g. verification needs credentials, services, or an environment it cannot reach). Writes `5 - VERIFY.md` and advances row `5`; when blocked, write no report — `advance <dir> --skip --note=<reason>` (the reason lives in the runbook) and continue.
12. (manual) Ask to continue.
13. **PR** — `sk-pr`. Writes `6 - PR.md`; advances row `6`, completing the flow.

## Example prompts

- `/sk-flow add-auth-token`
- `/sk-flow auto add-auth-token`
- `/sk-flow manual add-auth-token`
- `Run the full ai workflow for add-auth-token`
