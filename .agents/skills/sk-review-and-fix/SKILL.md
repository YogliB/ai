---
name: sk-review-and-fix
description: Closed-loop code review through review, triage, fix, and re-review until the latest pass is clean. Use when the user asks for sk-review-and-fix, /review, or review and fix.
---

# Review and Fix

Closed-loop diff review: **review → triage → fix → re-review** until the latest pass has zero valid findings.

## When to use

- User asks for `sk-review-and-fix`, `/review`, or fixing review findings.
- After implementation, when review and fixes should happen in one pass.

## Flow context

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else find the most recent `RUNBOOK.md`.
3. If no flow exists and no slug is given, continue without a flow folder; `4 - REVIEW.md` is the only artifact.

## Input

- **Repository:** absolute path to repo root
- **Diff target:** `branch changes` (default), `uncommitted changes`, or explicit branch/PR
- **Base branch:** only when non-default
- **Custom focus / out of scope:** only when the user gave constraints
- **Active plan:** newest `2 - PLANNING*.md` in the active flow
- **Known validation gaps:** list missing plan/spec/Figma/tests/browser; do not claim those areas verified

## Output contract

The subagent is read-only and returns ONLY the findings block below.

```text
You are a read-only diff reviewer. Produce ONLY the findings block below; do not implement fixes.

Repository: <absolute path>
Diff: <branch changes | uncommitted changes>
Base branch: <only when non-default>
Custom focus: <only when user gave constraints>
Out of scope: <only when user excluded areas>
Known validation gaps: <only when context/capability missing — list each; do not claim those areas verified>

Run the diff yourself (e.g. git diff <base>...<head> or git diff for uncommitted). Read changed files as needed.

Output ONLY in this format (no prose intro, no sections swapped).

### Review Findings

section:line: <emoji> <tag>: <problem/over-engineering>. <fix/replacement>.
totals: N🔴 N🟡 N✂️ N🪵 N⚡ N🔵 N❓ | net: -<N> lines possible

Or exactly when no findings:

### Review Findings

Lean & valid. Ship.

Rules for Review Findings:
- Sort findings file → line ascending
- One finding per line; problem then fix separated by ". "
- Location format: L<line>: for single line, L<start>-<end>: for span, or <file>:L<line>: when multiple files
- Action tags (literal after colon):
  - 🔴 bug: correctness bug, security risk, broken logic, regression
  - 🟡 gap: missing/error-prone test, error handling gap, maintainability defect
  - ✂️ cut: dead code, unused feature/dependency, speculative code (replacement: nothing)
  - 🪵 yagni: single-caller layer, unset config, premature abstraction (replacement: inline or drop)
  - ⚡ simplify: hand-rolled stdlib behavior, native platform duplicate, complex pattern (replacement: name function/type/feature or shorter form)
  - 🔵 nit: naming, minor style, formatting
  - ❓ question: unclear logic, missing spec/context (cite gap if missing)
- Do not report style-only nits outside project norms unless indicating real bugs.
- Do not flag a single smoke test, one assert-based self-check, or the smallest runnable check guarding changed logic.

Examples (tone only):
- L12-38: ⚡ simplify: 27-line email validator class. Use standard shape check or rely on confirmation mail.
- repo.py:L88: 🪵 yagni: AbstractRepository with one implementation. Inline until a second backend exists.
- L52-71: ✂️ cut: retry wrapper around an idempotent local call. Remove wrapper.

End with exactly one line:
- totals: N🔴 N🟡 N✂️ N🪵 N⚡ N🔵 N❓ | net: -<N> lines possible
- Or: Lean & valid. Ship.
```

## Tags

- `🔴 bug`: correctness bug, security risk, broken logic, regression
- `🟡 gap`: missing/error-prone test, error handling gap, maintainability defect
- `✂️ cut`: dead code, unused feature/dependency, speculative code
- `🪵 yagni`: single-caller layer, unset config, premature abstraction
- `⚡ simplify`: hand-rolled stdlib behavior, native platform duplicate, complex pattern
- `🔵 nit`: naming, minor style, formatting
- `❓ question`: unclear logic, missing spec/context

## Review criteria

- Correctness, security, and broken logic
- Tests and error handling
- Maintainability and dead code
- Unnecessary abstraction vs native/standard alternatives
- Naming and style
- Missing context (cite the gap)

## Loop

If the diff is empty, stop in one sentence.

1. **Review** — dispatch a new `readonly` `generalPurpose` Task subagent with the prompt above.
2. **Triage** — label each finding `valid`, `false_positive`, or `unvalidated`. Count `valid` only. `unvalidated` items are recorded as validation gaps.
3. **Fix** — resolve every `valid` finding before the next review. Use a builder subagent for ≤2 surgical files; parent edits for 3+ files or cross-cutting changes.
4. **Repeat** — dispatch a new subagent on the current tree. Continue until the latest pass has zero `valid` findings after triage.

**Exit rule:** hand off when the latest pass is `Lean & valid. Ship.` or all findings are `false_positive`.

**Stuck guard:** if the same `valid` finding persists after 3 fix passes, stop and report the blocker.

## Fix rules

- Minimal diff; match conventions; no scope creep.
- Do not silence linters — fix the root cause.
- Run relevant tests after non-trivial fixes; record failures as blockers.
- Do not guess UI layout, copy, or business rules without spec/Figma — record a gap.

## Output destination

When the exit rule is met (or blocked), write `4 - REVIEW.md` and update `RUNBOOK.md` row `4` with:

- Review rounds completed
- `valid` findings fixed (count and one-line summary)
- `false_positive` count
- Any `unvalidated` items / validation gaps
- Test and browser/visual status, if available

## Rules

- Subagent-only reviews every iteration.
- Single-block action-tagged output every pass.
- Re-review after every fix batch.
- No drive-by refactors; do not treat 🔵 as auto-`false_positive`.
- Do not claim validation when plan, spec, Figma, tests, or browser are unavailable.
- Do not auto-fix gap-dependent ❓ by guessing intent.
