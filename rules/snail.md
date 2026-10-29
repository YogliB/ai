---
description: snail AI conventions and skill pointers
alwaysApply: true
---

# snail

snail is an AI workflow toolkit. The snail skills are the `snail-*` skills listed below; they may live alongside other skills in `.agents/skills/`.

## Skills

<!-- skills:start -->

- `snail-ai-toolbelt` — Pointer to external AI tools and MCPs
- `snail-alternatives` — Suggest up to 3 viable alternatives for a code or design decision
- `snail-explore` — First-link discovery
- `snail-flow` — End-to-end snail workflow
- `snail-implement` — Execute an approved plan exactly as written, with per-step checks and atomic commits
- `snail-planning` — Draft a self-contained executable technical plan with atomic testable TODOs
- `snail-pr` — Create or update a GitHub pull request via gh CLI
- `snail-project-docs` — Scaffold, audit, or nudge a project's documentation structure
- `snail-review-alternatives` — Independent review of proposed alternatives before they are presented to the user
- `snail-review-plan` — Read-only review of a technical plan
- `snail-review` — Code review of a diff, read-only by default or fix mode on explicit request
- `snail-verify` — Verify that changes do what they aim to do and introduce no regressions

<!-- skills:end -->

## Conventions

- Keep `SKILL.md` files short, clear, and concise. Preserve output contracts, tag definitions, and subagent instructions; remove redundant prose and duplicated explanations.
- Before using a snail skill, read its `SKILL.md`.
- Invoke snail skills by name. Do not run the full workflow (`snail-flow`) unless the user explicitly asks for it.
- Flow skills write numbered phase YAML artifacts to `.agents/flows/snail-<slug>/` and update `runbook.yaml` via `node skills/snail-flow/scripts/flow-state.mjs` (Node 24+ required). The actual flow directory name starts with `snail-` and is short, clear, and concise.
- When delegating the flow or a phase to a subagent, the prompt names the skill to invoke plus its inputs (goal, slug, mode). Never paraphrase a phase into an artifact checklist — artifacts are outputs, not instructions.
- Each flow phase runs in a fresh subagent when the harness has one.
