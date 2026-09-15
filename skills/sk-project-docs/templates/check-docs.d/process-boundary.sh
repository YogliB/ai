#!/usr/bin/env bash
# process-boundary — CONTRIBUTING/USAGE document process, not
# architecture. An architecture-style heading there means rules are
# hiding in a process doc; move them to docs/ARCHITECTURE.md or
# docs/architecture/.
set -u

for f in CONTRIBUTING.md docs/CONTRIBUTING.md docs/USAGE.md; do
	[ -f "$f" ] || continue
	grep -qiE '^#{1,4}[^#].*(architect|invariant|data ?flow|system design)' "$f" &&
		echo "warn $f: architecture-style heading in process doc — move to docs/ARCHITECTURE.md or docs/architecture/"
done
exit 0
