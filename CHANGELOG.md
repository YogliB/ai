# Changelog

All notable user-facing changes to snail are documented in this file.

## [0.0.1] - 2026-10-30

First release of snail.

### Added

- Skills for every phase of a change: `snail-explore`, `snail-alternatives`, `snail-planning`, `snail-implement`, `snail-review`, `snail-review-alternatives`, `snail-review-plan`, `snail-verify`, `snail-pr`, `snail-project-docs`, and `snail-ai-toolbelt`.
- An optional end-to-end workflow (`snail-flow`): explore -> alternatives -> plan -> build -> review -> verify -> PR, with stage gates and a receipt for every phase.
- An always-on no-comments rule that keeps generated code comment-free.
- Works with Claude Code, Cursor, Devin, and any agent via `npx skills add`.
