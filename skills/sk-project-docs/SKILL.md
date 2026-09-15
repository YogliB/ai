---
name: sk-project-docs
description: Scaffold, audit, or nudge a project's documentation structure. Use when the user says "set up docs", "project docs", "nudge docs", "init documentation", "update docs index", or when docs are redundant and scattered.
---

# Project Docs

Create the docs a project needs, prune the ones it does not, and keep `AGENTS.md` and `llms.txt` in sync.

## When to use

- User asks to set up, init, nudge, or update project docs.
- A project is missing `README.md`, `AGENTS.md`, or `docs/`.
- Existing docs have drifted from the index.
- Existing docs are redundant, overlapping, or scattered.

## Goal

Scaffold only the docs the project needs. Audit existing docs, move overlapping content to the right standard doc, and ask before removing files.

`AGENTS.md` and `CLAUDE.md` are agent-only. `AGENTS.md` must be three things: a docs index, an AI rules index, and a highly condensed version of the docs. `CLAUDE.md` is a symlink (or fallback `@AGENTS.md` file) to `AGENTS.md`.

Docs are human- and agent-facing. Agent-only rules go in `.agents/rules/`, one rule per file, and are concatenated into the `<!-- rules -->` block of `AGENTS.md` by `scripts/sync-agents.sh` — `@`-includes only work on agents that resolve them, the generated block works everywhere.

## Output

These files may be created or updated:

- `README.md`
- `AGENTS.md`
- `CLAUDE.md`
- `llms.txt` (public projects)
- `LICENSE.md` (open or public projects)
- `docs/ARCHITECTURE.md`
- `docs/USAGE.md`
- `docs/CONTRIBUTING.md`
- `docs/SECURITY.md`
- `docs/CODE_OF_CONDUCT.md`
- `docs/CHANGELOG.md`
- `docs/TROUBLESHOOTING.md`
- `docs/<name>/*.md` (optional deep dives under a parent doc)
- `scripts/check-docs.sh` + `scripts/check-docs.d/` + `scripts/sync-agents.sh`

## Decision grid

Ask the user or infer from the repo:

| Field        | Values                                                  |
| ------------ | ------------------------------------------------------- |
| audience     | public, internal, personal                              |
| openness     | oss, proprietary, none                                  |
| project_type | cli, library, web-app, internal-tool, skill-repo, other |
| releases     | versioned, continuous, none                             |
| rules_dir    | does `.agents/rules/` exist?                            |

## File selection

| File                      | Default condition                                |
| ------------------------- | ------------------------------------------------ |
| `README.md`               | always                                           |
| `AGENTS.md`               | always                                           |
| `CLAUDE.md`               | always                                           |
| `llms.txt`                | `audience` is `public`                           |
| `LICENSE.md`              | `openness` is `oss` or user wants one            |
| `docs/ARCHITECTURE.md`    | project is non-trivial or user wants             |
| `docs/USAGE.md`           | `project_type` is `cli`, `library`, or `web-app` |
| `docs/CONTRIBUTING.md`    | project has contributors                         |
| `docs/SECURITY.md`        | project has users or contributors                |
| `docs/CODE_OF_CONDUCT.md` | `openness` is `oss` or corp policy               |
| `docs/CHANGELOG.md`       | `releases` is `versioned`                        |
| `docs/TROUBLESHOOTING.md` | project has common failure modes or user wants   |

Choose templates from `templates/` next to this `SKILL.md` (e.g. `README.md` → `templates/README.md`, `CONTRIBUTING.md` → `templates/CONTRIBUTING-oss.md` or `templates/CONTRIBUTING-internal.md`).

## Standard docs tree

A project should hold only these docs:

- `README.md` — human-facing overview, install, and usage.
- `AGENTS.md` — agent-only index: docs index, AI rules index, condensed docs.
- `CLAUDE.md` — symlink or `@AGENTS.md` fallback.
- `llms.txt` — public projects only.
- `LICENSE.md` — open/public projects.
- `docs/ARCHITECTURE.md` — structure and data flow. Template follows the [architecture.md](https://architecture.md/) spec.
- `docs/USAGE.md` — detailed usage.
- `docs/CONTRIBUTING.md` — setup, conventions, and PRs.
- `docs/SECURITY.md` — security policy.
- `docs/CODE_OF_CONDUCT.md` — open/corp policy.
- `docs/CHANGELOG.md` — versioned releases.
- `docs/TROUBLESHOOTING.md` — common problems.
- `docs/<name>/*.md` — optional deep-dive overflow for one `docs/<NAME>.md`. Exists only when the parent can't hold the content. Must stay flat, and every file must be linked from the parent.

Anything outside this tree that overlaps with a standard doc is a candidate for merging, not indexing. Anything that doesn't fit a standard doc and earns its keep goes under `docs/<name>/` — never a new top-level file.

## Audit checks

Deterministic lint, not editorial judgment. `templates/check-docs.sh` runs every check in `templates/check-docs.d/` from the repo root and prints `FAIL <file>: <msg>` / `warn <file>: <msg>` lines. Run it first, read only the flagged files, fix, re-run until clean.

| Check              | Catches                                                             | Level              |
| ------------------ | ------------------------------------------------------------------- | ------------------ |
| `line-budget`      | `docs/ARCHITECTURE.md` / `docs/CONTRIBUTING.md` over 300 lines      | FAIL (core) / warn |
| `quarantine`       | top-level `docs/*.md` outside the standard tree                     | FAIL               |
| `overflow-parent`  | `docs/<name>/` dir with no `docs/<NAME>.md` parent                  | FAIL               |
| `overflow-orphan`  | `docs/<name>/*.md` not linked from its parent                       | FAIL               |
| `overflow-flat`    | nested dirs or non-md files inside `docs/<name>/`                   | FAIL / warn        |
| `overflow-count`   | one `docs/<name>/` holding over 5 files                             | warn               |
| `no-ast-mirroring` | markdown tables of code identifiers (env vars, dotted names, paths) | warn               |
| `process-boundary` | architecture-style headings in CONTRIBUTING/USAGE                   | warn               |
| `agents-sync`      | AGENTS.md rules block out of sync with `.agents/rules/`             | FAIL               |

Each file in `check-docs.d/` is self-documenting: header comment states the rule, body implements it. Budgets tune via `DOCS_BUDGET` and `DOCS_OVERFLOW_MAX` env vars.

## Placeholders

Substitute `{{project}}`, `{{repository}}`, `{{author}}`, `{{license}}`, `{{setup}}`, `{{run}}`, `{{format}}`, `{{rules_table}}`, `{{docs_table}}`, `{{what}}`, `{{how}}`, and `{{conventions}}` from `package.json`, git remote, or by asking/inferring.

- `{{rules_table}}` — full markdown table with columns `Rule`, `File`, `What it covers`.
- `{{docs_table}}` — full markdown table with columns `Doc`, `Purpose`.
- `{{what}}` — one-paragraph summary of what the project is.
- `{{how}}` — short setup, conventions, common commands, and project layout.
- `{{conventions}}` — bullet list of the conventions an agent must follow.

## Conventions

- `AGENTS.md` is agent-only. No long prose, no human tutorial, no pull-request section. Just docs index, rules index, condensed docs.
- Agent-only rules live in `.agents/rules/`, one rule per file. `AGENTS.md` never references them with `@`-includes — `scripts/sync-agents.sh` splices them into the rules block instead.
- Start `AGENTS.md` with a strong instruction to read the rules before doing any work.
- Docs are human- and agent-facing. Do not duplicate `AGENTS.md` content in `README.md` or `docs/*`.
- Do not mirror code into docs. No tables of env vars, schema columns, or file inventories — link the source of truth.

## Steps

1. **Lint first.** Run `scripts/check-docs.sh` in the target repo; if absent, run `templates/check-docs.sh` from this skill with the repo root as argument. The report is the audit.
2. **Inspect** flagged files plus the repo's decision-grid signals and source of truth.
3. **Propose** fixes: which docs to create, update, merge, move under `docs/<name>/`, or remove. Ask before proceeding.
4. **Do not remove files** without explicit user approval. Move content first, then ask whether to delete the source.
5. **Read** the relevant templates from `templates/`.
6. **Substitute** placeholders.
7. **Write** each doc.
8. **Create or update** `AGENTS.md` from `templates/template-agents.md`. It must be a rules-first index, then a docs index, then a highly condensed version of the docs.
9. **Emit the scripts**: copy `check-docs.sh`, `check-docs.d/`, and `sync-agents.sh` into the repo's `scripts/` (skip only if the repo can't run bash). Run `sync-agents.sh` once `.agents/rules/` exists.
10. **Create or update** `llms.txt` if `audience` is `public`.
11. **Create or update** `CLAUDE.md`: try `ln -s AGENTS.md CLAUDE.md`, fall back to a one-line `@AGENTS.md` file.
12. **Re-run `check-docs.sh`.** Clean exit is the done condition, not your judgment.
13. **Report** what changed and suggest using the `documentation` skill to fill prose.

Do not create rule files; only reference what already exists.

## CLAUDE.md

1. If `CLAUDE.md` exists and is already a symlink to `AGENTS.md`, leave it.
2. If it does not exist, try `ln -s AGENTS.md CLAUDE.md`.
3. If a text fallback is needed, write `@AGENTS.md`.
4. If a regular `CLAUDE.md` exists and is not the fallback, warn and ask before overwriting.

## llms.txt

If `audience` is `public`, create or update `llms.txt` with entry points, docs, skills, and rules (use raw GitHub URLs when `{{repository}}` is known; otherwise relative paths).

After creating each file, report the paths.
