#!/usr/bin/env bash
# overflow-orphan — every docs/<name>/*.md must be linked from its
# parent docs/<NAME>.md. An unlinked child is a shadow doc.
set -u

[ -d docs ] || exit 0
find docs -mindepth 1 -maxdepth 1 -type d | while read -r d; do
	name=${d#docs/}
	upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
	parent="docs/$upper.md"
	[ -f "$parent" ] || continue # overflow-parent reports the missing parent
	find "$d" -name '*.md' | while read -r f; do
		grep -qE "\]\([^)]*$(basename "$f")" "$parent" ||
			echo "FAIL $f: not linked from $parent"
	done
done
exit 0
