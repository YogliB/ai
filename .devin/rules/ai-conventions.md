---
description: AI skill and plan conventions for this repo
trigger: always_on
---

# AI Conventions

This repo provides reusable agent skills under `.agents/skills/`.

## Skills

| Skill                  | File                                             | Use when                                            |
| ---------------------- | ------------------------------------------------ | --------------------------------------------------- |
| sk-explore             | `.agents/skills/sk-explore/SKILL.md`             | User needs to understand the problem and repo first |
| sk-alternatives        | `.agents/skills/sk-alternatives/SKILL.md`        | User wants options for a decision                   |
| sk-review-alternatives | `.agents/skills/sk-review-alternatives/SKILL.md` | Reviewing proposed alternatives                     |
| sk-planning            | `.agents/skills/sk-planning/SKILL.md`            | Writing an executable technical plan                |
| sk-review-and-fix      | `.agents/skills/sk-review-and-fix/SKILL.md`      | Reviewing a diff and fixing issues                  |
| sk-review-dont-fix     | `.agents/skills/sk-review-dont-fix/SKILL.md`     | Read-only diff review                               |
| sk-pr                  | `.agents/skills/sk-pr/SKILL.md`                  | Creating or updating a PR                           |
| sk-verify              | `.agents/skills/sk-verify/SKILL.md`              | Verifying changes work and have no regressions      |
| sk-project-docs        | `.agents/skills/sk-project-docs/SKILL.md`        | Scaffolding or nudging a project's docs structure   |
| sk-ai-toolbelt         | `.agents/skills/sk-ai-toolbelt/SKILL.md`         | Pointers to recommended external tools and MCPs     |
| sk-flow                | `.agents/skills/sk-flow/SKILL.md`                | Running the full end-to-end workflow.               |

Invoke the skill by name when the user asks for it. Do not force a full workflow unless the user asks for one.

## Plan files

When the user asks for planning, the final plan must be written to a file:

- Default: `.agents/plans/<slug>.md`
- Masterplan: `.agents/plans/<slug>-master.md`
- `<slug>` is short, kebab-case, and describes the work

The plan is the durable artifact for implementation, review, and PR phases.

## Alternatives

When the user asks for alternatives, the generated options must be reviewed by the `sk-review-alternatives` skill before presentation. If valid issues are found, revise once and re-review.

## Review

When reviewing code, use the latest plan file under `.agents/plans/` as context if one exists. Note any missing plan, spec, tests, or runtime under `Validation gaps`.

## PR

When creating a PR, use the diff, test evidence, and the plan file (if any) to build the body.
