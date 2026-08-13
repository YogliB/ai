# AGENTS.md

Agent-facing entry point. For the open format, see [agents.md](https://agents.md/).

## Quick links

| Topic                      | Where to look                                      |
| -------------------------- | -------------------------------------------------- |
| User-facing overview       | [README.md](README.md)                             |
| Agent entry point          | [CLAUDE.md](CLAUDE.md)                             |
| Architecture and data flow | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)       |
| Usage                      | [docs/USAGE.md](docs/USAGE.md)                     |
| Contributing               | [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)       |
| Troubleshooting            | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Security policy            | [docs/SECURITY.md](docs/SECURITY.md)               |
| Code of conduct            | [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md) |
| Changelog                  | [docs/CHANGELOG.md](docs/CHANGELOG.md)             |
| License                    | [LICENSE.md](LICENSE.md)                           |
| Skills                     | [.agents/skills/](.agents/skills/)                 |
| AI rules                   | [.agents/rules/](.agents/rules/)                   |

## Setup

```bash
{{setup}}
```

## Common commands

| Command      | Purpose                  |
| ------------ | ------------------------ |
| `{{setup}}`  | Install dependencies.    |
| `{{run}}`    | Run or test the project. |
| `{{format}}` | Format and lint.         |

## Project layout

- `README.md` — human-facing overview.
- `AGENTS.md` — this file; agent index and condensed docs.
- `CLAUDE.md` — entry point for Claude Code.
- `docs/` — contributor and user documentation.
- `.agents/skills/` — on-demand skills.
- `.agents/rules/` — always-on rules.

## Documentation sync

Keep these aligned when changing workflow, conventions, or navigation:

- `README.md`, `AGENTS.md`, `CLAUDE.md`
- `docs/ARCHITECTURE.md`, `docs/CONTRIBUTING.md`, `docs/SECURITY.md`, `docs/USAGE.md`, `docs/TROUBLESHOOTING.md`, `docs/CHANGELOG.md`
- `.agents/rules/*.md`

## Rules

@.agents/rules/\*.md
