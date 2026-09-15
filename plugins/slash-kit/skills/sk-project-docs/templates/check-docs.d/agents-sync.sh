#!/usr/bin/env bash
# agents-sync — AGENTS.md rules block must match .agents/rules/.
# Delegates to scripts/sync-agents.sh --check when present.
set -u

if [ -x scripts/sync-agents.sh ]; then
	scripts/sync-agents.sh --check >/dev/null 2>&1 ||
		echo "FAIL AGENTS.md: stale rules block — run scripts/sync-agents.sh"
elif [ -d .agents/rules ] && grep -q 'rules:start' AGENTS.md 2>/dev/null; then
	echo "warn AGENTS.md: rules block but no scripts/sync-agents.sh"
fi
exit 0
