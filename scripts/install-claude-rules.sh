#!/bin/sh
# Install slashkit rules for Claude Code: copies rules/*.md (frontmatter
# stripped) into ~/.claude/slashkit/ and links them from ~/.claude/CLAUDE.md
# via @imports, which also reaches subagent context.
# Undo: rm -rf ~/.claude/slashkit and remove the @slashkit/ lines from CLAUDE.md.
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEST="$HOME/.claude/slashkit"
MEMORY="$HOME/.claude/CLAUDE.md"

mkdir -p "$DEST"

for f in "$REPO_ROOT"/rules/*.md; do
	awk 'NR == 1 && $0 == "---" { skip = 1; next } skip && $0 == "---" { skip = 0; next } !skip' "$f" \
		> "$DEST/$(basename "$f")"
done

touch "$MEMORY"
for f in "$DEST"/*.md; do
	line="@slashkit/$(basename "$f")"
	grep -qxF "$line" "$MEMORY" || echo "$line" >> "$MEMORY"
done

echo "Installed rules into $DEST and linked them from $MEMORY"
