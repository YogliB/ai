# AI Workflow

The optional end-to-end flow is: **alternatives → planning → implementation → review → PR**.

The user must explicitly ask for the workflow. Do not run it automatically.

## Running the full flow

1. Read `RUNBOOK.md` if the user asks for the workflow.
2. Run `alternatives` first and let the user pick an option.
3. Run `planning` and write the plan file to `.agents/plans/<slug>.md`.
4. Implement the plan one atomic TODO at a time.
5. Run `review-and-fix` (or `review-dont-fix` if the user prefers read-only).
6. Run `pr`.

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
