#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
FS="$REPO_ROOT/skills/sk-flow/scripts/flow-state.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() {
	echo "test-flow-state: FAIL: $1" >&2
	exit 1
}

art_name() {
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

# runbook <dir> <rows like "0:done 1:pending ..."> [status]
runbook() {
	D=$1
	ROWS=$2
	STATUS=${3:-in-progress}
	mkdir -p "$D"
	{
		echo "# Flow Runbook: x"
		echo
		echo "Status: $STATUS"
		echo
		echo "Goal: test"
		echo
		echo "| #   | Phase               | State   | Agent / Session | Parent Dispatch / Input | Resulting HEAD | Artifact | Summary | Divergence / Notes |"
		echo "| --- | ------------------- | ------- | --------------- | ----------------------- | -------------- | -------- | ------- | ------------------ |"
		for pair in $ROWS; do
			row=${pair%%:*}
			state=${pair##*:}
			echo "| $row | $(art_name "$row" | sed 's/^[0-9] - //; s/\.md//') | $state | | | | | | |"
			case $state in done | diverged)
				case $row in *r) ;; *) echo "artifact $row" > "$D/$(art_name "$row")" ;; esac
				;;
			esac
		done
	} > "$D/RUNBOOK.md"
}

ROWS_ALL="0:pending 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"

# A: a fresh single-PR flow is valid, next phase is 0.
runbook sk-fresh "$ROWS_ALL"
OUT=$(sh "$FS" sk-fresh) || fail "a fresh flow is not valid"
echo "$OUT" | grep -q '^next: 0$' || fail "a fresh flow's next phase is not 0"

# B: mid-flow, next is the in-progress row.
runbook sk-mid "0:done 1:done 1r:done 2:done 2r:done 3:in-progress 4:pending 5:pending 6:pending"
OUT=$(sh "$FS" sk-mid) || fail "a mid flow is not valid"
echo "$OUT" | grep -q '^next: 3$' || fail "a mid flow's next phase is not 3: $OUT"

# C: done row with a missing artifact is an error.
runbook sk-bad1 "0:done 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
rm "sk-bad1/0 - EXPLORE.md"
if sh "$FS" sk-bad1 2>"$TMP/err"; then fail "a missing artifact is not reported"; fi
grep -q 'row 0 is done but 0 - EXPLORE.md is missing' "$TMP/err" || fail "the missing artifact is not named"

# D: an artifact whose row is pending is an error.
runbook sk-bad2 "$ROWS_ALL"
echo x > "sk-bad2/2 - PLANNING.md"
if sh "$FS" sk-bad2 2>"$TMP/err"; then fail "a pending row with an artifact is not reported"; fi

# E: an unexpected artifact name is an error.
runbook sk-bad3 "$ROWS_ALL"
echo x > "sk-bad3/2 - PLANNING-old.md"
if sh "$FS" sk-bad3 2>"$TMP/err"; then fail "an unexpected artifact file is not reported"; fi
grep -q 'unexpected artifact file' "$TMP/err" || fail "the unexpected file is not named"

# F: two rows in progress are an error.
runbook sk-bad4 "0:done 1:in-progress 1r:pending 2:in-progress 2r:pending 3:pending 4:pending 5:pending 6:pending"
if sh "$FS" sk-bad4 2>"$TMP/err"; then fail "two in-progress rows are not reported"; fi

# G: a done row after a pending one is an error.
runbook sk-bad5 "0:done 1:pending 1r:pending 2:done 2r:pending 3:pending 4:pending 5:pending 6:pending"
if sh "$FS" sk-bad5 2>"$TMP/err"; then fail "a done row after a pending one is not reported"; fi

# H: a complete flow has no next phase.
runbook sk-done "0:done 1:done 1r:done 2:done 2r:done 3:done 4:done 5:done 6:done" completed
OUT=$(sh "$FS" sk-done) || fail "a complete flow is not valid"
echo "$OUT" | grep -q '^next: none$' || fail "a complete flow has a next phase"

# Multi-PR helpers.
pr_row() { # order slug deps state
	echo "| $1 | $2 | YogliB/ai | $3 | $4 | [pr-$2/](pr-$2/) | - | - | - | - | |"
}

# M1: valid initiative, one in-progress PR, next phase from its runbook.
mkdir -p sk-multi/pr-first sk-multi/pr-second
{
	echo "# Flow Initiative: x"
	echo
	echo "Status: in-progress"
	echo
	echo "Goal: test"
	echo
	echo "Active PR: first"
	echo
	echo '## Initiative phases'
	echo
	echo "| #   | Phase               | State   | Agent / Session | Parent Dispatch / Input | Resulting HEAD | Artifact | Summary | Divergence / Notes |"
	echo "| --- | ------------------- | ------- | --------------- | ----------------------- | -------------- | -------- | ------- | ------------------ |"
	for pair in 0:done 1:done 1r:done 2:done 2r:done; do
		row=${pair%%:*}
		state=${pair##*:}
		echo "| $row | $(art_name "$row" | sed 's/^[0-9] - //; s/\.md//') | $state | | | | | | |"
	done
	echo
	echo '## Pull requests'
	echo
	echo '| Order | PR | Repo | Dependencies | State | Directory | Link | Branch | Base SHA | HEAD | Summary / Notes |'
	echo '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |'
	pr_row 1 first none in-progress
	pr_row 2 second first pending
} > sk-multi/RUNBOOK.md
echo a > "sk-multi/0 - EXPLORE.md"
echo a > "sk-multi/1 - ALTERNATIVES.md"
echo a > "sk-multi/2 - PLANNING.md"
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:in-progress 4:pending 5:pending 6:pending"
runbook sk-multi/pr-second "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
OUT=$(sh "$FS" sk-multi) || { sh "$FS" sk-multi; fail "a valid initiative is not valid"; }
echo "$OUT" | grep -q '^mode: multi$' || fail "multi mode not detected"
echo "$OUT" | grep -q '^active-pr: first$' || fail "active PR not reported"
echo "$OUT" | grep -q '^next: 3$' || fail "next phase not from the active PR: $OUT"

# M2: Active PR that matches no in-progress PR is an error.
sed -i 's/^Active PR: first$/Active PR: second/' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "a wrong Active PR is not reported"; fi
sed -i 's/^Active PR: second$/Active PR: first/' sk-multi/RUNBOOK.md

# M3: an in-progress PR whose dependency is not done is an error.
sed -i 's/| 2 | second | YogliB\/ai | first | pending/| 2 | second | YogliB\/ai | first | in-progress/' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "two in-progress PRs are not reported"; fi

# M4: a pr- directory missing from the table is an error.
runbook sk-multi/pr-stray "$ROWS_ALL"
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "a stray pr- directory is not reported"; fi
rm -rf sk-multi/pr-stray

# M5: Active PR none with an unblocked pending PR names it as next.
sed -i 's/| 1 | first | YogliB\/ai | none | in-progress/| 1 | first | YogliB\/ai | none | done/' sk-multi/RUNBOOK.md
sed -i 's/| 2 | second | YogliB\/ai | first | in-progress/| 2 | second | YogliB\/ai | first | pending/' sk-multi/RUNBOOK.md
sed -i 's/^Active PR: first$/Active PR: none/' sk-multi/RUNBOOK.md
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done"
OUT=$(sh "$FS" sk-multi) || { sh "$FS" sk-multi; fail "a done-first-PR initiative is not valid"; }
echo "$OUT" | grep -q '^next-phase: start PR second$' || fail "next unblocked PR not named: $OUT"

# Usage errors.
CODE=0
sh "$FS" 2>/dev/null || CODE=$?
[ "$CODE" -eq 2 ] || fail "missing arguments do not exit 2"
CODE=0
sh "$FS" no-such-dir >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 1 ] || fail "a missing directory does not exit 1"

runbook sk-order "0:pending 1:in-progress 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
if sh "$FS" sk-order 2>"$TMP/err"; then fail "an in-progress phase after a pending phase passes"; fi

runbook sk-completed "$ROWS_ALL" completed
if sh "$FS" sk-completed 2>"$TMP/err"; then fail "a completed flow with pending phases passes"; fi

sed -i 's/| 2r | PLANNING | done/| 2r | PLANNING | pending/' sk-multi/RUNBOOK.md
OUT=$(sh "$FS" sk-multi) || fail "an initiative awaiting plan review is invalid"
echo "$OUT" | grep -q '^next: 2r$' || fail "PR work starts before initiative plan review"
sed -i 's/| 2r | PLANNING | pending/| 2r | PLANNING | done/' sk-multi/RUNBOOK.md
sed -i 's/^Status: in-progress$/Status: completed/' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "a completed initiative with pending PRs passes"; fi
sed -i 's/^Status: completed$/Status: in-progress/' sk-multi/RUNBOOK.md

sed -i 's#\[pr-second/\](pr-second/)#[pr-wrong/](pr-wrong/)#' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "a mismatched Directory passes"; fi
sed -i 's#\[pr-wrong/\](pr-wrong/)#[pr-second/](pr-second/)#' sk-multi/RUNBOOK.md
sed -i 's/| 1 | first | YogliB\/ai | none | done/| 1 | first | YogliB\/ai | none | pending/; s/| 2 | second | YogliB\/ai | first | pending/| 2 | second | YogliB\/ai | first | in-progress/; s/^Active PR: none$/Active PR: second/' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "an active PR with an unfinished dependency passes"; fi
grep -q 'dependency first is pending' "$TMP/err" || fail "the unfinished dependency is not named"
sed -i 's/| 1 | first | YogliB\/ai | none | pending/| 1 | first | YogliB\/ai | none | done/; s/| 2 | second | YogliB\/ai | first | in-progress/| 2 | second | YogliB\/ai | first | done/; s/^Active PR: second$/Active PR: none/' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "a done PR with unfinished row 6 passes"; fi
grep -q 'PR second is done but its runbook row 6 is pending' "$TMP/err" || fail "the unfinished PR runbook is not named"
sed -i 's/| 2 | second | YogliB\/ai | first | done/| 2 | second | YogliB\/ai | first | pending/' sk-multi/RUNBOOK.md
pr_row 3 second first pending >> sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "a duplicate PR slug passes"; fi

echo "test-flow-state: all tests passed"
