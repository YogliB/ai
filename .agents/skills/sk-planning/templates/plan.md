# [Plan ID/Version]

**Shape:** One repo, one PR. Multi-repo or multi-PR work → [masterplan.md](masterplan.md) plus one plan per PR.

## Goal

[Clear statement of what this plan achieves]

## Files

`path/to/file`
`path/to/other`

## Context

Inlined facts required to implement without opening other docs or chat history: schemas, field mappings, API/GraphQL shapes, flag names, env vars, **verified current** before→after snippets, cross-service contracts, verification commands. **No pointer-only entries** ("see Confluence", "per Figma", "details in masterplan PR N").

If a `before→after` snippet is included, the `before` half must be the current code or docs as it exists right now, not the desired future state. Every file path and line number in this section must be re-checked against the repo before finalizing.

## Scope

- **In Scope:** [List of what is included]
- **Out of Scope:** [List of what is explicitly excluded]

## Risks

- [Risk 1]: [Mitigation]
- [Risk 2]: [Mitigation]

## Dependencies

- [Dep 1]
- [Dep 2]

## Priority

[High/Medium/Low]

## Logging / Observability

- [Log point 1]
- [Metric 1]

## Branch setup

Branch prefix `{branch-prefix}` = team, git user, or operator convention (derive from `git config user.name` / `gh api user -q .login` sanitized to lowercase, or `feature/` / `fix/`). Name the branch after the work — short kebab-case slug, **not** a ticket or issue ID. Example: `git checkout -b <username>/secrets-store-filter` or `git checkout -b feature/secrets-store-filter`.

- [ ] `git checkout main` then `git pull` on the default remote so `main` is current
- [ ] `git checkout -b {branch-prefix}/<short-meaningful-name>`

## Implementation Plan (TODOs)

Keep this section at depth 2 or less. Flatten nested bullets that are details, not independent TODOs. Order steps so test and dependency changes land before code changes that would break or hang them.

- [ ] **Step 1: [Name]**
    - [ ] Task 1.1
    - [ ] Task 1.2
- [ ] **Step 2: [Name]**
    - [ ] Task 2.1

## Delivery

- [ ] Commit on the feature branch with a message that reflects this plan’s scope (only when repository or operator policy explicitly allows commits for this work)
- [ ] Push the feature branch to the remote (only when policy or PR flow requires a remote branch)

## Docs

- [ ] [Document 1]: [File path or description]
- [ ] [Document 2]: [File path or description]

## Testing

- [ ] Verification / validation steps
- [ ] New or changed tests follow repository conventions (for example backend non-UI: `when_<condition>_then_<outcome>` style names where that rule exists)
- [ ] Unit tests
- [ ] Integration tests

## Verification

- [ ] [Verification Step 1]
- [ ] [Verification Step 2]

## Acceptance

- [ ] [Acceptance Criterion 1]
- [ ] [Acceptance Criterion 2]

## Fallback Plan

[What to do if the plan fails or causes issues]

## References

Optional source attribution only — every fact needed for execution must already appear under **Context**, **Scope**, **Implementation Plan (TODOs)**, or **Acceptance**. Omit section when nothing to attribute.

## Complexity Check

- Implementation TODO count (split threshold): [N] (checkboxes **only** under **Implementation Plan (TODOs)** above; used for “greater than 30” split rule in the sk-planning skill)
- Total checklist items (optional): [N]
- Depth: [N] (nesting **only** under **Implementation Plan (TODOs)** for split rule)
- Cross-deps: [N] (informational for Proceed/Split narrative; no mandatory split threshold in sk-planning skill)
- **Decision:** [Proceed / Split]
