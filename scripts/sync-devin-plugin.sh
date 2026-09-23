#!/bin/sh
# Syncs the canonical root skills/ and rules/ into the Devin plugin, which must
# be self-contained: git-subdir installs fetch only plugins/slash-kit/, so a
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

SRC_RULES="$ROOT/rules"
DST_RULES="$ROOT/plugins/slash-kit/rules"

rm -rf "$DST_RULES"
mkdir -p "$DST_RULES"

rcount=0
for f in "$SRC_RULES"/*.md; do
	[ -f "$f" ] || continue
	cp "$f" "$DST_RULES/"
	rcount=$((rcount + 1))
done

echo "sync-devin-plugin: synced $rcount rules to plugins/slash-kit/rules/"

SRC_HOOKS="$ROOT/hooks"
DST_HOOKS="$ROOT/plugins/slash-kit/hooks"

rm -rf "$DST_HOOKS"
mkdir -p "$DST_HOOKS"

hcount=0
for f in "$SRC_HOOKS"/*.py; do
	[ -f "$f" ] || continue
	cp "$f" "$DST_HOOKS/"
	hcount=$((hcount + 1))
done

echo "sync-devin-plugin: synced $hcount hook scripts to plugins/slash-kit/hooks/"
