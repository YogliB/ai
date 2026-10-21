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

# M3: two in-progress PRs are an error.
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

# I: a row whose ID is outside the expected set is an error.
runbook sk-bad4 "$ROWS_ALL 7:pending"
if sh "$FS" sk-bad4 2>"$TMP/err"; then fail "an unexpected row ID is not reported"; fi
grep -q 'unexpected row' "$TMP/err" || fail "the unexpected row ID is not named"


# Size: light. Light flows live at .agents/flows/<slug>, receipts under .agents/receipts.
mkdir -p .agents/receipts .agents/flows
printf 'result: pass\nexit-code: 0\n' > .agents/receipts/run.receipt
printf 'result: fail\nexit-code: 1\n' > .agents/receipts/bad.receipt
LF=.agents/flows
RCPT=".agents/receipts/run.receipt"
light_runbook() { # name rows
	runbook "$LF/$1" "$2"
	sed -i 's/^Goal: test$/Goal: test/; s/^Status: \(.*\)$/Status: \1\n\nSize: light/' "$LF/$1/RUNBOOK.md"
	echo "see $RCPT" > "$LF/$1/3 - IMPLEMENTATION.md"
	echo "see $RCPT" > "$LF/$1/5 - VERIFY.md"
}
LIGHT_OK="0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:done 6:pending"

light_runbook ok "$LIGHT_OK"
OUT=$(sh "$FS" $LF/ok) || { sh "$FS" $LF/ok; fail "a valid light flow is not valid"; }
echo "$OUT" | grep -q '^size: light$' || fail "light size not reported"
echo "$OUT" | grep -q '^next: 6$' || fail "light flow next phase is not 6"
(cd / && sh "$FS" "$TMP/$LF/ok" >/dev/null) || fail "receipts do not resolve from another working directory"
sh "$FS" sk-fresh | grep -q '^size: full$' || fail "a runbook without Size is not full"

light_runbook skip "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:skipped 4:skipped 5:pending 6:pending"
if sh "$FS" $LF/skip 2>"$TMP/err"; then fail "a light flow skipping implementation passes"; fi
grep -q 'cannot skip row 3' "$TMP/err" || fail "skipped implementation not named"

light_runbook rev "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:in-progress 4:pending 5:pending 6:pending"
if sh "$FS" $LF/rev 2>"$TMP/err"; then fail "a light flow with review pending passes"; fi
grep -q 'requires row 4 skipped' "$TMP/err" || fail "unskipped review not named"

light_runbook norec5 "$LIGHT_OK"
echo "no proof" > "$LF/norec5/5 - VERIFY.md"
if sh "$FS" $LF/norec5 2>"$TMP/err"; then fail "a light verify report without a receipt passes"; fi
grep -q 'row 5 artifact cites no receipt' "$TMP/err" || fail "missing receipt not named"

light_runbook norec3 "$LIGHT_OK"
echo "no proof" > "$LF/norec3/3 - IMPLEMENTATION.md"
if sh "$FS" $LF/norec3 2>"$TMP/err"; then fail "a light implementation report without a receipt passes"; fi
grep -q 'row 3 artifact cites no receipt' "$TMP/err" || fail "missing row 3 receipt not named"

light_runbook ghost "$LIGHT_OK"
echo "see .agents/receipts/ghost.receipt" > "$LF/ghost/5 - VERIFY.md"
if sh "$FS" $LF/ghost 2>"$TMP/err"; then fail "a missing cited receipt passes"; fi
grep -q 'missing receipt' "$TMP/err" || fail "missing cited receipt not named"

light_runbook failed "$LIGHT_OK"
echo "see .agents/receipts/bad.receipt" > "$LF/failed/5 - VERIFY.md"
if sh "$FS" $LF/failed 2>"$TMP/err"; then fail "a failing receipt passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "failing receipt not named"

light_runbook blocked "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:skipped 6:pending"
rm "$LF/blocked/5 - VERIFY.md"
sh "$FS" $LF/blocked >/dev/null || fail "a light flow with blocked verify is not valid"

# The light route is closed without Size: light (the bypass), in root and PR runbooks.
runbook sk-bypass "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:pending 6:pending"
if sh "$FS" sk-bypass 2>"$TMP/err"; then fail "light-shaped skips without Size: light pass"; fi
grep -q 'without Size: light' "$TMP/err" || fail "the bypass is not named"

# Only a Size line in the header counts.
runbook sk-sizeblock "$ROWS_ALL"
printf '\n```\nSize: light\n```\n' >> sk-sizeblock/RUNBOOK.md
sh "$FS" sk-sizeblock | grep -q '^size: full$' || fail "a Size line in a code block changes the size"
runbook sk-sizefirst "$ROWS_ALL"
sed -i 's/^Goal: test$/Size: full\n\nGoal: test\n\nSize: light/' sk-sizefirst/RUNBOOK.md
sh "$FS" sk-sizefirst | grep -q '^size: full$' || fail "a Size line after the header changes the size"

# Size: light is single-PR only.
sed -i 's/^Goal: test$/Size: light\n\nGoal: test/' sk-multi/pr-first/RUNBOOK.md
sed -i 's/^Status: completed$/Status: in-progress/' sk-multi/RUNBOOK.md
if sh "$FS" sk-multi 2>"$TMP/err"; then fail "Size: light in a PR runbook passes"; fi
grep -q 'single-PR runbooks only' "$TMP/err" || fail "light in a PR runbook not named"

echo "test-flow-state: all tests passed"
