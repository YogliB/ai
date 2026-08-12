---
name: review-and-fix
description: >
    Review code changes in Task subagent using single-block action-tagged output
    combining correctness (cavecrew) and ponytail complexity reduction, triage findings,
    fix every valid issue, re-review until latest pass has zero valid findings.
    Alerts explicitly when context or capabilities insufficient to validate
    (missing plan/spec/Figma, tests or browser cannot run). Use when user asks to
    review-and-fix, review and fix, fix review findings, clean up branch or diff,
    or run /review-and-fix. All review passes must run in subagents — never inline
    review in parent thread. Review subagents ALWAYS use gemini-3.6-flash-high
    unless explicitly requested otherwise.
---

# Review and Fix

Closed loop: **review (subagent) → triage → fix → re-review (new subagent)** until clean. Each pass emits a single block of action-tagged findings (`### Review Findings`) combining correctness (cavecrew) and complexity reduction (ponytail). Parent **triages and fixes**; parent **never** substitutes checklist skim for review pass.

## Subagent models (default)

Review subagents **ALWAYS** use model `gemini-3.6-flash-high` unless the user explicitly requests a different model for a pass.

Parent (orchestrator) stays on its own model; **every subagent gets an explicit `model: "gemini-3.6-flash-high"` slug**.

**Override:** ONLY when the user explicitly requests a specific model (e.g. "use claude-opus-4-8-thinking-high for review") do you use that model for that pass.

## Run card

1. **Scope:** repo root (absolute), diff target (`branch changes` default, or `uncommitted changes`, or explicit branch/PR), base branch if non-default, custom focus, out-of-scope exclusions.
2. **Gaps:** list what validation needs vs what exists; if anything material missing, emit **Validation gaps** (template below) before or with first pass; refresh when diff surface changes a lot.
3. **Review:** new Task (`generalPurpose`, `readonly: true`, **`model:` per Subagent models**) each iteration — full subagent prompt below; pass `Known validation gaps:` when applicable.
4. **Triage:** every non-header line gets exactly one label: `valid` | `false_positive` | `unvalidated` (see Triage).
5. **Fix:** all `valid` before next review; `unvalidated` → gaps + no guess-fixes.
6. **Repeat** until exit rule or stuck/unfixable stop.

If diff empty after scope resolution, stop in one sentence.

**Contrast:** `/review-bugbot` is single-pass; this skill loops until clean or blocked.

## Resolve scope first

1. **Repository:** absolute path to repo root (active workspace unless user names another).
2. **Diff target** (default `branch changes`):
    - `branch changes` — merge-base vs default/base branch; includes committed, staged, unstaged on current branch.
    - `uncommitted changes` — working tree only.
    - **Explicit branch/PR** — check out target branch first (same rules as `/review-bugbot`: stash only after user confirms).
3. **Base branch** — only when diff must compare against non-default branch.
4. **Custom focus** — optional user constraints (e.g. "tests only", "exclude logging").
5. **Out of scope** — honor exclusions during triage (`false_positive` when excluded).

## Context and validation assessment (mandatory)

Before first review pass — and again when diff surface changes materially — match **what validates** this change to **what is available**. Do not imply full validation when gaps remain.

### Check for

| Change involves            | Often needed                                                | Alert when missing                                      |
| -------------------------- | ----------------------------------------------------------- | ------------------------------------------------------- |
| Feature / ticket work      | Plan, spec, PRD, acceptance criteria, ticket body           | Cannot confirm scope or correctness vs intent           |
| UI / UX                    | Figma (or design screenshot), design tokens, component spec | Cannot verify layout, states, copy, a11y vs design      |
| API / contract             | OpenAPI, GraphQL schema, consumer docs                      | Cannot verify request/response shape vs contract        |
| Integration / E2E behavior | Running stack, credentials, test data                       | Cannot exercise real flows                              |
| Regressions                | Runnable unit/integration tests                             | Cannot confirm behavior unchanged                       |
| Browser-only behavior      | Running app + browser (e.g. `agent-browser`)                | Cannot verify interactions, routing, visual regressions |

Also flag environment blockers: missing deps, no Poetry/node, sandbox/network limits, no DB/tunnel, tests exist but cannot run.

**Plan files:** If the repo has a plan file under `.agents/plans/`, read the latest one as context. If it is missing and the change is feature work, note it under `Known validation gaps:`.

### Alert the user

When gaps affect validation, **stop before claiming loop complete** unless user chose proceed-with-limits — surface **Validation gaps**:

```markdown
## Validation gaps

- **Missing:** <artifact or capability, e.g. Figma link, original plan, runnable tests>
- **Impact:** <what cannot be verified — be specific to this diff>
- **Risk:** <what might be wrong that review cannot catch>
- **To unblock:** <one concrete ask — attach file, paste spec, run tests locally, provide Figma URL, start dev server>
```

**Interactive:** one ask at a time. (a) User supplies context → resume. (b) User confirms **proceed with limits** → continue; keep gaps in every final report.

**Headless:** document gaps; do not invent validation. Proceed only for findings supportable from repo + diff alone.

### Gaps vs loop (single reference)

| Phase  | Rule                                                                                                                                                                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Review | Include `Known validation gaps:` in subagent prompt when missing. Subagent must not assert design/E2E/spec compliance it cannot verify — use `❓` with gap cited, or omit.                                                            |
| Triage | Depends on missing context → `unvalidated`, not auto-fixed. Not `false_positive` unless wrong even without context. Do not call loop **fully validated** while material `unvalidated` 🔴/🟡 remain.                                   |
| Fix    | No guessed UI layout, copy, or business rules without spec/Figma. Fix only what code + available context support.                                                                                                                     |
| Exit   | Zero `valid` findings after triage can coexist with documented **Validation gaps** (records what was never exercised). If any gap remains at handoff, **Validation gaps** must appear in final report — no silent partial validation. |

## Review loop (mandatory)

Repeat until **exit rule** met. **Every Review step = new Task subagent** (including after fixes). Do not reuse prior review text as latest pass.

### 1. Review

Launch **Task** with:

- `subagent_type: "generalPurpose"`
- `readonly: true`
- `model:` slug per **Subagent models** (required every pass)
- `run_in_background: false` unless user asked for background
- `description: "review pass N (<model>)"` (increment N each loop)

**Prompt shape** (fill placeholders; omit optional lines when unused):

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

**Subagent failure:** fix invocation, retry once. If diff cannot be computed, retry with explicit file list + `git diff` in prompt. If still failing, stop with blocker — do not fabricate a pass.

### 2. Triage

**Labels (use these literals):** `valid` | `false_positive` | `unvalidated`

For **each** finding: assign one label plus one-line reason.

| Typical `valid`                                                      | Typical `false_positive`                                                      |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Real bug, security risk, incorrect logic                             | Already fixed earlier in loop                                                 |
| Missing/error-prone test for changed behavior                        | Intentional design user confirmed                                             |
| Maintainability issue that blocks safe change                        | Out-of-scope per user                                                         |
| Nit that violates stated project rule                                | Stale line number; code no longer matches                                     |
| Question exposing ambiguity needing code/test change                 | Pure preference, no correctness impact                                        |
| Dead code, reinvention, single-use abstraction to inline (`✂️`/`🪵`) | User or ticket explicitly required that abstraction, library, or config shape |
| Clear stdlib/native swap or measurable shrink (`⚡`)                 | "Could be shorter" with no concrete replacement or net ≤0                     |
| Speculative branch not tied to DOD (`✂️`)                            | Would remove only test or self-check for changed logic                        |

**❓ findings:** `valid` only when repo context can resolve via code or test; else `false_positive` or one clarifying question (interactive) then continue.

**Gap-dependent:** needs missing plan/spec/Figma/runtime/browser/tests → `unvalidated`, add to **Validation gaps**, do not auto-fix. Unblock or proceed-with-limits per user.

Count **valid** this pass (excludes `unvalidated`). `Lean & valid. Ship.` means zero valid findings after triage.

### 3. Fix

Resolve **every `valid`** finding before next review.

| Fix scope                                 | Use                                                                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| ≤2 files, surgical                        | `cavecrew-builder` via Task (`subagent_type: "generalPurpose"`, not readonly, **`model:`** per **Subagent models**) |
| 3+ files or cross-cutting                 | Parent thread edits                                                                                                 |
| Builder returns `too-big.` / `ambiguous.` | Parent thread takes over for that finding                                                                           |

- Minimal diff; match conventions; no scope creep.
- Do not silence linters (`noqa`, `eslint-disable`, etc.) — fix root cause.
- Run **relevant tests** after non-trivial fixes when repo has clear test command; fix failures before re-review. If tests cannot run, record under **Validation gaps**.
- UI: without Figma/design, do not guess layout/copy — record gap.
- **Commits:** only when user rules or explicit request allow.

**Unfixable** (design decision, rule conflict, investigation shows `false_positive` but loop cannot close): **STOP**; report file, finding, blocker.

### 4. Repeat

New **Review** subagent on **current** tree.

**Exit rule:** latest pass has **zero `valid`** findings after triage (`Review Findings` outputs `Lean & valid. Ship.` or all findings triaged false positive).

Do not stop while `valid` findings remain.

**Stuck guard:** same `valid` finding (same file, line/span, same sense) after **3** fix passes → stop; report persistence + what was tried.

## Final report

When exit rule met (or blocked):

- Review rounds completed; **subagent models** used per pass (review + fix Tasks)
- `valid` fixed (count; optional table: action tag, location, one-line fix)
- Subagent `net: -N` vs approximate lines removed, or `Lean & valid. Ship.` when triage agreed
- `false_positive` count (detail only if asked)
- **Validation gaps** when anything missing; include open `unvalidated` items
- Tests: result or **not run** + why
- Browser/visual: done or **not performed** + why
- Uncommitted vs committed state
- Deferred out-of-scope items

**Confidence line:** one sentence, e.g. "Verifiable surface clean; UI vs Figma and E2E not validated."

## Constraints

- **Subagent-only reviews** every iteration; no parent-authored findings; no parent merging partial subagent outputs into one pass.
- **Review model:** ALWAYS use `gemini-3.6-flash-high` for every review and re-review subagent unless the user explicitly requests a different model.
- **Single-block action-tagged output every pass** — `Review Findings` contract above (cavecrew + ponytail combined into one stream).
- **Re-review** after every fix batch — no "fixes look obvious" skip.
- **Headless:** no mid-loop confirmation; stop on unfixable blocker or stuck guard.
- **Interactive:** one clarifying question when triage needs input; then resume.
- No drive-by refactors; do not treat 🔵 as auto-`false_positive` — triage on merit.
- Do not claim implementation correct when plan, spec, Figma, tests, or browser unavailable.
- Do not auto-fix gap-dependent ❓ by guessing intent.
