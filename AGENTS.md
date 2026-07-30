# AGENTS.md

Agent-facing index and condensed notes for this repo.

## Index

| Doc                                                                | Purpose                               |
| ------------------------------------------------------------------ | ------------------------------------- |
| [README.md](README.md)                                             | Human-facing overview and quick start |
| [package.json](package.json)                                       | nub scripts and dependencies          |
| [.node-version](.node-version)                                     | Pinned Node: lts/24                   |
| [.husky/pre-commit](.husky/pre-commit)                             | Pre-commit lint step                  |
| [.agents/skills/](.agents/skills/)                                 | On-demand agent skills                |
| [.claude/agents/chore-runner.md](.claude/agents/chore-runner.md)   | Claude subagent prompt                |
| [.cursor/.agents/chore-runner.md](.cursor/.agents/chore-runner.md) | Cursor subagent prompt                |

## Summary

Personal toolkit of reusable agent skills and cross-IDE subagent prompts. Uses nub for package management and pins Node to lts/24. Skills cover planning, PRs, code review, and option analysis; the single subagent prompt is chore-runner.
