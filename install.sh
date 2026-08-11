#!/usr/bin/env sh
# Install the ai workflow plugin.
#
# Usage:
#   ./install.sh                    # install Claude Code plugin globally
#   ./install.sh /path/to/repo      # install rules and skills into a project

set -e

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

install_global() {
  PLUGIN_DIR="$CLAUDE_CONFIG_DIR/plugins/ai"
  echo "Installing Claude Code plugin to $PLUGIN_DIR"
  rm -rf "$PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
  rsync -a \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='logs' \
    --exclude='.serena' \
    --exclude='nub.lock' \
    "$REPO_ROOT"/ "$PLUGIN_DIR/"
  echo "Done. Restart Claude Code to load the plugin."
}

install_project() {
  TARGET="$1"
  if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory" >&2
    exit 1
  fi

  echo "Installing ai workflow into $TARGET"

  # Skills for all agents
  mkdir -p "$TARGET/.agents/skills"
  for skill_dir in "$REPO_ROOT"/.agents/skills/*; do
    if [ -d "$skill_dir" ]; then
      name=$(basename "$skill_dir")
      rm -rf "$TARGET/.agents/skills/$name"
      cp -R "$skill_dir" "$TARGET/.agents/skills/$name"
    fi
  done

  # Cursor rules
  mkdir -p "$TARGET/.cursor/rules"
  for rule in "$REPO_ROOT"/.cursor/rules/*.mdc; do
    if [ -f "$rule" ]; then
      cp "$rule" "$TARGET/.cursor/rules/"
    fi
  done

  # Claude rules
  mkdir -p "$TARGET/.claude/rules"
  for rule in "$REPO_ROOT"/.claude/rules/*.md; do
    if [ -f "$rule" ]; then
      cp "$rule" "$TARGET/.claude/rules/"
    fi
  done

  # Runbook
  cp "$REPO_ROOT/RUNBOOK.md" "$TARGET/RUNBOOK.md"

  # Plans directory README
  mkdir -p "$TARGET/.agents/plans"
  cp "$REPO_ROOT/.agents/plans/README.md" "$TARGET/.agents/plans/README.md"

  # Update or create AGENTS.md
  AGENTS="$TARGET/AGENTS.md"
  if [ -f "$AGENTS" ]; then
    if ! grep -q "ai workflow" "$AGENTS" 2>/dev/null; then
      {
        echo ""
        echo "---"
        echo ""
        echo "## AI workflow rules"
        echo ""
        echo "@.claude/rules/conventions.md"
        echo "@.claude/rules/workflow.md"
      } >> "$AGENTS"
    fi
  else
    cat > "$AGENTS" <<'EOF'
# AGENTS.md

@.claude/rules/conventions.md
@.claude/rules/workflow.md
@RUNBOOK.md
EOF
  fi

  # Update or create CLAUDE.md
  CLAUDE="$TARGET/CLAUDE.md"
  if [ -f "$CLAUDE" ]; then
    if ! grep -q "ai workflow" "$CLAUDE" 2>/dev/null; then
      {
        echo ""
        echo "---"
        echo ""
        echo "## AI workflow rules"
        echo ""
        echo "@.claude/rules/conventions.md"
        echo "@.claude/rules/workflow.md"
        echo "@RUNBOOK.md"
      } >> "$CLAUDE"
    fi
  else
    cat > "$CLAUDE" <<'EOF'
# CLAUDE.md

@.claude/rules/conventions.md
@.claude/rules/workflow.md
@RUNBOOK.md
EOF
  fi

  echo "Done. Rules, skills, and runbook installed in $TARGET."
}

case "${1:-}" in
  "")
    install_global
    ;;
  --global)
    install_global
    ;;
  *)
    install_project "$1"
    ;;
esac
