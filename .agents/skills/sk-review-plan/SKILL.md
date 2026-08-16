---
name: sk-review-plan
description: Read-only review of a technical plan. Checks for self-containment, executability, TODO atomicity/testability, scope/acceptance alignment, missing files/dependencies, contradictions, unrealistic sequencing, and ponytail complexity reduction. Returns a single `### Plan Review Findings` block. Use when the sk-planning skill has drafted a plan, or when the user passes a plan and asks for a review.
---

# Plan Review

## Purpose

Evaluate a technical plan before it is handed off for implementation. Flag correctness blockers, gaps, and unnecessary complexity while preserving the current plan shape.

## When to use

- After `sk-planning` writes a draft plan
- When the user pastes a plan and asks for a review
- Before presenting a masterplan or sub-plan to a stakeholder

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Input

The full plan text, plus any required context the reviewer needs:

- Repository constraints and conventions
- User scope and acceptance criteria
- Masterplan ↔ sub-plan linkage, when a masterplan is split
- Known validation gaps, if any

Paste the full plan text into the prompt. Do not point the subagent at plan files on disk.

## Output contract

Return **only** the findings block. No prose intro, no architecture essay.

```text
Output ONLY in this format (no prose intro, no sections swapped).

### Plan Review Findings

section:line: <emoji> <tag>: <problem/over-engineering>. <fix/replacement>.
totals: N🔴 N🟡 N✂️ N🪵 N⚡ N🔵 N❓ | net: -<N> lines/steps possible

Or exactly when no findings:

### Plan Review Findings

Lean & valid. Ship.

Rules for Plan Review Findings:
- Sort findings section → line ascending
- One finding per line; problem then fix separated by ". "
- Location: section = exact ## heading name; line = line number within that section (1-based from heading line), or — when issue spans whole section
- Action tags (literal after colon):
  - 🔴 bug: correctness blocker, contradiction, broken logic, missing critical step
  - 🟡 gap: weak testability, missing file/dependency, unclear sequencing, unmitigated risk
  - ✂️ cut: redundant prose, duplicate information, speculative task not required for goal (replacement: nothing)
  - 🪵 yagni: over-engineered scaffolding, premature generalization, unnecessary abstraction (replacement: inline or drop)
  - ⚡ simplify: over-complicated sequencing, multi-tier nesting, complex pattern (replacement: simpler layout or step)
  - 🔵 nit: wording, formatting, minor presentation tweak
  - ❓ question: unclear intent, missing context, needs author clarification
- Review focus: self-containment (no pointer-only external/cross-doc deps), executability, TODO atomicity/testability, scope/acceptance alignment, missing files or dependencies, contradictions between sections, unrealistic sequencing, untestable verification, risks without mitigation, Complexity Check accuracy, masterplan ↔ sub-plan consistency when split, AND ponytail plan complexity reduction (YAGNI, cuts, simplification). Do NOT perform pure micro prose edits unless they reduce implementation/plan scope, file count, or steps.

End with exactly one line:
- totals: N🔴 N🟡 N✂️ N🪵 N⚡ N🔵 N❓ | net: -<N> lines/steps possible
- Or: Lean & valid. Ship.
```

## Tags

Use these exact tags after the colon:

- `🔴 bug`: correctness blocker, contradiction, broken logic, missing critical step
- `🟡 gap`: weak testability, missing file/dependency, unclear sequencing, unmitigated risk
- `✂️ cut`: redundant prose, duplicate information, speculative task not required for goal
- `🪵 yagni`: over-engineered scaffolding, premature generalization, unnecessary abstraction
- `⚡ simplify`: over-complicated sequencing, multi-tier nesting, complex pattern
- `🔵 nit`: wording, formatting, minor presentation tweak
- `❓ question`: unclear intent, missing context, needs author clarification

## Review criteria

1. **Self-containment**: the plan can be executed using only the plan document plus a normal repo checkout. No pointer-only references to Confluence, Jira, Figma, sibling plans, or chat history.
2. **Executability**: every step can be done without guessing missing context.
3. **TODO atomicity/testability**: each TODO under `Implementation Plan` is one focused, testable action.
4. **Scope/acceptance alignment**: the plan matches the stated goal and acceptance criteria.
5. **Missing files or dependencies**: the `Files` section covers every path that needs to change.
6. **Contradictions**: sections do not contradict each other.
7. **Realistic sequencing**: dependencies and ordering are possible.
8. **Verifiable**: verification steps are concrete and runnable.
9. **Risk coverage**: risks are acknowledged or mitigated.
10. **Complexity Check accuracy**: counts and the Proceed/Split decision are honest.
11. **Masterplan ↔ sub-plan consistency**: when split, sub-plans repeat every fact they need from the masterplan.
12. **Ponytail complexity reduction**: the plan is as small as it can be while still correct.

## Output destination

The parent `sk-planning` skill triages these findings, revises the plan, and re-invokes `sk-review-plan` until the latest pass has zero valid findings. This subagent does not write files or update `RUNBOOK.md`.

## Rules

- Read-only: do not edit the plan or any repo files.
- Single block: emit exactly one `### Plan Review Findings` block.
- Sort findings by section, then line.
- One finding per line; problem then fix, separated by ". ".
- If no issues, output exactly `Lean & valid. Ship.`
- Do not add new sections or rewrite the plan; only review what is provided.
- Do not be overly harsh: minor wording issues are not findings unless they mislead.
