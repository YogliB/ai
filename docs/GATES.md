# Gates

How slash-kit keeps agent runs honest: a script decides and records facts, the model keeps judgment.

## Principles

1. **Scripts decide facts, the model decides meaning.** Which phase a flow is in, whether a plan's structure is complete, whether a check really ran: these are questions a script answers deterministically and records. The model writes, judges, and chooses.
2. **The base layer is a script the skill runs.** Each gate is a small shell script the skill invokes, checking its exit code and the receipt file it writes. This works in every harness, with or without hook support.
3. **Hooks and CI are optional layers on top.** Where the harness supports hooks (Claude Code, Cursor, Devin), a hook can enforce a gate by blocking. In this repo, CI runs the same checks. Neither is required for a gate to work.
4. **No one is forced to change their setup.** Installing the plugin never requires editing CI or settings; enforcement layers are opt-in.

## The gates

- **Check receipts** (`skills/sk-implement/scripts/run-with-receipt.sh` and `check-receipt.sh`): run a check, record a receipt. A check without a valid passing receipt did not happen. Used by `sk-implement` and `sk-verify`.
- **Plan lint** (`skills/sk-planning/scripts/lint-plan.sh`): a plan's structure matches the template - required sections in order, `Files` right after `Goal`, TODO depth at most 2, an explicit Proceed/Split decision. Used by `sk-planning`.
- **Flow state** (`skills/sk-flow/scripts/flow-state.sh`): a flow's recorded state is validated against the sk-flow contract (exact artifact names, valid states, one in-progress row, one active PR, dependencies done) and names the next phase. Used by `sk-flow`.
