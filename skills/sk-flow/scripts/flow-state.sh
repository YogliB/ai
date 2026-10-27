#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHECK_RECEIPT="$SELF_DIR/../../sk-implement/scripts/check-receipt.sh"

ROWS_FULL="0 1 1r 2 2r 3 4 5 6"
ROWS_LIGHT="2 3 5 6"
usage() {
	echo "usage: flow-state.sh check <dir> | init <dir> --slug=<s> --goal=<g> [--size=light|full] [--at=<row>] | advance <dir> [--skip|--receipts=a,b|--result=|--valid=|--decision=|--note=] | note <dir> <text...> | set <dir> <key>=<value>" >&2
	exit 2
}

die() { echo "flow-state: $1" >&2; exit "${2:-1}"; }

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

pname() {
	case $1 in
		0) echo "Explore" ;;
		1) echo "Alternatives" ;;
		1r) echo "Alternatives review" ;;
		2) echo "Planning" ;;
		2r) echo "Plan review" ;;
		3) echo "Implementation" ;;
		4) echo "Review" ;;
		5) echo "Verify" ;;
		6) echo "PR" ;;
	esac
}

NL='
'

kesc() { printf '%s' "$1" | sed 's/\./\\./g'; }

get() { sed -n "s/^$(kesc "$2"): //p" "$1" | head -n 1; }
fget() { get "$RB" "f.$1.$2"; }

esc() { printf '%s' "$1" | sed 's/[&|\\]/\\&/g'; }

set_kv() {
	case $2 in
		*"$NL"*) die "value for $1 contains a newline" 2 ;;
	esac
	kv_key=$(kesc "$1")
	if grep -q "^$kv_key: " "$RB"; then
		trap 'rm -f "$RB.tmp.$$"' EXIT
		sed "s|^$kv_key: .*|$1: $(esc "$2")|" "$RB" > "$RB.tmp.$$" || die "set: cannot write $RB"
		mv "$RB.tmp.$$" "$RB" || die "set: cannot write $RB"
	else
		ensure_nl "$RB"
		printf '%s: %s\n' "$1" "$2" >> "$RB" || die "set: cannot write $RB"
	fi
}

ensure_nl() {
	if [ -f "$1" ] && [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then
		printf '\n' >> "$1"
	fi
}

dirarg() {
	case $1 in
		-*) printf './%s' "$1" ;;
		*) printf '%s' "$1" ;;
	esac
}

rows_of() {
	case $(get "$RB" size) in
		light) echo "$ROWS_LIGHT" ;;
		*) echo "$ROWS_FULL" ;;
	esac
}

member() {
	for m in $2; do
		[ "$m" = "$1" ] && return 0
	done
	return 1
}

before() {
	out=
	for r in $ROWS; do
		[ "$r" = "$AT" ] && break
		out="$out $r"
	done
	echo $out
}

after() {
	seen= out=
	for r in $ROWS; do
		[ -n "$seen" ] && out="$out $r"
		[ "$r" = "$AT" ] && seen=1
	done
	echo $out
}

ERRS=
err() { ERRS="$ERRS$1
"; }

bad_receipt() {
	case $1 in
		/* | .. | ../* | */.. | */../*) printf '%s\n' "receipt path must stay inside the flow dir: $1"; return ;;
	esac
	[ -f "$DIR/$1" ] || { printf '%s\n' "missing receipt: $1"; return; }
	sh "$CHECK_RECEIPT" "$DIR/$1" >/dev/null 2>&1 || printf '%s\n' "receipt did not pass: $1"
}

receipts_ok() {
	list=$(fget "$1" receipts)
	if [ -z "$list" ]; then
		err "row $1 cites no receipts"
		return
	fi
	if [ ! -r "$CHECK_RECEIPT" ]; then
		err "row $1: receipt validator missing: $CHECK_RECEIPT (install sk-implement)"
		return
	fi
	collect_receipt_errs "$list"
	if [ -n "$RECEIPT_ERRS" ]; then
		err "row $1: $RECEIPT_ERRS"
	fi
}

RECEIPT_ERRS=
collect_receipt_errs() {
	RECEIPT_ERRS=
	oldifs=$IFS; IFS=,
	set -f
	for p in $1; do
		m=$(bad_receipt "$p")
		if [ -n "$m" ]; then
			RECEIPT_ERRS="$RECEIPT_ERRS$m
"
		fi
	done
	set +f
	IFS=$oldifs
}

receipts_check() {
	[ -r "$CHECK_RECEIPT" ] || die "advance: receipt validator missing: $CHECK_RECEIPT (install sk-implement)"
	collect_receipt_errs "$1"
	if [ -n "$RECEIPT_ERRS" ]; then
		die "advance: $RECEIPT_ERRS"
	fi
}

row_ok() {
	r=$1
	a=$(artifact "$r")
	if [ "$(fget "$r" skipped)" = "1" ]; then
		case $r in
			1r | 2r) : ;;
			*) if [ -e "$DIR/$a" ]; then err "row $r skipped but $a exists"; fi ;;
		esac
		return 0
	fi
	case $r in
		1r | 2r)
			[ "$(fget "$r" valid)" = "0" ] || err "row $r passed without valid=0"
			;;
		3)
			receipts_ok "$r"
			;;
		5)
			receipts_ok "$r"
			[ "$(fget 5 result)" = "pass" ] || err "row 5 passed without result=pass"
			;;
		4)
			res=$(fget 4 result)
			case $res in
				clean | findings-fixed) ;;
				*) err "row 4 passed with invalid result '$res'" ;;
			esac
			[ "$(fget 4 valid)" = "0" ] || err "row 4 passed without valid=0"
			;;
		2)
			[ "$(fget 2 decision)" = "proceed" ] || err "row 2 passed without decision=proceed"
			;;
	esac
	case $r in
		1r | 2r) : ;;
		*) [ -f "$DIR/$a" ] || err "row $r passed but $a is missing" ;;
	esac
}

load() {
	[ -d "$DIR" ] || die "no such directory: $DIR"
	RB="$DIR/runbook"
	[ -f "$RB" ] || die "runbook missing: $RB (legacy runbook.json/RUNBOOK.md is not supported)"
	ver=$(get "$RB" runbook-version)
	[ "$ver" = "3" ] || die "runbook-version is '${ver:-missing}', expected 3"
	ROWS=$(rows_of)
	AT=$(get "$RB" at)
}

validate() {
	slug=$(get "$RB" slug)
	case $slug in
		"" | *[!a-z0-9-]* | -* | *-) err "invalid slug '$slug'" ;;
	esac
	size=$(get "$RB" size)
	case $size in
		light | full) ;;
		*) err "invalid size '$size'" ;;
	esac
	while IFS= read -r line || [ -n "$line" ]; do
		case $line in
			*": "*) ;;
			*) err "malformed runbook line: $line" ;;
		esac
	done < "$RB"
	status=$(get "$RB" status)
	case $status in
		in-progress | completed | blocked | diverged) ;;
		*) err "invalid status '$status'" ;;
	esac
	member "$AT" "$ROWS done" || err "at '$AT' is not a row of this flow"
	if [ "$AT" = done ]; then
		[ "$status" = completed ] || err "at is done but status is '$status'"
	else
		[ "$status" != completed ] || err "status is completed but at is '$AT'"
	fi
	for r in $(before); do row_ok "$r"; done
	reached_files="$(artifact "$AT")"
	for r in $(before); do
		a=$(artifact "$r")
		case " $reached_files " in
			*" $a "*) ;;
			*) reached_files="$reached_files $a" ;;
		esac
	done
	for r in $(after); do
		a=$(artifact "$r")
		case " $reached_files " in
			*" $a "*) continue ;;
		esac
		if [ -e "$DIR/$a" ]; then
			err "$a exists but row $r has not been reached"
		fi
	done
	for f in "$DIR"/[0-9]*.md "$DIR"/pr-* "$DIR"/runbook.json "$DIR"/RUNBOOK.md; do
		[ -e "$f" ] || continue
		bn=$(basename "$f")
		found=
		for r in $ROWS; do
			[ "$bn" = "$(artifact "$r")" ] && found=1
		done
		[ -n "$found" ] || err "unexpected file: $bn"
	done
}

cmd_check() {
	load
	validate
	echo "flow: $(basename "$DIR")"
	echo "size: $(get "$RB" size)"
	if [ -n "$ERRS" ]; then
		echo "status: error"
		printf '%s' "$ERRS" | while IFS= read -r line; do
			if [ -n "$line" ]; then
				echo "flow-state: $DIR: $line" >&2
			fi
		done
		exit 1
	fi
	echo "status: ok"
	echo "at: $AT"
	if [ "$AT" = done ]; then
		echo "next: none"
		echo "next-phase: flow complete"
	else
		echo "next: $AT"
		echo "next-phase: $(pname "$AT")"
	fi
}

cmd_init() {
	slug= goal= size=full at= at_given=
	for a in "$@"; do
		case $a in
			--slug=*) slug=${a#--slug=} ;;
			--goal=*) goal=${a#--goal=} ;;
			--size=*) size=${a#--size=} ;;
			--at=*) at=${a#--at=}; at_given=1 ;;
			*) usage ;;
		esac
	done
	case $slug$goal in
		*"$NL"*) die "init: newlines are not allowed" 2 ;;
	esac
	case $slug in
		"" | *[!a-z0-9-]* | -* | *-) die "init: invalid or missing slug '$slug'" 2 ;;
	esac
	[ -n "$goal" ] || die "init: --goal is required" 2
	case $size in
		light) allowed=$ROWS_LIGHT ;;
		full) allowed=$ROWS_FULL ;;
		*) die "init: --size must be light or full" 2 ;;
	esac
	if [ -n "$at_given" ]; then
		[ -n "$at" ] || die "init: --at requires a row" 2
		member "$at" "$allowed" || die "init: --at '$at' is not a row of a $size flow" 2
		case $at in
			1r | 2r) die "init: --at must be an artifact row, not a review row" 2 ;;
		esac
	else
		set -- $allowed
		at=$1
	fi
	RB="$DIR/runbook"
	[ -e "$RB" ] && die "init: $RB already exists"
	flowsdir=$(dirname "$DIR")
	agentsdir=$(dirname "$flowsdir")
	if [ "$(basename "$flowsdir")" = flows ] && [ "$(basename "$agentsdir")" = .agents ]; then
		gi="$agentsdir/.gitignore"
		{ [ -f "$gi" ] && grep -qxF 'flows/' "$gi"; } || {
			mkdir -p "$agentsdir"
			ensure_nl "$gi"
			echo 'flows/' >> "$gi"
		}
		if git -C "$agentsdir" rev-parse --git-dir >/dev/null 2>&1 && [ -n "$(git -C "$agentsdir" ls-files flows | head -n 1)" ]; then
			echo "init: warning: $flowsdir already has tracked files; gitignore will not hide them (git rm -r --cached .agents/flows to untrack)" >&2
		fi
	fi
	mkdir -p "$DIR"
	trap 'rm -f "$RB.tmp.$$"' EXIT
	{
		printf '%s: %s\n' runbook-version 3
		printf '%s: %s\n' slug "$slug"
		printf '%s: %s\n' status in-progress
		printf '%s: %s\n' goal "$goal"
		printf '%s: %s\n' size "$size"
		printf '%s: %s\n' at "$at"
		for r in $allowed; do
			[ "$r" = "$at" ] && break
			printf '%s: %s\n' "f.$r.skipped" 1
			printf '%s: %s\n' "f.$r.note" "standalone entry"
		done
	} > "$RB.tmp.$$" || die "init: cannot write $RB"
	mv "$RB.tmp.$$" "$RB" || die "init: cannot write $RB"
	echo "init: $RB"
}

cmd_advance() {
	load
	validate
	[ -n "$ERRS" ] && {
		printf '%s' "$ERRS" >&2
		die "advance: runbook failed check; repair before advancing"
	}
	case $(get "$RB" status) in
		in-progress) ;;
		completed) die "advance: flow is already completed" ;;
		*) die "advance: flow is $(get "$RB" status); use set status=in-progress to resume" ;;
	esac
	member "$AT" "$ROWS" || die "advance: nothing to advance (at is '$AT')"
	a=$(artifact "$AT")
	skip= v_receipts= v_result= v_valid= v_decision= v_note=
	for arg in "$@"; do
		case $arg in
			--skip) skip=1 ;;
			--receipts=*) v_receipts=${arg#--receipts=} ;;
			--result=*) v_result=${arg#--result=} ;;
			--valid=*) v_valid=${arg#--valid=} ;;
			--decision=*) v_decision=${arg#--decision=} ;;
			--note=*) v_note=${arg#--note=} ;;
			*) die "advance: unknown flag ${arg%%=*}" 2 ;;
		esac
	done
	case $v_receipts$v_result$v_valid$v_decision$v_note in
		*"$NL"*) die "advance: newlines are not allowed" 2 ;;
	esac
	if [ -n "$skip" ]; then
		[ "$AT" = 5 ] || die "advance: --skip is only valid on row 5 (verification blocked)" 2
		[ -n "$v_note" ] || die "advance: --skip requires --note=<reason>" 2
		[ -z "$v_receipts$v_result$v_valid$v_decision" ] || die "advance: --skip accepts only --note" 2
		if [ -e "$DIR/$a" ]; then
			die "advance: $a exists; delete it or advance normally"
		fi
	else
		[ -f "$DIR/$a" ] || die "advance: $a is missing"
		allowed_flags=
		case $AT in
			1r | 2r) allowed_flags="valid" ;;
			2) allowed_flags="decision" ;;
			3) allowed_flags="receipts" ;;
			4) allowed_flags="result valid" ;;
			5) allowed_flags="result receipts" ;;
		esac
		for pair in "receipts=$v_receipts" "result=$v_result" "valid=$v_valid" "decision=$v_decision"; do
			f=${pair%%=*}
			[ -z "${pair#*=}" ] && continue
			member "$f" "$allowed_flags" || die "advance: --$f is not accepted on row $AT" 2
		done
		case $AT in
			1r | 2r) [ "$v_valid" = "0" ] || die "advance: row $AT requires --valid=0" 2 ;;
			2) [ "$v_decision" = "proceed" ] || die "advance: row 2 requires --decision=proceed" 2 ;;
			3)
				[ -n "$v_receipts" ] || die "advance: row $AT requires --receipts=<files>" 2
				receipts_check "$v_receipts"
				;;
			5)
				[ "$v_result" = "pass" ] || die "advance: row 5 requires --result=pass" 2
				[ -n "$v_receipts" ] || die "advance: row $AT requires --receipts=<files>" 2
				receipts_check "$v_receipts"
				;;
			4)
				case $v_result in clean | findings-fixed) ;; *) die "advance: row 4 requires --result=clean|findings-fixed" 2 ;; esac
				[ "$v_valid" = "0" ] || die "advance: row 4 requires --valid=0" 2
				;;
		esac
	fi
	next=
	for r in $(after); do next=$r; break; done
	trap 'rm -f "$RB.tmp.$$"' EXIT
	{
		sed -e "/^f\.$AT\./d" -e '/^at: /d' -e '/^status: /d' "$RB" || die "advance: cannot read $RB"
		if [ -n "$skip" ]; then
			printf 'f.%s.skipped: 1\n' "$AT"
		else
			for k in receipts result valid decision; do
				eval "v=\$v_$k"
				if [ -n "$v" ]; then
					printf 'f.%s.%s: %s\n' "$AT" "$k" "$v"
				fi
			done
		fi
		if [ -n "$v_note" ]; then
			printf 'f.%s.note: %s\n' "$AT" "$v_note"
		fi
		printf 'at: %s\n' "${next:-done}"
		if [ -n "$next" ]; then
			printf 'status: in-progress\n'
		else
			printf 'status: completed\n'
		fi
	} > "$RB.tmp.$$" || die "advance: cannot write $RB"
	mv "$RB.tmp.$$" "$RB" || die "advance: cannot write $RB"
	echo "advanced to ${next:-done}"
}

cmd_note() {
	[ $# -ge 1 ] || usage
	case "$*" in
		*"$NL"*) die "note: newlines are not allowed" 2 ;;
	esac
	ensure_nl "$RB"
	printf 'note: %s\n' "$*" >> "$RB"
	echo "note recorded"
}

cmd_set() {
	[ $# -eq 1 ] || usage
	case $1 in
		*=*) ;;
		*) usage ;;
	esac
	key=${1%%=*}
	val=${1#*=}
	if [ "$key" = note ]; then
		die "set: 'note' is append-only; use note" 2
	fi
	case $key in
		"" | *[!a-zA-Z0-9._-]*) die "set: invalid key '$key'" 2 ;;
	esac
	if [ "$key" = size ]; then
		case $val in
			light | full) ;;
			*) die "set: size must be light or full" 2 ;;
		esac
		for f in "$DIR"/[0-9]*.md "$DIR"/pr-*; do
			[ -e "$f" ] && die "set: size= is only safe before artifacts exist"
		done
		load
		case $val in
			light) allowed=$ROWS_LIGHT ;;
			*) allowed=$ROWS_FULL ;;
		esac
		set -- $allowed
		set_kv at "$1"
		set_kv size "$val"
		echo "set size $val"
		return
	fi
	set_kv "$key" "$val"
	echo "set $key $val"
}

[ $# -ge 1 ] || usage
cmd=$1
shift
case $cmd in
	check) [ $# -eq 1 ] || usage; DIR=$(dirarg "$1"); cmd_check ;;
	init) [ $# -ge 1 ] || usage; DIR=$(dirarg "$1"); shift; cmd_init "$@" ;;
	advance) [ $# -ge 1 ] || usage; DIR=$(dirarg "$1"); shift; cmd_advance "$@" ;;
	note) [ $# -ge 2 ] || usage; DIR=$(dirarg "$1"); shift; RB="$DIR/runbook"; [ -f "$RB" ] || die "runbook missing: $RB"; cmd_note "$@" ;;
	set) [ $# -eq 2 ] || usage; DIR=$(dirarg "$1"); RB="$DIR/runbook"; [ -f "$RB" ] || die "runbook missing: $RB"; shift; cmd_set "$@" ;;
	*) usage ;;
esac
