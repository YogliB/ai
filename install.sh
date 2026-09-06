#!/usr/bin/env sh
# Install the ai workflow skills and Cursor rules into a project.
# install.sh exists only for Cursor, until Cursor gets a proper plugin system.
#
# Usage:
#   ./install.sh /path/to/repo      # install skills and Cursor rules into a target project
#
# Other agents have their own install paths:
#   Claude Code:    claude plugin marketplace add YogliB/ai && claude plugin install slash-kit@ai
#   Devin:          devin plugins install YogliB/ai#plugins/slash-kit
#   Global skills:  npx skills add YogliB/ai -g

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

install_project() {
	TARGET="$1"
	if [ ! -d "$TARGET" ]; then
		echo "Error: $TARGET is not a directory" >&2
		exit 1
	fi

	echo "Installing ai workflow into $TARGET"

	# Skills
	mkdir -p "$TARGET/.agents/skills"
	remove_legacy_skills "$TARGET/.agents/skills"
	for skill_dir in "$REPO_ROOT"/skills/*; do
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

	# Runbook
	cp "$REPO_ROOT/RUNBOOK.md" "$TARGET/RUNBOOK.md"

	# Flow runbooks README
	mkdir -p "$TARGET/.agents/flows"
	cp "$REPO_ROOT/.agents/flows/README.md" "$TARGET/.agents/flows/README.md"

	echo "Done. Skills and Cursor rules installed in $TARGET."
}

if [ $# -ne 1 ]; then
	echo "Usage: $0 /path/to/repo" >&2
	exit 1
fi

install_project "$1"
