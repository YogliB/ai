# AI — Cursor Rules, Skills, and Workflows

Public repository containing reusable Cursor IDE rules, skills, subagent workflows, and personal developer toolkit references.

## Repository Structure

| Path | Description |
| --- | --- |
| [`.agents/skills/`](.agents/skills/) | On-demand agent skills and workflows |
| [`.cursor/agents/`](.cursor/agents/) | Subagent prompts (`chore-runner`) |
| [`package.json`](package.json) | Node environment and formatting scripts |

## Quick Start

```bash
npm install
npm run format
```

## Included Skills

On-demand workflows in `.agents/skills/`:

- **alternatives**: Evaluate up to 3 viable implementation/design alternatives with pros/cons before writing code.
- **apfel**: Delegate repetitive, low-risk tasks to macOS Tahoe's on-device Apple Intelligence CLI.
- **planning**: Generate self-contained, executable technical plans with atomic testable TODOs and plan review loops.
- **pr**: Create or update GitHub PRs via `gh` CLI with standard titles, templates, issue links, and image attachments.
- **review-and-fix**: Closed-loop code review pass (subagent) and fix cycle until zero valid findings remain.
- **review-dont-fix**: One-shot read-only code review without modifying source code.

## Subagents

Custom subagent prompts in `.cursor/agents/`:

- **chore-runner**: Fast, read-only agent for log tailing, terminal output inspection, CLI lookups, and web retrieval.

## Rules & Development Philosophy

Core guidelines and tools used in development:

- **caveman**: Terse, fluff-free communication mode for AI agents. Focus strictly on technical substance.
- **ponytail**: Anti-overengineering rules ("lazy senior dev mode"). Favor standard library, native platform features, YAGNI, and minimal code.
- **rtk**: [Rust Token Killer](https://github.com/reachingforthejack/rtk) — token-optimized CLI proxy saving 60-90% tokens on shell and developer tool outputs.

## External Skills & Plugins

Toolkit references and external agent plugins:

- **[mattpocock/skills/grilling](https://github.com/mattpocock/skills)**: Relentlessly grill plans, architectural decisions, and trade-offs before implementation.
- **[softaworks/agent-toolkit/humanizer](https://github.com/softaworks/agent-toolkit)**: Remove robotic phrasing and AI writing tropes from documentation and content.
- **[anthropics/knowledge-work-plugins/documentation](https://github.com/anthropics/knowledge-work-plugins)**: Structured standards for technical documentation, API references, runbooks, and onboarding guides.
