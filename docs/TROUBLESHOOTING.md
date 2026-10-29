# Troubleshooting

## A snail skill does nothing in Claude Code

- Check the install: `ls ~/.claude/skills/snail-<name>/SKILL.md` (single skill) or reinstall the plugin.
- Restart Claude Code after installing.
- Use the exact name: `/snail:snail-planning` from the plugin, `/snail-planning` for a single-skill install.

## Cursor ignores the rules

- Rules ship inside the plugin — check `~/.cursor/plugins/local/snail/rules/` exists, then reload the window.
- Cursor only loads plugin rules for the workspace the plugin is enabled in.

## Review or PR skills miss context

- They expect `.agents/flows/snail-<slug>/` with a `runbook.yaml` and a `2 - PLANNING.yaml`. Missing either? They note it under `Known validation gaps` and keep going.

## Node errors

- `node: command not found` or `Node 24+ (current LTS) is required` — the gates and toolkit scripts need Node 24+. Install the current LTS from https://nodejs.org/ and re-run. Nothing else is needed: the YAML parser is vendored inside each skill.

## An old flow lives under sk-<slug>

Flows started before the rename used `.agents/flows/sk-<slug>/`. Skills resolve only `snail-<slug>` now — rename the dir to continue it: `mv .agents/flows/sk-<slug> .agents/flows/snail-<slug>`. The `.agents/flows/` exclude rule keeps ignoring `sk-*` dirs, so nothing else is needed.

## Flows stay ignored after deleting the exclude line

Installs initialized before the exclude change have `.agents/.gitignore` with a `flows/` line, which keeps ignoring flows on its own. Delete that line (or the file) as well.

## Runbook errors

Create state only via `node skills/snail-flow/scripts/flow-state.mjs`:

- `runbook missing ...` — `init <dir> --slug=<slug> --goal=<goal>`, then `check`. A legacy `runbook`, `runbook.json` or `RUNBOOK.md` means the flow predates this version — finish it on the old plugin or start fresh.
- `advance: <file> is missing` — write the phase artifact first.
- `advance: row <r> requires --<flag>` — the phase's required flags weren't given; the error names them.
- `status: error` on `check` — state contradicts the contract (missing or unexpected artifacts, bad flags). Repair with `set`/`note`; `set <dir> at=<row>` reopens a row — delete stale later artifacts too.
- `advance: flow is blocked` — someone marked it. Resume with `set <dir> status=in-progress`.

## Plan review never converges

Shrink the plan, or split it into a masterplan plus sub-plans.

## Review finds the plan itself is wrong

Back to planning: revise `2 - PLANNING.yaml`, re-run `snail-review-plan`, re-implement. Don't patch code against a bad plan.

## The agent diverged from a skill

Record why with `flow-state.mjs note <dir> <reason>`, then return to the phase that drifted (`set <dir> at=<row>` if it already passed).
