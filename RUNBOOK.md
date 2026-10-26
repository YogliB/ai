# AI Workflow Runbook

End-to-end flow: **sk-explore → sk-alternatives → sk-review-alternatives → sk-planning → sk-review-plan → sk-implement → sk-review (fix mode) → sk-verify → sk-pr**.

Each step is a reusable skill. Use the whole flow or pick just the step you need. Every step writes a numbered doc into `.agents/flows/sk-<slug>/` and updates `runbook.json` via `skills/sk-flow/scripts/flow-state.mjs` (`init`/`set`/`pr`; agents never hand-edit it). The runbook is mandatory: it records what ran, what was skipped, and any divergence from the skill.

## When to use this runbook

Use the full flow when you are starting a non-trivial piece of work and want to:

- Explore options before committing to one.
- Write a durable, reviewable plan.
- Implement the plan in focused, testable steps.
- Review the implementation against the plan.
- Open a PR with the plan and review evidence in the body.

`sk-flow` triages size first: a small change (at most 3 files, ~50 lines, no new dependency, interface, schema or security-sensitive code, obvious approach) takes the light path with `size: "light"` in the runbook. Rows `0`, `1`, `1r`, `2r`, `4` are skipped, a short plan, implementation and verify with receipts, and a PR remain. Skip the runbook entirely only for hotfixes or when you are not using `sk-flow`.

## Prerequisites

- The slashkit skills and rules are installed in your project.
- You have a clean git working tree or a feature branch.
- You have permission to create files under `.agents/flows/`.
- For the PR step, `gh` is authenticated and the remote is reachable.

## Flow folder and runbook

Every flow lives in its own folder:

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

`runbook.json` is the mandatory state file. Each phase updates its row via `flow-state.mjs set`. If the agent diverges from the skill, the reason is recorded in the row's `note` and the `divergences` array. Each numbered doc starts with a `<!-- -->`-wrapped JSON frontmatter block that `flow-state.mjs check` validates against `skills/sk-flow/schemas/`.

## Step-by-step procedure

### 0. Explore

**When:** you are starting a new piece of work and need to understand the problem, scope, or repo context.

**Skill:** `sk-explore`

**Output:** `0 - EXPLORE.md` in `.agents/flows/sk-<slug>/`.

- Gather available context from the repo and user prompt.
- Recommend the next step: `sk-alternatives` (if the approach is unclear) or `sk-planning` (if the approach is clear).
- `flow-state.mjs set` row `0` to `done`.

### 1. Alternatives

**When:** you are not sure which approach to take.

**Skill:** `sk-alternatives`

**Output:** `1 - ALTERNATIVES.md` in `.agents/flows/sk-<slug>/`.

- Generate up to 3 reviewed options. In the full flow, this phase is mandatory; if there is only one viable approach, produce a `1 - ALTERNATIVES.md` that documents why.
- Run `sk-review-alternatives` on the options and resolve every `valid` finding before finalizing. This review is mandatory; do not skip it. Record it in runbook row `1r`.
- The user picks one.
- `flow-state.mjs set` row `1` to `done` (`diverged`/`blocked` need `--note`; `skipped` is only valid before `1 - ALTERNATIVES.md` exists).

### 2. Planning

**When:** you have chosen an approach and are ready to write an executable plan.

**Skill:** `sk-planning`

**Output:** `2 - PLANNING.md` in `.agents/flows/sk-<slug>/`.

- The plan must be fully executable from the file alone.
- Run `sk-review-plan` in a review loop and resolve every `valid` finding before finalizing `2 - PLANNING.md`. This review is mandatory; do not skip it. Record it in runbook row `2r`.
- `flow-state.mjs set` row `2` to `done`.

### 3. Implementation

**When:** the plan is finalized and you are ready to code.

**Skill:** `sk-implement`

**Output:** `3 - IMPLEMENTATION.md` in `.agents/flows/sk-<slug>/`.

- Executes the plan one atomic TODO at a time, with checks after each step and atomic commits.
- Plan gaps stop the work and are flagged, not improvised around.
- Deviations and gaps are documented in `3 - IMPLEMENTATION.md`; divergence also goes in `runbook.json`.
- `flow-state.mjs set` row `3` to `done`.

### 4. Review

**When:** code is implemented and tests pass.

**Skills:** `sk-review`. `sk-flow` runs it in fix mode (loop until clean); read-only mode (report only) when the user asks for it.

**Output:** `4 - REVIEW.md` in `.agents/flows/sk-<slug>/`.

- Review subagents use the plan to verify scope and acceptance.
- Fix mode: fix every valid finding before moving on.
- `flow-state.mjs set` row `4` to `done`.

### 5. Verify

**When:** always — required unless the agent is blocked (e.g. verification needs credentials, services, or an environment it cannot reach).

**Skill:** `sk-verify`

**Output:** `5 - VERIFY.md` in `.agents/flows/sk-<slug>/`.

- Run the verification steps from the plan.
- If blocked, `flow-state.mjs set` row `5` `skipped` with the blocking `--note` and continue.

### 6. PR

**When:** review is clean and verification is done.

**Skill:** `sk-pr`

**Output:** `6 - PR.md` in `.agents/flows/sk-<slug>/`.

- Create or update a GitHub pull request with the plan and review evidence reflected in the body.
- `flow-state.mjs set <dir> 6 done`, then `set <dir> --status=completed` (row and field updates are separate calls).

## Delegating to subagents

When dispatching the flow or one phase to a worker or subagent, the prompt must name the skill to invoke (e.g. `sk-flow`, `sk-planning`) plus its inputs (goal, slug, mode). Never paraphrase a phase into an artifact checklist like "write `2 - PLANNING.md`" — artifacts are outputs, and the skills carry mandatory steps (reviews, per-phase dispatch) that a paraphrase drops.

## Using just one skill

You do not have to run the full flow. Each skill is self-contained:

- `/sk-explore <slug>` or "use the sk-explore skill" — gather context and write `0 - EXPLORE.md`
- `/sk-alternatives` or "use the sk-alternatives skill" — reviewed options for any decision, writes `1 - ALTERNATIVES.md`
- `/sk-planning <slug>` or "use the sk-planning skill" — write `2 - PLANNING.md`
- "use the sk-review-plan skill" — review an existing plan
- `/sk-implement` or "use the sk-implement skill" — execute an approved plan, writes `3 - IMPLEMENTATION.md`
- `/sk-review` or "use the sk-review skill" (add "fix" for fix mode) — review the current diff, writes `4 - REVIEW.md`
- `/sk-pr` or "use the sk-pr skill" — create or update a PR, writes `6 - PR.md`
- `/sk-flow [auto|manual]` or "use the sk-flow skill" — run the full workflow

Standalone-capable skills (`sk-explore`, `sk-alternatives`, `sk-planning`) create the flow folder and runbook when missing via `flow-state.mjs init <dir> --slug=<slug> --goal=<goal> --at=<row>`; `--at` skips earlier rows and records a standalone-entry divergence. Downstream skills (`sk-implement`, `sk-verify`, `sk-pr`) require the prior phase's artifact, so they run inside an existing flow; `sk-review` can also run flow-less.

## Rollback

- **Before implementation:** if the plan is wrong, edit `2 - PLANNING.md` and re-run the planning review.
- **During implementation:** if a TODO is too big, split it into smaller TODOs in the plan and continue.
- **After review:** if a valid finding indicates the plan itself is wrong, stop implementation, revise the plan, and re-implement.
- **After PR:** if the PR is wrong, close or update it; do not force-merge.

## Escalation path

- **Skill or rule not loading:** see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
- **Skill output is wrong:** edit the skill `SKILL.md` directly and re-test.
- **Plan review never converges:** reduce plan scope or split into a masterplan and sub-plans.
- **Review finds the plan is wrong:** go back to planning before fixing code.
- **Agent diverged from the skill:** document it in the runbook and, if needed, return to the phase that diverged.

## For agents without skills

If your agent does not support skills, open this runbook and read the relevant step before starting.

The rules and skills files in this repo contain the detailed instructions for each step.
