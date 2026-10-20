# 4 — Review: ai-review-disclosure

AI review. harness: devin-cli, model: unknown

## Scope

- Repository: /home/sandbox/dev/instinct-runs/ai-pr27-review
- Diff: `feat/ai-review-disclosure` vs `main`
- Skill: `sk-review-and-fix` (no flow folder; this file is the only artifact)

## Rounds

1. 4 findings: 2 valid, 2 false_positive. Fixes: subagent contract reworded to "ONLY the disclosure header plus the findings block"; empty-diff path now spells out the literal header.
2. 2 findings: both valid. Fixes: `4 - REVIEW.md` explicitly covered by the disclosure contract (header under the title); Display step restructured so the header clearly applies to both branches.
3. 2 findings: 1 valid (empty-diff sentence ambiguity → "reply with the header plus one sentence and stop"), 1 false_positive.
4. `Lean & valid. Ship.`

Plugin copy `plugins/slash-kit/skills/sk-review/SKILL.md` kept identical via `scripts/sync-devin-plugin.sh`.

## Valid findings fixed

4 total: contradictory "ONLY the findings block" wording, ambiguous empty-diff instruction (twice), unspecified header placement for `4 - REVIEW.md`, Display step dropping the header in the no-findings branch.

## False positives

- skills/sk-review/SKILL.md:L37 | 🟡 gap | Contract says "every review output" gets header but sk-review-and-fix lacks it | Contract is scoped to the sk-review skill it lives in; commit 81a228f deliberately kept disclosure changes in sk-review only.
- skills/sk-review/SKILL.md:L55 | ❓ question | Which model fills header when three reviewers run on different models | "Fill each field from the running environment" already covers it: each emitter fills its own env.
- skills/sk-review/SKILL.md:L114 | 🟡 gap | No-findings clause doesn't restate the header | The Display step opens with "the disclosure header plus one ### Review Findings block", which governs both branches; restating is redundant.

## Validation gaps

- No test suite exercises these markdown skill files; agent behavioral conformance unverified.
