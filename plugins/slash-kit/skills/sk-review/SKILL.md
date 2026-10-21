---
name: sk-review
description: One-shot, read-only code review, posted as inline comments on the PR lines like a human reviewer. Use when the user asks for sk-review, a read-only review, or a PR/branch/diff review without editing.
---

# Review

One-shot, read-only diff review: run three parallel `readonly` `general-purpose` Task subagents on the same diff, triage their findings, deliver only the `valid` ones. On a PR, they land as inline comments like a human reviewer. Do not fix or loop.

## When to use

- User asks for `sk-review`, a read-only review, or review without fixing.
- Before `sk-pr` when only a report is needed.
- As a lighter alternative to `sk-review-and-fix`.

## Active PR handoff

Follow `../sk-flow/SKILL.md` section "Active PR handoff".

## Flow context

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else inspect root runbooks. For a multi-PR runbook, use its exact `Active PR` and matching `Directory`; for a single-PR runbook, use the root. Require `3 - IMPLEMENTATION.md` and missing `4 - REVIEW.md` there.
3. If no flow exists and no slug is given, continue without a flow folder; `4 - REVIEW.md` is the only artifact.

## Input

- **Repository:** absolute path to repo root
- **Diff target:** `branch changes` (default), `uncommitted changes`, or an explicit branch/PR (number or URL)
- **Base branch:** only when non-default
- **Custom focus / out of scope:** only when the user gave constraints
- **Active plan:** exact `2 - PLANNING.md` in the active flow or PR directory; never choose by glob or modification time
- **Known validation gaps:** list missing plan/spec/Figma/tests; do not claim those areas verified

## Output contract

Start every review output (including subagent results, local reports, and the PR review body) with `AI review. harness: <harness>, model: <model>`. In `4 - REVIEW.md` the header goes on the line directly under the title. Fill each field from the running environment; use `unknown` when unavailable, never guess. Every inline PR comment starts with `[AI review]`.

Each subagent returns ONLY the disclosure header plus the findings block below.

```text
You are a read-only diff reviewer. Produce ONLY the disclosure header and findings block below; do not implement fixes.

Repository: <absolute path>
Diff: <branch changes | uncommitted changes>
Base branch: <only when non-default>
Custom focus: <only when user gave constraints>
Out of scope: <only when user excluded areas>
Known validation gaps: <only when context/capability missing — list each; do not claim those areas verified>

Run the diff yourself (e.g. git diff <base>...<head> or git diff for uncommitted). Read changed files, relevant callers, callees, tests, contracts, and existing helpers. Check duplication, cohesion, coupling, control flow, abstraction, naming, data modeling, repository consistency, and change impact.

Output ONLY in this format (no prose intro, no sections swapped). Fill the header from your running environment; use `unknown` for unavailable fields, never guess.

AI review. harness: <harness>, model: <model>

### Review Findings

section:line: <emoji> <tag>: <problem/over-engineering>. <fix/replacement>.
totals: N🔴 N🟡 N✂️ N🪵 N⚡ N🔵 N❓ | net: -<N> lines possible

Or exactly when no findings:

AI review. harness: <harness>, model: <model>

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
```

## Clean-code criteria

Report only concrete violations introduced or exposed by the diff:

- **Duplication**: logic repeated in places that must change together.
- **Cohesion**: a function, class, or module performs unrelated jobs.
- **Coupling**: implementation details leak across boundaries or unrelated modules must change together.
- **Control flow**: nesting, branching, or state transitions obscure behavior.
- **Abstraction**: wrappers or interfaces add indirection without removing duplication or isolating volatility.
- **Naming**: names misrepresent behavior, units, ownership, or side effects.
- **Data modeling**: invalid states are easy to construct or related values travel separately.
- **Repository consistency**: the change bypasses an existing helper or established local pattern.
- **Change impact**: inspect affected callers, callees, tests, and contracts outside the diff.

Require a concrete failure, maintenance cost, or smaller replacement. Do not report function length, class size, or subjective style by itself.

## Parallel review

If the diff is empty, reply with `AI review. harness: <harness>, model: <model>` plus one sentence and stop.

1. **Resolve scope** — repository, diff target, base branch, custom focus, out-of-scope exclusions, known validation gaps.
2. **Dispatch three reviewers** — in one message, start three `readonly` `general-purpose` Task subagents with the same prompt. Use three different models if the harness supports per-invocation model overrides (orchestrator picks, e.g. fast, balanced, deep); otherwise run all three with the session default.
3. **Triage** — label every finding `valid`, `false_positive`, or `unvalidated` with a one-line reason. Count `valid` only; record `unvalidated` items as validation gaps.
4. **Display** — the disclosure header plus one `### Review Findings` block with only the `valid` findings, deduplicated by file:line:tag. If none remain, report `Lean & valid. Ship.`
5. **Deliver** — PR mode: post the findings (see below); otherwise display the block locally. Either way write `4 - REVIEW.md` and update `RUNBOOK.md` row `4` to `done` (`diverged` if you departed from read-only review; PR mode: add the posted review URL). Do not fix.

## Posting the review to a PR

PR mode only when the user passed a PR link/number or explicitly asked (e.g. `/sk-review review the pr`). Any other target stays local, nothing posted.

- **Inline comments, like a human reviewer** — one review comment per `valid` finding on the exact file and line (line range for multi-line). The line must be part of the PR diff; if not, anchor to the nearest changed line it concerns, and if none fits, move the finding to the general remarks.
- **General remarks in one place** — verdict, validation gaps, and anything not tied to a line go in the review body, not scattered across inline comments.
- **One review, one notification** — submit all inline comments plus the general remarks as a single PR review:

    ```bash
    sha=$(gh pr view <n> --json headRefOid -q .headRefOid)
    gh api repos/{owner}/{repo}/pulls/<n>/reviews --input review.json
    ```

    ```json
    {
    	"commit_id": "<sha>",
    	"event": "COMMENT",
    	"body": "AI review. harness: <harness>, model: <model>\n\n<general remarks>",
    	"comments": [
    		{
    			"path": "src/file.ts",
    			"line": 42,
    			"side": "RIGHT",
    			"body": "[AI review] <problem>. <fix>."
    		},
    		{
    			"path": "src/file.ts",
    			"start_line": 10,
    			"line": 15,
    			"side": "RIGHT",
    			"body": "[AI review] <problem>. <fix>."
    		}
    	]
    }
    ```

    Delete `review.json` after the call, even on failure.

- **No duplicates** — skim existing review comments first (`gh api repos/{owner}/{repo}/pulls/<n>/comments --paginate`) and skip findings already raised.
- If posting fails, display the findings block locally and say the PR post failed.

## Writing for the PR

Everything posted to the PR is short, clear, concise, and human-readable - write like a person reviewing a colleague's PR.

- One or two plain sentences per comment: the problem, then the fix.
- No emoji tags, totals, or report scaffolding in PR comments; those stay in the local findings block and `4 - REVIEW.md`.
- No filler, no praise padding, no restating the code back to the author.
- `❓` findings become plain questions to the author.

## Rules

- Read-only: no file edits or code changes.
- Do not suppress findings because they are hard to fix.
- If the user asks for fixes, switch to `sk-review-and-fix`.
