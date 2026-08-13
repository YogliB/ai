#!/usr/bin/env sh
# Uninstall the ai workflow skills, slash-kit plugin, and rules.
#
# Usage:
#   ./uninstall.sh                    # uninstall skills and plugin globally
#   ./uninstall.sh /path/to/repo      # uninstall rules and skills from a target project

set -e

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

resolve_dir() {
	CDPATH= cd -- "$1" >/dev/null 2>&1 && pwd
}

remove_if_unchanged() {
	src="$1"
	dest="$2"
	if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
		rm -f "$dest"
	fi
}

generated_agents_tmp() {
	tmp=$(mktemp)
	cat > "$tmp" <<'EOF'
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
	printf '%s\n' "$tmp"
}

generated_claude_tmp() {
	tmp=$(mktemp)
	printf '@AGENTS.md\n' > "$tmp"
	printf '%s\n' "$tmp"
}

remove_agents_workflow_block() {
	file="$1"
	tmp=$(mktemp)
	awk '
		{ lines[NR] = $0 }
		END {
			if (NR >= 7 &&
			    lines[NR-6] == "" &&
			    lines[NR-5] == "---" &&
			    lines[NR-4] == "" &&
			    lines[NR-3] == "## AI workflow rules" &&
			    lines[NR-2] == "" &&
			    lines[NR-1] == "@.claude/rules/conventions.md" &&
			    lines[NR]   == "@.claude/rules/workflow.md") {
				for (i = 1; i <= NR - 7; i++) print lines[i]
			} else {
				for (i = 1; i <= NR; i++) print lines[i]
			}
		}
	' "$file" > "$tmp"
	if [ ! -s "$tmp" ]; then
		rm -f "$file" "$tmp"
	else
		mv "$tmp" "$file"
	fi
}

uninstall_global() {
	echo "Uninstalling ai skills and the slash-kit Claude Code plugin..."

	# Collect the skill names defined in this repo.
	set --
	for skill_dir in "$REPO_ROOT"/.agents/skills/*; do
		if [ -d "$skill_dir" ]; then
			set -- "$@" "$(basename "$skill_dir")"
		fi
	done

	if [ $# -gt 0 ]; then
		if command -v npx >/dev/null 2>&1; then
			npx --yes skills remove -g -a universal -y "$@"
		else
			echo "npx not found; removing skill directories manually." >&2
			for skill in "$@"; do
				rm -rf "$HOME/.agents/skills/$skill"
			done
		fi
	fi

	if command -v claude >/dev/null 2>&1; then
		echo "Removing the slash-kit Claude Code plugin and marketplace..."
		claude plugin uninstall slash-kit@ai --scope user -y || true
		claude plugin marketplace remove ai --scope user || true
	else
		echo "Claude Code CLI not found; skipping Claude plugin removal."
	fi

	echo "Done."
}

uninstall_project() {
	target_raw="$1"
	TARGET=$(resolve_dir "$target_raw") || {
		echo "Error: $target_raw is not a directory" >&2
		exit 1
	}

	if [ "$TARGET" = "$REPO_ROOT" ]; then
		echo "Error: cannot uninstall from the ai repo itself" >&2
		exit 1
	fi

	echo "Uninstalling ai workflow from $TARGET"

	# Skills
	for skill_dir in "$REPO_ROOT"/.agents/skills/*; do
		if [ -d "$skill_dir" ]; then
			name=$(basename "$skill_dir")
			rm -rf "$TARGET/.agents/skills/$name"
		fi
	done

	# Cursor rules
	for rule in "$REPO_ROOT"/.cursor/rules/*.mdc; do
		if [ -f "$rule" ]; then
			rm -f "$TARGET/.cursor/rules/$(basename "$rule")"
		fi
	done

	# Claude rules
	for rule in "$REPO_ROOT"/.claude/rules/*.md; do
		if [ -f "$rule" ]; then
			rm -f "$TARGET/.claude/rules/$(basename "$rule")"
		fi
	done

	# Devin rules
	for rule in "$REPO_ROOT"/.devin/rules/*.md; do
		if [ -f "$rule" ]; then
			rm -f "$TARGET/.devin/rules/$(basename "$rule")"
		fi
	done

	# Runbook and plans README if unchanged
	remove_if_unchanged "$REPO_ROOT/RUNBOOK.md" "$TARGET/RUNBOOK.md"
	remove_if_unchanged "$REPO_ROOT/.agents/plans/README.md" "$TARGET/.agents/plans/README.md"

	# AGENTS.md: remove if it matches the generated version, otherwise trim the
	# appended workflow section if present.
	if [ -f "$TARGET/AGENTS.md" ]; then
		generated_agents=$(generated_agents_tmp)
		if cmp -s "$generated_agents" "$TARGET/AGENTS.md"; then
			rm -f "$TARGET/AGENTS.md"
		else
			remove_agents_workflow_block "$TARGET/AGENTS.md"
		fi
		rm -f "$generated_agents"
	fi

	# CLAUDE.md: remove a generated symlink that is now broken, or the generated
	# one-line fallback if AGENTS.md no longer exists.
	if [ -L "$TARGET/CLAUDE.md" ]; then
		if [ ! -e "$TARGET/AGENTS.md" ]; then
			rm -f "$TARGET/CLAUDE.md"
		fi
	elif [ -f "$TARGET/CLAUDE.md" ]; then
		generated_claude=$(generated_claude_tmp)
		if cmp -s "$generated_claude" "$TARGET/CLAUDE.md" && [ ! -e "$TARGET/AGENTS.md" ]; then
			rm -f "$TARGET/CLAUDE.md"
		fi
		rm -f "$generated_claude"
	fi

	# Clean up empty directories.
	rmdir "$TARGET/.agents/skills" 2>/dev/null || true
	rmdir "$TARGET/.agents/plans" 2>/dev/null || true
	rmdir "$TARGET/.agents" 2>/dev/null || true
	rmdir "$TARGET/.cursor/rules" 2>/dev/null || true
	rmdir "$TARGET/.cursor" 2>/dev/null || true
	rmdir "$TARGET/.claude/rules" 2>/dev/null || true
	rmdir "$TARGET/.claude" 2>/dev/null || true
	rmdir "$TARGET/.devin/rules" 2>/dev/null || true
	rmdir "$TARGET/.devin" 2>/dev/null || true

	echo "Done."
}

case "${1:-}" in
	"" | --global)
		uninstall_global
		;;
	*)
		uninstall_project "$1"
		;;
esac
