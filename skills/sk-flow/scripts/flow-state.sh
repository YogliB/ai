#!/bin/sh
# Validates a flow's recorded state against the sk-flow contract and
# names the next phase. The runbook is data; this script reads it, the
# model never guesses phase state from globs. See docs/GATES.md.
set -eu

usage() {
	echo "usage: flow-state.sh <flow-dir>" >&2
	exit 2
}

[ $# -eq 1 ] || usage
DIR=${1%/}
[ -d "$DIR" ] || {
	echo "flow-state: no such directory: $DIR" >&2
	exit 1
}
[ -f "$DIR/RUNBOOK.md" ] || {
	echo "flow-state: $DIR: RUNBOOK.md missing" >&2
	exit 1
}

ERR=0
err() {
	echo "flow-state: $DIR: $1" >&2
	ERR=1
}

ROWS_SINGLE="0 1 1r 2 2r 3 4 5 6"
ROWS_INITIATIVE="0 1 1r 2 2r"
STATES="done skipped diverged blocked in-progress pending"

artifact() {
	case $1 in
		0) echo "0 - EXPLORE.md" ;;
		1 | 1r) echo "1 - ALTERNATIVES.md" ;;
		2 | 2r) echo "2 - PLANNING.md" ;;
		3) echo "3 - IMPLEMENTATION.md" ;;
		4) echo "4 - REVIEW.md" ;;
		5) echo "5 - VERIFY.md" ;;
		6) echo "6 - PR.md" ;;
	esac
}

phasename() {
	case $1 in
		0) echo Explore ;;
		1) echo Alternatives ;;
		1r) echo "Alternatives review" ;;
		2) echo Planning ;;
		2r) echo "Plan review" ;;
		3) echo Implementation ;;
		4) echo Review ;;
		5) echo Verify ;;
		6) echo PR ;;
	esac
}

# Emits normalized facts from a runbook:
#   STATUS|<status>
#   ACTIVEPR|<slug|none>
#   ROW|<id>|<state>           phase rows (both table shapes)
#   PR|<order>|<slug>|<deps>|<state>|<dir>
parse_runbook() {
	awk -F'|' '
		/^Status: / { sub(/^Status: /, ""); print "STATUS|" $0; next }
		/^Active PR: / { sub(/^Active PR: /, ""); print "ACTIVEPR|" $0; next }
		/^## Pull requests/ { inpr = 1; next }
		/^## / { inpr = 0; next }
		!/^[[:space:]]*\|/ { next }
		{
			line = $0
			gsub(/[|]/, "", line)
			gsub(/[[:space:]-]/, "", line)
			if (line == "") next
			nf = 0
			for (i = 1; i <= NF; i++) {
				f = $i
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", f)
				cell[++nf] = f
			}
			if (inpr) {
				if (cell[2] ~ /^[0-9]+$/ && cell[3] != "" && cell[3] != "PR")
					print "PR|" cell[2] "|" cell[3] "|" cell[5] "|" cell[6] "|" cell[7]
			} else {
				if (cell[2] ~ /^[0-9]+r?$/)
					print "ROW|" cell[2] "|" cell[4]
			}
			for (i in cell) delete cell[i]
		}
	' "$1"
}

row_state() { # $1 facts file, $2 row id -> state or empty
	awk -F'|' -v id="$2" '$1 == "ROW" && $2 == id { print $3 }' "$1"
}

# Validates phase rows + artifacts of one runbook.
# $1 facts file, $2 dir, $3 expected row list, $4 label
validate_rows() {
	FACTS=$1
	RDIR=$2
	EXPECTED=$3
	LABEL=$4

	status=$(awk -F'|' '$1 == "STATUS" { print $2 }' "$FACTS")
	case $status in
		in-progress | completed | blocked | diverged) ;;
		*) err "$LABEL: missing or invalid Status line" ;;
	esac

	for row in $EXPECTED; do
		n=$(awk -F'|' -v id="$row" '$1 == "ROW" && $2 == id { n++ } END { print n+0 }' "$FACTS")
		[ "$n" -eq 0 ] && err "$LABEL: runbook row $row missing"
		[ "$n" -gt 1 ] && err "$LABEL: runbook row $row appears $n times"
		state=$(row_state "$FACTS" "$row")
		[ -n "$state" ] || continue
		ok=0
		for s in $STATES; do [ "$state" = "$s" ] && ok=1; done
		[ "$ok" = 1 ] || err "$LABEL: row $row has invalid state '$state'"
		art=$(artifact "$row")
		case $state in
			done | diverged)
				[ -f "$RDIR/$art" ] || err "$LABEL: row $row is $state but $art is missing"
				;;
			skipped)
				case $row in
					*r) ;; # review rows share the phase artifact
					*)
						[ -f "$RDIR/$art" ] && err "$LABEL: row $row is skipped but $art exists"
						;;
				esac
				;;
		esac
	done

	# A phase artifact whose producing row is pending is a contradiction.
	for row in 0 1 2 3 4 5 6; do
		case " $EXPECTED " in *" $row "*) ;; *) continue ;; esac
		state=$(row_state "$FACTS" "$row")
		art=$(artifact "$row")
		[ "$state" = "pending" ] && [ -f "$RDIR/$art" ] && err "$LABEL: $art exists but row $row is pending"
	done

	# Ordering: a done/diverged row cannot follow a pending/blocked one.
	seen_unfinished=0
	for row in $EXPECTED; do
		state=$(row_state "$FACTS" "$row")
		case $state in
			pending | blocked) seen_unfinished=1 ;;
			done | diverged)
				[ "$seen_unfinished" = 1 ] && err "$LABEL: row $row is $state while an earlier row is pending or blocked"
				;;
		esac
	done

	# At most one row in progress.
	n=$(awk -F'|' '$1 == "ROW" && $3 == "in-progress" { n++ } END { print n+0 }' "$FACTS")
	[ "$n" -gt 1 ] && err "$LABEL: $n rows are in-progress; at most one allowed"
	return 0
}

# Canonical artifact names present in a flow directory must be exact.
check_files() {
	RDIR=$1
	LABEL=$2
	for f in "$RDIR"/[0-9]*.md; do
		[ -e "$f" ] || continue
		base=$(basename "$f")
		ok=0
		for row in $ROWS_SINGLE; do
			[ "$base" = "$(artifact "$row")" ] && ok=1
		done
		[ "$ok" = 0 ] && err "$LABEL: unexpected artifact file: $base"
	done
	return 0
}

next_from_rows() { # $1 facts file, $2 expected list -> prints "<id>|<name>" or empty
	NF=$1
	for row in $2; do
		state=$(row_state "$NF" "$row")
		case $state in
			pending | in-progress | blocked)
				echo "$row|$(phasename "$row")"
				return
				;;
		esac
	done
	return 0
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

parse_runbook "$DIR/RUNBOOK.md" > "$TMP/root"

grep -q '^ACTIVEPR|' "$TMP/root" && MODE=multi || MODE=single
echo "flow: $(basename "$DIR")"
echo "mode: $MODE"

if [ "$MODE" = single ]; then
	validate_rows "$TMP/root" "$DIR" "$ROWS_SINGLE" "runbook"
	check_files "$DIR" "runbook"
	if [ "$ERR" = 0 ]; then
		echo "status: ok"
		NEXT=$(next_from_rows "$TMP/root" "$ROWS_SINGLE")
		if [ -n "$NEXT" ]; then
			echo "next: ${NEXT%%|*}"
			echo "next-phase: ${NEXT#*|}"
		else
			echo "next: none"
			echo "next-phase: flow complete"
		fi
	else
		echo "status: error"
	fi
	exit "$ERR"
fi

# Multi-PR initiative.
validate_rows "$TMP/root" "$DIR" "$ROWS_INITIATIVE" "initiative"
check_files "$DIR" "initiative"

ACTIVE=$(awk -F'|' '$1 == "ACTIVEPR" { print $2 }' "$TMP/root")
[ -n "$ACTIVE" ] || err "initiative: Active PR line missing"

awk -F'|' '$1 == "PR" { print $2 "|" $3 "|" $4 "|" $5 "|" $6 }' "$TMP/root" > "$TMP/prs"
[ -s "$TMP/prs" ] || err "initiative: the pull requests table has no rows"

# Collect slugs.
SLUGS=$(awk -F'|' '{ print $2 }' "$TMP/prs" | tr '\n' ' ')
INPROGRESS=""
while IFS='|' read -r order slug deps state dirlink; do
	# Deps must be existing slugs or none.
	if [ "$deps" != "none" ] && [ "$deps" != "-" ]; then
		for dep in $(echo "$deps" | tr ',' ' '); do
			dep=$(echo "$dep" | tr -d '[:space:]')
			case " $SLUGS " in *" $dep "*) ;; *) err "initiative: PR $slug depends on unknown PR '$dep'" ;; esac
		done
	fi
	case $state in
		pending | in-progress | blocked | done | canceled) ;;
		*) err "initiative: PR $slug has invalid state '$state'" ;;
	esac
	[ "$state" = "in-progress" ] && INPROGRESS="$INPROGRESS $slug"
	# Every listed PR has its directory and a valid runbook.
	if [ ! -d "$DIR/pr-$slug" ]; then
		err "initiative: PR $slug has no directory pr-$slug/"
		continue
	fi
	if [ ! -f "$DIR/pr-$slug/RUNBOOK.md" ]; then
		err "initiative: PR $slug has no pr-$slug/RUNBOOK.md"
		continue
	fi
	parse_runbook "$DIR/pr-$slug/RUNBOOK.md" > "$TMP/pr-$slug"
	validate_rows "$TMP/pr-$slug" "$DIR/pr-$slug" "$ROWS_SINGLE" "PR $slug"
	check_files "$DIR/pr-$slug" "PR $slug"
	s6=$(row_state "$TMP/pr-$slug" 6)
	[ "$state" = "done" ] && [ "$s6" != "done" ] && [ "$s6" != "skipped" ] && err "initiative: PR $slug is done but its runbook row 6 is ${s6:-missing}"
	[ "$state" = "in-progress" ] && [ "$s6" = "done" ] && err "initiative: PR $slug is in-progress but its runbook row 6 is done"
	# An in-progress PR's dependencies must all be done.
	if [ "$state" = "in-progress" ] && [ "$deps" != "none" ] && [ "$deps" != "-" ]; then
		for dep in $(echo "$deps" | tr ',' ' '); do
			dep=$(echo "$dep" | tr -d '[:space:]')
			dstate=$(awk -F'|' -v s="$dep" '$2 == s { print $4 }' "$TMP/prs")
			[ "$dstate" = "done" ] || err "initiative: PR $slug is in-progress but dependency $dep is ${dstate:-unknown}"
		done
	fi
done < "$TMP/prs"

# Every pr-* directory must appear in the table.
for d in "$DIR"/pr-*/; do
	[ -d "$d" ] || continue
	slug=$(basename "$d" | sed 's/^pr-//')
	case " $SLUGS " in *" $slug "*) ;; *) err "initiative: directory pr-$slug/ is not in the pull requests table" ;; esac
done

N_INPROGRESS=$(echo $INPROGRESS | wc -w | tr -d ' ')
if [ "$N_INPROGRESS" -gt 1 ]; then
	err "initiative: $N_INPROGRESS PRs are in-progress; at most one allowed"
elif [ "$N_INPROGRESS" = 1 ]; then
	[ "$ACTIVE" = "$(echo $INPROGRESS)" ] || err "initiative: Active PR is '$ACTIVE' but the in-progress PR is '$(echo $INPROGRESS)'"
else
	[ "$ACTIVE" = "none" ] || err "initiative: Active PR is '$ACTIVE' but no PR is in-progress"
fi

if [ "$ERR" -gt 0 ]; then
	echo "status: error"
	exit 1
fi

echo "status: ok"
echo "active-pr: ${ACTIVE:-none}"
if [ "$ACTIVE" != "none" ] && [ -n "$ACTIVE" ]; then
	NEXT=$(next_from_rows "$TMP/pr-$ACTIVE" "$ROWS_SINGLE")
	if [ -n "$NEXT" ]; then
		echo "next: ${NEXT%%|*}"
		echo "next-phase: ${NEXT#*|} (PR $ACTIVE)"
	else
		echo "next: none"
		echo "next-phase: PR $ACTIVE complete"
	fi
else
	# First pending PR whose dependencies are all done.
	NEXTPR=""
	while IFS='|' read -r order slug deps state dirlink; do
		[ "$state" = "pending" ] || continue
		blocked=0
		if [ "$deps" != "none" ] && [ "$deps" != "-" ]; then
			for dep in $(echo "$deps" | tr ',' ' '); do
				dep=$(echo "$dep" | tr -d '[:space:]')
				dstate=$(awk -F'|' -v s="$dep" '$2 == s { print $4 }' "$TMP/prs")
				[ "$dstate" = "done" ] || blocked=1
			done
		fi
		[ "$blocked" = 0 ] && NEXTPR=$slug && break
	done < "$TMP/prs"
	if [ -n "$NEXTPR" ]; then
		echo "next: 2"
		echo "next-phase: start PR $NEXTPR"
	else
		echo "next: none"
		echo "next-phase: initiative complete or blocked"
	fi
fi
