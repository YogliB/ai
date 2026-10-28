#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
	echo "test-claude-plugin: FAIL: $1" >&2
	exit 1
}

CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-2.1.304}"

npm install -g --prefix "$TMP/npm" --no-fund --no-audit "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" >"$TMP/npm.log" 2>&1
CLAUDE="$TMP/npm/bin/claude"
[ -x "$CLAUDE" ] || fail "claude-code $CLAUDE_CODE_VERSION install failed:
$(cat "$TMP/npm.log")"

export HOME="$TMP/home"
mkdir -p "$HOME"
unset CLAUDE_CONFIG_DIR

"$CLAUDE" plugin marketplace add "$REPO_ROOT" >/dev/null || fail "marketplace add failed"
"$CLAUDE" plugin install snail@snail >/dev/null || fail "plugin install failed"

DETAILS=$("$CLAUDE" plugin details snail@snail) || fail "plugin details failed"
echo "$DETAILS" | grep -q 'Skills (12)' || fail "expected 12 skills:
$DETAILS"

echo "test-claude-plugin: all tests passed"
