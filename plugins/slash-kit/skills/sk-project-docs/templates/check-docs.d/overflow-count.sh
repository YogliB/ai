#!/usr/bin/env bash
# overflow-count — a docs/<name>/ dir holding many files means the
# topic outgrew its parent. Warn past 5 files.
set -u
MAX=${DOCS_OVERFLOW_MAX:-5}

[ -d docs ] || exit 0
find docs -mindepth 1 -maxdepth 1 -type d | while read -r d; do
	n=$(find "$d" -name '*.md' | wc -l | tr -d ' ')
	[ "$n" -gt "$MAX" ] && echo "warn $d: $n files > $MAX — topic may want restructuring"
done
exit 0
