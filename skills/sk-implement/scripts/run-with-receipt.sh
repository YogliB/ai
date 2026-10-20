#!/bin/sh
# Runs a check command and records a receipt: what ran, when, on which
# commit, and how it ended. A check without a valid passing receipt did
# not happen. See docs/GATES.md.
set -eu

usage() {
	echo "usage: run-with-receipt.sh <label> -- <command...>" >&2
	exit 2
}

[ $# -ge 3 ] || usage
LABEL=$1
shift
[ "${1:-}" = "--" ] || usage
shift
[ $# -ge 1 ] || usage

case $LABEL in
	*[!A-Za-z0-9._-]*)
		echo "run-with-receipt: label may only contain letters, digits, dot, dash, underscore: $LABEL" >&2
		exit 2
		;;
esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIR="$ROOT/.agents/receipts"
mkdir -p "$DIR"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_S=$(date +%s)
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

set +e
"$@" >"$OUT" 2>&1
CODE=$?
set -e

END_S=$(date +%s)
ENDED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$CODE" -eq 0 ]; then RESULT=pass; else RESULT=fail; fi
HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo none)
BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)

RECEIPT="$DIR/$STAMP-$LABEL.receipt"
{
	echo "receipt-version: 1"
	echo "label: $LABEL"
	printf 'command:'
	for a in "$@"; do printf ' %s' "$a"; done
	echo
	echo "exit-code: $CODE"
	echo "result: $RESULT"
	echo "started-at: $STARTED"
	echo "finished-at: $ENDED"
	echo "duration-seconds: $((END_S - START_S))"
	echo "git-head: $HEAD"
	echo "git-branch: $BRANCH"
	echo "cwd: $(pwd)"
	echo
	echo "--- output (last 30 lines) ---"
	tail -30 "$OUT"
} >"$RECEIPT"

cat "$RECEIPT"
echo "run-with-receipt: receipt written to $RECEIPT" >&2
exit "$CODE"
