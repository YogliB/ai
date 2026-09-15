#!/usr/bin/env bash
# overflow-parent — every docs/<name>/ dir needs a parent docs/<NAME>.md.
# A dir without a parent doc is shadow architecture.
set -u

[ -d docs ] || exit 0
find docs -mindepth 1 -maxdepth 1 -type d | while read -r d; do
	name=${d#docs/}
	upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
	[ -f "docs/$upper.md" ] || echo "FAIL $d: no parent docs/$upper.md"
done
exit 0
