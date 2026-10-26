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
mkdir -p scripts receipts
cp "$REPO_ROOT/skills/sk-implement/scripts/run-with-receipt.sh" scripts/
cp "$REPO_ROOT/skills/sk-implement/scripts/check-receipt.sh" scripts/
git add -A
git commit -qm init

sh scripts/run-with-receipt.sh receipts ok -- sh -c 'echo hello' >/dev/null || fail "passing run exits nonzero"
RECEIPT=$(ls receipts/*-ok-*.receipt)
grep -q '^result: pass$' "$RECEIPT" || fail "passing run did not record result: pass"
grep -q '^exit-code: 0$' "$RECEIPT" || fail "passing run did not record exit-code: 0"
grep -q '^hello$' "$RECEIPT" || fail "receipt is missing the command output"
grep -q "git-head: $(git rev-parse HEAD)" "$RECEIPT" || fail "receipt has the wrong git-head"
sh scripts/check-receipt.sh "$RECEIPT" >/dev/null || fail "check-receipt rejects a passing receipt"
sh scripts/check-receipt.sh "$RECEIPT" --head >/dev/null || fail "check-receipt --head rejects a receipt on the current HEAD"

CODE=0
sh scripts/run-with-receipt.sh receipts bad -- sh -c 'echo oops; exit 3' >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 3 ] || fail "failing run exits $CODE, not the command's 3"
RECEIPT=$(ls receipts/*-bad-*.receipt)
grep -q '^result: fail$' "$RECEIPT" || fail "failing run did not record result: fail"
if sh scripts/check-receipt.sh "$RECEIPT" >/dev/null 2>&1; then
	fail "check-receipt accepts a failing receipt"
fi

git commit -qm second --allow-empty
if sh scripts/check-receipt.sh "$(ls receipts/*-ok-*.receipt)" --head >/dev/null 2>&1; then
	fail "check-receipt --head accepts a receipt from an older commit"
fi
sh scripts/check-receipt.sh "$(ls receipts/*-ok-*.receipt)" >/dev/null || fail "check-receipt without --head rejects an older receipt"

printf 'receipt-version: 1\nresult: pass\nexit-code: 0\n' > "$TMP/partial.receipt"
if sh scripts/check-receipt.sh "$TMP/partial.receipt" >/dev/null 2>&1; then
	fail "check-receipt accepts a receipt missing fields"
fi
if sh scripts/check-receipt.sh "$TMP/missing.receipt" >/dev/null 2>&1; then
	fail "check-receipt accepts a missing file"
fi

printf 'receipt-version: 1\nlabel: x\nexit-code: 3\nresult: fail\nstarted-at: t\nfinished-at: t\ngit-head: none\ncommand: false\n\n--- output (last 30 lines) ---\nresult: pass\nexit-code: 0\n' > "$TMP/smuggled.receipt"
if sh scripts/check-receipt.sh "$TMP/smuggled.receipt" >/dev/null 2>&1; then
	fail "check-receipt reads fields from the output tail"
fi
sh scripts/check-receipt.sh "$(ls receipts/*-ok-*.receipt)" >/dev/null || fail "a real receipt no longer passes after the tail cut"

if sh scripts/run-with-receipt.sh 2>/dev/null; then
	fail "missing arguments are not rejected"
fi
CODE=0
sh scripts/run-with-receipt.sh receipts 'bad label' -- true >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 2 ] || fail "a label with a space is not rejected with exit 2"
if sh scripts/check-receipt.sh 2>/dev/null; then
	fail "check-receipt without arguments is not rejected"
fi

cp "$(ls receipts/*-ok-*.receipt | head -1)" "$TMP/nogit.receipt"
mv "$TMP/nogit.receipt" /tmp/nogit-receipt-$$
sh scripts/check-receipt.sh /tmp/nogit-receipt-$$ --head >/dev/null || fail "check-receipt --head failed outside a git repo"
rm -f /tmp/nogit-receipt-$$

echo "test-receipts: all tests passed"
