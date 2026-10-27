# Architecture

A cross-agent toolkit: reusable skills, plus an optional multi-phase workflow on top.

## Layout

```text
./
├── skills/                  # Source of truth for all agents
│   ├── sk-flow/             #   the workflow + flow-state.sh gate + templates
│   ├── sk-implement/        #   + receipt scripts
│   ├── sk-planning/         #   + lint-plan.sh + plan templates
│   └── sk-*/                #   explore, alternatives, review-*, verify, pr, ...
├── .agents/flows/           # Flow dirs (sk-*, gitignored by default)
├── rules/                   # Shared rules, shipped in the Cursor and Devin plugins
├── .cursor-plugin/          # Cursor manifest (repo root is the plugin)
├── .claude-plugin/          # Claude Code manifest
├── plugins/slash-kit/       # Devin plugin — synced from root, never edited directly
└── scripts/                 # install, uninstall, sync, tests
```

## How a request flows

```text
user prompt ──▶ matching skills/sk-*/SKILL.md ──▶ output or file artifact
```

Claude Code loads the skill via `/sk-*` or description match, Devin via `/slash-kit:*`, Cursor through the plugin's skills and rules. Agents without skill support can read the SKILL.md files by hand.

A full `/sk-flow` run chains the phase skills:

```text
explore ─▶ alternatives ─▶ planning ─▶ implement ─▶ review ─▶ verify ─▶ pr
```

Each full-path phase runs in a fresh subagent when the harness has one. The worker prompt names the skill to invoke (never a paraphrased checklist — that would drop the mandatory steps inside the skill). `sk-flow` triages size first: small changes take the light path — plan, implement, verify, PR — with explore, alternatives, and the review rows skipped.

## Key decisions

### Skills are the source of truth

Each `skills/sk-*/SKILL.md` is the one definition of what that skill does. Every channel (Claude, Cursor, Devin, single-skill installs) ships or reads the same files — no per-agent forks to drift apart.

### The gate is a cursor, not a state machine

Every flow lives in `.agents/flows/sk-<slug>/`: a flat `key: value` `runbook`, the numbered phase docs, and `receipts/` — one self-contained bundle.

- `at` is the cursor; `f.<row>.*` records what each `advance` captured.
- Four commands: `init`, `check`, `advance` (the only structural mutation — it refuses until the row's artifact exists and its required flags pass), `note` (append-only), and `set` (repair hatch).
- Agents never hand-edit the runbook; the script (`skills/sk-flow/scripts/flow-state.sh`) owns it.
- Phase docs are pure Markdown for humans. Gate data lives in the runbook — nothing parses the docs.
- `init` writes `.agents/.gitignore` (`flows/`) so flows stay private; delete that line to commit them.

What the gate guarantees, and nothing more: fixed phase order, artifact must exist, review can't close with valid findings, verify can't close without a passing receipt.

### Scripts are `sh` + coreutils, nothing else

Node and Python existed only to touch JSON — kill the JSON and both runtimes vanish. The runbook and receipts are flat `key: value` (readable by `grep`/`sed`), gate fields ride on `advance` flags, and rules are plain files per channel. Git is opportunistic: `git-head` is recorded when present, never required.

### Alternatives get reviewed before you see them

`sk-alternatives` dispatches `sk-review-alternatives` to weed out irrelevant, duplicate, or weak options before they reach the user.

### Rules ship as files per channel

`rules/` goes inside the Cursor and Devin plugins. Claude Code has no plugin rules channel, so `scripts/install-claude-rules.sh` copies them into `~/.claude/slashkit/` and `@`-imports them from `~/.claude/CLAUDE.md` — imported memory reaches subagents without any prompt rewriting.

### The workflow is opt-in

Every skill works alone, including single-skill installs — skills skip gate calls when `flow-state.sh` isn't there. Nothing forces `sk-flow`.

## Gates

A gate keeps a run honest: a script decides facts and records them; the model keeps judgment.

1. **Scripts decide facts, the model decides meaning.** Which phase a flow is in, whether a check really ran — a script answers deterministically.
2. **The base layer is a script the skill runs.** Small `sh` scripts; the skill checks exit codes and the files they write. Works in every harness.
3. **CI is optional on top.** Same checks, not required.

The three gates:

- **Check receipts** (`run-with-receipt.sh`, `check-receipt.sh`): run a check, record a receipt inside the flow's `receipts/` — command, exit code, timestamps, `git-head`, output tail. A check without a valid passing receipt did not happen. `--head` binds to the current commit when git is available, skips cleanly when not.
- **Plan lint** (`lint-plan.sh`): plan structure matches the template — required sections in order, `Files` right after `Goal`, bounded TODO depth, explicit decision.
- **Flow state** (`flow-state.sh`): the cursor gate above. `size: light` limits rows to `2, 3, 5, 6`.

## Dependencies

- `sh` + core utilities — required, that's all.
- `git` — opportunistic (receipt metadata, the `sk-pr` flow).
- `gh` — `sk-pr` only.
- `npx` — only for the `npx skills add` install path.

## Security

No server, no credentials, no network calls from the toolkit. `sk-pr` uses the user's own authenticated `gh`. Report issues per [docs/SECURITY.md](SECURITY.md).
