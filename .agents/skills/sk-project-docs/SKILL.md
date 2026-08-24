---
name: sk-project-docs
description: Scaffold or nudge a project's documentation structure. Use when the user says "set up docs", "project docs", "nudge docs", "init documentation", or "update docs index".
---

# Project Docs

Create the docs a project needs and keep `AGENTS.md` and `llms.txt` in sync.

## When to use

- User asks to set up, init, nudge, or update project docs.
- A project is missing `README.md`, `AGENTS.md`, or `docs/`.
- Existing docs have drifted from the index.

## Goal

Scaffold only the docs the project needs. `AGENTS.md` is the agent-facing index. `CLAUDE.md` is a symlink (or fallback `@AGENTS.md` file) to `AGENTS.md`.

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

## Placeholders

Substitute `{{project}}`, `{{repository}}`, `{{author}}`, `{{license}}`, `{{setup}}`, `{{run}}`, `{{format}}`, `{{rules_table}}`, `{{rules_includes}}`, `{{docs_table}}`, `{{what}}`, `{{how}}`, and `{{conventions}}` from `package.json`, git remote, or by asking/inferring.

## Steps

1. **Inspect** the repo for existing docs and source of truth.
2. **Ask** the decision grid or infer and confirm.
3. **Propose** a list of docs and ask which to create.
4. **Read** the relevant templates from `templates/`.
5. **Substitute** placeholders.
6. **Write** each doc.
7. **Create or update** `AGENTS.md` from `templates/template-agents.md`. It must be three things: a rules index with a strong instruction to read the rules first, a docs index, and a highly condensed version of the docs. Include `@` includes for existing rule files.
8. **Create or update** `llms.txt` if `audience` is `public`.
9. **Create or update** `CLAUDE.md`: try `ln -s AGENTS.md CLAUDE.md`, fall back to a one-line `@AGENTS.md` file.
10. **Report** what changed and suggest using the `documentation` skill to fill prose.

Do not create rule files; only reference what already exists.

## CLAUDE.md

1. If `CLAUDE.md` exists and is already a symlink to `AGENTS.md`, leave it.
2. If it does not exist, try `ln -s AGENTS.md CLAUDE.md`.
3. If a text fallback is needed, write `@AGENTS.md`.
4. If a regular `CLAUDE.md` exists and is not the fallback, warn and ask before overwriting.

## llms.txt

If `audience` is `public`, create or update `llms.txt` with entry points, docs, skills, and rules (use raw GitHub URLs when `{{repository}}` is known; otherwise relative paths).

After creating each file, report the paths.
