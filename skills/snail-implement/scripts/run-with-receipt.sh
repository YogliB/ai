#!/bin/sh
set -eu

usage() {
	echo "usage: run-with-receipt.sh <receipts-dir> <label> -- <command...>" >&2
	exit 2
}

[ $# -ge 4 ] || usage
DIR=$1
case $DIR in
	-*) DIR=./$DIR ;;
esac
LABEL=$2
shift 2
[ "${1:-}" = "--" ] || usage
shift
[ $# -ge 1 ] || usage

[ -n "$LABEL" ] || usage

case $LABEL in
	*[!A-Za-z0-9._-]*)
		echo "run-with-receipt: label may only contain letters, digits, dot, dash, underscore: $LABEL" >&2
		exit 2
		;;
esac

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
HEAD=$(git rev-parse HEAD 2>/dev/null || echo none)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)

RECEIPT="$DIR/$STAMP-$LABEL-$$.receipt"
{
	echo "receipt-version: 1"
	echo "label: $LABEL"
	echo "exit-code: $CODE"
	echo "result: $RESULT"
	echo "started-at: $STARTED"
	echo "finished-at: $ENDED"
	echo "duration-seconds: $((END_S - START_S))"
	echo "git-head: $HEAD"
	echo "git-branch: $BRANCH"
	echo "cwd: $(pwd)"
	printf 'command:'
	for a in "$@"; do printf ' %s' "$a"; done
	echo
	echo
	echo "--- output (last 30 lines) ---"
	tail -n 30 "$OUT"
} >"$RECEIPT"

echo "run-with-receipt: receipt written to $RECEIPT" >&2
exit "$CODE"
