#!/usr/bin/env sh
# Remove the local slash-kit Cursor plugin.
#
# Usage:
#   ./scripts/uninstall.sh    # remove the Cursor plugin for this user
#
# Other agents have their own removal paths:
#   Claude Code:    claude plugin uninstall slash-kit@ai && claude plugin marketplace remove ai
#   Devin:          devin plugins remove slash-kit
#   Global skills:  npx skills remove -g

set -e

PLUGIN_HOME="$HOME/.cursor/plugins/local/slash-kit"

rm -rf "$PLUGIN_HOME"
echo "Removed Cursor plugin from $PLUGIN_HOME"
