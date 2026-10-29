---
name: snail-implement
description: Execute an approved plan exactly as written, with per-step checks and atomic commits. Use when a plan from snail-planning is approved and implementation should start.
---

# Implement

Execute the plan. This skill encodes execution discipline, not coding ability: the plan is the source of truth, and the implementer's job is to follow it faithfully and prove each step works before moving on.

## When to use

- An exact `2 - PLANNING.yaml` exists in the active flow or PR directory and has been approved by the user.
- The user asks to implement, build, or execute the plan.

Do not use this skill to fill in for a missing plan. If there is no approved plan, stop and point the user to `snail-planning`.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/snail-<slug>/`.
2. Else run `node ../snail-flow/scripts/flow-state.mjs check <dir>` on each `.agents/flows/snail-*/` and pick the flow whose `next` is `3` (a standalone install skips every `flow-state.mjs` call and works flow-less). Require exact `2 - PLANNING.yaml` and missing `3 - IMPLEMENTATION.yaml`. Never select from `2 - PLANNING*.yaml` or modification time.
3. Read the plan in full before touching any file. Read `0 - EXPLORE.yaml` and `1 - ALTERNATIVES.yaml` if present, only for context; the plan overrules them on any conflict.
4. Write `3 - IMPLEMENTATION.yaml` from `../snail-flow/templates/3 - IMPLEMENTATION.yaml`, listing every receipt path cited in it, then `node ../snail-flow/scripts/flow-state.mjs advance <dir> --receipts=<a,b>` when finished.

## Execution rules

1. **Execute the plan as written** - in the plan's order, step by step. Do not reorder, merge, or skip TODOs.
2. **Check after every change** - after each TODO, run the checks the plan names for that step (build, targeted test, typecheck, lint) through the bundled receipt runner: `node scripts/run-with-receipt.mjs <dir>/receipts <label> -- <command>` (script resolved next to this SKILL.md; inside a flow, `<dir>` is the flow dir so receipts land in `<dir>/receipts/`). Do not defer checks to the end. A step is done only when its checks pass and the receipt path is recorded in the report; a check without a valid passing receipt did not happen.
3. **Stay inside the plan's scope** - touch only the files and behavior the plan names. No drive-by refactors, no cleanup of adjacent code, no extra features, no dependency changes the plan does not call for. If the plan's `Files` section exists, treat it as the allowed file set.
4. **Atomic commits per step** - one commit per TODO (or per plan-named commit unit), using the repo's commit convention. Each commit must leave the tree in a working state: checks that passed before the step still pass after it.
5. **Keep existing behavior green** - never weaken, skip, or delete an existing test to make a step pass. If an existing check fails on the untouched baseline, stop and flag it (see below) instead of working around it.

## When the plan has a gap

The plan will sometimes be wrong or incomplete: a file that does not exist where the plan says, an API that differs, a step whose checks fail for reasons the plan did not anticipate.

1. **Stop.** Do not improvise a design decision, a scope change, or a workaround that alters behavior beyond the plan.
2. **Flag it**: record the gap in `3 - IMPLEMENTATION.yaml` under `plan_gaps` - what the plan said, what the repo actually shows, what you tried.
3. Small mechanical corrections with exactly one sensible reading (a typo'd path, a renamed import the compiler names) may be applied and recorded under `deviations` with a one-line reason. Anything with two plausible readings goes to the user as a question, not a guess.
4. Resume only after the gap is resolved: by the user's answer, or by an updated plan.

## Output

`3 - IMPLEMENTATION.yaml` includes (template: `snail-flow/templates/3 - IMPLEMENTATION.yaml`):

- **plan_reference** and **branch**.
- **goal**: one line, from the plan.
- **steps**: one entry per plan TODO - what was done, the checks run, their receipt paths and results, the commit hash.
- **deviations**: every departure from the plan text, with reasons. `None` if none.
- **plan_gaps**: unresolved gaps flagged to the user, if any.
- **final_verification**: the full check suite the plan names (build, tests, lint, typecheck, format), run through the receipt runner, with receipt paths and results.
- **next_step_recommendation**: `snail-review` (fix mode inside `snail-flow`) with a one-line reason; `snail-verify` when the runbook says `size: light`.

## Exit rule

Hand off when every plan TODO is checked off with passing checks, `3 - IMPLEMENTATION.yaml` is written, and the final verification suite is green - or when a plan gap stops the work, with the gap recorded and the user asked.
