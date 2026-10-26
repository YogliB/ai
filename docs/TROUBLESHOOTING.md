# Troubleshooting

## A slashkit skill does nothing in Claude Code

- Make sure the skill is installed: `ls ~/.claude/skills/sk-<name>/SKILL.md`.
- Restart Claude Code after installing.
- Use the exact skill name as the slash command: `/sk-explore`, `/sk-alternatives`, `/sk-planning`, `/sk-implement`, `/sk-review`, `/sk-pr`, or `/sk-flow`.
- Skills only respond to known names; arbitrary messages are not modified.

## Cursor does not use the rules

- Check that `.cursor/rules/` was copied to the project. The install script does this.
- Cursor rules only load when the directory is in the workspace root.
- If you are in a subfolder, rules may not apply. Move the `.cursor/rules/` to the folder Cursor opened.

## Plans are not written to a file

- The `sk-planning` skill writes the plan to `.agents/flows/sk-<slug>/2 - PLANNING.md`. If the directory does not exist, the agent should create it.
- If the agent has its own plan location, it should also copy or symlink to `.agents/flows/sk-<slug>/2 - PLANNING.md`.
- Review `skills/sk-flow/SKILL.md` for the naming convention.

## Review or PR skills miss context

- Make sure a flow folder exists under `.agents/flows/sk-<slug>/` with a `runbook.json`.
- The `sk-review` and `sk-pr` skills use the exact `2 - PLANNING.md` in the active flow or PR directory as context.
- If the plan or runbook is missing, the skills note it under `Known validation gaps`.

## Flow runbook is missing, out of date, or legacy

- Every phase must create or update `.agents/flows/sk-<slug>/runbook.json` via `skills/sk-flow/scripts/flow-state.mjs` (`init`, `set`, `pr`). Node ≥18 must be on `PATH`.
- If the runbook does not exist, create it with `node skills/sk-flow/scripts/flow-state.mjs init .agents/flows/sk-<slug> --slug=<slug> --goal=<goal>`, then `check` the directory.
- `legacy runbook format` means the directory has a Markdown `RUNBOOK.md` from an older plugin version: finish that flow on the old plugin or remove `RUNBOOK.md` and start fresh.
- `refusing to write invalid state` means a `set`/`pr` mutation would introduce a new invariant error; fix the named problem first (e.g. write the artifact before marking its row `done`).
- `masterplan prs order ... does not match runbook order` means a reorder was interrupted: the masterplan `prs` array and the runbook `order` fields must agree. Finish the reorder by setting the remaining `pr <dir> <slug> --order=<n>` values, or revert the masterplan `prs` array to match the runbook.

## Install script fails

- Requires `sh`, `cp`, and a writable target project directory.
- The target project must already exist.

## Uninstall script fails

- Requires `sh`, `rm`, `cmp`, `mktemp`, and a writable target project directory.
- The target project must already exist.
