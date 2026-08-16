# AI Workflow Runbook

End-to-end flow: **sk-explore → sk-alternatives → sk-planning → implementation → sk-review-and-fix (or sk-review) → optional sk-verify → sk-pr**.

Each step is a reusable skill. Use the whole flow or pick just the step you need. Every step writes a numbered doc into `.agents/sk-flows/<slug>/` and updates the `RUNBOOK.md` checklist. The runbook is mandatory: it records what ran, what was skipped, and any divergence from the skill.

## When to use this runbook

Use the full flow when you are starting a non-trivial piece of work and want to:

- Explore options before committing to one.
- Write a durable, reviewable plan.
- Implement the plan in focused, testable steps.
- Review the implementation against the plan.
- Open a PR with the plan and review evidence in the body.

Do not use the full flow for trivial changes, hotfixes, or when you already know exactly what to do.

## Prerequisites

- The `slash-kit` plugin or rules are installed in your project.
- You have a clean git working tree or a feature branch.
- You have permission to create files under `.agents/sk-flows/`.
- For the PR step, `gh` is authenticated and the remote is reachable.

## Flow folder and runbook

Every flow lives in its own folder:

```text
.agents/sk-flows/<slug>/
├── RUNBOOK.md
├── 0 - EXPLORE.md
├── 1 - ALTERNATIVES.md
├── 2 - PLANNING.md
├── 3 - IMPLEMENTATION.md
├── 4 - REVIEW.md
├── 5 - VERIFY.md
└── 6 - PR.md
```

`RUNBOOK.md` is a mandatory checklist. Each phase updates its row. If the agent diverges from the skill, the reason is recorded in the `Divergence / Notes` column and the `Divergence log` section.

## Step-by-step procedure

### 0. Explore

**When:** you are starting a new piece of work and need to understand the problem, scope, or repo context.

**Skill:** `sk-explore`

**Output:** `0 - EXPLORE.md` in `.agents/sk-flows/<slug>/`.

- Gather available context from the repo and user prompt.
- Recommend the next step: `sk-alternatives` (if the approach is unclear) or `sk-planning` (if the approach is clear).
- Update `RUNBOOK.md` row `0` to `done`.

### 1. Alternatives

**When:** you are not sure which approach to take.

**Skill:** `sk-alternatives`

**Output:** `1 - ALTERNATIVES.md` in `.agents/sk-flows/<slug>/`.

- Generate up to 3 reviewed options. In the full flow, this phase is mandatory; if there is only one viable approach, produce a `1 - ALTERNATIVES.md` that documents why.
- The options are first reviewed by the `sk-review-alternatives` skill to catch irrelevant, duplicate, or weak options.
- The user picks one.
- Update `RUNBOOK.md` row `1` to `done` or `skipped` with reason.

### 2. Planning

**When:** you have chosen an approach and are ready to write an executable plan.

**Skill:** `sk-planning`

**Output:** `2 - PLANNING.md` in `.agents/sk-flows/<slug>/`.

- The plan must be fully executable from the file alone.
- The `sk-planning` skill runs its own review loop before finalizing.
- Update `RUNBOOK.md` row `2` to `done`.

### 3. Implementation

**When:** the plan is finalized and you are ready to code.

**Approach:** read the plan file and implement one atomic TODO at a time.

**Output:** `3 - IMPLEMENTATION.md` in `.agents/sk-flows/<slug>/`.

- Run tests after each implementation step.
- Do not jump ahead; complete each TODO before marking it done.
- If the implementation departs from the plan, document the divergence in `3 - IMPLEMENTATION.md` and `RUNBOOK.md`.
- Update `RUNBOOK.md` row `3` to `done`.

### 4. Review

**When:** code is implemented and tests pass.

**Skills:** `sk-review-and-fix` (loop until clean) or `sk-review` (read-only report).

**Output:** `4 - REVIEW.md` in `.agents/sk-flows/<slug>/`.

- Review subagents use the plan to verify scope and acceptance.
- Fix every valid finding before moving on.
- Update `RUNBOOK.md` row `4` to `done`.

### 5. Verify

**When:** you want to confirm the changes work and introduce no regressions.

**Skill:** `sk-verify`

**Output:** `5 - VERIFY.md` in `.agents/sk-flows/<slug>/`.

- Run the verification steps from the plan.
- If this step is skipped, record the reason in `RUNBOOK.md` row `5`.

### 6. PR

**When:** review is clean and verification is done.

**Skill:** `sk-pr`

**Output:** `6 - PR.md` in `.agents/sk-flows/<slug>/`.

- Create or update a GitHub pull request with the plan and review evidence reflected in the body.
- Update `RUNBOOK.md` row `6` to `done` and set the top status to `completed`.

## Using just one skill

You do not have to run the full flow. Each skill is self-contained:

- `/explore <slug>` or "use the sk-explore skill" — gather context and write `0 - EXPLORE.md`
- `/alternatives` or "use the sk-alternatives skill" — reviewed options for any decision, writes `1 - ALTERNATIVES.md`
- `/plan <slug>` or "use the sk-planning skill" — write `2 - PLANNING.md`
- `/review` or "use the sk-review-and-fix skill" — review the current diff, writes `4 - REVIEW.md`
- `/pr` or "use the sk-pr skill" — create or update a PR, writes `6 - PR.md`
- `/flow [auto|manual]` or "use the sk-flow skill" — run the full workflow

Even when using just one skill, a flow folder and runbook are created so the state is documented.

## Rollback

- **Before implementation:** if the plan is wrong, edit `2 - PLANNING.md` and re-run the planning review.
- **During implementation:** if a TODO is too big, split it into smaller TODOs in the plan and continue.
- **After review:** if a valid finding indicates the plan itself is wrong, stop implementation, revise the plan, and re-implement.
- **After PR:** if the PR is wrong, close or update it; do not force-merge.

## Escalation path

- **Hook or rule not loading:** see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
- **Skill output is wrong:** edit the skill `SKILL.md` directly and re-test.
- **Plan review never converges:** reduce plan scope or split into a masterplan and sub-plans.
- **Review finds the plan is wrong:** go back to planning before fixing code.
- **Agent diverged from the skill:** document it in the runbook and, if needed, return to the phase that diverged.

## For agents without hooks

If your agent does not support `UserPromptSubmit` hooks, open this runbook and read the relevant step before starting.

The rules and skills files in this repo contain the detailed instructions for each step.
