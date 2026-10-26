#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() {
	echo "test-sync-devin-plugin: FAIL: $1" >&2
	exit 1
}

git init -q .
git config user.email test@example.com
git config user.name Test
mkdir -p scripts skills/sk-demo rules
cp "$REPO_ROOT/scripts/sync-devin-plugin.sh" scripts/
echo "# demo skill" > skills/sk-demo/SKILL.md
echo "demo rule" > rules/demo.md

sh scripts/sync-devin-plugin.sh >/dev/null
sh scripts/sync-devin-plugin.sh --check >/dev/null || fail "--check fails on freshly synced copies"

git add -A
git commit -qm init

for path in skills/sk-demo/SKILL.md rules/demo.md; do
	git checkout -q -- .
	echo "edited" > "$path"
	if sh scripts/sync-devin-plugin.sh --check >/dev/null 2>&1; then
		fail "--check misses drift in $path"
	fi
done

git checkout -q -- .
rm skills/sk-demo/SKILL.md
if sh scripts/sync-devin-plugin.sh --check >/dev/null 2>&1; then
	fail "--check misses deleted canonical file skills/sk-demo/SKILL.md"
fi

git checkout -q -- .
echo stray > plugins/slash-kit/rules/stray.md
if sh scripts/sync-devin-plugin.sh --check >/dev/null 2>&1; then
	fail "--check misses stray file plugins/slash-kit/rules/stray.md"
fi
echo "edited rule" > rules/demo.md
mkdir -p skills/sk-new
echo "# new skill" > skills/sk-new/SKILL.md
sh scripts/sync-devin-plugin.sh >/dev/null
grep '^git add plugins/slash-kit' "$REPO_ROOT/.husky/pre-commit" | while IFS= read -r line; do
	eval "$line"
done
UNSTAGED=$(git status --porcelain -- plugins/slash-kit | grep -E '^(.[^ ]|\?\?)' || true)
[ -z "$UNSTAGED" ] || fail "pre-commit staging leaves synced files unstaged or untracked: $UNSTAGED"

echo "test-sync-devin-plugin: all tests passed"
