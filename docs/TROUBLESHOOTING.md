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

- Make sure a flow folder exists under `.agents/flows/sk-<slug>/` with a `runbook` file.
- The `sk-review` and `sk-pr` skills use the exact `2 - PLANNING.md` in the active flow as context.
- If the plan or runbook is missing, the skills note it under `Known validation gaps`.

## Flow runbook is missing, out of date, or legacy

- Every phase must create or update `.agents/flows/sk-<slug>/runbook` via `skills/sk-flow/scripts/flow-state.sh` (`init`, `advance`, `note`, `set`). Only `sh` and core utilities are needed.
- If the runbook does not exist, create it with `sh skills/sk-flow/scripts/flow-state.sh init .agents/flows/sk-<slug> --slug=<slug> --goal=<goal>`, then `check` the directory.
- `runbook missing ... (legacy runbook.json/RUNBOOK.md is not supported)` means the directory predates the current format: finish that flow on the old plugin or remove the legacy file and start fresh.
- `advance: <file> is missing` means the artifact must exist before its row advances; `advance: row <r> requires --<flag>` means the phase's required flags were not supplied.
- `status: error` on `check` means the recorded state contradicts the contract (missing artifacts, unexpected files, bad flags). Repair via `set`/`note` or the files; `set <dir> at=<row>` reopens a row — delete stale later artifacts too.

## A skill's output is wrong

- Edit the skill's `skills/sk-*/SKILL.md` directly and re-test; the skills are the source of truth.

## Plan review never converges

- Reduce the plan's scope, or split it into a masterplan and sub-plans.

## Review finds the plan itself is wrong

- Go back to planning: revise `2 - PLANNING.md`, re-run `sk-review-plan`, then re-implement. Do not patch code against a wrong plan.

## The agent diverged from a skill

- Record the reason via `sh skills/sk-flow/scripts/flow-state.sh note <dir> <reason>`, then return to the phase that diverged (`set <dir> at=<row>` if it already passed).

## Install script fails

- Requires `sh`, `cp`, and a writable target project directory.
- The target project must already exist.

## Uninstall script fails

- Requires `sh`, `rm`, `cmp`, `mktemp`, and a writable target project directory.
- The target project must already exist.
