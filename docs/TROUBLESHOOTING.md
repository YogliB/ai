# Troubleshooting

## A slashkit skill does nothing in Claude Code

- Make sure the skill is installed: `ls ~/.claude/skills/sk-<name>/SKILL.md`.
- Restart Claude Code after installing.
- Use the exact skill name as the slash command: `/sk-explore`, `/sk-alternatives`, `/sk-planning`, `/sk-implement`, `/sk-review-and-fix`, `/sk-pr`, or `/sk-flow`.
- Skills only respond to known names; arbitrary messages are not modified.

## Cursor does not use the rules

- Check that `.cursor/rules/` was copied to the project. The install script does this.
- Cursor rules only load when the directory is in the workspace root.
- If you are in a subfolder, rules may not apply. Move the `.cursor/rules/` to the folder Cursor opened.

## Plans are not written to a file

- The `sk-planning` skill writes the plan to `.agents/flows/sk-<slug>/2 - PLANNING.md`. If the directory does not exist, the agent should create it.
- If the agent has its own plan location, it should also copy or symlink to `.agents/flows/sk-<slug>/2 - PLANNING.md`.
- Review `.agents/flows/README.md` for the naming convention.

## Review or PR skills miss context

- Make sure a flow folder exists under `.agents/flows/sk-<slug>/` with a `RUNBOOK.md`.
- The `sk-review-and-fix`, `sk-review`, and `sk-pr` skills look for the latest `2 - PLANNING*.md` as context.
- If the plan or runbook is missing, the skills note it under `Known validation gaps`.

## Flow runbook is missing or out of date

- Every phase must create or update `.agents/flows/sk-<slug>/RUNBOOK.md`.
- If the runbook does not exist, the phase skill should create it from the template in `.agents/skills/sk-flow/templates/RUNBOOK.md`.

## Install script fails

- Requires `sh`, `cp`, and a writable home directory.
- For global install, `~/.claude/` must be writable.
- For per-project install, the target must already exist.

## Uninstall script fails

- Requires `sh`, `rm`, `cmp`, `mktemp`, and a writable home directory.
- For global uninstall, `npx` is required; if it is missing, the script falls back to removing `~/.agents/skills/<name>` manually.
- For per-project uninstall, the target must already exist.
