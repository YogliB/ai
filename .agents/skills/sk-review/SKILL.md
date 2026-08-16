---
name: sk-review
description: >
    One-shot read-only code review using a Task subagent with single-block action-tagged output
    combining correctness (cavecrew) and ponytail complexity reduction. Does NOT apply fixes or loop.
    Alerts explicitly when context or capabilities insufficient to validate. Use when user asks for
    sk-review, read-only review, review code without fixing, or review PR/branch/diff
    without editing.
---

# Review

One-shot, read-only code review. Dispatches a **single Task subagent** to produce action-tagged findings (`### Review Findings`) combining correctness (cavecrew) and ponytail complexity reduction, then writes `4 - REVIEW.md` and updates the runbook without applying any fixes.

## Slug and flow folder

1. Determine the active flow:
    - If the user provided a slug, use `.agents/sk-flows/<slug>/`.
    - Else find the flow whose `RUNBOOK.md` is most recent.
    - If no flow exists and the user did not name one, continue without a flow folder; `4 - REVIEW.md` will be the only artifact.
2. Read the active plan (newest `2 - PLANNING*.md` in the active flow, if one exists) as context.
3. Write the final report to `.agents/sk-flows/<slug>/4 - REVIEW.md`.
4. Update `RUNBOOK.md` row `4` to `done` (or `diverged` if the agent departed from read-only review).

## Workflow

1. **Resolve scope:**
    - Repository: absolute path to repo root.
    - Diff target (`branch changes` default, or `uncommitted changes`, or explicit branch/PR).
    - Base branch if non-default.
2. **Context & validation check:**
    - Check if plan/spec, Figma, or runnable tests are missing.
    - If the active flow has a plan file under `2 - PLANNING*.md`, read the latest one as context.
    - If material context is missing, note under `Known validation gaps:`.
3. **Dispatch review subagent:**
    - Launch a **Task** subagent (`subagent_type: "generalPurpose"`, `readonly: true`). Do not perform the review inline in the parent thread.
    - Pass prompt with repository path, diff target, and output contract.
4. **Present report:**
    - Write `.agents/sk-flows/<slug>/4 - REVIEW.md` with the structured findings, summary line, and any validation gaps.
    - Update `RUNBOOK.md` row `4`.
    - Stop. Do NOT apply any fixes or enter a fix loop.

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Subagent prompt contract

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

Examples (tone only — not this repo's code):
- L12-38: ⚡ simplify: 27-line email validator class. Use standard shape check or rely on confirmation mail.
- L4: ⚡ simplify: moment.js for one date format call. Use native Intl.DateTimeFormat, no extra dependency.
- repo.py:L88: 🪵 yagni: AbstractRepository with one implementation. Inline until a second backend exists.
- L52-71: ✂️ cut: retry wrapper around an idempotent local call. Remove wrapper.
- L30-44: ⚡ simplify: loop builds dict from parallel lists. dict(zip(keys, values)).

End with exactly one line:
- totals: N🔴 N🟡 N✂️ N🪵 N⚡ N🔵 N❓ | net: -<N> lines possible
- Or: Lean & valid. Ship.
```

## Constraints

- Read-only: strictly no file edits or code changes.
- Single-pass: output findings and stop.
