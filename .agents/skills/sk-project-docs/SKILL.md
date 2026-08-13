---
name: sk-project-docs
description: Scaffold or nudge a project's documentation structure. Trigger with "set up docs", "project docs", "nudge docs", "init documentation", or "update docs index".
---

# Project Docs

Create the right documentation structure for the project and keep `AGENTS.md` and `llms.txt` in sync.

## When to use

- The user asks to "set up docs", "init docs", "project docs", "nudge docs", or "update the docs index".
- A project is missing `README.md`, `AGENTS.md`, or the `docs/` directory.
- Existing docs have drifted from the index.

## Goal

Scaffold only the docs the project needs, based on its context. `AGENTS.md` becomes the agent-facing index and condensed entry point. `CLAUDE.md` is a symlink (or fallback include) to `AGENTS.md`.

## Output

The following files may be created or updated in the repo root and `docs/`:

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

## Steps

1. **Inspect** the repo for existing docs and source of truth (`package.json`, `pyproject.toml`, `Cargo.toml`, git remote, source layout).
2. **Ask** the decision grid or infer and confirm.
3. **Propose** a list of docs with rationale and ask which to create.
4. **Read** the relevant templates from `templates/` next to this `SKILL.md`.
5. **Substitute** placeholders.
6. **Write** each doc.
7. **Create or update** `AGENTS.md` from `templates/template-agents.md`, filling the quick links and documentation sync sections.
8. **Create or update** `llms.txt` if public.
9. **Create or update** `CLAUDE.md`: try a relative symlink to `AGENTS.md`, then fall back to a one-line `@AGENTS.md` file.
10. **Report** what changed and suggest using the `documentation` skill to fill content.

## Decision grid

Ask the user, or infer from the repo:

- `audience`: `public` | `internal` | `personal`
- `openness`: `oss` | `proprietary` | `none`
- `project_type`: `cli` | `library` | `web-app` | `internal-tool` | `skill-repo` | `other`
- `releases`: `versioned` | `continuous` | `none`
- `rules_dir`: does `.agents/rules/` exist? (used only for `AGENTS.md` includes)

## File selection

| File                      | Default condition                                                |
| ------------------------- | ---------------------------------------------------------------- |
| `README.md`               | always                                                           |
| `AGENTS.md`               | always                                                           |
| `CLAUDE.md`               | always                                                           |
| `llms.txt`                | `audience` is `public`                                           |
| `LICENSE.md`              | `openness` is `oss` or user wants one                            |
| `docs/ARCHITECTURE.md`    | project is non-trivial or user wants                             |
| `docs/USAGE.md`           | `project_type` is `cli`, `library`, or `web-app`                 |
| `docs/CONTRIBUTING.md`    | project has contributors; template chosen by `openness`          |
| `docs/SECURITY.md`        | project has users or contributors; template chosen by `openness` |
| `docs/CODE_OF_CONDUCT.md` | `openness` is `oss` or corp policy                               |
| `docs/CHANGELOG.md`       | `releases` is `versioned`                                        |
| `docs/TROUBLESHOOTING.md` | project has common failure modes or user wants                   |

## Placeholders

Substitute these in each template:

- `{{project}}` — project name (from `package.json` name, directory, or ask)
- `{{repository}}` — repository URL (from `package.json` repository or git remote)
- `{{author}}` — author or org
- `{{license}}` — license name (e.g., MIT)
- `{{setup}}` — setup command
- `{{run}}` — run/test command
- `{{format}}` — format/lint command

## AGENTS.md

`AGENTS.md` is the index and condensed entry point. Use `templates/template-agents.md` and:

- Add a quick links table for every doc that exists.
- Add a "Documentation sync" section listing the files to keep aligned.
- Add `@` includes for rule files at the bottom:
    - `.agents/rules/*.md` if the directory exists.
    - `.claude/rules/*.md` if the directory exists.

Do not create rule files; only reference what already exists.

## CLAUDE.md

1. If `CLAUDE.md` exists and is already a symlink to `AGENTS.md`, leave it.
2. If it does not exist, try: `ln -s AGENTS.md CLAUDE.md` from the repo root.
3. If the symlink is not supported (text file with `AGENTS.md` as content, or `ln` fails), delete it and write a file with:
    ```markdown
    @AGENTS.md
    ```
4. If a regular `CLAUDE.md` already exists and is not the fallback, warn and ask before overwriting.

## llms.txt

If `audience` is `public`, create or update `llms.txt` with:

- Entry points: `README.md`, `AGENTS.md`, `CLAUDE.md`, `package.json`.
- Docs: relative paths or raw GitHub URLs.
- Skills: `.agents/skills/*/SKILL.md` if present.
- Rules: `.agents/rules/*.md` if present.

Use raw GitHub URLs when the `{{repository}}` is known; otherwise use relative paths.

## Templates

Templates live in `templates/` next to this file. Choose by condition:

- `README.md` → `templates/README.md`
- `AGENTS.md` → `templates/template-agents.md`
- `llms.txt` → `templates/llms.txt`
- `LICENSE.md` → do not create from a template; ask the user to choose a license and write the file.
- `docs/ARCHITECTURE.md` → `templates/ARCHITECTURE.md`
- `docs/USAGE.md` → `templates/USAGE.md`
- `docs/CONTRIBUTING.md` → `templates/CONTRIBUTING-oss.md` if `openness` is `oss`, else `templates/CONTRIBUTING-internal.md`
- `docs/SECURITY.md` → `templates/SECURITY-oss.md` if `openness` is `oss`, else `templates/SECURITY-internal.md`
- `docs/CODE_OF_CONDUCT.md` → `templates/CODE_OF_CONDUCT.md`
- `docs/CHANGELOG.md` → `templates/CHANGELOG.md`
- `docs/TROUBLESHOOTING.md` → `templates/TROUBLESHOOTING.md`

After creating each file, stop and report the paths. Suggest using the `documentation` skill to fill the prose.
