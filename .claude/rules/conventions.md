# AI Conventions

This repo provides reusable agent skills under `.agents/skills/`.

## Skills

| Skill               | File                                          | Use when                                       |
| ------------------- | --------------------------------------------- | ---------------------------------------------- |
| alternatives        | `.agents/skills/alternatives/SKILL.md`        | User wants options for a decision              |
| review-alternatives | `.agents/skills/review-alternatives/SKILL.md` | Reviewing proposed alternatives                |
| planning            | `.agents/skills/planning/SKILL.md`            | Writing an executable technical plan           |
| review-and-fix      | `.agents/skills/review-and-fix/SKILL.md`      | Reviewing a diff and fixing issues             |
| review-dont-fix     | `.agents/skills/review-dont-fix/SKILL.md`     | Read-only diff review                          |
| pr                  | `.agents/skills/pr/SKILL.md`                  | Creating or updating a PR                      |
| verify              | `.agents/skills/verify/SKILL.md`              | Verifying changes work and have no regressions |

Invoke the skill by name when the user asks for it. Do not force a full workflow unless the user asks for one.

## Plan files

When the user asks for planning, the final plan must be written to a file:

- Default: `.agents/plans/<slug>.md`
- Masterplan: `.agents/plans/<slug>-master.md`
- `<slug>` is short, kebab-case, and describes the work

The plan is the durable artifact for implementation, review, and PR phases.

## Alternatives

When the user asks for alternatives, the generated options must be reviewed by the `review-alternatives` skill before presentation. If valid issues are found, revise once and re-review.

## Review

When reviewing code, use the latest plan file under `.agents/plans/` as context if one exists. Note any missing plan, spec, tests, or runtime under `Validation gaps`.

## PR

When creating a PR, use the diff, test evidence, and the plan file (if any) to build the body.
