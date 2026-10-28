---
name: sk-verify
description: Verify that changes do what they aim to do and introduce no regressions. Use after implementation and before creating a PR.
---

# Verify

## When to use

- After implementation and before creating a PR.
- When the user asks "did this work?", "verify the changes", or similar.
- This skill exercises the feature end-to-end. Lint, tests, and security checks are prerequisites here, not the verification.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else run `sh ../sk-flow/scripts/flow-state.sh check <dir>` on each `.agents/flows/sk-*/` and pick the flow whose `next` is `5` (a standalone install skips every `flow-state.sh` call and works flow-less). Require missing `5 - VERIFY.md` there. If no flow identifies the work, ask for a slug.
3. When verification cannot run at all (missing credentials, services, environment), do not write `5 - VERIFY.md`: `advance <dir> --skip --note=<reason>` records the reason in the runbook. Otherwise write the verification report to `5 - VERIFY.md` from `../sk-flow/templates/5 - VERIFY.md` (list every receipt path), then `sh ../sk-flow/scripts/flow-state.sh advance <dir> --result=pass --receipts=<a,b>` only when every command passed. On failure `note <dir> <reason>`.

## Steps

1. **Understand intent**
    - Read the exact active plan (`2 - PLANNING.md`) in the selected flow or PR directory.
    - Review the diff.
    - If intent is unclear, ask the user for a one-line expected outcome.

2. **Find verification steps**
    - Use the plan's `## Verification` section (a light plan's per-step check commands serve).
    - If missing, read `.agents/verify/VERIFICATION.md`.

3. **Ask if nothing is known**
    - If no steps are found, ask: "What should I run or inspect to confirm these changes do what they aim and introduce no regressions?"
    - Create `.agents/verify/` if needed.
    - Append the answer to `.agents/verify/VERIFICATION.md`.
    - Do not write to the plan.

4. **Exercise the feature**
    - Run the change the way a user or agent will hit it, not just the test harness. Examples: run the CLI on real input and inspect what it writes; install the plugin and fire its hook through the real hook command; call the new API; serve the UI and hit the route.
    - Use the plan's steps as the floor. If every step only proves the code compiles or tests pass, add the missing feature-level exercise yourself — that is the point of this skill.
    - Treat each step as a shell command when possible, and run it through the receipt runner bundled with `sk-implement` (`scripts/run-with-receipt.sh <dir>/receipts <label> -- <command>` in that skill's directory). A standalone install without `sk-implement` has no runner — run the commands directly and record command plus result in the report. Record each command's receipt path in the report; a step without a valid passing receipt did not pass.
    - Stop on the first failure and report it.
    - Do not auto-fix failures.

5. **Report**
    - Print the result of each step and an overall `PASS` or `FAIL`.
    - If a feature path cannot be exercised in this environment (missing auth, external service, hardware), record the gap in the report instead of passing silently.
    - Write `5 - VERIFY.md` and `advance` only when every command passed; the gate refuses `--result=pass` that lacks valid receipts.

Run this skill in a subagent when the harness supports it (a `size: light` flow may run it inline).
