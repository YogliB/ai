---
name: sk-alternatives
description: Suggest up to 3 viable alternatives for a code or design decision. Use when the user asks for alternatives, options, or "better ways".
---

# Alternatives

## Slug and flow folder

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. If the user gave no clear context, look for a stuck flow: one where `0 - EXPLORE.md` exists and `1 - ALTERNATIVES.md` is missing. If one, suggest continuing it. If several, list them and ask. If none, derive a slug from the decision and confirm.
3. Create the folder if needed. Initialize or update `RUNBOOK.md` with all phases `pending` and row `1` as `in-progress`.
4. Write the final doc to `1 - ALTERNATIVES.md` and set row `1` to `done`, `skipped`, or `diverged` with a reason.

This skill can run on its own; it still maintains the flow folder and runbook.

## Steps

1. **Identify** — up to 3 distinct approaches. If only one is viable, document that and skip to planning.
2. **Present** — for each option: idea, snippet (if relevant), pros, cons.
3. **Review** — run the `sk-review-alternatives` skill. Triage findings; if valid, revise once and re-review.
4. **Recommend** — one clear choice based on clarity and maintainability.
5. **Write** — save options, review findings, recommendation, and decision to `1 - ALTERNATIVES.md`. Update `RUNBOOK.md`.
6. **Wait** — stop for the user's choice. Do not edit code files.

## Output

`1 - ALTERNATIVES.md` contains:

- Goal
- Options (Idea, Snippet, Pros, Cons)
- Review findings
- Recommendation
- Decision

## Alternatives review contract

The `sk-review-alternatives` skill returns ONLY:

```text
### Alternatives Review Findings

option:<n>: <tag>: <problem>. <fix>
totals: N irrelevant N duplicate N weak N strawman N missing-context N unjustified | verdict: pass / needs-revision
```

Or, when no findings:

```text
### Alternatives Review Findings

Lean & valid. Ship.
```

Tags: `irrelevant`, `duplicate`, `weak`, `strawman`, `missing-context`, `unjustified`.

Triage each finding as `valid`, `false_positive`, or `unvalidated`. Fix `valid` issues once, then re-review.

## Example

**Option 1: Shared helper**

- **Idea:** Extract common logic.
- **Snippet:**
    ```ts
    function processData(d: Data[]) {
    	return d.filter(validate).map(transform);
    }
    ```
- **Pros:** DRY, consistent.
- **Cons:** Adds indirection.

**Recommendation:** Option 1 — best balance.
