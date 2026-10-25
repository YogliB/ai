# Gates

How slash-kit keeps agent runs honest: a script decides and records facts, the model keeps judgment.

## Principles

1. **Scripts decide facts, the model decides meaning.** Which phase a flow is in, whether a plan's structure is complete, whether a check really ran: these are questions a script answers deterministically and records. The model writes, judges, and chooses.
2. **The base layer is a script the skill runs.** Each gate is a small script (shell or Node) the skill invokes, checking its exit code and the receipt file it writes. This works in every harness, with or without hook support.
3. **Hooks and CI are optional layers on top.** Where the harness supports hooks (Claude Code, Cursor, Devin), a hook can enforce a gate by blocking. In this repo, CI runs the same checks. Neither is required for a gate to work.
4. **No one is forced to change their setup.** Installing the plugin never requires editing CI or settings; enforcement layers are opt-in.

## The gates

- **Check receipts** (`skills/sk-implement/scripts/run-with-receipt.sh` and `check-receipt.sh`): run a check, record a receipt. A check without a valid passing receipt did not happen. Used by `sk-implement` and `sk-verify`. Receipt files stay key:value because the raw output tail cannot embed in JSON without escaping.
- **Plan lint** (`skills/sk-planning/scripts/lint-plan.sh`): a plan's structure matches the template - required sections in order, `Files` right after `Goal`, TODO depth at most 2, an explicit Proceed/Split decision. Used by `sk-planning`.
- **Flow state** (`skills/sk-flow/scripts/flow-state.mjs`, Node ≥18, stdlib only): `runbook.json` is validated against `skills/sk-flow/schemas/runbook.schema.json`, every artifact's frontmatter (a JSON object in an `<!-- -->` comment) against its own schema in `skills/sk-flow/schemas/`, and the whole flow contract (exact artifact names, valid states, one in-progress row, one active PR, dependencies done) — then it names the next phase. Agents never hand-edit state: `init` creates a runbook, `set` mutates rows and top-level fields, `pr` manages PR rows, and every mutation is re-validated so errors cannot be introduced. With `size: "light"` it also fixes the skipped rows and requires receipts listed in the implementation and verify frontmatter. Used by `sk-flow`.
