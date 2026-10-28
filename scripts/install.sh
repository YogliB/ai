#!/usr/bin/env sh
# Install snail as a local Cursor plugin (repo root is the plugin).
#
# Usage:
#   ./scripts/install.sh    # install the Cursor plugin for this user
#
# Other agents have their own install paths:
#   Claude Code:    claude plugin marketplace add YogliB/snail && claude plugin install snail@snail
#   Devin:          devin plugins install YogliB/snail#plugins/snail
#   Global skills:  npx skills add YogliB/snail -g

set -e

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PLUGIN_HOME="$HOME/.cursor/plugins/local/snail"

echo "Installing snail Cursor plugin into $PLUGIN_HOME"

rm -rf "$PLUGIN_HOME"
mkdir -p "$PLUGIN_HOME"
for part in .cursor-plugin skills rules; do
	if [ -e "$REPO_ROOT/$part" ]; then
		cp -R "$REPO_ROOT/$part" "$PLUGIN_HOME/$part"
	fi
done

echo "Done. Restart Cursor or run 'Developer: Reload Window' to load the plugin."
