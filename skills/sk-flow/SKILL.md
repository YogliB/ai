---
name: sk-flow
argument-hint: '[auto|manual]'
description: End-to-end slashkit workflow. Runs sk-explore, sk-alternatives, sk-planning, sk-implement, sk-review in fix mode, sk-verify, then sk-pr. Use when the user asks for /sk-flow, the full workflow, or "run the ai workflow".
---

# Flow

End-to-end flow: **Explore → Alternatives → Planning → Implementation → Review → Verify → PR**.

Only run this skill when the user explicitly asks for the workflow.

## Size triage

Once this skill is invoked, the work runs on exactly one path: **light** or **full**. Never implement outside both. Assess size first, before any phase, by reading only what you need (no `0 - EXPLORE.md`).

Light only if **all** hold; otherwise full. When unsure, full.

- at most 3 files change and roughly 50 changed lines
- no new dependency, public interface, schema, migration, or security-sensitive code
- the approach is obvious (no real alternatives to weigh)

Record the result via `init --size=<choice>` when creating the flow's `runbook.json` (or `set <dir> --size=light|full` to change an existing runbook), and give the user one line of reasoning. In `manual` mode the user may override it.

**Light path** - Explore, Alternatives, both reviews and Review are not run: `init --size=light` (or `set --size=light` on an existing runbook) marks rows `0`, `1`, `1r`, `2r`, `4` `skipped` itself — do not `set` them one by one. Rows `2`, `3`, `5`, `6` still run (row `5` may be `skipped` only when verification is blocked, with the reason, as on the full path):

1. Plan: write a short `2 - PLANNING.md` (goal, files, steps, the check command per step). No `sk-planning` template or lint — but it still needs `plan` frontmatter (`slug`, `decision`, `todos`, `review` counts; `check <file>` validates it).
2. `sk-implement`, `sk-verify`, `sk-pr` as usual. Every check runs through the receipt runner, and `3 - IMPLEMENTATION.md` and `5 - VERIFY.md` cite the receipt paths in their frontmatter `receipts` array.
3. Dispatch metadata: the light path may run its phases inline in one worker. Record `inline (light path)` via `set <dir> <row> <state> --agent="inline (light path)"`; this is the one exception to the mandatory dispatch below.

If the work grows past the criterion before implementation starts, `set <dir> --size=full` (it unskips the light rows itself) and continue on the full path. After implementation has started, stop and tell the user.

**Full path** - the phases below. Modes, state checks and dispatch metadata apply to both paths.

## Modes

- **manual** (default): ask before each phase.
- **auto**: run phases sequentially; still ask for missing critical input like the slug.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. If no slug, look for a stuck flow: any `.agents/flows/sk-*/` where the runbook has pending work. If one, suggest continuing its next pending phase or active PR. If several, list them and ask. If none, ask for a short kebab-case slug.
3. Create `.agents/flows/sk-<slug>/` if needed.
4. Start as a single-PR flow: `node scripts/flow-state.mjs init .agents/flows/sk-<slug> --slug=<slug> --goal=<goal>` (`--size=light` when triage chose the light path — `init` applies the row skips itself). Pass the slug to each phase.
5. If planning decides that the work needs multiple PRs, planning converts the root runbook via `pr <dir> <slug> --repo=<owner/repo> --init` per PR and the multi-PR contract below applies.

## State checks

The runbook is data, and the bundled state machine reads it: `node scripts/flow-state.mjs check .agents/flows/sk-<slug>` (resolved next to this SKILL.md, like templates). It validates `runbook.json` against `schemas/runbook.schema.json`, every artifact's frontmatter against its schema, and the full flow contract. Agents never hand-edit `runbook.json`: `init` creates it, `set` mutates rows and top-level fields, `pr` manages PR rows. Run `check` before starting any phase and when looking for a stuck flow, and act on its output:

- `status: error` - the recorded state contradicts this contract (bad states, missing artifacts, multiple in-progress rows or PRs, broken dependencies). Fix the state via `set`/`pr` or the files before continuing; do not continue on guessed state. `set` refuses mutations that introduce new errors but allows repairs.
- `size` (single-PR runbooks) - `light` or `full` (`full` when `size` is absent). `light` fixes which rows are skipped and requires cited, existing receipts in the implementation and verify reports' frontmatter `receipts` arrays. A full runbook cannot skip rows `2`, `3`, `4` or `6` (`pr-<slug>/` runbooks may still skip `6` — PR merged outside `sk-pr`), so the light route cannot be taken without `size: light`.
- `next` / `next-phase` - the phase to run. Never pick a phase by globbing artifacts or modification time.

## Single-PR contract

Keep the current flat flow unchanged:

```text
.agents/flows/sk-<slug>/
├── runbook.json
├── 0 - EXPLORE.md
├── 1 - ALTERNATIVES.md
├── 2 - PLANNING.md
├── 3 - IMPLEMENTATION.md
├── 4 - REVIEW.md
├── 5 - VERIFY.md
└── 6 - PR.md
```

Row states are `done`, `skipped` (with `--note` reason), `diverged` (with `--note` reason), `blocked` (with `--note` reason), `in-progress`, and `pending`.

## Multi-PR contract

Planning owns the transition from a single-PR flow to a multi-PR initiative:

```text
.agents/flows/sk-<slug>/
├── runbook.json               # initiative state and PR order
├── 0 - EXPLORE.md
├── 1 - ALTERNATIVES.md
├── 2 - PLANNING.md            # masterplan
├── pr-<stable-slug>/
│   ├── runbook.json
│   ├── 2 - PLANNING.md        # self-contained plan for this PR
│   ├── 3 - IMPLEMENTATION.md
│   ├── 4 - REVIEW.md
│   ├── 5 - VERIFY.md
│   └── 6 - PR.md
└── pr-<stable-slug>/...
```

- The root `runbook.json` holds `phases` `0–2r`, `active-pr`, and `prs` (keyed by slug). Each PR's `runbook.json` is a normal single-PR file with rows `0`, `1`, `1r` `skipped` (`initiative root`) and `size: "full"`; the light path is single-PR only.
- Derive each stable slug from the PR's purpose, not its ordinal number. Once recorded, never rename or reuse it even if PR order changes. To reorder, first update the masterplan `prs` array to the new order, then `pr <dir> <slug> --order=<n>` to match — the runbook must agree with the masterplan.
- Keep `active-pr` equal to exactly one PR slug, or `none` when the initiative is complete or blocked. `pr --state=` maintains it automatically (`in-progress` sets it; any other state on the active PR clears it). Direct `set <dir> --active-pr=<slug|none>` is for repairing a missing or stale field, not routine transitions. Downstream phases use this field and the matching `pr-<slug>/` directory; they never choose a plan from a glob or modification time.
- The root `prs` object is the source of truth for `order`, `repo`, `deps`, `state`, `branch`, `base-sha`, `head`, and `notes` (the PR URL goes in `notes`; the directory derives from the slug). `deps` lists PR slugs (`[]` = none).
- A PR is unblocked only when every dependency is `done`. Run one active PR through planning to PR before starting another.
- Before each phase, fetch refs and verify the checked-out branch and HEAD against the active PR row. Sync using the harness's supported workflow, then record the resulting HEAD in both runbooks. If safe sync is unavailable or the values disagree unexpectedly, `pr <dir> <slug> --state=blocked --notes=<reason>`; do not continue on guessed state.
- After `sk-pr`, record the PR URL, branch, base SHA, and final HEAD via `pr <dir> <slug> --state=done --branch= --base-sha= --head= --notes=<pr-url>`. Then select the first `pending` PR in order whose dependencies are all `done`: `pr <dir> <slug> --state=in-progress` (sets `active-pr`). If none is unblocked, `set <dir> --status=completed|blocked` as appropriate.
- To drop a PR, `pr <dir> <slug> --state=canceled` — a canceled PR keeps its `pr-<slug>/` directory but leaves the live ordering, dependency, and duplicate-order checks, and may be removed from the masterplan `prs` list.

## Dispatch metadata

Dispatch each phase to a fresh isolated worker. When the harness has a subagent/task mechanism this is mandatory, not optional. For the phase being executed, record its agent or session ID, parent dispatch ID or input artifact, and resulting HEAD when the phase can change the repository — `set <dir> <row> <state> --agent=<id> --input=<id> --head=<sha>`. Only when no isolated worker mechanism exists, record `--agent=inline` and explain the fallback via `--note`.

For multi-PR work, initiative coordination stays in the parent context. Phase dispatch metadata belongs in the active PR's runbook; the root table carries only cross-PR state.

## Delegating the flow or a phase

Delegate by reference, never by paraphrase. A worker prompt names the skill to invoke and carries only its inputs:

- Whole flow: the goal, the slug, the mode, and "invoke the `sk-flow` skill and follow it verbatim".
- One phase: the skill name (e.g. `sk-planning`), the slug, and the artifacts it consumes.

Never reduce a phase to "write `<N> - <NAME>.md`" or a checklist of artifacts. Artifacts are outputs, not instructions — a paraphrase silently drops every requirement that lives inside the skill (mandatory reviews, per-phase dispatch, runbook updates).

## Running one PR

1. **Explore** — `sk-explore`. Writes root `0 - EXPLORE.md`; updates row `0`.
2. (manual) Ask to continue.
3. **Alternatives** — `sk-alternatives`, including its mandatory `sk-review-alternatives` pass. Writes root `1 - ALTERNATIVES.md`; updates rows `1` and `1r`.
4. (manual) Ask to continue.
5. **Plan** — `sk-planning`, including its mandatory `sk-review-plan` loop. For one PR, writes root `2 - PLANNING.md`. For multiple PRs, writes the root masterplan, initializes each PR runbook via `pr --init`, then writes each PR directory's `2 - PLANNING.md`, and selects the first unblocked PR.
6. (manual) Ask to continue.
7. **Implement** — `sk-implement`. Writes `3 - IMPLEMENTATION.md` in the active flow or PR directory; updates row `3` there.
8. (manual) Ask to continue.
9. **Review** — `sk-review` in **fix mode**, called explicitly ("run sk-review in fix mode"); `sk-review` read-only only if the user asked for it. Writes `4 - REVIEW.md` beside the active plan; updates row `4` there.
10. (manual) Ask to continue.
11. **Verify** — `sk-verify` is required unless the agent is blocked (e.g. verification needs credentials, services, or an environment it cannot reach). Writes `5 - VERIFY.md` beside the active plan and updates row `5`; when blocked, mark row `5` `skipped` with the blocking reason and continue.
12. (manual) Ask to continue.
13. **PR** — `sk-pr`. Writes `6 - PR.md` beside the active plan; updates row `6`. Complete the single-PR flow, or update the initiative root and advance to the next unblocked PR.

## Example prompts

- `/sk-flow add-auth-token`
- `/sk-flow auto add-auth-token`
- `/sk-flow manual add-auth-token`
- `Run the full ai workflow for add-auth-token`
