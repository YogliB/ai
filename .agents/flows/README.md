# Flow runbooks

This directory holds one subfolder per flow. Each flow is a mandatory runbook plus numbered, self-contained phase docs.

## Layout

```text
.agents/flows/sk-<slug>/
├── RUNBOOK.md
├── 0 - EXPLORE.md
├── 1 - ALTERNATIVES.md
├── 2 - PLANNING.md
├── 3 - IMPLEMENTATION.md
├── 4 - REVIEW.md
├── 5 - VERIFY.md
└── 6 - PR.md
```

## Slug

- Short, kebab-case, describes the work (not a ticket or issue id).
- The actual flow directory is `sk-<slug>` (e.g., `sk-add-auth-token`, `sk-refactor-cache-layer`).

## Runbook

`RUNBOOK.md` is a mandatory checklist. Every phase that runs updates its row. If a phase is skipped, the reason is recorded. If the agent diverges from the skill, it is recorded in the `Divergence / Notes` column and the `Divergence log` section.

## Phase docs

Each numbered doc is self-contained so the next phase can start from it without chat context.

| #   | Doc                     | Phase          |
| --- | ----------------------- | -------------- |
| 0   | `0 - EXPLORE.md`        | Explore        |
| 1   | `1 - ALTERNATIVES.md`   | Alternatives   |
| 2   | `2 - PLANNING.md`       | Planning       |
| 3   | `3 - IMPLEMENTATION.md` | Implementation |
| 4   | `4 - REVIEW.md`         | Review         |
| 5   | `5 - VERIFY.md`         | Verify         |
| 6   | `6 - PR.md`             | PR             |

## Status values

- `done` — phase completed and doc written.
- `skipped` — phase not needed; reason recorded.
- `diverged` — agent departed from the skill; reason recorded.
- `blocked` — phase cannot continue; blocker recorded.
- `pending` — not yet reached.

## Finding the active flow

If the user did not name a slug, look for a stuck flow: one where the prior phase doc exists and the current skill's phase doc is missing. If one, suggest continuing it. If several, list them and ask. If none, fall back to the `RUNBOOK.md` with the most recent mtime.

## Not committed by default

Flow folders are not committed unless the user or repo policy explicitly asks.
