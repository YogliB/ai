# Architecture Overview

A cross-agent toolkit for reusable skills and an optional multi-phase workflow.

## Project Structure

```text
./
├── .agents/skills/          # On-demand skills (source of truth)
│   ├── explore/
│   ├── alternatives/
│   ├── review-alternatives/
│   ├── planning/
│   ├── review-and-fix/
│   ├── review-dont-fix/
│   ├── pr/
│   └── verify/
├── .agents/plans/           # Durable plan files
├── .agents/reports/         # Structured exploration reports
├── .claude/rules/           # Claude rule modules
├── .cursor/rules/           # Cursor project rules
├── .claude-plugin/          # Claude Code plugin manifest
├── src/hooks/               # Claude Code UserPromptSubmit hook
├── install.sh               # Install globally or per project
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
   ├── Claude: UserPromptSubmit hook expands shortcut if present
   │
   ├── Cursor: .cursor/rules/*.mdc loaded as context
   │
   ├── Devin: user invokes skill tool
   │
   ▼
[relevant .agents/skills/*/SKILL.md]
   ▼
[output or file artifact]
```

### Full workflow

```text
[user asks for /flow]
   ▼
[explore skill] → .agents/reports/<slug>.md
   ▼
[alternatives skill] (optional) → [review-alternatives skill] → user picks option
   ▼
[planning skill] → .agents/plans/<slug>.md
   ▼
[implementation] (code changes + tests)
   ▼
[review-and-fix or review-dont-fix skill]
   ▼
[pr skill]
```

Each phase can run in an independent subagent. The parent passes the plan or diff to the subagent, triages the output, and dispatches the next phase.

## Key Decisions

### Plan files are durable artifacts

Plans are written to `.agents/plans/<slug>.md` so implementation, review, and PR phases can read them without depending on chat context. This makes the workflow work across agents and sessions.

### Alternatives are reviewed before presentation

The `alternatives` skill dispatches `review-alternatives` to catch irrelevant, duplicate, or weak options before the user sees them. This keeps decision quality high without adding much friction.

### Rules are agent-native

Claude rules use the `@.claude/rules/*.md` include pattern from `CLAUDE.md`. Cursor rules use `.cursor/rules/*.mdc`. The content is the same, but the delivery mechanism matches each agent.

### Workflow is opt-in

Nothing forces the full flow. Each skill is self-contained and can be used alone. The runbook exists for agents that do not support hooks.

## External Dependencies

- `claude` — Claude Code CLI.
- `cursor` — Cursor CLI or IDE.
- `node` — For the Claude Code `UserPromptSubmit` hook.
- `gh` — Used by the `pr` skill.

## Security Notes

No web server, no stored credentials, and no network calls from the toolkit itself. The `pr` skill uses the user’s authenticated `gh` CLI. The hook only reads prompts and emits text. See [docs/SECURITY.md](SECURITY.md) for reporting vulnerabilities.
