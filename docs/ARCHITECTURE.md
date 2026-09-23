# Architecture Overview

A cross-agent toolkit for reusable skills and an optional multi-phase workflow.

## Project Structure

```text
./
├── skills/                  # Skills (source of truth for all agents)
│   ├── sk-ai-toolbelt/
│   ├── sk-alternatives/
│   ├── sk-explore/
│   ├── sk-flow/
│   ├── sk-implement/
│   ├── sk-planning/
│   ├── sk-pr/
│   ├── sk-project-docs/
│   ├── sk-review-alternatives/
│   ├── sk-review-and-fix/
│   ├── sk-review/
│   ├── sk-review-plan/
│   └── sk-verify/
├── .agents/flows/           # Flow output directory (actual flow dirs are sk-*)
├── .claude/rules/           # Claude rule modules
├── rules/                   # Shared rules shipped inside the Cursor and Devin plugins
├── hooks/                   # inject-rules.py + Claude (hooks.json) and Cursor (cursor/hooks.json) manifests
├── .cursor-plugin/          # Cursor plugin manifest (repo root is the plugin)
├── .claude-plugin/          # Claude Code plugin manifest
├── plugins/slash-kit/       # Devin plugin (manifest, skills/rules/hook scripts synced from root by scripts/sync-devin-plugin.sh)
├── scripts/                 # install.sh, uninstall.sh, sync-devin-plugin.sh
├── AGENTS.md                # Agent-facing index
├── CLAUDE.md                # Claude Code entry point
├── README.md                # Human-facing overview
├── RUNBOOK.md               # Optional end-to-end workflow
└── docs/                    # Contributor and user documentation
```

## Data Flow

### Single skill

```text
[user prompt]
   │
   ├── Claude: slash command or description match loads the matching skills/sk-*/SKILL.md
   │
   ├── Cursor: slash-kit plugin (repo root) provides the skill and shared rules as context
   │
   ├── Devin: slash-kit plugin (plugins/slash-kit/) provides the skills as /slash-kit:* commands
   │
   ▼
[relevant skills/sk-*/SKILL.md]
   ▼
[output or file artifact]
```

### Full workflow

```text
[user asks for /sk-flow [auto|manual] or "use the sk-flow skill"]
   ▼
[sk-flow skill] → parses mode, loads and runs the full flow
   ▼
[sk-explore] → 0 - EXPLORE.md
   ▼
[sk-alternatives] → [sk-review-alternatives] → user picks option → 1 - ALTERNATIVES.md
   ▼
[sk-planning] → [sk-review-plan] → 2 - PLANNING.md
   ▼
[sk-implement] (code changes + tests) → 3 - IMPLEMENTATION.md
   ▼
[sk-review-and-fix or sk-review] → 4 - REVIEW.md
   ▼
[sk-verify] (optional) → 5 - VERIFY.md
   ▼
[sk-pr] → 6 - PR.md
```

Each phase runs in a fresh subagent when the harness has one. The worker prompt names the skill to invoke (e.g. `sk-planning`) instead of paraphrasing it, so mandatory steps inside the skill — reviews, sub-dispatch — cannot be dropped. The parent triages the output and dispatches the next phase.

## Key Decisions

### Skills are source of truth

Each skill in `skills/sk-*/SKILL.md` is the source of truth. Claude Code loads the matching skill when the user types `/sk-*` or the model matches the description. Devin loads the same skill files through the slash-kit plugin; Cursor uses them through the skill tool or rules.

### Flow runbooks are durable artifacts

Every flow lives in `.agents/flows/sk-<slug>/` with a mandatory `RUNBOOK.md` checklist and numbered phase docs. The plan, implementation, review, and PR phases read these docs without depending on chat context, so the workflow works across agents and sessions.

### Alternatives are reviewed before presentation

The `sk-alternatives` skill dispatches `sk-review-alternatives` to catch irrelevant, duplicate, or weak options before the user sees them. This keeps decision quality high without adding much friction.

### Rules ship in plugins, hooks fill the gaps

Shared rules live in `rules/` and ship inside the Cursor and Devin plugins. Claude Code plugins have no rules channel, and spawned subagents load no plugin rules on any platform — `hooks/inject-rules.py` covers both gaps by returning the rules as `additionalContext` on `sessionStart` and prepending them to subagent prompts on `preToolUse`. Repo-local Claude rule modules in `.claude/rules/` are still loaded via `@`-includes from `CLAUDE.md`.

### Workflow is opt-in

Nothing forces the full flow. Each skill is self-contained and can be used alone. The runbook exists for agents that do not support skills.

## External Dependencies

- `claude` — Claude Code CLI.
- `cursor` — Cursor CLI or IDE.
- `Node.js` — For `npx skills`.
- `gh` — Used by the `sk-pr` skill.

## Security Notes

No web server, no stored credentials, and no network calls from the toolkit itself. The `sk-pr` skill uses the user’s authenticated `gh` CLI. See [docs/SECURITY.md](SECURITY.md) for reporting vulnerabilities.
