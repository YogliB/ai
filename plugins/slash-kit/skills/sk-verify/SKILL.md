---
name: sk-verify
description: Verify that changes do what they aim to do and introduce no regressions. Use after implementation and before creating a PR.
---

# Verify

## When to use

- After implementation and before creating a PR.
- When the user asks "did this work?", "verify the changes", or similar.
- This skill exercises the feature end-to-end. Lint, tests, and security checks are prerequisites here, not the verification.

## Active PR handoff

When the root runbook is multi-PR, fetch refs before this phase and verify the checked-out branch and HEAD against `prs[active-pr]`. Use the harness-supported sync workflow and record the resulting HEAD via `pr <dir> <slug> --head=<sha>` in the active PR's root runbook. If the branch or HEAD cannot be reconciled safely, `pr <dir> <slug> --state=blocked --notes=<reason>` and stop instead of reviewing or changing the wrong diff.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else inspect root runbooks (`runbook.json`; `node ../sk-flow/scripts/flow-state.mjs check <dir>` prints the resolved state when the script exists — a standalone install reads `runbook.json` directly and skips every `set`/`pr`/`check` call). For a multi-PR runbook, use its exact `active-pr` and matching `pr-<slug>/` directory; for a single-PR runbook, use the root. Require `4 - REVIEW.md` (unless row `4` is `skipped` in a `size:"light"` runbook) and missing `5 - VERIFY.md` there. If no runbook identifies the work, ask for a slug.
3. Write the verification report to `5 - VERIFY.md` from `../sk-flow/templates/5 - VERIFY.md` (frontmatter `schema: verify`; `receipts` lists every receipt path), then `set <dir> 5 <done|diverged|blocked>` (`diverged`/`blocked` need `--note=<reason>`; `skipped` is only valid when no report is written — `set <dir> 5 skipped --note=<reason>` when verification cannot run at all).

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
    - Treat each step as a shell command when possible, and run it through the receipt runner bundled with `sk-implement` (`scripts/run-with-receipt.sh` in that skill's directory). Record each command's receipt path in the report; a step without a valid passing receipt did not pass.
    - Stop on the first failure and report it.
    - Do not auto-fix failures.

5. **Report**
    - Print the result of each step and an overall `PASS` or `FAIL`.
    - If a feature path cannot be exercised in this environment (missing auth, external service, hardware), record the gap in the report instead of passing silently.
    - Write `5 - VERIFY.md` and `set <dir> 5 done` only when every command passed (`result: "pass"`); on failure `set <dir> 5 blocked --note=<reason>` (`diverged --note=<reason>` if you departed from this skill). The state gate refuses `done` on a non-pass report.

Run this skill in a subagent when the harness supports it (a `size:"light"` flow may run it inline).
