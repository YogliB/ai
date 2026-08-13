---
name: sk-flow
argument-hint: '[auto|manual]'
description: Optional end-to-end slash-kit workflow [auto|manual]. Run sk-explore, then optionally sk-alternatives, then sk-planning, then implement, then sk-review-and-fix (or sk-review-dont-fix), then sk-pr. In manual mode, stop and ask for user confirmation before each phase. In auto mode, run all phases without confirmation. Use when the user asks for the full workflow, /flow [auto|manual], or "run the ai workflow".
---

# Flow

The optional end-to-end flow is: **sk-explore → sk-alternatives (optional) → sk-planning → implementation → sk-review-and-fix (or sk-review-dont-fix) → sk-pr**.

The user must explicitly ask for the workflow. Do not run it automatically.

## Modes

The flow supports two modes:

- **manual** (default): stop and ask for user confirmation before each phase.
- **auto**: run all phases sequentially without confirmation prompts. Still ask for required input that cannot be inferred, such as the slug/topic or a missing critical detail.

Parse the mode from the prompt. If the user says `/flow auto add-auth-token` or `Use sk-flow auto for add-auth-token`, use auto mode. If no mode is given, default to manual.

## Running the full flow

1. Ask the user for a slug/topic if not provided. Derive one from the goal if needed.
2. **Explore** — invoke the `sk-explore` skill and write a structured report to `.agents/reports/<slug>.md`.
3. **Manual only:** Ask if they want to continue. If they want to stop, stop. If they want to skip alternatives, proceed to planning.
4. **Alternatives** (optional) — invoke the `sk-alternatives` skill if the approach is unclear. In manual mode, the skill runs `sk-review-alternatives` and presents reviewed options; let the user pick one. In auto mode, use the recommendation from the alternatives review.
5. **Plan** — invoke the `sk-planning` skill and write a plan file to `.agents/plans/<slug>.md`.
6. **Manual only:** Ask if they want to continue to implementation.
7. **Implement** — implement the plan one atomic TODO at a time. Run tests after each step.
8. **Manual only:** Ask if they want to continue to review.
9. **Review** — invoke `sk-review-and-fix` by default, or `sk-review-dont-fix` if the user prefers read-only.
10. **Manual only:** Ask if they want to continue to PR.
11. **PR** — invoke the `sk-pr` skill to create or update a GitHub pull request.

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Stopping and skipping

In manual mode, the user can stop or skip any phase. Each skill works on its own. Always ask before moving to the next phase.

In auto mode, do not stop between phases. Still run tests, verify no regressions, and confirm the PR is ready before creating it.

## Output

The durable artifacts are:

- `.agents/reports/<slug>.md` from `sk-explore`
- `.agents/plans/<slug>.md` from `sk-planning`
- A GitHub pull request from `sk-pr`

## Example prompts

- `/flow add-auth-token`
- `/flow auto add-auth-token`
- `/flow manual add-auth-token`
- `Run the full ai workflow for add-auth-token`
- `Run the full ai workflow in auto mode for add-auth-token`
- `Use the sk-flow skill for add-auth-token`
- `Use the sk-flow skill in manual mode for add-auth-token`

## Alias

This skill is the canonical source for the `/flow` shortcut in Claude Code and for `run the full workflow` in any agent.
