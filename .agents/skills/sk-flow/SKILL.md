---
name: sk-flow
argument-hint: '[auto|manual]'
description: End-to-end slash-kit workflow. Runs sk-explore, sk-alternatives, sk-planning, implement, sk-review-and-fix (or sk-review), optional sk-verify, then sk-pr. Use when the user asks for /flow, the full workflow, or "run the ai workflow".
---

# Flow

End-to-end flow: **Explore → Alternatives → Planning → Implementation → Review → (Verify) → PR**.

Only run this skill when the user explicitly asks for the workflow.

## Modes

- **manual** (default): ask before each phase.
- **auto**: run phases sequentially; still ask for missing critical input like the slug.

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. If no slug, look for a stuck flow: any `.agents/flows/sk-*/` where the prior phase doc exists and the next phase doc is missing. If one, suggest continuing from the next pending phase. If several, list them and ask. If none, ask for a short kebab-case slug.
3. Create `.agents/flows/sk-<slug>/` if needed.
4. Create or update `RUNBOOK.md` with the checklist below.
5. Pass the slug to each phase.

## Runbook template

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

State values: `done`, `skipped` (with reason), `diverged` (with reason), `blocked`, `pending`. Keep the runbook accurate after each phase.

## Running the flow

1. **Explore** — `sk-explore`. Writes `0 - EXPLORE.md`; updates row `0`.
2. (manual) Ask to continue.
3. **Alternatives** — `sk-alternatives`. Writes `1 - ALTERNATIVES.md`; updates row `1`.
4. (manual) Ask to continue.
5. **Plan** — `sk-planning`. Writes `2 - PLANNING.md`; updates row `2`.
6. (manual) Ask to continue.
7. **Implement** — execute the plan one TODO at a time. Writes `3 - IMPLEMENTATION.md`; updates row `3`. Run tests after each step. Record divergence if the plan changes.
8. (manual) Ask to continue.
9. **Review** — `sk-review-and-fix` by default, or `sk-review` if read-only. Writes `4 - REVIEW.md`; updates row `4`.
10. (manual) Ask to continue.
11. **Verify** (optional) — `sk-verify` if the plan or user requests it. Writes `5 - VERIFY.md` and updates row `5`; otherwise mark `skipped`.
12. (manual) Ask to continue.
13. **PR** — `sk-pr`. Writes `6 - PR.md`; updates row `6`. Set top status to `completed`.

## Example prompts

- `/flow add-auth-token`
- `/flow auto add-auth-token`
- `/flow manual add-auth-token`
- `Run the full ai workflow for add-auth-token`
