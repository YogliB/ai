#!/bin/sh
# Syncs the canonical root skills/ and rules/ into the Devin plugin, which must
# be self-contained: git-subdir installs fetch only plugins/snail/, so a
# symlink to ../../skills never resolves there.
set -eu

ROOT=$(git rev-parse --show-toplevel)
SRC="$ROOT/skills"
SRC_RULES="$ROOT/rules"
SUBDIRS="skills rules"

sync_all() {
	DST="$1"

	for sub in $SUBDIRS; do
		rm -rf "$DST/$sub"
		mkdir -p "$DST/$sub"
	done

	count=0
	for d in "$SRC"/snail-*; do
		[ -d "$d" ] || continue
		cp -R "$d" "$DST/skills/"
		count=$((count + 1))
	done

	rcount=0
	for f in "$SRC_RULES"/*.md; do
		[ -f "$f" ] || continue
		cp "$f" "$DST/rules/"
		rcount=$((rcount + 1))
	done
}

if [ "${1:-}" = "--check" ]; then
	TMP=$(mktemp -d)
	trap 'rm -rf "$TMP"' EXIT
	sync_all "$TMP"
	status=0
	for sub in $SUBDIRS; do
		if ! diff -r "$TMP/$sub" "$ROOT/plugins/snail/$sub" >/dev/null 2>&1; then
			echo "sync-devin-plugin: plugins/snail/$sub is out of sync with $sub/:" >&2
			diff -r "$TMP/$sub" "$ROOT/plugins/snail/$sub" 2>&1 | head -20 >&2
			status=1
		fi
	done
	if [ "$status" -eq 0 ]; then
		echo "sync-devin-plugin: plugin copies are in sync"
	fi
	exit "$status"
fi

sync_all "$ROOT/plugins/snail"
echo "sync-devin-plugin: synced $count skills, $rcount rules to plugins/snail/"
