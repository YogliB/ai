# Troubleshooting

## A snail skill does nothing in Claude Code

- Check the install: `ls ~/.claude/skills/snail-<name>/SKILL.md` (single skill) or reinstall the plugin.
- Restart Claude Code after installing.
- Use the exact name: `/snail:snail-planning` from the plugin, `/snail-planning` for a single-skill install.

## Cursor ignores the rules

- Rules ship inside the plugin — check `~/.cursor/plugins/local/snail/rules/` exists, then reload the window.
- Cursor only loads plugin rules for the workspace the plugin is enabled in.

## Review or PR skills miss context

- They expect `.agents/flows/snail-<slug>/` with a `runbook` and a `2 - PLANNING.md`. Missing either? They note it under `Known validation gaps` and keep going.

## Runbook errors

Create state only via `sh skills/snail-flow/scripts/flow-state.sh`:

- `runbook missing ...` — `init <dir> --slug=<slug> --goal=<goal>`, then `check`. A `runbook.json`/`RUNBOOK.md` means the flow predates this version — finish it on the old plugin or start fresh.
- `advance: <file> is missing` — write the phase artifact first.
- `advance: row <r> requires --<flag>` — the phase's required flags weren't given; the error names them.
- `status: error` on `check` — state contradicts the contract (missing or unexpected artifacts, bad flags). Repair with `set`/`note`; `set <dir> at=<row>` reopens a row — delete stale later artifacts too.
- `advance: flow is blocked` — someone marked it. Resume with `set <dir> status=in-progress`.

## Plan review never converges

Shrink the plan, or split it into a masterplan plus sub-plans.

## Review finds the plan itself is wrong

Back to planning: revise `2 - PLANNING.md`, re-run `snail-review-plan`, re-implement. Don't patch code against a bad plan.

## The agent diverged from a skill

Record why with `flow-state.sh note <dir> <reason>`, then return to the phase that drifted (`set <dir> at=<row>` if it already passed).
