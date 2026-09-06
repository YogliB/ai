# AI

Reusable agent skills and an optional end-to-end workflow for Claude, Cursor, and Devin. I built this to stop repeating myself to every agent. Take it, break it, and rebuild it into something that fits your own chaos.

## What you get

- **Skills** — single-purpose prompts like `sk-explore`, `sk-planning`, `sk-implement`, `sk-review-plan`, `sk-review-and-fix`, and `sk-pr`.
- **Slash commands** — in Claude Code, type `/sk-explore`, `/sk-planning`, `/sk-implement`, `/sk-review-and-fix`, `/sk-pr`, or `/sk-flow` to invoke the matching skill.
- **A runbook** — optional full flow: explore → alternatives → plan → build → review → verify → PR.
- **Rules** — editor-specific conventions for Claude and Cursor.

Everything lives in plain Markdown. No magic binaries, no cloud services, no tracking.

## Quick start

Pick your agent:

```bash
# Claude Code - plugin with /sk-* slash commands
claude plugin marketplace add YogliB/ai
claude plugin install slash-kit@ai

# Devin - plugin with /slash-kit:* commands
devin plugins install YogliB/ai#plugins/slash-kit

# Any agent - skills only, global
npx skills add YogliB/ai -g

# Cursor - per project
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh /path/to/your/repo
```

`install.sh` exists only for Cursor, until Cursor gets a proper plugin system.

Want just one skill?

```bash
npx skills add YogliB/ai --skill sk-planning
```

To remove one skill: `npx skills remove sk-planning` (add `-g` if you installed globally).
To remove a plugin, use the agent's own remove command (`claude plugin uninstall slash-kit@ai`, `devin plugins remove slash-kit`).
To remove a Cursor project install: `sh /tmp/ai/uninstall.sh /path/to/your/repo`.

## Use it

### In Claude Code

Plugin skills are namespaced. Type the command at the start of a prompt:

```text
/slash-kit:sk-explore add-auth-token
/slash-kit:sk-alternatives for caching API responses
/slash-kit:sk-planning add-auth-token
/slash-kit:sk-review-and-fix
/slash-kit:sk-pr
/slash-kit:sk-flow auto
```

Installed a skill individually with `npx skills add`? Drop the `/slash-kit:` prefix (`/sk-planning`).

| Slash command                    | What it does                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------ |
| `/slash-kit:/sk-explore <slug>`  | Gather context and write `0 - EXPLORE.md` to `.agents/flows/sk-<slug>/`.             |
| `/slash-kit:/sk-alternatives`    | Generate and review options, then write `1 - ALTERNATIVES.md`.                       |
| `/slash-kit:/sk-planning <slug>` | Write an executable `2 - PLANNING.md`.                                               |
| `/slash-kit:/sk-implement`       | Execute an approved plan, writing `3 - IMPLEMENTATION.md`.                           |
| `/slash-kit:/sk-review-and-fix`  | Review and fix the current diff.                                                     |
| `/slash-kit:/sk-pr`              | Create or update a GitHub PR.                                                        |
| `/slash-kit:/sk-flow [mode]`     | Run the whole workflow. `auto` skips confirmations; `manual` asks before each phase. |

### In Devin

Install the plugin, then prefix the skill name with `/slash-kit:`:

```bash
devin plugins install YogliB/ai#plugins/slash-kit
```

```text
/slash-kit:sk-planning add-auth-token
/slash-kit:sk-implement
/slash-kit:sk-flow auto
```

### In any editor

Name the skill directly:

```text
Use the sk-planning skill to write a plan for pagination.
Use the sk-review-plan skill to review the plan.
Use the sk-implement skill to implement the plan.
Use the sk-review-and-fix skill on the current diff.
Use the sk-pr skill to open a pull request.
```

## The flow

```text
sk-explore → sk-alternatives → sk-planning → sk-implement → sk-review-and-fix → optional sk-verify → sk-pr
```

Each phase writes a numbered doc into `.agents/flows/sk-<slug>/`, so you can pause, resume, or hand the work to another agent without losing context.

## Caveats

- **Slash commands work in Claude Code and Devin.** In Devin they come from the plugin and are namespaced (`/slash-kit:sk-*`). Cursor can use the skill names or the [runbook](RUNBOOK.md).
- **Cursor rules are project-scoped.** Install them into each repo where you want them.
- **Flow runbooks are not committed by default.** Commit them only if your policy wants them.
- **Skills are modular.** Nothing forces the full flow. Pick one skill and ignore the rest.
- **Cross-editor rules are not fully unified yet.** Claude Code supports rule `@` includes from `AGENTS.md`/`CLAUDE.md`, so agent-only rules can live in `.agents/rules/`. Cursor requires rules in its own project-scoped directory and does not reliably load global or shared rule files. The install script copies editor-specific rules as a workaround; a single `.agents/rules/` source for all editors is a known gap.

## More

- [RUNBOOK.md](RUNBOOK.md) — the full workflow.
- [docs/USAGE.md](docs/USAGE.md) — install options, advanced usage, and troubleshooting.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the pieces fit together.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — if you want to hack on this.

## License

MIT. Steal with attribution.
