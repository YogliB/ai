---
description: slashkit AI conventions and skill pointers
---

# slashkit

slashkit is an AI workflow toolkit. The slashkit skills are the `sk-*` skills listed below; they may live alongside other skills in `.agents/skills/`.

## Skills

- `sk-explore` — gather repo context
- `sk-alternatives` — compare approaches
- `sk-review-alternatives` — review options before presenting them
- `sk-planning` — write executable plans
- `sk-review-plan` — review plans
- `sk-review-and-fix` — review and fix code
- `sk-review` — read-only review
- `sk-pr` — create or update PRs
- `sk-verify` — verify changes
- `sk-project-docs` — scaffold docs
- `sk-ai-toolbelt` — external tool pointers
- `sk-flow` — run the full end-to-end workflow

## Conventions

- Keep `SKILL.md` files short, clear, and concise. Preserve output contracts, tag definitions, and subagent instructions; remove redundant prose and duplicated explanations.
- Before using a slashkit skill, read `.agents/skills/<skill>/SKILL.md`.
- Invoke slashkit skills by name. Do not run the full workflow (`sk-flow`) unless the user explicitly asks for it.
- Flow skills write numbered phase docs to `.agents/sk-flows/<slug>/` and update `RUNBOOK.md`. The slug is short, kebab-case, and describes the work.
