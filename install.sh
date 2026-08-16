#!/usr/bin/env sh
# Install the ai workflow skills, slash-kit plugin, and rules.
#
# Usage:
#   ./install.sh                    # install skills and the Claude Code plugin globally
#   ./install.sh /path/to/repo      # install rules and skills into a target project

set -e

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

LEGACY_SKILLS="ai-toolbelt alternatives explore planning pr project-docs review-alternatives review-and-fix review-dont-fix sk-review-dont-fix verify"

remove_legacy_skills() {
	target_dir="$1"
	for skill in $LEGACY_SKILLS; do
		rm -rf "$target_dir/$skill"
	done
}

remove_legacy_rules() {
	target_dir="$1"
	shift
	for rule in "$@"; do
		rm -f "$target_dir/$rule"
	done
}

install_global() {
	echo "Installing ai skills and the slash-kit Claude Code plugin..."

	if ! command -v npx >/dev/null 2>&1; then
		echo "Error: npx is required to install skills. Install Node.js." >&2
		exit 1
	fi

	# Remove old (unprefixed) skill directories from a previous install.
	mkdir -p "$HOME/.agents/skills"
	remove_legacy_skills "$HOME/.agents/skills"

	npx --yes skills add "$REPO_ROOT" -g -a universal -y

	if command -v claude >/dev/null 2>&1; then
		echo "Registering the ai repo as a Claude Code marketplace and installing the slash-kit plugin..."
		claude plugin marketplace add "$REPO_ROOT" --scope user
		claude plugin install slash-kit@ai --scope user
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
	remove_legacy_skills "$TARGET/.agents/skills"
	for skill_dir in "$REPO_ROOT"/.agents/skills/*; do
		if [ -d "$skill_dir" ]; then
			name=$(basename "$skill_dir")
			rm -rf "$TARGET/.agents/skills/$name"
			cp -R "$skill_dir" "$TARGET/.agents/skills/$name"
		fi
	done

	# Cursor rules
	mkdir -p "$TARGET/.cursor/rules"
	remove_legacy_rules "$TARGET/.cursor/rules" ai-conventions.mdc ai-workflow.mdc
	for rule in "$REPO_ROOT"/.cursor/rules/*.mdc; do
		if [ -f "$rule" ]; then
			cp "$rule" "$TARGET/.cursor/rules/"
		fi
	done

	# Claude rules
	mkdir -p "$TARGET/.claude/rules"
	remove_legacy_rules "$TARGET/.claude/rules" conventions.md workflow.md
	for rule in "$REPO_ROOT"/.claude/rules/*.md; do
		if [ -f "$rule" ]; then
			cp "$rule" "$TARGET/.claude/rules/"
		fi
	done

	# Devin rules
	mkdir -p "$TARGET/.devin/rules"
	remove_legacy_rules "$TARGET/.devin/rules" ai-conventions.md ai-workflow.md
	for rule in "$REPO_ROOT"/.devin/rules/*.md; do
		if [ -f "$rule" ]; then
			cp "$rule" "$TARGET/.devin/rules/"
		fi
	done

	# Runbook
	cp "$REPO_ROOT/RUNBOOK.md" "$TARGET/RUNBOOK.md"

	# Flow runbooks README
	mkdir -p "$TARGET/.agents/sk-flows"
	cp "$REPO_ROOT/.agents/sk-flows/README.md" "$TARGET/.agents/sk-flows/README.md"

	# Update or create AGENTS.md
	AGENTS="$TARGET/AGENTS.md"
	if [ -f "$AGENTS" ]; then
		if ! grep -qE "(^## AI rules$|^## AI workflow rules$)" "$AGENTS" 2>/dev/null; then
			{
				echo ""
				echo "---"
				echo ""
				echo "## AI rules"
				echo ""
				echo "@.claude/rules/slashkit.md"
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
| Claude rules | [.claude/rules/slashkit.md](.claude/rules/slashkit.md) |

## AI rules

@.claude/rules/slashkit.md
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
