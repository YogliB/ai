#!/bin/sh
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEST="$HOME/.claude/snail"
MEMORY="$HOME/.claude/CLAUDE.md"

mkdir -p "$DEST"

for f in "$REPO_ROOT"/rules/*.md; do
	awk 'NR == 1 && $0 == "---" { skip = 1; next } skip && $0 == "---" { skip = 0; next } !skip' "$f" \
		> "$DEST/$(basename "$f")"
done

touch "$MEMORY"
if [ -s "$MEMORY" ] && [ -n "$(tail -c 1 "$MEMORY")" ]; then
	printf '\n' >> "$MEMORY"
fi
for f in "$DEST"/*.md; do
	line="@snail/$(basename "$f")"
	grep -qxF "$line" "$MEMORY" || echo "$line" >> "$MEMORY"
done

echo "Installed rules into $DEST and linked them from $MEMORY"
