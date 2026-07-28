# [Feature] Masterplan

**Shape:** Umbrella for multi-PR and/or multi-repo work. Each PR has its own sub-plan from [plan.md](plan.md) (one repo, one PR each).

**Overview:** [2–3 short sentences]
**Approach:** [brief]
**Est. Time:** [X–Yh]
**PRs:** [N] across [M] repos
**Risk:** [Low/Med/High – why]
**Repos:** [repo-1], [repo-2], ...

## Files

`path/one`
`path/two`

## Context

Cross-cutting inlined facts for the whole initiative (shared schemas, rollout flags, version map rationale). Each **PR[N]** block below must also be **self-contained** for that PR's scope — repeat per-PR contracts here, not "see PR1".

## Implementation Status

> PRs: whole numbers, start at 1, sequential by dependencies.

| PR  | Repo   | Status | Link | Notes |
| --- | ------ | ------ | ---- | ----- |
| 1   | repo-a | ⏸️     | -    | ...   |
| 2   | repo-b | 🟡     | ...  | ...   |
| 3   | repo-a | 🟢     | ...  | ...   |

Status: 🟢 done · 🟡 in‑progress · 🟠 awaiting review · ⏸️ not‑started · 🔴 blocked · ⚫ canceled

## PR[N]: [Title] — [Status Icon]

**Repo:** [name] · **Link:** [-/URL] · **ETA:** [X–Yh]
**Files:** `path/one`, `path/two`

**Changes:**

1. [what/why] — File: `path.ext`
   - [line/context], before→after code
   - deps/imports

**Acceptance:**

- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Tests updated/added (integrated)
- [ ] No breaking changes
- [ ] All checks pass

**Dependencies:** Blocked by [PRs]/None · Blocks [PRs]/None

## Risk Mitigation

**[Risk Category]:** concern → analysis → mitigation → recovery.

## Deployment Strategy

**CRITICAL:** [ordering/coordination]

**Stage 1:** Repo [ ] · PRs: [ ]

1. deploy 2) verify 3) rollback

**Stage 2:** ...

**Cross‑Repo Version Map**

| Stage | PR  | repo‑1 | repo‑2 | repo‑3 | Notes |
| ----: | --- | ------ | ------ | ------ | ----- |
|     1 | 1   | v1.0   | -      | -      | ...   |

## Monitoring & Observability

**Metrics:** [name → expected]
**Logs:** success: ["..."], errors: ["..."]
**Alarms:** [condition → threshold]

## Verification

- [ ] [Verification Step 1]
- [ ] [Verification Step 2]

## Rollback

**Quick (flag):** disable → verify → fix → re‑enable.
**Full:** if [PR/Stage N] fails → steps, verify, what works/stops.
**Order:** first: last‑deployed/highest‑risk → ... → last: lowest‑risk.
**Artifacts safe to keep:** [list]

## Delivery (each PR / sub-plan)

- [ ] `main` pulled, branch `{branch-prefix}/<short-meaningful-name>` (`{branch-prefix}` derived from git user or `feature/` prefix; slug describes the work, not a ticket or issue ID — e.g. `<username>/secrets-store-filter` or `feature/secrets-store-filter`), implement
- [ ] Commit only when repository or operator policy explicitly allows commits for this work
- [ ] Push when policy or PR flow requires a remote branch

## Success Criteria

- [ ] All [N] PRs merged+prod
- [ ] Feature criteria 1/2
- [ ] No perf regression ([metric] < [thr])
- [ ] Tests ≥ [X]% & green
- [ ] 0 prod incidents
- [ ] Monitoring meets SLOs
- [ ] User‑facing criteria met

## References

Optional source attribution only — required content must be inlined under **Context** or the relevant **PR[N]** block. Omit when nothing to attribute.

## Notes & Assumptions

- Impl decisions: [ ], [ ]
- Cross‑repo coord: [ ], [ ]
- Data model: [ ], [ ]
- Risks: [ ], [ ]
- Testing: integrated with each PR (avoid standalone)
- Assumptions: ✅[1], ✅[2], ❌[3 needs verify]
