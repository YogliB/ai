---
name: sk-explore
description: First-link discovery skill. Gather available context from the repo and user prompt, then write a structured report that feeds into sk-alternatives or sk-planning.
---

# Explore

## When to use

- Starting a new piece of work and the problem, scope, or repo context is not fully understood.
- The user asks "explore X", "research X", or "understand X in this repo".
- Before `sk-alternatives` when multiple approaches are possible.
- Before `sk-planning` when the approach is clear but the details are not.

## Goal

Produce a self-contained, structured `0 - EXPLORE.md` so the next step can proceed without re-exploring, even in a new session.

## Slug and flow folder

1. If the user did not provide a slug, derive one from the goal and ask to confirm.
2. Create `.agents/sk-flows/<slug>/` if it does not exist.
3. Create or update `RUNBOOK.md` in that folder with the flow checklist. Mark all phases except `0` as `pending`. Mark phase `0` as `in-progress` while exploring.
4. Write `0 - EXPLORE.md` and update `RUNBOOK.md` row `0` to `done` with a one-line summary.

If this skill runs outside a flow, it is still a one-skill flow: the folder and runbook must still be created and maintained.

## Output

A durable report at `.agents/sk-flows/<slug>/0 - EXPLORE.md` with these sections:

- **Goal**: restated user goal and scope boundary.
- **Files and Context**: relevant files, code snippets, and current state. Inline facts; no pointer-only references.
- **Findings**: what exists, what is missing, patterns, constraints, and edge cases.
- **Assumptions and Open Questions**: unknowns with acceptance impact.
- **Risks**: known blockers or high-risk areas.
- **Next Step Recommendation**: `sk-alternatives` or `sk-planning` with a one-line reason.

## Steps

1. **Clarify**: restate the goal and scope. If ambiguity is high, ask the user or list assumptions.
2. **Search**: use code search, grep, and file search to find relevant code, tests, docs, and config.
3. **Read**: read the key files and inline the relevant snippets or facts.
4. **Synthesize**: summarize the current state, constraints, and gaps.
5. **Recommend**: choose `sk-alternatives` if the approach is unclear, `sk-planning` if the approach is clear.
6. **Write**: save the report to `.agents/sk-flows/<slug>/0 - EXPLORE.md` and update `RUNBOOK.md`.

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Initial setup

Before writing the first report in a repo:

- Create `.agents/sk-flows/` if it does not exist.
- Add `.agents/sk-flows/` to `.gitignore` so flow files are not committed by default.

## Report file output

- Default path: `.agents/sk-flows/<slug>/0 - EXPLORE.md`
- `<slug>` should describe the work in short kebab-case (e.g., `add-auth-token`, `auth-token-refresh`).
- If the user did not name it, derive one from the Goal and ask to confirm.
- Do not edit non-report files.

## Example

```markdown
# 0 — Explore: Add user authentication

## Goal

Add token-based authentication to the API.

## Files and Context

- `src/routes/auth.ts` — existing route stubs, no token logic.
- `src/middleware/auth.ts` — placeholder middleware.
- `tests/auth.test.ts` — tests for login only.

## Findings

- No token generation or validation exists.
- Tests cover login but not refresh or logout.
- The project uses Express and JWT is already a dependency.

## Assumptions and Open Questions

- Assumption: JWT secret lives in `AUTH_TOKEN_SECRET`.
- Open question: refresh tokens required?

## Risks

- Adding refresh tokens increases scope.

## Next Step Recommendation

- **sk-alternatives** — choose between session cookies, JWT only, or JWT + refresh tokens.
```

## Routing

After writing the report and updating `RUNBOOK.md`, stop and state the recommendation. Do not proceed to `sk-alternatives` or `sk-planning` unless the user explicitly asks.
