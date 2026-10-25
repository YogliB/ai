<!--
{"schema":"implementation","slug":"{{slug}}","branch":"{{branch}}","receipts":[],"deviations":0,"plan-gaps":0}
-->

# 3 — Implementation: {{slug}}

## Plan reference

[2 - PLANNING.md](2%20-%20PLANNING.md)

## Branch

{{branch name}}

## Goal

{{one line, from the plan}}

## Steps

- {{plan TODO}}: {{what was done}} — checks: {{commands and results}} — receipts: {{receipt paths}} — commit {{sha}}

## Deviations

{{every departure from the plan text, with one-line reasons; "None" if none}}

## Plan Gaps

{{unresolved gaps flagged to the user: what the plan said, what the repo actually shows, what was tried}}

## Final verification

{{the full check suite the plan names - build, tests, lint, typecheck, format - run through the receipt runner, with receipt paths and results}}

## Next Step Recommendation

`sk-review` (fix mode inside `sk-flow`) — {{one-line reason}}
