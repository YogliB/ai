---
name: sk-planning
description: Self-contained executable technical plans with atomic testable TODOs; required context inlined in the document (no pointer-only deps on Confluence, tickets, Figma, sibling plans, or skill templates). Ambiguity gates (~10% before planning, ~5% before acting; list unknowns when percent unclear), pre-finalization pass for refactors/performance/security, mandatory plan review loop via Task subagent using single-block action-tagged output (cavecrew + ponytail complexity reduction) with model escalation until zero valid findings. Regular plan = one repo, one PR only; multi-repo or multi-PR work requires masterplan plus one self-contained sub-plan per PR. Also split on complexity thresholds. Cross-deps in Complexity Check inform narrative only. Templates use neutral branch prefix; Delivery defers commit/push to operator/repo policy. SDD-sized implementation TODOs or multiple review cycles per parent TODO. Enforces layout via co-located templates; ~95% TODO coverage. Use for planning rules, validation, drafting plans, CreatePlan-style output, splits, standard layout.
---

# Planning

## When to use

- User asks planning rules or wants plan validated
- Draft or tighten technical plan before work starts
- Decide whether one plan enough or work should split

## Subagent execution

Run this skill in an independent subagent when the harness supports it. The main session is updated only when the subagent is done.

## Core requirements

- Plan must be **self-contained**: an implementer (human or agent) executes using **only this document** plus a normal repo checkout — no fetching Confluence/Jira/Figma, reading sibling plan files, opening skill templates, or relying on chat history
- Plan must be **durable**: the final plan is written to a file under `.agents/plans/` (or the agent's equivalent default) so the review, implementation, and PR phases can read it without chat context
- **Inline required context** in the plan body: API/data shapes, field mappings, env vars, flags, acceptance thresholds, before→after snippets, cross-PR contracts, and verification commands. The `Context` section must describe the repo as it is right now; a `before→after` snippet is allowed only when the `before` part is verified current code, not the desired future state. Links may appear **only** as optional source attribution **after** the needed facts are inlined
- **Pointer-only dependencies are blockers** — e.g. "see Confluence page X", "per design doc", "details in masterplan PR2", "attach Figma at implementation time". Either inline the excerpt or list as **Assumptions** with acceptance impact and a verification step
- **Every file path and line number** in the plan must be re-checked against the repo just before finalizing
- **Do not include cross-plan or cross-repo references** unless they are required for execution and fully inlined
- Plan must be **fully executable**: every step done without guessing missing context
- TODOs **atomic** and **testable** where code changes apply
- Include **Files** near top: **paths only** (one per line, backticked repo-relative paths), no descriptions, grouping, rationale. Union of every path you expect to create or edit for this plan (or whole masterplan). Place **Files** right after **Goal** in [templates/plan.md](templates/plan.md); in [templates/masterplan.md](templates/masterplan.md) place after overview metadata block, before **Implementation Status**. Update list when scope shifts

## Initial setup

Before writing the first plan in a repo:

- Create `.agents/plans/` if it does not exist.
- Add `.agents/plans/` to `.gitignore` so plan files are not committed by default.

## Clarification gates

- Before **planning**: drive ambiguity **under ~10%** (open questions answered or listed as assumptions with acceptance impact)
- Before **acting** (implementation): ambiguity **under ~5%**
- Percentages = judgment aid; when uncertain, list concrete unknowns and assumptions instead of claiming percent

## Pre-finalization pass

Before treating plan as final, note meaningful chances for **refactors**, **performance**, **security** (even if deferred, capture in Risks or short follow-up list)

## Pre-review self-audit

Before shipping a plan to the first subagent review, check:

- [ ] `Context` snippets are the **current** code or docs, not the desired future state.
- [ ] Every file path and line number was verified against the repo just before writing.
- [ ] For each test change, the runner/producer is named and the expected call count matches the fixture.
- [ ] Every constant, helper, or assertion referenced in the plan actually exists in the test file.
- [ ] The implementation order does not create a broken intermediate state (e.g., a code change that makes tests hang before the test update lands).
- [ ] No cross-plan or cross-repo references are included unless required for execution.
- [ ] Nested checkboxes are flattened when they are details, not independent TODOs; keep `Implementation Plan (TODOs)` depth at 2 or less.

## Plan shape

- **[templates/plan.md](templates/plan.md)** — **one PR only**, **one repo only**. All scoped changes land in single PR in single repo. Do not stretch one plan across multiple PRs or repos.
- **[templates/masterplan.md](templates/masterplan.md)** — required when work spans **more than one repo** or **more than one PR**. Masterplan owns sequencing, cross-repo coordination, rollout, PR status; **each PR** gets own **self-contained** sub-plan from [templates/plan.md](templates/plan.md). Sub-plans **repeat** (do not merely reference) every fact they need from the masterplan or external sources; masterplan PR blocks must already inline enough context to draft or execute that PR without re-reading chat

## Complexity split

If **any** holds, use **masterplan** plus **sub-plans** (one [templates/plan.md](templates/plan.md) per PR) instead of one monolithic plan:

- **More than one repo** or **more than one PR** (see **Plan shape** above — mandatory)
- **Implementation TODO count** greater than 30: count **only** checkboxes under **Implementation Plan (TODOs)** section in [templates/plan.md](templates/plan.md) (exclude Branch setup, Delivery, Docs, Testing, Acceptance, other non-implementation sections so scaffolding does not force split)
- **Depth** greater than 3: nested checklist levels **under** that same Implementation Plan section
- **High risk** items greater than 5: count **distinct** risk lines or bullets under **Risks** (or masterplan's risk equivalent), not every sub-clause in prose

**Complexity Check** fields **Cross-deps** and total checklist counts inform **Proceed** or **Split** narrative; they do **not** trigger mandatory split by themselves (multi-repo / multi-PR always does).

## Template enforcement

- Read [templates/plan.md](templates/plan.md) and include every `##` section **in file order**: Goal, Files, Context, Scope, Risks, Dependencies, Priority, Logging / Observability, Branch setup, Implementation Plan (TODOs), Delivery, Docs, Testing, Verification, Acceptance, Fallback Plan, References, Complexity Check (omit section only if user explicitly narrows scope). If that template's `##` headings change, update this list in same change
- Fill **Complexity Check** with real counts and explicit **Proceed** or **Split** decision

## Subagent models (default)

Review subagents **ALWAYS** use model `gemini-3.6-flash-high` unless the user explicitly requests a different model for a pass.

Parent (orchestrator) stays on its own model; **every subagent gets an explicit `model: "gemini-3.6-flash-high"` slug**.

**Override:** ONLY when the user explicitly requests a specific model (e.g. "use claude-opus-4-8-thinking-high for review") do you use that model for that pass.

## Plan review loop (mandatory before handoff)

After plan text matches template (and **Pre-finalization pass** done), run review loop on **each** emitted document (sub-plan and masterplan when split). Do **not** hand off or summarize plan as final while **valid** findings remain. Each pass emits a single block of action-tagged findings (`### Plan Review Findings`) combining correctness, gaps, and ponytail plan complexity reduction. Parent **triages and fixes**; parent **never** self-reviews inline.

**Subagent-only:** every **Review** step **must** run in a **Task** subagent (`subagent_type="generalPurpose"`, `readonly: true`, **`model: "gemini-3.6-flash-high"`**).

### 1. Review

Dispatch **Task** subagent (`subagent_type="generalPurpose"`, `readonly: true`, `model: "gemini-3.6-flash-high"`) on full plan text. **Required every loop iteration** — including after fixes. Do **not** substitute inline review, checklist skim, or parent-authored findings.

Prompt must include:

- Full plan body (paste text; do **not** point subagent at plan files on disk)
- Required context (repo constraints, user scope, masterplan ↔ sub-plan linkage when split)
- Output contract below (verbatim)

Subagent returns **only** structured findings in a single block (no prose intro or architecture essay). Use this contract:

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

### 2. Triage

**Labels (use these literals):** `valid` | `false_positive` | `unvalidated`

For **each** finding: assign one label plus a one-line reason. False positives do not require plan edits.

Count **valid** findings this pass. `Lean & valid. Ship.` means zero valid findings after triage.

### 3. Fix

Edit plan to resolve **every `valid`** finding before next review. Prefer minimal edits; do not expand scope while fixing.

### 4. Repeat

Return to **Review** — dispatch a **new Task subagent** on updated plan using `model: "gemini-3.6-flash-high"`. Continue until latest pass has **zero `valid` findings** across the review pass after triage.

**Exit rule:** hand off only when latest review pass has **zero `valid` findings** (`Plan Review Findings` is `Lean & valid. Ship.` or all findings triaged false positive). If valid findings remain after fix pass, loop again — do not stop early.

## Agent constraints

- Aim for roughly **95% TODO coverage** of work in scope (remaining gap only where truly non-actionable)
- **Consistent Markdown** (headings, lists, checkboxes)
- **Keep `Implementation Plan (TODOs)` depth at 2 or less**; flatten nested bullets that are details, not independent TODOs
- **Do not include cross-plan or cross-repo references** unless they are required for execution and fully inlined
- **Branch setup** and **Delivery** blocks from template are for plans that include execution; omit when user asks **draft-only** plan or narrows scope to design-only
- **Delivery** checklist: honor repository and operator rules for **git commit** and **push** (leave items unchecked or omit **Delivery** when commits require explicit operator request per policy)
- When repository **interactive workflow** rules apply (small chunks, confirmation between steps), **present** plan that way; final artifact can still match full template once agreed, unless user stays **draft-only** (then omit Branch setup and Delivery as above)
- **Plan review:** subagent-only per **Plan review loop**; never skip Task dispatch or review inline in parent thread
- When **Subagent-Driven Development** rules apply, size each **implementation** TODO to **one** focused implementer dispatch; if work larger, split into smaller TODOs or run multiple implementer cycles (each cycle: **spec compliance review** then **code quality review**) before checking parent TODO complete. One implementer at a time, never parallel implementers, and do **not** point subagents at plan files—paste a **self-contained** task slice (Goal, Files, inlined Context, scoped TODOs, acceptance for that slice only)

## Testing discipline

After **each** implementation TODO from plan, run **related tests** and **verification** steps, then fix failures before moving on. Where repository defines test naming or layers, follow those rules in Testing section and in new tests.

For each test change in the plan:

- Name the runner/producer and confirm the expected call count matches the fixture.
- Verify that every referenced helper, constant, or assertion exists in the test file.

Order implementation TODOs so test and dependency changes land before code changes that would break or hang them; simulate the implementation order before finalizing.

## Scope boundary

Planning covers **what** to build, **how** to sequence it, **delivery shape** when needed (branches, PR boundaries, rollout stages, dependencies)—including fields in [templates/masterplan.md](templates/masterplan.md), and **plan review** per **Plan review loop** above. **Code review** of implementation (diff review, SDD implementer review gates) **not** part of this skill; use repository rules for that.

## Plan file output

The finalized plan must be written to a file so later phases (implementation, review, PR) can read it without depending on chat context.

- Default path: `.agents/plans/<slug>.md`
- Masterplan path: `.agents/plans/<slug>-master.md`
- `<slug>` should describe the work in short kebab-case (e.g., `add-auth-token`, `crewmate-stream`). If the user did not name it, derive one from the Goal and ask to confirm.
- If the agent platform has its own default plan location (e.g., Cursor plan mode), write the plan there too, but always create or symlink the canonical copy under `.agents/plans/`.
- Do not commit or push the plan file unless the user or repo policy explicitly requests it.
- The planning review loop still pastes the full plan text into the review subagent; the file is the durable artifact after the review passes.

## Output

- Either **summarize these rules** when user only asked guidance
- Or **write the finalized plan to a file** and return a short summary with the path, then emit the plan text on request

## Bundled templates

- [templates/plan.md](templates/plan.md)
- [templates/masterplan.md](templates/masterplan.md)
- If repository keeps copies under `.cursor/templates/`, edit those files in **same change** whenever you change [templates/plan.md](templates/plan.md) or [templates/masterplan.md](templates/masterplan.md) here (or add TODO in plan to sync if copies missing)
