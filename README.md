# AI

Reusable agent skills and an optional end-to-end workflow for Claude, Cursor, and Devin. I built this to stop repeating myself to every agent. Take it, break it, and rebuild it into something that fits your own chaos.

## What you get

- **Skills** — single-purpose prompts like `sk-explore`, `sk-planning`, `sk-review-plan`, `sk-review-and-fix`, and `sk-pr`.
- **Shortcuts** — in Claude Code, type `/explore`, `/plan`, `/review`, `/pr`, or `/flow` and let the `slash-kit` plugin load the matching skill.
- **A runbook** — optional full flow: explore → alternatives → plan → build → review → verify → PR.
- **Rules** — editor-specific conventions for Claude, Cursor, and Devin.

Everything lives in plain Markdown. No magic binaries, no cloud services, no tracking.

## Quick start

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh
```

That installs skills globally and registers the Claude Code plugin. For a single project, pass the repo path:

```bash
npx degit YogliB/ai /tmp/ai && sh /tmp/ai/install.sh /path/to/your/repo
```

Want just one skill?

```bash
npx skills add YogliB/ai --skill sk-planning
```

To remove one skill: `npx skills remove sk-planning` (add `-g` if you installed globally).
To remove the full install: `sh /tmp/ai/uninstall.sh` (or pass a repo path).

## Use it

### In Claude Code

Type a shortcut at the start of a prompt:

```text
/explore add-auth-token
/alternatives for caching API responses
/plan add-auth-token
/review
/pr
/flow auto
```

| Shortcut          | What it does                                                                         |
| ----------------- | ------------------------------------------------------------------------------------ |
| `/explore <slug>` | Gather context and write `0 - EXPLORE.md` to `.agents/sk-flows/<slug>/`.             |
| `/alternatives`   | Generate and review options, then write `1 - ALTERNATIVES.md`.                       |
| `/plan <slug>`    | Write an executable `2 - PLANNING.md`.                                               |
| `/review`         | Review and fix the current diff.                                                     |
| `/pr`             | Create or update a GitHub PR.                                                        |
| `/flow [mode]`    | Run the whole workflow. `auto` skips confirmations; `manual` asks before each phase. |

### In any editor

Name the skill directly:

```text
Use the sk-planning skill to write a plan for pagination.
Use the sk-review-plan skill to review the plan.
Use the sk-review-and-fix skill on the current diff.
Use the sk-pr skill to open a pull request.
```

## The flow

```text
sk-explore → sk-alternatives → sk-planning → implementation → sk-review-and-fix → optional sk-verify → sk-pr
```

Each phase writes a numbered doc into `.agents/sk-flows/<slug>/`, so you can pause, resume, or hand the work to another agent without losing context.

## Caveats

- **Shortcuts only work in Claude Code.** Cursor and Devin can use the skill names or the [runbook](RUNBOOK.md).
- **Cursor rules are project-scoped.** Install them into each repo where you want them.
- **Flow runbooks are not committed by default.** Commit them only if your policy wants them.
- **Skills are modular.** Nothing forces the full flow. Pick one skill and ignore the rest.

## More

- [RUNBOOK.md](RUNBOOK.md) — the full workflow.
- [docs/USAGE.md](docs/USAGE.md) — install options, advanced usage, and troubleshooting.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the pieces fit together.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — if you want to hack on this.

## License

MIT. Steal with attribution.
