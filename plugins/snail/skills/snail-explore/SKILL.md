---
name: snail-explore
description: First-link discovery. Gather repo context and write a structured report that feeds into snail-alternatives or snail-planning.
---

# Explore

## When to use

- Starting work when the problem, scope, or repo context is unclear.
- The user asks to explore, research, or understand X in this repo.
- Before `snail-alternatives` or `snail-planning` when context is missing.

## Goal

Produce a self-contained `0 - EXPLORE.yaml` so the next phase can proceed without re-exploring.

## Slug and flow folder

1. Derive a short kebab-case slug from the goal (confirm with the user if not provided).
2. Create `.agents/flows/snail-<slug>/` if needed.
3. Create the runbook if missing: `node ../snail-flow/scripts/flow-state.mjs init .agents/flows/snail-<slug> --slug=<slug> --goal=<one-line goal>` (`init` writes `.agents/.gitignore` so flows stay private).
4. Write `0 - EXPLORE.yaml` from `../snail-flow/templates/0 - EXPLORE.yaml`, then `node ../snail-flow/scripts/flow-state.mjs advance <dir>`.

A standalone install has no `../snail-flow/scripts/flow-state.mjs` or templates — skip every `init`/`advance`/`check` call above and work flow-less.

## Output

`0 - EXPLORE.yaml` includes:

- **Goal**: restated scope.
- **Files and Context**: relevant files and inline facts.
- **Findings**: what exists, what's missing, patterns, constraints, edge cases.
- **Assumptions and Open Questions**: unknowns with acceptance impact.
- **Risks**: known blockers or high-risk areas.
- **Next Step Recommendation**: `snail-alternatives` or `snail-planning` with a one-line reason.

## Steps

1. **Clarify** — restate goal and scope. If ambiguity is high, ask or list assumptions.
2. **Search** — find relevant code, tests, docs, and config.
3. **Read** — inline the relevant snippets or facts.
4. **Synthesize** — summarize current state, constraints, and gaps.
5. **Recommend** — `snail-alternatives` if the approach is unclear, `snail-planning` if it is clear.
6. **Write** — save the report and `advance` the runbook.

Do not edit non-report files.
