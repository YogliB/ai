# slashkit

slashkit is an AI workflow toolkit. The slashkit skills are the `sk-*` skills listed below; they live in `skills/` in this repo and in `.agents/skills/` when installed into a project.

## Skills

- `sk-explore` — gather repo context
- `sk-alternatives` — compare approaches
- `sk-review-alternatives` — review options before presenting them
- `sk-planning` — write executable plans
- `sk-review-plan` — review plans
- `sk-implement` — execute approved plans
- `sk-review-and-fix` — review and fix code
- `sk-review` — read-only review, posted inline on PRs
- `sk-pr` — create or update PRs
- `sk-verify` — verify changes
- `sk-project-docs` — scaffold docs
- `sk-ai-toolbelt` — external tool pointers
- `sk-flow` — run the full end-to-end workflow

## Conventions

- Keep `SKILL.md` files short, clear, and concise. Preserve output contracts, tag definitions, and subagent instructions; remove redundant prose and duplicated explanations.
- Before using a slashkit skill, read `skills/<skill>/SKILL.md` (or `.agents/skills/<skill>/SKILL.md` in an installed project).
- Invoke slashkit skills by name. Do not run the full workflow (`sk-flow`) unless the user explicitly asks for it.
- Flow skills write numbered phase docs to `.agents/flows/sk-<slug>/` and update `RUNBOOK.md`. The actual flow directory name starts with `sk-` and is short, clear, and concise.
