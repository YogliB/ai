---
name: sk-review-alternatives
description: >
    Independent review of proposed alternatives before they are presented to the user.
    Checks for relevance, distinctness, weak or strawman options, and balanced pros/cons.
    Use when the sk-alternatives skill has generated options and you want a second opinion,
    or when the user passes a list of alternatives and asks for a review.
---

# Review Alternatives

## Purpose

Evaluate up to 3 proposed alternatives and flag low-quality options before the user sees them. This is a read-only review unless the user explicitly asks the reviewer to rewrite options.

## When to use

- After the `sk-alternatives` skill generates options
- When a user pastes a set of alternatives and asks you to review them
- Before presenting alternatives to a stakeholder where quality matters

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Input

The alternatives being reviewed, including for each option:

- **Idea**: short description
- **Snippet** (if present): minimal code or design example
- **Pros / Cons**: brief, balanced assessment
- **Recommendation** (if present): which option the author preferred and why

## Output contract

Return ONLY this block. No prose intro.

```text
### Alternatives Review Findings

option:<n>: <tag>: <problem>. <fix>
totals: N irrelevant N duplicate N weak N strawman N missing-context N unjustified | verdict: pass / needs-revision

Or exactly when no findings:

### Alternatives Review Findings

Lean & valid. Ship.
```

## Tags

Use these exact tags after the colon:

- `irrelevant`: the option does not solve the user's actual problem or constraints
- `duplicate`: the option overlaps another option without adding a distinct trade-off
- `weak`: the option is technically viable but worse in every meaningful dimension
- `strawman`: the option is intentionally bad or only included to make another look good
- `missing-context`: the option omits a critical cost, risk, or constraint
- `unjustified`: the recommendation is not supported by the stated pros/cons

## Review criteria

1. **Relevance to the real problem**: every option must address the user's actual constraints, not a simplified or adjacent problem.
2. **Distinctness**: options should differ on at least one meaningful trade-off (complexity, cost, portability, maintenance, etc.).
3. **Fairness**: pros and cons must be balanced. Do not include an option whose only purpose is to make another look good.
4. **Completeness**: each option should mention the main cost/risk/limitation.
5. **Recommendation support**: the final recommendation should be justified by the option comparisons.

## Output destination

The parent `sk-alternatives` skill writes the final options and these review findings into `.agents/sk-flows/<slug>/1 - ALTERNATIVES.md`. This subagent does not write files or update `RUNBOOK.md`.

## Rules

- One finding per line; problem then fix separated by ". "
- Sort findings by `option:<n>` ascending
- If the same issue spans multiple options, repeat it per option
- If no issues, output exactly `Lean & valid. Ship.`
- Do not add new options; only review what is provided
- Do not be overly harsh: minor wording issues or disagreements are not findings unless they mislead
