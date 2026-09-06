---
name: sk-verify
description: Verify that changes do what they aim to do and introduce no regressions. Use after implementation and before creating a PR.
---

# Verify

## When to use

- After implementation and before creating a PR.
- When the user asks "did this work?", "verify the changes", or similar.
- This skill does **not** run lint, tests, or security checks; use `before-pr` for those.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else look for a stuck flow: one where `4 - REVIEW.md` exists and `5 - VERIFY.md` is missing. If one, suggest continuing it. If several, list them and ask. If none, find the most recent `RUNBOOK.md`. If still none, ask for a slug.
3. Write the verification report to `5 - VERIFY.md` and update `RUNBOOK.md` row `5`.

## Steps

1. **Understand intent**
    - Read the active plan (`2 - PLANNING*.md`) to understand what the changes should do.
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
