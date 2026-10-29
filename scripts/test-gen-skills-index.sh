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
mkdir -p scripts skills/snail-a skills/snail-b rules
cp "$REPO_ROOT/scripts/gen-skills-index.sh" scripts/
printf -- '---\nname: snail-a\ndescription: Does A. Use when A.\n---\n' > skills/snail-a/SKILL.md
printf -- '---\nname: snail-b\ndescription: Does B.\n---\n' > skills/snail-b/SKILL.md
printf 'head\n\n<!-- skills:start -->\nstale\n<!-- skills:end -->\n\ntail\n' > rules/snail.md

if sh scripts/gen-skills-index.sh --check >/dev/null 2>&1; then
	fail "--check passes on a stale list"
fi

sh scripts/gen-skills-index.sh >/dev/null
sh scripts/gen-skills-index.sh --check >/dev/null || fail "--check fails right after generating"
grep -qF '`snail-a` — Does A' rules/snail.md || fail "snail-a missing"
grep -qF '`snail-b` — Does B' rules/snail.md || fail "snail-b missing"
grep -qx 'head' rules/snail.md || fail "text before the markers changed"
grep -qx 'tail' rules/snail.md || fail "text after the markers changed"

mkdir skills/snail-c
printf -- '---\nname: snail-c\ndescription: Does C.\n---\n' > skills/snail-c/SKILL.md
if sh scripts/gen-skills-index.sh --check >/dev/null 2>&1; then
	fail "--check misses a new skill"
fi

sh scripts/gen-skills-index.sh >/dev/null
rm -r skills/snail-b
if sh scripts/gen-skills-index.sh --check >/dev/null 2>&1; then
	fail "--check misses a removed skill"
fi

printf 'no markers\n' > rules/snail.md
if sh scripts/gen-skills-index.sh >/dev/null 2>&1; then
	fail "missing markers are not reported"
fi

printf '<!-- skills:end -->\nmiddle\n<!-- skills:start -->\n' > rules/snail.md
if sh scripts/gen-skills-index.sh >/dev/null 2>&1; then
	fail "reversed markers are not reported"
fi
grep -qx 'middle' rules/snail.md || fail "reversed markers deleted content"

echo "test-gen-skills-index: all tests passed"
