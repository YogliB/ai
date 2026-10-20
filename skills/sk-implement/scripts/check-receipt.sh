#!/bin/sh
# Validates a receipt written by run-with-receipt.sh: it must be a passing
# receipt, and with --head it must have been recorded on the current commit.
set -eu

usage() {
	echo "usage: check-receipt.sh <receipt> [--head]" >&2
	exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
RECEIPT=$1
CHECK_HEAD=0
if [ $# -eq 2 ]; then
	[ "$2" = "--head" ] || usage
	CHECK_HEAD=1
fi

[ -f "$RECEIPT" ] || {
	echo "check-receipt: no such file: $RECEIPT" >&2
	exit 1
}

fail() {
	echo "check-receipt: $RECEIPT: $1" >&2
	exit 1
}

get() {
	sed -n "s/^$1: //p" "$RECEIPT" | head -1
}

[ "$(get receipt-version)" = "1" ] || fail "missing or unsupported receipt-version"
[ -n "$(get command)" ] || fail "missing command"
CODE=$(get exit-code)
[ -n "$CODE" ] || fail "missing exit-code"
[ "$(get result)" = "pass" ] || fail "result is not pass"
[ "$CODE" = "0" ] || fail "exit-code is $CODE, not 0"
[ -n "$(get started-at)" ] || fail "missing started-at"
[ -n "$(get finished-at)" ] || fail "missing finished-at"
HEAD=$(get git-head)
[ -n "$HEAD" ] || fail "missing git-head"
grep -q '^--- output' "$RECEIPT" || fail "missing output section"

if [ "$CHECK_HEAD" -eq 1 ]; then
	CURRENT=$(git rev-parse HEAD)
	[ "$HEAD" = "$CURRENT" ] || fail "receipt was recorded on $HEAD, current HEAD is $CURRENT"
fi

echo "check-receipt: $RECEIPT is a valid passing receipt"
