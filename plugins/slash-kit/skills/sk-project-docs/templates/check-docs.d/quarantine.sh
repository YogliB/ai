#!/usr/bin/env bash
# quarantine — docs/ may only hold the standard tree files.
# Anything else at top level: merge into a standard doc or move
# under docs/<name>/ where <NAME>.md exists.
set -u
STANDARD=" ARCHITECTURE.md USAGE.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md TROUBLESHOOTING.md "

[ -d docs ] || exit 0
find docs -mindepth 1 -maxdepth 1 -name '*.md' | while read -r f; do
	base=${f#docs/}
	case "$STANDARD" in
	*" $base "*) ;;
	*) echo "FAIL $f: not in standard docs tree — merge or move under docs/<name>/" ;;
	esac
done
exit 0
