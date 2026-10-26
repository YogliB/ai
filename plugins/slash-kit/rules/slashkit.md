---
description: slashkit AI conventions and skill pointers
trigger: always_on
globs: '**/*'
alwaysApply: true
---

# slashkit

slashkit is an AI workflow toolkit. The slashkit skills are the `sk-*` skills listed below; they may live alongside other skills in `.agents/skills/`.

## Skills

<!-- skills:start -->

- `sk-ai-toolbelt` — Pointer to external AI tools and MCPs
- `sk-alternatives` — Suggest up to 3 viable alternatives for a code or design decision
- `sk-explore` — First-link discovery
- `sk-flow` — End-to-end slashkit workflow
- `sk-implement` — Execute an approved plan exactly as written, with per-step checks and atomic commits
- `sk-planning` — Draft a self-contained executable technical plan with atomic testable TODOs
- `sk-pr` — Create or update a GitHub pull request via gh CLI
- `sk-project-docs` — Scaffold, audit, or nudge a project's documentation structure
- `sk-review-alternatives` — Independent review of proposed alternatives before they are presented to the user
- `sk-review-plan` — Read-only review of a technical plan
- `sk-review` — Code review of a diff, read-only by default or fix mode on explicit request
- `sk-verify` — Verify that changes do what they aim to do and introduce no regressions

<!-- skills:end -->

## Conventions

- Keep `SKILL.md` files short, clear, and concise. Preserve output contracts, tag definitions, and subagent instructions; remove redundant prose and duplicated explanations.
- Before using a slashkit skill, read its `SKILL.md`.
- Invoke slashkit skills by name. Do not run the full workflow (`sk-flow`) unless the user explicitly asks for it.
- Flow skills write numbered phase docs to `.agents/flows/sk-<slug>/` and update `runbook` via `skills/sk-flow/scripts/flow-state.sh`. The actual flow directory name starts with `sk-` and is short, clear, and concise.
- When delegating the flow or a phase to a subagent, the prompt names the skill to invoke plus its inputs (goal, slug, mode). Never paraphrase a phase into an artifact checklist — artifacts are outputs, not instructions.
- Each flow phase runs in a fresh subagent when the harness has one.
