#!/usr/bin/env bash
# sync-agents.sh — splice .agents/rules/*.md into the rules block of
# AGENTS.md, so agents that can't resolve @-includes still get rules.
#
# The block lives between <!-- rules:start --> and <!-- rules:end -->
# markers. Edit .agents/rules/, never the block.
#
# Usage: sync-agents.sh          rewrite AGENTS.md in place
#        sync-agents.sh --check  exit 1 if the block is stale

set -eu
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1

AGENTS=AGENTS.md
RULES_DIR=.agents/rules
S='<!-- rules:start -->'
E='<!-- rules:end -->'

[ -f "$AGENTS" ] || {
	echo "sync-agents: no AGENTS.md"
	exit 1
}
grep -q "$S" "$AGENTS" || {
	echo "sync-agents: no $S marker in AGENTS.md"
	exit 1
}

gen() {
	echo "$S"
	echo "<!-- generated from .agents/rules/ — do not edit, run scripts/sync-agents.sh -->"
	for r in "$RULES_DIR"/*.md; do
		[ -f "$r" ] || continue
		printf '\n### %s\n\n' "$(basename "$r" .md)"
		cat "$r"
		printf '\n'
	done
	echo "$E"
}

if [ "${1:-}" = "--check" ]; then
	tmp=$(mktemp)
	trap 'rm -f "$tmp"' EXIT
	gen >"$tmp"
	sed -n "/$S/,/$E/p" "$AGENTS" | diff -q - "$tmp" >/dev/null || {
		echo "AGENTS.md: rules block stale — run scripts/sync-agents.sh"
		exit 1
	}
	exit 0
fi

tmp=$(mktemp)
block=$(mktemp)
trap 'rm -f "$tmp" "$block"' EXIT
gen >"$block"
awk -v s="$S" -v e="$E" -v b="$block" '
	$0 == s && !skip { system("cat " b); skip = 1; next }
	skip && $0 == e { skip = 0; next }
	skip { next }
	{ print }
' "$AGENTS" >"$tmp"
mv "$tmp" "$AGENTS"
echo "sync-agents: AGENTS.md updated"
