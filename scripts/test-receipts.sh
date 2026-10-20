#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() {
	echo "test-receipts: FAIL: $1" >&2
	exit 1
}

git init -q .
git config user.email test@test
git config user.name test
mkdir -p scripts
cp "$REPO_ROOT/skills/sk-implement/scripts/run-with-receipt.sh" scripts/
cp "$REPO_ROOT/skills/sk-implement/scripts/check-receipt.sh" scripts/
git add -A
git commit -qm init

# A passing command exits 0 and leaves a valid passing receipt.
sh scripts/run-with-receipt.sh ok -- sh -c 'echo hello' >"$TMP/run-out" || fail "passing run exits nonzero"
RECEIPT=$(ls .agents/receipts/*-ok.receipt)
grep -q '^result: pass$' "$RECEIPT" || fail "passing run did not record result: pass"
grep -q '^exit-code: 0$' "$RECEIPT" || fail "passing run did not record exit-code: 0"
grep -q '^hello$' "$RECEIPT" || fail "receipt is missing the command output"
grep -q "git-head: $(git rev-parse HEAD)" "$RECEIPT" || fail "receipt has the wrong git-head"
sh scripts/check-receipt.sh "$RECEIPT" >/dev/null || fail "check-receipt rejects a passing receipt"
sh scripts/check-receipt.sh "$RECEIPT" --head >/dev/null || fail "check-receipt --head rejects a receipt on the current HEAD"

# A failing command propagates its exit code and leaves a failing receipt.
CODE=0
sh scripts/run-with-receipt.sh bad -- sh -c 'echo oops; exit 3' >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 3 ] || fail "failing run exits $CODE, not the command's 3"
RECEIPT=$(ls .agents/receipts/*-bad.receipt)
grep -q '^result: fail$' "$RECEIPT" || fail "failing run did not record result: fail"
if sh scripts/check-receipt.sh "$RECEIPT" >/dev/null 2>&1; then
	fail "check-receipt accepts a failing receipt"
fi

# --head rejects a receipt recorded on an older commit.
git commit -qm second --allow-empty
if sh scripts/check-receipt.sh "$(ls .agents/receipts/*-ok.receipt)" --head >/dev/null 2>&1; then
	fail "check-receipt --head accepts a receipt from an older commit"
fi
sh scripts/check-receipt.sh "$(ls .agents/receipts/*-ok.receipt)" >/dev/null || fail "check-receipt without --head rejects an older receipt"

# Incomplete receipts are rejected.
printf 'receipt-version: 1\nresult: pass\nexit-code: 0\n' > "$TMP/partial.receipt"
if sh scripts/check-receipt.sh "$TMP/partial.receipt" >/dev/null 2>&1; then
	fail "check-receipt accepts a receipt missing fields"
fi
if sh scripts/check-receipt.sh "$TMP/missing.receipt" >/dev/null 2>&1; then
	fail "check-receipt accepts a missing file"
fi

# Bad usage exits 2.
if sh scripts/run-with-receipt.sh 2>/dev/null; then
	fail "missing arguments are not rejected"
fi
CODE=0
sh scripts/run-with-receipt.sh 'bad label' -- true >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 2 ] || fail "a label with a space is not rejected with exit 2"
if sh scripts/check-receipt.sh 2>/dev/null; then
	fail "check-receipt without arguments is not rejected"
fi

echo "test-receipts: all tests passed"
