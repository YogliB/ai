#!/bin/sh
# Validates a plan's structure against the sk-planning templates: required
# sections present and in order, Files right after Goal, TODO depth at
# most 2, Complexity Check filled. See docs/ARCHITECTURE.md#gates.
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

# Fenced code blocks are stripped first so '##' and checkbox examples in
# snippets do not count. Heading lines: "## Name" -> "linenum:Name".
awk '
	{
		t = $0
		gsub(/\t/, "    ", t)
		lead = match(t, /[^[:space:]]/) ? RSTART - 1 : 999
		s = $0
		sub(/^[[:space:]]+/, "", s)
		if (fence) {
			if (lead < 4 && substr(s, 1, 1) == fencec) {
				n = 0
				while (substr(s, n + 1, 1) == fencec) n++
				if (n >= fence && substr(s, n + 1) ~ /^[[:space:]]*$/) fence = 0
			}
			next
		}
		if (lead < 4 && (s ~ /^```/ || s ~ /^~~~/)) {
			fencec = substr(s, 1, 1)
			n = 0
			while (substr(s, n + 1, 1) == fencec) n++
			if (fencec != "`" || substr(s, n + 1) !~ /`/) {
				fence = n
				next
			}
		}
		if (lead < 4 && s ~ /^##[[:space:]]/) {
			sub(/^##[[:space:]]+/, "", s)
			sub(/[[:space:]]+#+[[:space:]]*$/, "", s)
			sub(/[[:space:]]+$/, "", s)
			print "## " s
			next
		}
		print
	}
' "$PLAN" > "$TMP/stripped"
grep -nE '^ {0,3}##[[:space:]]' "$TMP/stripped" | sed 's/^\([0-9]*\): *##[[:space:]]*\([^#].*\)$/\1:\2/' | sed 's/[[:space:]#]*$//' > "$TMP/headed"
cut -d: -f2- "$TMP/headed" > "$TMP/sections"

[ -s "$TMP/headed" ] || {
	echo "lint-plan: $PLAN: no '##' sections found" >&2
	exit 1
}

is_draft_ok() {
	case "|$DRAFT_OK|" in *"|$1|"*) return 0 ;; *) return 1 ;; esac
}

# Required sections must exist and, when present, appear in template order.
PREV=0
PREVNAME=
OLDIFS=$IFS
IFS='|'
for s in $SECTIONS; do
	pair=$(awk -v s="$s" '{ n = substr($0, index($0, ":") + 1); l = substr($0, 1, index($0, ":") - 1); if (n == s) { c++; if (!first) first = l } } END { print (c + 0) "|" first }' "$TMP/headed")
	count=${pair%%|*}
	line=${pair##*|}
	[ "$count" -gt 1 ] && err "duplicate section: ## $s"
	if [ -z "$line" ]; then
		[ "$ALLOW_DRAFT" = 1 ] && is_draft_ok "$s" && continue
		err "missing required section: ## $s"
		continue
	fi
	[ "$line" -le "$PREV" ] && err "section out of order: ## $s must come after ## $PREVNAME"
	PREV=$line
	PREVNAME=$s
done
IFS=$OLDIFS

if [ "$MODE" = plan ]; then
	# Files must be the section right after Goal.
	AFTER_GOAL=$(awk '{ n = substr($0, index($0, ":") + 1); if (n == "Goal") { print substr($0, 1, index($0, ":") - 1); exit } }' "$TMP/headed")
	if [ -n "$AFTER_GOAL" ]; then
		NEXT=$(awk -v g="$AFTER_GOAL" '{ l = substr($0, 1, index($0, ":") - 1) + 0; if (l > g + 0) { print substr($0, index($0, ":") + 1); exit } }' "$TMP/headed")
		[ -z "$NEXT" ] && NEXT="(none)"
		[ "$NEXT" = "Files" ] || err "## Files must come right after ## Goal, found ## $NEXT"
	fi

	# TODO depth inside Implementation Plan (TODOs): track nesting with an
	# indent stack; more than 2 nested checkbox levels fails the plan.
	awk '
		match($0, /^ *##[[:space:]]/) && RLENGTH <= 6 { insec = ($0 ~ /^ *##[[:space:]]*Implementation Plan \(TODOs\)[[:space:]]*$/) }
		insec && /^[[:space:]]*[-*+][[:space:]]+\[[ xX]\]/ {
			line = $0
			gsub(/\t/, "    ", line)
			match(line, /^ */)
			indent = RLENGTH
			while (depth > 0 && indents[depth] > indent) depth--
			if (depth == 0 || indents[depth] < indent) { depth++; indents[depth] = indent }
			print depth
		}
	' "$TMP/stripped" > "$TMP/indents"
	if [ -s "$TMP/indents" ]; then
		LEVELS=$(sort -n "$TMP/indents" | uniq | wc -l)
		[ "$LEVELS" -gt 2 ] && err "Implementation Plan (TODOs) nests checkboxes deeper than 2 levels"
		TODOS=$(awk '$1 == 1' "$TMP/indents" | wc -l | tr -d ' ')
		ALL=$(wc -l < "$TMP/indents" | tr -d ' ')
		echo "lint-plan: $PLAN: $TODOS top-level TODOs"
		[ "$ALL" -gt 30 ] && echo "lint-plan: $PLAN: info: more than 30 TODOs, sk-planning's split threshold"
	fi

	# Complexity Check must name an explicit Proceed or Split decision.
	if grep -qxF 'Complexity Check' "$TMP/sections"; then
		DECISION=$(awk 'match($0, /^ *##[[:space:]]/) && RLENGTH <= 6 { insec = ($0 ~ /##[[:space:]]*Complexity Check[[:space:]]*$/) } insec && /Decision:/ { print; exit }' "$TMP/stripped")
		VAL=$(printf '%s' "$DECISION" | sed 's/^.*Decision:[*_[:space:]]*//' | tr -d '*')
		FIRST=${VAL%%[!A-Za-z]*}
		case $FIRST in
			Proceed|Split)
				case $VAL in
					*Proceed*Split*|*Split*Proceed*) err "Complexity Check decision must pick one of Proceed or Split" ;;
				esac ;;
			*)
				case $VAL in
					'[Proceed / Split]'*) err "Complexity Check decision is still the template placeholder" ;;
					*) err "Complexity Check has no explicit Proceed or Split decision" ;;
				esac ;;
		esac
	fi
fi

[ "$ERR" -eq 0 ] && echo "lint-plan: $PLAN: passed"
exit "$ERR"
