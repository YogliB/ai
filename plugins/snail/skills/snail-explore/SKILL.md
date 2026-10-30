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
3. Create the runbook if missing: `node ../snail-flow/scripts/flow-state.mjs init .agents/flows/snail-<slug> --slug=<slug> --goal=<one-line goal>` (`init` adds `.agents/flows/` to the repo's `.git/info/exclude` so flows stay private). If slug `review` is requested while the standalone review artifact (`.agents/flows/snail-review/4 - REVIEW.yaml`, no runbook) exists, do not `init` over it and do not delete the file: surface the collision and let the user pick a different slug or explicitly approve moving or removing it.
4. Write `0 - EXPLORE.yaml` from `../snail-flow/templates/0 - EXPLORE.yaml`, then `node ../snail-flow/scripts/flow-state.mjs advance <dir>`.

A standalone install has no `../snail-flow/scripts/flow-state.mjs` or templates — skip every `init`/`advance`/`check` call above and work flow-less. Before writing artifacts, add the flow dir's repo-root-relative path (usually `.agents/flows/`) on its own line to the repo's exclude file (`$(git rev-parse --git-common-dir)/info/exclude`, usually `.git/info/exclude`) if it is not there already (backslash-escaping any gitignore special characters in the path), so flow artifacts stay out of git without adding any file to the repo, the same rule `init` adds; outside a git repo there is nothing to ignore. If any flow files are already tracked, warn the user: ignore rules will not untrack them.

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
