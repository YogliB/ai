# snail

Reusable agent skills and an optional stage-gated workflow for Claude, Cursor, and Devin. It carries state between phases and leaves a trail — every gate is a shell script, every phase leaves a receipt. I built this to stop repeating myself to every agent. Take it, break it, and rebuild it into something that fits your own chaos.

## What you get

- **Skills** — single-purpose prompts like `snail-explore`, `snail-planning`, `snail-implement`, `snail-review-plan`, `snail-review`, and `snail-pr`.
- **Slash commands** — in Claude Code, type `/snail-explore`, `/snail-planning`, `/snail-implement`, `/snail-review`, `/snail-pr`, or `/snail-flow` to invoke the matching skill.
- **A workflow** — optional full flow: explore → alternatives → plan → build → review → verify → PR.
- **Rules** — editor-specific conventions for Claude and Cursor.

Flow state and receipts are flat `key: value` files; everything else is plain Markdown. No magic binaries, no cloud services, no tracking. Every gate script needs only `sh` and core utilities (git optional).

## Quick start

Pick your agent:

```bash
# Claude Code - plugin with /snail-* slash commands
claude plugin marketplace add YogliB/snail
claude plugin install snail@snail
# + rules into ~/.claude (one-time): sh scripts/install-claude-rules.sh

# Devin - plugin with /snail:* commands
devin plugins install YogliB/snail#plugins/snail

# Any agent - skills only, global
npx skills add YogliB/snail -g

# Cursor - local plugin (skills + rules)
npx degit YogliB/snail /tmp/snail && sh /tmp/snail/scripts/install.sh
```

`scripts/install.sh` copies the plugin into `~/.cursor/plugins/local/snail`; reload the window to load it.

Want just one skill? `npx skills add YogliB/snail --skill snail-planning` — it works standalone, no plugin needed.

To remove: `npx skills remove snail-planning`, or each agent's own uninstall (`claude plugin uninstall snail@snail`, `devin plugins remove snail`, `sh /tmp/snail/scripts/uninstall.sh` for Cursor).

## Use it

### In Claude Code

Plugin skills are namespaced. Type the command at the start of a prompt:

```text
/snail:snail-explore add-auth-token
/snail:snail-alternatives for caching API responses
/snail:snail-planning add-auth-token
/snail:snail-review
/snail:snail-pr
/snail:snail-flow auto
```

Installed a skill individually with `npx skills add`? Drop the `/snail:` prefix (`/snail-planning`).

| Slash command                  | What it does                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------------ |
| `/snail:snail-explore <slug>`  | Gather context and write `0 - EXPLORE.md` to `.agents/flows/snail-<slug>/`.          |
| `/snail:snail-alternatives`    | Generate and review options, then write `1 - ALTERNATIVES.md`.                       |
| `/snail:snail-planning <slug>` | Write an executable `2 - PLANNING.md`.                                               |
| `/snail:snail-implement`       | Execute an approved plan, writing `3 - IMPLEMENTATION.md`.                           |
| `/snail:snail-review`          | Review the current diff (add "fix" to fix).                                          |
| `/snail:snail-pr`              | Create or update a GitHub PR.                                                        |
| `/snail:snail-flow [mode]`     | Run the whole workflow. `auto` skips confirmations; `manual` asks before each phase. |

### In Devin

Install the plugin, then prefix the skill name with `/snail:`:

```bash
devin plugins install YogliB/snail#plugins/snail
```

```text
/snail:snail-planning add-auth-token
/snail:snail-implement
/snail:snail-flow auto
```

### In any editor

Name the skill directly:

```text
Use the snail-planning skill to write a plan for pagination.
Use the snail-review-plan skill to review the plan.
Use the snail-implement skill to implement the plan.
Use the snail-review skill on the current diff (say "fix" for fix mode).
Use the snail-pr skill to open a pull request.
```

## The flow

```text
snail-explore → snail-alternatives → snail-planning → snail-implement → snail-review (fix mode) → snail-verify → snail-pr
```

Each phase writes a numbered doc into `.agents/flows/snail-<slug>/`, so you can pause, resume, or hand the work to another agent without losing context.

## Caveats

- **Slash commands work in Claude Code and Devin.** In Devin they come from the plugin and are namespaced (`/snail:snail-*`). Cursor can use the skill names.
- **Flow runbooks are not committed by default.** Commit them only if your policy wants them.
- **Skills are modular.** Nothing forces the full flow. Pick one skill and ignore the rest.
- **Rules ship inside the Cursor and Devin plugins** from the shared `rules/` directory. Claude Code plugins have no rules channel — `scripts/install-claude-rules.sh` copies the rules into `~/.claude/snail/` and `@`-imports them from `~/.claude/CLAUDE.md`, which also reaches subagent context.

## More

- [docs/USAGE.md](docs/USAGE.md) — install options, the full workflow, and advanced usage.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the pieces fit together.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — if you want to hack on this.

## License

MIT. Steal with attribution.
