---
name: sk-flow
argument-hint: '[auto|manual]'
description: Mandatory end-to-end slash-kit workflow [auto|manual]. Run sk-explore, then sk-alternatives, then sk-planning, then implement, then sk-review-and-fix (or sk-review), then optional sk-verify, then sk-pr. In manual mode, stop and ask for user confirmation before each phase. In auto mode, run all phases without confirmation. Use when the user asks for the full workflow, /flow [auto|manual], or "run the ai workflow".
---

# Flow

The end-to-end flow is: **sk-explore → sk-alternatives → sk-planning → implementation → sk-review-and-fix (or sk-review) → optional sk-verify → sk-pr**.

Every phase produces a numbered, self-contained doc inside `.agents/sk-flows/<slug>/` and updates the `RUNBOOK.md` checklist. The runbook is mandatory; it is the record of what ran, what was skipped, and any divergence from the skill.

The user must explicitly ask for the workflow. Do not run it automatically.

## Modes

- **manual** (default): stop and ask for user confirmation before each phase.
- **auto**: run all phases sequentially without confirmation prompts. Still ask for required input that cannot be inferred, such as the slug/topic or a missing critical detail.

Parse the mode from the prompt. If the user says `/flow auto add-auth-token` or `Use sk-flow auto for add-auth-token`, use auto mode. If no mode is given, default to manual.

## Slug and flow folder

1. Ask the user for a slug/topic if not provided. Derive one from the goal if needed. The slug should be short kebab-case describing the work (e.g., `add-auth-token`).
2. Create `.agents/sk-flows/<slug>/` if it does not exist.
3. Create or update `RUNBOOK.md` in that folder with the flow checklist.
4. Pass the slug to each phase (or let each phase locate the active flow by most-recent `RUNBOOK.md`).

## Runbook template

`RUNBOOK.md` must be present in every flow folder. Start from `.agents/skills/sk-flow/templates/RUNBOOK.md` if available; otherwise use this inline template:

```markdown
# Flow Runbook: <slug>

Status: in-progress

Goal: <one-line user goal>

| #   | Phase          | State   | Artifact                                           | Summary | Divergence / Notes |
| --- | -------------- | ------- | -------------------------------------------------- | ------- | ------------------ |
| 0   | Explore        | pending | [0 - EXPLORE.md](0%20-%20EXPLORE.md)               |         |                    |
| 1   | Alternatives   | pending | [1 - ALTERNATIVES.md](1%20-%20ALTERNATIVES.md)     |         |                    |
| 2   | Planning       | pending | [2 - PLANNING.md](2%20-%20PLANNING.md)             |         |                    |
| 3   | Implementation | pending | [3 - IMPLEMENTATION.md](3%20-%20IMPLEMENTATION.md) |         |                    |
| 4   | Review         | pending | [4 - REVIEW.md](4%20-%20REVIEW.md)                 |         |                    |
| 5   | Verify         | pending | [5 - VERIFY.md](5%20-%20VERIFY.md)                 |         |                    |
| 6   | PR             | pending | [6 - PR.md](6%20-%20PR.md)                         |         |                    |

## Divergence log

- none
```

When a phase completes, update the row for that phase:

- `done` — completed and doc written.
- `skipped` — not needed; record the reason in `Divergence / Notes`.
- `diverged` — the agent departed from the skill instructions; record the reason and append an entry to the `Divergence log` section.
- `blocked` — cannot continue; record the blocker.
- `pending` — not yet reached.

Do not leave a completed or skipped phase as `pending`. The runbook must match reality at all times.

## Running the full flow

1. **Explore** — invoke the `sk-explore` skill. It writes `0 - EXPLORE.md` and updates runbook row 0.
2. **Manual only:** Ask if they want to continue. If they want to stop, stop.
3. **Alternatives** — invoke the `sk-alternatives` skill. It is a mandatory phase in the full flow. It must produce `1 - ALTERNATIVES.md` and update runbook row 1. The only allowed skip is a documented one in the `1 - ALTERNATIVES.md` and runbook row 1 (e.g., "only one viable approach; no alternatives needed").
4. **Plan** — invoke the `sk-planning` skill. It writes `2 - PLANNING.md` and updates runbook row 2.
5. **Manual only:** Ask if they want to continue to implementation.
6. **Implement** — implement the plan one atomic TODO at a time. Write `3 - IMPLEMENTATION.md` and update runbook row 3. Run tests after each step. If the implementation departs from the plan, record the divergence in `3 - IMPLEMENTATION.md` and runbook row 3.
7. **Manual only:** Ask if they want to continue to review.
8. **Review** — invoke `sk-review-and-fix` by default, or `sk-review` if the user prefers read-only. It writes `4 - REVIEW.md` and updates runbook row 4.
9. **Manual only:** Ask if they want to continue to verify.
10. **Verify (optional in the flow)** — invoke `sk-verify` if the plan or user calls for it. If not, leave runbook row 5 as `skipped` with reason. If it runs, it writes `5 - VERIFY.md` and updates runbook row 5.
11. **Manual only:** Ask if they want to continue to PR.
12. **PR** — invoke the `sk-pr` skill. It writes `6 - PR.md` and updates runbook row 6. Set the top `Status` line to `completed` when the PR is open.

## Subagent execution

Run each phase in an independent subagent when the harness supports it. The parent is a thin dispatcher: it passes the slug, plan, or diff to the subagent, triages the output, updates the runbook, and dispatches the next phase. The main session is updated only when the subagent is done.

## Stopping, skipping, and divergence

In manual mode, the user can stop or skip any phase. Each skill works on its own. Always ask before moving to the next phase.

In auto mode, do not stop between phases. Still run tests, verify no regressions, and confirm the PR is ready before creating it.

If the agent decides to diverge from the skill instructions — for example, skip a mandatory step, merge phases, use a different output format, or proceed without a required artifact — it must be documented in the runbook and in the relevant phase doc. Divergence is a last resort; prefer sticking to the skill unless the user explicitly asks.

## Output

The durable artifacts are all inside `.agents/sk-flows/<slug>/`:

- `RUNBOOK.md` — mandatory checklist and divergence log
- `0 - EXPLORE.md` from `sk-explore`
- `1 - ALTERNATIVES.md` from `sk-alternatives`
- `2 - PLANNING.md` from `sk-planning`
- `3 - IMPLEMENTATION.md` from implementation
- `4 - REVIEW.md` from `sk-review-and-fix` or `sk-review`
- `5 - VERIFY.md` from `sk-verify` (if run)
- `6 - PR.md` from `sk-pr`

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
