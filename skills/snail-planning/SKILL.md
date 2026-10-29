---
name: snail-planning
description: Draft a self-contained executable technical plan with atomic testable TODOs. Required context is inlined. Use for planning rules, validation, splits, or any CreatePlan-style output.
---

# Planning

## When to use

- User asks for planning rules or wants a plan validated.
- Draft or tighten a technical plan before work starts.
- Decide whether one plan is enough or the work should split.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/snail-<slug>/`.
2. If the user gave no clear context, look for a stuck flow: one where `1 - ALTERNATIVES.yaml` exists and `2 - PLANNING*.yaml` is missing. If one, suggest continuing it. If several, list them and ask. If none, derive a short kebab-case slug from the goal and confirm.
3. Create `.agents/flows/snail-<slug>/` if needed.
4. Create the runbook if missing: `node ../snail-flow/scripts/flow-state.mjs init .agents/flows/snail-<slug> --slug=<slug> --goal=<goal> --at=2`.
5. Write a single-PR plan to `2 - PLANNING.yaml`, then `node ../snail-flow/scripts/flow-state.mjs advance <dir> --decision=proceed`, and `advance <dir> --valid=0` for row `2r` once the review loop's latest pass is clean.

A standalone install has no `../snail-flow/scripts/flow-state.mjs` or templates — skip every `init`/`advance`/`check` call and work flow-less. Before writing artifacts, add the flow dir's repo-root-relative path (usually `.agents/flows/`) on its own line to the repo's exclude file (`$(git rev-parse --git-common-dir)/info/exclude`, usually `.git/info/exclude`) if it is not there already (backslash-escaping any gitignore special characters in the path), so flow artifacts stay out of git without adding any file to the repo, the same rule `init` adds; outside a git repo there is nothing to ignore. If any flow files are already tracked, warn the user: ignore rules will not untrack them.

## Core requirements

- **Self-contained**: an implementer can execute using only this document plus a normal repo checkout. No pointer-only references to Confluence, Jira, Figma, sibling plans, or chat history.
- **Durable**: the active plan always has the exact name `2 - PLANNING.yaml` in its flow or PR directory, so later phases never guess from a glob.
- **Inlined context**: API/data shapes, field mappings, env vars, flags, acceptance thresholds, before→after snippets, cross-PR contracts, and verification commands. Links are only optional attribution after the facts are inlined.
- **Executable**: every step can be done without guessing missing context.
- **Atomic TODOs**: each `implementation_todos` item is one focused, testable action.
- **Files near top**: a `files` key right after `goal` lists every path expected to change (repo-relative, no descriptions).
- **No cross-plan or cross-repo references** unless required and fully inlined.
- **Verified paths**: every file path and line number is re-checked against the repo before finalizing.

## Clarification gates

- Before planning: drive ambiguity under ~10%. List unknowns as assumptions with acceptance impact.
- Before acting: under ~5%. Use concrete assumptions instead of percentages when uncertain.

## Pre-finalization pass

Note meaningful chances for refactors, performance, or security — even if deferred, capture them in Risks or a short follow-up list.

## Self-audit before review

- The structure lint passes on every emitted document: `node scripts/lint-plan.mjs <plan file>` (bundled next to this SKILL.md, Node 24+ required), with `--masterplan` for the masterplan and `--allow-draft` for draft-only plans that omit `branch_setup`, `delivery`, and `complexity_check`. A plan that fails the lint is not ready for the review loop.
- `context` snippets are current code, not desired state.
- Every file path and line number was verified.
- Test changes name the runner and expected call count.
- Implementation order does not create a broken intermediate state.
- `implementation_todos` depth stays at 2 or less (one `subtasks` level).

## Plan shape

- **one repo, one PR** → use `templates/plan.yaml`.
- **multi-repo or multi-PR** → write `templates/masterplan.yaml` as the decision record, then run each PR as its own normal flow (`snail-<slug>` per PR, one `templates/plan.yaml` each). Sub-plans repeat every fact they need from the masterplan.

## Complexity split

Use a masterplan + sub-plans (one per PR) if any of these hold:

- More than one repo or more than one PR.
- Implementation TODO count > 30 (items under `implementation_todos`, subtasks included).
- Depth > 2 (nesting under that same key).
- High-risk items > 5 (distinct risk entries).

The `complexity_check` fields `cross_deps` and total counts inform a `proceed` or `split` decision; they do not force a split by themselves (multi-repo / multi-PR always does).

## Template enforcement

- Include every key from `templates/plan.yaml` in file order: goal, files, context, scope, risks, dependencies, priority, logging_observability, branch_setup, implementation_todos, delivery, docs, testing, verification, acceptance, fallback_plan, references, complexity_check (omit only if the user narrows scope).
- Fill `complexity_check` with real counts and an explicit `proceed` or `split` decision.
- Keep `implementation_todos` depth at 2 or less; flatten nested subtasks that are details, not independent TODOs.
- Aim for ~95% TODO coverage of in-scope work.
- Use consistent YAML; every value filled, no `{{...}}` placeholders left.

## Testing discipline

- Run related tests after each implementation TODO; fix failures before moving on.
- Name the runner/producer and confirm expected call counts for test changes.
- Order TODOs so test and dependency changes land before code that would break or hang them.

## Plan review loop (mandatory)

After the plan matches the template and the pre-finalization pass is done, review every emitted document until the latest pass has zero `valid` findings.

1. **Review** — dispatch a new `readonly` `general-purpose` Task subagent and run the `snail-review-plan` skill on the full plan text (paste the plan; do not point at files).
2. **Triage** — label each finding `valid`, `false_positive`, or `unvalidated` with a one-line reason.
3. **Fix** — resolve every `valid` finding before the next review. Prefer minimal edits.
4. **Repeat** — dispatch a new subagent on the updated plan. Continue until the latest pass is clean.

**Exit rule:** hand off when the latest pass is `Lean & valid. Ship.` or has zero `valid` findings after triage (all `false_positive` or all `unvalidated`).

## Delivery notes

- Omit `branch_setup`, `delivery`, and `complexity_check` for draft-only or design-only plans (lint with `--allow-draft`).
- Defer commit/push to operator/repo policy.
- If the repo uses an interactive workflow, present the plan in small chunks first; the final artifact can still match the full template once agreed.
- Size each implementation TODO for one focused agent dispatch; split or run multiple cycles if larger.

## Scope boundary

Planning covers what to build, how to sequence it, delivery shape, and plan review. Code review of the implementation is not part of this skill.

## Plan file output

### Single PR

- Plan: `.agents/flows/snail-<slug>/2 - PLANNING.yaml`
- `advance <dir> --decision=proceed` and `advance <dir> --valid=0` (row `2r`).

### Multiple PRs

- Masterplan: `.agents/flows/snail-<slug>/2 - PLANNING.yaml` naming every PR and its slug.
- Each PR is its own flow: `node ../snail-flow/scripts/flow-state.mjs init .agents/flows/snail-<pr-slug> --slug=<pr-slug> --goal=<goal> --at=2`, then write that flow's `2 - PLANNING.yaml` from `templates/plan.yaml` and advance it normally. PRs run one at a time, in masterplan order.
- Do not emit suffixed `2 - PLANNING-*.yaml` files. Each flow has one unambiguous `2 - PLANNING.yaml`.

Do not commit or push unless requested.

## Next step

Once the user approves the plan, hand off to `snail-implement`.

## Bundled templates

- `templates/plan.yaml`
- `templates/masterplan.yaml`

If the repo keeps copies under `.cursor/templates/`, update those in the same change.
