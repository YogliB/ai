---
name: sk-verify
description: Verify that changes do what they aim to do and introduce no regressions. Uses the active plan's Verification section if available; otherwise falls back to a project-level .agents/verify/VERIFICATION.md. If verification steps are unknown, asks the user and records the answer.
---

# Verify

## When to use

- After implementation and before creating a PR.
- When the user asks "did this work?", "verify the changes", "use the sk-verify skill", or similar.
- This skill does **not** run lint, tests, or security checks; use `before-pr` for those.

## Steps

1. **Understand the intent**
    - If a plan exists in `.agents/plans/`, read its `## Goal` and `## Context` to understand what the changes should do.
    - Review the diff for changed files.
    - If the intent is still unclear, ask the user for a one-line statement of the expected outcome.

2. **Find verification steps**
    - Read the active plan (newest `.md` in `.agents/plans/` by mtime, or the one the user named).
    - If the plan's `## Verification` section has concrete steps, use those.
    - If the section is missing or empty, read `.agents/verify/VERIFICATION.md`.

3. **Ask if nothing is known**
    - If no verification steps are found, ask the user:
      "What should I run or inspect to confirm these changes do what they aim and introduce no regressions?"
    - Create `.agents/verify/` if needed.
    - Append the answer to `.agents/verify/VERIFICATION.md`.
    - **Do not write to the plan file.** This skill only reads the plan.

4. **Run the steps**
    - Treat each step as a shell command when possible.
    - If a step is not runnable (e.g. a manual check or a question), ask the user to confirm the result.
    - Stop on the first failure and report it.
    - Do not auto-fix failures.

5. **Report**
    - Print the result of each step and an overall `PASS` or `FAIL`.

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.
