# Architecture Overview

A cross-agent toolkit for reusable skills and an optional multi-phase workflow.

## Project Structure

```text
./
├── .agents/skills/          # On-demand skills (source of truth)
│   ├── sk-ai-toolbelt/
│   ├── sk-alternatives/
│   ├── sk-explore/
│   ├── sk-flow/
│   ├── sk-planning/
│   ├── sk-pr/
│   ├── sk-project-docs/
│   ├── sk-review-alternatives/
│   ├── sk-review-and-fix/
│   ├── sk-review/
│   ├── sk-review-plan/
│   └── sk-verify/
├── .agents/sk-flows/        # Flow runbooks and numbered phase docs
├── .claude/rules/           # Claude rule modules
├── .cursor/rules/           # Cursor project rules
├── .devin/rules/            # Devin project rules
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
   ├── Claude: UserPromptSubmit hook loads the matching .agents/skills/sk-*/SKILL.md
   │
   ├── Cursor: .cursor/rules/*.mdc loaded as context
   │
   ├── Devin: .devin/rules/*.md loaded as context, user invokes skill tool
   │
   ▼
[relevant .agents/skills/sk-*/SKILL.md]
   ▼
[output or file artifact]
```

### Full workflow

```text
[user asks for /flow [auto|manual]]
   ▼
[sk-flow skill] → parses mode, loads and runs the full flow
   ▼
[sk-explore] → 0 - EXPLORE.md
   ▼
[sk-alternatives] → [sk-review-alternatives] → user picks option → 1 - ALTERNATIVES.md
   ▼
[sk-planning] → [sk-review-plan] → 2 - PLANNING.md
   ▼
[implementation] (code changes + tests) → 3 - IMPLEMENTATION.md
   ▼
[sk-review-and-fix or sk-review] → 4 - REVIEW.md
   ▼
[sk-verify] (optional) → 5 - VERIFY.md
   ▼
[sk-pr] → 6 - PR.md
```

Each phase can run in an independent subagent. The parent passes the plan or diff to the subagent, triages the output, and dispatches the next phase.

## Key Decisions

### Skills are source of truth

Each slash command in Claude Code loads the matching `sk-*/SKILL.md`. The hook is a thin harness; the skill file is the canonical behavior. Devin and Cursor use the same skill files through the skill tool or rules.

### Flow runbooks are durable artifacts

Every flow lives in `.agents/sk-flows/<slug>/` with a mandatory `RUNBOOK.md` checklist and numbered phase docs. The plan, implementation, review, and PR phases read these docs without depending on chat context, so the workflow works across agents and sessions.

### Alternatives are reviewed before presentation

The `sk-alternatives` skill dispatches `sk-review-alternatives` to catch irrelevant, duplicate, or weak options before the user sees them. This keeps decision quality high without adding much friction.

### Rules are agent-native

Claude rules use the `@.claude/rules/*.md` include pattern from `CLAUDE.md`. Cursor rules use `.cursor/rules/*.mdc`. The content is the same, but the delivery mechanism matches each agent.

### Workflow is opt-in

Nothing forces the full flow. Each skill is self-contained and can be used alone. The runbook exists for agents that do not support hooks.

## External Dependencies

- `claude` — Claude Code CLI.
- `cursor` — Cursor CLI or IDE.
- `Node.js` — For `npx skills` and the Claude Code `UserPromptSubmit` hook.
- `gh` — Used by the `sk-pr` skill.

## Security Notes

No web server, no stored credentials, and no network calls from the toolkit itself. The `sk-pr` skill uses the user’s authenticated `gh` CLI. The hook only reads prompts and emits the relevant skill content. See [docs/SECURITY.md](SECURITY.md) for reporting vulnerabilities.
