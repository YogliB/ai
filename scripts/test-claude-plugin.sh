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
"$CLAUDE" plugin install slash-kit@ai >/dev/null || fail "plugin install failed"

DETAILS=$("$CLAUDE" plugin details slash-kit@ai) || fail "plugin details failed"
echo "$DETAILS" | grep -q 'Skills (12)' || fail "expected 12 skills:
$DETAILS"
echo "$DETAILS" | grep -q 'Hooks (2)' || fail "expected 2 hooks:
$DETAILS"

set -- "$HOME"/.claude/plugins/cache/ai/slash-kit/*/hooks/inject-rules.py
HOOK="$1"
[ -f "$HOOK" ] || fail "inject-rules.py missing from the installed plugin"
PLUGIN_DIR=$(dirname "$(dirname "$HOOK")")

COMMAND=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$PLUGIN_DIR/hooks/hooks.json") || fail "could not read the SessionStart command from hooks.json"

SPACE_ROOT="$TMP/dir with space"
mkdir -p "$SPACE_ROOT"
cp -R "$PLUGIN_DIR" "$SPACE_ROOT/slash-kit"

OUT=$(echo '{"hook_event_name":"SessionStart"}' | CLAUDE_PLUGIN_ROOT="$SPACE_ROOT/slash-kit" sh -c "$COMMAND")
echo "$OUT" | grep -q 'SLASHKIT RULES' || fail "hook output missing the rules: $OUT"
python3 "$HOOK" --self-check >/dev/null || fail "inject-rules self-check failed"

echo "test-claude-plugin: all tests passed"
