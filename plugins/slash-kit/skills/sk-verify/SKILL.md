---
name: sk-verify
description: Verify that changes do what they aim to do and introduce no regressions. Use after implementation and before creating a PR.
---

# Verify

## When to use

- After implementation and before creating a PR.
- When the user asks "did this work?", "verify the changes", or similar.
- This skill does **not** run lint, tests, or security checks; use `before-pr` for those.

## Active PR handoff

When the root runbook is multi-PR, fetch refs before this phase and verify the checked-out branch and HEAD against the active PR row. Use the harness-supported sync workflow and record the resulting HEAD in the active PR runbook. If the branch or HEAD cannot be reconciled safely, mark the PR blocked and stop instead of reviewing or changing the wrong diff.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else inspect root runbooks. For a multi-PR runbook, use its exact `Active PR` and matching `Directory`; for a single-PR runbook, use the root. Require `4 - REVIEW.md` and missing `5 - VERIFY.md` there. If no runbook identifies the work, ask for a slug.
3. Write the verification report to `5 - VERIFY.md` and update `RUNBOOK.md` row `5`.

## Steps

1. **Understand intent**
    - Read the exact active plan (`2 - PLANNING.md`) in the selected flow or PR directory.
    - Review the diff.
    - If intent is unclear, ask the user for a one-line expected outcome.

2. **Find verification steps**
    - Use the plan's `## Verification` section.
    - If missing, read `.agents/verify/VERIFICATION.md`.

3. **Ask if nothing is known**
    - If no steps are found, ask: "What should I run or inspect to confirm these changes do what they aim and introduce no regressions?"
    - Create `.agents/verify/` if needed.
    - Append the answer to `.agents/verify/VERIFICATION.md`.
    - Do not write to the plan.

4. **Run the steps**
    - Treat each step as a shell command when possible.
    - Stop on the first failure and report it.
    - Do not auto-fix failures.

5. **Report**
    - Print the result of each step and an overall `PASS` or `FAIL`.
    - Write `5 - VERIFY.md` and update `RUNBOOK.md` row `5` to `done` (or `diverged` if departed).

Run this skill in a subagent when the harness supports it.
