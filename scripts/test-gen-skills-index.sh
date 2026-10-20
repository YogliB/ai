#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() {
	echo "test-gen-skills-index: FAIL: $1" >&2
	exit 1
}

git init -q .
mkdir -p scripts skills/sk-a skills/sk-b rules
cp "$REPO_ROOT/scripts/gen-skills-index.sh" scripts/
printf -- '---\nname: sk-a\ndescription: Does A. Use when A.\n---\n' > skills/sk-a/SKILL.md
printf -- '---\nname: sk-b\ndescription: Does B.\n---\n' > skills/sk-b/SKILL.md
printf 'head\n\n<!-- skills:start -->\nstale\n<!-- skills:end -->\n\ntail\n' > rules/slashkit.md

if sh scripts/gen-skills-index.sh --check >/dev/null 2>&1; then
	fail "--check passes on a stale list"
fi

sh scripts/gen-skills-index.sh >/dev/null
sh scripts/gen-skills-index.sh --check >/dev/null || fail "--check fails right after generating"
grep -qF '`sk-a` — Does A' rules/slashkit.md || fail "sk-a missing"
grep -qF '`sk-b` — Does B' rules/slashkit.md || fail "sk-b missing"
grep -qx 'head' rules/slashkit.md || fail "text before the markers changed"
grep -qx 'tail' rules/slashkit.md || fail "text after the markers changed"

mkdir skills/sk-c
printf -- '---\nname: sk-c\ndescription: Does C.\n---\n' > skills/sk-c/SKILL.md
if sh scripts/gen-skills-index.sh --check >/dev/null 2>&1; then
	fail "--check misses a new skill"
fi

sh scripts/gen-skills-index.sh >/dev/null
rm -r skills/sk-b
if sh scripts/gen-skills-index.sh --check >/dev/null 2>&1; then
	fail "--check misses a removed skill"
fi

printf 'no markers\n' > rules/slashkit.md
if sh scripts/gen-skills-index.sh >/dev/null 2>&1; then
	fail "missing markers are not reported"
fi

printf '<!-- skills:end -->\nmiddle\n<!-- skills:start -->\n' > rules/slashkit.md
if sh scripts/gen-skills-index.sh >/dev/null 2>&1; then
	fail "reversed markers are not reported"
fi
grep -qx 'middle' rules/slashkit.md || fail "reversed markers deleted content"

echo "test-gen-skills-index: all tests passed"
