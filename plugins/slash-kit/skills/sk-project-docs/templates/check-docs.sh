#!/usr/bin/env bash
# check-docs.sh — documentation hygiene lint.
# Runs every check in check-docs.d/ next to this script, from the repo root.
#
# Output: `FAIL <file>: <msg>` or `warn <file>: <msg>`, one per line.
# Exit 1 if any FAIL was printed, else 0. Checks always exit 0; the
# runner owns the exit code.
#
# Usage: check-docs.sh [repo-root]

set -u
DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
cd "$ROOT" || exit 1

out=$(
	for c in "$DIR/check-docs.d"/*.sh; do
		[ -f "$c" ] || continue
		bash "$c"
	done
)

[ -n "$out" ] && printf '%s\n' "$out" | grep . || echo "docs: ok"
printf '%s\n' "$out" | grep -qc '^FAIL' && exit 1
exit 0
