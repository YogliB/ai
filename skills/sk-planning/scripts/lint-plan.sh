#!/bin/sh
# Validates a plan's structure against the sk-planning templates: required
# sections present and in order, Files right after Goal, TODO depth at
# most 2, Complexity Check filled. See docs/GATES.md.
set -eu

usage() {
	echo "usage: lint-plan.sh <plan-file> [--masterplan] [--allow-draft]" >&2
	exit 2
}

[ $# -ge 1 ] || usage
PLAN=$1
shift
MODE=plan
ALLOW_DRAFT=0
for a in "$@"; do
	case $a in
		--masterplan) MODE=masterplan ;;
		--allow-draft) ALLOW_DRAFT=1 ;;
		*) usage ;;
	esac
done

[ -f "$PLAN" ] || {
	echo "lint-plan: no such file: $PLAN" >&2
	exit 1
}

ERR=0
err() {
	echo "lint-plan: $PLAN: $1" >&2
	ERR=1
}

if [ "$MODE" = masterplan ]; then
	SECTIONS='Files|Context|Implementation Status|Risk Mitigation|Deployment Strategy|Monitoring & Observability|Verification|Rollback|Delivery (each PR / sub-plan)|Success Criteria|References|Notes & Assumptions'
else
	SECTIONS='Goal|Files|Context|Scope|Risks|Dependencies|Priority|Logging / Observability|Branch setup|Implementation Plan (TODOs)|Delivery|Docs|Testing|Verification|Acceptance|Fallback Plan|References|Complexity Check'
fi
# Sections a draft-only or design-only plan may omit.
DRAFT_OK='Branch setup|Delivery|Complexity Check'

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Heading lines: "## Name" -> "linenum:Name", one per line.
sed -n 's/^## \([^#].*\)$/\1/p' "$PLAN" | sed 's/[[:space:]]*$//' > "$TMP/sections"
grep -n '^## ' "$PLAN" | sed 's/^\([0-9]*\):## \([^#].*\)$/\1:\2/' | sed 's/[[:space:]]*$//' > "$TMP/headed"

[ -s "$TMP/headed" ] || {
	echo "lint-plan: $PLAN: no '##' sections found" >&2
	exit 1
}

is_draft_ok() {
	case "|$DRAFT_OK|" in *"|$1|"*) return 0 ;; *) return 1 ;; esac
}

# Pass 1: required sections exist.
OLDIFS=$IFS
IFS='|'
for s in $SECTIONS; do
	IFS=$OLDIFS
	[ "$ALLOW_DRAFT" = 1 ] && is_draft_ok "$s" && continue
	if ! grep -qxF "$s" "$TMP/sections"; then
		err "missing required section: ## $s"
	fi
	IFS='|'
done
IFS=$OLDIFS

# Pass 2: present required sections appear in template order.
PREV=0
PREVNAME=
IFS='|'
for s in $SECTIONS; do
	IFS=$OLDIFS
	line=$(awk -F: -v s="$s" '$2 == s { print $1; exit }' "$TMP/headed")
	if [ -n "$line" ]; then
		if [ "$line" -le "$PREV" ]; then
			err "section out of order: ## $s must come after ## $PREVNAME"
		fi
		PREV=$line
		PREVNAME=$s
	fi
	IFS='|'
done
IFS=$OLDIFS

if [ "$MODE" = plan ]; then
	# Files must be the section right after Goal.
	AFTER_GOAL=$(awk -F: '$2 == "Goal" { print $1; exit }' "$TMP/headed")
	if [ -n "$AFTER_GOAL" ]; then
		NEXT=$(awk -F: -v g="$AFTER_GOAL" '$1 > g { print $2; exit }' "$TMP/headed")
		[ "$NEXT" = "Files" ] || err "## Files must come right after ## Goal, found ## $NEXT"
	fi
fi

# TODO depth inside Implementation Plan (TODOs): count distinct checkbox
# indentation levels; more than 2 means nesting beyond the limit.
if [ "$MODE" = plan ]; then
	awk '
		/^## / { insec = ($0 == "## Implementation Plan (TODOs)") }
		insec && /^[[:space:]]*- \[[ xX]\]/ {
			line = $0
			gsub(/\t/, "    ", line)
			match(line, /^ */)
			print RLENGTH
		}
	' "$PLAN" > "$TMP/indents"
	if [ -s "$TMP/indents" ]; then
		LEVELS=$(sort -n "$TMP/indents" | uniq | wc -l)
		[ "$LEVELS" -gt 2 ] && err "Implementation Plan (TODOs) nests checkboxes deeper than 2 levels"
		TOP=$(sort -n "$TMP/indents" | head -1)
		TODOS=$(awk -v top="$TOP" '$1 == top' "$TMP/indents" | wc -l | tr -d ' ')
		echo "lint-plan: $PLAN: $TODOS top-level TODOs"
		[ "$TODOS" -gt 30 ] && echo "lint-plan: $PLAN: info: more than 30 TODOs, sk-planning's split threshold"
	fi

	# Complexity Check must name an explicit Proceed or Split decision.
	if grep -qxF 'Complexity Check' "$TMP/sections"; then
		DECISION=$(awk '/^## Complexity Check/ { insec = 1; next } /^## / { insec = 0 } insec && /Decision:/' "$PLAN")
		case $DECISION in
			*Proceed*|*Split*) ;;
			*) err "Complexity Check has no explicit Proceed or Split decision" ;;
		esac
		case $DECISION in
			*'[Proceed / Split]'*) err "Complexity Check decision is still the template placeholder" ;;
		esac
	fi
fi

[ "$ERR" -eq 0 ] && echo "lint-plan: $PLAN: passed"
exit "$ERR"
