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
│   ├── sk-review/
│   ├── sk-review-plan/
│   └── sk-verify/
├── .agents/flows/           # Flow output directory (actual flow dirs are sk-*)
├── rules/                   # Shared rules shipped inside the Cursor and Devin plugins
├── hooks/                   # inject-rules.py + Claude (hooks.json) and Cursor (cursor/hooks.json) manifests
├── .cursor-plugin/          # Cursor plugin manifest (repo root is the plugin)
├── .claude-plugin/          # Claude Code plugin manifest
├── plugins/slash-kit/       # Devin plugin (manifest, skills/rules/hook scripts synced from root by scripts/sync-devin-plugin.sh)
├── scripts/                 # install.sh, uninstall.sh, sync-devin-plugin.sh, gen-skills-index.sh, test-*.sh
├── AGENTS.md                # Agent-facing index
├── CLAUDE.md                # Claude Code entry point
├── README.md                # Human-facing overview
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
[sk-review] → 4 - REVIEW.md
   ▼
[sk-verify] → 5 - VERIFY.md
   ▼
[sk-pr] → 6 - PR.md
```

`sk-flow` first assesses size. A small change takes the light path: short plan, `sk-implement`, `sk-verify`, `sk-pr`, with explore, alternatives, and all three reviews skipped and the work allowed to run inline. Everything above is the full path. Each full-path phase runs in a fresh subagent when the harness has one. The worker prompt names the skill to invoke (e.g. `sk-planning`) instead of paraphrasing it, so mandatory steps inside the skill — reviews, sub-dispatch — cannot be dropped. The parent triages the output and dispatches the next phase.

## Key Decisions

### Skills are source of truth

Each skill in `skills/sk-*/SKILL.md` is the source of truth. Claude Code loads the matching skill when the user types `/sk-*` or the model matches the description. Devin loads the same skill files through the slash-kit plugin; Cursor uses them through the skill tool or rules.

### Flow runbooks are durable, validated state

Every flow lives in `.agents/flows/sk-<slug>/` with a mandatory `runbook.json` state file and numbered phase docs. The runbook is created and mutated only through `skills/sk-flow/scripts/flow-state.mjs` (`init`, `set`, `pr`), which validates every mutation against `skills/sk-flow/schemas/` before writing; `check` re-validates the whole flow and names the next phase. Each numbered doc carries a JSON frontmatter block (`<!-- -->`-wrapped) validated against its schema. The plan, implementation, review, and PR phases read these files without depending on chat context, so the workflow works across agents and sessions.

### Alternatives are reviewed before presentation

The `sk-alternatives` skill dispatches `sk-review-alternatives` to catch irrelevant, duplicate, or weak options before the user sees them. This keeps decision quality high without adding much friction.

### Rules ship in plugins, hooks fill the gaps

Shared rules live in `rules/` and ship inside the Cursor and Devin plugins. Claude Code plugins have no rules channel, and spawned subagents load no plugin rules on any platform — `hooks/inject-rules.py` covers both gaps by returning the rules as `additionalContext` on `sessionStart` and prepending them to subagent prompts on `preToolUse`.

### Workflow is opt-in

Nothing forces the full flow. Each skill is self-contained and can be used alone. Agents without skill support can follow the workflow doc in [USAGE.md](USAGE.md#run-the-workflow) manually.

## Gates

Gates keep agent runs honest: a script decides and records facts, the model keeps judgment.

1. **Scripts decide facts, the model decides meaning.** Which phase a flow is in, whether a plan's structure is complete, whether a check really ran: a script answers these deterministically and records the answer. The model writes, judges, and chooses.
2. **The base layer is a script the skill runs.** Each gate is a small script (shell or Node) the skill invokes, checking its exit code and the receipt file it writes. This works in every harness, with or without hook support.
3. **Hooks and CI are optional layers on top.** Where the harness supports hooks (Claude Code, Cursor, Devin), a hook can enforce a gate by blocking. In this repo, CI runs the same checks. Neither is required for a gate to work.
4. **No one is forced to change their setup.** Installing the plugin never requires editing CI or settings; enforcement layers are opt-in.

The gates:

- **Check receipts** (`skills/sk-implement/scripts/run-with-receipt.sh` and `check-receipt.sh`): run a check, record a receipt. A check without a valid passing receipt did not happen. Used by `sk-implement` and `sk-verify`. Receipt files stay key:value because the raw output tail cannot embed in JSON without escaping.
- **Plan lint** (`skills/sk-planning/scripts/lint-plan.sh`): a plan's structure matches the template — required sections in order, `Files` right after `Goal`, TODO depth at most 2, an explicit Proceed/Split decision. Used by `sk-planning`.
- **Flow state** (`skills/sk-flow/scripts/flow-state.mjs`): the runbook gate described under Key Decisions. With `size: "light"` it also fixes the skipped rows and requires receipts listed in the implementation and verify frontmatter. Used by `sk-flow`.

## External Dependencies

- `claude` — Claude Code CLI.
- `cursor` — Cursor CLI or IDE.
- `Node.js` — For `npx skills` and `skills/sk-flow/scripts/flow-state.mjs` (≥18).
- `gh` — Used by the `sk-pr` skill.

## Security Notes

No web server, no stored credentials, and no network calls from the toolkit itself. The `sk-pr` skill uses the user’s authenticated `gh` CLI. See [docs/SECURITY.md](SECURITY.md) for reporting vulnerabilities.
