#!/usr/bin/env bash
# line-budget — core docs must stay under DOCS_BUDGET lines (default 300).
# Over-budget core doc = content belongs in docs/<name>/ overflow.
# FAIL on ARCHITECTURE/CONTRIBUTING, warn on everything else.
set -u
BUDGET=${DOCS_BUDGET:-300}

for f in docs/*.md docs/*/*.md; do
	[ -f "$f" ] || continue
	n=$(wc -l <"$f" | tr -d ' ')
	case "$f" in
	docs/ARCHITECTURE.md | docs/CONTRIBUTING.md)
		[ "$n" -gt "$BUDGET" ] && echo "FAIL $f: $n lines > $BUDGET budget — split deep content into docs/<name>/ overflow"
		;;
	*)
		[ "$n" -gt "$BUDGET" ] && echo "warn $f: $n lines > $BUDGET budget"
		;;
	esac
done
exit 0
