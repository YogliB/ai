#!/usr/bin/env sh
# Install slash-kit as a local Cursor plugin (repo root is the plugin).
#
# Usage:
#   ./scripts/install.sh                  # install the Cursor plugin for this user
#   ./scripts/install.sh /path/to/repo    # also seed RUNBOOK.md and .agents/flows into the project
#
# Other agents have their own install paths:
#   Claude Code:    claude plugin marketplace add YogliB/ai && claude plugin install slash-kit@ai
#   Devin:          devin plugins install YogliB/ai#plugins/slash-kit
#   Global skills:  npx skills add YogliB/ai -g

set -e

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PLUGIN_HOME="$HOME/.cursor/plugins/local/slash-kit"

echo "Installing slash-kit Cursor plugin into $PLUGIN_HOME"

rm -rf "$PLUGIN_HOME"
mkdir -p "$PLUGIN_HOME"
for part in .cursor-plugin skills rules; do
	if [ -e "$REPO_ROOT/$part" ]; then
		cp -R "$REPO_ROOT/$part" "$PLUGIN_HOME/$part"
	fi
done

echo "Done. Restart Cursor or run 'Developer: Reload Window' to load the plugin."

if [ $# -gt 0 ]; then
	TARGET="$1"
	if [ ! -d "$TARGET" ]; then
		echo "Error: $TARGET is not a directory" >&2
		exit 1
	fi
	mkdir -p "$TARGET/.agents/flows"
	cp "$REPO_ROOT/RUNBOOK.md" "$TARGET/RUNBOOK.md"
	cp "$REPO_ROOT/.agents/flows/README.md" "$TARGET/.agents/flows/README.md"
	echo "Seeded RUNBOOK.md and .agents/flows/README.md in $TARGET."
fi
