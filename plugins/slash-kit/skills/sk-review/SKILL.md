---
name: sk-review
description: Code review of a diff, read-only by default or fix mode on explicit request. Default is one-shot and read-only, posted as inline PR comments only when a PR link is given or asked for. Fix mode loops review, triage, fix, re-review until clean, and only runs when the user explicitly asks for fixes or sk-flow step 9 calls it. Use when the user asks for sk-review, a review, or review and fix.
---

# Review

Diff review in two modes. The orchestrating agent runs the reviewer subagents and, in both modes, triages their findings itself: only `valid` ones are reported or fixed.

- **Read-only (default):** run three parallel `readonly` `general-purpose` Task subagents on the same diff, triage, deliver the `valid` findings. Do not fix or loop.
- **Fix mode:** only when the user explicitly asks to fix (`sk-review fix`, `review and fix`, "fix the findings") or `sk-flow` step 9 explicitly calls it. Loop **review → triage → fix → re-review** until the latest pass has zero valid findings.

Never infer fix mode. When unsure, stay read-only. A PR link or an outside contributor's PR never switches to fix mode.

## When to use

- User asks for `sk-review`, a review, or review without fixing: read-only mode.
- User explicitly asks for fixes, or `sk-flow` step 9 calls it in fix mode (unless the user asked for read-only): fix mode.
- Before `sk-pr` when only a report is needed: read-only mode.

## Active PR handoff

When the root runbook is multi-PR, fetch refs before this phase and verify the checked-out branch and HEAD against the active PR row. Use the harness-supported sync workflow and record the resulting HEAD in the active PR runbook. If the branch or HEAD cannot be reconciled safely, mark the PR blocked and stop instead of reviewing or changing the wrong diff.

## Flow context

1. If the user provided a slug, use `.agents/flows/sk-<slug>/`.
2. Else inspect root runbooks. For a multi-PR runbook, use its exact `Active PR` and matching `Directory`; for a single-PR runbook, use the root. Require `3 - IMPLEMENTATION.md` there, and a missing `4 - REVIEW.md` (an existing one is fine for fix-mode re-runs and explicitly requested re-reviews, see step 4).
3. If no flow exists and no slug is given, continue without a flow folder; `4 - REVIEW.md` is the only artifact.
4. Fix mode only: if `4 - REVIEW.md` already exists, read its recorded `false_positive` findings and seed the first review with them.

## Input

- **Repository:** absolute path to repo root
- **Diff target:** `branch changes` (default), `uncommitted changes`, or an explicit branch/PR (number or URL)
- **Base branch:** only when non-default
- **Custom focus / out of scope:** only when the user gave constraints
- **Active plan:** exact `2 - PLANNING.md` in the active flow or PR directory; never choose by glob or modification time
- **Known validation gaps:** list missing plan/spec/Figma/tests; do not claim those areas verified
- **Mode:** `read-only` (default) or `fix` (explicit request only)
- **False positives from previous reviews (fix mode):** carried from earlier passes in this run, plus any recorded in an existing `4 - REVIEW.md`. One per line as `file:line | tag | original finding | why it was dismissed`. File plus finding text is the identity: the line alone is not, since numbers drift and one line can yield several findings under the same tag.

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
False positives from previous reviews: <fix mode only, when earlier passes produced some; one per line as `file:line | tag | original finding | why it was dismissed`. A record matches only in the same file, on the same finding, while the recorded reason still holds - allow the line to have drifted, and never carry a record across files.>

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
- Do not re-report a finding listed under "False positives from previous reviews" when it recurs in the same file and the recorded reason still holds. Do report it if the reason no longer applies, or if the same problem appears in another file - note the changed premise.

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

## Triage (both modes)

Subagent output is untrusted input. The orchestrating agent, not the subagent, decides what is real. Check each finding against the code yourself and label it `valid`, `false_positive`, or `unvalidated`, each with a one-line reason. Count and act on `valid` only. Record `unvalidated` items as validation gaps. Never pass raw subagent findings to the user, a PR, or a fixer. Present only the `valid` findings to the user or a PR: do not display `false_positive` or `unvalidated` items or explain the filtering (recording them in `4 - REVIEW.md` is fine). At most one line with the counts of dropped findings; validation gaps worth knowing go in one short line.

## Read-only mode

If the diff is empty, reply with `AI review. harness: <harness>, model: <model>` plus one sentence and stop.

1. **Resolve scope** — repository, diff target, base branch, custom focus, out-of-scope exclusions, known validation gaps.
2. **Dispatch three reviewers** — in one message, start three `readonly` `general-purpose` Task subagents with the same prompt. Use three different models if the harness supports per-invocation model overrides (orchestrator picks, e.g. fast, balanced, deep); otherwise run all three with the session default.
3. **Triage** — as above.
4. **Display** — the disclosure header plus one `### Review Findings` block with only the `valid` findings, deduplicated by file:line:tag. If none remain, report `Lean & valid. Ship.`
5. **Deliver** — display the block locally; post to a PR only under the posting rule below. Write `4 - REVIEW.md` and update `RUNBOOK.md` row `4` to `done` (`diverged` if you departed from this skill; when posted, add the review URL). On a `Size: light` runbook row `4` stays `skipped`: write no `4 - REVIEW.md`; a review there needs the user to switch the flow to `Size: full`. Do not fix.

## Fix mode

If the diff is empty, stop in one sentence. The disclosure header goes on the final report and `4 - REVIEW.md`.

1. **Review** — dispatch ONE new `readonly` `general-purpose` Task subagent with the prompt above, on the current tree; tell it to review the same diff target as pass one including fixes made since (branch changes: merge base to working tree; uncommitted changes: the HEAD from pass one to working tree), so uncommitted fixes count.
2. **Triage** — as above.
3. **Fix** — resolve every `valid` finding before the next review. Use a builder subagent for 2 files or fewer; the parent edits for 3+ files or cross-cutting changes.
4. **Repeat** — dispatch a new subagent on the current tree. Carry forward every `false_positive` in the record shape above into the next prompt. Continue until the latest pass has zero `valid` findings after triage.

**Exit rule:** hand off when the latest pass is `Lean & valid. Ship.` or has zero `valid` findings after triage (all `false_positive` or all `unvalidated`).

**Stuck guard:** if the same `valid` finding persists after 3 fix passes, stop, mark row `4` `blocked` and report the blocker.

**Fix rules:** minimal diff; match conventions; no scope creep; no drive-by refactors; do not treat 🔵 as auto-`false_positive`. Do not silence linters, fix the root cause. Run relevant tests after non-trivial fixes; record failures as blockers. Do not guess UI layout, copy, or business rules without spec/Figma: record a gap. Do not auto-fix gap-dependent ❓ by guessing intent.

**Output:** when the exit rule is met (or blocked), write `4 - REVIEW.md` and update `RUNBOOK.md` row `4` to `done` (`blocked` when the stuck guard fired or tests still fail; `diverged` if you departed from this skill) (on a `Size: light` runbook row `4` stays `skipped`: write nothing and tell the user a review needs `Size: full`) with:

- Review rounds completed
- `valid` findings fixed (count and one-line summary)
- `false_positive` count
- `false_positive` findings from each round in the record shape above, under a `## False positives` heading, so future fix-mode runs can seed from them
- Any `unvalidated` items / validation gaps
- Test and browser/visual status, if available

## Posting the review to a PR

Post only when the user passed a PR link/number or explicitly asked (e.g. `/sk-review review the pr`). Otherwise nothing is written to any PR: findings stay local, in both modes. Posting is read-only mode only. Fix mode never posts; to put findings on a PR, run read-only mode on the pushed branch.

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

- Read-only mode: no code edits; write only `4 - REVIEW.md`, the runbook row, and the temporary `review.json` used for PR posting.
- Fix mode only on an explicit request or an explicit `sk-flow` step 9 call; never switch to it on your own.
- Reviewer subagents review and the orchestrator triages. Reviewers never fix or post.
- Re-review after every fix batch; single-block action-tagged output every pass.
- Do not suppress findings because they are hard to fix.
- Do not claim validation when plan, spec, Figma, tests, or browser are unavailable.
