# AI Workflow

The optional end-to-end flow is: **sk-explore → sk-alternatives (optional) → sk-planning → implementation → sk-review-and-fix (or sk-review-dont-fix) → sk-pr**.

The user must explicitly ask for the workflow. Do not run it automatically.

## Running the full flow

1. Read `RUNBOOK.md` if the user asks for the workflow.
2. Run `sk-flow` or follow the steps below.
3. Run `sk-explore` and write a structured report to `.agents/reports/<slug>.md`.
4. Run `sk-alternatives` if the approach is unclear and let the user pick an option; otherwise proceed to `sk-planning`.
5. Run `sk-planning` and write the plan file to `.agents/plans/<slug>.md`.
6. Implement the plan one atomic TODO at a time.
7. Run `sk-review-and-fix` (or `sk-review-dont-fix` if the user prefers read-only).
8. Run `sk-pr`.

## Using subagents

Each phase should always run in an independent subagent when the platform supports it:

- alternatives generation in one subagent
- alternatives review in another
- planning review in another
- code review in another
- fixes in a builder subagent

The parent acts as a thin dispatcher: pass the plan or diff to the subagent, triage the output, and dispatch the next phase. The main session is updated only when the subagent is done.

## Modes

`sk-flow` supports `auto` and `manual` modes. In auto mode, the agent runs all phases without confirmation. In manual mode, the agent asks before each phase. Default to manual when the mode is omitted.

## Opting out

The user can stop or skip any phase. Each skill works on its own.
