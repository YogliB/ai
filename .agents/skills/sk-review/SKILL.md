---
name: sk-review
description: One-shot, read-only code review. Use when the user asks for sk-review, a read-only review, or a PR/branch/diff review without editing.
---

# Review

One-shot, read-only diff review. Run three parallel `readonly` `general-purpose` Task subagents on the same diff, triage their findings, and display only the `valid` findings. Do not fix or loop.

## When to use

- User asks for `sk-review`, a read-only review, or review without fixing.
- Before `sk-pr` when only a report is needed.
- As a lighter alternative to `sk-review-and-fix`.

## Flow context

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else look for a stuck flow: one where `3 - IMPLEMENTATION.md` exists and `4 - REVIEW.md` is missing. If one, suggest continuing it. If several, list them and ask. If none, find the most recent `RUNBOOK.md`.
3. If no flow exists and no slug is given, continue without a flow folder; `4 - REVIEW.md` is the only artifact.

## Input

- **Repository:** absolute path to repo root
- **Diff target:** `branch changes` (default), `uncommitted changes`, or explicit branch/PR
- **Base branch:** only when non-default
- **Custom focus / out of scope:** only when the user gave constraints
- **Active plan:** newest `2 - PLANNING*.md` in the active flow
- **Known validation gaps:** list missing plan/spec/Figma/tests; do not claim those areas verified

## Output contract

Each subagent returns ONLY the findings block below.

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

## Parallel review

If the diff is empty, stop in one sentence.

1. **Resolve scope** — repository, diff target, base branch, custom focus, out-of-scope exclusions, and known validation gaps.
2. **Dispatch three reviewers** — in one message, start three `readonly` `general-purpose` Task subagents with the same prompt and different models:
    - `model: haiku` — fast pass for obvious issues
    - `model: sonnet` — balanced pass
    - `model: opus` — deep pass

    If the harness does not support per-invocation model overrides, run all three with the session default.

3. **Triage** — label every returned finding `valid`, `false_positive`, or `unvalidated` with a one-line reason. Count `valid` only. `unvalidated` items are recorded as validation gaps.
4. **Display** — output a single `### Review Findings` block containing only the `valid` findings, deduplicated by file:line:tag. If no `valid` findings remain, output exactly `Lean & valid. Ship.`.
5. **Stop** — do not fix. Write `4 - REVIEW.md` and update `RUNBOOK.md` row `4` to `done`.

## Output destination

Write the `valid`-only report to `.agents/flows/sk-<slug>/4 - REVIEW.md` and update `RUNBOOK.md` row `4` to `done`. If you depart from read-only review, use `diverged`.

## Rules

- Read-only: no file edits or code changes.
- Do not suppress findings because they are hard to fix.
- If the user asks for fixes, switch to `sk-review-and-fix`.
