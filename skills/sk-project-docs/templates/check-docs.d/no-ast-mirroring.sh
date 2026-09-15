#!/usr/bin/env bash
# no-ast-mirroring — markdown tables whose cells are code identifiers
# (env vars, dotted names, paths) rot the moment code changes.
# Warn on any table with 3+ consecutive identifier rows; the fix is a
# link to the source of truth, not a mirrored table.
set -u

find . -name node_modules -prune -o -name '*.md' -print | while read -r f; do
	awk '
		/^\|/ {
			line = $0
			sub(/^[ \t]*\|[ \t]*/, "", line)
			cell = line; sub(/\|.*/, "", cell)
			gsub(/[` \t]/, "", cell)
			if (cell ~ /^[A-Z_][A-Z0-9_]{2,}$/ ||
			    cell ~ /^[a-z_][a-z0-9_]*(\.[a-z0-9_]+)+$/ ||
			    cell ~ /^\.?[a-zA-Z0-9_-]+\/[a-zA-Z0-9_\/.-]+$/) {
				n++
				if (n == 3) print FILENAME ":" NR ": table of code identifiers — link the source of truth instead"
			} else n = 0
			next
		}
		{ n = 0 }
	' "$f"
done
exit 0
