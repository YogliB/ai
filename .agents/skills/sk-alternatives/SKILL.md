---
name: sk-alternatives
description: Suggest up to 3 viable alternatives for code or design decisions before committing to an implementation. Use when the user asks for sk-alternatives, alternatives, options, or "better ways" to solve a problem.
---

# Alternatives

## Slug and flow folder

1. Determine the active flow:
    - If the user provided a slug, use `.agents/sk-flows/<slug>/`.
    - Else find the flow whose `RUNBOOK.md` is most recent.
    - If no flow exists, derive a slug from the decision, create `.agents/sk-flows/<slug>/`, and create `RUNBOOK.md` with all other phases `pending`.
2. Update `RUNBOOK.md` row `1` to `in-progress`.
3. Write the final alternatives doc to `.agents/sk-flows/<slug>/1 - ALTERNATIVES.md` and set row `1` to `done`, `skipped` (with reason), or `diverged` (with reason).

This skill can run on its own; it still creates and updates the flow folder and runbook.

## Steps

1. **Identify Options**: Brainstorm distinct approaches (e.g., different patterns, libraries, or architectural choices). If only one viable approach exists, produce a single-option `1 - ALTERNATIVES.md` explaining that and skip to planning with the reason documented.
2. **Present**: For each option, provide:
    - **Idea**: Short description.
    - **Snippet**: Minimal code example (if relevant).
    - **Pros / Cons**: Brief, balanced assessment.
3. **Review**: Dispatch a **sk-review-alternatives** subagent (or invoke the `sk-review-alternatives` skill) to evaluate the options for relevance, distinctness, and weak/strawman choices. Triage findings; if valid issues remain, revise once and re-review. Stop after one revision pass to avoid loops.
4. **Recommend**: Provide **1 clear recommendation** based on clarity and maintainability.
5. **Write**: Save the reviewed options, review findings, recommendation, and decision to `.agents/sk-flows/<slug>/1 - ALTERNATIVES.md`. Update `RUNBOOK.md`.
6. **Wait**: Stop after writing and wait for the user's choice. **Do not edit code files.**

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Output

Markdown file at `.agents/sk-flows/<slug>/1 - ALTERNATIVES.md` with:

- Goal
- Options (Idea, Snippet, Pros, Cons)
- Review findings
- Recommendation
- Decision

The options are reviewed first; if the review finds valid issues, they are fixed before the user sees them.

## Alternatives review contract

The review subagent (or `sk-review-alternatives` skill) returns ONLY:

```text
### Alternatives Review Findings

option:1: <tag>: <problem>. <fix>
option:2: <tag>: <problem>. <fix>
option:3: <tag>: <problem>. <fix>
totals: N irrelevant N duplicate N weak N strawman N missing-context N unjustified | verdict: pass / needs-revision

Or exactly when no findings:

### Alternatives Review Findings

Lean & valid. Ship.
```

Tags:

- `irrelevant`: option does not solve the user's actual problem or constraints
- `duplicate`: option overlaps another option without adding a distinct trade-off
- `weak`: option is technically viable but worse in every meaningful dimension
- `strawman`: option is intentionally bad or only included to make another look good
- `missing-context`: option omits a critical cost, risk, or constraint
- `unjustified`: recommendation is not supported by the stated pros/cons

The parent triages each finding as `valid`, `false_positive`, or `unvalidated`. Fix `valid` issues once, then re-review. Present the final options when the review passes.

## Example

**Option 1: Shared helper function**

- **Idea:** Extract common logic
- **Snippet:**

```ts
function processData(d: Data[]) {
	return d.filter(validate).map(transform);
}
```

- **Pros:** DRY, consistent
- **Cons:** Adds indirection

**Recommendation:** Option 1 — best balance.
