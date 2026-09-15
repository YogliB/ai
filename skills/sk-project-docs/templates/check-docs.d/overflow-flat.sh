#!/usr/bin/env bash
# overflow-flat — docs/<name>/ stays flat: *.md only, one level.
# Nested dirs are sprawl recursion.
set -u

[ -d docs ] || exit 0
find docs -mindepth 2 -type d | while read -r d; do
	echo "FAIL $d: nested dir — docs/<name>/ must stay flat"
done
find docs -mindepth 2 -type f ! -name '*.md' | while read -r f; do
	echo "warn $f: non-markdown file under docs/<name>/"
done
exit 0
