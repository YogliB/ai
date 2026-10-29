# Architecture

A cross-agent toolkit: reusable skills, plus an optional multi-phase workflow on top.

## Layout

```text
./
├── skills/                  # Source of truth for all agents
│   ├── snail-flow/             #   the workflow + flow-state.mjs gate + templates
│   ├── snail-implement/        #   + receipt scripts
│   ├── snail-planning/         #   + lint-plan.mjs + plan templates
│   └── snail-*/                #   explore, alternatives, review-*, verify, pr, ...
├── .agents/flows/           # Flow dirs (snail-*, gitignored by default)
├── rules/                   # Shared rules, shipped in the Cursor and Devin plugins
├── .cursor-plugin/          # Cursor manifest (repo root is the plugin)
├── .claude-plugin/          # Claude Code manifest
├── plugins/snail/           # Devin plugin — synced from root, never edited directly
├── scripts/                 # install, uninstall, sync, vendor
└── tests/                   # node --test suite for the scripts and gates
```

## How a request flows

```text
user prompt ──▶ matching skills/snail-*/SKILL.md ──▶ output or file artifact
```

Claude Code loads the skill via `/snail-*` or description match, Devin via `/snail:*`, Cursor through the plugin's skills and rules. Agents without skill support can read the SKILL.md files by hand.

A full `/snail-flow` run chains the phase skills:

```text
explore ─▶ alternatives ─▶ planning ─▶ implement ─▶ review ─▶ verify ─▶ pr
```

Each full-path phase runs in a fresh subagent when the harness has one. The worker prompt names the skill to invoke (never a paraphrased checklist — that would drop the mandatory steps inside the skill). `snail-flow` triages size first: small changes take the light path — plan, implement, verify, PR — with explore, alternatives, and the review rows skipped.

## Key decisions

### Skills are the source of truth

Each `skills/snail-*/SKILL.md` is the one definition of what that skill does. Every channel (Claude, Cursor, Devin, single-skill installs) ships or reads the same files — no per-agent forks to drift apart.

### The gate is a cursor, not a state machine

Every flow lives in `.agents/flows/snail-<slug>/`: a `runbook.yaml`, the numbered phase YAML artifacts, and `receipts/` — one self-contained bundle.

- `at` is the cursor; `rows.<row>.*` records what each `advance` captured.
- Four commands: `init`, `check`, `advance` (the only structural mutation — it refuses until the row's artifact exists and its required flags pass), `note` (append-only), and `set` (repair hatch).
- Agents never hand-edit the runbook; the script (`skills/snail-flow/scripts/flow-state.mjs`) owns it.
- Everything the flow produces is YAML: the runbook, the phase artifacts, the receipts. The gate parses artifact YAML with the vendored parser, so a malformed artifact fails the check instead of passing silently.
- `init` writes `.agents/.gitignore` (`flows/`) so flows stay private; delete that line to commit them.

What the gate guarantees, and nothing more: fixed phase order, artifact must exist and parse, review can't close with valid findings, verify can't close without a passing receipt.

### Scripts are Node (current LTS), one language

All authored scripts are Node with JSDoc — no `sh`/`awk` mix. YAML needs a real parser, so `js-yaml` is vendored as a single dependency-free file inside each skill that needs it (`scripts/vendor/js-yaml.mjs`); installing or using a skill never runs npm or touches the network. Git is opportunistic: `git-head` is recorded when present, never required.

### Alternatives get reviewed before you see them

`snail-alternatives` dispatches `snail-review-alternatives` to weed out irrelevant, duplicate, or weak options before they reach the user.

### Rules ship as files per channel

`rules/` goes inside the Cursor and Devin plugins. Claude Code has no plugin rules channel, so `scripts/install-claude-rules.mjs` copies them into `~/.claude/snail/` and `@`-imports them from `~/.claude/CLAUDE.md` — imported memory reaches subagents without any prompt rewriting.

### The workflow is opt-in

Every skill works alone, including single-skill installs — skills skip gate calls when `flow-state.mjs` isn't there. Nothing forces `snail-flow`.

## Gates

A gate keeps a run honest: a script decides facts and records them; the model keeps judgment.

1. **Scripts decide facts, the model decides meaning.** Which phase a flow is in, whether a check really ran — a script answers deterministically.
2. **The base layer is a script the skill runs.** Small Node scripts; the skill checks exit codes and the files they write. Works in every harness. A missing or too-old Node fails loudly and names the fix — a mandatory gate is never skipped silently.
3. **CI is optional on top.** Same checks, not required.

The three gates:

- **Check receipts** (`run-with-receipt.mjs`, `check-receipt.mjs`): run a check, record a YAML receipt inside the flow's `receipts/` — command, exit code, timestamps, `git-head`, output tail. A check without a valid passing receipt did not happen. `--head` binds to the current commit when git is available, skips cleanly when not. `flow-state.mjs` warns (never blocks) when a cited receipt was recorded behind the current HEAD or on a commit that is not its ancestor.
- **Plan lint** (`lint-plan.mjs`): plan structure matches the template — required keys in order, `files` right after `goal`, bounded TODO depth, explicit `proceed`/`split` decision, no leftover template placeholders.
- **Flow state** (`flow-state.mjs`): the cursor gate above. `size: light` limits rows to `2, 3, 5, 6`.

## Dependencies

- Node.js, current LTS (24+) — required. The toolkit's scripts and gates run on it; everything else a skill needs is vendored inside the skill, so consumers never run npm or fetch anything.
- `git` — opportunistic (receipt metadata, the `snail-pr` flow).
- `gh` — `snail-pr` only.
- `npx` — only for the `npx skills add` install path.

## Security

No server, no credentials, no network calls from the toolkit. `snail-pr` uses the user's own authenticated `gh`. Report issues per [docs/SECURITY.md](SECURITY.md).
