---
name: snail-flow
argument-hint: '[auto|manual]'
description: End-to-end snail workflow. Runs snail-explore, snail-alternatives, snail-planning, snail-implement, snail-review in fix mode, snail-verify, then snail-pr. Use when the user asks for /snail-flow, the full workflow, or "run the ai workflow".
---

# Flow

End-to-end flow: **Explore → Alternatives → Planning → Implementation → Review → Verify → PR**.

Only run this skill when the user explicitly asks for the workflow.

## The gate

The gate is `scripts/flow-state.mjs`, resolved next to this SKILL.md (`node scripts/flow-state.mjs <command>`; Node 24+ required). It enforces three rules and nothing else:

1. Phases run in a fixed order.
2. A phase counts as done only when its artifact file exists and its required `advance` flags pass.
3. Implementation and verify must cite passing receipts that live inside the flow dir.

The runbook is `<dir>/runbook.yaml` (`at` is the cursor; `rows.<row>.*` records what `advance` captured; `notes` is the appended log). Agents never hand-edit it: `init` creates it, `advance` moves the cursor, `note` appends an entry, `set <dir> <key>=<value>` is the repair escape hatch (`f.<row>.<field>` addresses a row field).

## Size triage

Once this skill is invoked, the work runs on exactly one path: **light** or **full**. Never implement outside both. Assess size first, before any phase, by reading only what you need (no `0 - EXPLORE.yaml`).

Light only if **all** hold; otherwise full. When unsure, full.

- at most 3 files change and roughly 50 changed lines
- no new dependency, public interface, schema, migration, or security-sensitive code
- the approach is obvious (no real alternatives to weigh)

Pass the result to `init --size=<choice>` — or `set <dir> size=light|full` before any artifact exists, which resets the cursor to the new table's first row. Give the user one line of reasoning. In `manual` mode the user may override it. A light flow's rows are `2`, `3`, `5`, `6` — Explore, Alternatives, both review rows and Review are simply not part of the runbook.

## Modes

- **manual** (default): ask before each phase.
- **auto**: run phases sequentially; still ask for missing critical input like the slug.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/snail-<slug>/`.
2. If no slug, look for a stuck flow: run `check` on each `.agents/flows/snail-*/` — `at` other than `done` means pending work. If one, suggest continuing its next phase. If several, list them and ask. If none, ask for a short kebab-case slug.
3. Start the flow: `node scripts/flow-state.mjs init .agents/flows/snail-<slug> --slug=<slug> --goal=<goal>` (`--size=light` when triage chose light). `init` also writes `.agents/.gitignore` so flows stay private; remove that line to commit flows. Pass the slug to each phase.

## State checks

`node scripts/flow-state.mjs check <dir>` prints `status: ok|error`, `at`, and `next-phase`. Run it before starting any phase and when looking for a stuck flow; act on its output. `status: error` means the recorded state contradicts this contract (missing artifacts, bad flag values, unexpected files) — repair via `set`/`note` or the files before continuing; never continue on guessed state. Never pick a phase by globbing artifacts or modification time.

## Phases

Rows run in order; `advance` refuses to move until the row's artifact exists and its flags pass.

| Row  | Phase               | Artifact                  | Required `advance` flags                   |
| ---- | ------------------- | ------------------------- | ------------------------------------------ |
| `0`  | Explore             | `0 - EXPLORE.yaml`        | none                                       |
| `1`  | Alternatives        | `1 - ALTERNATIVES.yaml`   | none                                       |
| `1r` | Alternatives review | (same file)               | `--valid=0`                                |
| `2`  | Planning            | `2 - PLANNING.yaml`       | `--decision=proceed`                       |
| `2r` | Plan review         | (same file)               | `--valid=0`                                |
| `3`  | Implementation      | `3 - IMPLEMENTATION.yaml` | `--receipts=<a,b>`                         |
| `4`  | Review              | `4 - REVIEW.yaml`         | `--result=clean\|findings-fixed --valid=0` |
| `5`  | Verify              | `5 - VERIFY.yaml`         | `--result=pass --receipts=<a,b>`           |
| `6`  | PR                  | `6 - PR.yaml`             | none                                       |

- Receipts are YAML written by `node ../snail-implement/scripts/run-with-receipt.mjs <dir>/receipts <label> -- <command>` and cited relative to the flow dir (`receipts/<file>`). A check without a valid passing receipt did not happen.
- **Skip row 5** (verification blocked): `advance <dir> --skip --note=<reason>` — the only skippable row. Anything else needs `set` as a repair.
- **Redo a row**: `set <dir> at=<row>` (and `set <dir> status=in-progress` if the flow had completed). The next `advance` overwrites that row's recorded fields.
- **Multi-PR work**: no initiative machinery. Write the split in the plan, then run one normal flow per PR (`snail-<slug>` each); sequence them by hand.
- **Light path**: rows `2`, `3`, `5`, `6` only. A short `2 - PLANNING.yaml` (goal, files, steps, the check command per step) is enough — no `snail-planning` template or lint. The light path may run its phases inline in one worker.

## Dispatch metadata

Dispatch each phase to a fresh isolated worker. When the harness has a subagent/task mechanism this is mandatory, not optional — the light path is the one exception and may run inline.

## Delegating the flow or a phase

Delegate by reference, never by paraphrase. A worker prompt names the skill to invoke and carries only its inputs:

- Whole flow: the goal, the slug, the mode, and "invoke the `snail-flow` skill and follow it verbatim".
- One phase: the skill name (e.g. `snail-planning`), the slug, and the artifacts it consumes.

Never reduce a phase to "write `<N> - <NAME>.yaml`" or a checklist of artifacts. Artifacts are outputs, not instructions — a paraphrase silently drops every requirement that lives inside the skill (mandatory reviews, per-phase dispatch, receipts).

## Running a flow

1. **Explore** — `snail-explore`. Writes `0 - EXPLORE.yaml`; advances row `0`.
2. (manual) Ask to continue.
3. **Alternatives** — `snail-alternatives`, including its mandatory `snail-review-alternatives` pass. Writes `1 - ALTERNATIVES.yaml`; advances rows `1` and `1r`.
4. (manual) Ask to continue.
5. **Plan** — `snail-planning`, including its mandatory `snail-review-plan` loop. Writes `2 - PLANNING.yaml`; advances rows `2` and `2r`.
6. (manual) Ask to continue.
7. **Implement** — `snail-implement`. Writes `3 - IMPLEMENTATION.yaml`; advances row `3` with its receipts.
8. (manual) Ask to continue.
9. **Review** — `snail-review` in **fix mode**, called explicitly ("run snail-review in fix mode"); `snail-review` read-only only if the user asked for it. Writes `4 - REVIEW.yaml`; advances row `4`.
10. (manual) Ask to continue.
11. **Verify** — `snail-verify` is required unless the agent is blocked (e.g. verification needs credentials, services, or an environment it cannot reach). Writes `5 - VERIFY.yaml` and advances row `5`; when blocked, write no report — `advance <dir> --skip --note=<reason>` (the reason lives in the runbook) and continue.
12. (manual) Ask to continue.
13. **PR** — `snail-pr`. Writes `6 - PR.yaml`; advances row `6`, completing the flow.

## Example prompts

- `/snail-flow add-auth-token`
- `/snail-flow auto add-auth-token`
- `/snail-flow manual add-auth-token`
- `Run the full ai workflow for add-auth-token`
