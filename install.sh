#!/usr/bin/env sh
# Install the ai workflow skills, plugin and rules.
#
# Usage:
#   ./install.sh                    # install skills and the Claude Code plugin globally
#   ./install.sh /path/to/repo      # install rules and skills into a target project

set -e

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

install_global() {
	echo "Installing ai skills and Claude Code plugin..."

	if ! command -v npx >/dev/null 2>&1; then
		echo "Error: npx is required to install skills. Install Node.js." >&2
		exit 1
	fi

	npx --yes skills add "$REPO_ROOT" -g -a universal -y

	if command -v claude >/dev/null 2>&1; then
		echo "Registering ai repo as a Claude Code marketplace and installing the plugin..."
		claude plugin marketplace add "$REPO_ROOT" --scope user
		claude plugin install ai@ai --scope user
	else
		echo "Claude Code CLI not found; skipping Claude plugin installation."
	fi

	echo "Done. Restart any running agent sessions to pick up new skills/rules."
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

	# Devin rules
	mkdir -p "$TARGET/.devin/rules"
	for rule in "$REPO_ROOT"/.devin/rules/*.md; do
		if [ -f "$rule" ]; then
			cp "$rule" "$TARGET/.devin/rules/"
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

Agent-facing entry point.

## Quick links

| Topic | Where to look |
|---|---|
| Runbook | [RUNBOOK.md](RUNBOOK.md) |
| Skills | [.agents/skills/](.agents/skills/) |
| Claude rules | [.claude/rules/conventions.md](.claude/rules/conventions.md), [.claude/rules/workflow.md](.claude/rules/workflow.md) |

## AI workflow rules

@.claude/rules/conventions.md
@.claude/rules/workflow.md
@RUNBOOK.md
EOF
	fi

	# Create CLAUDE.md as a symlink to AGENTS.md, or fall back to an include.
	CLAUDE="$TARGET/CLAUDE.md"
	if [ ! -e "$CLAUDE" ] && [ ! -L "$CLAUDE" ]; then
		if ln -s AGENTS.md "$CLAUDE" 2>/dev/null && [ -L "$CLAUDE" ]; then
			:
		else
			rm -f "$CLAUDE"
			cat > "$CLAUDE" <<'EOF'
@AGENTS.md
EOF
		fi
	fi

	echo "Done. Rules, skills, and runbook installed in $TARGET."
}

case "${1:-}" in
	"" | --global)
		install_global
		;;
	*)
		install_project "$1"
		;;
esac
