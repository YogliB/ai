---
description: Optional end-to-end AI workflow (explore, alternatives, planning, implementation, review, PR)
trigger: model_decision
---

# AI Workflow

The optional end-to-end flow is: **explore → alternatives (optional) → planning → implementation → review → PR**.

The user must explicitly ask for the workflow. Do not run it automatically.

## Running the full flow

1. Read `RUNBOOK.md` if the user asks for the workflow.
2. Run `explore` and write a structured report to `.agents/reports/<slug>.md`.
3. Run `alternatives` if the approach is unclear and let the user pick an option; otherwise proceed to `planning`.
4. Run `planning` and write the plan file to `.agents/plans/<slug>.md`.
5. Implement the plan one atomic TODO at a time.
6. Run `review-and-fix` (or `review-dont-fix` if the user prefers read-only).
7. Run `pr`.

## Using subagents

Each phase should run in an independent subagent when the platform supports it:

- alternatives generation in one subagent
- alternatives review in another
- planning review in another
- code review in another
- fixes in a builder subagent

The parent acts as a thin dispatcher: pass the plan or diff to the subagent, triage the output, and dispatch the next phase.

## Opting out

The user can stop or skip any phase. Each skill works on its own.
