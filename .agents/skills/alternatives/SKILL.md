---
name: alternatives
description: Suggest up to 3 viable alternatives for code or design decisions before committing to an implementation. Use when the user asks for alternatives, options, or "better ways" to solve a problem.
---

# Alternatives

## Steps

1. **Identify Options**: Brainstorm distinct approaches (e.g., different patterns, libraries, or architectural choices).
2. **Present**: For each option, provide:
   - **Idea**: Short description.
   - **Snippet**: Minimal code example (if relevant).
   - **Pros / Cons**: Brief, balanced assessment.
3. **Review**: Dispatch a **review-alternatives** subagent (or invoke the `review-alternatives` skill) to evaluate the options for relevance, distinctness, and weak/strawman choices. Triage findings; if valid issues remain, revise once and re-review. Stop after one revision pass to avoid loops.
4. **Recommend**: Provide **1 clear recommendation** based on clarity and maintainability.
5. **Wait**: Stop after presenting and wait for the user's choice. **Do not edit files.**

## Output Format

Markdown list of options followed by a recommendation. The options are reviewed first; if the review finds valid issues, they are fixed before the user sees them.

## Alternatives review contract

The review subagent (or `review-alternatives` skill) returns ONLY:

```text
### Alternatives Review Findings

option:1: <tag>: <problem>. <fix>
option:2: <tag>: <problem>. <fix>
option:3: <tag>: <problem>. <fix>
totals: N irrelevant N duplicate N weak N strawman N missing-context | verdict: pass / needs-revision

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
