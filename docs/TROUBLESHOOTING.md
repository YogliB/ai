# Troubleshooting

## The `/alternatives` shortcut does nothing in Claude Code

- Make sure the plugin is installed: `ls ~/.claude/plugins/slash-kit/`.
- Restart Claude Code after installing.
- Check that the prompt starts with `/explore`, `/alternatives`, `/plan`, `/review`, `/pr`, or `/flow`.
- The hook only expands known shortcuts; arbitrary messages are not modified.

## Cursor does not use the rules

- Check that `.cursor/rules/` was copied to the project. The install script does this.
- Cursor rules only load when the directory is in the workspace root.
- If you are in a subfolder, rules may not apply. Move the `.cursor/rules/` to the folder Cursor opened.

## Plans are not written to a file

- The `planning` skill writes to `.agents/plans/<slug>.md`. If the directory does not exist, the agent should create it.
- If the agent has its own plan location, it should also copy or symlink to `.agents/plans/`.
- Review `.agents/plans/README.md` for the naming convention.

## Review or PR skills miss context

- Make sure a plan file exists under `.agents/plans/`.
- The `review-and-fix`, `review-dont-fix`, and `pr` skills look for the latest plan file as context.
- If the plan is missing, the skills note it under `Known validation gaps`.

## Install script fails

- Requires `sh`, `cp`, and a writable home directory.
- For global install, `~/.claude/` must be writable.
- For per-project install, the target must already exist.
