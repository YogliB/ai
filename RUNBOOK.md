# AI Workflow Runbook

Optional end-to-end flow: **sk-explore → sk-alternatives (optional) → sk-planning → implementation → sk-review-and-fix (or sk-review-dont-fix) → sk-pr**.

Each step is a reusable skill. Use the whole flow or pick just the step you need.

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
- You have permission to create plan files under `.agents/plans/`.
- For the PR step, `gh` is authenticated and the remote is reachable.

## Step-by-step procedure

### 1. Explore

**When:** you are starting a new piece of work and need to understand the problem, scope, or repo context.

**Skill:** `sk-explore`

**Output:** a structured report at `.agents/reports/<slug>.md`.

- Gather available context from the repo and user prompt.
- Recommend the next step: `sk-alternatives` (if the approach is unclear) or `sk-planning` (if the approach is clear).

### 2. Alternatives

**When:** you are not sure which approach to take.

**Skill:** `sk-alternatives`

**Output:** up to 3 reviewed options + a recommendation.

- The alternatives are first reviewed by the `sk-review-alternatives` skill to catch irrelevant, duplicate, or weak options.
- The user picks one.

### 3. Planning

**When:** you have chosen an approach and are ready to write an executable plan.

**Skill:** `sk-planning`

**Output:** a self-contained plan file at `.agents/plans/<slug>.md`.

- The plan must be fully executable from the file alone.
- The `sk-planning` skill runs its own review loop before finalizing.

### 4. Implementation

**When:** the plan is finalized and you are ready to code.

**Approach:** read the plan file and implement one atomic TODO at a time.

- Run tests after each implementation step.
- Do not jump ahead; complete each TODO before marking it done.

### 5. Review

**When:** code is implemented and tests pass.

**Skills:** `sk-review-and-fix` (loop until clean) or `sk-review-dont-fix` (read-only report).

**Input:** the diff and the plan file.

- Review subagents use the plan to verify scope and acceptance.
- Fix every valid finding before moving on.

### 6. PR

**When:** review is clean and verification is done.

**Skill:** `sk-pr`

**Output:** a GitHub pull request with the plan and review evidence reflected in the body.

## Using just one skill

You do not have to run the full flow. Each skill is self-contained:

- `/explore <slug>` or "use the sk-explore skill" — gather context and write a structured report
- `/alternatives` or "use the sk-alternatives skill" — reviewed options for any decision
- `/plan <slug>` or "use the sk-planning skill" — write a plan file
- `/review` or "use the sk-review-and-fix skill" — review the current diff
- `/pr` or "use the sk-pr skill" — create or update a PR
- `/flow [auto|manual]` or "use the sk-flow skill" — run the full workflow

## Rollback

- **Before implementation:** if the plan is wrong, edit the plan file and re-run the planning review.
- **During implementation:** if a TODO is too big, split it into smaller TODOs in the plan file and continue.
- **After review:** if a valid finding indicates the plan itself is wrong, stop implementation, revise the plan, and re-implement.
- **After PR:** if the PR is wrong, close or update it; do not force-merge.

## Escalation path

- **Hook or rule not loading:** see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
- **Skill output is wrong:** edit the skill `SKILL.md` directly and re-test.
- **Plan review never converges:** reduce plan scope or split into a masterplan and sub-plans.
- **Review finds the plan is wrong:** go back to planning before fixing code.

## For agents without hooks

If your agent does not support `UserPromptSubmit` hooks, open this runbook and read the relevant step before starting.

The rules and skills files in this repo contain the detailed instructions for each step.
