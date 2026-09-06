#!/bin/sh
# Syncs the canonical root skills/ into the Devin plugin, which must be
# self-contained: git-subdir installs fetch only plugins/slash-kit/, so a
# symlink to ../../skills never resolves there.
set -eu

ROOT=$(git rev-parse --show-toplevel)
SRC="$ROOT/skills"
DST="$ROOT/plugins/slash-kit/skills"

rm -rf "$DST"
mkdir -p "$DST"

count=0
for d in "$SRC"/sk-*; do
	[ -d "$d" ] || continue
	cp -R "$d" "$DST/"
	count=$((count + 1))
done

echo "sync-devin-plugin: synced $count skills to plugins/slash-kit/skills/"
