#!/usr/bin/env sh
# Remove the local snail Cursor plugin.
#
# Usage:
#   ./scripts/uninstall.sh    # remove the Cursor plugin for this user
#
# Other agents have their own removal paths:
#   Claude Code:    claude plugin uninstall snail@snail && claude plugin marketplace remove snail
#   Devin:          devin plugins remove snail
#   Global skills:  npx skills remove -g

set -e

PLUGIN_HOME="$HOME/.cursor/plugins/local/snail"

rm -rf "$PLUGIN_HOME"
echo "Removed Cursor plugin from $PLUGIN_HOME"
