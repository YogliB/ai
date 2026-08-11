# Plan files

This directory holds durable, self-contained technical plans produced by the `planning` skill. Keeping plans in files means later phases — implementation, review, and PR creation — can read them without depending on chat context.

## Conventions

- Name: `<short-slug>.md` or `<short-slug>-master.md` for masterplans
- Slug: short, kebab-case, describes the work (not a ticket or issue id)
- Examples: `add-auth-token.md`, `refactor-cache-layer-master.md`
- Plans are not committed unless the user or repo policy explicitly asks
- If an agent platform has its own default plan location, write there too, but keep a canonical copy here

## Finding the active plan

- If only one plan exists in this directory, it is the active plan
- If multiple exist, the newest file by mtime is the active plan unless another is named in the prompt
- For a specific feature, use `.agents/plans/<feature-name>.md`

## Plan content

Plans follow the template in `.agents/skills/planning/templates/plan.md` (or `masterplan.md` for multi-PR work). They must be fully self-contained: an implementer should be able to execute using only the plan plus a normal repo checkout.
