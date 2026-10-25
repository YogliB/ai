#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
FS="$REPO_ROOT/skills/sk-flow/scripts/flow-state.mjs"
run() { node "$FS" "$@"; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

mut() {
	sed "$1" "$2" >"$2.tmp" && mv "$2.tmp" "$2";
}

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

fm() {
	case $1 in
		0) echo '{"schema":"explore","slug":"x","next-step":"sk-planning","reason":"r"}' ;;
		1) echo '{"schema":"alternatives","slug":"x","options":1,"chosen":"","review":{"valid":0,"false-positive":0,"unvalidated":0}}' ;;
		2) echo '{"schema":"plan","slug":"x","decision":"proceed","todos":1,"review":{"valid":0,"false-positive":0,"unvalidated":0}}' ;;
		3) echo '{"schema":"implementation","slug":"x","branch":"b","receipts":[],"deviations":0,"plan-gaps":0}' ;;
		4) echo '{"schema":"review","slug":"x","result":"clean","passes":1,"valid":0,"false-positive":0,"unvalidated":0}' ;;
		5) echo '{"schema":"verify","slug":"x","result":"pass","receipts":[]}' ;;
		6) echo '{"schema":"pr","slug":"x","url":"u","status":"open","number":1}' ;;
	esac
}

artifact() { # dir row [frontmatter-override]
	SLUG=$(node -e 'try { process.stdout.write(require("./'"$1"'/runbook.json").slug) } catch { process.stdout.write("x") }')
	printf '<!--\n%s\n-->\n# x\n' "${3:-$(fm "$2" | sed 's/"slug":"x"/"slug":"'"$SLUG"'"/')}" > "$1/$(art_name "$2")"
}

# runbook <dir> <rows like "0:done 1:pending ..."> [status] [size]
runbook() {
	D=$1
	ROWS=$2
	STATUS=${3:-in-progress}
	SIZE=${4:-}
	SLUG=x
	case ${D##*/} in
		pr-*) SLUG=${D##*pr-} ;;
	esac
	mkdir -p "$D"
	{
		printf '{\n\t"runbook-version": 2,\n\t"slug": "%s",\n\t"status": "%s",\n\t"goal": "test",\n' "$SLUG" "$STATUS"
		[ -n "$SIZE" ] && printf '\t"size": "%s",\n' "$SIZE"
		printf '\t"phases": {\n'
		first=1
		for pair in $ROWS; do
			row=${pair%%:*}
			state=${pair##*:}
			[ "$first" = 1 ] || printf ',\n'
			first=0
			note=
			case $state in skipped | diverged | blocked) note=', "note": "test"' ;; esac
			printf '\t\t"%s": {"state": "%s"%s}' "$row" "$state" "$note"
		done
		printf '\n\t},\n\t"divergences": []\n}\n'
	} > "$D/runbook.json"
	for pair in $ROWS; do
		row=${pair%%:*}
		state=${pair##*:}
		case $state in
			done | diverged)
				case $row in *r) ;; *) artifact "$D" "$row" ;; esac ;;
			esac
	done
}

ROWS_ALL="0:pending 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"

# A: a fresh single-PR flow is valid, next phase is 0.
runbook sk-fresh "$ROWS_ALL"
OUT=$(run check sk-fresh) || fail "a fresh flow is not valid"
echo "$OUT" | grep -q '^next: 0$' || fail "a fresh flow's next phase is not 0"

# B: mid-flow, next is the in-progress row.
runbook sk-mid "0:done 1:done 1r:done 2:done 2r:done 3:in-progress 4:pending 5:pending 6:pending"
OUT=$(run check sk-mid) || fail "a mid flow is not valid"
echo "$OUT" | grep -q '^next: 3$' || fail "a mid flow's next phase is not 3: $OUT"

# C: done row with a missing artifact is an error.
runbook sk-bad1 "0:done 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
rm "sk-bad1/0 - EXPLORE.md"
if run check sk-bad1 2>"$TMP/err"; then fail "a missing artifact is not reported"; fi
grep -q 'row 0 is done but 0 - EXPLORE.md is missing' "$TMP/err" || fail "the missing artifact is not named"

# D: an artifact whose row is pending is an error.
runbook sk-bad2 "$ROWS_ALL"
artifact sk-bad2 2
if run check sk-bad2 2>"$TMP/err"; then fail "a pending row with an artifact is not reported"; fi

# E: an unexpected artifact name is an error.
runbook sk-bad3 "$ROWS_ALL"
echo x > "sk-bad3/2 - PLANNING-old.md"
if run check sk-bad3 2>"$TMP/err"; then fail "an unexpected artifact file is not reported"; fi
grep -q 'unexpected artifact file' "$TMP/err" || fail "the unexpected file is not named"

# F: two rows in progress are an error.
runbook sk-bad4 "0:done 1:in-progress 1r:pending 2:in-progress 2r:pending 3:pending 4:pending 5:pending 6:pending"
if run check sk-bad4 2>"$TMP/err"; then fail "two in-progress rows are not reported"; fi

# G: a done row after a pending one is an error.
runbook sk-bad5 "0:done 1:pending 1r:pending 2:done 2r:pending 3:pending 4:pending 5:pending 6:pending"
if run check sk-bad5 2>"$TMP/err"; then fail "a done row after a pending one is not reported"; fi

# H: a complete flow has no next phase.
runbook sk-done "0:done 1:done 1r:done 2:done 2r:done 3:done 4:done 5:done 6:done" completed
OUT=$(run check sk-done) || fail "a complete flow is not valid"
echo "$OUT" | grep -q '^next: none$' || fail "a complete flow has a next phase"

# Multi-PR helpers.
pr_json() { # indent slug order deps state
	deps=$(echo "$4" | sed 's/,/","/g')
	[ "$deps" = none ] || [ "$deps" = - ] && deps=""
	[ -n "$deps" ] && deps="\"$deps\""
	printf '%s"%s": {"order": %s, "repo": "o/r", "deps": [%s], "state": "%s", "branch": "", "base-sha": "", "head": "", "notes": "x"}' "$1" "$2" "$3" "$deps" "$5"
}

# M1: valid initiative, one in-progress PR, next phase from its runbook.
mkdir -p sk-multi/pr-first sk-multi/pr-second
{
	printf '{\n\t"runbook-version": 2,\n\t"slug": "x",\n\t"status": "in-progress",\n\t"goal": "test",\n'
	printf '\t"active-pr": "first",\n\t"phases": {\n'
	first=1
	for pair in 0:done 1:done 1r:done 2:done 2r:done; do
		row=${pair%%:*}
		state=${pair##*:}
		[ "$first" = 1 ] || printf ',\n'
		first=0
		printf '\t\t"%s": {"state": "%s"}' "$row" "$state"
	done
	printf '\n\t},\n\t"prs": {\n'
	pr_json '' first 1 none in-progress
	printf ',\n'
	pr_json '' second 2 first pending
	printf '\n\t},\n\t"divergences": []\n}\n'
} > sk-multi/runbook.json
artifact sk-multi 0
artifact sk-multi 1
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["first","second"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-multi/2 - PLANNING.md"
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:in-progress 4:pending 5:pending 6:pending"
runbook sk-multi/pr-second "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
OUT=$(run check sk-multi) || { run check sk-multi; fail "a valid initiative is not valid"; }
echo "$OUT" | grep -q '^mode: multi$' || fail "multi mode not detected"
echo "$OUT" | grep -q '^active-pr: first$' || fail "active PR not reported"
echo "$OUT" | grep -q '^next: 3$' || fail "next phase not from the active PR: $OUT"

# M2: Active PR that matches no in-progress PR is an error.
mut 's/"active-pr": "first"/"active-pr": "second"/' sk-multi/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "a wrong Active PR is not reported"; fi
mut 's/"active-pr": "second"/"active-pr": "first"/' sk-multi/runbook.json

# M3: two in-progress PRs are an error.
mut 's/"second": {"order": 2, "repo": "o\/r", "deps": \["first"\], "state": "pending"/"second": {"order": 2, "repo": "o\/r", "deps": ["first"], "state": "in-progress"/' sk-multi/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "two in-progress PRs are not reported"; fi
mut 's/"second": {"order": 2, "repo": "o\/r", "deps": \["first"\], "state": "in-progress"/"second": {"order": 2, "repo": "o\/r", "deps": ["first"], "state": "pending"/' sk-multi/runbook.json

# M4: a pr- directory missing from the table is an error.
runbook sk-multi/pr-stray "$ROWS_ALL"
if run check sk-multi 2>"$TMP/err"; then fail "a stray pr- directory is not reported"; fi
rm -rf sk-multi/pr-stray

# M5: Active PR none with an unblocked pending PR names it as next.
mut 's/"first": {"order": 1, "repo": "o\/r", "deps": \[\], "state": "in-progress"/"first": {"order": 1, "repo": "o\/r", "deps": [], "state": "done"/' sk-multi/runbook.json
mut 's/"active-pr": "first"/"active-pr": "none"/' sk-multi/runbook.json
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done"
OUT=$(run check sk-multi) || { run check sk-multi; fail "a done-first-PR initiative is not valid"; }
echo "$OUT" | grep -q '^next-phase: Implementation (PR second)$' || fail "next unblocked PR not named: $OUT"

# A done PR whose own row 6 is skipped stays valid (merged outside sk-pr).
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:skipped"
rm -f "sk-multi/pr-first/6 - PR.md"
run check sk-multi >/dev/null || { run check sk-multi 2>&1 | tail -3; fail "a done PR with a skipped row 6 is rejected"; }
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done"

# Usage errors.
CODE=0
run 2>/dev/null || CODE=$?
[ "$CODE" -eq 2 ] || fail "missing arguments do not exit 2"
CODE=0
run check no-such-dir >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 1 ] || fail "a missing directory does not exit 1"

runbook sk-order "0:pending 1:in-progress 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
if run check sk-order 2>"$TMP/err"; then fail "an in-progress phase after a pending phase passes"; fi

runbook sk-completed "$ROWS_ALL" completed
if run check sk-completed 2>"$TMP/err"; then fail "a completed flow with pending phases passes"; fi

mut 's/"2r": {"state": "done"}/"2r": {"state": "pending"}/' sk-multi/runbook.json
OUT=$(run check sk-multi) || fail "an initiative awaiting plan review is invalid"
echo "$OUT" | grep -q '^next: 2r$' || fail "PR work starts before initiative plan review"
mut 's/"2r": {"state": "pending"}/"2r": {"state": "done"}/' sk-multi/runbook.json
mut 's/"status": "in-progress"/"status": "completed"/' sk-multi/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "a completed initiative with pending PRs passes"; fi
mut 's/"status": "completed"/"status": "in-progress"/' sk-multi/runbook.json

# A missing pr- directory is an error.
mv sk-multi/pr-second sk-multi/pr-second-away
if run check sk-multi 2>"$TMP/err"; then fail "a missing PR directory is not reported"; fi
grep -q 'has no pr-.*runbook.json' "$TMP/err" || fail "the missing directory is not named"
mv sk-multi/pr-second-away sk-multi/pr-second

# An active PR with an unfinished dependency is an error.
mut 's/"first": {"order": 1, "repo": "o\/r", "deps": \[\], "state": "done"/"first": {"order": 1, "repo": "o\/r", "deps": [], "state": "pending"/' sk-multi/runbook.json
mut 's/"second": {"order": 2, "repo": "o\/r", "deps": \["first"\], "state": "pending"/"second": {"order": 2, "repo": "o\/r", "deps": ["first"], "state": "in-progress"/' sk-multi/runbook.json
mut 's/"active-pr": "none"/"active-pr": "second"/' sk-multi/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "an active PR with an unfinished dependency passes"; fi
grep -q 'dependency first is pending' "$TMP/err" || fail "the unfinished dependency is not named"
mut 's/"first": {"order": 1, "repo": "o\/r", "deps": \[\], "state": "pending"/"first": {"order": 1, "repo": "o\/r", "deps": [], "state": "done"/' sk-multi/runbook.json
mut 's/"second": {"order": 2, "repo": "o\/r", "deps": \["first"\], "state": "in-progress"/"second": {"order": 2, "repo": "o\/r", "deps": ["first"], "state": "done"/' sk-multi/runbook.json
mut 's/"active-pr": "second"/"active-pr": "none"/' sk-multi/runbook.json
runbook sk-multi/pr-second "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
if run check sk-multi 2>"$TMP/err"; then fail "a done PR with unfinished row 6 passes"; fi
grep -q 'PR second is done but its runbook row 6 is pending' "$TMP/err" || fail "the unfinished PR runbook is not named"
runbook sk-multi/pr-second "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done"

# A bad PR slug is an error.
mut 's/"second": {/"SECOND!!": {/' sk-multi/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "an invalid PR slug passes"; fi
grep -q 'invalid PR slug' "$TMP/err" || fail "the invalid slug is not named"
mut 's/"SECOND!!": {/"second": {/' sk-multi/runbook.json

# I: a row whose ID is outside the expected set is an error.
runbook sk-extra "$ROWS_ALL"
mut 's/"6": {"state": "pending"}/"6": {"state": "pending"},\n\t\t"7": {"state": "pending"}/' sk-extra/runbook.json
if run check sk-extra 2>"$TMP/err"; then fail "an unexpected row ID is not reported"; fi
grep -q 'unexpected row' "$TMP/err" || fail "the unexpected row ID is not named"

# Size: light. Light flows live at .agents/flows/<slug>, receipts under .agents/receipts.
mkdir -p .agents/receipts .agents/flows
printf 'receipt-version: 1\nlabel: t\nexit-code: 0\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: t\ncommand: true\n\n--- output (last 30 lines) ---\nok\n' > .agents/receipts/run.receipt
printf 'result: fail\nexit-code: 1\n' > .agents/receipts/bad.receipt
LF=.agents/flows
RCPT=".agents/receipts/run.receipt"
light_runbook() { # name rows
	runbook "$LF/$1" "$2" in-progress light
	artifact "$LF/$1" 3 "{\"schema\":\"implementation\",\"slug\":\"x\",\"branch\":\"b\",\"receipts\":[\"$RCPT\"],\"deviations\":0,\"plan-gaps\":0}"
	artifact "$LF/$1" 5 "{\"schema\":\"verify\",\"slug\":\"x\",\"result\":\"pass\",\"receipts\":[\"$RCPT\"]}"
}
LIGHT_OK="0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:done 6:pending"

light_runbook ok "$LIGHT_OK"
OUT=$(run check $LF/ok) || { run check $LF/ok; fail "a valid light flow is not valid"; }
echo "$OUT" | grep -q '^size: light$' || fail "light size not reported"
echo "$OUT" | grep -q '^next: 6$' || fail "light flow next phase is not 6"
(cd / && run check "$TMP/$LF/ok" >/dev/null) || fail "receipts do not resolve from another working directory"
run check sk-fresh | grep -q '^size: full$' || fail "a runbook without Size is not full"

light_runbook skip "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:skipped 4:skipped 5:pending 6:pending"
if run check $LF/skip 2>"$TMP/err"; then fail "a light flow skipping implementation passes"; fi
grep -q 'cannot skip row 3' "$TMP/err" || fail "skipped implementation not named"

light_runbook rev "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:in-progress 4:pending 5:pending 6:pending"
if run check $LF/rev 2>"$TMP/err"; then fail "a light flow with review pending passes"; fi
grep -q 'requires row 4 skipped' "$TMP/err" || fail "unskipped review not named"

light_runbook norec5 "$LIGHT_OK"
artifact $LF/norec5 5
if run check $LF/norec5 2>"$TMP/err"; then fail "a light verify report without a receipt passes"; fi
grep -q 'row 5 artifact cites no receipt' "$TMP/err" || fail "missing receipt not named"

light_runbook norec3 "$LIGHT_OK"
artifact $LF/norec3 3
if run check $LF/norec3 2>"$TMP/err"; then fail "a light implementation report without a receipt passes"; fi
grep -q 'row 3 artifact cites no receipt' "$TMP/err" || fail "missing row 3 receipt not named"

light_runbook ghost "$LIGHT_OK"
artifact $LF/ghost 5 '{"schema":"verify","slug":"x","result":"pass","receipts":[".agents/receipts/ghost.receipt"]}'
if run check $LF/ghost 2>"$TMP/err"; then fail "a missing cited receipt passes"; fi
grep -q 'missing receipt' "$TMP/err" || fail "missing cited receipt not named"

light_runbook failed "$LIGHT_OK"
artifact $LF/failed 5 '{"schema":"verify","slug":"x","result":"fail","receipts":[".agents/receipts/bad.receipt"]}'
if run check $LF/failed 2>"$TMP/err"; then fail "a failing receipt passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "failing receipt not named"

light_runbook spoof "$LIGHT_OK"
printf 'receipt-version: 1\nlabel: x\nexit-code: 1\nresult: fail\n--- output (last 30 lines) ---\nresult: pass\n' > .agents/receipts/spoof.receipt
artifact $LF/spoof 5 '{"schema":"verify","slug":"x","result":"fail","receipts":[".agents/receipts/spoof.receipt"]}'
if run check $LF/spoof 2>"$TMP/err"; then fail "a failing receipt with a spoofed output tail passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "spoofed receipt not named"

runbook sk-blank "0:done 1:done 1r:done 2:done 2r:done 3:done 4:done 5:done 6:done"
mut 's/"4": {"state": "done"}/"4": {"state": ""}/' sk-blank/runbook.json
rm -f "sk-blank/4 - REVIEW.md"
if run check sk-blank 2>"$TMP/err"; then fail "a blank state cell passes"; fi
grep -q 'must be one of\|invalid state\|no state' "$TMP/err" || fail "blank state not reported"

light_runbook blocked "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:skipped 6:pending"
rm "$LF/blocked/5 - VERIFY.md"
run check $LF/blocked >/dev/null || fail "a light flow with blocked verify is not valid"

light_runbook weasel "$LIGHT_OK"
printf 'receipt-version: 1\nlabel: t\nexit-code: 1\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: t\ncommand: true\n\n--- output (last 30 lines) ---\nok\n' > .agents/receipts/weasel.receipt
artifact $LF/weasel 5 '{"schema":"verify","slug":"x","result":"pass","receipts":[".agents/receipts/weasel.receipt"]}'
if run check $LF/weasel 2>"$TMP/err"; then fail "a receipt with result: pass but exit-code: 1 passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "the contradictory receipt is not named"

# The light route is closed without size: light.
runbook sk-bypass "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:pending 6:pending"
if run check sk-bypass 2>"$TMP/err"; then fail "light-shaped skips without size: light pass"; fi
grep -q 'without Size: light' "$TMP/err" || fail "the bypass is not named"

# An invalid size value is an error.
runbook sk-badsize "$ROWS_ALL" in-progress bogus
if run check sk-badsize 2>"$TMP/err"; then fail "an invalid size passes"; fi

# Light is single-PR only.
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done" in-progress light
if run check sk-multi 2>"$TMP/err"; then fail "size: light in a PR runbook passes"; fi
grep -q 'single-PR runbooks only' "$TMP/err" || fail "light in a PR runbook not named"
runbook sk-multi/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done"

# Legacy runbook detection.
runbook sk-legacy "$ROWS_ALL"
mv sk-legacy/runbook.json sk-legacy/RUNBOOK.md
if run check sk-legacy 2>"$TMP/err"; then fail "a legacy runbook passes"; fi
grep -q 'legacy runbook format' "$TMP/err" || fail "the legacy format is not named"

# Malformed runbook.json is an error.
mkdir -p sk-badjson
echo '{ broken' > sk-badjson/runbook.json
if run check sk-badjson 2>"$TMP/err"; then fail "malformed JSON passes"; fi
grep -q 'invalid JSON' "$TMP/err" || fail "malformed JSON is not named"

# Artifact frontmatter is enforced inside a flow.
runbook sk-nofm "$ROWS_ALL"
echo '# no frontmatter' > "sk-nofm/0 - EXPLORE.md"
if run check sk-nofm 2>"$TMP/err"; then fail "an artifact without frontmatter passes"; fi
grep -q 'missing frontmatter' "$TMP/err" || fail "missing frontmatter is not named"

runbook sk-wrongfm "$ROWS_ALL"
artifact sk-wrongfm 0 '{"schema":"pr","slug":"x","url":"u","status":"open","number":1}'
if run check sk-wrongfm 2>"$TMP/err"; then fail "a wrong-schema artifact passes"; fi
grep -q "not allowed" "$TMP/err" || fail "the schema mismatch is not named"

# check <file> validates one artifact standalone.
artifact "$TMP" 2
run check "$TMP/2 - PLANNING.md" | grep -q 'frontmatter valid' || fail "check <file> rejects a valid artifact"
printf '<!--\n{"schema":"plan","slug":"x"}\n-->\n' > "$TMP/2 - PLANNING.md"
if run check "$TMP/2 - PLANNING.md" 2>"$TMP/err"; then fail "check <file> passes an incomplete artifact"; fi
rm -f "$TMP/2 - PLANNING.md"

# CLI: init / set / pr.
run init sk-cli --slug=cli --goal="cli test" || fail "init failed"
run check sk-cli >/dev/null || fail "an init'd flow is not valid"
if run set sk-cli 0 done 2>"$TMP/err"; then fail "set done without artifact is not refused"; fi
grep -q 'refusing to write' "$TMP/err" || fail "refusal is not named"
artifact sk-cli 0
run set sk-cli 0 done >/dev/null || fail "set done after artifact is refused"
run set sk-cli 1 in-progress >/dev/null || fail "set in-progress refused"
OUT=$(run check sk-cli)
echo "$OUT" | grep -q '^next: 1$' || fail "set did not move the flow: $OUT"

# set repairs pre-existing inconsistency (warns, does not refuse).
runbook sk-repair "0:pending 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
artifact sk-repair 2
OUT=$(run set sk-repair 0 skipped --note="repair test" 2>&1) || fail "repair is refused"
echo "$OUT" | grep -q 'still invalid' || fail "the remaining error is not warned"
run set sk-repair 1 skipped --note=repair >/dev/null
run set sk-repair 1r skipped --note=repair >/dev/null
run set sk-repair 2 done >/dev/null || fail "the repair cannot finish"
OUT=$(run check sk-repair)
echo "$OUT" | grep -q '^next: 2r$' || fail "the repaired flow is still invalid"

# set --status on a finished flow.
runbook sk-fin "0:done 1:done 1r:done 2:done 2r:done 3:done 4:done 5:done 6:done"
run set sk-fin --status=completed >/dev/null || fail "set status refused on a complete flow"
OUT=$(run check sk-fin)
echo "$OUT" | grep -q '^next: none$' || fail "a completed flow has a next phase"

# set --status on an unfinished flow is refused.
runbook sk-unfin "0:done 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
if run set sk-unfin --status=completed 2>"$TMP/err"; then fail "set status on unfinished flow is not refused"; fi

# pr converts a single-PR runbook into an initiative.
runbook sk-conv "0:done 1:done 1r:done 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["first"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-conv/2 - PLANNING.md"
run pr sk-conv first --repo=o/r --init >/dev/null || fail "pr --init failed"
OUT=$(run check sk-conv) || { run check sk-conv; fail "the converted initiative is not valid"; }
echo "$OUT" | grep -q '^status: ok$' || fail "the converted initiative is not ok: $OUT"
echo "$OUT" | grep -q '^mode: multi$' || fail "pr did not convert to multi: $OUT"
[ -f sk-conv/pr-first/runbook.json ] || fail "pr --init did not scaffold the PR runbook"
grep -q '"skipped"' sk-conv/pr-first/runbook.json || fail "PR runbook rows 0-1r not skipped"

# set on a pr-<slug>/ dir uses the PR rule set: row 6 may be skipped.
artifact sk-conv/pr-first 2
run set sk-conv/pr-first 2 done 2>"$TMP/err" || fail "set on a PR runbook is refused: $(cat "$TMP/err")"
run set sk-conv/pr-first 2r done 2>"$TMP/err" || fail "set 2r on a PR runbook is refused: $(cat "$TMP/err")"
runbook sk-conv/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:pending"
artifact sk-conv/pr-first 3
artifact sk-conv/pr-first 4
artifact sk-conv/pr-first 5
run set sk-conv/pr-first 6 skipped --note="merged outside" >/dev/null || fail "a PR runbook cannot skip row 6"
OUT=$(run check sk-conv/pr-first)
echo "$OUT" | grep -q '^status: ok$' || fail "a PR runbook with row 6 skipped is not valid: $OUT"

# pr --state maintains active-pr atomically (no deadlock between the two invariants).
run set sk-conv/pr-first 6 pending >/dev/null || fail "reopening a skipped PR row refused"
run pr sk-conv first --state=in-progress >/dev/null || fail "PR activation refused"
node -e 'process.exit(require("./sk-conv/runbook.json")["active-pr"] === "first" ? 0 : 1)' ||
	fail "active-pr not set on activation"
run pr sk-conv first --state=pending >/dev/null || fail "deactivation to pending refused"
node -e 'process.exit(require("./sk-conv/runbook.json")["active-pr"] === "none" ? 0 : 1)' ||
	fail "active-pr not cleared on pending"
run pr sk-conv first --state=in-progress >/dev/null || fail "PR re-activation refused"
artifact sk-conv/pr-first 6
run set sk-conv/pr-first 6 done >/dev/null || fail "completing PR row 6 refused"
run pr sk-conv first --state=done --notes="o/r#1" >/dev/null || fail "PR completion refused"
node -e 'process.exit(require("./sk-conv/runbook.json")["active-pr"] === "none" ? 0 : 1)' ||
	fail "active-pr not cleared on completion"

# pr activation refuses while initiative rows are unfinished; slug none is reserved; pending clears active-pr.
runbook sk-early "0:done 1:done 1r:done 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
run pr sk-early first --repo=o/r --init >/dev/null || fail "pr --init failed"
if run pr sk-early first --state=in-progress 2>"$TMP/err"; then fail "activation before initiative phases finish is not refused"; fi
grep -q 'cannot start before initiative phases finish' "$TMP/err" || fail "the guard is not named"
if run pr sk-early none --repo=o/r 2>"$TMP/err"; then fail "reserved slug none is not refused"; fi

# set --size transitions atomically.
runbook sk-sizedown "0:pending 1:pending 1r:pending 2:done 2r:pending 3:pending 4:pending 5:pending 6:pending"
run set sk-sizedown --size=light >/dev/null || fail "full to light refused"
node -e 'const p = require("./sk-sizedown/runbook.json").phases; process.exit(p["4"].state === "skipped" && p["2r"].state === "skipped" ? 0 : 1)' ||
	fail "light rows not skipped"
OUT=$(run check sk-sizedown)
echo "$OUT" | grep -q '^size: light$' || fail "size not reported: $OUT"
runbook sk-sizeup "0:skipped 1:skipped 1r:skipped 2:done 2r:skipped 3:done 4:skipped 5:pending 6:pending" in-progress light
run set sk-sizeup --size=full >/dev/null || fail "light to full refused"
node -e 'process.exit(require("./sk-sizeup/runbook.json").phases["4"].state === "pending" ? 0 : 1)' ||
	fail "light rows not unskipped"
OUT=$(run check sk-sizeup)
echo "$OUT" | grep -q '^next: 0$' || fail "unskipped rows not pending: $OUT"
runbook sk-nolight "0:pending 1:pending 1r:pending 2:done 2r:pending 3:done 4:done 5:pending 6:pending"
artifact sk-nolight 4
if run set sk-nolight --size=light 2>"$TMP/err"; then fail "light with done rows is not refused"; fi

# skipped/diverged require --note.
if run set sk-cli 1 skipped 2>"$TMP/err"; then fail "skipped without --note is not refused"; fi
grep -q 'requires --note' "$TMP/err" || fail "the note requirement is not named"
if run set sk-cli 1 diverged 2>"$TMP/err"; then fail "diverged without --note is not refused"; fi

# init --at beyond 2 is refused (row 2 cannot be skipped); init inside a pr-* dir is refused.
if run init sk-badat --slug=badat --goal=g --at=3 2>"$TMP/err"; then fail "init --at=3 is not refused"; fi
mkdir -p pr-x && if run init pr-x --slug=x --goal=g 2>"$TMP/err"; then fail "init inside a pr-* dir is not refused"; fi

# set <row> pending reopens a finished row (ordering + artifact exemptions) but blocks completed.
runbook sk-roll "0:done 1:done 1r:done 2:done 2r:done 3:done 4:done 5:done 6:pending"
run set sk-roll 2 pending >/dev/null || fail "reopen to pending refused"
OUT=$(run check sk-roll)
echo "$OUT" | grep -q '^next: 2$' || fail "the reopened row is not next: $OUT"
if run set sk-roll --status=completed 2>"$TMP/err"; then fail "completed with a reopened row is not refused"; fi

# an artifact slug that disagrees with the runbook is an error.
runbook sk-slugx "0:done 1:pending 1r:pending 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"explore","slug":"other","next-step":"sk-planning","reason":"r"}\n-->\n# x\n' > "sk-slugx/0 - EXPLORE.md"
if run check sk-slugx 2>"$TMP/err"; then fail "a mismatched artifact slug passes"; fi
grep -q "does not match runbook slug" "$TMP/err" || fail "the slug mismatch is not named"

# conversion refuses when a dropped row is not pending/skipped.
runbook sk-convbad "0:done 1:done 1r:done 2:done 2r:done 3:in-progress 4:pending 5:pending 6:pending"
artifact sk-convbad 3
if run pr sk-convbad first --repo=o/r 2>"$TMP/err"; then fail "conversion with an in-progress row is not refused"; fi
grep -q 'cannot convert' "$TMP/err" || fail "the conversion guard is not named"

# dependency self-reference and cycles are errors.
runbook sk-cyc "0:done 1:done 1r:done 2:done 2r:done" in-progress
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["a","b"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-cyc/2 - PLANNING.md"
artifact sk-cyc 0
artifact sk-cyc 1
if run pr sk-cyc a --repo=o/r --deps=a 2>"$TMP/err"; then fail "self-dep is not refused"; fi
grep -q 'depends on itself' "$TMP/err" || fail "self-dep is not named"
run pr sk-cyc a --repo=o/r --init >/dev/null || fail "pr a refused"
run pr sk-cyc b --repo=o/r --init >/dev/null || fail "pr b refused"
node -e 'const fs = require("fs"); const rb = require("./sk-cyc/runbook.json"); rb.prs.a.deps = ["b"]; rb.prs.b.deps = ["a"]; fs.writeFileSync("./sk-cyc/runbook.json", JSON.stringify(rb, null, "\t"))'
if run check sk-cyc 2>"$TMP/err"; then fail "a dependency cycle passes"; fi
grep -q 'dependency cycle' "$TMP/err" || fail "the cycle is not named"

# init --at skips earlier rows; init --size=light applies the light transition.
run init sk-at --slug=at --goal="standalone plan" --at=2 >/dev/null || fail "init --at refused"
node -e 'const p = require("./sk-at/runbook.json").phases; process.exit(p["0"].state === "skipped" && p["1r"].state === "skipped" && p["2"].state === "pending" ? 0 : 1)' ||
	fail "init --at did not skip earlier rows"
run set sk-at 2 in-progress >/dev/null || fail "standalone entry cannot start"
run init sk-lt --slug=lt --goal="light" --size=light >/dev/null || fail "init light refused"
OUT=$(run check sk-lt)
echo "$OUT" | grep -q '^status: ok$' || fail "an init'd light flow is invalid: $OUT"

# masterplan prs: incremental pr adds are subset-consistent, ghost PRs refused.
runbook sk-mp "0:done 1:done 1r:done 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["first","second"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-mp/2 - PLANNING.md"
run pr sk-mp first --repo=o/r --init >/dev/null || fail "incremental pr add refused"
run pr sk-mp second --repo=o/r --init >/dev/null || fail "second pr add refused"
if run pr sk-mp third --repo=o/r 2>"$TMP/err"; then fail "a ghost PR is not refused"; fi
grep -q 'not in masterplan' "$TMP/err" || fail "the ghost PR is not named"
mut 's/"prs":\["first","second"\]/"prs":["first","second","ghost"]/' "sk-mp/2 - PLANNING.md"
if run check sk-mp 2>"$TMP/err"; then fail "an unscaffolded masterplan PR passes"; fi
grep -q 'has no pr-ghost/ directory' "$TMP/err" || fail "the unscaffolded PR is not named"

# mixed row+field flags and unknown flags are rejected.
if run set sk-conv/pr-first 6 done --status=completed 2>"$TMP/err"; then fail "mixed row+status set is not refused"; fi
grep -q 'inapplicable flag' "$TMP/err" || fail "the flag rejection is not named"
if run set sk-cli --bogus=1 2>"$TMP/err"; then fail "an unknown flag is not refused"; fi
if run init sk-bad --slug=bad 2>"$TMP/err"; then fail "init without --goal is not refused"; fi
if run init sk-bad --slug=bad --goal=g --size=huge 2>"$TMP/err"; then fail "init with a bad --size is not refused"; fi

# A scalar runbook.json reports a schema error instead of crashing.
mkdir -p sk-scalar
echo '5' > sk-scalar/runbook.json
if run check sk-scalar 2>"$TMP/err"; then fail "a scalar runbook passes"; fi
grep -q 'expected object, got number' "$TMP/err" || fail "the scalar runbook is not diagnosed: $(cat "$TMP/err")"
echo 'null' > sk-scalar/runbook.json
if run check sk-scalar 2>"$TMP/err"; then fail "a null runbook passes"; fi
grep -q 'expected object, got null' "$TMP/err" || fail "the null runbook is not diagnosed: $(cat "$TMP/err")"

# A malformed pr-*/runbook.json reports invalid JSON instead of crashing on `in`.
printf '{' > sk-multi/pr-second/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "a malformed PR runbook passes"; fi
grep -q 'invalid JSON' "$TMP/err" || fail "the malformed PR runbook is not diagnosed: $(cat "$TMP/err")"
! grep -qE 'Cannot use|Cannot read|not iterable|Cannot create' "$TMP/err" || fail "the malformed PR runbook crashes"
runbook sk-multi/pr-second "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:done"
run check sk-multi >/dev/null || fail "the repaired initiative is invalid"

# A child runbook schema error keeps the PR <slug> prefix.
mut 's/"slug": "second"/"slug": "BAD SLUG"/' sk-multi/pr-second/runbook.json
if run check sk-multi 2>"$TMP/err"; then fail "a bad child slug passes"; fi
grep -q 'PR second' "$TMP/err" || fail "the child runbook error loses its prefix: $(cat "$TMP/err")"
mut 's/"slug": "BAD SLUG"/"slug": "second"/' sk-multi/pr-second/runbook.json

# init --at=0 is a normal start and records no divergence.
run init sk-at0 --slug=at0 --goal=g --at=0 >/dev/null || fail "init --at=0 refused"
node -e 'const rb = require("./sk-at0/runbook.json"); process.exit(rb.divergences.length === 0 && rb.phases["0"].state === "pending" ? 0 : 1)' ||
	fail "init --at=0 records a divergence or skips row 0"

# plan decision split / masterplan doc in a single-PR runbook are errors.
runbook sk-split "0:done 1:done 1r:done 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"plan","slug":"x","decision":"split","todos":1,"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-split/2 - PLANNING.md"
if run check sk-split 2>"$TMP/err"; then fail "an unconverted split decision passes"; fi
grep -q "decision 'split' requires converting" "$TMP/err" || fail "the split guard is not named"
runbook sk-mpsingle "0:done 1:done 1r:done 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["a"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-mpsingle/2 - PLANNING.md"
if run check sk-mpsingle 2>"$TMP/err"; then fail "a masterplan in a single-PR runbook passes"; fi
grep -q 'masterplan requires an initiative runbook' "$TMP/err" || fail "the masterplan guard is not named"

# A cited receipt path that is a directory is a missing receipt, not a crash.
mkdir -p .agents/receipts/dir.receipt
light_runbook dirrec "$LIGHT_OK"
artifact $LF/dirrec 5 '{"schema":"verify","slug":"x","result":"pass","receipts":[".agents/receipts/dir.receipt"]}'
if run check $LF/dirrec 2>"$TMP/err"; then fail "a directory receipt passes"; fi
grep -q 'missing receipt' "$TMP/err" || fail "the directory receipt is not diagnosed: $(cat "$TMP/err")"
! grep -q 'EISDIR' "$TMP/err" || fail "the directory receipt crashes"

# Prototype-named slugs do not bypass prs lookups.
runbook sk-ctor "0:done 1:done 1r:done 2:done 2r:done"
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["constructor"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-ctor/2 - PLANNING.md"
if run pr sk-ctor constructor 2>"$TMP/err"; then fail "a prototype-named slug skips --repo"; fi
grep -q '\-\-repo is required' "$TMP/err" || fail "the repo requirement is not enforced"
run pr sk-ctor constructor --repo=o/r --init >/dev/null || fail "a prototype-named slug is not usable"
run check sk-ctor >/dev/null || fail "a prototype-named PR breaks check"
touch sk-ctor/pr-loose
if run check sk-ctor 2>"$TMP/err"; then fail "a stray pr-* file is not reported"; fi
grep -q 'is not a directory' "$TMP/err" || fail "the stray file is not diagnosed: $(cat "$TMP/err")"
rm sk-ctor/pr-loose

# A pr-* entry inside a single-PR flow or a PR dir is unexpected.
runbook sk-stray "$ROWS_ALL"
mkdir sk-stray/pr-ghost
if run check sk-stray 2>"$TMP/err"; then fail "a pr-* dir in a single flow passes"; fi
grep -q 'unexpected pr-\* entry' "$TMP/err" || fail "the stray entry is not named"
rmdir sk-stray/pr-ghost
mkdir sk-ctor/pr-constructor/pr-nested
if run check sk-ctor 2>"$TMP/err"; then fail "a nested pr-* dir passes"; fi
rmdir sk-ctor/pr-constructor/pr-nested

# A child runbook whose slug differs from its prs key is an error.
mut 's/"slug": "constructor"/"slug": "other"/' sk-ctor/pr-constructor/runbook.json
if run check sk-ctor 2>"$TMP/err"; then fail "a mismatched child slug passes"; fi
grep -q "runbook.json slug is 'other'" "$TMP/err" || fail "the child slug mismatch is not named"
mut 's/"slug": "other"/"slug": "constructor"/' sk-ctor/pr-constructor/runbook.json

# Non-object phases/prs/divergences are normalized for repair, not crashed or corrupted.
runbook sk-oddball "$ROWS_ALL"
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.phases = []; rb.divergences = "x"; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb, null, "\t"))'
run set sk-oddball --status=blocked >/dev/null 2>&1 || fail "set on non-object phases crashes or is refused"
node -e 'const rb = require("./sk-oddball/runbook.json"); process.exit(!Array.isArray(rb.phases) && Array.isArray(rb.divergences) ? 0 : 1)' ||
	fail "non-object fields are not normalized"
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.phases = {}; for (const r of ["0","1","1r","2","2r"]) rb.phases[r] = {state:"done"}; rb["active-pr"] = "none"; rb.prs = []; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb, null, "\t"))'
artifact sk-oddball 0
artifact sk-oddball 1
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["a"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-oddball/2 - PLANNING.md"
run pr sk-oddball a --repo=o/r --init >/dev/null 2>&1 || fail "pr on an array prs crashes or is refused"
node -e 'const rb = require("./sk-oddball/runbook.json"); process.exit(!Array.isArray(rb.prs) && Object.hasOwn(rb.prs, "a") ? 0 : 1)' ||
	fail "array prs is not normalized to an object"

# A canceled PR may leave the masterplan; --order sets and duplicates are flagged.
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["a","b"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-oddball/2 - PLANNING.md"
run pr sk-oddball b --repo=o/r --init >/dev/null || fail "adding PR b refused"
run pr sk-oddball b --state=canceled >/dev/null || fail "canceling a PR refused"
mut 's/"prs":\["a","b"\]/"prs":["a"]/' "sk-oddball/2 - PLANNING.md"
run check sk-oddball >/dev/null || { run check sk-oddball; fail "a canceled PR outside the masterplan is invalid"; }
run pr sk-oddball a --order=3 >/dev/null || fail "pr --order refused"
node -e 'process.exit(require("./sk-oddball/runbook.json").prs.a.order === 3 ? 0 : 1)' ||
	fail "--order did not set the order"
if run pr sk-oddball a --order=0 2>"$TMP/err"; then fail "--order=0 is not refused"; fi
mut 's/"prs":\["a"\]/"prs":["a","c"]/' "sk-oddball/2 - PLANNING.md"
if run pr sk-oddball c --repo=o/r --order=3 2>"$TMP/err"; then fail "a duplicate --order is not refused"; fi
grep -q 'duplicate PR order' "$TMP/err" || fail "duplicate orders are not named"

# null/non-object phases report schema errors instead of crashing.
runbook sk-np "$ROWS_ALL"
node -e 'const fs = require("fs"); const rb = require("./sk-np/runbook.json"); rb.phases = null; fs.writeFileSync("./sk-np/runbook.json", JSON.stringify(rb))'
if run check sk-np 2>"$TMP/err"; then fail "null phases passes"; fi
grep -q 'expected object, got null' "$TMP/err" || fail "null phases is not diagnosed: $(cat "$TMP/err")"
! grep -qE 'Cannot use|Cannot read|not iterable|Cannot create' "$TMP/err" || fail "null phases crashes"
node -e 'const fs = require("fs"); const rb = require("./sk-np/runbook.json"); rb.phases = {"0": "done"}; fs.writeFileSync("./sk-np/runbook.json", JSON.stringify(rb))'
if run check sk-np 2>"$TMP/err"; then fail "a scalar row passes"; fi
grep -q 'is not an object' "$TMP/err" || fail "the scalar row is not diagnosed: $(cat "$TMP/err")"
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a = "x"; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'
run pr sk-oddball a --repo=o/r >/dev/null 2>&1 || fail "a scalar prs entry cannot be repaired"
node -e 'const rb = require("./sk-oddball/runbook.json"); process.exit(typeof rb.prs.a === "object" ? 0 : 1)' ||
	fail "the scalar prs entry is not repaired"
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a = null; rb.status = "completed"; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'
if run check sk-oddball 2>"$TMP/err"; then fail "a null prs entry with completed status passes"; fi
! grep -qE 'Cannot use|Cannot read|not iterable|Cannot create' "$TMP/err" || fail "the null prs entry crashes"
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a = {order:3, repo:"o/r", deps:[], state:"pending", branch:"", "base-sha":"", head:"", notes:""}; rb.status = "in-progress"; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a.deps = 5; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'
if run check sk-oddball 2>"$TMP/err"; then fail "a scalar deps passes"; fi
! grep -qE 'Cannot use|Cannot read|not iterable|Cannot create' "$TMP/err" || fail "the scalar deps crashes: $(cat "$TMP/err")"
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a.deps = []; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'

# masterplan prs order must match runbook order (live slugs only).
if run pr sk-oddball c --repo=o/r --order=1 2>"$TMP/err"; then fail "an order reordering the masterplan is not refused"; fi
grep -q 'does not match runbook order' "$TMP/err" || fail "the order drift is not named"
mut 's/"prs":\["a","c"\]/"prs":["c","a"]/' "sk-oddball/2 - PLANNING.md"
run pr sk-oddball c --repo=o/r --order=1 --init >/dev/null || fail "reordering with masterplan agreement refused"
run check sk-oddball >/dev/null || { run check sk-oddball; fail "the reordered initiative is invalid"; }

# A non-string receipt entry is a validation error, not a crash.
light_runbook nstr "$LIGHT_OK"
artifact $LF/nstr 5 '{"schema":"verify","slug":"x","result":"pass","receipts":[5]}'
if run check $LF/nstr 2>"$TMP/err"; then fail "a non-string receipt passes"; fi
grep -q 'non-string receipt' "$TMP/err" || fail "the non-string receipt is not diagnosed: $(cat "$TMP/err")"
! grep -qE 'Cannot use|Cannot read|not iterable|Cannot create' "$TMP/err" || fail "the non-string receipt crashes"

# blocked requires a reason (row --note, PR --notes); pending from blocked is not a reopen.
run set sk-cli 1 blocked --note="dep missing" >/dev/null || fail "blocked with --note refused"
if run set sk-cli 1 blocked --note= 2>"$TMP/err"; then fail "an empty --note wipes the blocker"; fi
run set sk-cli 1 pending >/dev/null || fail "resuming a blocked row refused"
if run set sk-cli 2 done 2>"$TMP/err"; then fail "a later row completes while a paused row stays pending"; fi
run set sk-cli 1 in-progress >/dev/null
run set sk-cli 1 skipped --note="not needed" >/dev/null
if run set sk-cli 2r blocked 2>"$TMP/err"; then fail "blocked without --note is not refused"; fi
grep -q 'requires --note' "$TMP/err" || fail "the blocked note requirement is not named"
if run pr sk-oddball a --state=blocked 2>"$TMP/err"; then fail "PR blocked without --notes is not refused"; fi
grep -q 'requires --notes' "$TMP/err" || fail "the PR notes requirement is not named"
run pr sk-oddball a --state=blocked --notes="dep missing" >/dev/null || fail "PR blocked with --notes refused"
run pr sk-oddball a --state=pending >/dev/null

# A canceled PR's order does not collide with live PRs.
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.b.order = rb.prs.a.order; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'
run check sk-oddball >/dev/null || { run check sk-oddball; fail "a canceled PR's order collides with live PRs"; }
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a.order = rb.prs.c.order; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'
if run check sk-oddball 2>"$TMP/err"; then fail "duplicate live orders pass"; fi
node -e 'const fs = require("fs"); const rb = require("./sk-oddball/runbook.json"); rb.prs.a.order = 3; fs.writeFileSync("./sk-oddball/runbook.json", JSON.stringify(rb))'

# check side: a hand-edited blocked row or PR without a reason is an error.
runbook sk-bnote "$ROWS_ALL"
node -e 'const fs = require("fs"); const f = "sk-bnote/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.phases["1"] = {state: "blocked"}; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-bnote 2>"$TMP/err"; then fail "a noteless blocked row passes check"; fi
grep -q 'blocked without a note' "$TMP/err" || fail "the missing blocker note is not named"
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.second.state = "blocked"; r.prs.second.notes = ""; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-multi 2>"$TMP/err"; then fail "a noteless blocked PR passes check"; fi
grep -q 'blocked without notes' "$TMP/err" || fail "the missing PR blocker is not named"
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.second.state = "pending"; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-multi 2>"$TMP/err"; then fail "a pending PR with a finished runbook passes"; fi
grep -q 'is pending but its runbook row 6 is done' "$TMP/err" || fail "the finished-runbook mismatch is not named"
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.second.state = "done"; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-multi 2>"$TMP/err"; then fail "a done PR without notes passes check"; fi
grep -q 'done without notes' "$TMP/err" || fail "the missing done notes are not named"
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.second.notes = "x"; fs.writeFileSync(f, JSON.stringify(r))'

# A flag-less pr update on an existing row is refused like set's nothing-to-update.
if run pr sk-multi first 2>"$TMP/err"; then fail "a flag-less pr update is not refused"; fi
grep -q 'nothing to update' "$TMP/err" || fail "the no-op pr update is not named"

# init --at on a row light mode skips is refused; --at=2 still composes.
if run init sk-badlt --slug=badlt --goal=g --size=light --at=1 2>"$TMP/err"; then fail "init --at=1 --size=light is not refused"; fi
run init sk-oklt --slug=oklt --goal=g --size=light --at=2 >/dev/null || fail "init --at=2 --size=light refused"
run check sk-oklt >/dev/null || fail "a light flow entered at row 2 is invalid"

# A legacy RUNBOOK.md next to runbook.json is reported, not ignored.
runbook sk-legacy2 "$ROWS_ALL"
echo x > sk-legacy2/RUNBOOK.md
if run check sk-legacy2 2>"$TMP/err"; then fail "RUNBOOK.md next to runbook.json is not reported"; fi
grep -q 'RUNBOOK.md' "$TMP/err" || fail "the stale RUNBOOK.md is not named"
rm sk-legacy2/RUNBOOK.md
run check sk-legacy2 >/dev/null || fail "a clean flow fails after RUNBOOK.md removal"

# A pr- dir whose runbook slug disagrees is an error even standalone.
runbook sk-mismatch/pr-foo "$ROWS_ALL"
mut 's/"slug": "foo"/"slug": "bar"/' sk-mismatch/pr-foo/runbook.json
if run check sk-mismatch/pr-foo 2>"$TMP/err"; then fail "a pr- dir whose slug disagrees passes"; fi
grep -q 'does not match directory' "$TMP/err" || fail "the dir/slug mismatch is not named"

# Prototype-named slugs reach the override/masterplan lookups via own-property checks.
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.toString = {order: 4, repo: "o/r", deps: [], state: "pending", branch: "", "base-sha": "", head: "", notes: ""}; fs.writeFileSync(f, JSON.stringify(r))'
mut 's/"prs":\["first","second"\]/"prs":["first","second","constructor"]/' 'sk-multi/2 - PLANNING.md'
if run check sk-multi 2>"$TMP/err"; then fail "prototype-named lookups are skipped"; fi
grep -q 'PR toString has no pr-toString/runbook.json' "$TMP/err" || fail "the prototype-named PR is misdiagnosed: $(cat "$TMP/err")"
grep -q 'masterplan PR constructor has no pr-constructor/ directory' "$TMP/err" || fail "the prototype-named dir is not named: $(cat "$TMP/err")"

# A broken pr-* symlink is a diagnostic, not a crash.
ln -s /nonexistent-target sk-multi/pr-dead
if run check sk-multi 2>"$TMP/err"; then fail "a broken pr- symlink passes"; fi
grep -q 'pr-dead is not a directory' "$TMP/err" || fail "the broken symlink is not diagnosed: $(cat "$TMP/err")"
rm sk-multi/pr-dead

# pr repairs a missing active-pr field instead of warning forever.
node -e 'const fs = require("fs"); const f = "sk-oddball/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); delete r["active-pr"]; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-oddball 2>"$TMP/err"; then fail "a missing active-pr is not reported"; fi
run pr sk-oddball a --state=pending >/dev/null || fail "pr on a missing-active-pr initiative is refused"
run check sk-oddball >/dev/null || { run check sk-oddball; fail "the repaired initiative still fails"; }

# A frontmatter schema name must be one of the shipped schemas.
printf '<!--\n{"schema":"../../x"}\n-->\n' > "$TMP/evil.md"
if run check "$TMP/evil.md" 2>"$TMP/err"; then fail "a traversal schema name passes"; fi
grep -q 'unknown schema' "$TMP/err" || fail "the bad schema name is not diagnosed: $(cat "$TMP/err")"

# A standalone pr- dir holding an initiative runbook is an error.
runbook sk-mismatch2/pr-bar "$ROWS_ALL"
node -e 'const fs = require("fs"); const f = "sk-mismatch2/pr-bar/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs = {a: {order: 1, repo: "o/r", deps: [], state: "pending", branch: "", "base-sha": "", head: "", notes: ""}}; r["active-pr"] = "none"; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-mismatch2/pr-bar 2>"$TMP/err"; then fail "an initiative runbook inside a pr- dir passes standalone"; fi
grep -q 'initiative runbook' "$TMP/err" || fail "the embedded initiative is not named"

# set writes a runbook next to RUNBOOK.md but keeps the stale-file warning.
runbook sk-legacy3 "$ROWS_ALL"
echo x > sk-legacy3/RUNBOOK.md
OUT=$(run set sk-legacy3 --goal=g2 2>&1) || fail "set is refused on a runbook next to RUNBOOK.md"
echo "$OUT" | grep -q 'RUNBOOK.md' || fail "the stale RUNBOOK.md warning is dropped"

# pr --init refuses cleanly when pr-<slug> exists as a file.
run init sk-fpr --slug=fpr --goal=g >/dev/null
run pr sk-fpr first --repo=o/r --init >/dev/null || fail "scaffolding the first PR is refused"
touch sk-fpr/pr-ghost
OUT=$(run pr sk-fpr ghost --repo=o/r --init 2>&1) && fail "pr --init over a pr-* file is not refused"
echo "$OUT" | grep -q 'not a directory' || fail "the pr-* file is not diagnosed: $OUT"
echo "$OUT" | grep -q 'EEXIST' && fail "pr --init crashes on a pr-* file"
true

# A dependency on a later-ordered PR is an error.
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.second.deps = ["toString"]; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-multi 2>"$TMP/err"; then fail "a dependency on a later PR passes"; fi
grep -q 'not earlier in order' "$TMP/err" || fail "the dep order violation is not named"
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.second.deps = ["first"]; fs.writeFileSync(f, JSON.stringify(r))'

# Missing or corrupt schemas report a diagnostic, not a stack trace.
SCD=$(dirname "$FS")/../schemas
mv "$SCD" "$SCD-x"
CODE=0
OUT=$(run check sk-fresh 2>&1) || CODE=$?
mv "$SCD-x" "$SCD"
[ "$CODE" -eq 1 ] || fail "missing schemas do not exit 1"
echo "$OUT" | grep -q 'flow-state:' || fail "missing schemas print no diagnostic"
echo "$OUT" | grep -q 'at \|node:internal' && fail "missing schemas print a stack trace"
true

# An entry literally named pr- is flagged in both modes.
touch sk-fresh/pr-
if run check sk-fresh 2>"$TMP/err"; then fail "a bare pr- entry passes in a single flow"; fi
grep -q 'unexpected pr-\* entry: pr-' "$TMP/err" || fail "the bare pr- entry is not named"
rm sk-fresh/pr-
mkdir sk-multi/pr-
if run check sk-multi 2>"$TMP/err"; then fail "a bare pr- dir passes in an initiative"; fi
grep -q 'directory pr- is not in the pull requests table' "$TMP/err" || fail "the bare pr- dir is not named"
rmdir sk-multi/pr-

# A done PR cannot have an unfinished dependency.
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.first.state = "pending"; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-multi 2>"$TMP/err"; then fail "a done PR with a pending dependency passes"; fi
grep -q 'PR second is done but dependency first is pending' "$TMP/err" || fail "the done-with-pending-dep is not named"
node -e 'const fs = require("fs"); const f = "sk-multi/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.first.state = "done"; fs.writeFileSync(f, JSON.stringify(r))'

# pr --state=done requires --notes; a bare path is a usage error.
if run pr sk-oddball c --state=done 2>"$TMP/err"; then fail "PR done without --notes is not refused"; fi
grep -q 'requires --notes' "$TMP/err" || fail "the done notes requirement is not named: $(cat "$TMP/err")"
CODE=0
run sk-fresh >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 2 ] || fail "a bare path is not a usage error"

# init --at=1r is refused: review rows share artifacts with their doc row.
if run init sk-badat2 --slug=badat2 --goal=g --at=1r 2>"$TMP/err"; then fail "init --at=1r is not refused"; fi
grep -q 'at must be one of 0|1|2' "$TMP/err" || fail "the --at allowlist is not named"

# An unreadable receipt is a failed check, not a crash.
light_runbook unread "$LIGHT_OK"
printf 'receipt-version: 1\nlabel: t\nexit-code: 0\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: t\ncommand: true\n\n--- output (last 30 lines) ---\nok\n' > .agents/receipts/unread.receipt
chmod 000 .agents/receipts/unread.receipt
artifact $LF/unread 5 '{"schema":"verify","slug":"x","result":"pass","receipts":[".agents/receipts/unread.receipt"]}'
if run check $LF/unread 2>"$TMP/err"; then fail "an unreadable receipt passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "the unreadable receipt is not diagnosed: $(cat "$TMP/err")"
chmod 644 .agents/receipts/unread.receipt

# A plan with decision 'split' inside a PR runbook is an error.
printf '<!--\n{"schema":"plan","slug":"first","decision":"split","todos":1,"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-multi/pr-first/2 - PLANNING.md"
if run check sk-multi 2>"$TMP/err"; then fail "a split plan inside a PR passes"; fi
grep -q 'not valid in a PR runbook' "$TMP/err" || fail "the sub-plan split is not named"
artifact sk-multi/pr-first 2

# A pending PR reports its runbook's next row, not a hardcoded row 2.
rm "sk-conv/pr-first/6 - PR.md"
node -e 'const fs = require("fs"); const f = "sk-conv/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.first.state = "pending"; fs.writeFileSync(f, JSON.stringify(r))'
runbook sk-conv/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:in-progress 6:pending"
OUT=$(run check sk-conv) || { run check sk-conv; fail "a pending PR with an advanced runbook is invalid"; }
echo "$OUT" | grep -q '^next: 5$' || fail "the pending PR's next row is not its runbook row: $OUT"
echo "$OUT" | grep -q '(PR first)' || fail "the pending PR is not named: $OUT"
runbook sk-conv/pr-first "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:skipped"

# A live PR whose runbook has no remaining rows is an error.
if run check sk-conv 2>"$TMP/err"; then fail "a pending PR with a terminal runbook passes"; fi
grep -q 'has no pending rows' "$TMP/err" || fail "the terminal runbook is not named"
node -e 'const fs = require("fs"); const f = "sk-conv/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.first.state = "done"; fs.writeFileSync(f, JSON.stringify(r))'
run check sk-conv >/dev/null || { run check sk-conv; fail "the finished initiative is invalid"; }

# A live PR cannot depend on a canceled PR.
node -e 'const fs = require("fs"); const f = "sk-oddball/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.a.deps = ["b"]; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-oddball 2>"$TMP/err"; then fail "a dependency on a canceled PR passes"; fi
grep -q 'depends on canceled PR b' "$TMP/err" || fail "the canceled dependency is not named"
node -e 'const fs = require("fs"); const f = "sk-oddball/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.prs.a.deps = []; fs.writeFileSync(f, JSON.stringify(r))'

# init --at=0 composes with --size=light (a documented no-op).
run init sk-lt0 --slug=lt0 --goal=g --size=light --at=0 >/dev/null || fail "init --at=0 --size=light refused"
run check sk-lt0 >/dev/null || fail "a light flow entered at 0 is invalid"

# A flag named __proto__ is not silently swallowed.
if run check sk-lt0 --__proto__=x 2>"$TMP/err"; then fail "a __proto__ flag passes"; fi

# A key named like an Object member cannot evade additionalProperties.
node -e 'const fs = require("fs"); const f = "sk-lt0/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r["constructor"] = 1; fs.writeFileSync(f, JSON.stringify(r))'
if run check sk-lt0 2>"$TMP/err"; then fail "a prototype-named runbook key passes"; fi
grep -q "unexpected key 'constructor'" "$TMP/err" || fail "the unexpected key is not named"
node -e 'const fs = require("fs"); const f = "sk-lt0/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); delete r["constructor"]; fs.writeFileSync(f, JSON.stringify(r))'

# A file named like an Object member is diagnosed, not crashed on.
printf '<!--\n{"schema":"runbook"}\n-->\n# x\n' > sk-lt0/constructor
if run check sk-lt0/constructor 2>"$TMP/err"; then fail "a prototype-named file passes"; fi
grep -q 'flow-state:' "$TMP/err" || fail "the prototype-named file crashes"
rm sk-lt0/constructor

# A masterplan-listed PR can be added without --init and scaffolded later.
runbook sk-defer "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["a"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-defer/2 - PLANNING.md"
run pr sk-defer a --repo=o/r >/dev/null || fail "a masterplan-listed PR cannot be added without --init"
if run check sk-defer 2>"$TMP/err"; then fail "an unscaffolded listed PR passes"; fi
run pr sk-defer a --init >/dev/null || fail "deferred --init refused"
run check sk-defer >/dev/null || { run check sk-defer; fail "the deferred scaffold is invalid"; }

# A PR cannot be marked done before its runbook exists (the --init repair would deadlock).
runbook sk-d2 "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:pending 4:pending 5:pending 6:pending"
printf '<!--\n{"schema":"masterplan","slug":"x","decision":"split","prs":["a"],"review":{"valid":0,"false-positive":0,"unvalidated":0}}\n-->\n# x\n' > "sk-d2/2 - PLANNING.md"
run pr sk-d2 a --repo=o/r >/dev/null
if run pr sk-d2 a --state=done --notes="o/r#1" 2>"$TMP/err"; then fail "done on an unscaffolded PR passes"; fi
grep -q 'before its runbook exists' "$TMP/err" || fail "the unscaffolded-done refusal is not named"
run pr sk-d2 a --init >/dev/null || fail "--init after the refused done is refused"

# set --size=light repairs a scalar pending row instead of crashing or refusing.
runbook sk-scal "$ROWS_ALL"
node -e 'const fs = require("fs"); const f = "sk-scal/runbook.json"; const r = JSON.parse(fs.readFileSync(f)); r.phases["0"] = "pending"; fs.writeFileSync(f, JSON.stringify(r))'
run set sk-scal --size=light >/dev/null 2>&1 || fail "a scalar pending row blocks the light switch"
node -e 'const r = require("./sk-scal/runbook.json"); process.exit(r.phases["0"].state === "skipped" ? 0 : 1)' ||
	fail "the scalar row is not skipped"

# A done row requires a clean verdict in its artifact.
runbook sk-vfail "0:skipped 1:skipped 1r:skipped 2:done 2r:done 3:done 4:done 5:done 6:pending"
artifact sk-vfail 5 '{"schema":"verify","slug":"x","result":"fail","receipts":[]}'
if run check sk-vfail 2>"$TMP/err"; then fail "a failed verification with row 5 done passes"; fi
grep -q "result is 'fail'" "$TMP/err" || fail "the failed verify verdict is not named"
run set sk-vfail 5 blocked --note="verify failed" >/dev/null || fail "marking a failed verify blocked refused"

runbook sk-aval "0:done 1:done 1r:done 2:pending 2r:pending 3:pending 4:pending 5:pending 6:pending"
artifact sk-aval 1 '{"schema":"alternatives","slug":"x","options":2,"chosen":"a","review":{"valid":2,"false-positive":0,"unvalidated":0}}'
if run check sk-aval 2>"$TMP/err"; then fail "a done alternatives review with open findings passes"; fi
grep -q 'unresolved valid findings' "$TMP/err" || fail "the open findings are not named"

runbook sk-rv "0:done 1:done 1r:done 2:done 2r:done 3:done 4:done 5:pending 6:pending"
artifact sk-rv 4 '{"schema":"review","slug":"x","result":"findings-fixed","passes":1,"valid":1,"false-positive":0,"unvalidated":0}'
if run check sk-rv 2>"$TMP/err"; then fail "a done review with a valid finding passes"; fi
grep -q 'unresolved valid findings' "$TMP/err" || fail "the review finding is not named"
artifact sk-rv 4 '{"schema":"review","slug":"x","result":"blocked","passes":1,"valid":0,"false-positive":0,"unvalidated":0}'
if run check sk-rv 2>"$TMP/err"; then fail "a blocked review marked done passes"; fi
grep -q "result is 'blocked'" "$TMP/err" || fail "the blocked verdict is not named"

# A reopened unfinished row blocks new completions behind it.
runbook sk-reo "0:done 1:done 1r:done 2:done 2r:done 3:done 4:pending 5:pending 6:pending"
run set sk-reo 2 pending >/dev/null || fail "reopening a finished row refused"
run set sk-reo 2 in-progress >/dev/null || fail "resuming a reopened row refused"
if run set sk-reo 4 done 2>"$TMP/err"; then fail "completing a later row past a reopened one passes"; fi
grep -q 'while reopened row 2' "$TMP/err" || fail "the reopened-row guard is not named"
run set sk-reo 2 done >/dev/null || fail "finishing the reopened row refused"

# A receipt stays valid while its recorded HEAD is still in the tree, and fails once orphaned or fabricated.
git init -q g && git -C g config user.email t@t && git -C g config user.name t
git -C g commit -q --allow-empty -m c1
H1=$(git -C g rev-parse HEAD)
mkdir -p g/.agents/receipts
printf 'receipt-version: 1\nlabel: t\nexit-code: 0\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: %s\ncommand: true\n\n--- output (last 30 lines) ---\nok\n' "$H1" > g/.agents/receipts/run.receipt
runbook g/.agents/flows/lr "$LIGHT_OK" in-progress light
artifact g/.agents/flows/lr 3 '{"schema":"implementation","slug":"x","branch":"b","receipts":[".agents/receipts/run.receipt"],"deviations":0,"plan-gaps":0}'
artifact g/.agents/flows/lr 5 '{"schema":"verify","slug":"x","result":"pass","receipts":[".agents/receipts/run.receipt"]}'
run check g/.agents/flows/lr >/dev/null || fail "a receipt on the current HEAD is not valid"
git -C g commit -q --allow-empty -m c2
run check g/.agents/flows/lr >/dev/null || fail "a receipt on an ancestor commit is not valid"
git -C g checkout -qb side && git -C g commit -q --allow-empty -m s
S=$(git -C g rev-parse HEAD)
git -C g checkout -q -
printf 'receipt-version: 1\nlabel: t\nexit-code: 0\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: %s\ncommand: true\n\n--- output (last 30 lines) ---\nok\n' "$S" > g/.agents/receipts/run.receipt
if run check g/.agents/flows/lr 2>"$TMP/err"; then fail "a receipt on a side-branch head passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "the side-branch receipt is not diagnosed"
printf 'receipt-version: 1\nlabel: t\nexit-code: 0\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: deadbeef\ncommand: true\n\n--- output (last 30 lines) ---\nok\n' > g/.agents/receipts/run.receipt
if run check g/.agents/flows/lr 2>"$TMP/err"; then fail "a receipt on a fabricated head passes"; fi
grep -q 'did not pass' "$TMP/err" || fail "the fabricated receipt is not diagnosed"

echo "test-flow-state: all tests passed"
