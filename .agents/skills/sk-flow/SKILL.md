---
name: sk-flow
description: Optional end-to-end slash-kit workflow. Run sk-explore, then optionally sk-alternatives, then sk-planning, then implement, then sk-review-and-fix (or sk-review-dont-fix), then sk-pr. Stop and ask for user confirmation before each phase. Use when the user asks for the full workflow, /flow, or "run the ai workflow".
---

# Flow

The optional end-to-end flow is: **sk-explore → sk-alternatives (optional) → sk-planning → implementation → sk-review-and-fix (or sk-review-dont-fix) → sk-pr**.

The user must explicitly ask for the workflow. Do not run it automatically.

## Running the full flow

1. Ask the user for a slug/topic if not provided. Derive one from the goal if needed.
2. **Explore** — invoke the `sk-explore` skill and write a structured report to `.agents/reports/<slug>.md`.
3. Ask if they want to continue. If they want to stop, stop. If they want to skip alternatives, proceed to planning.
4. **Alternatives** (optional) — invoke the `sk-alternatives` skill if the approach is unclear. The skill runs `sk-review-alternatives` internally and presents reviewed options. Let the user pick one.
5. **Plan** — invoke the `sk-planning` skill and write a plan file to `.agents/plans/<slug>.md`.
6. Ask if they want to continue to implementation.
7. **Implement** — implement the plan one atomic TODO at a time. Run tests after each step.
8. Ask if they want to continue to review.
9. **Review** — invoke `sk-review-and-fix` by default, or `sk-review-dont-fix` if the user prefers read-only.
10. Ask if they want to continue to PR.
11. **PR** — invoke the `sk-pr` skill to create or update a GitHub pull request.

## Stopping and skipping

The user can stop or skip any phase. Each skill works on its own. Always ask before moving to the next phase.

## Output

The durable artifacts are:

- `.agents/reports/<slug>.md` from `sk-explore`
- `.agents/plans/<slug>.md` from `sk-planning`
- A GitHub pull request from `sk-pr`

## Example prompts

- `/flow add-auth-token`
- `Run the full ai workflow for add-auth-token`
- `Use the sk-flow skill for add-auth-token`

## Alias

This skill is the canonical source for the `/flow` shortcut in Claude Code and for `run the full workflow` in any agent.
