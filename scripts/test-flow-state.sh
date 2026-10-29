#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() {
	echo "test-flow-state: FAIL: $1" >&2
	exit 1
}

git init -q .
git config user.email test@test
git config user.name test
git commit -qm init --allow-empty

FS="$REPO_ROOT/skills/sk-flow/scripts/flow-state.sh"
RW="$REPO_ROOT/skills/sk-implement/scripts/run-with-receipt.sh"
D=.agents/flows/sk-demo

ok() { sh "$FS" check "${2:-$D}" > "$TMP/out" 2> "$TMP/err" || fail "$1"; grep -q "status: ok" "$TMP/out" || fail "$1"; }
bad() { if sh "$FS" check "${2:-$D}" > "$TMP/out" 2> "$TMP/err"; then fail "$1"; fi; }

sh "$FS" init "$D" --slug=demo --goal="test flow" || fail "init failed"
[ -f "$D/runbook" ] || fail "init did not write $D/runbook"
grep -qx 'flows/' .agents/.gitignore || fail "init did not write .agents/.gitignore"
if sh "$FS" init "$D" --slug=demo --goal=x 2>/dev/null; then fail "init over an existing runbook succeeded"; fi

ok "fresh runbook does not check"
grep -q 'at: 0' "$TMP/out" || fail "fresh runbook not at row 0"
grep -q 'next-phase: Explore' "$TMP/out" || fail "next-phase is not Explore"

if sh "$FS" advance "$D" 2>/dev/null; then fail "advance accepted a missing artifact"; fi
echo "# 0 - EXPLORE" > "$D/0 - EXPLORE.md"
sh "$FS" advance "$D" >/dev/null || fail "advance row 0 failed"
grep -q '^at: 1$' "$D/runbook" || fail "cursor did not move to 1"

echo "# 1 - ALTERNATIVES" > "$D/1 - ALTERNATIVES.md"
sh "$FS" advance "$D" >/dev/null || fail "advance row 1 failed"
if sh "$FS" advance "$D" >/dev/null 2>&1; then fail "row 1r advanced without --valid=0"; fi
sh "$FS" advance "$D" --valid=0 >/dev/null || fail "advance row 1r failed"
grep -q '^f.1r.valid: 0$' "$D/runbook" || fail "row 1r valid not recorded"

echo "# 2 - PLANNING" > "$D/2 - PLANNING.md"
if sh "$FS" advance "$D" --decision=split 2>/dev/null; then fail "decision split accepted"; fi
sh "$FS" advance "$D" --decision=proceed >/dev/null || fail "advance row 2 failed"
sh "$FS" advance "$D" --valid=0 >/dev/null || fail "advance row 2r failed"

echo "# 3 - IMPLEMENTATION" > "$D/3 - IMPLEMENTATION.md"
if sh "$FS" advance "$D" 2>/dev/null; then fail "row 3 advanced without receipts"; fi
if sh "$FS" advance "$D" --receipts=receipts/nope.receipt 2>/dev/null; then fail "row 3 accepted a missing receipt"; fi
if sh "$FS" advance "$D" --receipts=../outside.receipt 2>/dev/null; then fail "row 3 accepted a receipt outside the flow dir"; fi
sh "$RW" "$D/receipts" impl -- true >/dev/null
R=$(basename "$D"/receipts/*-impl-*.receipt)
sh "$FS" advance "$D" --receipts="receipts/$R" >/dev/null || fail "advance row 3 with receipt failed"
mv "$D/receipts/$R" "$D/receipts/$R.keep"
bad "check passed with a missing cited receipt"
grep -q 'missing receipt' "$TMP/err" || fail "check did not report the missing receipt"
mv "$D/receipts/$R.keep" "$D/receipts/$R"
ok "check failed after restoring receipt"
grep -q 'warning' "$TMP/err" && fail "fresh receipt triggered a stale warning"
git commit -qm move-head --allow-empty
sh "$FS" check "$D" > "$TMP/out" 2> "$TMP/warn" || fail "stale receipt blocked the check"
grep -q 'status: ok' "$TMP/out" || fail "stale receipt flipped the status"
grep -q 'warning: .*behind current HEAD' "$TMP/warn" || fail "no stale-receipt warning on check"
B=$(git branch --show-current)
git checkout -q --orphan diverged
git commit -qm diverged --allow-empty
sh "$FS" check "$D" > "$TMP/out" 2> "$TMP/warn" || fail "diverged receipt blocked the check"
grep -q 'status: ok' "$TMP/out" || fail "diverged receipt flipped the status"
grep -q 'warning: .*not an ancestor' "$TMP/warn" || fail "no diverged-receipt warning on check"
git checkout -q "$B"
git branch -qD diverged


if sh "$FS" advance "$D" --receipts="receipts/$R" 2>/dev/null; then fail "row 4 accepted result-less advance"; fi
echo "# 4 - REVIEW" > "$D/4 - REVIEW.md"
if sh "$FS" advance "$D" --result=clean 2>/dev/null; then fail "row 4 advanced without --valid=0"; fi
if sh "$FS" advance "$D" --result=bogus --valid=0 2>/dev/null; then fail "row 4 accepted a bogus result"; fi
sh "$FS" advance "$D" --result=findings-fixed --valid=0 >/dev/null || fail "advance row 4 failed"

echo "# 5 - VERIFY" > "$D/5 - VERIFY.md"
if sh "$FS" advance "$D" --result=fail --receipts="receipts/$R" 2>/dev/null; then fail "row 5 accepted result=fail"; fi
sh "$RW" "$D/receipts" verify -- true >/dev/null
V=$(basename "$D"/receipts/*-verify-*.receipt)
sh "$FS" advance "$D" --result=pass --receipts="receipts/$V" >/dev/null || fail "advance row 5 failed"

echo "# 6 - PR" > "$D/6 - PR.md"
sh "$FS" advance "$D" >/dev/null || fail "advance row 6 failed"
grep -q '^at: done$' "$D/runbook" || fail "flow did not complete"
grep -q '^status: completed$' "$D/runbook" || fail "status not completed"
ok "completed flow does not check"
grep -q 'next: none' "$TMP/out" || fail "completed flow still has a next"

if sh "$FS" advance "$D" 2>/dev/null; then fail "advance on a completed flow succeeded"; fi

sh "$FS" set "$D" at=4 >/dev/null || fail "set at failed"
sh "$FS" set "$D" status=in-progress >/dev/null || fail "set status failed"
bad "stale later artifacts tolerated after reopen"
rm "$D/5 - VERIFY.md" "$D/6 - PR.md"
ok "reopened flow does not check"
grep -q 'at: 4' "$TMP/out" || fail "reopen did not move cursor back to 4"
if sh "$FS" advance "$D" --result=clean --valid=0 2>/dev/null; then :; else fail "re-advance of reopened row failed"; fi
echo "# 5 - VERIFY" > "$D/5 - VERIFY.md"
sh "$FS" advance "$D" --result=pass --receipts="receipts/$V" >/dev/null || fail "re-advance row 5 failed"
echo "# 6 - PR" > "$D/6 - PR.md"
sh "$FS" advance "$D" >/dev/null || fail "re-advance row 6 failed"

D2=.agents/flows/sk-skip
sh "$FS" init "$D2" --slug=skip --goal=g --at=5 >/dev/null || fail "init --at=5 failed"
grep -q '^f.3.skipped: 1$' "$D2/runbook" || fail "init --at did not mark earlier rows skipped"
if sh "$FS" advance "$D2" --skip 2>/dev/null; then fail "skip accepted without a note"; fi
if sh "$FS" advance "$D2" --skip --note=x --receipts=y 2>/dev/null; then fail "skip accepted extra flags"; fi
sh "$FS" advance "$D2" --skip --note="verify blocked" >/dev/null || fail "skip advance on row 5 failed"
grep -q '^f.5.skipped: 1$' "$D2/runbook" || fail "row 5 skip not recorded"
grep -q '^f.5.note: verify blocked$' "$D2/runbook" || fail "row 5 skip note not recorded"
sh "$FS" check "$D2" > "$TMP/out" || fail "check after skip failed"
grep -q 'at: 6' "$TMP/out" || fail "skip did not move cursor to 6"
echo "# 6 - PR" > "$D2/6 - PR.md"
sh "$FS" advance "$D2" >/dev/null || fail "advance row 6 after skip failed"
if sh "$FS" advance "$D2" --skip --note=x 2>/dev/null; then fail "skip accepted on a completed flow"; fi
if sh "$FS" note "$D2" "bad
note" 2>/dev/null; then fail "note accepted a newline"; fi
if sh "$FS" set "$D2" "at=one
two" 2>/dev/null; then fail "set accepted a newline value"; fi

D3=.agents/flows/sk-errs
sh "$FS" init "$D3" --slug=errs --goal=g --at=1 >/dev/null || fail "init --at=1 failed"
echo "# stray" > "$D3/9 - STRAY.md"
bad "stray numbered artifact accepted" "$D3"
rm "$D3/9 - STRAY.md"
echo "# 6 - PR" > "$D3/6 - PR.md"
bad "artifact for an unreached row accepted" "$D3"
rm "$D3/6 - PR.md"
echo "{}" > "$D3/runbook.json"
bad "legacy runbook.json tolerated" "$D3"
rm "$D3/runbook.json"
ok "clean dir does not check" "$D3"
if sh "$FS" init .agents/flows/sk-bad --slug=bad --goal=g --at=1r 2>/dev/null; then fail "init --at=1r accepted"; fi
echo "# 1" > "$D3/1 - ALTERNATIVES.md"
if sh "$FS" advance "$D3" --result=clean 2>/dev/null; then fail "row 1 accepted a flag it does not use"; fi
if sh "$FS" set "$D3" size=lihgt 2>/dev/null; then fail "set accepted a typo'd size"; fi
ok "typo'd size rejected by set" "$D3"

DL=.agents/flows/sk-lite
sh "$FS" init "$DL" --slug=lite --goal=g --size=light >/dev/null || fail "light init failed"
grep -q '^at: 2$' "$DL/runbook" || fail "light flow did not start at row 2"
echo "# 2 - PLANNING" > "$DL/2 - PLANNING.md"
if sh "$FS" advance "$DL" 2>/dev/null; then fail "row 2 advanced without --decision"; fi
sh "$FS" advance "$DL" --decision=proceed >/dev/null || fail "light advance row 2 failed"
echo "# 3 - IMPLEMENTATION" > "$DL/3 - IMPLEMENTATION.md"
sh "$RW" "$DL/receipts" impl -- true >/dev/null
RL=$(basename "$DL"/receipts/*-impl-*.receipt)
sh "$FS" advance "$DL" --receipts="receipts/$RL" >/dev/null || fail "light advance row 3 failed"
grep -q '^at: 5$' "$DL/runbook" || fail "light cursor did not jump 3->5 (row 4 must not exist)"
echo "# 4 - REVIEW" > "$DL/4 - REVIEW.md"
if sh "$FS" check "$DL" >/dev/null 2>&1; then fail "light flow tolerated a row-4 artifact"; fi
rm "$DL/4 - REVIEW.md"
echo "# 5 - VERIFY" > "$DL/5 - VERIFY.md"
sh "$FS" advance "$DL" --result=pass --receipts="receipts/$RL" >/dev/null || fail "light advance row 5 failed"
echo "# 6 - PR" > "$DL/6 - PR.md"
sh "$FS" advance "$DL" >/dev/null || fail "light advance row 6 failed"
grep -q '^at: done$' "$DL/runbook" || fail "light flow did not complete"

sh "$FS" note "$D" "reopened for a test" >/dev/null || fail "note failed"
grep -q '^note: reopened for a test$' "$D/runbook" || fail "note was not recorded"

D4=.agents/flows/sk-blocked
sh "$FS" init "$D4" --slug=blocked --goal=x >/dev/null || fail "blocked init failed"
sh "$FS" set "$D4" status=blocked >/dev/null || fail "set status=blocked failed"
if sh "$FS" advance "$D4" 2>"$TMP/err"; then fail "advance ran on a blocked flow"; fi
grep -q 'set status=in-progress to resume' "$TMP/err" || fail "blocked advance did not print the resume hint"
sh "$FS" set "$D4" status=in-progress >/dev/null || fail "set status=in-progress failed"
echo "# 0 - EXPLORE" > "$D4/0 - EXPLORE.md"
sh "$FS" advance "$D4" >/dev/null || fail "advance after resume failed"

D5=.agents/flows/sk-size
sh "$FS" init "$D5" --slug=size --goal=x >/dev/null || fail "size init failed"
sh "$FS" set "$D5" size=light >/dev/null || fail "set size=light failed"
grep -q '^at: 2$' "$D5/runbook" || fail "size=light did not move cursor to row 2"
ok "check after size=light" "$D5"
sh "$FS" set "$D5" size=full >/dev/null || fail "set size=full failed"
grep -q '^at: 0$' "$D5/runbook" || fail "size=full did not move cursor to row 0"
ok "check after size=full" "$D5"
echo "# 0 - EXPLORE" > "$D5/0 - EXPLORE.md"
if sh "$FS" set "$D5" size=light 2>/dev/null; then fail "set size= ran with artifacts present"; fi
rm "$D5/0 - EXPLORE.md"

mkdir -p nested/.agents/flows
printf 'dist' > nested/.agents/.gitignore
sh "$FS" init nested/.agents/flows/sk-nl --slug=nl --goal=x >/dev/null || fail "init under existing .gitignore failed"
[ "$(sed -n '1p' nested/.agents/.gitignore)" = "dist" ] || fail "init merged into last .gitignore line"
[ "$(sed -n '2p' nested/.agents/.gitignore)" = "flows/" ] || fail "init did not append flows/ after missing newline"
sh "$FS" init nested/.agents/flows/sk-nl2 --slug=nl2 --goal=x >/dev/null || fail "second init under existing .gitignore failed"
[ "$(grep -cx 'flows/' nested/.agents/.gitignore)" = "1" ] || fail "init duplicated flows/ in .gitignore"

echo "test-flow-state: all tests passed"
