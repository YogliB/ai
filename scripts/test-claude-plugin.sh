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

npm install -g --prefix "$TMP/npm" "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" >/dev/null 2>&1
CLAUDE="$TMP/npm/bin/claude"
[ -x "$CLAUDE" ] || fail "claude-code $CLAUDE_CODE_VERSION install failed"

export HOME="$TMP/home"
mkdir -p "$HOME"

"$CLAUDE" plugin marketplace add "$REPO_ROOT" >/dev/null || fail "marketplace add failed"
"$CLAUDE" plugin install slash-kit@ai >/dev/null || fail "plugin install failed"

DETAILS=$("$CLAUDE" plugin details slash-kit@ai) || fail "plugin details failed"
echo "$DETAILS" | grep -q 'Skills (13)' || fail "expected 13 skills:
$DETAILS"
echo "$DETAILS" | grep -q 'Hooks (2)' || fail "expected 2 hooks:
$DETAILS"

set -- "$HOME"/.claude/plugins/cache/ai/slash-kit/*/hooks/inject-rules.py
HOOK="$1"
[ -f "$HOOK" ] || fail "inject-rules.py missing from the installed plugin"

OUT=$(echo '{"hook_event_name":"SessionStart"}' | python3 "$HOOK")
echo "$OUT" | grep -q 'SLASHKIT RULES' || fail "hook output missing the rules: $OUT"
python3 "$HOOK" --self-check >/dev/null || fail "inject-rules self-check failed"

echo "test-claude-plugin: all tests passed"
